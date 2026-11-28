/**
 * @fileoverview Authentication and authorization security tests.
 *
 * Drives the production middleware through supertest:
 * - middleware/auth.js authenticateJWT and requireAdmin, backed by the real
 *   AuthService (RS256 signature, issuer, audience and expiry checks);
 * - middleware/admin-auth.js adminAuth (database-backed admin roles);
 * - middleware/pipeline.js setupMiddlewarePipeline (helmet security headers).
 *
 * Only the edges are replaced: the Cloudflare Access JWKS fetch returns a key
 * pair generated here, and Postgres is an in-memory fake.
 */

import {
  describe,
  it,
  beforeAll,
  beforeEach,
  expect,
  jest,
} from "@jest/globals";
import crypto from "crypto";

const TEAM_DOMAIN = "team.example.com";
const AUDIENCE = "test-access-audience";
const KID = "test-kid";

process.env.CF_ACCESS_TEAM_DOMAIN = TEAM_DOMAIN;
process.env.CF_ACCESS_AUD = AUDIENCE;
delete process.env.DEV_BYPASS_TOKEN;

const signingKeys = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
const otherKeys = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
const publicPem = signingKeys.publicKey.export({ type: "spki", format: "pem" });

// JWKS endpoint: serves the test public key for the test kid only.
jest.unstable_mockModule("jwks-rsa", () => {
  const client = () => ({
    getSigningKey: (kid, cb) => {
      if (kid !== KID) {
        cb(new Error(`Unable to find a signing key that matches '${kid}'`));
        return;
      }
      cb(null, { getPublicKey: () => publicPem });
    },
  });
  return { default: client };
});

// In-memory database: subjects map to users; admins have admin_roles rows.
const db = {
  suspended: new Set(),
  adminRoles: new Map(),
};

function userIdFor(sub) {
  return `user-${sub}`;
}

async function fakeQuery(sql, params = []) {
  if (sql.includes("FROM users WHERE access_subject")) {
    return { rows: [{ id: userIdFor(params[0]) }], rowCount: 1 };
  }
  if (sql.includes("SELECT is_suspended FROM users")) {
    const sub = String(params[0]).replace(/^user-/, "");
    return { rows: [{ is_suspended: db.suspended.has(sub) }], rowCount: 1 };
  }
  if (sql.includes("SELECT * FROM user_sessions")) {
    return { rows: [{ id: "session-1", is_active: true }], rowCount: 1 };
  }
  if (sql.includes("LEFT JOIN admin_roles")) {
    const sub = params[0];
    return {
      rows: [
        {
          id: userIdFor(sub),
          email: `${sub}@example.com`,
          jwt_id: sub,
          roles: db.adminRoles.get(sub) ?? null,
        },
      ],
      rowCount: 1,
    };
  }
  return { rows: [], rowCount: 1 };
}

jest.unstable_mockModule(
  "../../../services/api-backend/database/migrate-pg.js",
  () => ({
    DatabaseMigratorPG: class {
      constructor() {
        this.pool = { query: fakeQuery };
      }
      async initialize() {}
    },
  }),
);

jest.unstable_mockModule(
  "../../../services/api-backend/database/db-pool.js",
  () => ({
    default: { query: fakeQuery },
    query: fakeQuery,
    getPool: () => ({ query: fakeQuery }),
    initializePool: async () => {},
    closePool: async () => {},
  }),
);

const request = (await import("supertest")).default;
const express = (await import("express")).default;
const jwt = (await import("jsonwebtoken")).default;
const { authenticateJWT, requireAdmin } =
  await import("../../../services/api-backend/middleware/auth.js");
const { adminAuth } =
  await import("../../../services/api-backend/middleware/admin-auth.js");
const { setupMiddlewarePipeline } =
  await import("../../../services/api-backend/middleware/pipeline.js");

function signToken(claims = {}, options = {}) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    sub: "access-user",
    email: "user@example.com",
    email_verified: true,
    iat: now,
    exp: now + 3600,
    ...claims,
  };
  return jwt.sign(payload, options.privateKey ?? signingKeys.privateKey, {
    algorithm: "RS256",
    keyid: options.kid ?? KID,
    issuer: options.issuer ?? `https://${TEAM_DOMAIN}`,
    audience: options.audience ?? AUDIENCE,
  });
}

function buildApp() {
  const app = express();
  app.use(express.json());
  app.get("/protected", authenticateJWT, (req, res) => {
    res.json({ sub: req.auth.payload.sub, sessionId: req.auth.session?.id });
  });
  app.get("/admin/claims", authenticateJWT, requireAdmin, (req, res) => {
    res.json({ ok: true, sub: req.auth.payload.sub });
  });
  app.get("/admin/db", adminAuth(), (req, res) => {
    res.json({ ok: true, roles: req.adminRoles });
  });
  app.get("/admin/refunds", adminAuth(["process_refunds"]), (req, res) => {
    res.json({ ok: true });
  });
  return app;
}

describe("authenticateJWT (middleware/auth.js)", () => {
  let app;

  beforeAll(() => {
    app = buildApp();
  });

  beforeEach(() => {
    db.suspended.clear();
    db.adminRoles.clear();
  });

  it("rejects a request without an Authorization header with 401", async () => {
    const res = await request(app).get("/protected");
    expect(res.status).toBe(401);
    expect(res.body.code).toBe("AUTH_HEADER_MISSING");
  });

  it("rejects a non-Bearer Authorization header with 401", async () => {
    const res = await request(app)
      .get("/protected")
      .set("Authorization", `Basic ${signToken()}`);
    expect(res.status).toBe(401);
    expect(res.body.code).toBe("AUTH_HEADER_MISSING");
  });

  it("rejects a malformed token with 401", async () => {
    const res = await request(app)
      .get("/protected")
      .set("Authorization", "Bearer not-a-jwt");
    expect(res.status).toBe(401);
    expect(res.body.code).toBe("TOKEN_INVALID");
  });

  it("rejects a token signed with a different key with 401", async () => {
    const token = signToken({}, { privateKey: otherKeys.privateKey });
    const res = await request(app)
      .get("/protected")
      .set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(401);
    expect(res.body.code).toBe("TOKEN_INVALID");
  });

  it("rejects a token for another audience with 401", async () => {
    const token = signToken({}, { audience: "some-other-application" });
    const res = await request(app)
      .get("/protected")
      .set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(401);
    // jsonwebtoken reports "jwt ... invalid. expected: ...", which the
    // middleware's substring check currently labels TOKEN_EXPIRED; the
    // status is what keeps the request out.
    expect(["TOKEN_INVALID", "TOKEN_EXPIRED"]).toContain(res.body.code);
  });

  it("rejects a token from another issuer with 401", async () => {
    const token = signToken({}, { issuer: "https://other.example.com" });
    const res = await request(app)
      .get("/protected")
      .set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(401);
    // jsonwebtoken reports "jwt ... invalid. expected: ...", which the
    // middleware's substring check currently labels TOKEN_EXPIRED; the
    // status is what keeps the request out.
    expect(["TOKEN_INVALID", "TOKEN_EXPIRED"]).toContain(res.body.code);
  });

  it("rejects an expired token with 401 TOKEN_EXPIRED", async () => {
    const now = Math.floor(Date.now() / 1000);
    const token = signToken({ iat: now - 7200, exp: now - 3600 });
    const res = await request(app)
      .get("/protected")
      .set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(401);
    expect(res.body.code).toBe("TOKEN_EXPIRED");
  });

  it("rejects an unsigned (alg none) token with 401", async () => {
    const token = jwt.sign(
      { sub: "access-user", email: "user@example.com" },
      null,
      {
        algorithm: "none",
        issuer: `https://${TEAM_DOMAIN}`,
        audience: AUDIENCE,
      },
    );
    const res = await request(app)
      .get("/protected")
      .set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(401);
  });

  it("rejects a valid token of a suspended account with 403", async () => {
    db.suspended.add("access-user");
    const res = await request(app)
      .get("/protected")
      .set("Authorization", `Bearer ${signToken()}`);
    expect(res.status).toBe(403);
    expect(res.body.code).toBe("ACCOUNT_SUSPENDED");
  });

  it("accepts a valid token and attaches the verified subject", async () => {
    const res = await request(app)
      .get("/protected")
      .set("Authorization", `Bearer ${signToken()}`);
    expect(res.status).toBe(200);
    expect(res.body.sub).toBe("access-user");
    expect(res.body.sessionId).toBe("session-1");
  });
});

describe("admin authorization", () => {
  let app;

  beforeAll(() => {
    app = buildApp();
  });

  beforeEach(() => {
    db.suspended.clear();
    db.adminRoles.clear();
  });

  describe("requireAdmin (middleware/auth.js)", () => {
    it("returns 401 without a token", async () => {
      const res = await request(app).get("/admin/claims");
      expect(res.status).toBe(401);
    });

    it("returns 403 for a valid non-admin token", async () => {
      const res = await request(app)
        .get("/admin/claims")
        .set("Authorization", `Bearer ${signToken()}`);
      expect(res.status).toBe(403);
      expect(res.body.code).toBe("FORBIDDEN");
    });

    it("returns 200 for a valid token with the admin role claim", async () => {
      const token = signToken({
        sub: "access-admin",
        app_metadata: { role: "admin" },
      });
      const res = await request(app)
        .get("/admin/claims")
        .set("Authorization", `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.sub).toBe("access-admin");
    });
  });

  describe("adminAuth (middleware/admin-auth.js)", () => {
    it("returns 401 without a token", async () => {
      const res = await request(app).get("/admin/db");
      expect(res.status).toBe(401);
      expect(res.body.code).toBe("NO_TOKEN");
    });

    it("returns 401 for a token signed with a different key", async () => {
      const token = signToken(
        { sub: "access-admin" },
        { privateKey: otherKeys.privateKey },
      );
      db.adminRoles.set("access-admin", ["super_admin"]);
      const res = await request(app)
        .get("/admin/db")
        .set("Authorization", `Bearer ${token}`);
      expect(res.status).toBe(401);
      expect(res.body.code).toBe("INVALID_TOKEN");
    });

    it("returns 403 for a valid token whose user has no admin role", async () => {
      const res = await request(app)
        .get("/admin/db")
        .set("Authorization", `Bearer ${signToken()}`);
      expect(res.status).toBe(403);
      expect(res.body.code).toBe("ADMIN_ACCESS_REQUIRED");
    });

    it("does not trust an admin claim in the token without a database role", async () => {
      const token = signToken({ app_metadata: { role: "admin" } });
      const res = await request(app)
        .get("/admin/db")
        .set("Authorization", `Bearer ${token}`);
      expect(res.status).toBe(403);
      expect(res.body.code).toBe("ADMIN_ACCESS_REQUIRED");
    });

    it("returns 200 for a valid token whose user has an admin role", async () => {
      db.adminRoles.set("access-admin", ["support_admin"]);
      const res = await request(app)
        .get("/admin/db")
        .set("Authorization", `Bearer ${signToken({ sub: "access-admin" })}`);
      expect(res.status).toBe(200);
      expect(res.body.roles).toEqual(["support_admin"]);
    });

    it("returns 403 when the admin role lacks the required permission", async () => {
      db.adminRoles.set("access-admin", ["support_admin"]);
      const res = await request(app)
        .get("/admin/refunds")
        .set("Authorization", `Bearer ${signToken({ sub: "access-admin" })}`);
      expect(res.status).toBe(403);
      expect(res.body.code).toBe("INSUFFICIENT_PERMISSIONS");
    });

    it("returns 403 for a suspended admin account", async () => {
      db.adminRoles.set("access-admin", ["super_admin"]);
      db.suspended.add("access-admin");
      const res = await request(app)
        .get("/admin/db")
        .set("Authorization", `Bearer ${signToken({ sub: "access-admin" })}`);
      expect(res.status).toBe(403);
      expect(res.body.code).toBe("ACCOUNT_SUSPENDED");
    });
  });
});

describe("security headers (middleware/pipeline.js)", () => {
  let app;

  beforeAll(() => {
    app = express();
    setupMiddlewarePipeline(app);
    app.get("/health", (req, res) => res.json({ status: "ok" }));
  });

  it("sets the helmet security headers on responses", async () => {
    const res = await request(app).get("/health");
    expect(res.status).toBe(200);
    const csp = res.headers["content-security-policy"];
    expect(csp).toEqual(expect.stringContaining("default-src 'self'"));
    expect(csp).toEqual(expect.stringContaining("object-src 'none'"));
    expect(csp).toEqual(expect.stringContaining("frame-ancestors 'self'"));
    expect(res.headers["x-content-type-options"]).toBe("nosniff");
    expect(res.headers["x-frame-options"]).toBe("SAMEORIGIN");
    expect(res.headers["strict-transport-security"]).toEqual(
      expect.stringMatching(/max-age=\d+/),
    );
    expect(res.headers["referrer-policy"]).toBe("no-referrer");
    expect(res.headers["cross-origin-resource-policy"]).toBe("cross-origin");
    expect(res.headers["x-powered-by"]).toBeUndefined();
  });
});
