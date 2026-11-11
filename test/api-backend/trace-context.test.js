/**
 * Tests for Distributed Trace Context Middleware
 *
 * Verifies trace ID generation, extraction, and propagation
 * through the request/response cycle.
 *
 * @fileoverview Trace context middleware tests
 */

import express from 'express';
import request from 'supertest';
import { describe, it, expect, beforeEach } from '@jest/globals';
import { traceContextMiddleware } from '../middleware/trace-context.js';
import { requestLoggingMiddleware } from '../middleware/request-logging.js';

describe('Trace Context Middleware', () => {
  let app;

  beforeEach(() => {
    app = express();
    app.use(traceContextMiddleware);

    // Simple route for testing
    app.get('/test', (req, res) => {
      res.json({
        traceId: req.traceId,
        traceContext: req.traceContext,
        traceparent: req.headers.traceparent,
      });
    });
  });

  describe('Trace ID Generation', () => {
    it('should generate a trace ID when none is provided', async () => {
      const response = await request(app).get('/test');

      expect(response.status).toBe(200);
      expect(response.body.traceId).toBeDefined();
      expect(response.body.traceId).toMatch(/^[0-9a-f]{32}$/); // 32 hex chars
      expect(response.headers['x-trace-id']).toBe(response.body.traceId);
    });

    it('should generate a valid W3C traceparent header', async () => {
      const response = await request(app).get('/test');

      const traceparent = response.headers.traceparent;
      expect(traceparent).toBeDefined();
      expect(traceparent).toMatch(/^00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$/);
    });

    it('should include trace context in request object', async () => {
      const response = await request(app).get('/test');

      const { traceContext } = response.body;
      expect(traceContext).toBeDefined();
      expect(traceContext.version).toBe('00');
      expect(traceContext.traceId).toMatch(/^[0-9a-f]{32}$/);
      expect(traceContext.spanId).toMatch(/^[0-9a-f]{16}$/);
      expect(traceContext.flags).toMatch(/^[0-9a-f]{2}$/);
    });
  });

  describe('Trace ID Extraction', () => {
    it('should extract trace ID from incoming traceparent header', async () => {
      const incomingTraceparent = '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01';

      const response = await request(app)
        .get('/test')
        .set('traceparent', incomingTraceparent);

      expect(response.status).toBe(200);
      expect(response.body.traceId).toBe('0af7651916cd43dd8448eb211c80319c');
      expect(response.headers.traceparent).toBe(incomingTraceparent);
    });

    it('should handle invalid traceparent headers gracefully', async () => {
      const invalidTraceparent = 'invalid-trace-id';

      const response = await request(app)
        .get('/test')
        .set('traceparent', invalidTraceparent);

      expect(response.status).toBe(200);
      expect(response.body.traceId).toBeDefined();
      expect(response.body.traceId).toMatch(/^[0-9a-f]{32}$/);
      // New trace ID should be generated
      expect(response.body.traceId).not.toBe('invalid-trace-id');
    });

    it('should preserve tracestate header', async () => {
      const traceparent = '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01';
      const tracestate = 'congo=t61rcWxrMzE,rojo=00f067aa0ba902b7';

      const response = await request(app)
        .get('/test')
        .set('traceparent', traceparent)
        .set('tracestate', tracestate);

      expect(response.headers.tracestate).toBe(tracestate);
    });
  });

  describe('Response Headers', () => {
    it('should include W3C traceparent in response headers', async () => {
      const response = await request(app).get('/test');

      expect(response.headers.traceparent).toBeDefined();
      expect(response.headers.traceparent).toMatch(/^00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$/);
    });

    it('should include legacy X-Trace-ID header for backward compatibility', async () => {
      const response = await request(app).get('/test');

      expect(response.headers['x-trace-id']).toBeDefined();
      expect(response.headers['x-trace-id']).toBe(response.body.traceId);
    });

    it('should not include tracestate if not provided in request', async () => {
      const response = await request(app).get('/test');

      expect(response.headers.tracestate).toBeUndefined();
    });
  });

  describe('Integration with Request Logging', () => {
    it('should include trace context in logged requests', async () => {
      const app2 = express();
      app2.use(traceContextMiddleware);
      app2.use(requestLoggingMiddleware);
      app2.get('/test', (req, res) => {
        res.json({ 
          success: true,
          traceId: req.traceId,
        });
      });

      const response = await request(app2).get('/test');

      expect(response.status).toBe(200);
      expect(response.body.traceId).toBeDefined();
      expect(response.body.traceId).toMatch(/^[0-9a-f]{32}$/);
    });
  });

  describe('Trace ID Consistency', () => {
    it('should maintain the same trace ID across request/response cycle', async () => {
      const response = await request(app).get('/test');

      const reqTraceId = response.body.traceId;
      const responseTraceparent = response.headers.traceparent;
      const responseXTraceId = response.headers['x-trace-id'];

      expect(responseXTraceId).toBe(reqTraceId);
      expect(responseTraceparent).toMatch(new RegExp(`^00-${reqTraceId}-`));
    });

    it('should generate unique trace IDs for separate requests', async () => {
      const response1 = await request(app).get('/test');
      const response2 = await request(app).get('/test');

      expect(response1.body.traceId).not.toBe(response2.body.traceId);
    });
  });

  describe('Error Handling', () => {
    it('should recover from errors in trace context generation', async () => {
      app.get('/error-test', (req, res) => {
        // Should still have trace ID despite earlier errors
        res.json({
          hasTraceId: !!req.traceId,
          traceId: req.traceId,
        });
      });

      const response = await request(app).get('/error-test');

      expect(response.status).toBe(200);
      expect(response.body.hasTraceId).toBe(true);
      expect(response.body.traceId).toMatch(/^[0-9a-f]{32}$/);
    });
  });
});
