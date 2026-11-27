# Pistisai API Documentation Guide

## Overview

The Pistisai API Backend provides comprehensive REST API endpoints for managing tunnels, users, authentication, and system operations. This guide explains how to access and use the API documentation.

## Accessing API Documentation

### Source documents (available)

The authoritative API docs in this repo are the Markdown files under [`docs/api/`](../README.md) and [`docs/development/API_DOCUMENTATION.md`](../../development/API_DOCUMENTATION.md), plus the code itself in `services/api-backend/routes/`.

### Swagger UI (not available)

> **Verified:** `services/api-backend/server.js` has no `/api/docs` or Swagger route, and neither `services/api-backend/package.json` nor the root `package.json` declares a Swagger/OpenAPI dependency. The URLs below do not resolve; use the source documents above instead.

Previously documented (but unmounted) URLs:

- ~~`https://api.example.com/api/docs`~~
- ~~`http://localhost:8080/api/docs`~~

The raw `swagger.json` URLs were likewise unmounted. There is no generated OpenAPI specification in the repository at present.

## API Endpoints

> The "documented under the … tag" references below come from the planned Swagger documentation. There is no running Swagger UI, so `services/api-backend/routes/` is the source of truth for live paths.

### Authentication Endpoints

Authentication endpoints are listed below (the planned Swagger tag is "Authentication").

#### Token Management

- `POST /auth/token/refresh` - Refresh an expired JWT token
- `POST /auth/token/validate` - Validate a JWT token
- `POST /auth/token/check-expiry` - Check if token needs refresh
- `POST /auth/logout` - Logout and revoke token
- `POST /auth/session/revoke` - Revoke a specific session
- `GET /auth/me` - Get current user information

### User Endpoints

User management endpoints are documented under the "Users" tag.

#### User Profile

- `GET /users/tier` - Get current user's tier information
- `GET /users/:id` - Get user profile
- `PUT /users/:id` - Update user profile
- `DELETE /users/:id` - Delete user account

#### User Activity

- `GET /users/:id/activity` - Get user activity logs
- `GET /users/:id/usage` - Get user usage metrics

### Tunnel Endpoints (legacy-gated)

> **Verified:** the `/tunnels` route group is registered only when `PISTISAI_ENABLE_LEGACY_TUNNEL_ROUTES=true` or `PISTISAI_ENABLE_LEGACY_PROXY_ROUTES=true` (`services/api-backend/server.js:186-188, 323-325`). With default settings these endpoints are not mounted and return 404.

Tunnel management endpoints are documented under the "Tunnels" tag. Available methods in `services/api-backend/routes/tunnels.js` include `POST /tunnels`, `GET /tunnels`, `GET /tunnels/:id`, `PUT /tunnels/:id`, `DELETE /tunnels/:id`, `GET /tunnels/:id/metrics`, `GET /tunnels/:id/activity`, `GET /tunnels/:id/config` and the start/stop endpoints.

#### Tunnel Lifecycle

- `POST /tunnels` - Create a new tunnel
- `GET /tunnels` - List user's tunnels
- `GET /tunnels/:id` - Get tunnel details
- `PUT /tunnels/:id` - Update tunnel configuration
- `DELETE /tunnels/:id` - Delete tunnel
- `POST /tunnels/:id/start` - Start tunnel
- `POST /tunnels/:id/stop` - Stop tunnel

#### Tunnel Status and Metrics

- `GET /tunnels/:id/status` - Get tunnel status
- `GET /tunnels/:id/health` - Get tunnel health
- `GET /tunnels/:id/metrics` - Get tunnel metrics
- `GET /tunnels/:id/endpoints` - Get tunnel endpoints

### Webhook Endpoints

Webhook management endpoints are documented under the "Webhooks" tag.

#### Webhook Management

- `POST /webhooks` - Register a webhook
- `GET /webhooks` - List webhooks
- `GET /webhooks/:id` - Get webhook details
- `PUT /webhooks/:id` - Update webhook
- `DELETE /webhooks/:id` - Delete webhook

#### Webhook Events

- `GET /webhooks/:id/events` - Get webhook events
- `POST /webhooks/:id/test` - Send test webhook
- `POST /webhooks/:id/replay` - Replay webhook events

### Admin Endpoints

Administrative endpoints are documented under the "Admin" tag.

#### System Management

- `GET /admin/system/stats` - Get system statistics
- `GET /admin/system/health` - Get system health
- `POST /admin/system/config` - Update system configuration

#### User Management

- `GET /admin/users` - List all users
- `GET /admin/users/:id` - Get user details
- `PUT /admin/users/:id` - Update user
- `DELETE /admin/users/:id` - Delete user

#### Audit and Logging

- `GET /admin/audit` - Get audit logs
- `GET /admin/audit/:id` - Get audit log details

### Monitoring Endpoints

Monitoring endpoints are documented under the "Monitoring" tag.

#### Metrics

- `GET /metrics` - Prometheus metrics endpoint
- `GET /metrics/health` - Metrics collection health

#### Health Checks

- `GET /health` - API health check
- `GET /db/pool/health` - Database pool health
- `GET /db/pool/metrics` - Database pool metrics

## Authentication

### JWT Token Authentication

All protected endpoints require a valid JWT token in the Authorization header:

```
Authorization: Bearer <JWT_TOKEN>
```

### Token Refresh

Tokens expire after a set period. Refresh tokens using:

```bash
curl -X POST https://api.example.com/auth/token/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken": "your_refresh_token"}'
```

### API Key Authentication

Service-to-service communication uses API keys:

```
X-API-Key: <API_KEY>
```

## Request/Response Examples

### Example: Create a Tunnel

**Request:**

```bash
curl -X POST https://api.example.com/tunnels \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Tunnel",
    "config": {
      "maxConnections": 100,
      "timeout": 30000,
      "compression": true
    },
    "endpoints": [
      {
        "url": "http://localhost:8000",
        "priority": 1,
        "weight": 1
      }
    ]
  }'
```

**Response:**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "auth0|123456",
  "name": "My Tunnel",
  "status": "created",
  "endpoints": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "url": "http://localhost:8000",
      "priority": 1,
      "weight": 1,
      "healthStatus": "unknown"
    }
  ],
  "config": {
    "maxConnections": 100,
    "timeout": 30000,
    "compression": true
  },
  "metrics": {
    "requestCount": 0,
    "successCount": 0,
    "errorCount": 0,
    "averageLatency": 0
  },
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

### Example: Get User Tier Information

**Request:**

```bash
curl -X GET https://api.example.com/users/tier \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

**Response** (verified against `services/api-backend/routes/users.js:42-123` — note the `success`/`data` wrapper):

```json
{
  "success": true,
  "data": {
    "currentTier": "premium",
    "features": [
      { "name": "containerOrchestration", "enabled": true, "description": "Container orchestration and management", "value": true }
    ],
    "limits": { "maxConnections": 10, "maxModels": 50 },
    "capabilities": {
      "containerOrchestration": true,
      "teamFeatures": true,
      "apiAccess": true,
      "prioritySupport": true,
      "advancedNetworking": true,
      "multipleInstances": true
    },
    "upgrade": {
      "availableTier": "enterprise",
      "message": "...",
      "benefits": {}
    },
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

The `features` array above is abridged; the handler emits one entry per tier feature. Note that `GET /user/tier` is a **different** endpoint (`services/api-backend/server.js:389-395`, handler `routes/user-tier.js:10-17`) that returns `{ tier, features (object), upgradeUrl, timestamp }` without the `success`/`data` wrapper.

## Error Handling

All errors follow a standard format with error codes and HTTP status codes.

### Error Response Format

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "category": "error_category",
    "statusCode": 400,
    "correlationId": "req-12345-abcde",
    "suggestion": "Suggested action to resolve the error"
  }
}
```

### Common Error Codes

- `INVALID_TOKEN` (401) - Invalid or expired JWT token
- `MISSING_PARAMETER` (400) - Required parameter missing
- `RATE_LIMIT_EXCEEDED` (429) - Rate limit exceeded
- `NOT_FOUND` (404) - Resource not found
- `INTERNAL_ERROR` (500) - Server error

See [API_ERROR_CODES.md](API_ERROR_CODES.md) for complete error code reference.

## Rate Limiting

The API implements rate limiting to prevent abuse:

- **Default**: 100 requests per minute per user
- **Premium**: 500 requests per minute per user
- **Enterprise**: 2000 requests per minute per user

Rate limit information is included in response headers:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640000000
```

## Pagination

List endpoints support pagination with query parameters:

```
GET /admin/users?page=1&limit=20&sort=createdAt&order=desc
```

### Pagination Parameters

- `page` - Page number (default: 1)
- `limit` - Items per page (default: 20, max: 100)
- `sort` - Sort field (default: createdAt)
- `order` - Sort order: asc or desc (default: desc)

## Filtering

List endpoints support filtering with query parameters:

```
GET /tunnels?status=connected&userId=auth0|123456
```

## Sorting

List endpoints support sorting:

```
GET /tunnels?sort=createdAt&order=desc
```

## Webhooks

### Webhook Events

Webhooks are sent for important events:

- `tunnel.created` - Tunnel created
- `tunnel.started` - Tunnel started
- `tunnel.stopped` - Tunnel stopped
- `tunnel.deleted` - Tunnel deleted
- `user.created` - User created
- `user.updated` - User updated
- `user.deleted` - User deleted

### Webhook Payload

```json
{
  "id": "evt_123456",
  "type": "tunnel.created",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "tunnel": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "My Tunnel",
      "status": "created"
    }
  }
}
```

### Webhook Signature Verification

Webhooks include a signature header for verification:

```
X-Webhook-Signature: sha256=abcdef123456...
```

## SDKs and Client Libraries

Official SDKs are available for:

- **JavaScript/TypeScript**: `@Pistisai/sdk`
- **Python**: `Pistisai-api`
- **Go**: `github.com/pistisAI/pistisai-app`

## API Versioning

> **Verified:** `services/api-backend/middleware/api-versioning.js` is in the pipeline (`services/api-backend/middleware/pipeline.js:102-106`) and tags requests with `req.apiVersion` from a `/vN/` path prefix, defaulting to `v2`. No `/v1/` or `/v2/` route mounts exist. See [API_VERSIONING_GUIDE.md](API_VERSIONING_GUIDE.md).

- Current (default tag): `v2` on unversioned paths
- Legacy tag: `v1` (deprecated; no mounted handlers)
- Version metadata endpoint: `GET /api/versions` (also `/versions` on the api subdomain)

## Best Practices

1. **Always use HTTPS** in production
2. **Store tokens securely** (never in localStorage)
3. **Implement exponential backoff** for retries
4. **Monitor rate limits** and adjust request rate
5. **Use correlation IDs** for debugging
6. **Validate webhook signatures** before processing
7. **Implement proper error handling** for all requests
8. **Keep tokens fresh** by refreshing before expiry

## Support

For API support:

- **Documentation**: https://docs.example.com
- **Issues**: https://github.com/pistisAI/pistisai-app/issues
- **Email**: ops@example.com
- **Discord**: https://discord.gg/Pistisai

## Changelog

See CHANGELOG.md for API changes and updates.

## License

The Pistisai API is licensed under the MIT License.
