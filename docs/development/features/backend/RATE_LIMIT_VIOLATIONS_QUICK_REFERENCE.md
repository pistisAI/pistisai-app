# Rate Limit Violations Logging - Quick Reference

## Overview

Task 35 implements comprehensive rate limit violation logging for the API backend. This feature logs all rate limit violations with full context (user, IP, endpoint) and provides analysis endpoints for administrators.

## Validates

- **Requirement 6.8**: THE API SHALL log rate limit violations for analysis

## Components Implemented

### 1. Database Migration (019_rate_limit_violations.sql)

Creates two tables:

- `rate_limit_violations` - Stores individual violation records
- `rate_limit_violation_stats` - Stores aggregated statistics

**Key Fields:**

- `user_id` - User who triggered the violation
- `violation_type` - Type of violation (window, burst, concurrent, IP)
- `endpoint` - API endpoint that was rate limited
- `method` - HTTP method (GET, POST, etc.)
- `ip_address` - Client IP address
- `user_agent` - Client user agent
- `violation_context` - JSONB with additional context
- `timestamp` - When the violation occurred

### 2. Service (`services/api-backend/services/rate-limit-violations-service.js`)

> **Verified against code:** the service is at `services/api-backend/services/rate-limit-violations-service.js` (class methods `logViolation` at :36, `getUserViolations` at :109, `getIpViolations` at :164, `getUserViolationStats` at :217, `getIpViolationStats` at :294, `getTopViolators` at :371, `getTopViolatingIps` at :435, `getEndpointViolations` at :499). The router is `services/api-backend/routes/rate-limit-violations.js`, imported at `services/api-backend/server.js:100` and mounted at `/rate-limit-violations` by `server.js:350`. The migration is `services/api-backend/database/migrations/019_rate_limit_violations.sql`.

**RateLimitViolationsService** provides:

#### Logging Methods

- `logViolation()` - Log a single violation

#### Retrieval Methods

- `getUserViolations()` - Get violations for a specific user
- `getIpViolations()` - Get violations for a specific IP
- `getEndpointViolations()` - Get violations for a specific endpoint

#### Analysis Methods

- `getUserViolationStats()` - Statistics for a user
- `getIpViolationStats()` - Statistics for an IP
- `getTopViolators()` - Top violating users
- `getTopViolatingIps()` - Top violating IPs

### 3. Routes (rate-limit-violations.js)

Admin-only endpoints:

```
GET /violations/user/:userId
  - Get violations for a user
  - Query params: limit, offset, startTime, endTime

GET /violations/ip/:ipAddress
  - Get violations for an IP
  - Query params: limit, offset, startTime, endTime

GET /violations/stats/user/:userId
  - Get user violation statistics
  - Query params: startTime, endTime

GET /violations/stats/ip/:ipAddress
  - Get IP violation statistics
  - Query params: startTime, endTime

GET /violations/top-violators
  - Get top violating users
  - Query params: limit, startTime, endTime

GET /violations/top-ips
  - Get top violating IPs
  - Query params: limit, startTime, endTime

GET /violations/endpoint/:endpoint
  - Get violations for an endpoint
  - Query params: startTime, endTime
```

### 4. Middleware Integration (rate-limiter.js)

Updated to log violations when rate limits are exceeded:

- Logs window limit violations
- Logs burst limit violations
- Logs concurrent limit violations
- Includes request context (endpoint, method, IP, user agent)
- Asynchronous logging to avoid blocking requests

## Usage Example

### Logging a Violation

```javascript
const violationsService = new RateLimitViolationsService();

await violationsService.logViolation({
  userId: 'user-123',
  violationType: 'window_limit_exceeded',
  endpoint: '/api/tunnels',
  method: 'GET',
  ipAddress: '192.168.1.100',
  userAgent: 'Mozilla/5.0',
  context: {
    windowRequests: 1000,
    maxRequests: 1000,
    correlationId: 'req-12345'
  }
});
```

### Retrieving Violations

```javascript
// Get user violations
const violations = await violationsService.getUserViolations('user-123', {
  limit: 100,
  offset: 0,
  startTime: '2024-01-01T00:00:00Z',
  endTime: '2024-01-31T23:59:59Z'
});

// Get user statistics
const stats = await violationsService.getUserViolationStats('user-123');
// Returns: {
//   userId: 'user-123',
//   totalViolations: 10,
//   violationTypesCount: 2,
//   uniqueIps: 3,
//   uniqueEndpoints: 4,
//   firstViolation: Date,
//   lastViolation: Date,
//   violationsByType: { window_limit_exceeded: 6, burst_limit_exceeded: 4 }
// }

// Get top violators
const topViolators = await violationsService.getTopViolators({ limit: 10 });
```

### API Usage

```bash
# Get violations for a user
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.example.com/violations/user/user-123?limit=50&offset=0"

# Get violation statistics for a user
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.example.com/violations/stats/user/user-123"

# Get top violators
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.example.com/violations/top-violators?limit=10"

# Get violations for an IP
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.example.com/violations/ip/192.168.1.100"

# Get violations for an endpoint
curl -H "Authorization: Bearer $TOKEN" \
  "https://api.example.com/violations/endpoint/%2Fapi%2Ftunnels"
```

## Violation Types

```javascript
VIOLATION_TYPES = {
  WINDOW_LIMIT_EXCEEDED: 'window_limit_exceeded',
  BURST_LIMIT_EXCEEDED: 'burst_limit_exceeded',
  CONCURRENT_LIMIT_EXCEEDED: 'concurrent_limit_exceeded',
  IP_LIMIT_EXCEEDED: 'ip_limit_exceeded'
}
```

## Database Indexes

Optimized for common queries:

- `idx_rate_limit_violations_user_id` - User lookups
- `idx_rate_limit_violations_timestamp` - Time-based queries
- `idx_rate_limit_violations_ip_address` - IP lookups
- `idx_rate_limit_violations_violation_type` - Type filtering
- `idx_rate_limit_violations_user_timestamp` - User + time queries
- `idx_rate_limit_violations_ip_timestamp` - IP + time queries

## Testing

Comprehensive test suite in `test/api-backend/rate-limit-violations.test.js`:

- Logging violations (window, burst, concurrent, IP)
- Retrieving violations by user and IP
- Pagination and time filtering
- Statistics calculation
- Top violators identification
- Endpoint violation analysis

**Test Coverage:** 65.6% statements, 68.49% branches, 100% functions

## Integration Points

1. **Rate Limiter Middleware** - Automatically logs violations when limits are exceeded
2. **Admin Routes** - Provides analysis endpoints for administrators
3. **Security Audit Logger** - Integrates with existing security logging
4. **Database** - Stores violations in PostgreSQL

## Performance Considerations

- Asynchronous logging to avoid blocking requests
- Indexed queries for efficient retrieval
- Pagination support for large result sets
- Time-based filtering for historical analysis
- Aggregated statistics for quick insights

## Next Steps

1. Apply the migration: `services/api-backend/database/migrations/019_rate_limit_violations.sql` is applied at backend startup via `services/api-backend/server.js:563-578` → `dbMigrator.migrate()` (`services/api-backend/database/migrate-pg.js`). **There is no `npm run migrate` script** in `services/api-backend/package.json` (scripts: `start`, `dev`, `test`, `test:*`, `db:validate`, `db:stats`, `db:test`, …).
2. Routes are **already registered** in the main server — `services/api-backend/server.js:100` imports `./routes/rate-limit-violations.js` and `:350` mounts it at `/rate-limit-violations` (also `/api/rate-limit-violations`, see `registerRoutes` at `:265-267`).
3. Monitor violation patterns
4. Set up alerts for excessive violations
5. Use analytics for rate limit tuning
