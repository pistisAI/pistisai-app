-- Rollback for 024_google_oauth_token_expiry.sql

DROP INDEX IF EXISTS idx_email_configurations_token_expiry;
ALTER TABLE email_configurations
  DROP COLUMN IF EXISTS google_oauth_token_expires_at;
