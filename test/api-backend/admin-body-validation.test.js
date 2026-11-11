import { jest } from "@jest/globals";
import express from "express";
import request from "supertest";

// Real routers, with only the outside world faked: database, auth, logging.
const mockQuery = jest.fn();
const noop = (req, res, next) => next();
const log = { info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() };

jest.unstable_mockModule("../../services/api-backend/logger.js", () => ({
  default: log,
}));
jest.unstable_mockModule("../../services/api-backend/database/db-pool.js", () => ({
  getPool: () => ({ query: mockQuery }),
  closePool: jest.fn(),
}));
jest.unstable_mockModule("../../services/api-backend/utils/audit-logger.js", () => ({
  logAdminAction: jest.fn().mockResolvedValue({}),
}));
jest.unstable_mockModule("../../services/api-backend/middleware/admin-auth.js", () => ({
  adminAuth: () => (req, res, next) => {
    req.adminUser = { id: "admin-1", email: "admin@example.com", role: "super_admin" };
    next();
  },
  requireSuperAdmin: noop,
}));
jest.unstable_mockModule(
  "../../services/api-backend/middleware/admin-rate-limiter.js",
  () => ({ adminRateLimiter: noop, adminReadOnlyLimiter: noop }),
);

const { default: usersRouter } = await import(
  "../../services/api-backend/routes/admin/users.js"
);
const { default: adminsRouter } = await import(
  "../../services/api-backend/routes/admin/admins.js"
);

const app = express();
app.use(express.json());
app.use("/users", usersRouter);
app.use("/admins", adminsRouter);

const USER = "123e4567-e89b-12d3-a456-426614174000";

beforeEach(() => {
  mockQuery.mockReset();
  mockQuery.mockResolvedValue({ rows: [] });
});

describe("admin routes reject malformed bodies with 400, never 500", () => {
  const bad = [
    ["PATCH tier: tier is a number", "patch", `/users/${USER}`, { subscriptionTier: 5 }],
    ["PATCH tier: tier missing", "patch", `/users/${USER}`, { reason: "x" }],
    ["PATCH tier: tier is an object", "patch", `/users/${USER}`, { subscriptionTier: { a: 1 } }],
    ["suspend: reason is a number", "post", `/users/${USER}/suspend`, { reason: 42 }],
    ["suspend: reason is a list", "post", `/users/${USER}/suspend`, { reason: ["a"] }],
    ["reactivate: note is an object", "post", `/users/${USER}/reactivate`, { note: { a: 1 } }],
    ["add admin: email is a number", "post", "/admins", { email: 123, role: "support_admin" }],
    ["add admin: email is not an email", "post", "/admins", { email: "nope", role: "support_admin" }],
    ["add admin: role is a list", "post", "/admins", { email: "a@example.com", role: ["support_admin"] }],
  ];

  it.each(bad)("%s", async (_name, method, url, body) => {
    const res = await request(app)[method](url).send(body);

    expect(res.status).toBe(400);
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it("still accepts a valid tier change request through to the database", async () => {
    await request(app).patch(`/users/${USER}`).send({ subscriptionTier: "premium" });

    expect(mockQuery).toHaveBeenCalled();
  });
});
