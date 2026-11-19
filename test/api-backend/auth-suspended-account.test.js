/**
 * #847: Suspended accounts must be rejected during token validation.
 */
import { jest, describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import { AuthService } from "../../services/api-backend/auth/auth-service.js";

describe("AuthService suspended account check (#847)", () => {
  let auth;

  beforeEach(() => {
    process.env.CF_ACCESS_TEAM_DOMAIN = "example.cloudflareaccess.com";
    process.env.CF_ACCESS_AUD = "test-aud";
    auth = new AuthService({});
    auth.logSecurityEvent = jest.fn().mockResolvedValue(undefined);
  });

  afterEach(() => {
    delete process.env.CF_ACCESS_TEAM_DOMAIN;
    delete process.env.CF_ACCESS_AUD;
  });

  it("rejects a suspended user with ACCOUNT_SUSPENDED and does not create a session", async () => {
    auth.resolveUserId = jest.fn().mockResolvedValue("user-suspended");
    auth.createOrUpdateSession = jest.fn();
    auth.runQuery = jest.fn(async (sql) => {
      const normalized = sql.replace(/\s+/g, " ").trim();
      if (normalized.includes("is_suspended")) {
        return { is_suspended: true };
      }
      throw new Error(`Unexpected query: ${normalized}`);
    });

    const result = await auth.validateToken(
      "unused-token",
      { ip: "127.0.0.1", headers: {} },
      {
        sub: "access-sub-1",
        email: "suspended@example.com",
        aud: "test-aud",
        exp: Math.floor(Date.now() / 1000) + 3600,
      },
    );

    expect(result.valid).toBe(false);
    expect(result.code).toBe("ACCOUNT_SUSPENDED");
    expect(result.error).toMatch(/suspended/i);
    expect(auth.createOrUpdateSession).not.toHaveBeenCalled();
  });

  it("allows a non-suspended user through to session creation", async () => {
    auth.resolveUserId = jest.fn().mockResolvedValue("user-active");
    auth.createOrUpdateSession = jest.fn().mockResolvedValue({ id: "sess-1" });
    auth.runQuery = jest.fn(async (sql) => {
      const normalized = sql.replace(/\s+/g, " ").trim();
      if (normalized.includes("is_suspended")) {
        return { is_suspended: false };
      }
      throw new Error(`Unexpected query: ${normalized}`);
    });

    const payload = {
      sub: "access-sub-2",
      email: "active@example.com",
      aud: "test-aud",
      exp: Math.floor(Date.now() / 1000) + 3600,
    };

    const result = await auth.validateToken(
      "unused-token",
      { ip: "127.0.0.1", headers: {} },
      payload,
    );

    expect(result.valid).toBe(true);
    expect(auth.createOrUpdateSession).toHaveBeenCalled();
  });
});

describe("authenticateJWT suspended account response (#847)", () => {
  it("returns 403 with ACCOUNT_SUSPENDED when validateToken reports suspension", async () => {
    jest.resetModules();

    jest.unstable_mockModule("../../services/api-backend/auth/auth-service.js", () => ({
      AuthService: jest.fn().mockImplementation(() => ({
        isDevBypassToken: () => false,
        validateToken: jest.fn().mockResolvedValue({
          valid: false,
          error: "Account is suspended",
          code: "ACCOUNT_SUSPENDED",
        }),
      })),
    }));

    const { authenticateJWT } = await import(
      "../../services/api-backend/middleware/auth.js"
    );

    const req = {
      headers: { authorization: "Bearer some.jwt.token" },
      path: "/api/test",
      ip: "127.0.0.1",
    };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };
    const next = jest.fn();

    await authenticateJWT(req, res, next);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ code: "ACCOUNT_SUSPENDED" }),
    );
    expect(next).not.toHaveBeenCalled();
  });
});
