/**
 * Behavior tests for admin rate limiter middleware.
 */

import { describe, it, expect, jest } from '@jest/globals';
import express from 'express';
import request from 'supertest';
import {
  createAdminRateLimiter,
  combineRateLimiters,
  getRateLimitStats,
  adminRateLimiter,
  adminBurstLimiter,
  adminExpensiveLimiter,
  adminReadOnlyLimiter,
  adminCriticalLimiter,
} from '../../../services/api-backend/middleware/admin-rate-limiter.js';

function buildApp(limiter) {
  const app = express();
  app.use((req, _res, next) => {
    req.adminUser = { id: 'admin-user-1' };
    next();
  });
  app.use(limiter);
  app.get('/admin/resource', (_req, res) => {
    res.json({ ok: true });
  });
  app.get('/admin/health', (_req, res) => {
    res.json({ status: 'ok' });
  });
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });
  return app;
}

describe('admin-rate-limiter middleware', () => {
  it('allows requests under the configured limit', async () => {
    const limiter = createAdminRateLimiter('default', {
      windowMs: 60_000,
      max: 5,
    });
    const app = buildApp(limiter);
    const res = await request(app).get('/admin/resource').expect(200);
    expect(res.body.ok).toBe(true);
  });

  it('returns 429 with ADMIN_RATE_LIMIT_EXCEEDED when limit is exceeded', async () => {
    const limiter = createAdminRateLimiter('default', {
      windowMs: 60_000,
      max: 2,
    });
    const app = buildApp(limiter);
    await request(app).get('/admin/resource').expect(200);
    await request(app).get('/admin/resource').expect(200);
    const res = await request(app).get('/admin/resource').expect(429);
    expect(res.body.code).toBe('ADMIN_RATE_LIMIT_EXCEEDED');
    expect(res.body.retryAfter).toBe(60);
  });

  it('skips rate limiting for health endpoints', async () => {
    const limiter = createAdminRateLimiter('default', {
      windowMs: 60_000,
      max: 1,
    });
    const app = buildApp(limiter);
    await request(app).get('/admin/resource').expect(200);
    await request(app).get('/admin/resource').expect(429);
    await request(app).get('/health').expect(200);
    await request(app).get('/admin/health').expect(200);
  });

  it('uses expensive operation error codes', async () => {
    const limiter = createAdminRateLimiter('expensive', {
      windowMs: 60_000,
      max: 1,
    });
    const app = buildApp(limiter);
    await request(app).get('/admin/resource').expect(200);
    const res = await request(app).get('/admin/resource').expect(429);
    expect(res.body.code).toBe('ADMIN_EXPENSIVE_OPERATION_LIMIT_EXCEEDED');
  });

  it('falls back to default config for unknown types', async () => {
    const limiter = createAdminRateLimiter('not-a-real-type', {
      windowMs: 60_000,
      max: 1,
    });
    const app = buildApp(limiter);
    await request(app).get('/admin/resource').expect(200);
    const res = await request(app).get('/admin/resource').expect(429);
    expect(res.body.code).toBe('ADMIN_RATE_LIMIT_EXCEEDED');
  });

  it('combineRateLimiters runs limiters in sequence', async () => {
    const first = createAdminRateLimiter('default', {
      windowMs: 60_000,
      max: 10,
    });
    const second = createAdminRateLimiter('burst', {
      windowMs: 10_000,
      max: 1,
    });
    const app = buildApp(combineRateLimiters(first, second));
    await request(app).get('/admin/resource').expect(200);
    const res = await request(app).get('/admin/resource').expect(429);
    expect(res.body.code).toBe('ADMIN_BURST_LIMIT_EXCEEDED');
  });

  it('combineRateLimiters forwards errors from a limiter', () => {
    const failing = (_req, _res, next) => next(new Error('limiter failed'));
    const ok = (_req, _res, next) => next();
    const combined = combineRateLimiters(failing, ok);
    const next = jest.fn();
    combined({}, {}, next);
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });

  it('getRateLimitStats returns config summaries', () => {
    const stats = getRateLimitStats();
    expect(stats.configs.map((c) => c.type)).toEqual(
      expect.arrayContaining([
        'default',
        'burst',
        'expensive',
        'readOnly',
        'critical',
      ]),
    );
    expect(stats.recommendation).toMatch(/Redis/);
  });

  it('exports preconfigured limiter middleware functions', () => {
    expect(typeof adminRateLimiter).toBe('function');
    expect(typeof adminBurstLimiter).toBe('function');
    expect(typeof adminExpensiveLimiter).toBe('function');
    expect(typeof adminReadOnlyLimiter).toBe('function');
    expect(typeof adminCriticalLimiter).toBe('function');
  });
});
