-- Migration: Scope subagent registry rows to their creator
-- Cursor HIGH finding, 2026-11-24: /api/admin/subagents had no owner check,
-- so any signed-in user could list, overwrite or delete another user's rows.

-- A Cloudflare Access JWT `sub` is a string (UUID for real accounts, a fixed
-- value for the dev bypass token), matching the TEXT convention already used
-- by the user-activity tracking tables.
ALTER TABLE subagent_registry
  ADD COLUMN IF NOT EXISTS user_id TEXT;

-- Rows written before this migration have no verifiable owner. Fail closed:
-- they remain in the table, but owner-scoped SELECT/UPDATE/DELETE never match
-- a NULL user_id, so no caller can claim them.
COMMENT ON COLUMN subagent_registry.user_id IS
  'Cloudflare Access JWT sub of the signed-in user who created the row. NULL means a legacy, ownerless row that owner-scoped endpoints cannot read or change.';

CREATE INDEX IF NOT EXISTS idx_subagent_registry_user_id_subagent_id
  ON subagent_registry (user_id, subagent_id);
