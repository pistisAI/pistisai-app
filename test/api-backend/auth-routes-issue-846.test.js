/**
 * Auth route fixes for #846: extractUserId misuse and session revoke.
 */

import { jest } from '@jest/globals';
import crypto from 'crypto';

const mockQuery = jest.fn();
const mockLogLogout = jest.fn(async () => ({}));
const mockLogTokenRevoke = jest.fn(async () => ({}));
const mockRevokeSession = jest.fn(async () => true);
const mockValidateToken = jest.fn();

const TEST_PAYLOAD = {
  sub: 'jwt|test-user-846',
  email: 'test@example.com',
  name: 'Test User',
  picture: null,
  email_verified: true,
  updated_at: '2026-01-01T00:00:00.000Z',
  exp: Math.floor(Date.now() / 1000) + 3600,
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

// The real middleware/auth.js (authenticateJWT, extractUserId,
// getAuthService) runs; only the AuthService it builds is replaced, so token
// verification is controlled here and session revoke is observable.
jest.unstable_mockModule('../../services/api-backend/auth/auth-service.js', () => ({
  AuthService: class {
    constructor() {
      this.devBypassToken = null;
    }
    isDevBypassToken() {
      return false;
    }
    validateToken(...args) {
      return mockValidateToken(...args);
    }
    revokeSession(...args) {
      return mockRevokeSession(...args);
    }
  },
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
const { extractUserId } = await import(
  '../../services/api-backend/middleware/auth.js'
);

const AUTH = { Authorization: 'Bearer test-token' };

describe('Auth routes (#846)', () => {
  let app;

  beforeEach(() => {
    mockQuery.mockReset();
    mockLogLogout.mockClear();
    mockLogTokenRevoke.mockClear();
    mockRevokeSession.mockReset();
    mockRevokeSession.mockResolvedValue(true);
    mockValidateToken.mockReset();
    mockValidateToken.mockResolvedValue({
      valid: true,
      payload: TEST_PAYLOAD,
      session: { id: 'session-846' },
    });
    app = express();
    app.use(express.json());
    app.use('/auth', authRouter);
  });

  it('GET /auth/me returns user info without 500', async () => {
    const res = await request(app).get('/auth/me').set(AUTH);
    expect(res.status).toBe(200);
    expect(res.body.userId).toBe('jwt|test-user-846');
    expect(res.body.email).toBe('test@example.com');
  });

  it('POST /auth/logout returns success without 500', async () => {
    const res = await request(app).post('/auth/logout').set(AUTH);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.userId).toBe('jwt|test-user-846');
  });

  it('POST /auth/session/revoke deactivates the session through the auth service', async () => {
    const sessionId = crypto.randomUUID();
    mockRevokeSession.mockResolvedValueOnce(true);

    const res = await request(app)
      .post('/auth/session/revoke')
      .set(AUTH)
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
      .set(AUTH)
      .send({ sessionId });

    expect(res.status).toBe(404);
  });

  it('GET /auth/me returns 401 without a bearer token', async () => {
    const res = await request(app).get('/auth/me');
    expect(res.status).toBe(401);
    expect(mockValidateToken).not.toHaveBeenCalled();
  });

  it('GET /auth/me returns 401 when the token does not verify', async () => {
    mockValidateToken.mockResolvedValueOnce({
      valid: false,
      error: 'invalid signature',
    });
    const res = await request(app).get('/auth/me').set(AUTH);
    expect(res.status).toBe(401);
    expect(res.body.code).toBe('TOKEN_INVALID');
  });

  it('GET /auth/me returns 401 USER_ID_MISSING when the verified payload has no sub', async () => {
    const { sub: _sub, ...noSub } = TEST_PAYLOAD;
    mockValidateToken.mockResolvedValueOnce({ valid: true, payload: noSub });
    const res = await request(app).get('/auth/me').set(AUTH);
    expect(res.status).toBe(401);
    expect(res.body.code).toBe('USER_ID_MISSING');
  });
});

describe('extractUserId (middleware/auth.js)', () => {
  function run(req) {
    const res = {
      statusCode: 200,
      body: undefined,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(body) {
        this.body = body;
        return this;
      },
    };
    const next = jest.fn();
    extractUserId(req, res, next);
    return { res, next };
  }

  it('copies the verified subject to req.userId', () => {
    const req = { auth: { payload: { sub: 'jwt|abc' } } };
    const { res, next } = run(req);
    expect(next).toHaveBeenCalledTimes(1);
    expect(req.userId).toBe('jwt|abc');
    expect(res.statusCode).toBe(200);
  });

  it.each([
    ['no auth', {}],
    ['no payload', { auth: {} }],
    ['empty sub', { auth: { payload: { sub: '' } } }],
  ])('returns 401 USER_ID_MISSING with %s', (_label, req) => {
    const { res, next } = run(req);
    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(401);
    expect(res.body.code).toBe('USER_ID_MISSING');
    expect(req.userId).toBeUndefined();
  });

  it('ignores a user id that did not come from the verified payload', () => {
    const req = { userId: 'spoofed', body: { userId: 'spoofed' } };
    const { res, next } = run(req);
    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(401);
  });
});
