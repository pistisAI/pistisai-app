# Tunnel Configuration Management - Quick Reference

> **Verified against code (2026-11-24):** the config endpoints are real — `GET /:id/config` at `services/api-backend/routes/tunnels.js:793`, `PUT /:id/config` at :868, backed by `getTunnelConfig`/`updateTunnelConfig`/`resetTunnelConfig` at `services/api-backend/services/tunnel-service.js:620/652/725`, with validation in `services/api-backend/utils/tunnel-config-validation.js`. They are mounted at `/tunnels` (and `/api/tunnels`) by `services/api-backend/server.js:324`, **gated by `PISTISAI_ENABLE_LEGACY_TUNNEL_ROUTES`** (`server.js:186-188`). The old `services/api-backend/TUNNEL_CONFIG_MANAGEMENT_IMPLEMENTATION.md` does not exist; it was archived under `docs/archive/historical-reports/` (see "Files" below).

## Endpoints

### Get Configuration

```bash
GET /api/tunnels/:id/config
Authorization: Bearer <JWT>
```

### Update Configuration

```bash
PUT /api/tunnels/:id/config
Authorization: Bearer <JWT>
Content-Type: application/json

{
  "maxConnections": 200,
  "timeout": 60000,
  "compression": false
}
```

### Reset Configuration

```bash
POST /api/tunnels/:id/config/reset
Authorization: Bearer <JWT>
```

## Configuration Parameters

| Parameter | Type | Range | Default |
|-----------|------|-------|---------|
| maxConnections | integer | 1-10000 | 100 |
| timeout | integer | 1000-300000 ms | 30000 |
| compression | boolean | true/false | true |

## Service Methods

```javascript
// Get configuration
const config = await tunnelService.getTunnelConfig(tunnelId, userId);

// Update configuration
const updated = await tunnelService.updateTunnelConfig(
  tunnelId, userId, { maxConnections: 200 }, ipAddress, userAgent
);

// Reset configuration
const reset = await tunnelService.resetTunnelConfig(
  tunnelId, userId, ipAddress, userAgent
);
```

## Validation Utilities

```javascript
import {
  validateTunnelConfig,
  getDefaultTunnelConfig,
  mergeTunnelConfig,
  sanitizeTunnelConfig
} from './utils/tunnel-config-validation.js';

// Validate configuration
const result = validateTunnelConfig({ maxConnections: 200 });
// { isValid: true, errors: [] }

// Get defaults
const defaults = getDefaultTunnelConfig();
// { maxConnections: 100, timeout: 30000, compression: true }

// Merge with defaults
const merged = mergeTunnelConfig({ maxConnections: 200 });
// { maxConnections: 200, timeout: 30000, compression: true }

// Sanitize values
const sanitized = sanitizeTunnelConfig({ maxConnections: 20000 });
// { maxConnections: 10000, timeout: 30000, compression: true }
```

## Error Responses

### Invalid Configuration (400)

```json
{
  "error": "Bad request",
  "code": "INVALID_CONFIG",
  "message": "Invalid tunnel configuration",
  "details": ["maxConnections must be between 1 and 10000"]
}
```

### Tunnel Not Found (404)

```json
{
  "error": "Not found",
  "code": "TUNNEL_NOT_FOUND",
  "message": "Tunnel not found"
}
```

### Service Unavailable (503)

```json
{
  "error": "Service unavailable",
  "code": "SERVICE_UNAVAILABLE",
  "message": "Tunnel service is not initialized"
}
```

## Activity Logging

Configuration changes are logged with:

- Action: `config_update` or `config_reset`
- Status: `success` or `failure`
- IP Address: Client IP
- User Agent: Client user agent
- Details: Configuration changes (for updates)

## Testing

```bash
npm test -- test/api-backend/tunnel-config-management.test.js
```

**Test Coverage:**

- 19 unit tests
- 100% validation utility coverage
- All validation scenarios covered

## Files

- **Implementation:** `services/api-backend/utils/tunnel-config-validation.js`
- **Service Methods:** `services/api-backend/services/tunnel-service.js`
- **Endpoints:** `services/api-backend/routes/tunnels.js`
- **Tests:** `test/api-backend/tunnel-config-management.test.js`
- **Documentation:** `docs/archive/historical-reports/development/features/backend/TUNNEL_CONFIG_MANAGEMENT_IMPLEMENTATION.md` (the old `services/api-backend/TUNNEL_CONFIG_MANAGEMENT_IMPLEMENTATION.md` no longer exists — it was archived; see that file for the historical write-up)

## Validation Rules

### maxConnections

- Must be integer
- Minimum: 1
- Maximum: 10000
- Default: 100

### timeout

- Must be integer (milliseconds)
- Minimum: 1000 (1 second)
- Maximum: 300000 (5 minutes)
- Default: 30000 (30 seconds)

### compression

- Must be boolean
- Default: true

## Examples

### Create tunnel with custom config

```javascript
const tunnel = await tunnelService.createTunnel(userId, {
  name: 'My Tunnel',
  config: {
    maxConnections: 200,
    timeout: 60000,
    compression: false
  }
}, ipAddress, userAgent);
```

### Update single parameter

```javascript
const updated = await tunnelService.updateTunnelConfig(
  tunnelId, userId,
  { maxConnections: 500 },
  ipAddress, userAgent
);
// Other parameters preserved
```

### Reset to defaults

```javascript
const reset = await tunnelService.resetTunnelConfig(
  tunnelId, userId, ipAddress, userAgent
);
// Returns: { maxConnections: 100, timeout: 30000, compression: true }
```

## Requirement Coverage

✅ **Requirement 4.3: Tunnel Configuration Management**

- ✅ Create tunnel config endpoints (GET, PUT, POST)
- ✅ Support max connections, timeout, compression settings
- ✅ Implement config validation with comprehensive error messages
