/**
 * AuthService session and signing-key hardening:
 * - trimming old sessions keeps revoked rows until they expire,
 * - logout can end the session of one exact token,
 * - malformed or unknown key ids do not trigger repeated JWKS fetches.
 */
import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import crypto from 'crypto';

// Record the options AuthService passes to the JWKS client.
const jwksClientOptions = [];
jest.unstable_mockModule('jwks-rsa', () => ({
  default: (options) => {
    jwksClientOptions.push(options);
    return { getSigningKey: jest.fn() };
  },
}));

const { AuthService } = await import(
  '../../services/api-backend/auth/auth-service.js'
);

function quietService() {
  const auth = new AuthService({});
  auth.logger = { info: jest.fn(), warn: jest.fn(), error: jest.fn() };
  auth.logSecurityEvent = jest.fn(async () => {});
  return auth;
}

describe('AuthService.cleanupUserSessions keeps revoked sessions', () => {
  it('only trims active sessions beyond the per-user limit', async () => {
    const auth = quietService();
    auth.runQuery = jest.fn(async () => ({ changes: 0 }));

    await auth.cleanupUserSessions('user-1');

    const deletes = auth.runQuery.mock.calls
      .map(([sql, params]) => ({ sql: sql.replace(/\s+/g, ' '), params }))
      .filter(({ sql }) => /DELETE FROM user_sessions/i.test(sql));
    expect(deletes.length).toBeGreaterThan(0);

    for (const { sql } of deletes) {
      // Every delete either targets active rows only, or expired rows only.
      const activeOnly = /WHERE user_id = \$1 AND is_active = true/i.test(sql);
      const expiredOnly = /WHERE expires_at < NOW\(\)\s*$/i.test(sql.trim());
      expect(activeOnly || expiredOnly).toBe(true);
    }

    const trim = deletes.find(({ sql }) => /NOT IN/i.test(sql));
    expect(trim).toBeDefined();
    // The kept set is counted among active sessions, so revoked rows neither
    // get deleted nor push active rows out.
    expect(trim.sql).toMatch(
      /SELECT id FROM user_sessions WHERE user_id = \$1 AND is_active = true ORDER BY last_activity DESC LIMIT \$2/i,
    );
    expect(trim.params).toEqual(['user-1', auth.config.MAX_SESSIONS_PER_USER]);
  });

  it('a revoked session is returned as is and no new active one is created', async () => {
    const auth = quietService();
    auth.resolveUserId = jest.fn(async () => 'user-1');
    const revoked = { id: 's-1', is_active: false };
    auth.runQuery = jest.fn(async (sql) =>
      /^SELECT \* FROM user_sessions/.test(sql) ? revoked : { changes: 1 },
    );
    auth.cleanupUserSessions = jest.fn();

    const session = await auth.createOrUpdateSession(
      { sub: 'sub-1', exp: Math.floor(Date.now() / 1000) + 600 },
      'token-1',
      {},
    );

    expect(session).toBe(revoked);
    expect(auth.cleanupUserSessions).not.toHaveBeenCalled();
    expect(
      auth.runQuery.mock.calls.some(([sql]) => /INSERT INTO user_sessions/.test(sql)),
    ).toBe(false);
  });
});

describe('AuthService.revokeSessionByToken', () => {
  it('deactivates the session matching the token hash of the caller', async () => {
    const auth = quietService();
    auth.resolveUserId = jest.fn(async () => 'user-1');
    auth.runQuery = jest.fn(async () => ({ changes: 1 }));

    const ok = await auth.revokeSessionByToken('sub-1', 'token-1', {
      email: 'user@example.com',
    });

    expect(ok).toBe(true);
    const [sql, params] = auth.runQuery.mock.calls[0];
    expect(sql).toMatch(/UPDATE user_sessions SET is_active = false/);
    expect(sql).toMatch(/jwt_token_hash = \$2/);
    expect(params).toEqual([
      'user-1',
      crypto.createHash('sha256').update('token-1').digest('hex'),
    ]);
  });

  it('reports false when no active session matched', async () => {
    const auth = quietService();
    auth.resolveUserId = jest.fn(async () => 'user-1');
    auth.runQuery = jest.fn(async () => ({ changes: 0 }));
    expect(await auth.revokeSessionByToken('sub-1', 'token-1')).toBe(false);
  });
});

describe('AuthService.getKey and the JWKS client', () => {
  const previousDomain = process.env.CF_ACCESS_TEAM_DOMAIN;

  beforeEach(() => {
    process.env.CF_ACCESS_TEAM_DOMAIN = 'team.example.com';
  });

  afterEach(() => {
    if (previousDomain === undefined) {
      delete process.env.CF_ACCESS_TEAM_DOMAIN;
    } else {
      process.env.CF_ACCESS_TEAM_DOMAIN = previousDomain;
    }
  });

  function serviceWithFakeJwks(impl) {
    const auth = quietService();
    auth.jwksClient = { getSigningKey: jest.fn(impl) };
    return auth;
  }

  function getKey(auth, header) {
    return new Promise((resolve) => {
      auth.getKey(header, (err, key) => resolve({ err, key }));
    });
  }

  it('configures a long-lived key cache in front of the rate limiter', () => {
    jwksClientOptions.length = 0;
    quietService();
    const opts = jwksClientOptions[0];
    expect(opts.cache).toBe(true);
    expect(opts.cacheMaxAge).toBeGreaterThanOrEqual(60 * 60 * 1000);
    expect(opts.cacheMaxEntries).toBeGreaterThanOrEqual(1);
    expect(opts.rateLimit).toBe(true);
  });

  it.each([
    ['missing', {}],
    ['not a string', { kid: 42 }],
    ['empty', { kid: '' }],
    ['too long', { kid: 'a'.repeat(300) }],
    ['with odd characters', { kid: 'abc def<script>' }],
  ])('rejects a kid that is %s without fetching keys', async (_label, header) => {
    const auth = serviceWithFakeJwks((_kid, cb) => cb(null, { getPublicKey: () => 'k' }));
    const { err } = await getKey(auth, header);
    expect(err).toBeInstanceOf(Error);
    expect(auth.jwksClient.getSigningKey).not.toHaveBeenCalled();
  });

  it('remembers a kid the JWKS does not contain and does not refetch it', async () => {
    const auth = serviceWithFakeJwks((_kid, cb) => {
      const err = new Error('Unable to find a signing key that matches');
      err.name = 'SigningKeyNotFoundError';
      cb(err);
    });

    const first = await getKey(auth, { kid: 'unknownkid01' });
    const second = await getKey(auth, { kid: 'unknownkid01' });

    expect(first.err).toBeInstanceOf(Error);
    expect(second.err).toBeInstanceOf(Error);
    expect(auth.jwksClient.getSigningKey).toHaveBeenCalledTimes(1);
  });

  it('does not remember a kid after a transient fetch error', async () => {
    const auth = serviceWithFakeJwks((_kid, cb) => cb(new Error('network down')));

    await getKey(auth, { kid: 'goodkid01' });
    await getKey(auth, { kid: 'goodkid01' });

    expect(auth.jwksClient.getSigningKey).toHaveBeenCalledTimes(2);
  });

  it('keeps the unknown-kid cache bounded', async () => {
    const auth = serviceWithFakeJwks((_kid, cb) => {
      const err = new Error('not found');
      err.name = 'SigningKeyNotFoundError';
      cb(err);
    });
    for (let i = 0; i < 1100; i++) {
      await getKey(auth, { kid: `kid${i}` });
    }
    expect(auth.unknownKids.size).toBeLessThanOrEqual(1000);
  });

  it('returns the public key for a known kid', async () => {
    const auth = serviceWithFakeJwks((_kid, cb) =>
      cb(null, { getPublicKey: () => 'public-key' }),
    );
    const { err, key } = await getKey(auth, {
      kid: 'b5f4c9d1e2a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d',
    });
    expect(err).toBeNull();
    expect(key).toBe('public-key');
  });
});
