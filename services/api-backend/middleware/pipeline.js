/**
 * Middleware Pipeline Configuration for Pistisai API Backend
 *
 * Defines the correct order of middleware for the Express application.
 * The order is critical for proper request handling and security.
 *
 * @fileoverview Middleware pipeline configuration
 * @version 1.0.0
 */

import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import express from 'express';

import { traceContextMiddleware } from './trace-context.js';
import { sentryTraceContextMiddleware } from './sentry-trace-context.js';
import { requestLoggingMiddleware } from './request-logging.js';
import { requestValidationMiddleware } from './request-validation.js';
import { requestTimeoutMiddleware } from './request-timeout.js';
import { authenticateJWT } from './auth.js';
import { authorizeRBAC } from './rbac.js';
import { addTierInfo } from './tier-check.js';
import {
  createRequestQueuingMiddleware,
  createQueueStatusMiddleware,
} from './request-queuing.js';
import { metricsCollectionMiddleware } from './metrics-collection.js';
import {
  apiVersioningMiddleware,
  backwardCompatibilityMiddleware,
} from './api-versioning.js';
import logger from '../logger.js';
import { createCircuitBreakerMiddleware } from './circuit-breaker.js';
import {
  dynamicBrandCorsMiddleware,
  logBrandCorsDecisions,
  initializeBrandCORSPolicies,
} from './brand-cors-config.js';

/**
 * Middleware Pipeline Order (CRITICAL - DO NOT CHANGE WITHOUT UNDERSTANDING IMPLICATIONS)
 *
 * 1. Sentry Request Handler - Removed (Handled by Sentry.init in server.js)
 * 2. Sentry Tracing Handler - Removed (Handled by Sentry.init in server.js)
 * 3. CORS Middleware - Handle preflight requests early
 * 4. Helmet Security Headers - Security headers
 * 4.5. Trace Context - Extract/generate trace IDs (W3C traceparent)
 * 5. Request Logging - Log all requests with trace and correlation IDs
 * 6. API Versioning - Extract and validate API version from URL
 * 7. Backward Compatibility - Apply version-specific transformations
 * 8. Request Validation - Validate request format
 * 8.5. Circuit Breaker - Protect against cascading failures
 * 9. Rate Limiting - Protect against abuse
 * 10. Request Queuing - Queue requests when rate limit approached
 * 11. Body Parsing - Parse request body
 * 12. Request Timeout - Set timeout for long-running requests
 * 13. Authentication - Validate JWT tokens
 * 14. Authorization - Check user permissions
 * 15. Queue Status - Add queue status to request
 * 16. Error Handling - Catch and format errors
 */

/**
 * Setup middleware pipeline on Express app
 * @param {Object} app - Express application instance
 * @param {Object} options - Configuration options
 * @returns {void}
 */
export function setupMiddlewarePipeline(app, options = {}) {
  const {
    rateLimitOptions = {},
    timeoutMs = 30000,
  } = options;

  // Initialize brand CORS policies
  initializeBrandCORSPolicies();

  // 3. CORS Middleware - Handle preflight requests with brand-aware enforcement
  // Uses dynamic brand-aware CORS middleware for tenant isolation and per-brand policy enforcement
  try {
    // First, add logging for CORS decisions (for observability)
    app.use(logBrandCorsDecisions);

    // Then, apply the brand-aware CORS enforcement middleware
    app.use(dynamicBrandCorsMiddleware);

    logger.info('Brand-aware CORS middleware initialized', {
      mode: 'dynamic-per-brand',
    });
  } catch (error) {
    logger.error('Error setting up brand-aware CORS', {
      error: error.message,
      stack: error.stack,
    });
    throw error;
  }

  // 4. Helmet Security Headers
  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          connectSrc: ["'self'", 'https:'],
          scriptSrc: ["'self'", "'unsafe-inline'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", 'data:', 'https:'],
        },
      },
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  // 4.5. Trace Context - Extract/generate trace IDs (W3C traceparent)
  app.use(traceContextMiddleware);

  // 4.75. Sentry Trace Context - Attach trace IDs to Sentry scope
  app.use(sentryTraceContextMiddleware);

  // 5. Request Logging - Log all requests with correlation IDs
  app.use(requestLoggingMiddleware);

  // 5.5. Metrics Collection - Collect HTTP request metrics for Prometheus
  app.use(metricsCollectionMiddleware);

  // 6. API Versioning - Extract and validate API version from URL
  app.use(apiVersioningMiddleware());

  // 6.5. Backward Compatibility - Apply version-specific transformations
  app.use(backwardCompatibilityMiddleware());

  // 8. Request Validation - Validate request format
  app.use(requestValidationMiddleware);

  // 8.5. Circuit Breaker - Protect against cascading failures for external services
  const circuitBreakerMiddleware = createCircuitBreakerMiddleware({
    breakers: {
      ollama: {
        failureThreshold: 5,
        successThreshold: 2,
        timeout: 30000,
      },
      stripe: {
        failureThreshold: 5,
        successThreshold: 2,
        timeout: 30000,
      },
      sendgrid: {
        failureThreshold: 5,
        successThreshold: 2,
        timeout: 30000,
      },
      slack: {
        failureThreshold: 5,
        successThreshold: 2,
        timeout: 30000,
      },
    },
    isExternalServiceCall: (req) => {
      // Identify external service calls based on route/request
      if (req.path.startsWith('/api/ollama')) {
        return 'ollama';
      }
      if (req.path.includes('/payment') || req.path.includes('/stripe')) {
        return 'stripe';
      }
      if (req.path.includes('/email') || req.path.includes('/sendgrid')) {
        return 'sendgrid';
      }
      if (req.path.includes('/slack')) {
        return 'slack';
      }
      return null;
    },
    getFallbackResponse: (req, serviceName) => ({
      status: 503,
      body: {
        error: 'Service Unavailable',
        message: `External service "${serviceName}" is temporarily unavailable. Please retry in a moment.`,
        service: serviceName,
      },
    }),
  });
  app.use(circuitBreakerMiddleware);

  // 9. Rate Limiting - Protect against abuse
  const standardLimiter = rateLimit({
    windowMs: rateLimitOptions.windowMs || 15 * 60 * 1000,
    max: rateLimitOptions.max || 100,
    message: 'Too many requests from this IP, please try again later.',
    standardHeaders: true,
    legacyHeaders: false,
  });

  const bridgeLimiter = rateLimit({
    windowMs: rateLimitOptions.windowMs || 15 * 60 * 1000,
    max: rateLimitOptions.bridgeMax || 500,
    message: 'Too many bridge requests from this IP, please try again later.',
    standardHeaders: true,
    legacyHeaders: false,
  });

  app.use((req, res, next) => {
    // Skip rate limiting for OPTIONS (preflight) requests
    if (req.method === 'OPTIONS') {
      return next();
    }
    // Skip rate limiting for health checks
    if (req.path === '/health') {
      return next();
    }
    // Apply more lenient limits to bridge routes
    if (req.path.startsWith('/api/bridge/')) {
      return bridgeLimiter(req, res, next);
    }
    // Apply standard limits to all other routes
    return standardLimiter(req, res, next);
  });

  // 10. Request Queuing - Queue requests when rate limit approached
  const requestQueuingMiddleware = createRequestQueuingMiddleware({
    maxQueueSize: rateLimitOptions.maxQueueSize || 1000,
    queueTimeoutMs: rateLimitOptions.queueTimeoutMs || 30000,
    queueThresholdPercent: rateLimitOptions.queueThresholdPercent || 80,
  });
  app.use(requestQueuingMiddleware);

  // 11. Body Parsing - Parse request body
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // 12. Request Timeout - Set timeout for long-running requests
  app.use(requestTimeoutMiddleware);

  // 13. Authentication - Validate JWT tokens (optional for public endpoints)
  // Note: This is applied selectively to protected routes, not globally

  // 14. Authorization - RBAC middleware for role-based access control
  // Applied globally to attach user roles to all requests
  app.use(authorizeRBAC);

  // 15. Queue Status - Add queue status to request
  const queueStatusMiddleware = createQueueStatusMiddleware();
  app.use(queueStatusMiddleware);

  logger.info('Middleware pipeline configured successfully', {
    corsEnabled: true,
    helmetEnabled: true,
    loggingEnabled: true,
    validationEnabled: true,
    rateLimitingEnabled: true,
    requestQueuingEnabled: true,
    rbacEnabled: true,
    timeoutMs,
  });
}

/**
 * Get authentication middleware for protected routes
 * @returns {Function} Express middleware function
 */
export function getAuthMiddleware() {
  return authenticateJWT;
}

/**
 * Get tier info middleware for authenticated routes
 * @returns {Function} Express middleware function
 */
export function getTierInfoMiddleware() {
  return addTierInfo;
}

/**
 * Get RBAC authorization middleware
 * @returns {Function} Express middleware function
 */
export function getRBACMiddleware() {
  return authorizeRBAC;
}

export default {
  setupMiddlewarePipeline,
  getAuthMiddleware,
  getTierInfoMiddleware,
  getRBACMiddleware,
};
