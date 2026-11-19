/**
 * API key routes must not call extractUserId as a helper (#846).
 */

import { jest } from '@jest/globals';

const mockListApiKeys = jest.fn(async () => [{ id: 'key-1', name: 'Test' }]);

const extractUserId = (req, res, next) => {
  if (!req.auth?.payload?.sub) {
    return res.status(401).json({
      error: 'User ID not available',
      code: 'USER_ID_MISSING',
    });
  }
  req.userId = req.auth.payload.sub;
  next();
};

jest.unstable_mockModule('express-rate-limit', () => ({
  default: () => (_req, _res, next) => next(),
}));

jest.unstable_mockModule('../../services/api-backend/middleware/auth.js', () => ({
  authenticateJWT: (req, _res, next) => {
    const payload = { sub: 'user-846' };
    req.auth = { payload };
    req.user = payload;
    next();
  },
  extractUserId,
}));

jest.unstable_mockModule(
  '../../services/api-backend/middleware/schema-validation.js',
  () => ({
    validateSchema: () => (_req, _res, next) => next(),
  }),
);

jest.unstable_mockModule(
  '../../services/api-backend/services/api-key-service.js',
  () => ({
    generateApiKey: jest.fn(),
    listApiKeys: (...args) => mockListApiKeys(...args),
    getApiKey: jest.fn(),
    updateApiKey: jest.fn(),
    rotateApiKey: jest.fn(),
    revokeApiKey: jest.fn(),
    getApiKeyAuditLogs: jest.fn(),
  }),
);

const request = (await import('supertest')).default;
const express = (await import('express')).default;
const apiKeysRouter = (
  await import('../../services/api-backend/routes/api-keys.js')
).default;

describe('API key routes (#846)', () => {
  let app;

  beforeEach(() => {
    mockListApiKeys.mockClear();
    app = express();
    app.use(express.json());
    app.use('/api-keys', apiKeysRouter);
  });

  it('GET /api-keys lists keys without 500 from extractUserId', async () => {
    const res = await request(app).get('/api-keys');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([{ id: 'key-1', name: 'Test' }]);
    expect(mockListApiKeys).toHaveBeenCalledWith('user-846');
  });
});
