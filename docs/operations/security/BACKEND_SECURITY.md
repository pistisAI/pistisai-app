# Backend Security Guide

## Overview

This guide documents the middleware actually configured in
`services/api-backend`: request/schema validation, CORS profiles from
`cors-config.js`, and the helmet-backed security headers installed by
`pipeline.js`. There is no `input-sanitizer.js` or `https-enforcer.js` in this
repository; older examples that import them are not valid.

## Security components

### 1. Input validation

- `services/api-backend/middleware/schema-validation.js` and
  `request-validation.js` provide Zod-based validation; routes call
  `validateSchema({ body, params, query })`.
- Database access uses parameterized queries (`$1`, `$2`, …). Never concatenate
  user input into SQL.

### 2. CORS configuration

`middleware/cors-config.js` defines an explicit origin allowlist with no
wildcards:

- `https://app.pistisai.app`
- `https://pistisai.app`
- `https://docs.pistisai.app`
- `https://admin.pistisai.app`
- `https://api.pistisai.app`
- In development: `http(s)://localhost` and `127.0.0.1` on ports 3000, 8080, 5000
- Extra origins via the comma-separated `ADDITIONAL_CORS_ORIGINS` variable

Profiles: `standardCorsOptions`, `adminCorsOptions`, `webhookCorsOptions`, with
ready-to-use `standardCors`, `adminCors` and `webhookCors` middleware.

### 3. Security headers and pipeline

`setupMiddlewarePipeline(app, options)` in `middleware/pipeline.js` installs the
middleware in order: CORS, helmet, request logging with correlation IDs,
metrics, rate limiting, timeout and queuing. Helmet is configured with a
content-security policy (`defaultSrc 'self'`, `connectSrc 'self' https:`,
`scriptSrc`/`styleSrc` self plus inline, `imgSrc` self/data/https) and
`crossOriginResourcePolicy: cross-origin`; helmet defaults such as HSTS remain
in force unless explicitly overridden.

## Integration

```javascript
import express from 'express';
import { setupMiddlewarePipeline } from './middleware/pipeline.js';
import { standardCorsOptions } from './middleware/cors-config.js';

const app = express();
setupMiddlewarePipeline(app, {
  corsOptions: standardCorsOptions,
  rateLimitOptions: { windowMs: 15 * 60 * 1000, max: 100, bridgeMax: 500 },
  timeoutMs: 30000,
});
```

## Best practices

1. Validate every request body, params and query with a Zod schema.
2. Always use parameterized queries.
3. Set `NODE_ENV=production` in production and keep `ADDITIONAL_CORS_ORIGINS`
   explicit and minimal.
4. Do not claim redirect-based HTTPS enforcement or a sanitizer middleware that
   does not exist; TLS termination is a deployment concern.

## Related documentation

- Admin Management API
- Audit Log API
- [Rate Limiting](./RATE_LIMITING.md)
