/**
 * Subagent registry ownership (Cursor HIGH finding, 2026-11-24).
 *
 * A signed-in user must only list, read, overwrite and delete their own
 * registry rows. The original routes were JWT-only: every row was visible and
 * mutable by every authenticated caller.
 */
import { jest, describe, it, expect, beforeAll, beforeEach } from '@jest/globals';

const VICTIM_OWNER = 'victim-sub';
const victimRow = {
  id: 'row-1',
  subagent_id: 'victim-agent',
  label: 'Victim agent',
  agent_id: 'parent-agent',
  task: 'secret prompt belonging to the victim',
  status: 'completed',
  created_at: new Date().toISOString(),
  started_at: null,
  completed_at: new Date().toISOString(),
  result_json: { secret: true },
  logs: 'victim execution logs',
  error_message: null,
  user_id: VICTIM_OWNER,
};

const mockDb = { query: jest.fn() };

jest.unstable_mockModule(
  '../../../services/api-backend/database/db-pool.js',
  () => ({ default: mockDb, getPool: jest.fn(() => mockDb) }),
);

jest.unstable_mockModule(
  '../../../services/api-backend/middleware/auth.js',
  () => ({
    authenticateJWT: (req, _res, next) => {
      const header = req.headers['x-test-sub'];
      req.user = {
        sub: header === 'none' ? null : header || 'owner-sub',
      };
      req.auth = { payload: req.user };
      next();
    },
  }),
);

jest.unstable_mockModule(
  '../../../services/api-backend/middleware/schema-validation.js',
  () => ({ validateSchema: () => (_req, _res, next) => next() }),
);

jest.unstable_mockModule(
  '../../../services/api-backend/routes/misc-body-schemas.js',
  () => ({
    validateBody: () => (_req, _res, next) => next(),
    subagentMetadataBody: {},
  }),
);

jest.unstable_mockModule(
  '../../../services/api-backend/utils/logger.js',
  () => ({
    TunnelLogger: class {
      info() {}
      warn() {}
      error() {}
      debug() {}
    },
  }),
);

process.env.NODE_ENV = 'test';

let app;
let request;

/** Mimic Postgres honouring the owner predicate in each generated query. */
function ownerArg(sql, params) {
  if (sql.includes('INSERT INTO subagent_registry')) return params[4];
  if (sql.includes('SELECT id, subagent_id')) return params[0]; // list
  if (sql.includes('SELECT * FROM subagent_registry')) return params[1];
  if (sql.includes('DELETE FROM subagent_registry')) return params[1];
  return params[params.length - 1]; // status + metadata UPDATEs
}

beforeAll(async () => {
  const express = (await import('express')).default;
  const router = (
    await import('../../../services/api-backend/routes/subagent-registry-routes.js')
  ).default;
  request = (await import('supertest')).default;
  app = express();
  app.use(express.json());
  app.use('/api/admin/subagents', router);
});

beforeEach(() => {
  mockDb.query.mockReset();
  mockDb.query.mockImplementation(async (sql, params = []) => {
    if (!sql.includes('subagent_registry')) return { rows: [], rowCount: 0 };
    const owned = ownerArg(sql, params) === VICTIM_OWNER;
    if (sql.includes('INSERT INTO')) return { rows: owned ? [victimRow] : [] };
    if (owned) return { rows: [victimRow], rowCount: 1 };
    return { rows: [], rowCount: 0 };
  });
});

const lastQuery = () => mockDb.query.mock.calls.at(-1);
const asVictim = (r) => r.set('x-test-sub', VICTIM_OWNER);
const asAttacker = (r) => r.set('x-test-sub', 'attacker-sub');

describe('subagent registry ownership (Cursor HIGH finding)', () => {
  it('GET / never returns another user\'s task, result or logs', async () => {
    const res = await asAttacker(request(app).get('/api/admin/subagents')).expect(200);
    expect(res.body.subagents).toEqual([]);

    const [sql, params] = lastQuery();
    expect(sql).toContain('WHERE user_id = $1');
    expect(params[0]).toBe('attacker-sub');
  });

  it('GET / returns the caller\'s own rows', async () => {
    const res = await asVictim(request(app).get('/api/admin/subagents')).expect(200);
    expect(res.body.subagents).toHaveLength(1);
    expect(res.body.subagents[0].logs).toBe('victim execution logs');
  });

  it('GET /:id does not disclose another user\'s row', async () => {
    await asAttacker(request(app).get('/api/admin/subagents/victim-agent')).expect(404);
    const [sql, params] = lastQuery();
    expect(sql).toContain('AND user_id = $2');
    expect(params[1]).toBe('attacker-sub');
  });

  it('POST cannot reset a row owned by another user', async () => {
    const res = await asAttacker(request(app)
      .post('/api/admin/subagents')
      .send({ subagentId: 'victim-agent', agentId: 'parent-agent', task: 'hijack' }))
      .expect(409);

    expect(res.body.code).toBe('SUBAGENT_ID_CONFLICT');
    const [sql, params] = lastQuery();
    expect(sql).toContain('WHERE subagent_registry.user_id = EXCLUDED.user_id');
    expect(params[4]).toBe('attacker-sub');
  });

  it('POST records the caller as owner on a new row', async () => {
    mockDb.query.mockImplementationOnce(async () => ({
      rows: [{ ...victimRow, user_id: 'attacker-sub' }],
    }));
    await asAttacker(request(app)
      .post('/api/admin/subagents')
      .send({ subagentId: 'fresh-agent', agentId: 'parent-agent' }))
      .expect(200);

    const [usedSql, usedParams] = lastQuery();
    expect(usedSql).toContain('INSERT INTO subagent_registry');
    expect(usedParams[4]).toBe('attacker-sub');
  });

  it('PATCH status cannot change another user\'s row', async () => {
    await asAttacker(request(app)
      .patch('/api/admin/subagents/victim-agent/status')
      .send({ status: 'completed', logs: 'poisoned' }))
      .expect(404);

    const [sql, params] = lastQuery();
    expect(sql).toContain('AND user_id = $');
    expect(params.at(-1)).toBe('attacker-sub');
  });

  it('PATCH metadata cannot rewrite another user\'s task', async () => {
    await asAttacker(request(app)
      .patch('/api/admin/subagents/victim-agent/metadata')
      .send({ task: 'overwritten' }))
      .expect(404);

    const [sql, params] = lastQuery();
    expect(sql).toContain('AND user_id = $');
    expect(params.at(-1)).toBe('attacker-sub');
  });

  it('DELETE cannot remove another user\'s row', async () => {
    await asAttacker(request(app)
      .delete('/api/admin/subagents/victim-agent'))
      .expect(404);

    const [sql, params] = lastQuery();
    expect(sql).toContain('DELETE FROM subagent_registry WHERE subagent_id = $1 AND user_id = $2');
    expect(params[1]).toBe('attacker-sub');
  });

  it('owner can update and delete their own row', async () => {
    await asVictim(request(app)
      .patch('/api/admin/subagents/victim-agent/status')
      .send({ status: 'completed' }))
      .expect(200);
    await asVictim(request(app)
      .delete('/api/admin/subagents/victim-agent'))
      .expect(200);
  });

  it('fails closed when the JWT has no sub claim', async () => {
    await request(app)
      .get('/api/admin/subagents')
      .set('x-test-sub', 'none')
      .expect(401);
    await request(app)
      .delete('/api/admin/subagents/victim-agent')
      .set('x-test-sub', 'none')
      .expect(401);
  });
});
