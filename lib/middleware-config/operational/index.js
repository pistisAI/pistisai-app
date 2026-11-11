/**
 * Operational Middleware Module
 *
 * Graceful shutdown, request timeout, queuing, and rate limiting
 */

// Graceful Shutdown
export {
  createGracefulShutdownManager,
  setupGracefulShutdown,
} from './graceful-shutdown.js';

// Request Timeout
export {
  createRequestTimeoutMiddleware,
  requestTimeoutMiddleware,
} from './request-timeout.js';

// Request Queuing
export {
  createRequestQueuingMiddleware,
  createQueueStatusMiddleware,
  createQueueStatusHandler,
  createQueueDrainHandler,
} from './request-queuing.js';

// Admin Rate Limiting
export {
  createAdminRateLimiter,
  adminRateLimiter,
  adminReadOnlyLimiter,
  adminExpensiveLimiter,
  adminBurstLimiter,
  adminCriticalLimiter,
  getRateLimitStats,
  combineRateLimiters,
} from './admin-rate-limiter.js';

// Webhook Rate Limiting
export {
  webhookRateLimiterMiddleware,
  webhookRateLimitConfigMiddleware,
} from './webhook-rate-limiter.js';

// Endpoint Rate Limiting
export {
  createEndpointRateLimiter,
  createEndpointRateLimiters,
  createTieredRateLimiter,
  getRateLimitMetrics,
  ENDPOINT_LIMITS,
} from './endpoint-rate-limiter.js';
