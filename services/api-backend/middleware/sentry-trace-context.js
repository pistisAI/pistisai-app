/**
 * Sentry Trace Context Integration Middleware
 *
 * Attaches trace IDs from trace context to Sentry scope for
 * correlation between logs, traces, and error reports.
 *
 * @fileoverview Middleware to integrate trace context with Sentry
 * @version 1.0.0
 */

import * as Sentry from '@sentry/node';

/**
 * Create Sentry trace context middleware
 * Attaches trace ID and span ID to Sentry scope
 * @returns {Function} Express middleware function
 */
export function createSentryTraceContextMiddleware() {
  return (req, res, next) => {
    try {
      // Get trace context from request (set by traceContextMiddleware)
      const traceId = req.traceId;
      const traceContext = req.traceContext || {};
      const correlationId = req.correlationId;

      // Set trace ID in Sentry scope
      Sentry.withScope((scope) => {
        if (traceId) {
          scope.setTag('traceId', traceId);
        }
        if (traceContext.spanId) {
          scope.setTag('traceSpanId', traceContext.spanId);
        }
        if (traceContext.flags) {
          scope.setTag('traceFlags', traceContext.flags);
        }
        if (correlationId) {
          scope.setTag('correlationId', correlationId);
        }

        // Also set as part of the transaction name if available
        if (req.method && req.path) {
          const transaction = `${req.method} ${req.path}`;
          scope.setTransactionName(transaction);
        }

        next();
      });
    } catch (error) {
      // Continue even if Sentry integration fails
      console.error('Error in Sentry trace context middleware:', error);
      next();
    }
  };
}

/**
 * Default Sentry trace context middleware
 */
export const sentryTraceContextMiddleware = createSentryTraceContextMiddleware();

export default sentryTraceContextMiddleware;
