/**
 * Circuit Breaker Middleware Integration Tests
 *
 * Tests circuit breaker middleware with Express and external service calls.
 */

import express from 'express';
import request from 'supertest';
import { createCircuitBreakerMiddleware, circuitBreakerManager } from '../../services/api-backend/middleware/circuit-breaker.js';

describe('Circuit Breaker Middleware Integration', () => {
  let app;

  beforeEach(() => {
    circuitBreakerManager.resetAll();
    app = express();
    app.use(express.json());
  });

  test('should allow requests when circuit is CLOSED', async () => {
    const middleware = createCircuitBreakerMiddleware({
      breakers: {
        'external-api': { failureThreshold: 2 },
      },
      isExternalServiceCall: (req) => {
        if (req.path === '/api/external') return 'external-api';
        return null;
      },
    });

    app.use(middleware);

    app.get('/api/external', (req, res) => {
      res.json({ success: true });
    });

    const res = await request(app).get('/api/external');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('should block requests when circuit is OPEN', async () => {
    const middleware = createCircuitBreakerMiddleware({
      breakers: {
        'failing-service': { failureThreshold: 2, timeout: 500 },
      },
      isExternalServiceCall: (req) => {
        if (req.path === '/api/failing') return 'failing-service';
        return null;
      },
      getFallbackResponse: () => ({
        status: 503,
        body: { error: 'Service temporarily unavailable' },
      }),
    });

    app.use(middleware);

    let requestCount = 0;
    app.get('/api/failing', (req, res) => {
      requestCount++;
      if (req.currentCircuitBreaker) {
        req.currentCircuitBreaker.recordFailure();
      }
      res.status(500).json({ error: 'Service error' });
    });

    // First request - fails
    let res = await request(app).get('/api/failing');
    expect(res.status).toBe(500);
    expect(requestCount).toBe(1);

    // Second request - fails, circuit opens
    res = await request(app).get('/api/failing');
    expect(res.status).toBe(500);
    expect(requestCount).toBe(2);

    // Third request - circuit is open, fallback response returned
    res = await request(app).get('/api/failing');
    expect(res.status).toBe(503);
    expect(res.body.error).toBe('Service temporarily unavailable');
    expect(requestCount).toBe(2); // Handler not called
  });

  test('should allow requests when circuit is HALF_OPEN', async () => {
    const middleware = createCircuitBreakerMiddleware({
      breakers: {
        'recovery-service': { failureThreshold: 1, timeout: 100 },
      },
      isExternalServiceCall: (req) => {
        if (req.path === '/api/recovery') return 'recovery-service';
        return null;
      },
    });

    app.use(middleware);

    app.get('/api/recovery', (req, res) => {
      if (req.currentCircuitBreaker) {
        req.currentCircuitBreaker.recordSuccess();
      }
      res.json({ recovered: true });
    });

    // Open the circuit
    const breaker = circuitBreakerManager.getBreaker('recovery-service');
    breaker.recordFailure();
    expect(breaker.state).toBe('OPEN');

    // Try immediately - should be blocked
    let res = await request(app).get('/api/recovery');
    expect(res.status).toBe(503);

    // Wait for timeout
    await new Promise((resolve) => setTimeout(resolve, 150));

    // Next request should be allowed (HALF_OPEN)
    res = await request(app).get('/api/recovery');
    expect(res.status).toBe(200);
    expect(breaker.state).toBe('HALF_OPEN');
  });

  test('should respect non-external-service requests', async () => {
    const middleware = createCircuitBreakerMiddleware({
      breakers: {
        'api': { failureThreshold: 2 },
      },
      isExternalServiceCall: (req) => {
        // Only mark paths starting with /external as external
        if (req.path.startsWith('/external')) return 'api';
        return null;
      },
    });

    app.use(middleware);

    app.get('/internal', (req, res) => {
      res.json({ internal: true });
    });

    const res = await request(app).get('/internal');
    expect(res.status).toBe(200);
    // Should not have circuit breaker attached
    expect(res.body.internal).toBe(true);
  });

  test('should provide fallback response when circuit is open', async () => {
    const getFallbackResponse = (req, serviceName) => ({
      status: 503,
      body: {
        error: 'Service degraded',
        service: serviceName,
        retryAfter: 30,
      },
    });

    const middleware = createCircuitBreakerMiddleware({
      breakers: {
        'stripe': { failureThreshold: 1 },
      },
      isExternalServiceCall: (req) => {
        if (req.path === '/api/stripe') return 'stripe';
        return null;
      },
      getFallbackResponse,
    });

    app.use(middleware);

    // Open the circuit immediately
    const breaker = circuitBreakerManager.getBreaker('stripe');
    breaker.recordFailure();

    const res = await request(app).get('/api/stripe');
    expect(res.status).toBe(503);
    expect(res.body.service).toBe('stripe');
    expect(res.body.retryAfter).toBe(30);
  });
});
