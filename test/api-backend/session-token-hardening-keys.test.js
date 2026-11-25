/**
 * Key-based authentication hardening:
 * - API keys of suspended or deleted accounts are refused,
 * - infrastructure keys are compared in constant time.
 */
import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import realCrypto from 'crypto';

const mockQuery = jest.fn();
const timingSafeEqualSpy = jest.fn((a, b) => realCrypto.timingSafeEqual(a, b));

jest.unstable_mockModule('crypto', () => ({
  ...realCrypto,
  default: { ...realCrypto, timingSafeEqual: timingSafeEqualSpy },
  timingSafeEqual: timingSafeEqualSpy,
}));

jest.unstable_mockModule('../../services/api-backend/database/db-pool.js', () => ({
  default: { query: (...args) => mockQuery(...args) },
  query: (...args) => mockQuery(...args),
  getClient: jest.fn(),
  getPool: () => ({ query: mockQuery }),
  initializePool: jest.fn(),
  closePool: jest.fn(),
}));

const { validateApiKey } = await import(
  '../../services/api-backend/services/api-key-service.js'
);
const { authenticateApiKey, optionalApiKeyAuth } = await import(
  '../../services/api-backend/middleware/api-key-auth.js'
);
const { authenticateInfrastructure, optionalInfrastructureAuth } = await import(
  '../../services/api-backend/middleware/infrastructure-auth.js'
);

const API_KEY = 'ctll_' + 'a'.repeat(64);

function mockRes() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
    set() {},
  };
}

/** Database with one active key owned by user-1 in the given account state. */
function databaseWithOwner(owner) {
  mockQuery.mockImplementation(async (sql) => {
    if (/FROM api_keys/.test(sql)) {
      return {
        rows: [
          {
            id: 'key-1',
            user_id: 'user-1',
            name: 'k',
            scopes: ['read'],
            rate_limit: 100,
            is_active: true,
            expires_at: null,
            last_used_at: null,
          },
        ],
      };
    }
    if (/FROM users/.test(sql)) {
      return { rows: owner ? [owner] : [] };
    }
    return { rows: [], rowCount: 1 };
  });
}

describe('API keys respect the owner account state', () => {
  beforeEach(() => {
    mockQuery.mockReset();
  });

  it('accepts a key of an active account', async () => {
    databaseWithOwner({ is_suspended: false, deleted_at: null });
    const meta = await validateApiKey(API_KEY);
    expect(meta).toEqual(expect.objectContaining({ id: 'key-1', userId: 'user-1' }));
  });

  it('refuses a key of a suspended account', async () => {
    databaseWithOwner({ is_suspended: true, deleted_at: null });
    await expect(validateApiKey(API_KEY)).rejects.toMatchObject({
      code: 'ACCOUNT_SUSPENDED',
    });
  });

  it('refuses a key of a deleted account', async () => {
    databaseWithOwner({ is_suspended: false, deleted_at: new Date() });
    expect(await validateApiKey(API_KEY)).toBeNull();
  });

  it('authenticateApiKey answers 403 ACCOUNT_SUSPENDED like the JWT path', async () => {
    databaseWithOwner({ is_suspended: true, deleted_at: null });
    const req = { headers: { 'x-api-key': API_KEY }, ip: '127.0.0.1', path: '/x' };
    const res = mockRes();
    const next = jest.fn();

    await authenticateApiKey(req, res, next);

    expect(res.statusCode).toBe(403);
    expect(res.body.code).toBe('ACCOUNT_SUSPENDED');
    expect(next).not.toHaveBeenCalled();
    expect(req.apiKey).toBeUndefined();
  });

  it('optionalApiKeyAuth does not let a suspended account through', async () => {
    databaseWithOwner({ is_suspended: true, deleted_at: null });
    const req = { headers: { 'x-api-key': API_KEY }, ip: '127.0.0.1', path: '/x' };
    const res = mockRes();
    const next = jest.fn();

    await optionalApiKeyAuth(req, res, next);

    expect(req.apiKey).toBeUndefined();
    expect(res.statusCode).toBe(403);
    expect(next).not.toHaveBeenCalled();
  });

  it('authenticateApiKey still accepts a key of an active account', async () => {
    databaseWithOwner({ is_suspended: false, deleted_at: null });
    const req = { headers: { 'x-api-key': API_KEY }, ip: '127.0.0.1', path: '/x' };
    const res = mockRes();
    const next = jest.fn();

    await authenticateApiKey(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(req.userId).toBe('user-1');
  });
});

describe('infrastructure keys are compared in constant time', () => {
  const previousKey = process.env.INFRASTRUCTURE_API_KEY;

  beforeEach(() => {
    timingSafeEqualSpy.mockClear();
    process.env.INFRASTRUCTURE_API_KEY = 'infra-secret-value';
  });

  afterEach(() => {
    if (previousKey === undefined) {
      delete process.env.INFRASTRUCTURE_API_KEY;
    } else {
      process.env.INFRASTRUCTURE_API_KEY = previousKey;
    }
  });

  it.each([
    ['authenticateInfrastructure', authenticateInfrastructure],
    ['optionalInfrastructureAuth', optionalInfrastructureAuth],
  ])('%s uses timingSafeEqual and rejects a wrong key', (_name, middleware) => {
    const req = { headers: { 'x-infrastructure-key': 'short' }, ip: '127.0.0.1' };
    const res = mockRes();
    const next = jest.fn();

    middleware(req, res, next);

    expect(timingSafeEqualSpy).toHaveBeenCalled();
    const [a, b] = timingSafeEqualSpy.mock.calls[0];
    expect(a.length).toBe(b.length);
    expect(res.statusCode).toBe(401);
    expect(next).not.toHaveBeenCalled();
  });

  it.each([
    ['authenticateInfrastructure', authenticateInfrastructure],
    ['optionalInfrastructureAuth', optionalInfrastructureAuth],
  ])('%s accepts the right key', (_name, middleware) => {
    const req = {
      headers: { 'x-infrastructure-key': 'infra-secret-value' },
      ip: '127.0.0.1',
    };
    const res = mockRes();
    const next = jest.fn();

    middleware(req, res, next);

    expect(timingSafeEqualSpy).toHaveBeenCalled();
    expect(next).toHaveBeenCalled();
  });
});
