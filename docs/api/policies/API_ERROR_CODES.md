# Pistisai API Error Codes and HTTP Status Codes

> **Audit decision (#816, part of #812 — docs audit; recorded 2026-11-24):** keep this page but **narrow the catalog to codes verified against source**, rather than regenerating a "complete" list. Of the 39 named codes previously documented, 16 were found as emitted `code` values in `services/**`, `backend/**` and `lib/**` and are retained below with a source citation; 23 had no source match and were removed. Source emits roughly 305 distinct `code` literals across individual handlers (for example `ADMIN_RATE_LIMIT_EXCEEDED`, `PROXY_001`, `TEMPLATE_SAVE_FAILED`), so a hand-maintained catalog cannot be exhaustive — treat source as authoritative for endpoint-specific codes.

This page lists the codes used by the API backend's shared authentication, authorization, validation, rate-limit and common route handlers. Each row cites where the code is emitted.

## HTTP status codes

Statuses actually set by handlers:

| Code | Name | When used |
|------|------|-----------|
| 200 | OK | Request succeeded |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid token payload, invalid email, failed schema validation |
| 401 | Unauthorized | Missing/invalid/expired bearer token, authentication required |
| 403 | Forbidden | Insufficient permissions; HTTPS required on auth endpoints |
| 404 | Not Found | Missing resource, user, tunnel, session or webhook |
| 429 | Too Many Requests | Rate limit exceeded (e.g. bridge polling, Stripe rate-limit mapping) |
| 500 | Internal Server Error | Unexpected server error |
| 503 | Service Unavailable | Dependencies or local services unavailable |

## Verified error codes

### Authentication

| Code | Status | Meaning | Source |
|------|--------|---------|--------|
| MISSING_TOKEN | 400 | No bearer token supplied to the token-expiry check | `services/api-backend/routes/auth.js` |
| INVALID_TOKEN | 401 | Token could not be decoded / is invalid | `services/api-backend/routes/auth.js`, `middleware/admin-auth.js` |
| TOKEN_EXPIRED | 401 | JWT `exp` is in the past | `services/api-backend/middleware/auth.js` |
| AUTH_REQUIRED | 401 | Endpoint requires authentication | `services/api-backend/middleware/composite-auth.js`, `rbac.js`, `tier-check.js` |
| HTTPS_REQUIRED | 403 | Auth endpoint requires HTTPS | `services/api-backend/routes/auth.js` |

### Authorization

| Code | Status | Meaning | Source |
|------|--------|---------|--------|
| INSUFFICIENT_PERMISSIONS | 403 | Authenticated user lacks the required permission | `services/api-backend/middleware/admin-auth.js`, `rbac.js` |

### Validation

| Code | Status | Meaning | Source |
|------|--------|---------|--------|
| VALIDATION_ERROR | 400 | Shared schema/input validation failed | `services/api-backend/middleware/schema-validation.js`, `utils/input-validation.js` |
| INVALID_EMAIL | 400 | Invalid email address | `services/api-backend/routes/admin/email.js` |

### Not found

| Code | Status | Meaning | Source |
|------|--------|---------|--------|
| NOT_FOUND | 404 | Generic resource not found | `services/api-backend/routes/api-keys.js`, `proxy-config.js`, `proxy-health.js` |
| USER_NOT_FOUND | 404 (403 in admin auth) | User does not exist | `services/api-backend/routes/admin/users.js`, `middleware/admin-auth.js` |
| TUNNEL_NOT_FOUND | 404 | Tunnel does not exist | `services/api-backend/routes/tunnel-health.js`, `tunnels.js` |
| SESSION_NOT_FOUND | 404 | Session does not exist | `services/api-backend/routes/auth.js` |
| WEBHOOK_NOT_FOUND | 404 | Webhook does not exist | `services/api-backend/routes/proxy-webhooks.js`, `tunnel-webhooks.js` |

### Rate limiting

| Code | Status | Meaning | Source |
|------|--------|---------|--------|
| RATE_LIMIT_EXCEEDED | 429 | Bridge polling limit exceeded / Stripe rate-limit mapped to 429 | `services/api-backend/routes/bridge-polling-routes.js`, `services/stripe-client.js` |

Other rate-limit handlers emit their own codes, for example `ADMIN_RATE_LIMIT_EXCEEDED`, `API_KEY_RATE_LIMIT_EXCEEDED` and `WEBHOOK_RATE_LIMIT_EXCEEDED`; see the corresponding middleware for details.

### Server errors

| Code | Status | Meaning | Source |
|------|--------|---------|--------|
| INTERNAL_ERROR | 500 | Unexpected server error | `services/api-backend/routes/proxy-webhooks.js`, `sandbox.js`, `tunnel-health.js` |
| SERVICE_UNAVAILABLE | 503 | Dependency or service unavailable | `services/api-backend/routes/cloud-connector.js`, `proxy-config.js`, `proxy-diagnostics.js` |

## Error response format

Handlers do not use a single enforced envelope. The common shape is a flat object with a human-readable `error` and a machine-readable `code`:

```json
{
  "error": "Token required",
  "code": "MISSING_TOKEN"
}
```

Some handlers add extra fields — for example `services/api-backend/services/stripe-client.js` returns `code`, `message`, `details` and `statusCode`. Clients must not assume any field other than `error`/`code` is always present.

### Error response fields

| Field | When present |
|-------|--------------|
| error | Common: human-readable description |
| code | Common: machine-readable code from the tables above |
| message, statusCode, details | Handler-specific (e.g. Stripe error mapping) |

## Error categories

- **Validation** — failed schema/input validation (`VALIDATION_ERROR`, `INVALID_EMAIL`)
- **Authentication** — missing, invalid or expired tokens (`MISSING_TOKEN`, `INVALID_TOKEN`, `TOKEN_EXPIRED`, `AUTH_REQUIRED`)
- **Authorization** — insufficient permissions (`INSUFFICIENT_PERMISSIONS`)
- **Not found** — missing resources (`NOT_FOUND`, `USER_NOT_FOUND`, `TUNNEL_NOT_FOUND`, `SESSION_NOT_FOUND`, `WEBHOOK_NOT_FOUND`)
- **Rate limiting** — too many requests (`RATE_LIMIT_EXCEEDED`)
- **Server/unavailable** — unexpected errors (`INTERNAL_ERROR`, `SERVICE_UNAVAILABLE`)

## Rate limit headers

Rate-limit handlers set these headers; `services/api-backend/middleware/webhook-rate-limiter.js` uses minute/hour-suffixed variants.

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640000000
```

| Header | Description |
|--------|-------------|
| X-RateLimit-Limit | Maximum requests per window |
| X-RateLimit-Remaining | Remaining requests in current window |
| X-RateLimit-Reset | Unix timestamp when the window resets |

Sources: `services/api-backend/middleware/api-key-auth.js`, `cors-config.js`, `webhook-rate-limiter.js`.

## Retry strategy (client guidance)

Retryable with backoff:

- 429 (rate limited) — respect `Retry-After` when provided
- 503 (service unavailable)

Non-retryable without a change to the request:

- 400 (bad request)
- 401 (unauthorized)
- 403 (forbidden)
- 404 (not found)

## Best practices

1. Include correlation IDs in server-side error logs for tracing
2. Use appropriate HTTP status codes for error categorization
3. Treat `code`, not the human-readable `error` text, as the stable identifier
4. Add relevant details where the handler supplies them
5. Apply exponential backoff to retryable responses

## Support

For questions about error codes or to report issues, contact support at ops@example.com.
