/**
 * #893: suspended accounts and revoked sessions on WebSocket paths, and admin
 * audit entries written inside the admin transaction.
 */
import { describe, it, expect, beforeEach, jest } from "@jest/globals";

const mockValidateWs = jest.fn();
const mockPoolQuery = jest.fn();

jest.unstable_mockModule(
  "../../services/api-backend/middleware/auth.js",
  () => ({
    getAuthService: () => ({ validateTokenForWebSocket: mockValidateWs }),
  }),
);
jest.unstable_mockModule(
  "../../services/api-backend/database/db-pool.js",
  () => ({
    default: { query: mockPoolQuery },
    getPool: () => ({ query: mockPoolQuery }),
    closePool: jest.fn(),
  }),
);

const { AuthService } =
  await import("../../services/api-backend/auth/auth-service.js");
const { logAdminAction } =
  await import("../../services/api-backend/utils/audit-logger.js");
const dashboardWS = (
  await import("../../services/api-backend/websocket/dashboard-ws.js")
).default;

function fakeSocket() {
  return { write: jest.fn(), destroy: jest.fn() };
}

describe("AuthService.assertAccountUsable (#893)", () => {
  let auth;
  beforeEach(() => {
    auth = new AuthService({});
    auth.logger = { info: jest.fn(), warn: jest.fn(), error: jest.fn() };
    auth.logSecurityEvent = jest.fn(async () => {});
    auth.resolveUserId = jest.fn(async () => "user-1");
  });

  it("rejects a suspended account", async () => {
    auth.runQuery = jest.fn(async (sql) =>
      sql.includes("is_suspended") ? { is_suspended: true } : undefined,
    );
    await expect(auth.assertAccountUsable({ sub: "s" }, "t")).rejects.toThrow(
      /suspended/,
    );
  });

  it("rejects a revoked session", async () => {
    auth.runQuery = jest.fn(async (sql) =>
      sql.includes("is_suspended")
        ? { is_suspended: false }
        : { is_active: false },
    );
    await expect(auth.assertAccountUsable({ sub: "s" }, "t")).rejects.toThrow(
      /revoked/,
    );
  });

  it("accepts an active account", async () => {
    auth.runQuery = jest.fn(async (sql) =>
      sql.includes("is_suspended")
        ? { is_suspended: false }
        : { is_active: true },
    );
    await expect(
      auth.assertAccountUsable({ sub: "s" }, "t"),
    ).resolves.toBeUndefined();
  });
});

describe("dashboard WebSocket upgrade (#893)", () => {
  beforeEach(() => {
    mockValidateWs.mockReset();
    dashboardWS.logger = { error: jest.fn(), info: jest.fn() };
    dashboardWS.wss = { handleUpgrade: jest.fn(), emit: jest.fn() };
  });

  const request = (token) => ({
    url: `/ws/dashboard?token=${token}`,
    headers: { host: "api.example.com" },
  });

  it("refuses the upgrade when the Access check rejects the token", async () => {
    mockValidateWs.mockRejectedValueOnce(new Error("Account is suspended"));
    const socket = fakeSocket();
    await dashboardWS.handleUpgrade(request("t"), socket, Buffer.alloc(0));
    expect(socket.write).toHaveBeenCalledWith(expect.stringContaining("401"));
    expect(dashboardWS.wss.handleUpgrade).not.toHaveBeenCalled();
  });

  it("upgrades a verified token and uses its subject", async () => {
    mockValidateWs.mockResolvedValueOnce({ sub: "access-sub-1" });
    const req = request("t");
    await dashboardWS.handleUpgrade(req, fakeSocket(), Buffer.alloc(0));
    expect(dashboardWS.wss.handleUpgrade).toHaveBeenCalled();
    expect(req.userId).toBe("access-sub-1");
  });
});

describe("logAdminAction inside a transaction (#893)", () => {
  const entry = {
    adminUserId: "admin-1",
    adminRole: "super_admin",
    action: "user_suspended",
    resourceType: "user",
    resourceId: "user-2",
  };

  beforeEach(() => mockPoolQuery.mockReset());

  it("writes through the transaction client, not the pool", async () => {
    const client = { query: jest.fn(async () => ({ rows: [{ id: 1 }] })) };
    await logAdminAction({ ...entry, client });
    expect(client.query).toHaveBeenCalledTimes(1);
    expect(mockPoolQuery).not.toHaveBeenCalled();
  });

  it("rethrows inside a transaction so the caller rolls back", async () => {
    const client = {
      query: jest.fn(async () => {
        throw new Error("insert failed");
      }),
    };
    await expect(logAdminAction({ ...entry, client })).rejects.toThrow(
      "insert failed",
    );
  });

  it("outside a transaction a failure still does not throw", async () => {
    mockPoolQuery.mockRejectedValueOnce(new Error("insert failed"));
    await expect(logAdminAction(entry)).resolves.toBeNull();
  });
});
