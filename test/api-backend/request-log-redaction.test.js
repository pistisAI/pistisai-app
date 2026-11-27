/**
 * Request log redaction: session tokens in the path must be redacted under
 * every mount prefix of the session routes (`/auth/sessions` and
 * `/api/auth/sessions`), and credential-looking query parameters must be
 * redacted from logged URLs.
 */
import { describe, expect, it } from "@jest/globals";

import {
  redactPathForLog,
  redactQueryForLog,
  redactUrlQuery,
} from "../../services/api-backend/middleware/request-logging.js";

const TOKEN = "eyJhbGciOiJIUzI1NiJ9.payload.signature";

describe("redactPathForLog", () => {
  it.each([
    [`/auth/sessions/validate/${TOKEN}`, "/auth/sessions/validate/[REDACTED]"],
    [
      `/api/auth/sessions/validate/${TOKEN}`,
      "/api/auth/sessions/validate/[REDACTED]",
    ],
    [
      `/api/v1/auth/sessions/validate/${TOKEN}`,
      "/api/v1/auth/sessions/validate/[REDACTED]",
    ],
    [`/auth/sessions/${TOKEN}`, "/auth/sessions/[REDACTED]"],
    [`/api/auth/sessions/${TOKEN}`, "/api/auth/sessions/[REDACTED]"],
    [`/api/auth/sessions/${TOKEN}/`, "/api/auth/sessions/[REDACTED]/"],
  ])("redacts %s", (input, expected) => {
    expect(redactPathForLog(input)).toBe(expected);
    expect(redactPathForLog(input)).not.toContain(TOKEN);
  });

  it.each([
    "/api/auth/sessions/current",
    "/api/auth/sessions/tokens",
    "/api/auth/sessions/cleanup",
    "/api/auth/sessions/validate",
    "/api/auth/sessions/invalidate",
    "/auth/sessions/current",
    "/api/conversations/abc",
  ])("keeps static path %s", (input) => {
    expect(redactPathForLog(input)).toBe(input);
  });

  it("redacts token query parameters in a full URL", () => {
    const url = `/api/auth/sessions/validate/${TOKEN}?token=${TOKEN}&page=2`;
    const out = redactPathForLog(url);
    expect(out).not.toContain(TOKEN);
    expect(out).toContain("page=2");
  });

  it("passes non-strings through", () => {
    expect(redactPathForLog(undefined)).toBeUndefined();
  });
});

describe("redactUrlQuery", () => {
  it.each([
    "token",
    "access_token",
    "cf_jwt",
    "jwt",
    "apiKey",
    "api_key",
    "refresh_token",
  ])("redacts %s", (key) => {
    const out = redactUrlQuery(`/api/tunnel/ws?${key}=s3cret&x=1#frag`);
    expect(out).toBe(`/api/tunnel/ws?${key}=[REDACTED]&x=1#frag`);
  });

  it("leaves URLs without a query alone", () => {
    expect(redactUrlQuery("/api/health")).toBe("/api/health");
  });
});

describe("redactQueryForLog", () => {
  it("redacts jwt-style keys as well as token keys", () => {
    expect(
      redactQueryForLog({
        cf_jwt: "a",
        jwt: "b",
        apiKey: "c",
        access_token: "d",
        q: "ok",
      }),
    ).toEqual({
      cf_jwt: "[REDACTED]",
      jwt: "[REDACTED]",
      apiKey: "[REDACTED]",
      access_token: "[REDACTED]",
      q: "ok",
    });
  });
});
