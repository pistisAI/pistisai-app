import { jest } from "@jest/globals";
import express from "express";
import request from "supertest";

// Real routers; authentication, logging, rate limits, the database and the
// services behind each route are fakes.
const noop = (req, res, next) => next();
const asUser = (req, _res, next) => {
  req.user = { sub: "user-1" };
  req.userId = "user-1";
  req.tier = "free";
  next();
};
const log = {
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
};
const mockQuery = jest.fn();
const dnsService = {
  createRecord: jest.fn().mockResolvedValue({ id: "r1", record_type: "A" }),
  updateRecord: jest.fn().mockResolvedValue({ id: "r1", record_type: "A" }),
  getRecommendedGoogleWorkspaceRecords: jest.fn().mockReturnValue({
    mx: [],
    spf: { type: "TXT", name: "@", value: "v=spf1", ttl: 3600 },
    dmarc: { type: "TXT", name: "_dmarc", value: "v=DMARC1", ttl: 3600 },
  }),
};
const purge = jest.fn().mockResolvedValue({});
const scaling = { executeScaling: jest.fn().mockResolvedValue({ id: "e1" }) };

jest.unstable_mockModule("express-rate-limit", () => ({ default: () => noop }));
jest.unstable_mockModule("../../services/api-backend/logger.js", () => ({
  default: log,
}));
jest.unstable_mockModule("../../services/api-backend/utils/logger.js", () => ({
  TunnelLogger: class {
    info() {}
    warn() {}
    error() {}
    debug() {}
  },
  default: log,
}));
jest.unstable_mockModule(
  "../../services/api-backend/database/db-pool.js",
  () => ({
    default: { query: mockQuery },
    getPool: () => ({ query: mockQuery }),
    closePool: jest.fn(),
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/utils/audit-logger.js",
  () => ({
    logAdminAction: jest.fn().mockResolvedValue({}),
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/middleware/admin-auth.js",
  () => ({
    adminAuth: () => (req, _res, next) => {
      req.adminUser = { id: "admin-1", email: "admin@example.com" };
      req.adminRoles = ["super_admin"];
      next();
    },
    requireSuperAdmin: noop,
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/middleware/admin-rate-limiter.js",
  () => ({
    adminRateLimiter: noop,
    adminReadOnlyLimiter: noop,
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
jest.unstable_mockModule(
  "../../services/api-backend/middleware/infrastructure-auth.js",
  () => ({
    authenticateInfrastructure: asUser,
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/cloudflare-infrastructure-tunnel-service.js",
  () => ({ getInfrastructureTunnelService: () => ({ purgeCache: purge }) }),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/cloudflare-dns-service.js",
  () => ({
    default: class {
      constructor() {
        return dnsService;
      }
    },
  }),
);
const svc = (extra = {}) => ({
  default: class {
    constructor() {
      Object.assign(this, extra);
    }
  },
});
jest.unstable_mockModule(
  "../../services/api-backend/services/google-workspace-service.js",
  () => svc({ getOAuthConfiguration: jest.fn().mockResolvedValue(null) }),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/email-config-service.js",
  () => svc({ saveTemplate: jest.fn().mockResolvedValue({ id: "t1" }) }),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/email-queue-service.js",
  () => svc(),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/auth-audit-service.js",
  () => ({
    logLogout: jest.fn(),
    logTokenRevoke: jest.fn(),
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/tunnel-sharing-service.js",
  () => ({
    TunnelSharingService: class {},
  }),
);

const { default: dnsRouter } =
  await import("../../services/api-backend/routes/admin/dns.js");
const { default: emailRouter } =
  await import("../../services/api-backend/routes/admin/email.js");
const { default: authRouter } =
  await import("../../services/api-backend/routes/auth.js");
const { default: infraRouter } =
  await import("../../services/api-backend/routes/infrastructure-tunnel.js");
const { createProxyScalingRoutes } =
  await import("../../services/api-backend/routes/proxy-scaling.js");
const { default: sharingRouter } =
  await import("../../services/api-backend/routes/tunnel-sharing.js");
const { default: subagentRouter } =
  await import("../../services/api-backend/routes/subagent-registry-routes.js");

const app = express();
app.use(express.json());
app.use("/dns", dnsRouter);
app.use("/email", emailRouter);
app.use("/auth", authRouter);
app.use("/infra", infraRouter);
app.use("/scale", createProxyScalingRoutes(scaling));
app.use("/share", sharingRouter);
app.use("/sub", subagentRouter);

beforeEach(() => {
  jest.clearAllMocks();
  mockQuery.mockReset();
  mockQuery.mockResolvedValue({ rows: [{ id: "s1" }] });
});

const rejects = (title, rows) =>
  describe(title, () => {
    it.each(rows)("rejects: %s", async (_name, method, url, body) => {
      const res = await request(app)[method](url).send(body);

      expect(res.status).toBe(400);
      expect(dnsService.createRecord).not.toHaveBeenCalled();
      expect(dnsService.updateRecord).not.toHaveBeenCalled();
      expect(purge).not.toHaveBeenCalled();
      expect(scaling.executeScaling).not.toHaveBeenCalled();
      expect(mockQuery).not.toHaveBeenCalled();
    });
  });

const dns = { recordType: "CNAME", name: "www", value: "target.example.com" };
rejects("DNS", [
  ["ttl is text", "post", "/dns/records", { ...dns, ttl: "abc" }],
  ["ttl is a fraction", "post", "/dns/records", { ...dns, ttl: 60.5 }],
  ["name is an object", "post", "/dns/records", { ...dns, name: { a: 1 } }],
  ["value is a number", "post", "/dns/records", { ...dns, value: 7 }],
  [
    "record type is a list",
    "post",
    "/dns/records",
    { ...dns, recordType: ["A"] },
  ],
  ["update: ttl is text", "put", "/dns/records/r1", { ttl: "abc" }],
  ["update: value is a number", "put", "/dns/records/r1", { value: 5 }],
  [
    "setup: domain is an object",
    "post",
    "/dns/setup-google",
    { domain: { a: 1 } },
  ],
  [
    "setup: domain is not a host name",
    "post",
    "/dns/setup-google",
    { domain: "x.com; rm -rf /" },
  ],
  [
    "setup: record types is text",
    "post",
    "/dns/setup-google",
    { recordTypes: "mx" },
  ],
  [
    "setup: unknown record type",
    "post",
    "/dns/setup-google",
    { recordTypes: ["ns"] },
  ],
]);

rejects("email", [
  [
    "oauth: code is a number",
    "post",
    "/email/oauth/callback",
    { code: 5, state: "s" },
  ],
  [
    "oauth: state is a list",
    "post",
    "/email/oauth/callback",
    { code: "c", state: ["s"] },
  ],
  [
    "test: subject is an object",
    "post",
    "/email/test",
    { recipientEmail: "a@example.com", subject: { a: 1 } },
  ],
  ["test: recipient is a number", "post", "/email/test", { recipientEmail: 5 }],
  [
    "template: name is a number",
    "post",
    "/email/templates",
    { name: 5, subject: "s", html_body: "<p>x</p>" },
  ],
  [
    "template: html body is an object",
    "post",
    "/email/templates",
    { name: "n", subject: "s", html_body: { a: 1 } },
  ],
  [
    "template: variables is text",
    "post",
    "/email/templates",
    { name: "n", subject: "s", html_body: "<p>x</p>", variables: "a" },
  ],
]);

rejects("other routes", [
  [
    "token check: token is a number",
    "post",
    "/auth/token/check-expiry",
    { token: 5 },
  ],
  [
    "cache purge: urls is an empty text",
    "post",
    "/infra/cache/purge",
    { urls: "" },
  ],
  ["cache purge: urls is zero", "post", "/infra/cache/purge", { urls: 0 }],
  [
    "cache purge: urls holds numbers",
    "post",
    "/infra/cache/purge",
    { urls: [5] },
  ],
  [
    "cache purge: a non-http address",
    "post",
    "/infra/cache/purge",
    { urls: ["javascript:alert(1)"] },
  ],
  [
    "cache purge: more than 30 urls",
    "post",
    "/infra/cache/purge",
    { urls: Array(31).fill("https://example.com/a") },
  ],
  [
    "scaling: count is text",
    "post",
    "/scale/proxy/scaling/execute/p1",
    { newReplicaCount: "5" },
  ],
  [
    "scaling: count is a fraction",
    "post",
    "/scale/proxy/scaling/execute/p1",
    { newReplicaCount: 1.5 },
  ],
  [
    "scaling: count is negative",
    "post",
    "/scale/proxy/scaling/execute/p1",
    { newReplicaCount: -2 },
  ],
  [
    "scaling: count is huge",
    "post",
    "/scale/proxy/scaling/execute/p1",
    { newReplicaCount: 1e9 },
  ],
  [
    "scaling: reason is an object",
    "post",
    "/scale/proxy/scaling/execute/p1",
    { newReplicaCount: 2, reason: { a: 1 } },
  ],
  [
    "share: permission is a number",
    "put",
    "/share/t1/shares/s1/permission",
    { permission: 5 },
  ],
  ["subagent: label is a number", "patch", "/sub/a1/metadata", { label: 5 }],
  [
    "subagent: task is an object",
    "patch",
    "/sub/a1/metadata",
    { task: { a: 1 } },
  ],
]);

describe("valid bodies still reach the handlers", () => {
  it("creates a DNS record", async () => {
    await request(app)
      .post("/dns/records")
      .send({ ...dns, ttl: 300 });
    expect(dnsService.createRecord).toHaveBeenCalledTimes(1);
  });

  it("updates a DNS record", async () => {
    await request(app).put("/dns/records/r1").send({ ttl: 300 });
    expect(dnsService.updateRecord).toHaveBeenCalledTimes(1);
  });

  it("purges listed addresses, or everything when none are given", async () => {
    await request(app)
      .post("/infra/cache/purge")
      .send({ urls: ["https://example.com/a"] });
    await request(app).post("/infra/cache/purge").send({});
    expect(purge).toHaveBeenCalledTimes(2);
    expect(purge.mock.calls[1][0].urls).toBeUndefined();
  });

  it("scales a proxy", async () => {
    await request(app)
      .post("/scale/proxy/scaling/execute/p1")
      .send({ newReplicaCount: 3 });
    expect(scaling.executeScaling).toHaveBeenCalledTimes(1);
  });

  it("updates sub-agent metadata", async () => {
    const res = await request(app)
      .patch("/sub/a1/metadata")
      .send({ label: "x", task: "y" });
    expect(res.status).toBe(200);
    expect(mockQuery).toHaveBeenCalledTimes(1);
  });

  it("lets a text token through to the expiry check", async () => {
    const res = await request(app)
      .post("/auth/token/check-expiry")
      .send({ token: "not-a-jwt" });
    expect(res.status).toBe(401);
  });

  it("lets a permission text through (the service is not set up here: 503)", async () => {
    const res = await request(app)
      .put("/share/t1/shares/s1/permission")
      .send({ permission: "read" });
    expect(res.status).toBe(503);
  });
});
