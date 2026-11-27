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

// Matches token, access_token, refresh_token, jwt, cf_jwt, apiKey, api_key,
// and other credential-looking query keys.
const SENSITIVE_QUERY_KEY =
  /token|secret|password|passwd|api[_-]?key|authorization|signature|jwt/i;
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
  // The session routes are mounted under several prefixes (`/auth/sessions`
  // and `/api/auth/sessions`, see registerRoutes in server.js), so match the
  // `/auth/sessions/` segment wherever it sits in the path.
  const validate = path.match(/^(.*?\/auth\/sessions\/validate\/)[^/?#]+/i);
  if (validate) {
    return `${validate[1]}[REDACTED]${redactUrlQuery(path.slice(validate[0].length))}`;
  }
  const legacy = path.match(
    /^(.*?\/auth\/sessions\/)([^/?#]+)(?=\/?(?:$|[?#]))/i,
  );
  if (legacy && !STATIC_SESSION_SUBPATHS.has(legacy[2].toLowerCase())) {
    return `${legacy[1]}[REDACTED]${redactUrlQuery(path.slice(legacy[0].length))}`;
  }
  return redactUrlQuery(path);
}

/**
 * Redact credential-looking query parameter values inside a URL or path
 * string (for example `?token=...`, `?cf_jwt=...`, `?apiKey=...`).
 */
export function redactUrlQuery(url) {
  if (typeof url !== 'string') {
    return url;
  }
  const queryStart = url.indexOf('?');
  if (queryStart === -1) {
    return url;
  }
  const hashStart = url.indexOf('#', queryStart);
  const end = hashStart === -1 ? url.length : hashStart;
  const query = url
    .slice(queryStart + 1, end)
    .split('&')
    .map((pair) => {
      const eq = pair.indexOf('=');
      const rawKey = eq === -1 ? pair : pair.slice(0, eq);
      let key = rawKey;
      try {
        key = decodeURIComponent(rawKey.replace(/\+/g, ' '));
      } catch {
        // keep the raw key
      }
      return eq !== -1 && SENSITIVE_QUERY_KEY.test(key)
        ? `${rawKey}=[REDACTED]`
        : pair;
    })
    .join('&');
  return `${url.slice(0, queryStart)}?${query}${url.slice(end)}`;
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
