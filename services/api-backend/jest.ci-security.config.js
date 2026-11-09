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
    '**/test/api-backend/cloud-connector.test.js',
    '**/test/api-backend/webhook-rate-limiting.test.js',
    '**/test/api-backend/sandbox-service.test.js',
  ],
  testPathIgnorePatterns: [
    ...base.testPathIgnorePatterns,
    'user-isolation\\.test\\.js$',
  ],
};
