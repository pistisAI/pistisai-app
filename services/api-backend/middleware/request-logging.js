/**
 * Request Logging Middleware for Pistisai API Backend
 *
 * Implements structured request/response logging with correlation IDs
 * for request tracing across distributed systems.
 *
 * @fileoverview Request logging middleware with correlation IDs
 * @version 1.0.0
 */

import { v4 as uuidv4 } from 'uuid';
import logger from '../logger.js';

const SENSITIVE_QUERY_KEY =
  /token|secret|password|passwd|api[_-]?key|authorization|signature/i;
const STATIC_SESSION_SUBPATHS = new Set([
  'current',
  'tokens',
  'cleanup',
  'validate',
  'invalidate',
]);

/**
 * Session tokens have historically travelled in the URL path. Strip them
 * from anything we log so an info-level request log (and its Sentry forward)
 * cannot leak a bearer credential.
 */
export function redactPathForLog(path) {
  if (typeof path !== 'string') {
    return path;
  }
  const validate = path.match(/^(\/auth\/sessions\/validate\/)[^/]+/i);
  if (validate) {
    return `${validate[1]}[REDACTED]`;
  }
  const legacy = path.match(/^(\/auth\/sessions\/)([^/]+)$/i);
  if (legacy && !STATIC_SESSION_SUBPATHS.has(legacy[2].toLowerCase())) {
    return `${legacy[1]}[REDACTED]`;
  }
  return path;
}

/** Redact query-string values whose key names a credential. */
export function redactQueryForLog(query) {
  if (!query || typeof query !== 'object' || Array.isArray(query)) {
    return query;
  }
  const redacted = {};
  for (const [key, value] of Object.entries(query)) {
    redacted[key] = SENSITIVE_QUERY_KEY.test(key) ? '[REDACTED]' : value;
  }
  return redacted;
}

/**
 * Create request logging middleware with correlation ID tracking
 * @returns {Function} Express middleware function
 */
export function createRequestLoggingMiddleware() {
  return (req, res, next) => {
    // Generate or extract correlation ID
    const correlationId = req.headers['x-correlation-id'] || `req-${uuidv4()}`;
    req.correlationId = correlationId;

    // Add correlation ID to response headers
    res.setHeader('X-Correlation-ID', correlationId);

    // Record request start time
    const startTime = Date.now();

    // Log incoming request
    logger.info('Incoming request', {
      correlationId,
      method: req.method,
      path: redactPathForLog(req.path),
      query: redactQueryForLog(req.query),
      userId: req.user?.sub,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    });

    // Intercept response to log completion
    const originalSend = res.send;
    res.send = function (data) {
      const duration = Date.now() - startTime;

      // Log response
      logger.info('Request completed', {
        correlationId,
        method: req.method,
        path: redactPathForLog(req.path),
        statusCode: res.statusCode,
        duration,
        userId: req.user?.sub,
        ip: req.ip,
      });

      // Add timing header
      res.setHeader('X-Response-Time', `${duration}ms`);

      // Call original send
      return originalSend.call(this, data);
    };

    next();
  };
}

/**
 * Default request logging middleware
 */
export const requestLoggingMiddleware = createRequestLoggingMiddleware();

export default requestLoggingMiddleware;
