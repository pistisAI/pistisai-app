/**
 * Account hard delete must remove (or pseudonymize) the user's rows in every
 * table that references a user without ON DELETE CASCADE.
 */
import { describe, expect, it, beforeEach } from "@jest/globals";
import path from "path";
import { fileURLToPath } from "url";
import { readFileSync, readdirSync } from "fs";

import {
  USER_DATA_DELETE_TABLES,
  USER_DATA_PSEUDONYMIZE_TABLES,
  collectUserIdentifiers,
  purgeUserData,
} from "../../services/api-backend/services/user-data-purge.js";
import { bulkOperationsService } from "../../services/api-backend/services/bulk-operations-service.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DB_DIR = path.join(__dirname, "../../services/api-backend/database");

const USER_ID = "11111111-2222-3333-4444-555555555555";
const SUBJECT = "auth-subject-abc";
const SECOND_SUBJECT = "auth-subject-def";
const PRIMARY_ONLY_SUBJECT = "auth-subject-primary-only";

/** Tables referencing users through a cascading foreign key, or the users table itself. */
function tablesNeedingExplicitPurge() {
  const files = [
    path.join(DB_DIR, "schema.pg.sql"),
    path.join(DB_DIR, "schema-auth.pg.sql"),
    ...readdirSync(path.join(DB_DIR, "migrations"))
      .filter((f) => f.endsWith(".sql"))
      .map((f) => path.join(DB_DIR, "migrations", f)),
  ];
  const tables = new Set();
  const createRe =
    /CREATE TABLE(?: IF NOT EXISTS)?\s+(?:public\.)?(\w+)\s*\(([\s\S]*?)\n\);/gi;
  for (const file of files) {
    const sql = readFileSync(file, "utf8");
    for (const match of sql.matchAll(createRe)) {
      const [, table, body] = match;
      if (table === "users") continue;
      const hasUserIdColumn = /^\s*user_id\s+\w+/m.test(body);
      if (!hasUserIdColumn) continue;
      const cascades =
        /user_id[^,\n]*REFERENCES\s+(?:public\.)?users\s*\(id\)\s+ON DELETE CASCADE/i.test(
          body,
        ) ||
        /FOREIGN KEY\s*\(user_id\)\s*REFERENCES\s+(?:public\.)?users\s*\(id\)\s+ON DELETE CASCADE/i.test(
          body,
        );
      if (!cascades) tables.add(table);
    }
  }
  return tables;
}

function makeClient({
  missing = [],
  userRow = {
    id: USER_ID,
    jwt_id: null,
    access_subject: SUBJECT,
    legacy_access_subject: null,
    email: "user@example.com",
  },
} = {}) {
  const calls = [];
  const client = {
    calls,
    query: async (sql, params = []) => {
      calls.push({ sql: sql.replace(/\s+/g, " ").trim(), params });
      if (/to_regclass/.test(sql)) {
        return { rows: [{ exists: !missing.includes(params[0]) }] };
      }
      if (/FROM users u/.test(sql)) {
        return { rows: [userRow] };
      }
      if (/FROM user_auth_subjects/.test(sql)) {
        return { rows: [{ subject: SUBJECT }, { subject: SECOND_SUBJECT }] };
      }
      if (/INSERT INTO admin_audit_logs/.test(sql)) {
        return { rows: [{ id: "audit-1" }] };
      }
      return { rows: [], rowCount: 1 };
    },
    release: () => {},
  };
  return client;
}

describe("collectUserIdentifiers (#1058 access_subject rename)", () => {
  it("reads the primary subject from users.access_subject", async () => {
    const client = makeClient({
      userRow: {
        id: USER_ID,
        jwt_id: null,
        access_subject: PRIMARY_ONLY_SUBJECT,
        legacy_access_subject: null,
        email: "user@example.com",
      },
    });
    const { identifiers } = await collectUserIdentifiers(client, USER_ID);

    expect(identifiers).toContain(PRIMARY_ONLY_SUBJECT);
    const usersQuery = client.calls.find((c) => /FROM users u/.test(c.sql));
    expect(usersQuery.sql).toContain(
      "to_jsonb(u)->>'access_subject' AS access_subject",
    );
  });

  it("still reads the pre-029 supabase_id column so a purge stays complete", async () => {
    const client = makeClient({
      userRow: {
        id: USER_ID,
        jwt_id: null,
        access_subject: null,
        legacy_access_subject: PRIMARY_ONLY_SUBJECT,
        email: "user@example.com",
      },
    });
    const { identifiers } = await collectUserIdentifiers(client, USER_ID);

    expect(identifiers).toContain(PRIMARY_ONLY_SUBJECT);
    const usersQuery = client.calls.find((c) => /FROM users u/.test(c.sql));
    expect(usersQuery.sql).toContain(
      "to_jsonb(u)->>'supabase_id' AS legacy_access_subject",
    );
  });
});

describe("purgeUserData", () => {
  it("covers every table with a user_id column that does not cascade from users", () => {
    const covered = new Set([
      ...USER_DATA_DELETE_TABLES,
      ...USER_DATA_PSEUDONYMIZE_TABLES,
    ]);
    const missing = [...tablesNeedingExplicitPurge()].filter(
      (t) => !covered.has(t),
    );
    expect(missing).toEqual([]);
  });

  it("includes the tables named in the issue", () => {
    for (const table of [
      "conversations",
      "api_usage",
      "user_preferences",
      "tunnel_connections",
      "user_activity_logs",
      "user_sessions",
      "subscriptions",
    ]) {
      expect(USER_DATA_DELETE_TABLES).toContain(table);
    }
    expect(USER_DATA_PSEUDONYMIZE_TABLES).toEqual(
      expect.arrayContaining(["audit_logs", "auth_audit_logs"]),
    );
  });

  it("deletes and pseudonymizes with parameterized queries for every identifier", async () => {
    const client = makeClient();
    const summary = await purgeUserData(client, USER_ID);

    expect(summary.identifiers.sort()).toEqual(
      [USER_ID, SUBJECT, SECOND_SUBJECT].sort(),
    );

    for (const table of USER_DATA_DELETE_TABLES) {
      const call = client.calls.find((c) =>
        c.sql.startsWith(`DELETE FROM ${table} `),
      );
      expect(call).toBeDefined();
      expect(call.sql).toContain("= ANY($1::text[])");
      expect(call.params[0]).toEqual(summary.identifiers);
      expect(call.sql).not.toContain(USER_ID);
    }

    const messages = client.calls.find((c) =>
      c.sql.startsWith("DELETE FROM messages"),
    );
    expect(messages).toBeDefined();
    expect(messages.params[0]).toEqual(summary.identifiers);

    for (const table of USER_DATA_PSEUDONYMIZE_TABLES) {
      const call = client.calls.find((c) =>
        c.sql.startsWith(`UPDATE ${table} `),
      );
      expect(call).toBeDefined();
      expect(call.sql).toMatch(
        /user_id = NULL, ip_address = NULL, user_agent = NULL/,
      );
      expect(call.params[0]).toEqual(summary.identifiers);
    }

    // security_events has no user_id column. Rows are found by identifiers
    // and email addresses stored in details, then the personal fields are cleared.
    const securityEvents = client.calls.find((c) =>
      c.sql.startsWith("UPDATE security_events "),
    );
    expect(securityEvents).toBeDefined();
    expect(securityEvents.sql).toMatch(/ip_address = NULL/);
    expect(securityEvents.sql).toMatch(/details = '\{\}'::jsonb/);
    expect(securityEvents.sql).toContain("details->>'userId'");
    expect(securityEvents.sql).toContain("details->>'user_id'");
    expect(securityEvents.sql).toContain("details->>'accessSub'");
    expect(securityEvents.sql).toContain("details->>'subject'");
    expect(securityEvents.sql).toContain("details->>'sub'");
    expect(securityEvents.sql).toContain("details->>'email'");
    expect(securityEvents.sql).toContain("lower(addr.value)");
    expect(securityEvents.sql).not.toContain("strpos");
    expect(securityEvents.sql).not.toContain(USER_ID);
    expect(securityEvents.sql).not.toContain("user@example.com");
    expect(securityEvents.params[0]).toEqual(summary.identifiers);
    expect(securityEvents.params[1]).toEqual(["user@example.com"]);
    expect(summary.pseudonymized.security_events).toBe(1);
  });

  it("skips optional tables that do not exist", async () => {
    const client = makeClient({
      missing: ["user_activity_summary", "auth_audit_logs"],
    });
    const summary = await purgeUserData(client, USER_ID);
    expect(summary.skipped).toEqual(
      expect.arrayContaining(["user_activity_summary", "auth_audit_logs"]),
    );
    expect(
      client.calls.some((c) =>
        c.sql.startsWith("DELETE FROM user_activity_summary"),
      ),
    ).toBe(false);
    expect(
      client.calls.some((c) => c.sql.startsWith("UPDATE auth_audit_logs")),
    ).toBe(false);
  });

  it("skips security_events when the table is absent", async () => {
    const client = makeClient({ missing: ["security_events"] });
    const summary = await purgeUserData(client, USER_ID);
    expect(summary.skipped).toContain("security_events");
    expect(
      client.calls.some((c) => c.sql.startsWith("UPDATE security_events")),
    ).toBe(false);
  });
});

describe("bulk hard delete", () => {
  beforeEach(() => {
    bulkOperationsService.operations.clear();
  });

  it("purges user data in the same transaction before deleting the user", async () => {
    const client = makeClient();
    const pool = { connect: async () => client };
    const operation = {
      id: "op-1",
      type: "delete",
      successCount: 0,
      failureCount: 0,
      processedUsers: 0,
    };

    const result = await bulkOperationsService._executeDelete(
      operation,
      [USER_ID],
      { softDelete: false },
      "admin-1",
      "super_admin",
      pool,
    );

    expect(result.errors).toEqual([]);
    expect(result.deletedUsers).toEqual([USER_ID]);
    const sqls = client.calls.map((c) => c.sql);
    const begin = sqls.indexOf("BEGIN");
    const commit = sqls.indexOf("COMMIT");
    const deleteUser = sqls.findIndex((s) => s.startsWith("DELETE FROM users"));
    const deleteConversations = sqls.findIndex((s) =>
      s.startsWith("DELETE FROM conversations"),
    );
    const deleteActivity = sqls.findIndex((s) =>
      s.startsWith("DELETE FROM user_activity_logs"),
    );
    expect(begin).toBeGreaterThanOrEqual(0);
    expect(deleteConversations).toBeGreaterThan(begin);
    expect(deleteActivity).toBeGreaterThan(begin);
    expect(deleteUser).toBeGreaterThan(deleteConversations);
    expect(commit).toBeGreaterThan(deleteUser);

    const audit = client.calls.find((c) =>
      c.sql.startsWith("INSERT INTO admin_audit_logs"),
    );
    // affected_user_id must not reference the deleted users row.
    expect(audit.params[5]).toBeNull();
  });

  it("keeps soft delete as the default and does not purge", async () => {
    const client = makeClient();
    const pool = { connect: async () => client };
    const operation = {
      id: "op-2",
      type: "delete",
      successCount: 0,
      failureCount: 0,
      processedUsers: 0,
    };

    await bulkOperationsService._executeDelete(
      operation,
      [USER_ID],
      {},
      "admin-1",
      "super_admin",
      pool,
    );

    const sqls = client.calls.map((c) => c.sql);
    expect(
      sqls.some((s) => s.startsWith("UPDATE users SET deleted_at = NOW()")),
    ).toBe(true);
    expect(sqls.some((s) => s.startsWith("DELETE FROM"))).toBe(false);
  });
});
