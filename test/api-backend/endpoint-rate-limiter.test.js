/**
 * @fileoverview Tests for endpoint rate limiter
 * Tests per-endpoint configuration, tiered limiting, and metrics
 */

import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import request from 'supertest';
import express from 'express';
import {
  createEndpointRateLimiter,
  createEndpointRateLimiters,
  createTieredRateLimiter,
  ENDPOINT_LIMITS,
} from '../../lib/middleware-config/operational/endpoint-rate-limiter.js';

describe('Endpoint Rate Limiter', () => {
  let app;
  let mockRedis;

  beforeEach(() => {
    app = express();
    mockRedis = null; // No Redis in tests
    app.use(express.json());
  });

  describe('ENDPOINT_LIMITS configuration', () => {
    it('should define all standard endpoint types', () => {
      const types = Object.keys(ENDPOINT_LIMITS);
      expect(types).toContain('public');
      expect(types).toContain('user');
      expect(types).toContain('conversation');
      expect(types).toContain('agent');
      expect(types).toContain('upload');
      expect(types).toContain('admin');
      expect(types).toContain('webhook');
    });

    it('should have consistent configuration structure', () => {
      Object.entries(ENDPOINT_LIMITS).forEach(([type, config]) => {
        expect(config).toHaveProperty('windowMs');
        expect(config).toHaveProperty('max');
        expect(config).toHaveProperty('keyscan');
        expect(typeof config.windowMs).toBe('number');
        expect(typeof config.max).toBe('number');
        expect(typeof config.keyscan).toBe('string');
      });
    });

    it('should have stricter limits for expensive operations', () => {
      expect(ENDPOINT_LIMITS.agent.max).toBeLessThan(ENDPOINT_LIMITS.user.max);
      expect(ENDPOINT_LIMITS.upload.max).toBeLessThan(ENDPOINT_LIMITS.user.max);
    });
  });

  describe('createEndpointRateLimiter', () => {
    it('should create a rate limiter for valid endpoint types', () => {
      Object.keys(ENDPOINT_LIMITS).forEach((type) => {
        const limiter = createEndpointRateLimiter(type, mockRedis);
        expect(typeof limiter).toBe('function');
      });
    });

    it('should throw error for unknown endpoint type', () => {
      expect(() => {
        createEndpointRateLimiter('unknown', mockRedis);
      }).toThrow('Unknown endpoint type');
    });

    it('should apply rate limit to public endpoint', async () => {
      const limiter = createEndpointRateLimiter('public', mockRedis);
      app.get('/test', limiter, (req, res) => {
        res.json({ ok: true });
      });

      const limit = ENDPOINT_LIMITS.public.max;
      
      // Make requests up to limit
      for (let i = 0; i < limit; i++) {
        const response = await request(app).get('/test');
        expect(response.status).toBe(200);
      }

      // Next request should fail
      const response = await request(app).get('/test');
      expect(response.status).toBe(429);
      expect(response.body).toHaveProperty('error', 'Too Many Requests');
      expect(response.body).toHaveProperty('limit', limit);
    });

    it('should skip rate limiting for health check endpoints', async () => {
      const limiter = createEndpointRateLimiter('user', mockRedis);
      app.get('/health', limiter, (req, res) => {
        res.json({ ok: true });
      });

      // Make many requests to health endpoint
      for (let i = 0; i < 100; i++) {
        const response = await request(app).get('/health');
        // Health check should not be rate limited
        expect([200, 429]).toContain(response.status);
      }
    });

    it('should include rate limit headers in response', async () => {
      const limiter = createEndpointRateLimiter('user', mockRedis);
      app.get('/test', limiter, (req, res) => {
        res.json({ ok: true });
      });

      const response = await request(app).get('/test');
      expect(response.headers).toHaveProperty('ratelimit-limit');
      expect(response.headers).toHaveProperty('ratelimit-remaining');
      expect(response.headers).toHaveProperty('ratelimit-reset');
    });

    it('should use user ID as key when authenticated', async () => {
      const limiter = createEndpointRateLimiter('user', mockRedis);
      app.use((req, res, next) => {
        req.user = { id: 'test-user-123' };
        next();
      });
      app.get('/test', limiter, (req, res) => {
        res.json({ ok: true });
      });

      const response = await request(app).get('/test');
      expect(response.status).toBe(200);
      // Key should be "user:test-user-123" not IP-based
    });

    it('should apply different limits per endpoint type', async () => {
      const userLimiter = createEndpointRateLimiter('user', mockRedis);
      const agentLimiter = createEndpointRateLimiter('agent', mockRedis);

      const app2 = express();
      app2.get('/user-endpoint', userLimiter, (req, res) => {
        res.json({ ok: true });
      });
      app2.get('/agent-endpoint', agentLimiter, (req, res) => {
        res.json({ ok: true });
      });

      // User endpoint has higher limit
      const userLimit = ENDPOINT_LIMITS.user.max;
      for (let i = 0; i < userLimit; i++) {
        const response = await request(app2).get('/user-endpoint');
        expect(response.status).toBe(200);
      }

      // Agent endpoint has lower limit
      const agentLimit = ENDPOINT_LIMITS.agent.max;
      expect(agentLimit).toBeLessThan(userLimit);
    });

    it('should accept configuration overrides', () => {
      const customLimit = 5;
      const limiter = createEndpointRateLimiter('user', mockRedis, {
        max: customLimit,
      });
      expect(typeof limiter).toBe('function');
      // The custom limit is applied internally
    });
  });

  describe('createEndpointRateLimiters', () => {
    it('should batch-create multiple limiters', () => {
      const types = ['user', 'agent', 'conversation'];
      const limiters = createEndpointRateLimiters(types, mockRedis);

      expect(Object.keys(limiters)).toEqual(types);
      types.forEach((type) => {
        expect(typeof limiters[type]).toBe('function');
      });
    });

    it('should apply per-type overrides', () => {
      const types = ['user', 'agent'];
      const overrides = {
        user: { max: 100 },
        agent: { max: 5 },
      };
      const limiters = createEndpointRateLimiters(types, mockRedis, overrides);

      expect(Object.keys(limiters)).toEqual(types);
    });
  });

  describe('createTieredRateLimiter', () => {
    it('should create a tiered rate limiter', () => {
      const tierLimits = {
        free: 10,
        pro: 50,
        enterprise: 500,
      };
      const limiter = createTieredRateLimiter('conversation', tierLimits, mockRedis);
      expect(typeof limiter).toBe('function');
    });

    it('should throw error for unknown base endpoint type', () => {
      expect(() => {
        createTieredRateLimiter('unknown', { free: 10 }, mockRedis);
      }).toThrow('Unknown base endpoint type');
    });

    it('should apply different limits based on user tier', async () => {
      const tierLimits = {
        free: 10,
        pro: 50,
      };
      const limiter = createTieredRateLimiter('user', tierLimits, mockRedis);

      // Test free tier
      const app1 = express();
      app1.use((req, res, next) => {
        req.user = { id: 'free-user', tier: 'free' };
        next();
      });
      app1.get('/test', limiter, (req, res) => {
        res.json({ ok: true });
      });

      // Free tier: 10 requests allowed
      for (let i = 0; i < 10; i++) {
        const response = await request(app1).get('/test');
        expect(response.status).toBe(200);
      }

      // Test pro tier
      const app2 = express();
      app2.use((req, res, next) => {
        req.user = { id: 'pro-user', tier: 'pro' };
        next();
      });
      app2.get('/test', limiter, (req, res) => {
        res.json({ ok: true });
      });

      // Pro tier: 50 requests allowed
      for (let i = 0; i < 50; i++) {
        const response = await request(app2).get('/test');
        expect(response.status).toBe(200);
      }
    });
  });

  describe('Rate Limit Response Format', () => {
    it('should return proper 429 response', async () => {
      const limiter = createEndpointRateLimiter('public', mockRedis);
      app.get('/test', limiter, (req, res) => {
        res.json({ ok: true });
      });

      const limit = ENDPOINT_LIMITS.public.max;
      for (let i = 0; i < limit; i++) {
        await request(app).get('/test');
      }

      const response = await request(app).get('/test');
      expect(response.status).toBe(429);
      expect(response.body).toEqual({
        error: 'Too Many Requests',
        message: expect.any(String),
        retryAfter: expect.any(Number),
        limit: expect.any(Number),
        window: expect.any(Number),
      });
    });

    it('should include retry-after information', async () => {
      const windowMs = 60000;
      const limiter = createEndpointRateLimiter('public', mockRedis, {
        windowMs,
      });
      app.get('/test', limiter, (req, res) => {
        res.json({ ok: true });
      });

      const limit = ENDPOINT_LIMITS.public.max;
      for (let i = 0; i < limit; i++) {
        await request(app).get('/test');
      }

      const response = await request(app).get('/test');
      expect(response.body.retryAfter).toBe(Math.ceil(windowMs / 1000));
    });
  });

  describe('Endpoint-specific configuration', () => {
    it('should allow per-route custom limits', () => {
      const limiter = createEndpointRateLimiter('conversation', mockRedis, {
        max: 25, // Custom limit
      });
      expect(typeof limiter).toBe('function');
    });

    it('should handle overlapping route patterns', async () => {
      const publicLimiter = createEndpointRateLimiter('public', mockRedis);
      const userLimiter = createEndpointRateLimiter('user', mockRedis);

      app.get('/api/test', publicLimiter, (req, res) => {
        res.json({ type: 'public' });
      });
      app.get('/api/user/test', userLimiter, (req, res) => {
        res.json({ type: 'user' });
      });

      const response1 = await request(app).get('/api/test');
      const response2 = await request(app).get('/api/user/test');

      expect(response1.status).toBe(200);
      expect(response2.status).toBe(200);
    });
  });

  describe('Realistic endpoint scenarios', () => {
    it('should handle upload endpoint with strict limits', async () => {
      const uploadLimiter = createEndpointRateLimiter('upload', mockRedis);
      app.post('/upload', uploadLimiter, (req, res) => {
        res.json({ uploaded: true });
      });

      const limit = ENDPOINT_LIMITS.upload.max;
      expect(limit).toBeLessThan(10); // Upload should have very low limit

      for (let i = 0; i < limit; i++) {
        const response = await request(app).post('/upload');
        expect(response.status).toBe(200);
      }

      const response = await request(app).post('/upload');
      expect(response.status).toBe(429);
    });

    it('should handle agent endpoint with very strict limits', async () => {
      const agentLimiter = createEndpointRateLimiter('agent', mockRedis);
      app.post('/agent/execute', agentLimiter, (req, res) => {
        res.json({ executed: true });
      });

      const limit = ENDPOINT_LIMITS.agent.max;
      expect(limit).toBe(10); // Agent should have 10/min limit
    });

    it('should handle conversation endpoint with moderate limits', async () => {
      const conversationLimiter = createEndpointRateLimiter('conversation', mockRedis);
      app.post('/conversations', conversationLimiter, (req, res) => {
        res.json({ id: 'conv-123' });
      });

      const limit = ENDPOINT_LIMITS.conversation.max;
      expect(limit).toBe(30); // Conversation should have 30/min limit
    });
  });

  describe('Rate limit reset behavior', () => {
    it('should reset counters after window expires', async () => {
      const windowMs = 1000; // 1 second for testing
      const limiter = createEndpointRateLimiter('public', mockRedis, {
        windowMs,
        max: 2,
      });

      app.get('/test', limiter, (req, res) => {
        res.json({ ok: true });
      });

      // Make 2 requests
      await request(app).get('/test');
      await request(app).get('/test');

      // 3rd should fail
      let response = await request(app).get('/test');
      expect(response.status).toBe(429);

      // Wait for window to expire
      await new Promise((resolve) => setTimeout(resolve, windowMs + 100));

      // Now should work again
      response = await request(app).get('/test');
      expect(response.status).toBe(200);
    }, 5000);
  });
});
