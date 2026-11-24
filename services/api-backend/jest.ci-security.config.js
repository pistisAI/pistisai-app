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
  ],
  testPathIgnorePatterns: [
    ...base.testPathIgnorePatterns,
    'user-isolation\\.test\\.js$',
  ],
};
