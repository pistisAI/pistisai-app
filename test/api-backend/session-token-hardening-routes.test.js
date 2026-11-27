/**
 * Route-level session hardening:
 * - POST /auth/logout ends the server-side session of the presented token,
 * - the legacy tunnel routes only accept tokens validateToken marks valid.
 */
import { describe, it, expect, beforeEach, jest } from '@jest/globals';

const mockRevokeSessionByToken = jest.fn();

jest.unstable_mockModule('express-rate-limit', () => ({
  default: () => (_req, _res, next) => next(),
}));

jest.unstable_mockModule(
  '../../services/api-backend/services/auth-audit-service.js',
  () => ({
    logLogout: jest.fn(async () => ({})),
    logTokenRevoke: jest.fn(async () => ({})),
  }),
);

jest.unstable_mockModule('../../services/api-backend/middleware/auth.js', () => ({
  authenticateJWT: (req, _res, next) => {
    const payload = {
      sub: 'access-sub-1',
      email: 'user@example.com',
      exp: Math.floor(Date.now() / 1000) + 3600,
    };
    req.auth = { token: 'bearer-token-1', payload };
    req.user = payload;
    next();
  },
  extractUserId: (req, _res, next) => {
    req.userId = req.auth.payload.sub;
    next();
  },
  getAuthService: () => ({
    revokeSessionByToken: mockRevokeSessionByToken,
    revokeSession: jest.fn(),
  }),
}));

const request = (await import('supertest')).default;
const express = (await import('express')).default;
const authRouter = (await import('../../services/api-backend/routes/auth.js'))
  .default;
const { createTunnelRoutes } = await import(
  '../../services/api-backend/tunnel/tunnel-routes.js'
);

describe('POST /auth/logout ends the session', () => {
  let app;

  beforeEach(() => {
    mockRevokeSessionByToken.mockReset();
    app = express();
    app.use(express.json());
    app.use('/auth', authRouter);
  });

  it('revokes the session of the presented token', async () => {
    mockRevokeSessionByToken.mockResolvedValue(true);

    const res = await request(app).post('/auth/logout');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.sessionRevoked).toBe(true);
    expect(mockRevokeSessionByToken).toHaveBeenCalledWith(
      'access-sub-1',
      'bearer-token-1',
      expect.objectContaining({ sub: 'access-sub-1' }),
    );
  });

  it('says so when no active session was found', async () => {
    mockRevokeSessionByToken.mockResolvedValue(false);

    const res = await request(app).post('/auth/logout');

    expect(res.status).toBe(200);
    expect(res.body.sessionRevoked).toBe(false);
    expect(res.body.message).toMatch(/no active server session/i);
  });

  it('does not report success when the session could not be ended', async () => {
    mockRevokeSessionByToken.mockRejectedValue(new Error('db unavailable'));

    const res = await request(app).post('/auth/logout');

    expect(res.status).toBe(500);
    expect(res.body.success).toBeUndefined();
    expect(res.body.code).toBe('LOGOUT_ERROR');
    expect(JSON.stringify(res.body)).not.toMatch(/db unavailable/);
  });
});

describe('legacy tunnel routes authentication', () => {
  function appWith(validateToken) {
    const tunnelProxy = {
      getHealthStatus: jest.fn(() => ({ status: 'healthy' })),
    };
    const router = createTunnelRoutes(tunnelProxy, undefined, {
      validateToken,
    });
    // Probe route behind the router's authentication middleware.
    router.get('/whoami', (req, res) =>
      res.json({ userId: req.userId, sub: req.user?.sub }),
    );
    const app = express();
    app.use('/tunnel', router);
    return { app, tunnelProxy };
  }

  it('rejects a token that validateToken reports invalid', async () => {
    const validateToken = jest.fn(async () => ({
      valid: false,
      error: 'invalid signature',
    }));
    const { app, tunnelProxy } = appWith(validateToken);

    const res = await request(app)
      .get('/tunnel/health')
      .set('Authorization', 'Bearer forged');

    expect(res.status).toBe(401);
    expect(tunnelProxy.getHealthStatus).not.toHaveBeenCalled();
  });

  it('rejects a suspended account with 403', async () => {
    const validateToken = jest.fn(async () => ({
      valid: false,
      error: 'Account is suspended',
      code: 'ACCOUNT_SUSPENDED',
    }));
    const { app, tunnelProxy } = appWith(validateToken);

    const res = await request(app)
      .get('/tunnel/health')
      .set('Authorization', 'Bearer suspended');

    expect(res.status).toBe(403);
    expect(res.body.code).toBe('ACCOUNT_SUSPENDED');
    expect(tunnelProxy.getHealthStatus).not.toHaveBeenCalled();
  });

  it('accepts a valid token and uses the validated subject', async () => {
    const validateToken = jest.fn(async () => ({
      valid: true,
      payload: { sub: 'access-sub-1' },
      session: { id: 's-1', is_active: true },
    }));
    const { app } = appWith(validateToken);

    const res = await request(app)
      .get('/tunnel/whoami')
      .set('Authorization', 'Bearer good');

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ userId: 'access-sub-1', sub: 'access-sub-1' });
  });
});
