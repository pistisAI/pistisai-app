/**
 * Behavior tests for request queuing Express middleware (not just the service).
 */

import { describe, it, expect, jest, beforeEach } from '@jest/globals';

const mockQueueService = {
  shouldQueue: jest.fn(),
  queueRequest: jest.fn(),
  getQueueStatus: jest.fn(),
  getStatistics: jest.fn(),
  getHealthStatus: jest.fn(),
  processNextRequest: jest.fn(),
  maxQueueSize: 100,
};

jest.unstable_mockModule(
  '../../../services/api-backend/services/request-queue-service.js',
  () => ({
    getRequestQueueService: () => mockQueueService,
    RequestQueueService: jest.fn(),
  }),
);

const {
  createRequestQueuingMiddleware,
  createQueueStatusMiddleware,
  createQueueStatusHandler,
  createQueueDrainHandler,
} = await import(
  '../../../services/api-backend/middleware/request-queuing.js'
);

function mockRes() {
  return {
    statusCode: null,
    body: null,
    headers: {},
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
    set(name, value) {
      this.headers[name] = value;
    },
  };
}

describe('request-queuing middleware', () => {
  let next;

  beforeEach(() => {
    next = jest.fn();
    jest.clearAllMocks();
    mockQueueService.shouldQueue.mockReturnValue(false);
  });

  describe('createRequestQueuingMiddleware', () => {
    it('skips queuing for GET/HEAD/OPTIONS', async () => {
      const middleware = createRequestQueuingMiddleware();
      for (const method of ['GET', 'HEAD', 'OPTIONS']) {
        next.mockClear();
        await middleware(
          { method, get: () => undefined },
          mockRes(),
          next,
        );
        expect(next).toHaveBeenCalledTimes(1);
        expect(mockQueueService.shouldQueue).not.toHaveBeenCalled();
      }
    });

    it('proceeds when usage is below the queue threshold', async () => {
      mockQueueService.shouldQueue.mockReturnValue(false);
      const middleware = createRequestQueuingMiddleware();
      const req = {
        method: 'POST',
        path: '/api/x',
        get: (h) =>
          h === 'X-RateLimit-Limit'
            ? '100'
            : h === 'X-RateLimit-Remaining'
              ? '90'
              : undefined,
      };
      await middleware(req, mockRes(), next);
      expect(mockQueueService.shouldQueue).toHaveBeenCalledWith(90, 100);
      expect(next).toHaveBeenCalledTimes(1);
    });

    it('rejects with 429 when the queue is full', async () => {
      mockQueueService.shouldQueue.mockReturnValue(true);
      mockQueueService.queueRequest.mockReturnValue({ queued: false });
      const middleware = createRequestQueuingMiddleware();
      const req = {
        method: 'POST',
        path: '/api/x',
        correlationId: 'c1',
        ip: '10.0.0.1',
        get: () => undefined,
      };
      const res = mockRes();
      await middleware(req, res, next);
      expect(res.statusCode).toBe(429);
      expect(res.body.code).toBe('QUEUE_FULL');
      expect(next).not.toHaveBeenCalled();
    });

    it('waits for a queued request then continues', async () => {
      mockQueueService.shouldQueue.mockReturnValue(true);
      mockQueueService.queueRequest.mockReturnValue({
        queued: true,
        position: 2,
        promise: Promise.resolve({ queuedDuration: 15 }),
      });
      const middleware = createRequestQueuingMiddleware();
      const req = {
        method: 'POST',
        path: '/api/x',
        user: { sub: 'user-1' },
        ip: '10.0.0.9',
        get: () => undefined,
      };
      const res = mockRes();
      await middleware(req, res, next);
      expect(req.isQueued).toBe(true);
      expect(req.queuedDuration).toBe(15);
      expect(res.headers['X-Queue-Position']).toBe(2);
      expect(next).toHaveBeenCalledTimes(1);
    });

    it('returns 504 on QUEUE_TIMEOUT', async () => {
      mockQueueService.shouldQueue.mockReturnValue(true);
      mockQueueService.queueRequest.mockReturnValue({
        queued: true,
        position: 1,
        promise: Promise.reject(new Error('QUEUE_TIMEOUT')),
      });
      const middleware = createRequestQueuingMiddleware();
      const req = {
        method: 'POST',
        path: '/api/x',
        correlationId: 'c2',
        ip: '10.0.0.2',
        get: () => undefined,
      };
      const res = mockRes();
      await middleware(req, res, next);
      expect(res.statusCode).toBe(504);
      expect(res.body.code).toBe('QUEUE_TIMEOUT');
      expect(next).not.toHaveBeenCalled();
    });

    it('returns 503 on other queue processing errors', async () => {
      mockQueueService.shouldQueue.mockReturnValue(true);
      mockQueueService.queueRequest.mockReturnValue({
        queued: true,
        position: 1,
        promise: Promise.reject(new Error('unexpected')),
      });
      const middleware = createRequestQueuingMiddleware();
      const req = {
        method: 'POST',
        path: '/api/x',
        correlationId: 'c3',
        ip: '10.0.0.3',
        get: () => undefined,
      };
      const res = mockRes();
      await middleware(req, res, next);
      expect(res.statusCode).toBe(503);
      expect(res.body.code).toBe('QUEUE_ERROR');
    });

    it('skips re-queuing when req.isQueued is already set', async () => {
      mockQueueService.shouldQueue.mockReturnValue(true);
      const middleware = createRequestQueuingMiddleware();
      const req = {
        method: 'POST',
        path: '/api/x',
        isQueued: true,
        ip: '10.0.0.8',
        get: () => undefined,
      };
      await middleware(req, mockRes(), next);
      expect(mockQueueService.queueRequest).not.toHaveBeenCalled();
      expect(next).toHaveBeenCalledTimes(1);
    });
  });

  describe('createQueueStatusMiddleware', () => {
    it('attaches queueStatus helpers to the request', () => {
      mockQueueService.getStatistics.mockReturnValue({ totalQueued: 1 });
      mockQueueService.getHealthStatus.mockReturnValue({ status: 'healthy' });
      mockQueueService.getQueueStatus.mockReturnValue({ queueSize: 0 });
      const middleware = createQueueStatusMiddleware();
      const req = {};
      middleware(req, mockRes(), next);
      expect(req.queueStatus.getStatistics().totalQueued).toBe(1);
      expect(req.queueStatus.getHealthStatus().status).toBe('healthy');
      expect(req.queueStatus.getStatus('id', 'user').queueSize).toBe(0);
      expect(next).toHaveBeenCalledTimes(1);
    });
  });

  describe('createQueueStatusHandler', () => {
    it('returns queue statistics and health', () => {
      mockQueueService.getStatistics.mockReturnValue({
        currentQueuedRequests: 3,
        totalQueuesCount: 2,
        userQueuesCount: 1,
        ipQueuesCount: 1,
        totalQueued: 10,
        totalProcessed: 7,
        totalExpired: 1,
        totalRejected: 2,
      });
      mockQueueService.getHealthStatus.mockReturnValue({
        status: 'healthy',
        averageQueueSize: 1.5,
      });
      const handler = createQueueStatusHandler();
      const res = mockRes();
      handler({}, res);
      expect(res.body.status).toBe('healthy');
      expect(res.body.queue.currentQueued).toBe(3);
      expect(res.body.statistics.totalProcessed).toBe(7);
    });

    it('returns 500 when statistics lookup fails', () => {
      mockQueueService.getStatistics.mockImplementation(() => {
        throw new Error('stats failed');
      });
      const handler = createQueueStatusHandler();
      const res = mockRes();
      handler({}, res);
      expect(res.statusCode).toBe(500);
      expect(res.body.code).toBe('QUEUE_STATUS_ERROR');
    });
  });

  describe('createQueueDrainHandler', () => {
    it('drains queued requests for the caller', () => {
      mockQueueService.getQueueStatus.mockReturnValue({ queueSize: 2 });
      mockQueueService.processNextRequest
        .mockReturnValueOnce({ id: 1 })
        .mockReturnValueOnce({ id: 2 })
        .mockReturnValueOnce(null);
      const handler = createQueueDrainHandler();
      const req = { user: { sub: 'user-9' }, ip: '1.2.3.4' };
      const res = mockRes();
      handler(req, res);
      expect(res.body.success).toBe(true);
      expect(res.body.processed).toBe(2);
      expect(res.body.queueType).toBe('user');
    });

    it('returns 500 when drain fails', () => {
      mockQueueService.getQueueStatus.mockImplementation(() => {
        throw new Error('drain failed');
      });
      const handler = createQueueDrainHandler();
      const res = mockRes();
      handler({ ip: '1.2.3.4' }, res);
      expect(res.statusCode).toBe(500);
      expect(res.body.code).toBe('QUEUE_DRAIN_ERROR');
    });
  });
});
