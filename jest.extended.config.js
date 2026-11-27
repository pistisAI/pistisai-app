/**
 * Repo-root Jest suites that no other config runs in CI: repository policy
 * checks (action SHA pins, nginx security headers) and the streaming-proxy
 * /stats auth check. Run from the repo root by
 * .github/workflows/extended-tests.yml:
 *
 *   node --experimental-vm-modules \
 *     services/streaming-proxy/node_modules/jest/bin/jest.js \
 *     --config jest.extended.config.js
 *
 * (The repo root has no lockfile; streaming-proxy's locked Jest is used.)
 */
export default {
  rootDir: '.',
  testEnvironment: 'node',
  testMatch: [
    '<rootDir>/test/policy/**/*.test.js',
    '<rootDir>/test/streaming-proxy/**/*.test.js',
  ],
  transform: {},
  testPathIgnorePatterns: ['/node_modules/'],
};
