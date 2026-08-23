/**
 * Route-level integration tests for /cloud connector endpoints.
 * DB pool and JWT auth are mocked; exercises the real express router,
 * zod validation, and status-code contract.
 */

import { jest } from '@jest/globals';

const mockPool = { query: jest.fn() };

jest.unstable_mockModule(
  '../../services/api-backend/database/db-pool.js',
  () => ({
    initializePool: jest.fn(async () => mockPool),
    getPool: jest.fn(() => mockPool),
    query: jest.fn((...args) => mockPool.query(...args)),
    closePool: jest.fn(async () => {}),
  }),
);

jest.unstable_mockModule(
  '../../services/api-backend/middleware/auth.js',
  () => ({
    authenticateJWT: (req, res, next) => {
      req.user = { sub: 'auth0|test-user' };
      next();
    },
    extractUserId: (req) => req.user?.sub ?? 'auth0|test-user',
    checkJwt: (_req, _res, next) => next(),
    syncSession: (_req, _res, next) => next(),
    requireScope: () => (_req, _res, next) => next(),
  }),
);

process.env.NODE_ENV = 'test';

const request = (await import('supertest')).default;
const express = (await import('express')).default;
const cloudConnectorRoutes = (
  await import('../../services/api-backend/routes/cloud-connector.js')
).default;
const { initializeCloudConnectorService } = await import(
  '../../services/api-backend/routes/cloud-connector.js'
);

describe('Cloud connector routes', () => {
  let app;

  beforeAll(async () => {
    await initializeCloudConnectorService();
    app = express();
    app.use(express.json());
    app.use('/api/cloud', cloudConnectorRoutes);
  });

  beforeEach(() => {
    mockPool.query.mockReset();
    // Default: user-uuid lookup + generic single-row responses
    mockPool.query.mockImplementation(async () => ({
      rows: [{ id: 'user-uuid' }],
      rowCount: 1,
    }));
  });

  const deviceRow = {
    id: 'uuid-1',
    device_id: 'abcdef1234567890',
    device_name: 'linux-device',
    platform: 'linux',
    runtime_location: 'local',
    capabilities: {},
    status: 'online',
    last_seen: new Date().toISOString(),
    runtime_available: false,
  };

  describe('POST /devices', () => {
    it('registers a valid device', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [{ id: 'user-uuid' }] })
        .mockResolvedValueOnce({ rows: [deviceRow] })
        .mockResolvedValueOnce({ rows: [{ last_seen: new Date() }] });

      const res = await request(app)
        .post('/api/cloud/devices')
        .send({
          device_id: 'abcdef1234567890',
          runtime_location: 'local',
          capabilities: {},
        })
        .expect(201);

      expect(res.body.data.device_id).toBe('abcdef1234567890');
    });

    it('rejects a short device_id with 400', async () => {
      const res = await request(app)
        .post('/api/cloud/devices')
        .send({ device_id: 'short' })
        .expect(400);
      expect(res.body.error).toBeDefined();
    });

    it('rejects an invalid runtime_location with 400', async () => {
      await request(app)
        .post('/api/cloud/devices')
        .send({
          device_id: 'abcdef1234567890',
          runtime_location: 'bogus',
        })
        .expect(400);
    });
  });

  describe('POST /devices/heartbeat', () => {
    it('records presence for a registered device', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [{ id: 'uuid-1' }] })
        .mockResolvedValueOnce({ rows: [{ last_seen: new Date() }] });

      await request(app)
        .post('/api/cloud/devices/heartbeat')
        .send({
          device_id: 'abcdef1234567890',
          runtime_available: true,
          metadata: {},
        })
        .expect(200);
    });

    it('returns 404 for an unregistered device', async () => {
      mockPool.query.mockResolvedValueOnce({ rows: [] });

      const res = await request(app)
        .post('/api/cloud/devices/heartbeat')
        .send({ device_id: 'unknown000000000' })
        .expect(404);
      expect(res.body.error).toBeDefined();
    });
  });

  describe('GET /devices', () => {
    it('lists the user devices', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [{ id: 'user-uuid' }] })
        .mockResolvedValueOnce({ rows: [deviceRow] });

      const res = await request(app).get('/api/cloud/devices').expect(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data[0].device_id).toBe('abcdef1234567890');
    });
  });

  describe('POST /relay', () => {
    it('allows a syncable scope without device targeting', async () => {
      const res = await request(app)
        .post('/api/cloud/relay')
        .send({ scope: 'channel_history', payload: {} })
        .expect(200);
      expect(res.body.data.syncable).toBe(true);
    });

    it('rejects a device-scoped scope missing target with 404', async () => {
      const res = await request(app)
        .post('/api/cloud/relay')
        .send({ scope: 'screen_capture', payload: {} })
        .expect(404);
      expect(res.body.code).toBe('MISSING_TARGET_DEVICE');
    });

    it('rejects unknown target device with 404', async () => {
      mockPool.query.mockResolvedValueOnce({ rows: [{ id: 'user-uuid' }] });
      mockPool.query.mockResolvedValueOnce({ rows: [] }); // _getUserDevice

      const res = await request(app)
        .post('/api/cloud/relay')
        .send({
          scope: 'shell_commands',
          target_device_id: 'unknown000000000',
          payload: {},
        })
        .expect(404);
      expect(res.body.code).toBe('TARGET_DEVICE_NOT_FOUND');
    });

    it('allows relay to an online target device', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [{ id: 'user-uuid' }] })
        .mockResolvedValueOnce({
          rows: [{ id: 'uuid-1', status: 'online' }],
        });

      const res = await request(app)
        .post('/api/cloud/relay')
        .send({
          scope: 'clipboard',
          target_device_id: 'abcdef1234567890',
          payload: {},
        })
        .expect(200);
      expect(res.body.data.requiresTargetDevice).toBe(true);
      expect(res.body.data.targetDeviceId).toBe('abcdef1234567890');
    });

    it('returns 409 for an offline target device', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [{ id: 'user-uuid' }] })
        .mockResolvedValueOnce({
          rows: [{ id: 'uuid-1', status: 'offline' }],
        });

      const res = await request(app)
        .post('/api/cloud/relay')
        .send({
          scope: 'file_operations',
          target_device_id: 'abcdef1234567890',
          payload: {},
        })
        .expect(409);
      expect(res.body.code).toBe('TARGET_DEVICE_OFFLINE');
    });
  });

  describe('GET /sync-scopes', () => {
    it('exposes the syncable scope list', async () => {
      const res = await request(app).get('/api/cloud/sync-scopes').expect(200);
      expect(res.body.data.syncable).toContain('channel_history');
      expect(res.body.data.syncable).not.toContain('screen_capture');
    });
  });

  describe('POST /tailscale/join-token + /tailscale/join', () => {
    it('issues a join token, then redeems it for a container spec', async () => {
      const issued = await request(app)
        .post('/api/cloud/tailscale/join-token')
        .send({})
        .expect(201);
      expect(issued.body.data.token).toBeDefined();

      const joined = await request(app)
        .post('/api/cloud/tailscale/join')
        .send({ token: issued.body.data.token })
        .expect(200);
      expect(joined.body.data.containerName).toContain('pistisai-connector-');
      expect(joined.body.data.tailscale.tags).toContain(
        'tag:pistisai-connector',
      );
      expect(joined.body.data.constraints.scope).toBe('single_user');
    });

    it('rejects reuse of a join token (single-use)', async () => {
      const issued = await request(app)
        .post('/api/cloud/tailscale/join-token')
        .send({})
        .expect(201);
      await request(app)
        .post('/api/cloud/tailscale/join')
        .send({ token: issued.body.data.token })
        .expect(200);
      const res = await request(app)
        .post('/api/cloud/tailscale/join')
        .send({ token: issued.body.data.token })
        .expect(403);
      expect(res.body.code).toBe('INVALID_JOIN_TOKEN');
    });

    it('rejects a bogus token with 403', async () => {
      const res = await request(app)
        .post('/api/cloud/tailscale/join')
        .send({ token: 'not-a-real-token-value' })
        .expect(403);
      expect(res.body.code).toBe('INVALID_JOIN_TOKEN');
    });
  });

  describe('DELETE /devices/:deviceId', () => {
    it('revokes a device', async () => {
      mockPool.query
        .mockResolvedValueOnce({ rows: [{ id: 'user-uuid' }] })
        .mockResolvedValueOnce({ rows: [{ id: 'uuid-1', user_id: 'u' }] })
        .mockResolvedValueOnce({ rowCount: 1 })
        .mockResolvedValueOnce({ rowCount: 1 });

      await request(app)
        .delete('/api/cloud/devices/abcdef1234567890')
        .expect(200);
    });
  });
});
