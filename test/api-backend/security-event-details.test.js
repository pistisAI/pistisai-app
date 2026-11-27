/**
 * security_events.details must not store raw emails or tokens, and auth-service
 * logs must mask addresses the same way as the other api-backend log sites.
 */
import { describe, expect, it, afterEach, jest } from "@jest/globals";

import { sanitizeSecurityEventDetails } from "../../services/api-backend/utils/security-event-details.js";
import { AuthService } from "../../services/api-backend/auth/auth-service.js";

const USER_ID = "11111111-2222-3333-4444-555555555555";
const JWT =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyIn0.signaturevalue";

function loggedText(logger) {
  return JSON.stringify([
    ...logger.info.mock.calls,
    ...logger.warn.mock.calls,
    ...logger.error.mock.calls,
  ]);
}

describe("sanitizeSecurityEventDetails", () => {
  it("masks emails and redacts tokens but keeps the user id", () => {
    const safe = sanitizeSecurityEventDetails({
      userId: USER_ID,
      email: "user@example.com",
      error: `rejected ${JWT} for user@example.com`,
      ip: "203.0.113.10",
      userAgent: "TestAgent/1.0",
      channel: "websocket",
    });
    const encoded = JSON.stringify(safe);
    expect(encoded).not.toContain("user@example.com");
    expect(encoded).not.toContain(JWT);
    expect(encoded).not.toContain("eyJ");
    expect(safe.userId).toBe(USER_ID);
    expect(safe.email).toBe("u***@example.com");
    expect(safe.error).toContain("u***@example.com");
    expect(safe.error).toContain("[redacted]");
    expect(safe.channel).toBe("websocket");
    expect(safe.ip).toBe("203.0.113.10");
    expect(safe.userAgent).toBe("TestAgent/1.0");
  });

  it("returns an empty object for non-objects", () => {
    expect(sanitizeSecurityEventDetails(null)).toEqual({});
    expect(sanitizeSecurityEventDetails(undefined)).toEqual({});
    expect(sanitizeSecurityEventDetails("user@example.com")).toEqual({});
    expect(sanitizeSecurityEventDetails(["user@example.com"])).toEqual({});
  });

  it("masks an email nested in a detail object", () => {
    const safe = sanitizeSecurityEventDetails({
      context: { email: "ada@example.com", note: "seen ada@example.com" },
    });
    const encoded = JSON.stringify(safe);
    expect(encoded).not.toContain("ada@example.com");
    expect(safe.context.email).toBe("a***@example.com");
    expect(safe.context.note).toContain("a***@example.com");
  });
});

describe("AuthService personal data in logs and security_events", () => {
  let auth;

  afterEach(async () => {
    await auth?.db?.pool?.end?.();
  });

  function service() {
    auth = new AuthService({});
    auth.logger = { info: jest.fn(), warn: jest.fn(), error: jest.fn() };
    return auth;
  }

  it("stores sanitized details and the ip column", async () => {
    const svc = service();
    const queries = [];
    svc.runQuery = async (sql, params) => {
      queries.push({ sql, params });
      return { changes: 1 };
    };

    await svc.logSecurityEvent("token_validation_failure", {
      error: `bad ${JWT} user@example.com`,
      email: "user@example.com",
      ip: "203.0.113.10",
      userAgent: "TestAgent/1.0",
      userId: USER_ID,
    });

    expect(queries[0].sql).toMatch(/INSERT INTO security_events/);
    const details = JSON.parse(queries[0].params[1]);
    const encoded = JSON.stringify(details);
    expect(encoded).not.toContain("user@example.com");
    expect(encoded).not.toContain(JWT);
    expect(details.userId).toBe(USER_ID);
    expect(details.email).toBe("u***@example.com");
    expect(queries[0].params[2]).toBe("203.0.113.10");
  });

  it("does not send an empty ip string to the inet column", async () => {
    const svc = service();
    const queries = [];
    svc.runQuery = async (sql, params) => {
      queries.push({ sql, params });
      return { changes: 1 };
    };
    await svc.logSecurityEvent("token_validation_failure", {
      error: "jwt malformed",
      ip: "",
    });
    expect(queries[0].params[2]).toBeNull();
    expect(JSON.parse(queries[0].params[1]).error).toBe("jwt malformed");
  });

  it("logs a masked email when linking an Access subject", async () => {
    const svc = service();
    svc.runQuery = async (sql) => {
      if (
        sql.includes("supabase_id = $1") &&
        sql.includes("SELECT id FROM users")
      ) {
        return null;
      }
      if (sql.includes("user_auth_subjects WHERE subject")) return null;
      if (sql.includes("WHERE email = $1")) {
        return { id: USER_ID, supabase_id: "old-subject" };
      }
      return { changes: 1 };
    };
    svc.linkAuthSubject = async () => {};

    await svc.resolveUserId("new-subject", {
      email: "user@example.com",
      email_verified: true,
    });

    const logged = loggedText(svc.logger);
    expect(logged).toContain("u***@example.com");
    expect(logged).not.toContain("user@example.com");
  });

  it("logs a masked email when refusing an unverified link", async () => {
    const svc = service();
    svc.runQuery = async (sql) => {
      if (
        sql.includes("supabase_id = $1") &&
        sql.includes("SELECT id FROM users")
      ) {
        return null;
      }
      if (sql.includes("user_auth_subjects WHERE subject")) return null;
      if (sql.includes("WHERE email = $1")) {
        return { id: USER_ID, supabase_id: "old-subject" };
      }
      return { changes: 1 };
    };

    await expect(
      svc.resolveUserId("new-subject", {
        email: "user@example.com",
        email_verified: false,
      }),
    ).rejects.toThrow(/not verified/);

    const logged = loggedText(svc.logger);
    expect(logged).toContain("u***@example.com");
    expect(logged).not.toContain("user@example.com");
  });

  it("does not log or store a raw email or token from a validation failure", async () => {
    const svc = service();
    const queries = [];
    svc.runQuery = async (sql, params) => {
      queries.push({ sql, params });
      if (String(sql).includes("security_events")) return { changes: 1 };
      throw new Error(`duplicate key user@example.com ${JWT}`);
    };

    const result = await svc.validateToken(
      "ignored",
      { ip: "203.0.113.10", headers: { "user-agent": "TestAgent/1.0" } },
      { sub: "subject-1", email: "user@example.com" },
    );

    expect(result.valid).toBe(false);
    const logged = loggedText(svc.logger);
    expect(logged).not.toContain("user@example.com");
    expect(logged).not.toContain(JWT);
    expect(logged).toContain("u***@example.com");

    const insert = queries.find((q) =>
      String(q.sql).includes("security_events"),
    );
    expect(insert).toBeDefined();
    const encoded = insert.params[1];
    expect(encoded).not.toContain("user@example.com");
    expect(encoded).not.toContain(JWT);
    expect(encoded).toContain("u***@example.com");
  });

  it("keeps the resolved user id on a failure after the account is known", async () => {
    const svc = service();
    const queries = [];
    svc.resolveUserId = async () => USER_ID;
    svc.runQuery = async (sql, params) => {
      queries.push({ sql, params });
      if (String(sql).includes("is_suspended")) {
        throw new Error("db down");
      }
      if (String(sql).includes("security_events")) return { changes: 1 };
      return null;
    };

    const result = await svc.validateToken(
      "ignored",
      { ip: "203.0.113.10", headers: {} },
      { sub: "subject-1" },
    );

    expect(result.valid).toBe(false);
    const insert = queries.find((q) =>
      String(q.sql).includes("security_events"),
    );
    expect(insert).toBeDefined();
    expect(JSON.parse(insert.params[1]).userId).toBe(USER_ID);
    expect(JSON.parse(insert.params[1]).error).toBe("db down");
  });
});
