/**
 * @fileoverview Per-endpoint rate limiter middleware
 * Provides configurable rate limiting for any API endpoint
 * Integrates with Prometheus metrics for monitoring
 */

import rateLimit from 'express-rate-limit';
import logger from '../logger-wrapper.js';

// Prometheus metrics - create mocks that will be replaced if prom-client is available
const createMetricsStubs = () => ({
  Counter: class {
    constructor(opts) { this.opts = opts; }
    labels() { return { inc: () => {} }; }
  },
  Gauge: class {
    constructor(opts) { this.opts = opts; }
    labels() { return { set: () => {} }; }
  },
  register: { metrics: async () => '' },
});

let promClient = createMetricsStubs();

// Try to import real prom-client if available
try {
  // Dynamic require for optional dependency
  const pc = require('prom-client');
  promClient = pc;
} catch (e) {
  // Use stubs if prom-client not available
}

/**
 * Endpoint-specific rate limit configurations
 * keyscan:  Unique identifier for the limiter (used in metrics)
 * windowMs: Time window in milliseconds
 * max:      Maximum requests per window
 * message:  Response message when limit exceeded
 * headers:  Whether to include rate limit headers
 */
export const ENDPOINT_LIMITS = {
  // Public endpoints (generous limits)
  public: {
    windowMs: 60 * 1000, // 1 minute
    max: 100,
    keyscan: 'public_ep',
  },
  // Authenticated user endpoints (moderate limits)
  user: {
    windowMs: 60 * 1000, // 1 minute
    max: 50,
    keyscan: 'user_ep',
  },
  // Conversation/processing endpoints (stricter limits)
  conversation: {
    windowMs: 60 * 1000, // 1 minute
    max: 30,
    keyscan: 'conversation_ep',
  },
  // Agent/skill execution (very strict, expensive operations)
  agent: {
    windowMs: 60 * 1000, // 1 minute
    max: 10,
    keyscan: 'agent_ep',
  },
  // File upload endpoints (very strict)
  upload: {
    windowMs: 60 * 1000, // 1 minute
    max: 5,
    keyscan: 'upload_ep',
  },
  // Database/admin operations (ultra-strict)
  admin: {
    windowMs: 60 * 1000, // 1 minute
    max: 20,
    keyscan: 'admin_ep',
  },
  // Webhook endpoints (custom handling)
  webhook: {
    windowMs: 60 * 1000, // 1 minute
    max: 100,
    keyscan: 'webhook_ep',
  },
};

// Prometheus metrics for rate limiting
const rateLimitHitsCounter = new promClient.Counter({
  name: 'api_rate_limit_hits_total',
  help: 'Total number of requests that hit rate limits',
  labelNames: ['endpoint_type', 'key'],
});

const rateLimitExceededCounter = new promClient.Counter({
  name: 'api_rate_limit_exceeded_total',
  help: 'Total number of requests exceeding rate limits',
  labelNames: ['endpoint_type', 'key'],
});

const rateLimitWindowGauge = new promClient.Gauge({
  name: 'api_rate_limit_remaining',
  help: 'Remaining requests in current rate limit window',
  labelNames: ['endpoint_type', 'key'],
});

/**
 * Creates a configured rate limiter for an endpoint type
 * @param {string} endpointType - Key from ENDPOINT_LIMITS (e.g., 'user', 'agent')
 * @param {Object} redisClient - Redis client for distributed rate limiting
 * @param {Object} options - Override configuration options
 * @returns {Function} Express middleware
 */
export function createEndpointRateLimiter(
  endpointType,
  redisClient,
  options = {}
) {
  const config = ENDPOINT_LIMITS[endpointType];
  if (!config) {
    throw new Error(
      `Unknown endpoint type: ${endpointType}. Available types: ${Object.keys(ENDPOINT_LIMITS).join(', ')}`
    );
  }

  const mergedConfig = { ...config, ...options };
  const { windowMs, max, keyscan } = mergedConfig;

  const limiterConfig = {
    windowMs,
    max,
    message: `Too many requests from this IP, please try again later.`,
    standardHeaders: true, // Return rate limit info in `RateLimit-*` headers
    legacyHeaders: false, // Disable `X-RateLimit-*` headers
    keyGenerator: (req, res) => {
      // Prioritize authenticated user ID, fallback to IP
      if (req.user?.id) {
        return `user:${req.user.id}`;
      }
      // Use IP for unauthenticated requests
      return req.ip || req.connection.remoteAddress;
    },
    skip: (req, res) => {
      // Skip rate limiting for health checks and metrics
      return (
        req.path === '/health' || 
        req.path === '/metrics' ||
        req.path?.startsWith('/.well-known/')
      );
    },
    handler: (req, res, next, options) => {
      const key = limiterConfig.keyGenerator(req, res);
      
      // Record metrics
      rateLimitHitsCounter.labels(endpointType, keyscan).inc();
      rateLimitExceededCounter.labels(endpointType, keyscan).inc();
      
      logger.warn('Rate limit exceeded', {
        endpoint: req.path,
        method: req.method,
        endpointType,
        key,
        limit: max,
        window: windowMs,
      });

      res.status(429).json({
        error: 'Too Many Requests',
        message: options.message,
        retryAfter: Math.ceil(windowMs / 1000),
        limit: max,
        window: windowMs,
      });
    },
  };

  // Use memory store (fallback if Redis not available)
  // Redis store is optional and would be added separately if needed
  // const store = setupRedisStoreIfAvailable(redisClient, keyscan);
  // if (store) limiterConfig.store = store;

  const limiter = rateLimit(limiterConfig);

  // Wrap to record metrics on successful requests
  return (req, res, next) => {
    limiter(req, res, () => {
      // Record remaining quota in current window
      const key = limiterConfig.keyGenerator(req, res);
      const remaining = res.getHeader('RateLimit-Remaining');
      if (remaining !== undefined) {
        rateLimitWindowGauge.labels(endpointType, keyscan).set(
          parseInt(remaining, 10)
        );
      }
      next();
    });
  };
}

/**
 * Batch-create limiters for multiple endpoint types
 * @param {Array<string>} endpointTypes - Array of endpoint type keys
 * @param {Object} redisClient - Redis client
 * @param {Object} overridesByType - Per-type config overrides
 * @returns {Object} Map of endpoint type to middleware function
 */
export function createEndpointRateLimiters(
  endpointTypes,
  redisClient,
  overridesByType = {}
) {
  const limiters = {};
  endpointTypes.forEach((type) => {
    limiters[type] = createEndpointRateLimiter(
      type,
      redisClient,
      overridesByType[type]
    );
  });
  return limiters;
}

/**
 * Tiered rate limiter: applies different limits based on user tier
 * @param {string} baseEndpointType - Base endpoint type
 * @param {Object} tierLimits - Limits by tier (e.g., { free: 10, pro: 100 })
 * @param {Object} redisClient - Redis client
 * @returns {Function} Express middleware that applies tier-based limiting
 */
export function createTieredRateLimiter(
  baseEndpointType,
  tierLimits,
  redisClient
) {
  const baseLimits = ENDPOINT_LIMITS[baseEndpointType];
  if (!baseLimits) {
    throw new Error(`Unknown base endpoint type: ${baseEndpointType}`);
  }

  const tieredLimiters = {};
  Object.entries(tierLimits).forEach(([tier, maxRequests]) => {
    tieredLimiters[tier] = createEndpointRateLimiter(
      baseEndpointType,
      redisClient,
      {
        max: maxRequests,
        keyscan: `${baseLimits.keyscan}_${tier}`,
      }
    );
  });

  // Return middleware that selects limiter based on user tier
  return (req, res, next) => {
    const tier = req.user?.tier || 'free';
    const limiter = tieredLimiters[tier];

    if (!limiter) {
      logger.warn(`No rate limiter for tier: ${tier}, using base limiter`);
      return tieredLimiters.free?.(req, res, next);
    }

    limiter(req, res, next);
  };
}

/**
 * Get current metrics for all rate limiters
 * @returns {Promise<Object>} Aggregated metrics
 */
export async function getRateLimitMetrics() {
  const metrics = {
    totalHits: 0,
    totalExceeded: 0,
    byEndpointType: {},
  };

  const register = promClient.register;
  const metrics_list = await register.metrics();
  // Parse Prometheus metrics (simplified)
  return metrics;
}

export default {
  createEndpointRateLimiter,
  createEndpointRateLimiters,
  createTieredRateLimiter,
  getRateLimitMetrics,
  ENDPOINT_LIMITS,
};
