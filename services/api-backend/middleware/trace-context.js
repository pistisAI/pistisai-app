/**
 * Distributed Trace Context Middleware for Pistisai API Backend
 *
 * Implements W3C Trace Context (https://www.w3.org/TR/trace-context/) for
 * distributed tracing across services. Generates or extracts trace IDs and
 * integrates with structured logging and observability tools (Sentry, ELK, Datadog).
 *
 * @fileoverview Trace context middleware with W3C support
 * @version 1.0.0
 */

import { v4 as uuidv4 } from 'uuid';

/**
 * Parse W3C traceparent header
 * Format: 00-trace-id(32-hex)-span-id(16-hex)-flags(2-hex)
 * Example: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
 *
 * @param {string} traceparent - The traceparent header value
 * @returns {Object|null} Parsed trace context or null if invalid
 */
function parseTraceparent(traceparent) {
  if (!traceparent || typeof traceparent !== 'string') {
    return null;
  }

  const parts = traceparent.split('-');
  if (parts.length !== 4) {
    return null;
  }

  const [version, traceId, spanId, flags] = parts;

  // Validate format
  if (version !== '00' || traceId.length !== 32 || spanId.length !== 16 || flags.length !== 2) {
    return null;
  }

  // Validate hex characters
  if (!/^[0-9a-f]{32}$/.test(traceId) || !/^[0-9a-f]{16}$/.test(spanId) || !/^[0-9a-f]{2}$/.test(flags)) {
    return null;
  }

  return {
    version,
    traceId,
    spanId,
    flags,
    sampled: (parseInt(flags, 16) & 0x01) !== 0,
  };
}

/**
 * Generate a new W3C traceparent header
 * @returns {string} Valid W3C traceparent header
 */
function generateTraceparent() {
  const version = '00';
  // Remove dashes from UUID to get 32 hex chars
  const traceId = uuidv4().replace(/-/g, '');
  // Generate random 16 hex char span ID
  const spanId = Math.random().toString(16).substring(2, 10) +
                 Math.random().toString(16).substring(2, 10);
  const flags = '01'; // Always sampled for now

  return `${version}-${traceId}-${spanId}-${flags}`;
}

/**
 * Create trace context middleware
 * @returns {Function} Express middleware function
 */
export function createTraceContextMiddleware() {
  return (req, res, next) => {
    try {
      // Extract or generate trace context
      const incomingTraceparent = req.headers.traceparent;
      let traceContext = parseTraceparent(incomingTraceparent);

      if (!traceContext) {
        // Generate new trace context if not provided
        const newTraceparent = generateTraceparent();
        traceContext = parseTraceparent(newTraceparent);
        req.headers.traceparent = newTraceparent;
      }

      // Attach trace context to request
      req.traceId = traceContext.traceId;
      req.traceContext = traceContext;

      // Extract tracestate header if present
      const tracestate = req.headers.tracestate || '';
      req.tracestate = tracestate;

      // Add trace headers to response (W3C standard)
      res.setHeader('traceparent', req.headers.traceparent);
      if (tracestate) {
        res.setHeader('tracestate', tracestate);
      }

      // Also add as legacy header for backward compatibility
      res.setHeader('X-Trace-ID', req.traceId);

      // Continue to next middleware
      next();
    } catch {
      // On error, generate a new trace context and continue
      const newTraceparent = generateTraceparent();
      const traceContext = parseTraceparent(newTraceparent);
      req.traceId = traceContext.traceId;
      req.traceContext = traceContext;
      req.headers.traceparent = newTraceparent;

      res.setHeader('traceparent', newTraceparent);
      res.setHeader('X-Trace-ID', req.traceId);

      next();
    }
  };
}

/**
 * Default trace context middleware
 */
export const traceContextMiddleware = createTraceContextMiddleware();

export default traceContextMiddleware;
