/**
 * Server-side Sentry reports must never carry credentials: the api-backend
 * beforeSend hook removes credential headers, cookies and token-like query
 * parameters from the request and from breadcrumbs.
 */
import { describe, expect, it } from "@jest/globals";
import path from "path";
import { fileURLToPath } from "url";
import { readFileSync } from "fs";

import { scrubSentryEvent } from "../../services/api-backend/utils/sentry-scrub.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const API_DIR = path.join(__dirname, "../../services/api-backend");

function sampleEvent() {
  return {
    event_id: "abc123",
    message: "boom",
    tags: { service: "api-backend" },
    extra: { requestId: "req-1" },
    request: {
      method: "POST",
      url: "https://api.example.com/v1/chat?model=llama&token=t1&access_token=t2&api_key=k1&page=2#frag",
      query_string: "model=llama&token=t1&access_token=t2&api_key=k1&page=2",
      cookies: { session: "s1" },
      data: { prompt: "hello" },
      headers: {
        Authorization: "Bearer secret-1",
        cookie: "session=s1",
        "Set-Cookie": "session=s1",
        "CF-ACCESS-JWT-ASSERTION": "jwt-1",
        "x-api-key": "key-1",
        "Content-Type": "application/json",
        "User-Agent": "test-agent",
      },
    },
    breadcrumbs: [
      {
        category: "http",
        data: {
          url: "https://upstream.example.com/x?refresh_token=r1&q=ok",
          method: "GET",
          status_code: 500,
          headers: { authorization: "Bearer b1", accept: "text/plain" },
          "http.query": "refresh_token=r1&q=ok",
        },
      },
      { category: "console", message: "log line" },
    ],
  };
}

describe("scrubSentryEvent (api-backend)", () => {
  it.each([
    "Authorization",
    "cookie",
    "Set-Cookie",
    "CF-ACCESS-JWT-ASSERTION",
    "x-api-key",
  ])("removes the %s request header", (name) => {
    const event = scrubSentryEvent(sampleEvent());
    expect(event.request.headers).not.toHaveProperty(name);
  });

  it("matches header names in any letter case", () => {
    const event = scrubSentryEvent({
      request: {
        headers: {
          AUTHORIZATION: "a",
          Cookie: "b",
          "set-cookie": "c",
          "Cf-Access-Jwt-Assertion": "d",
          "X-API-KEY": "e",
        },
      },
    });
    expect(event.request.headers).toEqual({});
  });

  it("keeps the other request headers and fields", () => {
    const event = scrubSentryEvent(sampleEvent());
    expect(event.request.headers).toEqual({
      "Content-Type": "application/json",
      "User-Agent": "test-agent",
    });
    expect(event.request.method).toBe("POST");
    expect(event.request.data).toEqual({ prompt: "hello" });
    expect(event.event_id).toBe("abc123");
    expect(event.message).toBe("boom");
    expect(event.tags).toEqual({ service: "api-backend" });
    expect(event.extra).toEqual({ requestId: "req-1" });
  });

  it("removes the cookies field", () => {
    const event = scrubSentryEvent(sampleEvent());
    expect(event.request).not.toHaveProperty("cookies");
  });

  it("removes token-like query params and keeps the others", () => {
    const event = scrubSentryEvent(sampleEvent());
    expect(event.request.query_string).toBe("model=llama&page=2");
    expect(event.request.url).toBe(
      "https://api.example.com/v1/chat?model=llama&page=2#frag",
    );
  });

  it("handles query_string as an object or as pairs", () => {
    const asObject = scrubSentryEvent({
      request: { query_string: { token: "t", Api_Key: "k", q: "ok" } },
    });
    expect(asObject.request.query_string).toEqual({ q: "ok" });

    const asPairs = scrubSentryEvent({
      request: {
        query_string: [
          ["access_token", "t"],
          ["q", "ok"],
        ],
      },
    });
    expect(asPairs.request.query_string).toEqual([["q", "ok"]]);
  });

  it("drops the ? when every param is a credential", () => {
    const event = scrubSentryEvent({
      request: { url: "https://api.example.com/x?token=t" },
    });
    expect(event.request.url).toBe("https://api.example.com/x");
  });

  it("scrubs breadcrumb headers and URLs, keeping other breadcrumb data", () => {
    const event = scrubSentryEvent(sampleEvent());
    const http = event.breadcrumbs[0].data;
    expect(http.headers).toEqual({ accept: "text/plain" });
    expect(http.url).toBe("https://upstream.example.com/x?q=ok");
    expect(http["http.query"]).toBe("q=ok");
    expect(http.method).toBe("GET");
    expect(http.status_code).toBe(500);
    expect(event.breadcrumbs[1]).toEqual({
      category: "console",
      message: "log line",
    });
  });

  it("accepts breadcrumbs in the { values } shape", () => {
    const event = scrubSentryEvent({
      breadcrumbs: {
        values: [{ data: { url: "https://h.example.com/?token=t&a=1" } }],
      },
    });
    expect(event.breadcrumbs.values[0].data.url).toBe(
      "https://h.example.com/?a=1",
    );
  });

  it("leaves events without a request untouched", () => {
    const event = { message: "no request" };
    expect(scrubSentryEvent(event)).toEqual({ message: "no request" });
    expect(scrubSentryEvent(null)).toBeNull();
  });
});

describe("api-backend Sentry wiring", () => {
  const server = readFileSync(path.join(API_DIR, "server.js"), "utf8");

  it("beforeSend returns the scrubbed event", () => {
    expect(server).toMatch(
      /import \{ scrubSentryEvent \} from '\.\/utils\/sentry-scrub\.js'/,
    );
    const hook = server.slice(server.indexOf("beforeSend(event)"));
    expect(hook).toMatch(/return scrubSentryEvent\(event\);/);
  });

  it("Sentry stays tied to SENTRY_DSN", () => {
    expect(server).toMatch(/dsn: process\.env\.SENTRY_DSN,/);
  });
});
