# Pistisai Tier-Based API Documentation

## Overview

The Pistisai API supports tier-aware behavior for cloud features, per-user connectors, optional hosted agent runtimes, and legacy proxy paths.

> **Status**: This document still contains older Ollama/direct-proxy endpoint examples. Current product direction is agent-runtime-first and Tailscale-first. New tier policy should apply to selected agent runtimes, optional cloud connectors, optional support model providers, and optional hosted agent runtime containers. Do not design new primary app flows around direct Ollama proxy endpoints.

## Route availability (verified against code)

The endpoints below are **not all enabled by default**. Verified in `services/api-backend/server.js:184-197` (flag definitions) and the guarded registrations at `server.js:254, 274-278, 323-325, 334-337, 352-358, 367-369, 378-387, 486-497`:

| Path group | Default | Flag required to register |
|---|---|---|
| `GET /api/user/tier` | enabled | none — registered unconditionally at `server.js:389-395` |
| `/api/direct-proxy/*`, `/api/failover`, `/api/proxy-*` | **disabled** | `PISTISAI_ENABLE_LEGACY_DIRECT_PROXY_ROUTES=true` (or `PISTISAI_ENABLE_LEGACY_PROXY_ROUTES=true`) |
| `/api/tunnel*`, `/api/tunnels/*`, `/api/infrastructure/tunnel` | **disabled** | `PISTISAI_ENABLE_LEGACY_TUNNEL_ROUTES=true` (or `PISTISAI_ENABLE_LEGACY_PROXY_ROUTES=true`) |
| `/api/proxy/start`, `/stop`, `/status`, `/api/streaming-proxy/provision` | **disabled** | `PISTISAI_ENABLE_LEGACY_STREAMING_PROXY_ROUTES=true` (or `PISTISAI_ENABLE_LEGACY_PROXY_ROUTES=true`) |
| `/api/ollama*` | **disabled** | `PISTISAI_ENABLE_LEGACY_OLLAMA_PROXY=true` (or `PISTISAI_ENABLE_LEGACY_PROXY_ROUTES=true`) |

Everything described as "Direct Proxy", "Container Proxy" or "Tunnel" below applies **only when the matching flag is set**; with the defaults these paths are not mounted and return 404.

## User Tiers

### Account tier

- **Local/user-owned agent runtime access** without hosted runtime compute
- **No Docker required** on user's machine
- **Single local or private-network agent runtime path**
- **Basic features** with upgrade prompts for advanced functionality

### Account tier

- **Optional hosted agent runtime or cloud connector orchestration** with isolated environments
- **Team features** and collaboration tools
- **API access** for custom integrations
- **Multiple connections** and advanced networking
- **Priority support**

### Account tier

- **Unlimited resources** and connections
- **Custom configurations** and on-premise deployment
- **Advanced security** and compliance features
- **Dedicated support** and SLA guarantees

## Authentication & Tier Detection

All API endpoints require authentication via Auth0 JWT tokens. User tier information is extracted from the token's metadata:

Verified against `services/api-backend/middleware/tier-check.js:90-127` — both the plain (`user_metadata`, `app_metadata`) and namespaced (`https://Pistisai.com/user_metadata`, `https://Pistisai.com/app_metadata`) claim shapes are read. The actual lookup order is:

```javascript
// Tier information locations (in priority order)
userMetadata.tier
appMetadata.tier
userMetadata.subscription
userMetadata.plan
appMetadata.subscription
appMetadata.plan
```

An unrecognised or missing value falls back to `free` (`tier-check.js:129-160`).

## API Endpoints

### Tier Information

#### GET `/api/user/tier`

Get current user's tier information and available features.

**Response** (verified against `services/api-backend/routes/user-tier.js:10-17` and the feature map at `services/api-backend/middleware/tier-check.js:27-59`):

```json
{
  "tier": "free",
  "features": {
    "containerOrchestration": false,
    "teamFeatures": false,
    "apiAccess": false,
    "prioritySupport": false,
    "advancedNetworking": false,
    "multipleInstances": false,
    "maxConnections": 1,
    "maxModels": 5,
    "directTunnelOnly": true
  },
  "upgradeUrl": "https://app.pistisai.app/upgrade",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

`upgradeUrl` comes from `UPGRADE_URL` or defaults to `https://app.pistisai.app/upgrade`. The four booleans shown in older examples were an incomplete subset of the features object.

### Direct Proxy (Legacy / Fallback)

> **Only mounted when** `PISTISAI_ENABLE_LEGACY_DIRECT_PROXY_ROUTES=true` (or the umbrella `PISTISAI_ENABLE_LEGACY_PROXY_ROUTES=true`). See `services/api-backend/server.js:334-337`.

#### GET `/api/direct-proxy/:userId/health`

Health check for the historical direct proxy service.

**Headers:**

- `Authorization: Bearer <jwt_token>`

**Response:**

```json
{
  "status": "ok",
  "service": "direct-proxy",
  "userTier": "free",
  "directTunnelEnabled": true,
  "tunnelConnected": true,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

#### ALL `/api/direct-proxy/:userId/ollama/*`

Historical direct proxy to a local Ollama support-provider path for account tier users. New agent-runtime designs should expose the selected agent runtime path instead of assuming Ollama.

**Security:**

- Only accessible by account tier users
- User can only access their own proxy (`:userId` must match authenticated user)
- Request/response headers are sanitized
- Path traversal protection enabled
- Request size limits enforced

**Example:**

```bash
# Get available models
GET /api/direct-proxy/auth0|user123/ollama/api/tags

# Generate completion
POST /api/direct-proxy/auth0|user123/ollama/api/generate
Content-Type: application/json

{
  "model": "llama2",
  "prompt": "Hello, world!",
  "stream": false
}
```

**Error Responses:**

```json
// Desktop client not connected
{
  "error": "Desktop client not connected",
  "code": "DESKTOP_CLIENT_DISCONNECTED",
  "message": "Please ensure your Pistisai desktop client is running and connected.",
  "requestId": "dp-1642234567890-abc123"
}

// Request timeout
{
  "error": "Request timeout",
  "code": "REQUEST_TIMEOUT",
  "message": "The request to your legacy Ollama support-provider path timed out.",
  "timeout": 30000,
  "requestId": "dp-1642234567890-abc123"
}

// Access denied for another account tier
{
  "error": "Direct proxy access is only available for account tier users",
  "code": "DIRECT_PROXY_FORBIDDEN",
  "userTier": "premium",
  "suggestion": "Use container-based proxy for premium features",
  "requestId": "dp-1642234567890-abc123"
}
```

### Container Proxy (Legacy / Fallback)

> **Only mounted when** `PISTISAI_ENABLE_LEGACY_STREAMING_PROXY_ROUTES=true` (or the umbrella `PISTISAI_ENABLE_LEGACY_PROXY_ROUTES=true`) for `/proxy/start`, and `PISTISAI_ENABLE_LEGACY_TUNNEL_ROUTES=true` for `/tunnel/*`. See `services/api-backend/server.js:274-278, 486-497`.

#### POST `/api/proxy/start`

Start the historical container-based proxy for premium/enterprise users.

**Request:**

```json
{
  "testMode": false
}
```

**Response:**

```json
{
  "success": true,
  "message": "Streaming proxy started successfully",
  "proxy": {
    "proxyId": "proxy-auth0|user123-1642234567890",
    "status": "running",
    "createdAt": "2024-01-15T10:30:00.000Z",
    "directTunnel": false,
    "endpoint": "https://api.example.com/proxy/auth0|user123",
    "userTier": "premium"
  }
}
```

#### ALL `/api/tunnel/:userId/*`

Container-based proxy with advanced features (premium/enterprise only).

**Features:**

- Isolated container environments
- Advanced networking and security
- Team collaboration capabilities
- Custom configurations

## Error Handling

### Standard Error Response Format

```json
{
  "error": "Error description",
  "code": "ERROR_CODE",
  "message": "User-friendly message",
  "userTier": "free",
  "upgradeUrl": "https://app.example.com/upgrade",
  "requestId": "unique-request-id"
}
```

### Common Error Codes

| Code | Description | HTTP Status |
|------|-------------|-------------|
| `AUTH_REQUIRED` | Authentication required | 401 |
| `TIER_INSUFFICIENT` | Insufficient subscription tier | 403 |
| `FEATURE_UNAVAILABLE` | Feature not available in current tier | 403 |
| `DIRECT_PROXY_FORBIDDEN` | Direct proxy access denied | 403 |
| `DESKTOP_CLIENT_DISCONNECTED` | Desktop client not connected | 503 |
| `REQUEST_TIMEOUT` | Request timed out | 504 |
| `REQUEST_TOO_LARGE` | Request entity too large | 413 |
| `INVALID_PATH` | Invalid or malicious path | 400 |
| `PROXY_ERROR` | Internal proxy error | 500 |

## Rate Limiting

> **Verified against code:** the per-tier figures listed below are not enforced by a tier-specific limiter in `services/api-backend`. The generic API limiter is configured in `services/api-backend/middleware/pipeline.js:111-126` (15-minute window, `max` 100 per IP by default, `bridgeMax` 500), and the legacy admin limiters live in `middleware/admin-rate-limiter.js`. Treat the tier numbers here as planned targets, not current behaviour.

### Account tier

- **Legacy direct proxy**: 100 requests per minute when enabled
- **API calls**: 50 requests per minute
- **Concurrent connections**: 1

### Account tier

- **Legacy container proxy**: 500 requests per minute when enabled
- **API calls**: 200 requests per minute
- **Concurrent connections**: 10

### Account tier

- **No rate limits** (within reasonable usage)
- **Custom limits** available upon request

## Security Considerations

### Request Sanitization

- Hop-by-hop headers removed from forwarded requests
- Security-sensitive headers (Authorization, Cookie) stripped
- Response headers sanitized before returning to client
- Path traversal protection on all proxy endpoints

### User Isolation

- Users can only access their own proxy endpoints
- Tier validation performed on every request
- Audit logging for all tier-related access attempts
- Request tracing with unique request IDs

### Data Protection

- No sensitive user data logged in error messages
- Request/response bodies not logged by default
- Secure token handling and validation
- HTTPS required for all API communications

## Usage Examples

### Legacy Account tier Proxy Flow

```javascript
// 1. Check tier and features
const tierInfo = await fetch('/api/user/tier', {
  headers: { 'Authorization': `Bearer ${token}` }
}).then(r => r.json());

if (tierInfo.tier === 'free') {
  // 2. Use legacy direct proxy for Ollama support-model access
  const models = await fetch(`/api/direct-proxy/${userId}/ollama/api/tags`, {
    headers: { 'Authorization': `Bearer ${token}` }
  }).then(r => r.json());
  
  // 3. Generate completion
  const completion = await fetch(`/api/direct-proxy/${userId}/ollama/api/generate`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: 'llama2',
      prompt: 'Hello!',
      stream: false
    })
  }).then(r => r.json());
}
```

### Legacy Premium Proxy Flow

```javascript
// 1. Start container-based proxy
const proxy = await fetch('/api/proxy/start', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ testMode: false })
}).then(r => r.json());

// 2. Use container proxy with advanced features
const response = await fetch(`/api/tunnel/${userId}/ollama/api/generate`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    model: 'llama2',
    prompt: 'Hello!',
    stream: true
  })
});
```

## Migration Guide

### Existing Users

- **Premium/Enterprise users**: Preserve existing proxy behavior where still enabled, but prefer cloud connector or hosted agent runtime design for new work.
- **Account tier users**: Should use local/user-owned agent runtimes by default.
- **Setup process**: Must verify an agent runtime first, then configure optional support model providers or cloud features.

### API Clients

- **Existing endpoints**: Continue to work with tier validation where the legacy proxy path is still enabled.
- **New endpoints**: Prefer selected agent runtime, Tailscale cloud connector, and hosted agent runtime APIs.
- **Error handling**: Update to handle new tier-related error codes

## Support & Troubleshooting

### Common Issues

1. **"Direct proxy access denied"**
   - Verify user is on account tier
   - Check Auth0 metadata configuration
   - Ensure proper authentication

2. **"Desktop client not connected"**
   - Verify desktop client is running
   - Check WebSocket connection status
   - Review firewall and network settings

3. **"Request timeout"**
   - Check selected agent runtime status, or the support model provider if using a legacy direct-proxy path
   - Verify network connectivity
   - Review timeout configuration

### Debug Information

- All responses include `requestId` for tracing
- Health check endpoints provide connection status
- Tier information available in user profile
- Audit logs capture all tier-related events
