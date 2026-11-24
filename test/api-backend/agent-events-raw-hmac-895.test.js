/**
 * #895: the agent-events webhook HMAC must cover the raw request body bytes,
 * not JSON.stringify(req.body). Exercised through the real middleware
 * pipeline (global JSON parser) and the real agent-events router, mounted
 * the way server.js mounts it.
 */
import {
  describe,
  it,
  expect,
  beforeAll,
  beforeEach,
  afterAll,
  jest,
} from '@jest/globals';
import crypto from 'crypto';

const SECRET = 'test-openclaw-webhook-secret';

const mockQuery = jest.fn();

jest.unstable_mockModule(
  '../../services/api-backend/database/db-pool.js',
  () => ({
    getPool: () => ({ query: mockQuery }),
    default: { getPool: () => ({ query: mockQuery }) },
  }),
);

jest.unstable_mockModule(
  '../../services/api-backend/websocket/dashboard-ws.js',
  () => ({
    default: { broadcast: jest.fn() },
  }),
);

const { default: express } = await import('express');
const { default: request } = await import('supertest');
const { setupMiddlewarePipeline } = await import(
  '../../services/api-backend/middleware/pipeline.js'
);
const { default: agentEventsRoutes } = await import(
  '../../services/api-backend/routes/agent-events.js'
);

function sign(raw, secret = SECRET) {
  return crypto.createHmac('sha256', secret).update(raw).digest('hex');
}

function buildApp() {
  const app = express();
  setupMiddlewarePipeline(app);
  // Same mounting as registerRoutes('/agent/events', ...) in server.js.
  app.use('/api/agent/events', agentEventsRoutes);
  app.use('/agent/events', agentEventsRoutes);
  return app;
}

// Valid JSON whose bytes differ from JSON.stringify(JSON.parse(raw)):
// extra whitespace and an escaped character.
const RAW_BODY =
  '{ "agent_id" : "agent-1",\n  "event_type": "tool:start",' +
  ' "event_data": { "agent_name": "caf\\u00e9" } }';

describe('agent-events webhook raw-body HMAC (#895)', () => {
  let app;
  let savedSecret;

  beforeAll(() => {
    savedSecret = process.env.OPENCLAW_WEBHOOK_SECRET;
    app = buildApp();
  });

  afterAll(() => {
    if (savedSecret === undefined) {
      delete process.env.OPENCLAW_WEBHOOK_SECRET;
    } else {
      process.env.OPENCLAW_WEBHOOK_SECRET = savedSecret;
    }
  });

  beforeEach(() => {
    process.env.OPENCLAW_WEBHOOK_SECRET = SECRET;
    mockQuery.mockReset();
    mockQuery.mockImplementation(async (sql) => {
      if (/SELECT \* FROM agents/.test(sql)) {
        return {
          rows: [{ id: 7, agent_id: 'agent-1', name: 'a', user_id: null }],
        };
      }
      return { rows: [] };
    });
  });

  it('sanity: the raw body differs from its re-serialized form', () => {
    expect(JSON.stringify(JSON.parse(RAW_BODY))).not.toBe(RAW_BODY);
  });

  it.each(['/api/agent/events', '/agent/events'])(
    'accepts a signature over the exact raw bytes on %s',
    async (path) => {
      const res = await request(app)
        .post(path)
        .set('Content-Type', 'application/json')
        .set('x-openclaw-signature', sign(RAW_BODY))
        .send(RAW_BODY);

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ success: true, agent_id: 7 });
      expect(mockQuery).toHaveBeenCalled();
    },
  );

  it('rejects a signature over the re-serialized JSON', async () => {
    const reserialized = JSON.stringify(JSON.parse(RAW_BODY));
    const res = await request(app)
      .post('/api/agent/events')
      .set('Content-Type', 'application/json')
      .set('x-openclaw-signature', sign(reserialized))
      .send(RAW_BODY);

    expect(res.status).toBe(401);
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('rejects a missing or wrong signature', async () => {
    const missing = await request(app)
      .post('/api/agent/events')
      .set('Content-Type', 'application/json')
      .send(RAW_BODY);
    expect(missing.status).toBe(401);

    const wrong = await request(app)
      .post('/api/agent/events')
      .set('Content-Type', 'application/json')
      .set('x-openclaw-signature', sign(RAW_BODY, 'other-secret'))
      .send(RAW_BODY);
    expect(wrong.status).toBe(401);
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('fails closed when OPENCLAW_WEBHOOK_SECRET is not set', async () => {
    delete process.env.OPENCLAW_WEBHOOK_SECRET;
    const res = await request(app)
      .post('/api/agent/events')
      .set('Content-Type', 'application/json')
      .set('x-openclaw-signature', sign(RAW_BODY))
      .send(RAW_BODY);

    expect(res.status).toBe(500);
    expect(mockQuery).not.toHaveBeenCalled();
  });

  it('fails closed when the raw body was not captured', async () => {
    // A JSON parser without the captureRawBody hook: the route must not fall
    // back to re-serializing req.body, even for a matching signature.
    const bare = express();
    bare.use(express.json());
    bare.use('/api/agent/events', agentEventsRoutes);
    const reserialized = JSON.stringify(JSON.parse(RAW_BODY));

    const res = await request(bare)
      .post('/api/agent/events')
      .set('Content-Type', 'application/json')
      .set('x-openclaw-signature', sign(reserialized))
      .send(reserialized);

    expect(res.status).toBe(401);
    expect(mockQuery).not.toHaveBeenCalled();
  });
});
