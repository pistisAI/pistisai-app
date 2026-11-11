/**
 * Idempotency Middleware
 *
 * Provides request deduplication for idempotent operations (payments, subscriptions, etc.).
 * Uses Redis to track idempotency keys and return cached responses for duplicate requests.
 *
 * @fileoverview Idempotency key tracking and deduplication
 * @version 1.0.0
 */

import { v4 as uuidv4 } from 'uuid';
import logger from '../logger.js';

const IDEMPOTENCY_KEY_HEADER = 'idempotency-key';
export { IDEMPOTENCY_KEY_HEADER };
const IDEMPOTENCY_TTL_SECONDS = 24 * 60 * 60; // 24 hours
const IDEMPOTENCY_PREFIX = 'idempotency:';

/**
 * Store idempotency response in cache
 * @param {Object} cache - Redis or memory cache instance
 * @param {string} key - Idempotency key
 * @param {Object} response - Response data to cache
 */
function storeIdempotencyResponse(cache, key, response) {
  if (!cache) {
return;
}

  try {
    const cacheKey = `${IDEMPOTENCY_PREFIX}${key}`;
    const data = {
      statusCode: response.statusCode,
      headers: response.headers || {},
      body: response.body,
      timestamp: new Date().toISOString(),
    };

    if (cache.setex) {
      // Redis-like cache - async
      cache.setex(cacheKey, IDEMPOTENCY_TTL_SECONDS, JSON.stringify(data));
    } else if (cache.set) {
      // Memory-like cache with TTL support - synchronous
      cache.set(cacheKey, data, IDEMPOTENCY_TTL_SECONDS * 1000);
    }

    logger.info('Idempotency response stored', {
      idempotencyKey: key,
      statusCode: data.statusCode,
      ttlSeconds: IDEMPOTENCY_TTL_SECONDS,
    });
  } catch (error) {
    logger.error('Failed to store idempotency response', {
      error: error.message,
      idempotencyKey: key,
    });
  }
}

/**
 * Retrieve cached idempotency response
 * @param {Object} cache - Redis or memory cache instance
 * @param {string} key - Idempotency key
 * @returns {Object|null} Cached response or null
 */
function getIdempotencyResponse(cache, key) {
  if (!cache) {
return null;
}

  try {
    const cacheKey = `${IDEMPOTENCY_PREFIX}${key}`;
    let data;

    if (cache.get) {
      // Both Redis and memory cache have .get
      data = cache.get(cacheKey);
    }

    if (!data) {
return null;
}

    const parsed = typeof data === 'string' ? JSON.parse(data) : data;

    logger.info('Idempotency response retrieved from cache', {
      idempotencyKey: key,
      statusCode: parsed.statusCode,
    });

    return parsed;
  } catch (error) {
    logger.error('Failed to retrieve idempotency response', {
      error: error.message,
      idempotencyKey: key,
    });
    return null;
  }
}

/**
 * Create idempotency middleware
 *
 * Tracks requests by idempotency key and returns cached responses for duplicates.
 * Idempotency keys can be provided via:
 * - Idempotency-Key header
 * - idempotency_key query parameter (deprecated but supported)
 *
 * @param {Object} options - Configuration options
 * @param {Object} options.cache - Cache instance (Redis or memory cache)
 * @param {string[]} options.idempotentMethods - HTTP methods to track (default: ['POST', 'PATCH', 'DELETE'])
 * @param {string[]} options.idempotentRoutes - Route patterns to track (optional, if empty all routes are tracked)
 * @returns {Function} Express middleware
 */
export function createIdempotencyMiddleware(options = {}) {
  const {
    cache = null,
    idempotentMethods = ['POST', 'PATCH', 'DELETE'],
    idempotentRoutes = [],
  } = options;

  return async (req, res, next) => {
    try {
      // Skip if no cache is configured
      if (!cache) {
        return next();
      }

      // Check if this is an idempotent method
      if (!idempotentMethods.includes(req.method)) {
        return next();
      }

      // If idempotent routes are specified, check if this route matches
      if (idempotentRoutes.length > 0) {
        const matchesRoute = idempotentRoutes.some((pattern) => {
          if (pattern instanceof RegExp) {
            return pattern.test(req.path);
          }
          return req.path.startsWith(pattern);
        });

        if (!matchesRoute) {
          return next();
        }
      }

      // Extract idempotency key from header or query parameter
      let idempotencyKey =
        req.headers[IDEMPOTENCY_KEY_HEADER] ||
        req.query.idempotency_key ||
        req.body?.idempotency_key;

      if (!idempotencyKey) {
        // Generate one if not provided
        idempotencyKey = uuidv4();
        logger.debug('Generated idempotency key for request', {
          method: req.method,
          path: req.path,
          idempotencyKey,
        });
      }

      // Attach to request for later use
      req.idempotencyKey = idempotencyKey;

      // Check for cached response
      const cachedResponse = getIdempotencyResponse(cache, idempotencyKey);

      if (cachedResponse) {
        logger.info('Returning cached response for duplicate request', {
          method: req.method,
          path: req.path,
          idempotencyKey,
          statusCode: cachedResponse.statusCode,
        });

        // Set response headers
        if (cachedResponse.headers) {
          Object.entries(cachedResponse.headers).forEach(([key, value]) => {
            res.setHeader(key, value);
          });
        }

        // Add idempotency header and replay flag
        res.setHeader(IDEMPOTENCY_KEY_HEADER, idempotencyKey);
        res.setHeader('Idempotency-Replay', 'true');

        return res
          .status(cachedResponse.statusCode)
          .json(cachedResponse.body);
      }

      // Set idempotency key header on response
      res.setHeader(IDEMPOTENCY_KEY_HEADER, idempotencyKey);

      // Intercept res.json to cache the response
      const originalJson = res.json.bind(res);
      res.json = function (body) {
        // Capture status code before json is called
        const statusCode = res.statusCode || 200;

        // Store response for future idempotent requests
        // For MemoryCache, this is synchronous
        storeIdempotencyResponse(cache, idempotencyKey, {
          statusCode,
          headers: {
            'content-type': 'application/json',
          },
          body,
        });

        return originalJson(body);
      };

      // Also intercept send for non-JSON responses
      const originalSend = res.send.bind(res);
      res.send = function (body) {
        const statusCode = res.statusCode || 200;

        storeIdempotencyResponse(cache, idempotencyKey, {
          statusCode,
          headers: {
            'content-type': res.getHeader('content-type') || 'text/plain',
          },
          body,
        });

        return originalSend(body);
      };

      next();
    } catch (error) {
      logger.error('Idempotency middleware error', {
        error: error.message,
        stack: error.stack,
        method: req.method,
        path: req.path,
      });

      // Don't fail the request due to idempotency errors
      next();
    }
  };
}

/**
 * Validate idempotency key format
 * @param {string} key - Idempotency key to validate
 * @returns {boolean} True if valid
 */
export function validateIdempotencyKey(key) {
  if (!key || typeof key !== 'string') {
    return false;
  }

  // Accept UUID format or any alphanumeric string up to 256 chars
  return /^[a-zA-Z0-9\-._~]{1,256}$/.test(key);
}

/**
 * Extract idempotency key from request
 * @param {Object} req - Express request object
 * @returns {string|null} Idempotency key or null
 */
export function extractIdempotencyKey(req) {
  const key =
    req.headers[IDEMPOTENCY_KEY_HEADER] ||
    req.query.idempotency_key ||
    req.body?.idempotency_key;

  return key || null;
}

/**
 * Check if response is a replay (cached response)
 * @param {Object} res - Express response object
 * @returns {boolean} True if response is a replay
 */
export function isIdempotencyReplay(res) {
  return res.getHeader('Idempotency-Replay') === 'true';
}

export default {
  createIdempotencyMiddleware,
  validateIdempotencyKey,
  extractIdempotencyKey,
  isIdempotencyReplay,
  IDEMPOTENCY_KEY_HEADER,
};
