/**
 * Behavior tests for monitoring dashboard routes.
 */

import { describe, it, expect, jest, beforeEach } from '@jest/globals';

jest.unstable_mockModule(
  '../../services/api-backend/middleware/admin-auth.js',
  () => ({
    adminAuth: () => (_req, _res, next) => next(),
  }),
);

const request = (await import('supertest')).default;
const express = (await import('express')).default;
const { createMonitoringRoutes } = await import(
  '../../services/api-backend/routes/monitoring.js'
);

function buildTunnelProxy(overrides = {}) {
  const connections = new Map();
  connections.set('conn-1', {
    userId: 'user-1',
    isConnected: true,
    connectedAt: new Date().toISOString(),
    lastActivity: new Date().toISOString(),
    lastPing: new Date().toISOString(),
    pendingRequests: new Map(),
  });

  return {
    getPerformanceMetrics: jest.fn(() => ({
      performance: { averageResponseTime: 42 },
      enhanced: {
        throughputPerMinute: 10,
        memoryUsageMB: 100,
        peakMemoryUsageMB: 120,
        p95ResponseTime: 80,
        p99ResponseTime: 120,
        connectionPoolStats: { poolEfficiency: 0.9 },
        queueStats: { size: 0 },
      },
      requests: { successRate: 99 },
      connections: { total: 1 },
    })),
    getHealthStatus: jest.fn(() => ({
      status: 'healthy',
      checks: { tunnel: true },
    })),
    getStats: jest.fn(() => ({
      connections: { active: 1 },
      requests: { total: 5 },
    })),
    performanceAlerts: [
      { timestamp: new Date().toISOString(), message: 'high latency' },
      {
        timestamp: new Date(Date.now() - 10 * 60 * 1000).toISOString(),
        message: 'old alert',
      },
    ],
    lastPerformanceCheck: new Date().toISOString(),
    connections,
    userConnections: new Map([['user-1', 'conn-1']]),
    metrics: {
      requestTimestamps: [new Date(), new Date(Date.now() - 30_000)],
    },
    checkPerformanceAlerts: jest.fn(),
    updateMemoryUsage: jest.fn(),
    ...overrides,
  };
}

describe('monitoring routes', () => {
  let app;
  let tunnelProxy;

  beforeAll(() => {
    // createMonitoringRoutes mutates a module-level router; mount once.
    tunnelProxy = buildTunnelProxy();
    const router = createMonitoringRoutes(tunnelProxy);
    app = express();
    app.use(express.json());
    app.use('/monitoring', router);
  });

  beforeEach(() => {
    jest.clearAllMocks();
    Object.assign(tunnelProxy, buildTunnelProxy());
  });

  it('GET /performance returns metrics', async () => {
    const res = await request(app).get('/monitoring/performance').expect(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.performance.averageResponseTime).toBe(42);
  });

  it('GET /health returns 200 when healthy and 503 when not', async () => {
    await request(app).get('/monitoring/health').expect(200);
    tunnelProxy.getHealthStatus.mockReturnValue({
      status: 'unhealthy',
      checks: {},
    });
    const res = await request(app).get('/monitoring/health').expect(503);
    expect(res.body.data.status).toBe('unhealthy');
  });

  it('GET /alerts filters to the last 5 minutes', async () => {
    const res = await request(app).get('/monitoring/alerts').expect(200);
    expect(res.body.data.activeAlerts).toBe(1);
    expect(res.body.data.totalAlerts).toBe(2);
  });

  it('GET /connections returns connection details', async () => {
    const res = await request(app).get('/monitoring/connections').expect(200);
    expect(res.body.data.connections).toHaveLength(1);
    expect(res.body.data.connections[0].connectionId).toBe('conn-1');
    expect(res.body.data.userConnections).toBe(1);
  });

  it('GET /requests supports timeframe query values', async () => {
    for (const timeframe of ['5m', '15m', '1h', '24h', 'bogus']) {
      const res = await request(app)
        .get(`/monitoring/requests?timeframe=${timeframe}`)
        .expect(200);
      expect(res.body.data.timeframe).toBe(timeframe);
      expect(res.body.data.recentActivity.requestCount).toBeGreaterThanOrEqual(
        0,
      );
    }
  });

  it('GET /resources returns process and tunnel memory stats', async () => {
    const res = await request(app).get('/monitoring/resources').expect(200);
    expect(res.body.data.process.heapUsed).toBeGreaterThan(0);
    expect(res.body.data.tunnel.memoryUsageMB).toBe(100);
  });

  it('GET /dashboard computes KPIs from health and metrics', async () => {
    const res = await request(app).get('/monitoring/dashboard').expect(200);
    expect(res.body.data.kpis.availability).toBe(100);
    expect(res.body.data.kpis.activeConnections).toBe(1);
  });

  it('GET /dashboard reports degraded availability', async () => {
    tunnelProxy.getHealthStatus.mockReturnValue({
      status: 'degraded',
      checks: {},
    });
    const res = await request(app).get('/monitoring/dashboard').expect(200);
    expect(res.body.data.kpis.availability).toBe(75);
  });

  it('POST /check triggers performance checks', async () => {
    const res = await request(app).post('/monitoring/check').expect(200);
    expect(tunnelProxy.checkPerformanceAlerts).toHaveBeenCalled();
    expect(tunnelProxy.updateMemoryUsage).toHaveBeenCalled();
    expect(res.body.message).toMatch(/completed/);
  });

  it('returns 500 when performance metrics throw', async () => {
    tunnelProxy.getPerformanceMetrics.mockImplementation(() => {
      throw new Error('metrics boom');
    });
    const res = await request(app).get('/monitoring/performance').expect(500);
    expect(res.body.error || res.body.message || res.body).toBeTruthy();
  });
});
