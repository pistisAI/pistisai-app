import { jest } from "@jest/globals";
import express from "express";
import request from "supertest";

/**
 * Body-shape rejection for routes that previously only had params checks,
 * hand-rolled typeof guards, or non-Zod sanitizers.
 */
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
const shareTunnel = jest.fn().mockResolvedValue({ id: "s1" });
const createShareToken = jest.fn().mockResolvedValue({ id: "t1", token: "tok" });
const recordMetrics = jest.fn().mockResolvedValue({});
const updateTunnelConfig = jest.fn().mockResolvedValue({ maxConnections: 10 });
const updateUserProfile = jest.fn().mockResolvedValue({});
const updateUserPreferences = jest.fn().mockResolvedValue({});
const updateUserAvatar = jest.fn().mockResolvedValue({});
const setSlowQueryThreshold = jest.fn().mockReturnValue({
  slowQueryThreshold: 200,
});
const updateTemplate = jest.fn().mockResolvedValue({ id: "tmpl-1" });

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
  "../../services/api-backend/services/tunnel-sharing-service.js",
  () => ({
    TunnelSharingService: class {
      async initialize() {}
      shareTunnel = shareTunnel;
      createShareToken = createShareToken;
    },
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/tunnel-health-service.js",
  () => ({
    TunnelHealthService: class {
      async initialize() {}
      recordMetrics = recordMetrics;
    },
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/tunnel-service.js",
  () => ({
    TunnelService: class {
      async initialize() {}
      updateTunnelConfig = updateTunnelConfig;
    },
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/user-profile-service.js",
  () => ({
    UserProfileService: class {
      async initialize() {}
      updateUserProfile = updateUserProfile;
      updateUserPreferences = updateUserPreferences;
      updateUserAvatar = updateUserAvatar;
    },
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/database/query-performance-tracker.js",
  () => ({
    getPerformanceMetrics: jest.fn(),
    getSlowQueries: jest.fn(),
    getQueryStatsByType: jest.fn(),
    analyzePerformance: jest.fn(),
    setSlowQueryThreshold,
    resetPerformanceMetrics: jest.fn(),
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/email-config-service.js",
  () => ({
    default: class {
      updateTemplate = updateTemplate;
      saveTemplate = jest.fn();
    },
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/google-workspace-service.js",
  () => ({
    default: class {},
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/services/email-queue-service.js",
  () => ({
    default: class {},
  }),
);

const { default: sharingRouter, initializeTunnelSharingService } =
  await import("../../services/api-backend/routes/tunnel-sharing.js");
const {
  default: healthRouter,
  initializeTunnelHealthService,
} = await import("../../services/api-backend/routes/tunnel-health.js");
const { default: tunnelsRouter, initializeTunnelService } =
  await import("../../services/api-backend/routes/tunnels.js");
const {
  default: profileRouter,
  initializeUserProfileService,
} = await import("../../services/api-backend/routes/user-profile.js");
const { default: dbPerfRouter } =
  await import("../../services/api-backend/routes/database-performance.js");
const { default: emailRouter } =
  await import("../../services/api-backend/routes/admin/email.js");

await initializeTunnelSharingService();
await initializeTunnelHealthService();
await initializeTunnelService();
await initializeUserProfileService();

const TUNNEL = "123e4567-e89b-12d3-a456-426614174000";
const USER = "223e4567-e89b-12d3-a456-426614174000";
const TMPL = "323e4567-e89b-12d3-a456-426614174000";

const app = express();
app.use(express.json());
app.use("/share", sharingRouter);
app.use("/health", healthRouter);
app.use("/tunnels", tunnelsRouter);
app.use("/profile", profileRouter);
app.use("/db", dbPerfRouter);
app.use("/email", emailRouter);

beforeEach(() => {
  jest.clearAllMocks();
  mockQuery.mockReset();
  mockQuery.mockResolvedValue({
    rows: [
      {
        id: TMPL,
        name: "n",
        subject: "s",
        html_body: "<p>x</p>",
        text_body: null,
        description: null,
        variables: "[]",
        user_id: "admin-1",
      },
    ],
  });
});

describe("routes that were missing Zod body validation", () => {
  it.each([
    [
      "share: sharedWithUserId is a number",
      "post",
      `/share/${TUNNEL}/shares`,
      { sharedWithUserId: 7 },
    ],
    [
      "share: permission is a number",
      "post",
      `/share/${TUNNEL}/shares`,
      { sharedWithUserId: USER, permission: 5 },
    ],
    [
      "share-token: permission is a list",
      "post",
      `/share/${TUNNEL}/share-tokens`,
      { permission: ["read"] },
    ],
    [
      "share-token: expiresInHours is text",
      "post",
      `/share/${TUNNEL}/share-tokens`,
      { expiresInHours: "soon" },
    ],
    [
      "share-token: maxUses is text",
      "post",
      `/share/${TUNNEL}/share-tokens`,
      { maxUses: "many" },
    ],
    [
      "metrics: latency is text",
      "post",
      `/health/${TUNNEL}/metrics/record`,
      { latency: "fast", success: true },
    ],
    [
      "metrics: success is text",
      "post",
      `/health/${TUNNEL}/metrics/record`,
      { latency: 10, success: "yes" },
    ],
    [
      "tunnel config: maxConnections is text",
      "put",
      `/tunnels/${TUNNEL}/config`,
      { maxConnections: "10" },
    ],
    [
      "tunnel config: compression is text",
      "put",
      `/tunnels/${TUNNEL}/config`,
      { compression: "true" },
    ],
    [
      "profile: profile is a string",
      "put",
      "/profile/profile",
      { profile: "x" },
    ],
    [
      "preferences: theme is a number",
      "put",
      "/profile/preferences",
      { theme: 1 },
    ],
    ["avatar: avatarUrl is a number", "put", "/profile/avatar", { avatarUrl: 5 }],
    ["db threshold: thresholdMs is text", "post", "/db/threshold", { thresholdMs: "200" }],
    [
      "email template update: name is a number",
      "put",
      `/email/templates/${TMPL}`,
      { name: 5 },
    ],
    [
      "email template update: variables is text",
      "put",
      `/email/templates/${TMPL}`,
      { variables: "a" },
    ],
  ])("rejects: %s", async (_name, method, url, body) => {
    const res = await request(app)[method](url).send(body);

    expect(res.status).toBe(400);
    expect(res.body.error).toBe("Validation failed");
    expect(shareTunnel).not.toHaveBeenCalled();
    expect(createShareToken).not.toHaveBeenCalled();
    expect(recordMetrics).not.toHaveBeenCalled();
    expect(updateTunnelConfig).not.toHaveBeenCalled();
    expect(updateUserProfile).not.toHaveBeenCalled();
    expect(updateUserPreferences).not.toHaveBeenCalled();
    expect(updateUserAvatar).not.toHaveBeenCalled();
    expect(setSlowQueryThreshold).not.toHaveBeenCalled();
    expect(updateTemplate).not.toHaveBeenCalled();
  });
});
