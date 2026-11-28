/**
 * #1058: users.supabase_id held the Cloudflare Access subject, not a Supabase
 * id. Migration 029 renames it to users.access_subject; the api-backend code
 * must use the new name. Older migrations (026, 027) keep the old name because
 * applied migrations are never edited.
 */
import { describe, expect, it } from "@jest/globals";
import path from "path";
import { fileURLToPath } from "url";
import { readFileSync, readdirSync, statSync } from "fs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BACKEND = path.join(__dirname, "../../services/api-backend");
const MIGRATIONS = path.join(BACKEND, "database/migrations");
const MIGRATION_029 = path.join(
  MIGRATIONS,
  "029_rename_users_supabase_id_to_access_subject.sql",
);

/** Every .js file under the api-backend, outside node_modules. */
function backendSources(dir = BACKEND) {
  const out = [];
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name.startsWith(".")) continue;
    const full = path.join(dir, name);
    if (statSync(full).isDirectory()) {
      out.push(...backendSources(full));
    } else if (name.endsWith(".js")) {
      out.push(full);
    }
  }
  return out;
}

describe("users.access_subject rename (#1058)", () => {
  const sql = readFileSync(MIGRATION_029, "utf8");

  it("is the newest numbered migration, so it runs after 026 and 027", () => {
    const numbered = readdirSync(MIGRATIONS)
      .filter((f) => /^\d+_.+\.sql$/.test(f))
      .sort();
    expect(numbered.indexOf(path.basename(MIGRATION_029))).toBeGreaterThan(
      numbered.indexOf("027_user_auth_subjects.sql"),
    );
  });

  it("renames the column only when the old name is present", () => {
    expect(sql).toMatch(/column_name = 'supabase_id'/);
    expect(sql).toMatch(/column_name = 'access_subject'/);
    expect(sql).toMatch(
      /ELSIF has_old THEN\s+ALTER TABLE public\.users RENAME COLUMN supabase_id TO access_subject;/,
    );
    // Both columns present is ambiguous: refuse rather than guess.
    expect(sql).toMatch(/IF has_old AND has_new THEN\s+[\s\S]*?RAISE EXCEPTION/);
  });

  it("renames the indexes and foreign key from migration 026, with guards", () => {
    expect(sql).toMatch(
      /to_regclass\('public\.idx_users_supabase_id_unique'\) IS NOT NULL[\s\S]*?RENAME TO idx_users_access_subject_unique/,
    );
    expect(sql).toMatch(
      /to_regclass\('public\.idx_users_supabase_id'\) IS NOT NULL[\s\S]*?RENAME TO idx_users_access_subject;/,
    );
    expect(sql).toMatch(
      /conname = 'users_supabase_id_fkey'[\s\S]*?RENAME CONSTRAINT users_supabase_id_fkey TO users_access_subject_fkey/,
    );
  });

  it("recreates the Supabase sync trigger function with the new column", () => {
    // Function bodies are text; RENAME COLUMN does not rewrite them.
    const fn = sql.slice(sql.indexOf("CREATE OR REPLACE FUNCTION"));
    expect(fn).toContain("INSERT INTO public.users (access_subject,");
    expect(fn).toContain("ON CONFLICT (access_subject)");
    expect(fn).not.toContain("supabase_id");
  });

  it("api-backend code no longer queries users.supabase_id", () => {
    const offenders = [];
    for (const file of backendSources()) {
      const rel = path.relative(BACKEND, file);
      const text = readFileSync(file, "utf8");
      const hits = text
        .split("\n")
        .filter((line) => line.includes("supabase_id"))
        // The purge also reads the pre-029 name, so a hard delete on a
        // database that is not migrated yet still finds the subject.
        .filter(
          (line) =>
            !(
              rel === path.join("services", "user-data-purge.js") &&
              (line.includes("legacy_access_subject") ||
                line.includes("before migration 029"))
            ),
        );
      if (hits.length > 0) offenders.push(`${rel}: ${hits.join(" | ")}`);
    }
    expect(offenders).toEqual([]);
  });
});
