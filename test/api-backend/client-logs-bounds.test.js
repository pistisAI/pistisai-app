/**
 * The unauthenticated client-log intake is bounded: field lengths, batch
 * size, body size, request rate per IP and on-disk file size.
 */
import { afterAll, beforeAll, describe, expect, it } from "@jest/globals";
import express from "express";
import request from "supertest";
import os from "os";
import path from "path";
import { promises as fs } from "fs";

import clientLogsRouter, {
  CLIENT_LOG_LIMITS,
  rotateIfNeeded,
  sanitizeClientLogEntry,
  setClientLogDirForTesting,
  stripUrlQuery,
} from "../../services/api-backend/routes/client-logs.js";
import { hasOwnBodyParser } from "../../services/api-backend/middleware/raw-body.js";

let tmpDir;
let logFile;
let ipCounter = 0;

function nextIp() {
  ipCounter += 1;
  return `198.51.100.${ipCounter}`;
}

function buildApp() {
  const app = express();
  app.set("trust proxy", true);
  app.use("/api/client-logs", clientLogsRouter);
  return app;
}

beforeAll(async () => {
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "client-logs-test-"));
  logFile = setClientLogDirForTesting(tmpDir);
});

afterAll(async () => {
  await fs.rm(tmpDir, { recursive: true, force: true });
});

describe("client log sanitizing", () => {
  it("stringifies object messages and caps them", () => {
    const entry = sanitizeClientLogEntry(
      { message: { text: "x".repeat(5000) } },
      { source: "flutter-web", sessionId: null, fallbackUserAgent: null },
    );
    expect(typeof entry.message).toBe("string");
    expect(entry.message.length).toBe(CLIENT_LOG_LIMITS.maxMessageLength);
    expect(entry.message.startsWith('{"text":')).toBe(true);
  });

  it("caps string messages and user agents", () => {
    const entry = sanitizeClientLogEntry(
      { message: "m".repeat(3000), userAgent: "u".repeat(3000) },
      { source: "s".repeat(500), sessionId: null, fallbackUserAgent: null },
    );
    expect(entry.message.length).toBe(CLIENT_LOG_LIMITS.maxMessageLength);
    expect(entry.userAgent.length).toBe(CLIENT_LOG_LIMITS.maxUserAgentLength);
    expect(entry.source.length).toBe(CLIENT_LOG_LIMITS.maxSourceLength);
  });

  it("strips query string and fragment from urls", () => {
    expect(
      stripUrlQuery("https://app.example.com/chat?token=abc#access_token=x"),
    ).toBe("https://app.example.com/chat");
    expect(
      stripUrlQuery(`https://app.example.com/${"p".repeat(2000)}`).length,
    ).toBe(CLIENT_LOG_LIMITS.maxUrlLength);
    expect(stripUrlQuery(null)).toBeNull();
  });
});

describe("POST /client-logs", () => {
  it("accepts the web app format and writes sanitized entries", async () => {
    const res = await request(buildApp())
      .post("/api/client-logs")
      .set("X-Forwarded-For", nextIp())
      .send({
        entries: [
          {
            timestamp: new Date().toISOString(),
            level: "INFO",
            message: "hello",
            url: "https://app.example.com/home?code=secret#frag",
            userAgent: "TestAgent/1.0",
          },
        ],
        source: "flutter-web",
      });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, count: 1 });
    const written = await fs.readFile(logFile, "utf8");
    expect(written).toContain('"url":"https://app.example.com/home"');
    expect(written).not.toContain("secret");
  });

  it("rejects more than 100 entries", async () => {
    const entries = Array.from(
      { length: CLIENT_LOG_LIMITS.maxEntries + 1 },
      () => ({
        message: "x",
      }),
    );
    const res = await request(buildApp())
      .post("/api/client-logs")
      .set("X-Forwarded-For", nextIp())
      .send({ entries });
    expect(res.status).toBe(400);
  });

  it("rejects bodies over the route limit", async () => {
    const entries = Array.from({ length: 50 }, () => ({
      message: "x".repeat(6000),
    }));
    const res = await request(buildApp())
      .post("/api/client-logs")
      .set("X-Forwarded-For", nextIp())
      .send({ entries });
    expect(res.status).toBe(413);
  });

  it("rate limits each IP", async () => {
    const app = buildApp();
    const ip = nextIp();
    let last;
    for (let i = 0; i < 31; i += 1) {
      last = await request(app)
        .post("/api/client-logs")
        .set("X-Forwarded-For", ip)
        .send({ entries: [{ message: "x" }] });
    }
    expect(last.status).toBe(429);
    const other = await request(app)
      .post("/api/client-logs")
      .set("X-Forwarded-For", nextIp())
      .send({ entries: [{ message: "x" }] });
    expect(other.status).toBe(200);
  });
});

describe("log file size cap", () => {
  it("rotates to .1 when the cap would be exceeded, keeping one rotated file", async () => {
    const file = path.join(tmpDir, "rotate.log");
    await fs.writeFile(file, "a".repeat(90));
    expect(await rotateIfNeeded(file, 5, 100)).toBe(false);
    expect(await rotateIfNeeded(file, 20, 100)).toBe(true);
    await expect(fs.stat(file)).rejects.toThrow();
    expect((await fs.stat(`${file}.1`)).size).toBe(90);

    await fs.writeFile(file, "b".repeat(95));
    expect(await rotateIfNeeded(file, 20, 100)).toBe(true);
    expect(await fs.readFile(`${file}.1`, "utf8")).toBe("b".repeat(95));
    await expect(fs.stat(`${file}.2`)).rejects.toThrow();
  });

  it("does nothing when the file does not exist yet", async () => {
    expect(await rotateIfNeeded(path.join(tmpDir, "none.log"), 10, 100)).toBe(
      false,
    );
  });
});

describe("global body parser skip list", () => {
  it.each(["/client-logs", "/api/client-logs", "/api/client-logs/"])(
    "skips %s",
    (url) => {
      expect(hasOwnBodyParser({ originalUrl: url })).toBe(true);
    },
  );

  it("does not skip other routes", () => {
    expect(hasOwnBodyParser({ originalUrl: "/api/conversations" })).toBe(false);
  });
});
