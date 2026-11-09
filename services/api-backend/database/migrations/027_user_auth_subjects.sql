-- Map multiple Cloudflare Access subjects (OTP, Google, GitHub) to one user.
-- users.supabase_id remains the first-seen subject; additional subjects land here.

CREATE TABLE IF NOT EXISTS user_auth_subjects (
  subject TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_auth_subjects_user_id
  ON user_auth_subjects(user_id);

-- Backfill the primary subject when present.
INSERT INTO user_auth_subjects (subject, user_id)
SELECT supabase_id::text, id
FROM users
WHERE supabase_id IS NOT NULL
ON CONFLICT (subject) DO NOTHING;
