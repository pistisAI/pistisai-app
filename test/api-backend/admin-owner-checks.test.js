/**
 * Admin and owner checks on session cleanup, the model catalogue, webhook
 * test events, rate-limit admin routes and the public database health check.
 *
 * The routers are the real ones. Token validation and the database are
 * mocked: the bearer token is used as the caller's user id, and only the
 * user id 'admin-1' has a server-side admin role (admin_roles).
 */

import { jest, describe, it, expect, beforeEach } from "@jest/globals";

const ADMIN = "admin-1";

const mockQuery = jest.fn(async (sql, params = []) => {
  if (/FROM users u\s+LEFT JOIN admin_roles/.test(sql)) {
    const sub = params[0];
    if (sub === ADMIN) {
      return {
        rows: [
          {
            id: "u-admin",
            email: "admin@example.com",
            jwt_id: sub,
            roles: ["super_admin"],
          },
        ],
      };
    }
    return {
      rows: [
        { id: `u-${sub}`, email: "user@example.com", jwt_id: sub, roles: null },
      ],
    };
  }
  if (/^\s*DELETE FROM user_sessions/.test(sql)) {
    return { rowCount: 2, rows: [] };
  }
  if (/INSERT INTO models/.test(sql)) {
    return { rows: [{ model_id: "m-1" }] };
  }
  return { rows: [], rowCount: 0 };
});

const mockPool = { query: mockQuery, connect: jest.fn() };

jest.unstable_mockModule(
  "../../services/api-backend/database/db-pool.js",
  () => ({
    default: mockPool,
    getPool: () => mockPool,
    closePool: jest.fn(async () => {}),
  }),
);

jest.unstable_mockModule(
  "../../services/api-backend/auth/auth-service.js",
  () => ({
    AuthService: class {
      async validateToken(token) {
        return { valid: true, payload: { sub: token } };
      }
    },
  }),
);

function bearerSub(req) {
  const header = req.headers.authorization || "";
  return header.startsWith("Bearer ") ? header.slice(7) : null;
}

jest.unstable_mockModule(
  "../../services/api-backend/middleware/auth.js",
  () => ({
    authenticateJWT: (req, res, next) => {
      const sub = bearerSub(req);
      if (!sub) {
        return res.status(401).json({ error: "No token" });
      }
      req.auth = { payload: { sub } };
      req.user = { sub };
      req.userId = sub;
      next();
    },
  }),
);

const request = (await import("supertest")).default;
const express = (await import("express")).default;
const sessionRoutes = (
  await import("../../services/api-backend/routes/sessions.js")
).default;
const modelsRoutes = (
  await import("../../services/api-backend/routes/models-routes.js")
).default;
const webhookTestingRoutes = (
  await import("../../services/api-backend/routes/webhook-testing.js")
).default;
const rateLimitViolationsRoutes = (
  await import("../../services/api-backend/routes/rate-limit-violations.js")
).default;
const rateLimitMetricsRoutes = (
  await import("../../services/api-backend/routes/rate-limit-metrics.js")
).default;
const { dbHealthHandler, setDbMigrator } =
  await import("../../services/api-backend/routes/db-health.js");
const { webhookTestingService } =
  await import("../../services/api-backend/services/webhook-testing-service.js");

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use("/auth/sessions", sessionRoutes);
  app.use("/admin/models", modelsRoutes);
  app.use("/webhook-testing", webhookTestingRoutes);
  app.use("/rate-limit-violations", rateLimitViolationsRoutes);
  app.use("/", rateLimitMetricsRoutes);
  app.use("/db/health", dbHealthHandler);
  return app;
}

// A route that never answers fails here instead of at the Jest timeout.
const RESPONSE_TIMEOUT_MS = 2000;

describe("admin and owner checks", () => {
  let app;

  beforeEach(() => {
    mockQuery.mockClear();
    webhookTestingService.clearTestEventCache();
    app = buildApp();
  });

  describe("POST /auth/sessions/cleanup", () => {
    it("rejects a signed-in user without an admin role", async () => {
      const res = await request(app)
        .post("/auth/sessions/cleanup")
        .set("Authorization", "Bearer user-a");
      expect(res.status).toBe(403);
      const deletes = mockQuery.mock.calls.filter(([sql]) =>
        /DELETE FROM user_sessions/.test(sql),
      );
      expect(deletes).toHaveLength(0);
    });

    it("lets an admin delete expired sessions and keeps revoked ones until they expire", async () => {
      const res = await request(app)
        .post("/auth/sessions/cleanup")
        .set("Authorization", `Bearer ${ADMIN}`);
      expect(res.status).toBe(200);
      const deletes = mockQuery.mock.calls.filter(([sql]) =>
        /DELETE FROM user_sessions/.test(sql),
      );
      expect(deletes).toHaveLength(1);
      const [sql] = deletes[0];
      expect(sql).toMatch(/expires_at < NOW\(\)/);
      expect(sql).not.toMatch(/is_active/);
    });
  });

  describe("/admin/models", () => {
    it("rejects POST from a user without an admin role", async () => {
      const res = await request(app)
        .post("/admin/models")
        .set("Authorization", "Bearer user-a")
        .send({ model_id: "m-1" });
      expect(res.status).toBe(403);
      expect(
        mockQuery.mock.calls.some(([sql]) => /INSERT INTO models/.test(sql)),
      ).toBe(false);
    });

    it("rejects GET from a user without an admin role", async () => {
      const res = await request(app)
        .get("/admin/models")
        .set("Authorization", "Bearer user-a");
      expect(res.status).toBe(403);
    });

    it("lets an admin write the catalogue", async () => {
      const res = await request(app)
        .post("/admin/models")
        .set("Authorization", `Bearer ${ADMIN}`)
        .send({ model_id: "m-1" });
      expect(res.status).toBe(200);
    });
  });

  describe("webhook test events", () => {
    async function sendAs(user) {
      const res = await request(app)
        .post("/webhook-testing/test/send")
        .set("Authorization", `Bearer ${user}`)
        .send({
          webhookUrl: "https://hooks.test.invalid/x",
          eventType: "user.activity",
        });
      expect(res.status).toBe(200);
      return res.body.testId;
    }

    it("lists only the caller's own events", async () => {
      const aId = await sendAs("user-a");
      const bId = await sendAs("user-b");

      const res = await request(app)
        .get("/webhook-testing/test/events")
        .set("Authorization", "Bearer user-b");
      expect(res.status).toBe(200);
      const ids = res.body.events.map((e) => e.testId);
      expect(ids).toEqual([bId]);
      expect(ids).not.toContain(aId);
    });

    it("does not return another user's event by id", async () => {
      const aId = await sendAs("user-a");
      const res = await request(app)
        .get(`/webhook-testing/test/events/${aId}`)
        .set("Authorization", "Bearer user-b");
      expect(res.status).toBe(404);
    });

    it("clears only the caller's own events", async () => {
      const aId = await sendAs("user-a");
      await sendAs("user-b");

      const del = await request(app)
        .delete("/webhook-testing/test/events")
        .set("Authorization", "Bearer user-b");
      expect(del.status).toBe(200);
      expect(del.body.cleared).toBe(1);

      const res = await request(app)
        .get("/webhook-testing/test/events")
        .set("Authorization", "Bearer user-a");
      expect(res.body.events.map((e) => e.testId)).toEqual([aId]);
    });
  });

  describe("rate-limit admin routes answer instead of hanging", () => {
    it("violations route: non-admin gets 403", async () => {
      const res = await request(app)
        .get("/rate-limit-violations/violations/user/user-a")
        .set("Authorization", "Bearer user-a")
        .timeout(RESPONSE_TIMEOUT_MS);
      expect(res.status).toBe(403);
    });

    it("violations route: admin passes the check", async () => {
      const res = await request(app)
        .get("/rate-limit-violations/violations/user/user-a")
        .set("Authorization", `Bearer ${ADMIN}`)
        .timeout(RESPONSE_TIMEOUT_MS);
      expect([401, 403]).not.toContain(res.status);
    });

    it("metrics route: non-admin gets 403 and admin gets 200", async () => {
      const denied = await request(app)
        .get("/rate-limit-metrics/top-violators")
        .set("Authorization", "Bearer user-a")
        .timeout(RESPONSE_TIMEOUT_MS);
      expect(denied.status).toBe(403);

      const allowed = await request(app)
        .get("/rate-limit-metrics/top-violators")
        .set("Authorization", `Bearer ${ADMIN}`)
        .timeout(RESPONSE_TIMEOUT_MS);
      expect(allowed.status).toBe(200);
    });
  });

  describe("GET /db/health", () => {
    it("returns only a status and a timestamp", async () => {
      setDbMigrator({
        validateSchema: async () => ({
          allValid: false,
          results: { users: { valid: false } },
        }),
      });
      const res = await request(app).get("/db/health");
      expect(res.status).toBe(200);
      expect(res.body.status).toBe("degraded");
      expect(Object.keys(res.body).sort()).toEqual(["status", "timestamp"]);
    });

    it("does not return the error message", async () => {
      setDbMigrator({
        validateSchema: async () => {
          throw new Error('relation "users" does not exist');
        },
      });
      const res = await request(app).get("/db/health");
      expect(res.status).toBe(503);
      expect(Object.keys(res.body).sort()).toEqual(["status", "timestamp"]);
      expect(JSON.stringify(res.body)).not.toContain("relation");
    });
  });
});
