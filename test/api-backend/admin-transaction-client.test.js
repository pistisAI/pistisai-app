/**
 * #847: Admin multi-step DB work must use a dedicated pool client so
 * BEGIN/COMMIT/ROLLBACK actually wrap the statements between them.
 */
import { describe, it, expect, beforeEach, jest } from "@jest/globals";

jest.unstable_mockModule("../../services/api-backend/utils/audit-logger.js", () => ({
  logAdminAction: jest.fn().mockResolvedValue({ id: "audit-1" }),
  // re-export nothing else needed
}));

jest.unstable_mockModule("../../services/api-backend/database/db-pool.js", () => ({
  getPool: jest.fn(),
  closePool: jest.fn(),
  initializePool: jest.fn(),
}));

const { bulkOperationsService } = await import(
  "../../services/api-backend/services/bulk-operations-service.js"
);

describe("Bulk operations transactions (#847)", () => {
  beforeEach(() => {
    bulkOperationsService.operations.clear();
  });

  it("_executeSuspend uses pool.connect() and runs BEGIN on that client", async () => {
    const clientQueries = [];
    const poolQueries = [];
    const mockClient = {
      query: jest.fn(async (sql, params) => {
        clientQueries.push({ sql, params });
        const normalized = String(sql).replace(/\s+/g, " ").trim();
        if (
          normalized === "BEGIN" ||
          normalized === "COMMIT" ||
          normalized === "ROLLBACK"
        ) {
          return { rows: [], rowCount: 0 };
        }
        if (normalized.includes("SELECT id, is_suspended")) {
          return { rows: [{ id: "user-1", is_suspended: false }], rowCount: 1 };
        }
        if (normalized.startsWith("UPDATE users")) {
          return { rows: [], rowCount: 1 };
        }
        if (normalized.startsWith("UPDATE user_sessions")) {
          return { rows: [], rowCount: 1 };
        }
        return { rows: [], rowCount: 0 };
      }),
      release: jest.fn(),
    };
    const pool = {
      connect: jest.fn().mockResolvedValue(mockClient),
      query: jest.fn(async (sql, params) => {
        poolQueries.push({ sql, params });
        return { rows: [], rowCount: 0 };
      }),
    };

    const operation = {
      id: "op-1",
      type: "suspend",
      processedUsers: 0,
      successCount: 0,
      failureCount: 0,
    };

    const results = await bulkOperationsService._executeSuspend(
      operation,
      ["user-1"],
      { reason: "abuse" },
      "admin-1",
      "super_admin",
      pool,
    );

    expect(results.successCount).toBe(1);
    expect(pool.connect).toHaveBeenCalled();
    expect(clientQueries.some((q) => String(q.sql).trim() === "BEGIN")).toBe(
      true,
    );
    expect(poolQueries.some((q) => String(q.sql).trim() === "BEGIN")).toBe(
      false,
    );
    expect(mockClient.release).toHaveBeenCalled();
  });
});
