# @pistisai/middleware-config

Unified middleware configuration module for all PistisAI backend services.

## Overview

This module consolidates 23 middleware files that were previously duplicated across services into a single, well-organized module. It provides all common middleware for:

- **Authentication**: JWT, API keys, admin auth, infrastructure auth
- **Security**: CORS, RBAC (role-based access control), rate limiting, tier checks
- **Logging & Metrics**: Request logging, Prometheus metrics, admin audit logs
- **Validation**: Request validation, schema validation, API versioning
- **Operational**: Graceful shutdown, request timeout, request queuing

## Installation

The module is internal to pistisai-app. No npm install needed.

## Quick Start

### 1. Initialize the Logger (Required)

Before setting up middleware, inject your logger instance:

```javascript
import express from 'express';
import { setLoggerInstance } from '@pistisai/middleware-config/logger';
import { setupMiddlewarePipeline } from '@pistisai/middleware-config/pipeline';

// Your logger (could be Pino, Winston, or custom)
import logger from './logger.js';

// Initialize middleware config logger
setLoggerInstance(logger);

const app = express();

// Now setup all middleware with one call
setupMiddlewarePipeline(app, {
  corsOptions: {
    // CORS config
  },
  rateLimitOptions: {
    // Rate limit config
  },
  timeoutMs: 30000,
  logger, // Pass your logger instance
});
```

### 2. Use Individual Middleware

Import what you need:

```javascript
// Authentication
import {
  authenticateJWT,
  optionalAuth,
  authenticateApiKey,
  authenticateAdmin,
} from '@pistisai/middleware-config/auth';

// Security
import {
  standardCors,
  authorizeRBAC,
  requireTier,
  addTierInfo,
} from '@pistisai/middleware-config/security';

// Logging
import {
  requestLoggingMiddleware,
  metricsCollectionMiddleware,
  adminMetricsMiddleware,
} from '@pistisai/middleware-config/logging';

// Validation
import {
  requestValidationMiddleware,
  validateSchema,
  apiVersioningMiddleware,
} from '@pistisai/middleware-config/validation';

// Operational
import {
  createGracefulShutdownManager,
  requestTimeoutMiddleware,
  createRequestQueuingMiddleware,
} from '@pistisai/middleware-config/operational';
```

## Module Structure

```
auth/                    # Authentication middleware
├── jwt-authenticator.js # JWT token validation
├── admin-auth.js        # Admin-specific auth
├── api-key-auth.js      # API key validation
├── infrastructure-auth.js # Infrastructure token auth
└── composite-auth.js    # Composite auth strategies

security/               # Security middleware
├── cors-config.js       # CORS configuration
├── rbac.js              # Role-based access control
└── tier-check.js        # Subscription tier validation

logging/                # Logging & metrics
├── request-logging.js   # HTTP request logging
├── metrics-collection.js # Prometheus metrics
└── admin-metrics.js     # Admin-specific metrics

validation/             # Request validation
├── request-validation.js # Generic request validation
├── schema-validation.js  # Zod schema validation
└── api-versioning.js    # API version handling

operational/            # Operational concerns
├── graceful-shutdown.js # Server shutdown handling
├── request-timeout.js   # Request timeout enforcement
├── request-queuing.js   # Request queuing
├── admin-rate-limiter.js # Admin rate limiting
└── webhook-rate-limiter.js # Webhook-specific rate limiting

pipeline/              # Main orchestration
└── index.js            # setupMiddlewarePipeline() function

logger.js              # Logger injection system
logger-wrapper.js      # Backward compatibility wrapper
```

## Middleware Pipeline Order

The default pipeline order (critical - see `pipeline/index.js` for details):

1. CORS Middleware
2. Helmet Security Headers
3. Request Logging
4. Metrics Collection
5. API Versioning
6. Backward Compatibility
7. Request Validation
8. Rate Limiting
9. Request Queuing
10. Body Parsing (handled by Express)
11. Request Timeout
12. JWT Authentication
13. RBAC Authorization
14. Tier Check
15. Queue Status

## Configuration Examples

### CORS Configuration

```javascript
import { standardCorsOptions } from '@pistisai/middleware-config/security';

const corsOptions = {
  ...standardCorsOptions,
  origin: ['https://app.example.com'],
  credentials: true,
};

setupMiddlewarePipeline(app, { corsOptions });
```

### Rate Limiting

```javascript
setupMiddlewarePipeline(app, {
  rateLimitOptions: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // 100 requests per window
    bridgeMax: 500, // 500 requests for bridge endpoints
    maxQueueSize: 1000,
    queueTimeoutMs: 30000,
    queueThresholdPercent: 80,
  },
});
```

### Authentication

```javascript
import { authenticateJWT, authorizeRBAC } from '@pistisai/middleware-config';

app.get('/api/resource', authenticateJWT, authorizeRBAC, (req, res) => {
  // Handle authenticated and authorized request
});
```

## Service Migration Guide

### From services/api-backend

1. The `setupMiddlewarePipeline()` function works exactly like before
2. All middleware functions have identical signatures
3. Replace local `middleware/` imports with `@pistisai/middleware-config/` imports

**Before:**
```javascript
import { setupMiddlewarePipeline } from './middleware/pipeline.js';
```

**After:**
```javascript
import { setupMiddlewarePipeline } from '@pistisai/middleware-config/pipeline';
```

### From services/streaming-proxy

1. Replace local TypeScript middleware with JavaScript exports
2. Inject logger instance at startup
3. Use shared auth and security middleware

**Before:**
```typescript
import { authMiddleware } from './src/middleware/auth-middleware';
```

**After:**
```javascript
import { authenticateJWT, optionalAuth } from '@pistisai/middleware-config/auth';
```

## API Reference

### Logger Injection

```javascript
import { setLoggerInstance, getLoggerInstance } from '@pistisai/middleware-config/logger';

// Set logger (call once at startup)
setLoggerInstance(myLogger);

// Get logger (auto-called by middleware)
const logger = getLoggerInstance();
```

### Authentication

- `authenticateJWT(req, res, next)` - Validate JWT token
- `authenticateApiKey(req, res, next)` - Validate API key
- `authenticateAdmin(req, res, next)` - Admin-only authentication
- `authenticateInfrastructure(req, res, next)` - Infrastructure token validation
- `authenticateComposite` - Array of multiple auth methods

### Security

- `standardCors` - Standard CORS middleware
- `authorizeRBAC(req, res, next)` - Role-based authorization
- `addTierInfo(req, res, next)` - Add subscription tier to request
- `requireTier(tier)` - Enforce tier requirement

### Operational

- `setupGracefulShutdown(server, options)` - Setup graceful shutdown
- `createRequestQueuingMiddleware(options)` - Queue requests when rate limit approaches

## Backward Compatibility

All existing middleware in `services/api-backend/middleware/` continues to work. The migration to the shared module is gradual and non-breaking.

Services can:
1. Keep using local middleware while gradually adopting shared module
2. Override shared middleware with service-specific implementations
3. Mix shared and local middleware in the same app

## Testing

All middleware is tested via:
- Unit tests for each middleware function
- Integration tests in each service
- End-to-end tests for the complete pipeline

Run tests:
```bash
cd services/api-backend && npm test
cd services/streaming-proxy && npm test
```

## Contributing

When modifying shared middleware:
1. Update the file in `lib/middleware-config/`
2. Run tests in all dependent services
3. Update CHANGELOG.md
4. Create PR with migration notes

## Support

- Documentation: See individual module README files
- Issues: File against `pistisai-app` repo with `[middleware-config]` tag
- Questions: Contact backend team
