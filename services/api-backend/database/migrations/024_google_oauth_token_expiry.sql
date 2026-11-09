-- Migration 024: Google OAuth token expiry tracking
--
-- getValidAccessToken() previously returned any stored access token without
-- checking expiry (issue #147), guaranteeing 401s after Google's ~1h token
-- lifetime. This column records the absolute expiry so the service can refresh
-- proactively.

ALTER TABLE email_configurations
  ADD COLUMN IF NOT EXISTS google_oauth_token_expires_at TIMESTAMPTZ;

-- Existing rows: unknown expiry — force a refresh on next use rather than
-- trusting a possibly-stale token.
UPDATE email_configurations
SET google_oauth_token_expires_at = NOW() - INTERVAL '1 second'
WHERE google_oauth_token_encrypted IS NOT NULL
  AND google_oauth_token_expires_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_email_configurations_token_expiry
  ON email_configurations (google_oauth_token_expires_at)
  WHERE google_oauth_token_encrypted IS NOT NULL;
