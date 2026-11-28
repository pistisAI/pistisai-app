# Backend middleware guide

How Express middleware is ordered and shared across Node services. Express majors
differ: **api-backend** and **streaming-proxy** are Express 5;
**tailscale-relay** is Express 4. `backend/auth` is quarantined and is not a
running Express service. Do not copy middleware verbatim across that
boundary without checking the Express major.

## Standard order (api-backend)

Source of truth: `services/api-backend/middleware/pipeline.js`
(`setupMiddlewarePipeline`).

| Step | Middleware | Purpose |
|------|------------|---------|
| 1–2 | Sentry init (in `server.js`) | Capture errors early |
| 3 | CORS (`middleware/cors-config.js`) | Preflight and origin policy |
| 4 | Helmet | Security headers baseline |
| 5 | Request logging | Correlation IDs |
| 5.5 | Metrics | Prometheus HTTP metrics |
| 6 | API versioning | Version from URL |
| 6.5 | Backward compatibility | Version-specific transforms |
| 8 | Request validation | Request shape checks |
| 9 | Rate limiting | Abuse protection (health/`OPTIONS` skipped) |
| 10 | Request queuing | Back-pressure near rate limit |
| 11 | Body parsing | JSON / urlencoded (10mb) |
| 12 | Request timeout | Bound long handlers |
| 13 | Auth (selective) | JWT on protected routes only |
| 14 | RBAC | Attach roles |
| 15 | Queue status | Expose queue info on request |
| Final | 404 + error handler | After all routes |

Do not reorder this list without understanding auth/rate-limit interactions.

## Security headers baseline (Helmet)

api-backend Helmet config (in the pipeline) sets:

- `contentSecurityPolicy` with `defaultSrc 'self'`, `connectSrc 'self' https:`,
  inline script/style allowances needed by the current admin surfaces, and
  `imgSrc` including `data:` / `https:`
- `crossOriginResourcePolicy: cross-origin` for cross-origin asset use

Other services should match this baseline when they terminate HTTP for browsers.

## CORS

- **api-backend:** `middleware/cors-config.js` → `standardCorsOptions`
- Pass service-specific overrides into `setupMiddlewarePipeline(app, { corsOptions })`

## Rate limiting

- Default window: 15 minutes
- Standard max: 100; bridge routes (`/api/bridge/`): 500
- Skips: `OPTIONS`, `/health`

## Auth

- **api-backend:** `authenticateJWT` / composite auth / API-key middleware applied
  per route group, not globally in the pipeline
- **streaming-proxy:** JWT validation middleware under `src/middleware/`
  (Cloudflare Access team JWKS + `CF_ACCESS_AUD`, RS256)
- **backend/auth:** quarantined. Do not mount it or extend it as an auth service. Active auth is Cloudflare Access in api-backend

## Per-service notes

### api-backend (Express 5, ESM)

```js
import { setupMiddlewarePipeline, getAuthMiddleware } from './middleware/pipeline.js';
setupMiddlewarePipeline(app, { corsOptions: standardCorsOptions });
// Protected route example:
app.use('/api/conversations', getAuthMiddleware(), conversationRouter);
```

Schema validation for bodies: `middleware/schema-validation.js` (`validateSchema`).
Prefer attaching it on write routes that accept `req.body`.

### streaming-proxy (Express 5, ESM + TypeScript)

Auth and audit live under `services/streaming-proxy/src/middleware/`. Prefer the
typed middleware entry (`index.ts`) over duplicating JWT checks in route files.

### backend/auth (quarantined)

`handlers.js` fails closed: running it exits non-zero and requiring it throws.
It does not bind a port and does not validate tokens. Do not add middleware here.
Active auth is Cloudflare Access in `services/api-backend`.

### tailscale-relay (Express 4, ESM)

Express 4 middleware signatures and error-handling differ. Do not import
api-backend pipeline helpers here without an Express 4-compatible adapter.

## Error handling

Unhandled errors should reach a final Express error middleware that responds with
JSON including `error`, `statusCode`, and `timestamp`. See
`services/api-backend/middleware/error-handler.js`.

## Checklist for new routes

1. Mount behind the shared pipeline (or document why not).
2. Attach auth + RBAC/tier checks when the route is not public.
3. Validate `req.body` with Zod / `validateSchema` for write methods.
4. Let thrown errors propagate to the shared error handler (or wrap with
   `asyncHandler`).
