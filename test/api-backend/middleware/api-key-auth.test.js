/**
 * Behavior tests for API key authentication middleware.
 */

import { describe, it, expect, jest, beforeEach } from '@jest/globals';

const mockValidateApiKey = jest.fn();

jest.unstable_mockModule(
  '../../../services/api-backend/services/api-key-service.js',
  () => ({
    validateApiKey: (...args) => mockValidateApiKey(...args),
  }),
);

const {
  authenticateApiKey,
  optionalApiKeyAuth,
  requireApiKeyScope,
  apiKeyAuth,
} = await import('../../../services/api-backend/middleware/api-key-auth.js');

function mockRes() {
  return {
    statusCode: null,
    body: null,
    headers: {},
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
    set(name, value) {
      this.headers[name] = value;
    },
  };
}

describe('api-key-auth middleware', () => {
  let next;

  beforeEach(() => {
    next = jest.fn();
    mockValidateApiKey.mockReset();
  });

  describe('authenticateApiKey', () => {
    it('returns 401 when no API key is provided', async () => {
      const req = { headers: {}, ip: '127.0.0.1', path: '/api/svc' };
      const res = mockRes();
      await authenticateApiKey(req, res, next);
      expect(res.statusCode).toBe(401);
      expect(res.body.code).toBe('MISSING_API_KEY');
      expect(next).not.toHaveBeenCalled();
    });

    it('authenticates via Authorization Bearer header', async () => {
      mockValidateApiKey.mockResolvedValue({
        id: 'key-1',
        userId: 'user-1',
        scopes: ['read'],
      });
      const req = {
        headers: { authorization: 'Bearer secret-key' },
        ip: '127.0.0.1',
        path: '/api/svc',
      };
      const res = mockRes();
      await authenticateApiKey(req, res, next);
      expect(mockValidateApiKey).toHaveBeenCalledWith('secret-key');
      expect(req.apiKey.id).toBe('key-1');
      expect(req.userId).toBe('user-1');
      expect(req.isServiceAuth).toBe(true);
      expect(next).toHaveBeenCalledTimes(1);
    });

    it('falls back to X-API-Key header', async () => {
      mockValidateApiKey.mockResolvedValue({
        id: 'key-2',
        userId: 'user-2',
        scopes: [],
      });
      const req = {
        headers: { 'x-api-key': 'header-key' },
        ip: '127.0.0.1',
        path: '/api/svc',
      };
      const res = mockRes();
      await authenticateApiKey(req, res, next);
      expect(mockValidateApiKey).toHaveBeenCalledWith('header-key');
      expect(next).toHaveBeenCalledTimes(1);
    });

    it('returns 401 for invalid keys', async () => {
      mockValidateApiKey.mockResolvedValue(null);
      const req = {
        headers: { 'x-api-key': 'bad' },
        ip: '127.0.0.1',
        path: '/api/svc',
      };
      const res = mockRes();
      await authenticateApiKey(req, res, next);
      expect(res.statusCode).toBe(401);
      expect(res.body.code).toBe('INVALID_API_KEY');
      expect(next).not.toHaveBeenCalled();
    });

    it('returns 500 when validation throws', async () => {
      mockValidateApiKey.mockRejectedValue(new Error('db down'));
      const req = {
        headers: { 'x-api-key': 'any' },
        ip: '127.0.0.1',
        path: '/api/svc',
      };
      const res = mockRes();
      await authenticateApiKey(req, res, next);
      expect(res.statusCode).toBe(500);
      expect(res.body.code).toBe('API_KEY_AUTH_ERROR');
      expect(next).not.toHaveBeenCalled();
    });
  });

  describe('optionalApiKeyAuth', () => {
    it('continues without auth when no key is present', async () => {
      const req = { headers: {} };
      const res = mockRes();
      await optionalApiKeyAuth(req, res, next);
      expect(req.apiKey).toBeUndefined();
      expect(next).toHaveBeenCalledTimes(1);
    });

    it('attaches metadata when a valid key is present', async () => {
      mockValidateApiKey.mockResolvedValue({
        id: 'key-3',
        userId: 'user-3',
        scopes: ['write'],
      });
      const req = { headers: { 'x-api-key': 'good' } };
      const res = mockRes();
      await optionalApiKeyAuth(req, res, next);
      expect(req.apiKey.id).toBe('key-3');
      expect(req.isServiceAuth).toBe(true);
      expect(next).toHaveBeenCalledTimes(1);
    });

    it('continues when validation throws', async () => {
      mockValidateApiKey.mockRejectedValue(new Error('boom'));
      const req = { headers: { 'x-api-key': 'any' } };
      const res = mockRes();
      await optionalApiKeyAuth(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      expect(res.statusCode).toBeNull();
    });
  });

  describe('requireApiKeyScope', () => {
    it('returns 401 when apiKey is missing', () => {
      const res = mockRes();
      requireApiKeyScope('read')({}, res, next);
      expect(res.statusCode).toBe(401);
      expect(res.body.code).toBe('API_KEY_REQUIRED');
    });

    it('returns 403 when required scope is missing', () => {
      const req = { apiKey: { id: 'k', scopes: ['read'] } };
      const res = mockRes();
      requireApiKeyScope(['write', 'admin'])(req, res, next);
      expect(res.statusCode).toBe(403);
      expect(res.body.code).toBe('INSUFFICIENT_SCOPES');
      expect(next).not.toHaveBeenCalled();
    });

    it('calls next when at least one required scope is present', () => {
      const req = { apiKey: { id: 'k', scopes: ['write'] } };
      const res = mockRes();
      requireApiKeyScope('write')(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
    });
  });

  describe('apiKeyAuth rate limiting', () => {
    it('skips limiting when no apiKey is attached', () => {
      const middleware = apiKeyAuth();
      const res = mockRes();
      middleware({}, res, next);
      expect(next).toHaveBeenCalledTimes(1);
    });

    it('allows requests under the limit and sets rate headers', () => {
      const middleware = apiKeyAuth();
      const req = { apiKey: { id: 'rate-key', rateLimit: 2 } };
      const res = mockRes();
      middleware(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      expect(res.headers['X-RateLimit-Limit']).toBe('2');
      expect(Number(res.headers['X-RateLimit-Remaining'])).toBe(1);
    });

    it('returns 429 when the key exceeds its rate limit', () => {
      const middleware = apiKeyAuth();
      const req = { apiKey: { id: 'burst-key', rateLimit: 1 } };
      const res1 = mockRes();
      const res2 = mockRes();
      middleware(req, res1, next);
      expect(next).toHaveBeenCalledTimes(1);
      next.mockClear();
      middleware(req, res2, next);
      expect(res2.statusCode).toBe(429);
      expect(res2.body.code).toBe('API_KEY_RATE_LIMIT_EXCEEDED');
      expect(next).not.toHaveBeenCalled();
    });
  });
});
