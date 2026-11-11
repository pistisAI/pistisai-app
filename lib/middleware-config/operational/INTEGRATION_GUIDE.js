/**
 * @fileoverview Integration guide: How to add rate limiting to PistisAI API endpoints
 * This file shows best practices for applying per-endpoint rate limiters
 */

// ============================================================================
// EXAMPLE 1: Apply rate limiting to existing routes
// ============================================================================

import express from 'express';
import { createEndpointRateLimiter, ENDPOINT_LIMITS } from '@pistisai/middleware-config';

const router = express.Router();

// Create reusable limiters
const userLimiter = createEndpointRateLimiter('user');
const conversationLimiter = createEndpointRateLimiter('conversation');
const agentLimiter = createEndpointRateLimiter('agent');

// Apply to routes - add limiter AFTER auth, BEFORE handler
router.post(
  '/conversations',
  authenticateJWT,
  conversationLimiter, // Rate limit here
  validateSchema(createConversationSchema),
  createConversationHandler
);

router.get(
  '/conversations/:id',
  authenticateJWT,
  userLimiter, // Lighter limit for reads
  getConversationHandler
);

router.post(
  '/agents/execute',
  authenticateJWT,
  agentLimiter, // Very strict for expensive operations
  validateSchema(executeAgentSchema),
  executeAgentHandler
);

// ============================================================================
// EXAMPLE 2: Custom limits for specific routes
// ============================================================================

// Tighter limit for a specific endpoint
const uploadLimiter = createEndpointRateLimiter('upload', redisClient, {
  max: 3, // Only 3 uploads per minute
  windowMs: 60000,
});

router.post(
  '/files/upload',
  authenticateJWT,
  uploadLimiter,
  handleFileUpload
);

// ============================================================================
// EXAMPLE 3: Tiered rate limiting based on subscription
// ============================================================================

import { createTieredRateLimiter } from '@pistisai/middleware-config';

const tieredConversationLimiter = createTieredRateLimiter(
  'conversation',
  {
    free: 10,      // Free tier: 10 conversations/minute
    pro: 100,      // Pro tier: 100 conversations/minute
    enterprise: 1000, // Enterprise: unlimited (1000/min)
  },
  redisClient
);

router.post(
  '/conversations',
  authenticateJWT,
  tieredConversationLimiter, // Automatically applies tier-based limit
  validateSchema(createConversationSchema),
  createConversationHandler
);

// ============================================================================
// EXAMPLE 4: Batch apply limiters in a service initialization
// ============================================================================

export function initializeRateLimiters(redisClient) {
  return createEndpointRateLimiters(
    ['public', 'user', 'conversation', 'agent', 'upload', 'admin'],
    redisClient
  );
}

// In server.js:
const allLimiters = initializeRateLimiters(redisClient);

// Export them for use in routes
export { allLimiters };

// ============================================================================
// EXAMPLE 5: Middleware ordering (CRITICAL)
// ============================================================================

/*
CORRECT ORDER:
1. Body parser
2. Auth middleware (authenticate user)
3. Rate limiter (now we know who they are)
4. Schema validation
5. Handler

WRONG (rate limiter won't have user info):
1. Body parser
2. Rate limiter <- No user info yet!
3. Auth middleware
4. Handler

The rate limiter needs req.user to be set so it can key by user ID.
Without it, it will fall back to IP-based limiting.
*/

router.post('/endpoint',
  express.json(),            // 1. Parse body
  authenticateJWT,           // 2. Auth - sets req.user
  rateLimiter,               // 3. Rate limit - uses req.user
  validateSchema(schema),    // 4. Validate
  handler                    // 5. Handle request
);

// ============================================================================
// EXAMPLE 6: Excluding endpoints from rate limiting
// ============================================================================

/*
The endpoint rate limiter AUTOMATICALLY excludes:
- /health
- /metrics
- /.well-known/*

To exclude additional endpoints, use app-level checks before the limiter,
or modify the limiter's skip function.
*/

// ============================================================================
// EXAMPLE 7: Handling rate limit errors in UI
// ============================================================================

/*
When rate limited (429), the API responds with:

{
  "error": "Too Many Requests",
  "message": "Too many requests from this IP, please try again later.",
  "retryAfter": 60,          // Seconds to wait
  "limit": 50,               // Requests per window
  "window": 60000            // Window in milliseconds
}

Frontend should:
1. Check for 429 status code
2. Read retryAfter value
3. Show error: "Too many requests. Please try again in {retryAfter} seconds"
4. Disable the button for retryAfter seconds
5. Re-enable once timer expires
*/

// Example React hook:
function useRateLimitedRequest(asyncFn) {
  const [retryAfter, setRetryAfter] = React.useState(null);
  
  return async (...args) => {
    try {
      return await asyncFn(...args);
    } catch (error) {
      if (error.response?.status === 429) {
        const seconds = error.response.data.retryAfter;
        setRetryAfter(seconds);
        
        // Countdown timer
        for (let i = seconds; i > 0; i--) {
          await new Promise(r => setTimeout(r, 1000));
          setRetryAfter(i - 1);
        }
        setRetryAfter(null);
      }
      throw error;
    }
  };
}

// ============================================================================
// EXAMPLE 8: Monitoring rate limit metrics in Prometheus
// ============================================================================

/*
Three metrics are exported:

1. api_rate_limit_hits_total
   - Counts requests that were rate limited
   - Labels: endpoint_type, key
   - Example: api_rate_limit_hits_total{endpoint_type="user"} 5

2. api_rate_limit_exceeded_total
   - Counts requests exceeding limits
   - Labels: endpoint_type, key
   - Example: api_rate_limit_exceeded_total{endpoint_type="agent"} 2

3. api_rate_limit_remaining
   - Gauge: remaining requests in current window
   - Labels: endpoint_type, key
   - Example: api_rate_limit_remaining{endpoint_type="user"} 45

Query examples:

// Alert when agent endpoint hits limit > 5 times per minute
rate(api_rate_limit_exceeded_total{endpoint_type="agent"}[1m]) > 5

// Check if rate limiter is healthy
increase(api_rate_limit_hits_total[5m]) < 100

// Track remaining quota
api_rate_limit_remaining{endpoint_type="conversation"}
*/

// ============================================================================
// EXAMPLE 9: Configuration per environment
// ============================================================================

// config/rate-limits.js
export const rateLimitsByEnvironment = {
  development: {
    public: { max: 1000, windowMs: 60000 }, // Lenient in dev
    user: { max: 500, windowMs: 60000 },
    agent: { max: 100, windowMs: 60000 },
  },
  staging: {
    public: { max: 500, windowMs: 60000 },
    user: { max: 200, windowMs: 60000 },
    agent: { max: 50, windowMs: 60000 },
  },
  production: {
    public: { max: 100, windowMs: 60000 }, // Strict in production
    user: { max: 50, windowMs: 60000 },
    agent: { max: 10, windowMs: 60000 },
  },
};

// server.js
const envConfig = rateLimitsByEnvironment[process.env.NODE_ENV || 'development'];
const limiters = createEndpointRateLimiters(
  Object.keys(envConfig),
  redisClient,
  envConfig
);

// ============================================================================
// EXAMPLE 10: Testing rate-limited endpoints
// ============================================================================

import request from 'supertest';

describe('Rate Limiting Integration', () => {
  test('POST /conversations respects rate limit', async () => {
    const app = setupApp(limiters);
    
    // Make requests up to limit
    for (let i = 0; i < ENDPOINT_LIMITS.conversation.max; i++) {
      const res = await request(app)
        .post('/conversations')
        .set('Authorization', `Bearer ${token}`)
        .send({ title: 'Test' });
      expect(res.status).toBe(200);
    }
    
    // Next request should be rate limited
    const res = await request(app)
      .post('/conversations')
      .set('Authorization', `Bearer ${token}`)
      .send({ title: 'Test' });
    expect(res.status).toBe(429);
    expect(res.body.retryAfter).toBeDefined();
  });
});

// ============================================================================
// EXAMPLE 11: Gradual rollout using feature flags
// ============================================================================

import featureFlags from '@pistisai/feature-flags';

function createConditionalRateLimiter(endpointType, featureFlagKey) {
  const limiter = createEndpointRateLimiter(endpointType);
  
  return (req, res, next) => {
    // Only apply rate limiter if feature flag is enabled
    if (featureFlags.isEnabled(featureFlagKey, req.user?.id)) {
      return limiter(req, res, next);
    }
    next(); // Skip rate limiting
  };
}

const gradualRollout = createConditionalRateLimiter(
  'conversation',
  'enable-conversation-rate-limit'
);

router.post('/conversations', authenticateJWT, gradualRollout, handler);

// ============================================================================
// KEY TAKEAWAYS
// ============================================================================

/*
1. MIDDLEWARE ORDER: Auth → Rate Limit → Validation → Handler
   (Rate limiter needs req.user to be set)

2. REUSE LIMITERS: Create once, use many times
   const userLimiter = createEndpointRateLimiter('user');
   router.get('/users', userLimiter, handler);
   router.post('/users/action', userLimiter, handler);

3. TIERED LIMITS: Use createTieredRateLimiter for subscription tiers
   Different users can have different limits

4. CUSTOM LIMITS: Override defaults per endpoint
   createEndpointRateLimiter('user', redis, { max: 200 })

5. METRICS: Monitor api_rate_limit_* Prometheus metrics
   Alert when exceeded_total exceeds thresholds

6. TESTING: Always test that rate limits are enforced
   Verify 429 returned after N requests

7. UX: Show "retry in N seconds" message to users
   Use retryAfter value from response

8. DISTRIBUTED: Pass Redis client for multi-instance deployments
   Ensures limits apply across all servers

9. EXCLUDED: /health, /metrics, /.well-known/* are always skipped
   No need to disable rate limiting on these

10. CONFIGURATION: Store limits in config/env, not hardcoded
    Easy to adjust without code changes
*/

export {}; // Make this a module
