# Endpoint Rate Limiter

Comprehensive per-endpoint rate limiting middleware for PistisAI API.

## Features

- **Per-endpoint configuration** — Apply different rate limits to different endpoint types
- **Tiered limiting** — Apply different limits based on user tier (free, pro, enterprise)
- **Prometheus metrics** — Track rate limit hits, exceeded requests, and remaining quota
- **Redis support** — Distributed rate limiting for multi-instance deployments
- **Automatic key generation** — Use authenticated user ID or IP address
- **Graceful degradation** — Skip limiting for health checks and monitoring

## Endpoint Types

Seven pre-configured endpoint types with sensible defaults:

| Type | Window | Limit | Use Case |
|------|--------|-------|----------|
| `public` | 1 min | 100 | Public, cacheable endpoints |
| `user` | 1 min | 50 | Authenticated user endpoints |
| `conversation` | 1 min | 30 | Conversation creation/management |
| `agent` | 1 min | 10 | Agent/skill execution (expensive) |
| `upload` | 1 min | 5 | File uploads (resource-intensive) |
| `admin` | 1 min | 20 | Admin operations |
| `webhook` | 1 min | 100 | Incoming webhook handlers |

## Usage

### Basic Usage

Apply rate limiting to individual routes:

```javascript
import express from 'express';
import {
  createEndpointRateLimiter,
  ENDPOINT_LIMITS,
} from '@pistisai/middleware-config';

const app = express();
const userLimiter = createEndpointRateLimiter('user');
const agentLimiter = createEndpointRateLimiter('agent');

// Public conversation endpoint: 50 requests/minute
app.post('/api/conversations', userLimiter, (req, res) => {
  // Handle conversation creation
  res.json({ id: 'conv-123' });
});

// Expensive agent execution: 10 requests/minute
app.post('/api/agents/execute', agentLimiter, (req, res) => {
  // Handle agent execution
  res.json({ result: '...' });
});
```

### Batch Create Limiters

Create multiple limiters at once:

```javascript
import { createEndpointRateLimiters } from '@pistisai/middleware-config';

const limiters = createEndpointRateLimiters(
  ['user', 'conversation', 'agent'],
  redisClient // Optional Redis client
);

app.post('/conversations', limiters.conversation, handler);
app.post('/agents/run', limiters.agent, handler);
```

### Custom Limits

Override default limits:

```javascript
const customLimiter = createEndpointRateLimiter('user', redisClient, {
  max: 200, // Increase from default 50 to 200
  windowMs: 60000, // Override window
});

app.get('/api/search', customLimiter, handler);
```

### Tiered Rate Limiting

Apply different limits based on user tier:

```javascript
import { createTieredRateLimiter } from '@pistisai/middleware-config';

const tierLimiter = createTieredRateLimiter('conversation', {
  free: 10,    // Free tier: 10 requests/minute
  pro: 100,    // Pro tier: 100 requests/minute
  enterprise: 1000, // Enterprise: 1000 requests/minute
}, redisClient);

app.post('/api/conversations', tierLimiter, handler);
```

The middleware automatically selects the appropriate limit based on `req.user.tier`.

## Key Generation

Rate limit keys are generated automatically:

1. **Authenticated users**: `user:<userId>` — Uses `req.user.id`
2. **Unauthenticated**: `<ip-address>` — Uses IP address from request

This ensures rate limits apply per-user (not per-IP) for authenticated requests.

## Excluded Endpoints

Rate limiting is automatically skipped for:

- `/health` — Health check endpoint
- `/metrics` — Prometheus metrics endpoint
- `/.well-known/*` — Well-known configuration endpoints

## Response Format

When a rate limit is exceeded, the API returns:

```json
HTTP/1.1 429 Too Many Requests

{
  "error": "Too Many Requests",
  "message": "Too many requests from this IP, please try again later.",
  "retryAfter": 60,
  "limit": 50,
  "window": 60000
}
```

Additionally, standard rate limit headers are included:

```
RateLimit-Limit: 50
RateLimit-Remaining: 0
RateLimit-Reset: 1699747200
```

## Metrics

Rate limiting exports Prometheus metrics:

```
# HELP api_rate_limit_hits_total Total number of requests that hit rate limits
# TYPE api_rate_limit_hits_total counter
api_rate_limit_hits_total{endpoint_type="user",key="user_ep"} 5

# HELP api_rate_limit_exceeded_total Total number of requests exceeding rate limits
# TYPE api_rate_limit_exceeded_total counter
api_rate_limit_exceeded_total{endpoint_type="agent",key="agent_ep"} 2

# HELP api_rate_limit_remaining Remaining requests in current rate limit window
# TYPE api_rate_limit_remaining gauge
api_rate_limit_remaining{endpoint_type="user",key="user_ep"} 45
```

## Distributed Rate Limiting

For multi-instance deployments, pass a Redis client:

```javascript
import redis from 'redis';

const redisClient = redis.createClient();
const limiter = createEndpointRateLimiter('user', redisClient);

app.post('/api/users/action', limiter, handler);
```

This ensures rate limits are enforced across all instances using shared Redis state.

## Integration with Middleware Pipeline

If using the consolidated middleware pipeline:

```javascript
import {
  setupMiddlewarePipeline,
  createEndpointRateLimiters,
} from '@pistisai/middleware-config';

const pipeline = setupMiddlewarePipeline(app, {
  environment: 'production',
  enableMetrics: true,
});

// Add rate limiters after pipeline setup
const limiters = createEndpointRateLimiters(
  ['public', 'user', 'agent'],
  redisClient
);
```

## Configuration File Example

Store configurations in environment or config files:

```javascript
// config/rate-limits.js
export const rateLimitConfig = {
  byEndpoint: {
    'POST /api/conversations': { type: 'conversation' },
    'POST /api/agents/execute': { type: 'agent', max: 5 },
    'GET /api/users/*': { type: 'user' },
    'POST /api/files/upload': { type: 'upload', max: 3 },
  },
  tiers: {
    free: 0.5, // Free tier gets 50% of normal limits
    pro: 1.0,  // Pro gets normal limits
    enterprise: 5.0, // Enterprise gets 5x limits
  },
};
```

## Testing

Tests verify:

- ✅ Per-endpoint configuration applies correctly
- ✅ Rate limits are enforced (429 after N requests)
- ✅ Different endpoint types have different limits
- ✅ Tiered limits based on user tier
- ✅ Excluded endpoints (health, metrics) bypass limiting
- ✅ Rate limit headers present in response
- ✅ Window reset after expiry
- ✅ Metrics recorded accurately

Run tests:

```bash
npm test -- test/api-backend/endpoint-rate-limiter.test.js
```

## Troubleshooting

### All requests return 429

**Cause**: Limiter is too strict or not resetting.

**Solution**: Check `windowMs` and `max` values, verify Redis connection if using distributed limiting.

### Rate limits not enforced between instances

**Cause**: Redis client not connected.

**Solution**: Pass `redisClient` to `createEndpointRateLimiter()`.

### Headers missing from response

**Cause**: Using legacy configuration.

**Solution**: Ensure `standardHeaders: true` in limiter config (default in this implementation).

## See Also

- [Admin Rate Limiter](./admin-rate-limiter.js) — Specialized limiter for admin endpoints
- [Webhook Rate Limiter](./webhook-rate-limiter.js) — Specialized limiter for webhooks
- [Prometheus Metrics](../../monitoring/prometheus-client.js) — Metrics export details
