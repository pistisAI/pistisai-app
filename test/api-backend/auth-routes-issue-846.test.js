/**
 * Auth route fixes for #846: extractUserId misuse and session revoke.
 */

import { jest } from '@jest/globals';
import crypto from 'crypto';

const mockQuery = jest.fn();
const mockLogLogout = jest.fn(async () => ({}));
const mockLogTokenRevoke = jest.fn(async () => ({}));
const mockRevokeSession = jest.fn(async () => true);

/** Real extractUserId middleware (same contract as middleware/auth.js). */
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

jest.unstable_mockModule('../../services/api-backend/database/db-pool.js', () => ({
  default: { query: (...args) => mockQuery(...args) },
  query: (...args) => mockQuery(...args),
  getPool: () => ({ query: mockQuery }),
  initializePool: jest.fn(),
  closePool: jest.fn(),
}));

jest.unstable_mockModule(
  '../../services/api-backend/services/auth-audit-service.js',
  () => ({
    logLogout: (...args) => mockLogLogout(...args),
    logTokenRevoke: (...args) => mockLogTokenRevoke(...args),
  }),
);

jest.unstable_mockModule('../../services/api-backend/middleware/auth.js', () => ({
  authenticateJWT: (req, _res, next) => {
    const payload = {
      sub: 'jwt|test-user-846',
      email: 'test@example.com',
      name: 'Test User',
      picture: null,
      email_verified: true,
      updated_at: '2026-01-01T00:00:00.000Z',
      exp: Math.floor(Date.now() / 1000) + 3600,
    };
    req.auth = { token: 'test-token', payload };
    req.user = payload;
    next();
  },
  extractUserId,
  getAuthService: () => ({
    revokeSession: mockRevokeSession,
    revokeSessionByToken: jest.fn(async () => true),
  }),
}));

jest.unstable_mockModule(
  '../../services/api-backend/middleware/schema-validation.js',
  () => ({
    validateSchema: (schemas) => async (req, res, next) => {
      try {
        if (schemas.body) {
          req.body = await schemas.body.parseAsync(req.body ?? {});
        }
        next();
      } catch (error) {
        return res.status(400).json({
          error: 'Validation failed',
          details: error.issues ?? error.errors,
        });
      }
    },
  }),
);

const request = (await import('supertest')).default;
const express = (await import('express')).default;
const authRouter = (await import('../../services/api-backend/routes/auth.js'))
  .default;

describe('Auth routes (#846)', () => {
  let app;

  beforeEach(() => {
    mockQuery.mockReset();
    mockLogLogout.mockClear();
    mockLogTokenRevoke.mockClear();
    mockRevokeSession.mockReset();
    mockRevokeSession.mockResolvedValue(true);
    app = express();
    app.use(express.json());
    app.use('/auth', authRouter);
  });

  it('GET /auth/me returns user info without 500', async () => {
    const res = await request(app).get('/auth/me');
    expect(res.status).toBe(200);
    expect(res.body.userId).toBe('jwt|test-user-846');
    expect(res.body.email).toBe('test@example.com');
  });

  it('POST /auth/logout returns success without 500', async () => {
    const res = await request(app).post('/auth/logout');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.userId).toBe('jwt|test-user-846');
  });

  it('POST /auth/session/revoke deactivates the session through the auth service', async () => {
    const sessionId = crypto.randomUUID();
    mockRevokeSession.mockResolvedValueOnce(true);

    const res = await request(app)
      .post('/auth/session/revoke')
      .send({ sessionId });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.sessionId).toBe(sessionId);
    expect(mockRevokeSession).toHaveBeenCalledWith(
      'jwt|test-user-846',
      sessionId,
      expect.objectContaining({ sub: 'jwt|test-user-846' }),
    );
  });

  it('POST /auth/session/revoke returns 404 when session is missing', async () => {
    const sessionId = crypto.randomUUID();
    mockRevokeSession.mockResolvedValueOnce(false);

    const res = await request(app)
      .post('/auth/session/revoke')
      .send({ sessionId });

    expect(res.status).toBe(404);
  });
});
