import { describe, it, expect, jest } from '@jest/globals';

// Use unstable_mockModule for ESM (jest.mock doesn't hoist before await import)
jest.unstable_mockModule('../../services/api-backend/database/db-pool.js', () => ({
  initializePool: jest.fn(),
  getPool: jest.fn(() => ({
    query: jest.fn(),
    connect: jest.fn(),
    end: jest.fn(),
    totalCount: 0,
    idleCount: 0,
    waitingCount: 0,
    on: jest.fn(),
  })),
  getPoolMetrics: jest.fn(() => ({
    totalConnections: 0,
    idleConnections: 0,
    waitingClients: 0,
    errors: 0,
    status: 'mocked',
  })),
  healthCheck: jest.fn(() => Promise.resolve({ healthy: true })),
  closePool: jest.fn(() => Promise.resolve()),
  query: jest.fn(),
  getClient: jest.fn(),
}));

jest.unstable_mockModule('../../services/api-backend/auth/auth-service.js', () => {
  return {
    AuthService: jest.fn().mockImplementation(() => ({
      validateToken: jest.fn(async (token) => {
        if (!token || token.split('.').length !== 3) {
          return { valid: false, error: 'Invalid token format' };
        }
        try {
          const header = JSON.parse(Buffer.from(token.split('.')[0], 'base64url').toString());
          if (header.alg === 'none') {
            return { valid: false, error: 'Algorithm "none" not allowed' };
          }
          if (header.alg !== 'ES256') {
            return { valid: false, error: `Unsupported algorithm: ${header.alg}` };
          }
        } catch {
          return { valid: false, error: 'Invalid token header' };
        }
        return { valid: false, error: 'Token verification failed: invalid signature' };
      }),
    })),
  };
});

const { adminAuth } = await import('../../services/api-backend/middleware/admin-auth.js');
const jwt = await import('jsonwebtoken');

// Helper: create a forged JWT with arbitrary claims but INVALID signature
function createForgedToken(claims) {
  return jwt.sign(claims, 'totally-wrong-secret', { algorithm: 'HS256' });
}

describe('adminAuth middleware — signature verification', () => {
  it('rejects a forged JWT with invalid signature', async () => {
    const forgedToken = createForgedToken({
      sub: '00000000-0000-0000-0000-000000000000',
      email: '<EMAIL>',
      role: 'authenticated',
      exp: Math.floor(Date.now() / 1000) + 3600,
      iat: Math.floor(Date.now() / 1000),
    });

    const req = {
      headers: { authorization: `Bearer ${forgedToken}` },
      ip: '127.0.0.1',
    };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };
    const next = jest.fn();

    await adminAuth()(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ code: 'INVALID_TOKEN' }),
    );
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects a token with "none" algorithm', async () => {
    const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
    const payload = Buffer.from(JSON.stringify({
      sub: '00000000-0000-0000-0000-000000000000',
      email: '<EMAIL>',
      exp: Math.floor(Date.now() / 1000) + 3600,
    })).toString('base64url');
    const noneToken = `${header}.${payload}.`;

    const req = {
      headers: { authorization: `Bearer ${noneToken}` },
      ip: '127.0.0.1',
    };
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
    };
    const next = jest.fn();

    await adminAuth()(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });
});
