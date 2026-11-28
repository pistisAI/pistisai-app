import base from './jest.config.js';

/** CI security gate — auth, RBAC, validation, rate limits, connector hardening. */
export default {
  ...base,
  collectCoverage: false,
  testMatch: [
    // Prefer **/ globs — <rootDir>/../../.../security/** fails to expand on Windows
    '**/test/api-backend/security/*.test.js',
    '**/test/api-backend/rbac.test.js',
    '**/test/api-backend/input-validation.test.js',
    '**/test/api-backend/route-body-validation-2.test.js',
    '**/test/api-backend/suspension-gaps-893.test.js',
    '**/test/api-backend/session-revoke-892.test.js',
    '**/test/api-backend/route-body-validation-3.test.js',
    '**/test/api-backend/usage-event-body-validation.test.js',
    '**/test/api-backend/admin-body-validation.test.js',
    '**/test/api-backend/admin-body-validation-2.test.js',
    '**/test/api-backend/route-body-validation.test.js',
    '**/test/api-backend/cloud-connector.test.js',
    '**/test/api-backend/webhook-rate-limiting.test.js',
    '**/test/api-backend/sandbox-service.test.js',
    // Regression tests added by the #846, #847 and #807 security fixes.
    // They existed on main but were never picked up by this gate.
    '**/test/api-backend/api-keys-routes-issue-846.test.js',
    '**/test/api-backend/auth-routes-issue-846.test.js',
    '**/test/api-backend/middleware/schema-validation.test.js',
    '**/test/api-backend/admin-transaction-client.test.js',
    '**/test/api-backend/auth-suspended-account.test.js',
    '**/test/api-backend/agent-events-webhook-secret.test.js',
    // #895: raw-body webhook HMAC and development-only dev bypass.
    '**/test/api-backend/agent-events-raw-hmac-895.test.js',
    '**/test/api-backend/dev-bypass-node-env-895.test.js',
    // Admin/owner checks on session cleanup, model catalogue, webhook test
    // events, rate-limit admin routes and the public database health check.
    '**/test/api-backend/admin-owner-checks.test.js',
    '**/test/api-backend/db-health-route.test.js',
    // Session, signing-key and key-comparison hardening.
    '**/test/api-backend/session-token-hardening-auth-service.test.js',
    '**/test/api-backend/session-token-hardening-routes.test.js',
    '**/test/api-backend/session-token-hardening-keys.test.js',
    // Server-side personal data: log redaction, client-log bounds, account
    // hard delete coverage, masked emails in logs.
    '**/test/api-backend/request-log-redaction.test.js',
    '**/test/api-backend/client-logs-bounds.test.js',
    '**/test/api-backend/user-data-purge.test.js',
    '**/test/api-backend/mask-email-logs.test.js',
    // Follow-up for #1022: auth-service email masking and security_events
    // details (no user_id column; cleared on hard delete).
    '**/test/api-backend/security-event-details.test.js',
    // #1058: the Access subject column is users.access_subject (migration 029).
    '**/test/api-backend/access-subject-column-1058.test.js',
    '**/test/api-backend/auth-access-identity.test.js',
    // Sentry beforeSend removes credential headers, cookies and token
    // query params from server-side error reports.
    '**/test/api-backend/sentry-scrub.test.js',
  ],
  testPathIgnorePatterns: [
    ...base.testPathIgnorePatterns,
    'user-isolation\\.test\\.js$',
  ],
};
