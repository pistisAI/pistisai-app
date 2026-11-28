/**
 * Server-side Sentry reports must never carry credentials: both streaming-proxy
 * entry points (proxy-server.js and src/server.ts) pass events through
 * scrubSentryEvent in their beforeSend hook.
 */
import { describe, expect, it } from "@jest/globals";
import path from "path";
import { fileURLToPath } from "url";
import { readFileSync } from "fs";

import { scrubSentryEvent } from "../../services/streaming-proxy/sentry-scrub.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROXY_DIR = path.join(__dirname, "../../services/streaming-proxy");

function sampleEvent() {
  return {
    message: "boom",
    tags: { service: "streaming-proxy" },
    request: {
      method: "GET",
      url: "https://proxy.example.com/api/tags?token=t1&api_key=k1&stream=true",
      query_string: "token=t1&api_key=k1&stream=true",
      cookies: { CF_Authorization: "c1" },
      headers: {
        authorization: "Bearer secret-1",
        Cookie: "CF_Authorization=c1",
        "set-cookie": "a=b",
        "Cf-Access-Jwt-Assertion": "jwt-1",
        "X-Api-Key": "key-1",
        host: "proxy.example.com",
        accept: "application/json",
      },
    },
    breadcrumbs: [
      {
        category: "http",
        data: {
          url: "http://127.0.0.1:11434/api/chat?access_token=a1&x=1",
          method: "POST",
          request_headers: { "x-api-key": "k2", "content-type": "json" },
        },
      },
    ],
  };
}

describe("scrubSentryEvent (streaming-proxy)", () => {
  it.each([
    "authorization",
    "Cookie",
    "set-cookie",
    "Cf-Access-Jwt-Assertion",
    "X-Api-Key",
  ])("removes the %s request header", (name) => {
    const event = scrubSentryEvent(sampleEvent());
    expect(event.request.headers).not.toHaveProperty(name);
  });

  it("keeps the other headers and fields", () => {
    const event = scrubSentryEvent(sampleEvent());
    expect(event.request.headers).toEqual({
      host: "proxy.example.com",
      accept: "application/json",
    });
    expect(event.request.method).toBe("GET");
    expect(event.message).toBe("boom");
    expect(event.tags).toEqual({ service: "streaming-proxy" });
  });

  it("removes cookies and token query params", () => {
    const event = scrubSentryEvent(sampleEvent());
    expect(event.request).not.toHaveProperty("cookies");
    expect(event.request.query_string).toBe("stream=true");
    expect(event.request.url).toBe(
      "https://proxy.example.com/api/tags?stream=true",
    );
  });

  it("scrubs breadcrumb headers and URLs", () => {
    const event = scrubSentryEvent(sampleEvent());
    const data = event.breadcrumbs[0].data;
    expect(data.request_headers).toEqual({ "content-type": "json" });
    expect(data.url).toBe("http://127.0.0.1:11434/api/chat?x=1");
    expect(data.method).toBe("POST");
  });
});

describe("streaming-proxy Sentry wiring", () => {
  it.each([
    ["proxy-server.js", "./sentry-scrub.js"],
    ["src/server.ts", "../sentry-scrub.js"],
  ])("%s beforeSend returns the scrubbed event", (file, importPath) => {
    const source = readFileSync(path.join(PROXY_DIR, file), "utf8");
    expect(source).toContain(
      `import { scrubSentryEvent } from '${importPath}';`,
    );
    expect(source).toMatch(/dsn: process\.env\.SENTRY_DSN,/);
    const hook = source.slice(source.indexOf("beforeSend(event)"));
    expect(hook).toMatch(/return scrubSentryEvent\(event\);/);
  });
});
