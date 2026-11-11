import { jest } from "@jest/globals";
import express from "express";
import request from "supertest";

// Real routers; database, auth, logging and the services behind them are fakes.
const mockQuery = jest.fn();
const mockCreateBulk = jest.fn();
const noop = (req, res, next) => next();
const log = { info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() };

jest.unstable_mockModule("../../services/api-backend/logger.js", () => ({ default: log }));
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
jest.unstable_mockModule("../../services/api-backend/services/bulk-operations-service.js", () => ({
  bulkOperationsService: { createBulkOperation: mockCreateBulk },
}));
jest.unstable_mockModule("../../services/api-backend/services/refund-service.js", () => ({
  default: class RefundService {},
}));

const { default: bulkRouter } = await import("../../services/api-backend/routes/admin/bulk-operations.js");
const { default: paymentsRouter } = await import("../../services/api-backend/routes/admin/payments.js");
const { default: subsRouter } = await import("../../services/api-backend/routes/admin/subscriptions.js");

const app = express();
app.use(express.json());
app.use((req, _res, next) => {
  req.db = { query: mockQuery };
  next();
});
app.use("/bulk", bulkRouter);
app.use("/payments", paymentsRouter);
app.use("/subs", subsRouter);

const ID = "123e4567-e89b-12d3-a456-426614174000";

beforeEach(() => {
  mockQuery.mockReset();
  mockQuery.mockResolvedValue({ rows: [] });
  mockCreateBulk.mockReset();
  mockCreateBulk.mockResolvedValue({ operationId: "op", totalUsers: 1 });
});

describe("bulk operations: the body must have the right shape", () => {
  const bad = [
    ["user ids are numbers", { operationType: "suspend", userIds: [1, 2], operationData: { reason: "x" } }],
    ["user ids contain an object", { operationType: "suspend", userIds: [ID, {}], operationData: { reason: "x" } }],
    ["user ids are not UUIDs", { operationType: "suspend", userIds: ["a; DROP TABLE users"], operationData: { reason: "x" } }],
    ["more than 1000 user ids", { operationType: "suspend", userIds: Array(1001).fill(ID), operationData: { reason: "x" } }],
    ["operation data is a string", { operationType: "suspend", userIds: [ID], operationData: "x" }],
    ["operation type is a list", { operationType: ["suspend"], userIds: [ID], operationData: { reason: "x" } }],
  ];

  it.each(bad)("rejects: %s", async (_n, body) => {
    const res = await request(app).post("/bulk/create").send(body);

    expect(res.status).toBe(400);
    expect(mockCreateBulk).not.toHaveBeenCalled();
  });

  it("passes a valid request to the service", async () => {
    const res = await request(app)
      .post("/bulk/create")
      .send({ operationType: "suspend", userIds: [ID], operationData: { reason: "abuse" } });

    expect(res.status).toBe(201);
    expect(mockCreateBulk).toHaveBeenCalledTimes(1);
  });
});

describe("refunds: the body must have the right shape", () => {
  const ok = { transactionId: ID, reason: "duplicate" };
  const bad = [
    ["amount with trailing text", { ...ok, amount: "12abc" }],
    ["amount is a list", { ...ok, amount: [5] }],
    ["amount is an object", { ...ok, amount: { v: 5 } }],
    ["transaction id is a number", { ...ok, transactionId: 7 }],
    ["reason is a list", { ...ok, reason: ["duplicate"] }],
    ["reason details is an object", { ...ok, reasonDetails: { a: 1 } }],
  ];

  it.each(bad)("rejects: %s", async (_n, body) => {
    const res = await request(app).post("/payments/refunds").send(body);

    expect(res.status).toBe(400);
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it("accepts a number or a plain numeric string as the amount", async () => {
    await request(app).post("/payments/refunds").send({ ...ok, amount: 12.5 });
    await request(app).post("/payments/refunds").send({ ...ok, amount: "12.50" });

    expect(mockQuery).toHaveBeenCalled();
  });
});

describe("subscriptions: the body must have the right shape", () => {
  it('does not read the text "false" as an immediate cancellation', async () => {
    const res = await request(app)
      .post(`/subs/subscriptions/${ID}/cancel`)
      .send({ immediate: "false", reason: "customer asked" });

    expect(res.status).toBe(400);
    expect(mockQuery).not.toHaveBeenCalled();
  });

  const bad = [
    ["cancel: reason is a number", "post", `/subs/subscriptions/${ID}/cancel`, { reason: 5 }],
    ["cancel: reason missing", "post", `/subs/subscriptions/${ID}/cancel`, {}],
    ["change: tier is a list", "patch", `/subs/subscriptions/${ID}`, { tier: ["premium"], priceId: "price_1" }],
    ["change: price id is a number", "patch", `/subs/subscriptions/${ID}`, { tier: "premium", priceId: 3 }],
    ["change: unknown proration", "patch", `/subs/subscriptions/${ID}`, { tier: "premium", priceId: "price_1", prorationBehavior: "whatever" }],
  ];

  it.each(bad)("rejects: %s", async (_n, method, url, body) => {
    const res = await request(app)[method](url).send(body);

    expect(res.status).toBe(400);
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it("still takes a valid cancellation through to the database", async () => {
    await request(app)
      .post(`/subs/subscriptions/${ID}/cancel`)
      .send({ immediate: true, reason: "customer asked" });

    expect(mockQuery).toHaveBeenCalled();
  });
});
