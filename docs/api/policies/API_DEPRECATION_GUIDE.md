# API Deprecation and Migration Guide

## Overview

Pistisai API implements a structured deprecation process to ensure smooth transitions between API versions. This guide explains how deprecation works, how to identify deprecated endpoints, and how to migrate to newer versions.

**Requirements: 12.5**

## Current implementation (verified against code)

- The discovery endpoints are live: `services/api-backend/server.js:333` registers `/deprecation`, implemented in `services/api-backend/routes/deprecation.js:22-142` (`GET /status`, `/deprecated`, `/sunset`, `/endpoint-info`, `/migration-guide/:guideId`).
- The registry in `services/api-backend/services/deprecation-service.js:23-57` contains four deprecated `/v1/*` paths with `sunsetAt: '2027-01-01'`, not `2025-01-01`.
- `daysUntilSunset` is calculated at request time (`deprecation-service.js:128-134`), so it is not a fixed number.
- **There is no deprecation middleware in the request pipeline** (`services/api-backend/middleware/pipeline.js`). The `getDeprecationHeaders()` helper exists (`deprecation-service.js:225-242`) but is not wired into any request, and no middleware injects `_deprecation` into response bodies or returns `410 Gone` at sunset. The header/body/sunset-enforcement behaviour described below is the planned design, not current behaviour. See [API_VERSIONING_GUIDE.md](API_VERSIONING_GUIDE.md) for the versioning middleware that *is* in the pipeline.

## Deprecation Policy

### Timeline

- **Deprecation**: Endpoint is marked as deprecated but continues to work
- **Sunset**: Endpoint is removed and no longer available (planned: 410 Gone — not yet enforced in code)
- **Minimum Notice**: 12 months between deprecation and sunset

### Current Status

Verified against `services/api-backend/services/deprecation-service.js:23-57`; the sunset is `2027-01-01` and the remaining-days value is computed on each request.

| Version | Status | Deprecated | Sunset | Days Remaining |
|---------|--------|-----------|--------|-----------------|
| v1 | Deprecated (registry) | 2024-01-01 | 2027-01-01 | computed at request time |
| v2 | Current | N/A | N/A | N/A |

## Identifying Deprecated Endpoints

### Deprecation Headers (planned — not applied by the current pipeline)

> `getDeprecationHeaders()` builds the headers below (`services/api-backend/services/deprecation-service.js:225-242`), but no deprecation middleware is registered in `services/api-backend/middleware/pipeline.js`, so responses from `/v1/*` paths do **not** currently carry them. The separate versioning middleware does set `Deprecation`/`Sunset`/`Warning` for a `/v1/` path prefix (`middleware/api-versioning.js:76-87`) using its own `2025-01-01` date; see [API_VERSIONING_GUIDE.md](API_VERSIONING_GUIDE.md).

The intended response headers:

```
Deprecation: true
Sunset: Fri, 01 Jan 2027 00:00:00 GMT
Warning: 299 - "API endpoint /v1/users is deprecated and will be removed on 2027-01-01 (days). Use /v2/users instead."
Deprecation-Link: /v2/users
```

### Response Body (planned — no body injection in code)

> No middleware adds a `_deprecation` object to responses. The shape below is the planned design; today the `/api/deprecation/*` discovery endpoints are the source of this information.

```json
{
  "user": {
    "id": "123",
    "email": "user@example.com"
  },
  "_deprecation": {
    "deprecated": true,
    "message": "API endpoint /v1/users is deprecated and will be removed on 2027-01-01 (days, computed at request time). Use /v2/users instead.",
    "replacedBy": "/v2/users",
    "sunsetAt": "2027-01-01",
    "migrationGuide": {
      "title": "Migrating from API v1 to v2",
      "steps": [...]
    }
  }
}
```

## Deprecation Information Endpoints

> These routes are live (`services/api-backend/server.js:333`, `routes/deprecation.js`). Numeric `daysUntilSunset` values in the examples below are illustrative: the service computes them on every request from the `2027-01-01` sunset date (`deprecation-service.js:128-134`). `totalDeprecated` is `4` for the four registered `/v1/*` paths.

### Get Deprecation Status

```bash
curl https://api.example.com/api/deprecation/status
```

Response:

```json
{
  "timestamp": "2024-11-20T10:00:00Z",
  "deprecatedEndpoints": [
    {
      "path": "/v1/users",
      "status": "deprecated",
      "deprecatedAt": "2024-01-01",
      "sunsetAt": "2027-01-01",
      "replacedBy": "/v2/users",
      "reason": "API v1 is deprecated. Use v2 for new integrations.",
      "daysUntilSunset": 45
    }
  ],
  "sunsetEndpoints": [],
  "totalDeprecated": 4,
  "totalSunset": 0
}
```

### Get List of Deprecated Endpoints

```bash
curl https://api.example.com/api/deprecation/deprecated
```

Response:

```json
{
  "endpoints": [
    {
      "path": "/v1/users",
      "status": "deprecated",
      "deprecatedAt": "2024-01-01",
      "sunsetAt": "2027-01-01",
      "replacedBy": "/v2/users",
      "reason": "API v1 is deprecated. Use v2 for new integrations.",
      "daysUntilSunset": 45
    },
    {
      "path": "/v1/tunnels",
      "status": "deprecated",
      "deprecatedAt": "2024-01-01",
      "sunsetAt": "2027-01-01",
      "replacedBy": "/v2/tunnels",
      "reason": "API v1 is deprecated. Use v2 for new integrations.",
      "daysUntilSunset": 45
    }
  ],
  "count": 4
}
```

### Get Endpoint Deprecation Info

```bash
curl "https://api.example.com/api/deprecation/endpoint-info?path=/v1/users"
```

Response:

```json
{
  "path": "/v1/users",
  "status": "deprecated",
  "deprecatedAt": "2024-01-01",
  "sunsetAt": "2027-01-01",
  "replacedBy": "/v2/users",
  "reason": "API v1 is deprecated. Use v2 for new integrations.",
  "migrationGuide": {
    "title": "Migrating from API v1 to v2",
    "steps": [...]
  }
}
```

### Get Migration Guide

```bash
curl https://api.example.com/api/deprecation/migration-guide/MIGRATION_V1_TO_V2
```

Response:

```json
{
  "title": "Migrating from API v1 to v2",
  "description": "Complete guide for migrating from Pistisai API v1 to v2",
  "steps": [
    {
      "step": 1,
      "title": "Update Base URL",
      "description": "Change your API base URL from /v1 to /v2",
      "before": "https://api.example.com/v1/users",
      "after": "https://api.example.com/v2/users"
    },
    {
      "step": 2,
      "title": "Update Response Parsing",
      "description": "Update your code to handle the new v2 response format",
      "before": "const email = data.data.userEmail;",
      "after": "const email = data.user.email;"
    },
    {
      "step": 3,
      "title": "Update Error Handling",
      "description": "Update error handling to use the new v2 error format",
      "before": "console.error(error.error);",
      "after": "console.error(error.error.message);"
    },
    {
      "step": 4,
      "title": "Test Thoroughly",
      "description": "Test all API endpoints with v2 before deploying to production",
      "resources": [
        "https://docs.example.com/api/v2",
        "https://api.example.com/api/docs"
      ]
    }
  ],
  "resources": {
    "documentation": "https://docs.example.com/api/migration",
    "apiDocs": "https://api.example.com/api/docs",
    "support": "ops@example.com"
  },
  "timeline": {
    "deprecatedAt": "2024-01-01",
    "sunsetAt": "2027-01-01",
    "daysUntilSunset": 45
  }
}
```

## Migration Guide: v1 to v2

### Step 1: Update Base URL

Change your API base URL from v1 to v2:

**Before (v1):**

```javascript
const baseURL = 'https://api.example.com/v1';
```

**After (v2):**

```javascript
const baseURL = 'https://api.example.com/v2';
```

### Step 2: Update Response Parsing

Update your code to handle the new v2 response format:

**Before (v1):**

```javascript
const response = await fetch('/v1/users/me');
const data = await response.json();
const email = data.data.userEmail;
const tier = data.data.userTier;
```

**After (v2):**

```javascript
const response = await fetch('/v2/users/me');
const data = await response.json();
const email = data.user.email;
const tier = data.user.tier;
```

### Step 3: Update Error Handling

Update error handling to use the new v2 error format:

**Before (v1):**

```javascript
if (!response.ok) {
  const error = await response.json();
  console.error(error.error);
  console.error(error.errorCode);
}
```

**After (v2):**

```javascript
if (!response.ok) {
  const error = await response.json();
  console.error(error.error.message);
  console.error(error.error.code);
  console.error(error.error.suggestion);
}
```

### Step 4: Update Tunnel Endpoints

**Before (v1):**

```javascript
const tunnels = await fetch('/v1/tunnels');
const data = await tunnels.json();
const tunnelId = data.data[0].tunnelId;
```

**After (v2):**

```javascript
const tunnels = await fetch('/v2/tunnels');
const data = await tunnels.json();
const tunnelId = data.tunnels[0].id;
```

### Step 5: Test Thoroughly

Test all API endpoints with v2 before deploying to production:

```bash
# Test user endpoint
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.example.com/v2/users/me

# Test tunnels endpoint
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.example.com/v2/tunnels

# Test admin endpoint
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.example.com/v2/admin/users
```

## Sunset Endpoints (planned)

> No sunset enforcement is implemented in the request pipeline. The response below is the planned contract; today the registry reports sunset state via `GET /api/deprecation/sunset` (`services/api-backend/routes/deprecation.js:55-71`).

When an endpoint reaches its sunset date, it is intended to return a 410 Gone response:

```json
{
  "error": {
    "code": "ENDPOINT_SUNSET",
    "message": "This API endpoint has been removed as of 2027-01-01",
    "statusCode": 410,
    "replacedBy": "/v2/users",
    "suggestion": "Please use /v2/users instead"
  }
}
```

## Best Practices

1. **Monitor Deprecation Headers**: Check for deprecation headers in API responses
2. **Plan Migration Early**: Don't wait until the sunset date to migrate
3. **Use Deprecation Endpoints**: Check `/api/deprecation/status` regularly
4. **Test with v2**: Ensure your integration works with v2 before deploying
5. **Update Documentation**: Keep your API documentation up to date
6. **Set Reminders**: Set calendar reminders for sunset dates
7. **Gradual Migration**: Migrate endpoints gradually, not all at once

## Deprecation Timeline

### Current Deprecations

- **v1 API**: Deprecated 2024-01-01, Sunset 2027-01-01 (per `services/api-backend/services/deprecation-service.js:23-57`)

### Future Deprecations

When v3 is released:

1. v2 will remain current for 12 months
2. v2 will be marked as deprecated
3. v3 will become the default version
4. Migration guides will be provided

## Support

For questions about API deprecation or migration help:

- **Email**: ops@example.com
- **Documentation**: https://docs.example.com
- **API Docs**: the Markdown guides in [`docs/api/`](../README.md) (no Swagger UI is mounted)
- **GitHub Issues**: https://github.com/pistisAI/pistisai-app/issues

## Implementation Details

### Deprecation Service

The deprecation service manages:

- Deprecated endpoint registry
- Migration guides
- Deprecation status tracking
- Sunset date calculation (`calculateDaysUntilSunset`, `deprecation-service.js:128-134`) — not enforcement

### Deprecation Middleware (planned — not in the pipeline)

The middleware described here does not exist in `services/api-backend/middleware/pipeline.js`. The equivalent helper functions are exported by `services/api-backend/services/deprecation-service.js` but are only used by the discovery routes. Planned behaviour:

- Adds deprecation headers to responses (`getDeprecationHeaders`, `deprecation-service.js:225-242`)
- Logs deprecation warnings
- Includes deprecation info in response body
- Enforces sunset endpoints (no implementation found in code)

### Deprecation Routes (live)

Deprecation routes are mounted by `services/api-backend/server.js:333` and provide:

- `/api/deprecation/status` - Overall deprecation status
- `/api/deprecation/deprecated` - List of deprecated endpoints
- `/api/deprecation/sunset` - List of sunset endpoints
- `/api/deprecation/endpoint-info` - Info for specific endpoint
- `/api/deprecation/migration-guide/{id}` - Migration guides

## Monitoring Deprecation

### Logging

All deprecation warnings are logged with:

- Endpoint path
- Request method
- User ID
- Timestamp

### Metrics

Track deprecation usage:

- Number of requests to deprecated endpoints
- Percentage of traffic using deprecated endpoints
- Time until sunset for each endpoint

### Alerts

Set up alerts for:

- Endpoints approaching sunset date
- High traffic to deprecated endpoints
- Sunset endpoint access attempts

</content>
