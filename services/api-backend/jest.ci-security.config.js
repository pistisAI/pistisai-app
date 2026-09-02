import base from './jest.config.js';

/** CI security gate — auth, RBAC, validation, rate limits, connector hardening. */
export default {
  ...base,
  collectCoverage: false,
  testMatch: [
    '<rootDir>/../../test/api-backend/security/**/*.js',
    '<rootDir>/../../test/api-backend/rbac.test.js',
    '<rootDir>/../../test/api-backend/https-enforcer.test.js',
    '<rootDir>/../../test/api-backend/input-validation.test.js',
    '<rootDir>/../../test/api-backend/cloud-connector.test.js',
    '<rootDir>/../../test/api-backend/adaptive-rate-limiting.test.js',
    '<rootDir>/../../test/api-backend/rate-limit-exemptions.test.js',
    '<rootDir>/../../test/api-backend/webhook-rate-limiting.test.js',
    '<rootDir>/../../test/api-backend/sandbox-service.test.js',
  ],
  testPathIgnorePatterns: [
    ...base.testPathIgnorePatterns,
    'user-isolation\\.test\\.js$',
  ],
};
