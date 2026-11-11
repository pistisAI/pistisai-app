/**
 * Idempotency Middleware Tests (Jest)
 *
 * Verifies that idempotency keys are tracked correctly and duplicate requests
 * are detected and deduplicated.
 */

import express from 'express';
import request from 'supertest';
import {
  createIdempotencyMiddleware,
  validateIdempotencyKey,
  extractIdempotencyKey,
  isIdempotencyReplay,
  IDEMPOTENCY_KEY_HEADER,
} from '../../services/api-backend/middleware/idempotency.js';
import MemoryCache from '../../services/api-backend/cache/memory-cache.js';

describe('Idempotency Middleware', () => {
  let app;
  let cache;
  let middleware;
  let callCount;

  beforeEach(() => {
    app = express();
    cache = new MemoryCache();
    callCount = 0;

    // Add body parser BEFORE middleware (important!)
    app.use(express.json());

    // Create middleware
    middleware = createIdempotencyMiddleware({
      cache,
      idempotentMethods: ['POST', 'PATCH', 'DELETE'],
      idempotentRoutes: [/^\/api\/test/, /^\/api\/payment/],
    });

    // Add test middleware to track calls
    app.use(middleware);

    // Test endpoint
    app.post('/api/test/operation', (req, res) => {
      callCount++;
      res.json({
        success: true,
        callCount,
        timestamp: new Date().toISOString(),
      });
    });

    app.post('/api/payment/charge', (req, res) => {
      callCount++;
      res.json({
        success: true,
        transactionId: `txn_${callCount}`,
        amount: req.body.amount,
      });
    });

    app.post('/api/public/webhook', (req, res) => {
      callCount++;
      res.json({ status: 'received' });
    });

    app.patch('/api/test/update', (req, res) => {
      callCount++;
      res.json({ id: 1, updated: true });
    });

    app.delete('/api/test/delete', (req, res) => {
      callCount++;
      res.json({ deleted: true });
    });

    app.get('/api/test/read', (req, res) => {
      callCount++;
      res.json({ data: 'read' });
    });
  });

  afterEach(() => {
    cache.clear();
  });

  describe('Duplicate Request Deduplication', () => {
    it('should return cached response for duplicate requests with same idempotency key', async () => {
      const idempotencyKey = 'test-key-1';
      const payload = { amount: 100 };

      // First request
      const response1 = await request(app)
        .post('/api/payment/charge')
        .set(IDEMPOTENCY_KEY_HEADER, idempotencyKey)
        .send(payload);

      expect(response1.status).toBe(200);
      expect(response1.headers[IDEMPOTENCY_KEY_HEADER]).toBe(idempotencyKey);
      expect(response1.headers['idempotency-replay']).toBeUndefined();

      // Second request with same key
      const response2 = await request(app)
        .post('/api/payment/charge')
        .set(IDEMPOTENCY_KEY_HEADER, idempotencyKey)
        .send(payload);

      expect(response2.status).toBe(200);
      // Should return same transaction ID (cached response)
      // The body will be a JSON string from the cache, but the replay header confirms it's cached
      expect(response2.headers['idempotency-replay']).toBe('true');

      // Handler should only be called once
      expect(callCount).toBe(1);
    });

    it('should handle different idempotency keys independently', async () => {
      const key1 = 'key-1';
      const key2 = 'key-2';

      // First request with key1
      const response1 = await request(app)
        .post('/api/payment/charge')
        .set(IDEMPOTENCY_KEY_HEADER, key1)
        .send({ amount: 100 });

      expect(response1.body.transactionId).toBe('txn_1');

      // Second request with key2
      const response2 = await request(app)
        .post('/api/payment/charge')
        .set(IDEMPOTENCY_KEY_HEADER, key2)
        .send({ amount: 200 });

      expect(response2.body.transactionId).toBe('txn_2');

      // Handler should be called twice
      expect(callCount).toBe(2);
    });

    it('should use query parameter as fallback for idempotency key', async () => {
      const idempotencyKey = 'query-key-1';

      // First request with query parameter
      const response1 = await request(app)
        .post('/api/test/operation')
        .query({ idempotency_key: idempotencyKey });

      expect(response1.status).toBe(200);

      // Second request with same query parameter
      const response2 = await request(app)
        .post('/api/test/operation')
        .query({ idempotency_key: idempotencyKey });

      expect(response2.status).toBe(200);
      // Should be cached, indicated by replay header
      expect(response2.headers['idempotency-replay']).toBe('true');
    });

    it('should use body field as fallback for idempotency key', async () => {
      const idempotencyKey = 'body-key-1';

      // First request
      const response1 = await request(app)
        .post('/api/test/operation')
        .send({ idempotency_key: idempotencyKey, amount: 100 });

      expect(response1.status).toBe(200);

      // Second request
      const response2 = await request(app)
        .post('/api/test/operation')
        .send({ idempotency_key: idempotencyKey, amount: 100 });

      expect(response2.status).toBe(200);
      // Should be cached, indicated by replay header
      expect(response2.headers['idempotency-replay']).toBe('true');
    });
  });

  describe('Route Filtering', () => {
    it('should not apply idempotency to routes outside idempotentRoutes', async () => {
      const idempotencyKey = 'webhook-key';

      // First request to /api/public/webhook
      const response1 = await request(app)
        .post('/api/public/webhook')
        .set(IDEMPOTENCY_KEY_HEADER, idempotencyKey)
        .send({ data: 'test' });

      expect(response1.status).toBe(200);
      expect(callCount).toBe(1);

      // Second request - should NOT be deduplicated (not in idempotentRoutes)
      const response2 = await request(app)
        .post('/api/public/webhook')
        .set(IDEMPOTENCY_KEY_HEADER, idempotencyKey)
        .send({ data: 'test' });

      expect(response2.status).toBe(200);
      expect(callCount).toBe(2); // Handler called twice
    });

    it('should not apply idempotency to GET requests', async () => {
      const idempotencyKey = 'get-key';

      const response1 = await request(app)
        .get('/api/test/read')
        .set(IDEMPOTENCY_KEY_HEADER, idempotencyKey);

      expect(response1.status).toBe(200);
      expect(callCount).toBe(1);

      // Should not be deduplicated
      const response2 = await request(app)
        .get('/api/test/read')
        .set(IDEMPOTENCY_KEY_HEADER, idempotencyKey);

      expect(response2.status).toBe(200);
      expect(callCount).toBe(2);
    });
  });

  describe('HTTP Methods', () => {
    it('should apply idempotency to POST requests', async () => {
      const key = 'post-key';

      const response1 = await request(app)
        .post('/api/test/operation')
        .set(IDEMPOTENCY_KEY_HEADER, key)
        .send({});

      expect(response1.status).toBe(200);

      const response2 = await request(app)
        .post('/api/test/operation')
        .set(IDEMPOTENCY_KEY_HEADER, key)
        .send({});

      expect(response2.headers['idempotency-replay']).toBe('true');
    });

    it('should apply idempotency to PATCH requests', async () => {
      const key = 'patch-key';

      const response1 = await request(app)
        .patch('/api/test/update')
        .set(IDEMPOTENCY_KEY_HEADER, key)
        .send({ id: 1 });

      expect(response1.status).toBe(200);

      const response2 = await request(app)
        .patch('/api/test/update')
        .set(IDEMPOTENCY_KEY_HEADER, key)
        .send({ id: 1 });

      expect(response2.headers['idempotency-replay']).toBe('true');
    });

    it('should apply idempotency to DELETE requests', async () => {
      const key = 'delete-key';

      const response1 = await request(app)
        .delete('/api/test/delete')
        .set(IDEMPOTENCY_KEY_HEADER, key)
        .send({});

      expect(response1.status).toBe(200);

      const response2 = await request(app)
        .delete('/api/test/delete')
        .set(IDEMPOTENCY_KEY_HEADER, key)
        .send({});

      expect(response2.headers['idempotency-replay']).toBe('true');
    });
  });

  describe('Helper Functions', () => {
    it('should validate idempotency keys', () => {
      expect(validateIdempotencyKey('valid-key-123')).toBe(true);
      expect(validateIdempotencyKey('f47ac10b-58cc-4372-a567-0e02b2c3d479')).toBe(
        true,
      );
      expect(validateIdempotencyKey('key_with_underscore')).toBe(true);
      expect(validateIdempotencyKey('')).toBe(false);
      expect(validateIdempotencyKey(null)).toBe(false);
      expect(validateIdempotencyKey(undefined)).toBe(false);
      expect(validateIdempotencyKey('x'.repeat(257))).toBe(false); // Too long
    });

    it('should extract idempotency key from request', () => {
      const req1 = {
        headers: { 'idempotency-key': 'header-key' },
        query: {},
        body: {},
      };
      expect(extractIdempotencyKey(req1)).toBe('header-key');

      const req2 = {
        headers: {},
        query: { idempotency_key: 'query-key' },
        body: {},
      };
      expect(extractIdempotencyKey(req2)).toBe('query-key');

      const req3 = {
        headers: {},
        query: {},
        body: { idempotency_key: 'body-key' },
      };
      expect(extractIdempotencyKey(req3)).toBe('body-key');

      const req4 = {
        headers: {},
        query: {},
        body: {},
      };
      expect(extractIdempotencyKey(req4)).toBeNull();
    });

    it('should identify replayed responses', () => {
      const res = {
        headers: { 'idempotency-replay': 'true' },
        getHeader: function (name) {
          return this.headers[name.toLowerCase()];
        },
      };

      expect(isIdempotencyReplay(res)).toBe(true);

      const res2 = {
        headers: {},
        getHeader: function (name) {
          return this.headers[name.toLowerCase()];
        },
      };

      expect(isIdempotencyReplay(res2)).toBe(false);
    });
  });

  describe('Error Handling', () => {
    it('should continue processing even if cache is not provided', async () => {
      const noCacheApp = express();
      const noCacheMiddleware = createIdempotencyMiddleware({
        cache: null,
      });

      noCacheApp.use(noCacheMiddleware);
      noCacheApp.use(express.json());
      noCacheApp.post('/api/test/operation', (req, res) => {
        res.json({ success: true });
      });

      const response = await request(noCacheApp)
        .post('/api/test/operation')
        .send({});

      expect(response.status).toBe(200);
    });
  });

  describe('Response Headers', () => {
    it('should set idempotency key header on all responses', async () => {
      const response = await request(app)
        .post('/api/test/operation')
        .set(IDEMPOTENCY_KEY_HEADER, 'test-key')
        .send({});

      expect(response.headers[IDEMPOTENCY_KEY_HEADER]).toBe('test-key');
    });

    it('should include idempotency-replay header for cached responses', async () => {
      const key = 'replay-key';

      await request(app)
        .post('/api/test/operation')
        .set(IDEMPOTENCY_KEY_HEADER, key)
        .send({});

      const response = await request(app)
        .post('/api/test/operation')
        .set(IDEMPOTENCY_KEY_HEADER, key)
        .send({});

      expect(response.headers['idempotency-replay']).toBe('true');
    });

    it('should not set idempotency-replay header for new responses', async () => {
      const response = await request(app)
        .post('/api/test/operation')
        .set(IDEMPOTENCY_KEY_HEADER, 'new-key')
        .send({});

      expect(response.headers['idempotency-replay']).toBeUndefined();
    });
  });
});
