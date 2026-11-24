/**
 * A device_id is globally unique; registration by another user must never
 * reassign ownership of an existing row (Cursor HIGH finding, 2026-11-24).
 */
import { jest, describe, it, expect, beforeAll, beforeEach } from '@jest/globals';

const mockPool = { query: jest.fn() };

jest.unstable_mockModule(
  '../../../services/api-backend/database/db-pool.js',
  () => ({
    initializePool: jest.fn(async () => mockPool),
    getPool: jest.fn(() => mockPool),
    query: jest.fn((...args) => mockPool.query(...args)),
    closePool: jest.fn(async () => {}),
  }),
);

jest.unstable_mockModule(
  '../../../services/api-backend/middleware/auth.js',
  () => ({
    authenticateJWT: (req, _res, next) => {
      req.user = { sub: 'attacker-sub' };
      next();
    },
    extractUserId: () => 'attacker-sub',
    checkJwt: (_req, _res, next) => next(),
    syncSession: (_req, _res, next) => next(),
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

const { CloudConnectorService } = await import(
  '../../../services/api-backend/services/cloud-connector-service.js'
);
const request = (await import('supertest')).default;
const express = (await import('express')).default;
const routesModule = await import(
  '../../../services/api-backend/routes/cloud-connector.js'
);

describe('CloudConnectorService device ownership', () => {
  let service;

  beforeEach(() => {
    mockPool.query.mockReset();
    service = new CloudConnectorService();
    service.pool = mockPool;
  });

  it('does not reassign user_id on device_id conflict', async () => {
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'dev-uuid' }] })
      .mockResolvedValueOnce({ rows: [{ last_seen: new Date() }] });

    await service.registerDevice('owner-id', {
      deviceId: 'victim-device-id',
      runtimeLocation: 'local',
      capabilities: {},
    });

    const [sql] = mockPool.query.mock.calls[0];
    expect(sql).toContain('ON CONFLICT (device_id) DO UPDATE SET');
    expect(sql).not.toMatch(/DO UPDATE SET\s+user_id\s*=/);
    expect(sql).toMatch(/WHERE cloud_devices\.user_id = EXCLUDED\.user_id/);
  });

  it('rejects a device id already owned by another user', async () => {
    mockPool.query.mockResolvedValueOnce({ rows: [] });

    await expect(
      service.registerDevice('attacker-id', {
        deviceId: 'victim-device-id',
        runtimeLocation: 'local',
        capabilities: {},
      }),
    ).rejects.toMatchObject({ code: 'DEVICE_ID_CONFLICT' });

    // Presence must not be created for a device we do not own.
    expect(mockPool.query).toHaveBeenCalledTimes(1);
  });

  it('still upserts the same user\'s own device', async () => {
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'dev-uuid' }] })
      .mockResolvedValueOnce({ rows: [{ last_seen: new Date() }] });

    const device = await service.registerDevice('owner-id', {
      deviceId: 'own-device-id',
      runtimeLocation: 'local',
      capabilities: {},
    });
    expect(device.id).toBe('dev-uuid');
    expect(mockPool.query).toHaveBeenCalledTimes(2);
  });
});

describe('POST /api/cloud/devices ownership conflict', () => {
  let app;

  beforeAll(async () => {
    await routesModule.initializeCloudConnectorService();
    app = express();
    app.use(express.json());
    app.use('/api/cloud', routesModule.default);
  });

  beforeEach(() => {
    mockPool.query.mockReset();
  });

  it('returns 409 when the device belongs to another user', async () => {
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'victim-user-uuid' }] })
      .mockResolvedValueOnce({ rows: [] });

    const res = await request(app)
      .post('/api/cloud/devices')
      .set('Authorization', 'Bearer attacker-jwt')
      .send({
        device_id: 'victim-device-id',
        runtime_location: 'local',
        capabilities: {},
      })
      .expect(409);

    expect(res.body.code).toBe('DEVICE_ID_CONFLICT');
  });
});
