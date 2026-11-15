/**
 * Behavior tests for cache metrics routes.
 */

import { describe, it, expect, jest, beforeEach } from '@jest/globals';

const mockGetCacheStats = jest.fn();
const mockClearCache = jest.fn();
const mockInvalidate = jest.fn();
const mockInvalidateByTable = jest.fn();
const mockResetMetrics = jest.fn();

jest.unstable_mockModule(
  '../../services/api-backend/database/cached-query-wrapper.js',
  () => ({
    getCacheStats: (...args) => mockGetCacheStats(...args),
    clearCache: (...args) => mockClearCache(...args),
  }),
);

jest.unstable_mockModule(
  '../../services/api-backend/database/query-cache.js',
  () => ({
    getQueryCache: () => ({
      invalidate: (...args) => mockInvalidate(...args),
      invalidateByTable: (...args) => mockInvalidateByTable(...args),
      resetMetrics: (...args) => mockResetMetrics(...args),
    }),
  }),
);

jest.unstable_mockModule(
  '../../services/api-backend/middleware/admin-auth.js',
  () => ({
    adminAuth: () => (_req, _res, next) => next(),
  }),
);

const request = (await import('supertest')).default;
const express = (await import('express')).default;
const cacheMetricsRoutes = (
  await import('../../services/api-backend/routes/cache-metrics.js')
).default;

describe('cache-metrics routes', () => {
  let app;

  beforeEach(() => {
    jest.clearAllMocks();
    app = express();
    app.use(express.json());
    app.use('/cache', cacheMetricsRoutes);
  });

  it('GET /stats returns cache statistics', async () => {
    mockGetCacheStats.mockReturnValue({ hits: 10, misses: 2 });
    const res = await request(app).get('/cache/stats').expect(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.hits).toBe(10);
  });

  it('GET /stats returns 500 when stats lookup fails', async () => {
    mockGetCacheStats.mockImplementation(() => {
      throw new Error('stats failed');
    });
    const res = await request(app).get('/cache/stats').expect(500);
    expect(res.body.success).toBe(false);
  });

  it('POST /clear clears the cache', async () => {
    const res = await request(app).post('/cache/clear').expect(200);
    expect(mockClearCache).toHaveBeenCalled();
    expect(res.body.success).toBe(true);
  });

  it('POST /clear returns 500 when clear fails', async () => {
    mockClearCache.mockImplementation(() => {
      throw new Error('clear failed');
    });
    const res = await request(app).post('/cache/clear').expect(500);
    expect(res.body.success).toBe(false);
  });

  it('POST /invalidate by table returns invalidated count', async () => {
    mockInvalidateByTable.mockReturnValue(4);
    const res = await request(app)
      .post('/cache/invalidate')
      .send({ table: 'users' })
      .expect(200);
    expect(mockInvalidateByTable).toHaveBeenCalledWith('users');
    expect(res.body.invalidatedCount).toBe(4);
  });

  it('POST /invalidate by pattern escapes regex metacharacters', async () => {
    mockInvalidate.mockReturnValue(2);
    const res = await request(app)
      .post('/cache/invalidate')
      .send({ pattern: 'user.*id' })
      .expect(200);
    expect(mockInvalidate).toHaveBeenCalledTimes(1);
    const regexArg = mockInvalidate.mock.calls[0][0];
    expect(regexArg).toBeInstanceOf(RegExp);
    expect(regexArg.source).toBe('user\\.\\*id');
    expect(res.body.invalidatedCount).toBe(2);
  });

  it('POST /invalidate rejects bodies missing pattern and table', async () => {
    const res = await request(app)
      .post('/cache/invalidate')
      .send({})
      .expect(400);
    expect(res.body).toBeTruthy();
  });

  it('GET /reset-metrics resets cache metrics', async () => {
    const res = await request(app).get('/cache/reset-metrics').expect(200);
    expect(mockResetMetrics).toHaveBeenCalled();
    expect(res.body.success).toBe(true);
  });

  it('GET /reset-metrics returns 500 when reset fails', async () => {
    mockResetMetrics.mockImplementation(() => {
      throw new Error('reset failed');
    });
    const res = await request(app).get('/cache/reset-metrics').expect(500);
    expect(res.body.success).toBe(false);
  });
});
