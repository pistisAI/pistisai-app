import base from './jest.config.js';

/**
 * Extended backend checks: auth, access, CORS, rate-limit and SSRF suites that
 * pass but are not in the security gate (jest.ci-security.config.js).
 * Run by .github/workflows/extended-tests.yml on every pull request.
 * api-keys and sandbox-routes exercise authenticated key management and the
 * sandbox gate (401 without a bearer token, 403 when SANDBOX_MODE is off).
 */
export default {
  ...base,
  collectCoverage: false,
  testMatch: [
    // Prefer **/ globs — <rootDir>/../../.../middleware/** fails to expand on Windows
    '**/test/api-backend/middleware/admin-auth.test.js',
    '**/test/api-backend/middleware/api-key-auth.test.js',
    '**/test/api-backend/middleware/cors-config.test.js',
    '**/test/api-backend/middleware/infrastructure-auth.test.js',
    '**/test/api-backend/middleware/admin-rate-limiter.test.js',
    '**/test/api-backend/middleware/request-validation.test.js',
    '**/test/api-backend/auth-access-identity.test.js',
    '**/test/api-backend/auth-token-refresh.test.js',
    '**/test/api-backend/auth-audit.test.js',
    '**/test/api-backend/aws-oidc-authentication.test.js',
    '**/test/api-backend/cf-access-audience.test.js',
    '**/test/api-backend/legacy-routes-default-disabled.test.js',
    '**/test/api-backend/tier-validation.test.js',
    '**/test/api-backend/user-tier-route.test.js',
    '**/test/api-backend/api-key-service.unit.test.js',
    '**/test/api-backend/cloud-connector-routes.test.js',
    '**/test/api-backend/kubernetes-secret-encryption.test.js',
    '**/test/api-backend/rate-limit-violations.test.js',
    '**/test/api-backend/webhook-rate-limiting-unit.test.js',
    '**/test/api-backend/utils/ssrf-protection.test.js',
    '**/test/api-backend/api-keys.test.js',
    '**/test/api-backend/sandbox-routes.test.js',
    '**/test/api-backend/service-version.test.js',
  ],
};
