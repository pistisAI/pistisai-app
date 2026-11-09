import { jest, describe, it, expect, beforeEach } from '@jest/globals';

const mockPool = {
  query: jest.fn(),
};

jest.unstable_mockModule('../../services/api-backend/database/db-pool.js', () => ({
  initializePool: jest.fn(async () => mockPool),
  getPool: jest.fn(() => mockPool),
}));

jest.unstable_mockModule('../../services/api-backend/middleware/auth.js', () => ({
  authenticateJWT: (req, res, next) => {
    req.user = { sub: 'auth0|test-user' };
    next();
  },
  extractUserId: () => 'auth0|test-user',
}));

jest.unstable_mockModule('../../services/api-backend/middleware/schema-validation.js', () => ({
  validateSchema: () => (req, res, next) => next(),
}));

jest.unstable_mockModule('../../services/api-backend/logger.js', () => ({
  default: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

process.env.NODE_ENV = 'test';

const { CloudConnectorService } = await import('../../services/api-backend/services/cloud-connector-service.js');
const request = (await import('supertest')).default;


describe('CloudConnectorService', () => {
  let service;

  beforeEach(() => {
    mockPool.query.mockReset();
    service = new CloudConnectorService();
    service.pool = mockPool;
  });

  it('registers a device with upsert semantics', async () => {
    mockPool.query
      .mockResolvedValueOnce({
        rows: [{ id: 'dev-uuid', device_id: 'abc123def456' }],
      })
      .mockResolvedValueOnce({ rows: [{ last_seen: new Date() }] });

    const device = await service.registerDevice('user-1', {
      deviceId: 'abc123def456',
      runtimeLocation: 'local',
      capabilities: {},
    });
    expect(device.device_id).toBe('abc123def456');
    expect(mockPool.query).toHaveBeenCalledTimes(2);
  });

  it('rejects invalid runtime location', async () => {
    await expect(
      service.registerDevice('user-1', {
        deviceId: 'abc123def456',
        runtimeLocation: 'bogus',
      }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
  });

  it('heartbeat fails for unregistered device', async () => {
    mockPool.query.mockResolvedValueOnce({ rows: [] });
    await expect(service.heartbeat('user-1', 'unknown123')).rejects.toMatchObject({
      code: 'DEVICE_NOT_FOUND',
    });
  });

  it('revokes a device and clears presence', async () => {
    mockPool.query
      .mockResolvedValueOnce({ rows: [{ id: 'dev-uuid', device_id: 'abc123def456' }] })
      .mockResolvedValueOnce({ rowCount: 1 })
      .mockResolvedValueOnce({ rowCount: 1 });

    const result = await service.revokeDevice('user-1', 'abc123def456');
    expect(result.revoked).toBe(true);
  });
});

describe('TailscaleJoinService', () => {
  it('redeems a valid token and rejects a mismatch', async () => {
    const { default: TailscaleJoinService } = await import(
      '../../services/api-backend/services/tailscale-join-service.js'
    );
    const joinService = new TailscaleJoinService();
    try {
      const { token } = joinService.createJoinToken('user-1');
      expect(joinService.redeemJoinToken('user-1', 'wrong-token-value-xx').ok).toBe(
        false,
      );
      const { token: token2 } = joinService.createJoinToken('user-1');
      expect(joinService.redeemJoinToken('user-1', token2).ok).toBe(true);
      expect(joinService.redeemJoinToken('user-1', token2).ok).toBe(false);
      expect(token).toHaveLength(48);
    } finally {
      joinService.destroy();
    }
  });
});
