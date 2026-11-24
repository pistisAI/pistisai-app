# API Versioning Strategy

## Overview

Pistisai API has versioning middleware in the request pipeline, but it only tags requests and sets headers. This guide explains what the middleware actually does, and labels the URL-routed, response-transforming model that does **not** exist in code.

**Requirements: 12.4**

## Current implementation (verified against code)

- `apiVersioningMiddleware()` is in the pipeline at `services/api-backend/middleware/pipeline.js:102-103`. It reads a `/vN/` prefix from the request path, validates it against `API_VERSIONS`, sets `req.apiVersion` / `req.versionInfo`, and sets `API-Version` and `API-Version-Status` response headers (`services/api-backend/middleware/api-versioning.js:55-99`). Requests without a prefix are tagged `v2` (the default, `api-versioning.js:32, 88-92`).
- **No versioned routes are mounted.** `mountVersionedRoutes`, `versionRouter` and `createVersionedRouter` are exported from `api-versioning.js:109-170` but never called. All routes in `services/api-backend/server.js` are unversioned, so `/v1/users/me` is tagged as v1 but has no handler and returns 404. See [API_DOCUMENTATION_GUIDE.md](API_DOCUMENTATION_GUIDE.md) for the live unversioned paths.
- `backwardCompatibilityMiddleware()` is also in the pipeline (`pipeline.js:105-106`), but only adds `_apiVersion: 'v1'` to object responses (`api-versioning.js:200-221`). There is no response-format transformation between v1 and v2.
- **Conflicting sunset dates:** `API_VERSIONS.v1.sunsetAt` is `2025-01-01` in the versioning middleware (`api-versioning.js:14-21`), while the deprecation registry uses `2027-01-01` (`services/api-backend/services/deprecation-service.js:23-57`). Both are real values in code; the middleware's `Sunset` header uses 2025, the `/api/deprecation/*` endpoints report 2027. See [API_DEPRECATION_GUIDE.md](API_DEPRECATION_GUIDE.md).
- `/api/versions` is live (`server.js:434-436`; also `/versions` on the api subdomain) and returns the `API_VERSIONS` table.

## Versioning Strategy

### URL Prefix detection (tagging only — no versioned route mounts)

The middleware recognises a `/vN/` prefix for tagging and header purposes:

```
/v1/endpoint  - tagged v1; no v1 handlers are mounted (404 in practice)
/v2/endpoint  - tagged v2; no v2 handlers are mounted (404 in practice)
/endpoint     - tagged v2 (default); this is the live unversioned route set
```

This is verified by the absence of any call to `mountVersionedRoutes` / `versionRouter` in `services/api-backend`. The examples under "Using API Versions" below describe the planned URL-routed model, not the current app.

### Supported Versions

| Version | Status | Description | Sunset Date |
|---------|--------|-------------|------------|
| v1 | Deprecated | Tag-only in versioning middleware (`sunsetAt: 2025-01-01`) | 2025-01-01 in `api-versioning.js:14-21`; 2027-01-01 in the deprecation registry |
| v2 | Current | Current stable version | N/A |

## Using API Versions

> The `/v1/...` and `/v2/...` URLs below are part of the planned model. In the current code these prefixes are only read for tagging; see [API_DOCUMENTATION_GUIDE.md](API_DOCUMENTATION_GUIDE.md) for the unversioned paths that actually exist.

### Version 2 (Current)

Use v2 for all new integrations. This is the recommended version.

```bash
# Using explicit v2 prefix
curl https://api.example.com/v2/users/me \
  -H "Authorization: Bearer YOUR_TOKEN"

# Using default (also v2)
curl https://api.example.com/users/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Version 1 (Deprecated)

v1 is marked deprecated. The versioning middleware emits `Sunset: Wed, 01 Jan 2025 00:00:00 GMT` for a `/v1/` prefix (`services/api-backend/middleware/api-versioning.js:76-87`), while the deprecation service registry uses `2027-01-01` (`services/api-backend/services/deprecation-service.js:23-57`). Migrate to the unversioned (v2-default) paths for new work.

```bash
# Using v1 (deprecated)
curl https://api.example.com/v1/users/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Version Headers

All API responses include version information in headers:

```
API-Version: v2
API-Version-Status: current
```

### Deprecation Headers

Deprecated versions include additional headers:

```
Deprecation: true
Sunset: Wed, 01 Jan 2025 00:00:00 GMT
Warning: 299 - "API version v1 is deprecated. Migrate to v2 before 2025-01-01"
```

## Response Format Differences (planned — not transformed in code)

> No middleware rewrites response bodies by version. `backwardCompatibilityMiddleware()` only adds `_apiVersion: 'v1'` to object responses (`services/api-backend/middleware/api-versioning.js:200-221`). The two shapes below are the planned contract, not the current app's behaviour.

### Version 1 (Deprecated)

```json
{
  "success": true,
  "data": {
    "userId": "123",
    "userEmail": "user@example.com",
    "userTier": "premium"
  }
}
```

### Version 2 (Current)

```json
{
  "user": {
    "id": "123",
    "email": "user@example.com",
    "tier": "premium",
    "profile": {
      "firstName": "John",
      "lastName": "Doe"
    }
  }
}
```

## Error Response Differences (planned — not transformed in code)

### Version 1 (Deprecated)

```json
{
  "success": false,
  "error": "User not found",
  "errorCode": "USER_NOT_FOUND"
}
```

### Version 2 (Current)

```json
{
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "User not found",
    "statusCode": 404,
    "suggestion": "Check the user ID and try again"
  }
}
```

## Migration Guide

### Step 1: Update Base URL

Change your API base URL from:

```
https://api.example.com/v1
```

To:

```
https://api.example.com/v2
```

Or simply use:

```
https://api.example.com
```

### Step 2: Update Response Parsing

Update your code to handle the new v2 response format:

**Before (v1):**

```javascript
const response = await fetch('/v1/users/me');
const data = await response.json();
const email = data.data.userEmail;
```

**After (v2):**

```javascript
const response = await fetch('/v2/users/me');
const data = await response.json();
const email = data.user.email;
```

### Step 3: Update Error Handling

Update error handling to use the new v2 error format:

**Before (v1):**

```javascript
if (!response.ok) {
  const error = await response.json();
  console.error(error.error);
}
```

**After (v2):**

```javascript
if (!response.ok) {
  const error = await response.json();
  console.error(error.error.message);
  console.error(error.error.suggestion);
}
```

### Step 4: Test Thoroughly

Test all API endpoints with v2 before deploying to production.

## Backward Compatibility

### Automatic Fallback

A request without a version prefix is tagged `v2` by the middleware (`services/api-backend/middleware/api-versioning.js:32, 88-92`). There is no separate v2 route set to fall back to: the unversioned path is the live route, while a `/v2/...` prefix is only a tag (and has no handler, so it 404s today).

### Version-Specific Behavior

Some endpoints may have different behavior in different versions:

- **v1**: Legacy response format, limited features
- **v2**: Current response format, all features

## API Version Information Endpoint

Get information about all supported API versions:

```bash
curl https://api.example.com/api/versions
```

Response (verified against `services/api-backend/middleware/api-versioning.js:178-190` and `routes/handlers.js` / `server.js:434-436`):

```json
{
  "currentVersion": "v2",
  "defaultVersion": "v2",
  "supportedVersions": [
    {
      "version": "1.0.0",
      "status": "deprecated",
      "deprecatedAt": "2024-01-01",
      "sunsetAt": "2025-01-01",
      "description": "Legacy API version - use v2 for new integrations"
    },
    {
      "version": "2.0.0",
      "status": "current",
      "description": "Current stable API version"
    }
  ],
  "timestamp": "2024-11-20T10:00:00Z"
}
```

`currentVersion` reflects the request's own tag (`req.apiVersion`), not a fixed value — the example above is for an unversioned request. The `version` field inside each `supportedVersions` entry is the semver value from `API_VERSIONS` (`1.0.0` / `2.0.0`), because the handler spreads `...value` after setting `version: key`.

## Best Practices

1. **Always use v2 for new integrations** - v1 is deprecated and will be removed
2. **Check deprecation headers** - Monitor for deprecation warnings in responses
3. **Plan migration early** - Don't wait until the sunset date to migrate
4. **Test with v2** - Ensure your integration works with v2 before deploying
5. **Update documentation** - Keep your API documentation up to date with the version you're using

## Deprecation Timeline

- **2024-01-01**: v1 marked as deprecated
- **2025-01-01**: `API_VERSIONS.v1.sunsetAt` in the versioning middleware (`api-versioning.js:19`)
- **2027-01-01**: `DEPRECATED_ENDPOINTS` sunset in the deprecation registry (`deprecation-service.js:28,36,44,52`)

These two dates disagree in code; the middleware's `Sunset` header uses 2025, the `/api/deprecation/*` report uses 2027. Neither removes the `/v1/*` paths, because no versioned routes are mounted.

## Support

For questions about API versioning or migration help, contact:

- Email: ops@example.com
- Documentation: https://docs.example.com
- GitHub Issues: https://github.com/pistisAI/pistisai-app/issues

## Implementation Details

### Versioning Middleware (live)

The API uses middleware in the pipeline (`services/api-backend/middleware/pipeline.js:102-106`) to:

1. Extract a version tag from a `/vN/` URL path (`api-versioning.js:41-47, 55-99`)
2. Validate the tag is supported (400 `UNSUPPORTED_API_VERSION` otherwise)
3. Add version info to the request (`req.apiVersion`, `req.versionInfo`)
4. Add `API-Version` / `API-Version-Status` headers and `Deprecation` / `Sunset` / `Warning` headers for a deprecated tag

### Version Routing (planned — not mounted)

`mountVersionedRoutes`, `versionRouter` and `createVersionedRouter` exist in `api-versioning.js:109-170` but are never called. Routes in `server.js` are unversioned:

- `/v1/endpoint` — no handler (404)
- `/v2/endpoint` — no handler (404)
- `/endpoint` — live unversioned handler, tagged `v2`

### Response Transformation (planned — only a tag today)

`backwardCompatibilityMiddleware()` is in the pipeline but only adds `_apiVersion: 'v1'` to object responses (`api-versioning.js:200-221`); it does not translate between v1 and v2 response formats.

## Future Versions

When v3 is released:

1. v2 will remain current for 12 months
2. v2 will be marked as deprecated
3. v3 will become the default version
4. Migration guides will be provided

This ensures a smooth transition path for all API consumers.
