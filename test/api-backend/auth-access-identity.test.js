/**
 * Access identity linking: same email + new Access sub must map to one user
 * without overwriting users.supabase_id (which would orphan prior data).
 */

import { jest, describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import { AuthService } from "../../services/api-backend/auth/auth-service.js";

describe("AuthService Access identity linking", () => {
  let auth;
  let queries;

  beforeEach(() => {
    process.env.CF_ACCESS_TEAM_DOMAIN = "pistisai.cloudflareaccess.com";
    process.env.CF_ACCESS_AUD = "test-aud";
    auth = new AuthService({});
    queries = [];
    auth.runQuery = jest.fn(async (sql, params = []) => {
      queries.push({ sql, params });
      const normalized = sql.replace(/\s+/g, " ").trim();

      if (normalized.startsWith("SELECT id FROM users WHERE supabase_id")) {
        return auth.__byPrimarySub?.[params[0]] || null;
      }
      if (
        normalized.startsWith(
          "SELECT user_id AS id FROM user_auth_subjects WHERE subject",
        )
      ) {
        return auth.__bySubject?.[params[0]] || null;
      }
      if (
        normalized.startsWith(
          "SELECT id, supabase_id FROM users WHERE email",
        )
      ) {
        return auth.__byEmail?.[params[0]] || null;
      }
      if (normalized.startsWith("INSERT INTO user_auth_subjects")) {
        return { rowCount: 1 };
      }
      if (normalized.startsWith("UPDATE users SET")) {
        return { rowCount: 1 };
      }
      if (normalized.startsWith("INSERT INTO users")) {
        return { rows: [{ id: auth.__newUserId || "user-new" }] };
      }
      throw new Error(`Unexpected query: ${normalized}`);
    });
  });

  afterEach(() => {
    delete process.env.CF_ACCESS_TEAM_DOMAIN;
    delete process.env.CF_ACCESS_AUD;
  });

  it("links a new Access sub for the same email without overwriting supabase_id", async () => {
    auth.__byPrimarySub = {};
    auth.__bySubject = {};
    auth.__byEmail = {
      "chris@example.com": {
        id: "user-1",
        supabase_id: "otp-sub-original",
      },
    };

    const userId = await auth.resolveUserId("google-sub-new", {
      email: "chris@example.com",
      name: "Chris",
      email_verified: true,
    });

    expect(userId).toBe("user-1");

    const update = queries.find((q) =>
      q.sql.replace(/\s+/g, " ").trim().startsWith("UPDATE users SET"),
    );
    expect(update).toBeDefined();
    // First bind must NOT be the new Access sub — supabase_id stays put.
    expect(update.params).not.toContain("google-sub-new");
    expect(update.params[update.params.length - 1]).toBe("user-1");

    const link = queries.find((q) =>
      q.sql.includes("INSERT INTO user_auth_subjects"),
    );
    expect(link).toBeDefined();
    expect(link.params).toEqual(["google-sub-new", "user-1"]);
  });

  it("resolves via user_auth_subjects when primary supabase_id differs", async () => {
    auth.__byPrimarySub = {};
    auth.__bySubject = {
      "google-sub-new": { id: "user-1" },
    };
    auth.__byEmail = {};

    const userId = await auth.resolveUserId("google-sub-new", {
      email: "chris@example.com",
    });

    expect(userId).toBe("user-1");
    expect(
      queries.some((q) => q.sql.includes("INSERT INTO users")),
    ).toBe(false);
  });

  it("creates a user and records the first Access subject", async () => {
    auth.__byPrimarySub = {};
    auth.__bySubject = {};
    auth.__byEmail = {};
    auth.__newUserId = "user-created";

    const userId = await auth.resolveUserId("otp-sub-first", {
      email: "new@example.com",
      name: "New",
      email_verified: true,
    });

    expect(userId).toBe("user-created");
    const insert = queries.find((q) =>
      q.sql.replace(/\s+/g, " ").trim().startsWith("INSERT INTO users"),
    );
    expect(insert.params[0]).toBe("otp-sub-first");
    expect(insert.params[1]).toBe("new@example.com");
    const link = queries.find((q) =>
      q.sql.includes("INSERT INTO user_auth_subjects"),
    );
    expect(link.params).toEqual(["otp-sub-first", "user-created"]);
  });
});
