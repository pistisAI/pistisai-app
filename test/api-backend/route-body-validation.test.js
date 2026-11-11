import { jest } from "@jest/globals";
import express from "express";
import request from "supertest";

// Real routers and handler; authentication, logging and the services behind
// them are fakes.
const log = {
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
};
const asUser = (req, _res, next) => {
  req.user = { sub: "user-1" };
  req.userId = "user-1";
  req.tier = "free";
  next();
};

// The rate limiters are not what is under test; many requests are sent here.
jest.unstable_mockModule("express-rate-limit", () => ({
  default: () => (_req, _res, next) => next(),
}));
jest.unstable_mockModule("../../services/api-backend/logger.js", () => ({
  default: log,
}));
jest.unstable_mockModule(
  "../../services/api-backend/middleware/composite-auth.js",
  () => ({
    authenticateComposite: [asUser],
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/middleware/auth.js",
  () => ({
    authenticateJWT: asUser,
    authenticateToken: asUser,
    checkJwt: asUser,
    optionalAuth: asUser,
    extractUserId: asUser,
    requireAdmin: asUser,
    syncSession: asUser,
    getAuthService: () => ({}),
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/middleware/tier-check.js",
  () => ({
    addTierInfo: asUser,
    requireTier: () => asUser,
    requireFeature: () => asUser,
    getUserTier: () => "free",
    shouldUseDirectTunnel: () => false,
    getTierFeatures: () => ({}),
    hasFeature: () => true,
    getUpgradeMessage: () => "",
    USER_TIERS: {},
    TIER_FEATURES: {},
    default: {},
  }),
);

const { default: bridgeRouter } =
  await import("../../services/api-backend/routes/bridge-polling-routes.js");
const { createProxyMetricsRoutes } =
  await import("../../services/api-backend/routes/proxy-metrics.js");
const { createProxyUsageRoutes } =
  await import("../../services/api-backend/routes/proxy-usage.js");
const { proxyProvisionHandler } =
  await import("../../services/api-backend/routes/proxy.js");

const metricsService = { recordMetricsEvent: jest.fn().mockResolvedValue({}) };
const usageService = {
  recordUsageEvent: jest.fn().mockResolvedValue({}),
  aggregateUserUsage: jest.fn().mockResolvedValue({}),
};

const app = express();
app.use(express.json());
app.use("/bridge", bridgeRouter);
app.use("/pm", createProxyMetricsRoutes(metricsService));
app.use("/pu", createProxyUsageRoutes(usageService));
app.post("/provision", asUser, proxyProvisionHandler);

beforeEach(() => {
  jest.clearAllMocks();
});

describe("bridge routes: the body must have the right shape", () => {
  const good = { clientId: "c-1", platform: "windows", version: "1.0.0" };

  it.each([
    ["client id is a number", { ...good, clientId: 7 }],
    ["platform is an object", { ...good, platform: { a: 1 } }],
    ["version is a list", { ...good, version: ["1"] }],
    ["capabilities is a string", { ...good, capabilities: "llm" }],
    ["capabilities holds objects", { ...good, capabilities: [{ a: 1 }] }],
    [
      "capabilities is far too long",
      { ...good, capabilities: Array(500).fill("x") },
    ],
    ["client id is huge", { ...good, clientId: "x".repeat(5000) }],
  ])("register rejects: %s", async (_n, body) => {
    const res = await request(app).post("/bridge/register").send(body);

    expect(res.status).toBe(400);
  });

  it("register still accepts a valid body", async () => {
    const res = await request(app)
      .post("/bridge/register")
      .send({ ...good, capabilities: ["llm-proxy"] });

    expect(res.status).toBe(200);
  });

  describe("with a registered bridge", () => {
    let bridgeId;
    beforeAll(async () => {
      const res = await request(app).post("/bridge/register").send(good);
      bridgeId = res.body.bridgeId;
    });

    it.each([
      ["providers is a string", { providers: "ollama" }],
      ["providers is an object", { providers: { a: 1 } }],
      ["timestamp is a list", { providers: [], timestamp: [1] }],
    ])("provider-status rejects: %s", async (_n, body) => {
      const res = await request(app)
        .post(`/bridge/${bridgeId}/provider-status`)
        .send(body);

      expect(res.status).toBe(400);
    });

    it.each([
      ["request id is a number", { requestId: 5, status: 200 }],
      ["status is text", { requestId: "r1", status: "ok" }],
      ["status is out of range", { requestId: "r1", status: 99999 }],
      ["headers is a string", { requestId: "r1", status: 200, headers: "x" }],
      ["error is an object", { requestId: "r1", error: { a: 1 } }],
    ])("response rejects: %s", async (_n, body) => {
      const res = await request(app)
        .post(`/bridge/${bridgeId}/response`)
        .send(body);

      expect(res.status).toBe(400);
    });

    it("response still accepts a valid body", async () => {
      const res = await request(app)
        .post(`/bridge/${bridgeId}/response`)
        .send({
          requestId: "r1",
          status: 200,
          headers: { "x-a": "b" },
          body: "hello",
        });

      expect(res.status).toBe(200);
    });
  });
});

describe("proxy metrics and usage: the body must have the right shape", () => {
  it.each([
    [
      "metrics: event type is a number",
      "/pm/metrics/p1/record",
      { eventType: 5 },
    ],
    [
      "metrics: metrics is a string",
      "/pm/metrics/p1/record",
      { eventType: "x", metrics: "s" },
    ],
    [
      "usage: event type is a list",
      "/pu/usage/p1/record",
      { eventType: ["x"] },
    ],
    [
      "usage: event data is a string",
      "/pu/usage/p1/record",
      { eventType: "x", eventData: "s" },
    ],
    [
      "aggregate: dates are objects",
      "/pu/usage/aggregate",
      { periodStart: {}, periodEnd: {} },
    ],
    [
      "aggregate: dates are not dates",
      "/pu/usage/aggregate",
      { periodStart: "soon", periodEnd: "later" },
    ],
  ])("rejects: %s", async (_n, url, body) => {
    const res = await request(app).post(url).send(body);

    expect(res.status).toBe(400);
    expect(metricsService.recordMetricsEvent).not.toHaveBeenCalled();
    expect(usageService.recordUsageEvent).not.toHaveBeenCalled();
    expect(usageService.aggregateUserUsage).not.toHaveBeenCalled();
  });

  it("still passes valid bodies to the services", async () => {
    await request(app)
      .post("/pm/metrics/p1/record")
      .send({ eventType: "latency", metrics: { ms: 5 } });
    await request(app)
      .post("/pu/usage/p1/record")
      .send({ eventType: "request", eventData: { n: 1 } });
    await request(app)
      .post("/pu/usage/aggregate")
      .send({
        periodStart: "2026-11-01T00:00:00Z",
        periodEnd: "2026-11-30T00:00:00Z",
      });

    expect(metricsService.recordMetricsEvent).toHaveBeenCalledTimes(1);
    expect(usageService.recordUsageEvent).toHaveBeenCalledTimes(1);
    expect(usageService.aggregateUserUsage).toHaveBeenCalledTimes(1);
  });
});

describe("proxy provisioning: the body must have the right shape", () => {
  it('does not read the text "false" as test mode', async () => {
    const res = await request(app)
      .post("/provision")
      .send({ testMode: "false" });

    expect(res.status).toBe(400);
  });

  it("does not crash on a missing body (it goes on to real provisioning)", async () => {
    const res = await request(app).post("/provision");

    // Real provisioning needs a cluster and fails here, but not with a
    // TypeError from reading properties of an undefined body.
    // The default Express error page carries the TypeError text; a JSON reply
    // would carry it in the body.
    expect(`${res.text} ${JSON.stringify(res.body)}`).not.toMatch(
      /Cannot destructure|Cannot read properties/,
    );
  });

  it("accepts test mode as a real boolean", async () => {
    const res = await request(app).post("/provision").send({ testMode: true });

    expect(res.status).toBeLessThan(500);
    expect(res.status).not.toBe(400);
  });
});
