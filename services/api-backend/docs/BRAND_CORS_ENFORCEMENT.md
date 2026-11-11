# Brand-Aware CORS Policy Enforcement

## Overview

Issue #385: Enforce strict CORS policies per whitelabel brand to prevent unauthorized cross-origin requests and provide tenant isolation for whitelabel builds.

## Features

- **Per-Brand CORS Policies**: Each whitelabel brand can have its own set of allowed origins
- **Automatic Brand Detection**: Brand ID extracted from request headers, subdomain, or query parameters
- **Tenant Isolation**: Strict origin validation ensures requests from one brand cannot access another brand's API
- **Dynamic Configuration**: Brand policies can be loaded from environment variables or registered at runtime
- **Backward Compatibility**: Default brand policy ensures existing deployments continue to work
- **Development Mode Support**: Localhost origins automatically included in development environment
- **Flexible Origin Validation**: Supports multiple formats for specifying allowed origins

## Architecture

### Request Flow

```
Request → Brand Detection → Policy Lookup → Origin Validation → Response
   ↓           ↓                  ↓               ↓
Extract    X-Brand-ID        CORS_POLICIES    Allow/Reject
Brand ID   Subdomain         Registry          with Headers
           Query Param
           Origin Header
```

### Brand Detection Priority

The middleware uses the following priority order to detect the brand:

1. **X-Brand-ID Header**: Explicit brand specification (highest priority)
2. **Subdomain**: Extracted from `Host` header (e.g., `acme.pistisai.app` → `acme`)
3. **Origin Header**: Derived from `Origin` or `Referer` header
4. **Query Parameter**: `?brandId=acme` in the request URL
5. **Default**: Falls back to `default` brand if no identification found

Reserved subdomains are skipped: `www`, `api`, `admin`, `app`, `localhost`, `127`

## Configuration

### Environment Variables

```bash
# Define CORS policies for multiple brands as JSON
BRAND_CORS_POLICIES_JSON='
{
  "acme": {
    "origins": [
      "https://app.acme.com",
      "https://api.acme.com",
      "https://admin.acme.com"
    ],
    "credentials": true,
    "methods": ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
  },
  "widgets": {
    "origins": [
      "https://widgets-app.io",
      "https://api.widgets-io"
    ],
    "credentials": true
  }
}
'

# Additional origins to allow for the default brand
ADDITIONAL_CORS_ORIGINS="https://custom.example.com, https://another.example.com"

# Node environment (controls inclusion of localhost in default brand)
NODE_ENV=production
```

### Runtime API

Register a brand's CORS policy programmatically:

```javascript
import {
  registerBrandCORSPolicy,
  getBrandCORSPolicy,
  isOriginAllowedForBrand,
} from './middleware/brand-cors-config.js';

// Register a new brand
registerBrandCORSPolicy('acme', {
  origins: [
    'https://app.acme.com',
    'https://api.acme.com',
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
});

// Retrieve a brand's policy
const policy = getBrandCORSPolicy('acme');

// Check if an origin is allowed for a brand
const allowed = isOriginAllowedForBrand('acme', 'https://app.acme.com');
```

### Default CORS Policy

The default CORS policy includes:

- **Methods**: GET, POST, PUT, PATCH, DELETE, OPTIONS
- **Allowed Headers**: Content-Type, Authorization, X-Requested-With, Accept, Origin, Sentry-Trace, Baggage
- **Exposed Headers**: Content-Length, Content-Type, X-RateLimit-*, Baggage
- **Credentials**: true
- **Max Age**: 86400 seconds (24 hours)
- **Success Status**: 200

## Middleware Integration

### In the Pipeline

The brand-aware CORS middleware is integrated into the standard middleware pipeline:

```javascript
// services/api-backend/middleware/pipeline.js

// Initialize brand CORS policies
initializeBrandCORSPolicies();

// Add CORS decision logging (for observability)
app.use(logBrandCorsDecisions);

// Apply brand-aware CORS enforcement
app.use(dynamicBrandCorsMiddleware);
```

### Middleware Order

The brand-aware CORS middleware is placed **early in the pipeline** (step 3):

1. Sentry Request Handler (global)
2. Sentry Tracing Handler (global)
3. **Brand-Aware CORS Middleware** ← Handles preflight requests
4. Helmet Security Headers
5. Trace Context
6. Request Logging
7. ... (remaining middleware)

## Behavior

### Preflight Requests (OPTIONS)

For OPTIONS requests:

1. Extract brand from request
2. Look up brand's CORS policy
3. Validate origin against brand's allowed origins
4. If allowed: respond with CORS headers and status 200
5. If not allowed: respond with 403 Forbidden and error message

### Actual Requests (GET, POST, etc.)

For non-OPTIONS requests:

1. Extract brand from request
2. Look up brand's CORS policy
3. Validate origin against brand's allowed origins
4. If allowed: add `Access-Control-Allow-Origin` and other CORS headers
5. If not allowed: omit CORS headers (browser will block the response)

### Requests Without Origin

Requests without an `Origin` header (mobile apps, curl, server-to-server) are **always allowed** to proceed. This maintains compatibility with:

- Native mobile applications
- Desktop applications
- Server-to-server API calls
- Command-line tools (curl, wget)

## Security Features

### Tenant Isolation

Each brand's CORS policy is strictly enforced. A request from one brand's origin cannot:

- Access APIs meant for another brand
- Steal data from another brand's resources
- Escalate privileges via CORS

### Origin Validation

- Origins are compared exactly (case-sensitive, including protocol and port)
- Subdomains are isolated from each other
- Wildcard origins are not supported (explicit whitelist only)

### Logging and Monitoring

All CORS decisions are logged:

```json
{
  "level": "debug",
  "message": "CORS Decision: GET /api/users",
  "origin": "https://app.acme.com",
  "brandId": "acme",
  "allowed": true,
  "originCount": 3
}
```

Rejected CORS requests are logged at WARN level:

```json
{
  "level": "warn",
  "message": "CORS rejected for brand acme",
  "origin": "https://evil.com",
  "brandId": "acme",
  "allowedCount": 2
}
```

## Examples

### Example 1: Whitelabel with Multiple Origins

```javascript
registerBrandCORSPolicy('contoso', {
  origins: [
    'https://app.contoso.local',
    'https://api.contoso.local',
    'https://admin.contoso.local',
    'https://contoso.local',
  ],
  credentials: true,
});
```

Request from `https://app.contoso.local`:
```
✓ ALLOWED
Access-Control-Allow-Origin: https://app.contoso.local
```

Request from `https://evil.com`:
```
✗ BLOCKED (403 Forbidden for OPTIONS, omitted headers for GET/POST)
```

### Example 2: Brand Detection from Subdomain

Request to `api.acme.pistisai.app`:

```
Host: api.acme.pistisai.app
X-Brand-ID: (not set)
```

→ Brand detected as `acme`
→ Uses CORS policy for `acme` brand

### Example 3: Development Mode

When `NODE_ENV=development`, the default brand includes localhost:

```javascript
const policy = getBrandCORSPolicy('default');
// Returns:
// {
//   origins: [
//     'https://app.pistisai.app',
//     'http://localhost:3000',     // ← development
//     'http://localhost:8080',     // ← development
//     'http://127.0.0.1:3000',     // ← development
//     ...
//   ]
// }
```

## Testing

Comprehensive test suite in `test/api-backend/brand-cors-config.test.js`:

- 31 unit tests covering all aspects
- Brand extraction from various request sources
- CORS policy application and enforcement
- Origin validation and isolation
- Preflight request handling
- Policy fallback to defaults
- Environment configuration loading
- Development mode support

Run tests:

```bash
npm test -- test/api-backend/brand-cors-config.test.js
```

Expected output:
```
Test Suites: 1 passed, 1 total
Tests:       31 passed, 31 total
```

## Troubleshooting

### CORS requests blocked in production

**Problem**: Cross-origin requests are being rejected with 403 Forbidden

**Solution**: Verify the brand's CORS policy includes all required origins

```bash
# Check registered policies
curl http://localhost:3000/admin/cors-policies
```

### Brand not detected correctly

**Problem**: Wrong brand policy is being applied

**Solution**: Check brand detection priority

1. Is `X-Brand-ID` header set?
2. Is subdomain correct?
3. Is `Origin` header valid?

Add debug logging:

```bash
NODE_DEBUG=brand-cors node server.js
```

### Development environment not working

**Problem**: Localhost origins not allowed

**Solution**: Ensure `NODE_ENV=development` is set

```bash
NODE_ENV=development npm run dev
```

## Migration Guide

### From Static to Dynamic CORS

Before (static CORS config):

```javascript
import { standardCorsOptions } from './middleware/cors-config.js';

app.use(cors(standardCorsOptions));
```

After (brand-aware CORS):

```javascript
import {
  dynamicBrandCorsMiddleware,
  initializeBrandCORSPolicies,
} from './middleware/brand-cors-config.js';

initializeBrandCORSPolicies();
app.use(dynamicBrandCorsMiddleware);
```

The old `cors-config.js` is still available for backward compatibility but should be phased out.

## Future Enhancements

- Database-backed brand policies (dynamic reload without restart)
- Wildcard origin matching for subdomains (e.g., `*.acme.com`)
- Rate limiting per origin
- Request signing/verification for enhanced security
- CORS preflight caching optimization

## References

- Issue: #385
- Related: #395 (Circuit Breaker), #405 (Request Tracing), #450 (Structured Logging), #380 (Request Deduplication)
- RFC: https://fetch.spec.whatwg.org/#http-cors-protocol
