/**
 * Session endpoints must be scoped to the authenticated caller. A valid JWT
 * for account A plus a stolen session token from account B must not read,
 * overwrite or invalidate B's session (Cursor HIGH finding, 2026-11-24).
 */
import { jest, describe, it, expect, beforeAll, beforeEach } from '@jest/globals';

const mockDb = { query: jest.fn() };
let callerUserId = 'user-owner';
const victimOwnerId = 'user-owner';

const victimSession = {
  id: 'session-1',
  session_token: 'victim-token',
  expires_at: new Date(Date.now() + 60000).toISOString(),
  jwt_access_token: 'victim-access',
  jwt_id_token: 'victim-id',
  refresh_token: 'victim-refresh',
  created_at: new Date().toISOString(),
  last_activity: new Date().toISOString(),
  is_active: true,
  jwt_id: 'victim-sub',
  email: 'victim@example.com',
  name: 'Victim',
  nickname: 'victim',
  picture: null,
};

jest.unstable_mockModule(
  '../../../services/api-backend/database/db-pool.js',
  () => ({ default: mockDb, getPool: jest.fn(() => mockDb) }),
);

jest.unstable_mockModule(
  '../../../services/api-backend/middleware/auth.js',
  () => ({
    authenticateJWT: (req, _res, next) => {
      // No req.auth.session on purpose: the owner must be resolved from sub.
      req.user = { sub: req.headers['x-test-sub'] || 'owner-sub' };
      next();
    },
  }),
);

jest.unstable_mockModule(
  '../../../services/api-backend/middleware/schema-validation.js',
  () => ({ validateSchema: () => (_req, _res, next) => next() }),
);

jest.unstable_mockModule('../../../services/api-backend/logger.js', () => ({
  default: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

process.env.NODE_ENV = 'test';

let app;
let request;

beforeAll(async () => {
  const express = (await import('express')).default;
  const router = (
    await import('../../../services/api-backend/routes/sessions.js')
  ).default;
  request = (await import('supertest')).default;
  app = express();
  app.use(express.json());
  app.use('/auth/sessions', router);
});

beforeEach(() => {
  mockDb.query.mockReset();
  callerUserId = 'user-owner';
  mockDb.query.mockImplementation(async (sql, params) => {
    if (sql.includes('FROM users u')) {
      return { rows: [{ id: callerUserId }] };
    }
    if (sql.includes('FROM user_sessions s')) {
      // The DB returns the victim row only when the caller is its real owner.
      const owned = params[1] === victimOwnerId;
      return { rows: owned ? [victimSession] : [] };
    }
    if (sql.includes('SET jwt_access_token')) {
      const owned = params[4] === victimOwnerId;
      return owned ? { rows: [{ id: 'session-1' }] } : { rows: [] };
    }
    if (sql.includes('SET is_active = false')) {
      const owned = params[1] === victimOwnerId;
      return { rowCount: owned ? 1 : 0 };
    }
    return { rows: [], rowCount: 0 };
  });
});

const sessionCalls = () =>
  mockDb.query.mock.calls.filter(([sql]) => sql.includes('user_sessions'));

describe('session ownership (Cursor HIGH finding)', () => {
  it('GET validate returns the session only to its owner', async () => {
    const res = await request(app)
      .get('/auth/sessions/validate/victim-token')
      .set('x-test-sub', 'owner-sub')
      .expect(200);

    expect(res.body.session.refreshToken).toBe('victim-refresh');
    const [sql, params] = sessionCalls()[0];
    expect(sql).toMatch(/s\.user_id = \$2/);
    expect(params).toEqual(['victim-token', 'user-owner']);
  });

  it('GET validate with a stolen token from another account returns 404 and no tokens', async () => {
    callerUserId = 'user-attacker';
    const res = await request(app)
      .get('/auth/sessions/validate/victim-token')
      .set('x-test-sub', 'attacker-sub')
      .expect(404);

    expect(res.body).not.toHaveProperty('session');
    expect(JSON.stringify(res.body)).not.toContain('victim-refresh');
    expect(sessionCalls()[0][1]).toEqual(['victim-token', 'user-attacker']);
  });

  it('POST validate accepts the token in the body, still owner-scoped', async () => {
    const res = await request(app)
      .post('/auth/sessions/validate')
      .set('x-test-sub', 'owner-sub')
      .send({ sessionToken: 'victim-token' })
      .expect(200);

    expect(res.body.session.jwtAccessToken).toBe('victim-access');
    expect(sessionCalls()[0][1]).toEqual(['victim-token', 'user-owner']);
  });

  it('PUT tokens cannot overwrite another account\'s stored IdP tokens', async () => {
    callerUserId = 'user-attacker';
    await request(app)
      .put('/auth/sessions/tokens')
      .set('x-test-sub', 'attacker-sub')
      .send({
        sessionToken: 'victim-token',
        accessToken: 'attacker-access',
        refreshToken: 'attacker-refresh',
      })
      .expect(404);

    const [sql, params] = sessionCalls()[0];
    expect(sql).toMatch(/user_id = \$5/);
    expect(params).toEqual([
      'attacker-access',
      undefined,
      'attacker-refresh',
      'victim-token',
      'user-attacker',
    ]);
  });

  it('DELETE legacy route cannot invalidate another account\'s session', async () => {
    callerUserId = 'user-attacker';
    await request(app)
      .delete('/auth/sessions/victim-token')
      .set('x-test-sub', 'attacker-sub')
      .expect(404);

    const [sql, params] = sessionCalls()[0];
    expect(sql).toMatch(/session_token = \$1 AND user_id = \$2/);
    expect(params).toEqual(['victim-token', 'user-attacker']);
  });

  it('POST invalidate cannot invalidate another account\'s session', async () => {
    callerUserId = 'user-attacker';
    await request(app)
      .post('/auth/sessions/invalidate')
      .set('x-test-sub', 'attacker-sub')
      .send({ sessionToken: 'victim-token' })
      .expect(404);

    expect(sessionCalls()[0][1]).toEqual(['victim-token', 'user-attacker']);
  });

  it('rejects a request with no resolvable identity', async () => {
    mockDb.query.mockImplementation(async () => ({ rows: [] }));
    await request(app)
      .get('/auth/sessions/validate/victim-token')
      .expect(401);
  });
});
