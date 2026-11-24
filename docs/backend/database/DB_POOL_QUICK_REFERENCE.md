# Database Connection Pool - Quick Reference

## Overview

Centralized PostgreSQL connection pool with health monitoring for the Pistisai Admin Center backend.

## Usage

### Import and Use the Pool

```javascript
import { getPool, query, getClient } from '../database/db-pool.js';

// Simple query
const result = await query('SELECT * FROM users WHERE id = $1', [userId]);

// Get a client for transactions
const client = await getClient();
try {
  await client.query('BEGIN');
  await client.query('INSERT INTO ...');
  await client.query('UPDATE ...');
  await client.query('COMMIT');
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
} finally {
  client.release();
}

// Get pool instance directly
const pool = getPool();
const result = await pool.query('SELECT * FROM users');
```

## Configuration

### Environment Variables

```bash
# Database Connection
DB_HOST=localhost
DB_PORT=5432
DB_NAME=Pistisai
DB_USER=your_db_user
DB_PASSWORD=your_db_password
DB_SSL=false

# Pool Configuration (Requirement 17)
DB_POOL_MAX=50                      # Maximum connections (default: 50)
DB_POOL_MIN=5                       # Minimum connections (default: 5)
DB_POOL_CONNECT_TIMEOUT=30000       # Connection timeout in ms (default: 30000)
DB_POOL_IDLE=600000                 # Idle timeout in ms (default: 600000)
DB_STATEMENT_TIMEOUT=60000          # Statement timeout in ms (default: 60000)

# Monitoring Configuration
DB_HEALTH_CHECK_INTERVAL=30000      # Health check interval in ms (default: 30000)
DB_METRICS_LOG_INTERVAL=60000       # Metrics logging interval in ms (default: 60000)
```

## API Endpoints

> **Verified against code:** `services/api-backend/server.js:265-267` mounts every route at both `/api<path>` and `<path>`. The only registered database health route is `registerRoutes('/db/health', dbHealthHandler)` (`server.js:284`), with the handler in `services/api-backend/routes/db-health.js:8-38`; a catch-all `registerRoutes('/db', dbHealthRoutes)` at `server.js:296` uses that same handler. **No `/api/db/pool/health`, `/api/db/pool/metrics` or `/api/db/pool/status` route is registered anywhere in `services/api-backend`** (no matches for those paths in its `.js` files). Pool internals exist in code as `getPoolMetrics()` and `healthCheck()` (`services/api-backend/database/db-pool.js:688-750`) but are not exposed by those endpoints. The pool-specific request/response examples below are a **planned API, not current behavior**.

### Health Check (planned pool endpoint — not implemented)

> The **live** endpoint is `GET /api/db/health` (or `/db/health`), registered at `services/api-backend/server.js:284` and implemented at `services/api-backend/routes/db-health.js:8-38`. It reports schema validation via `dbMigrator.validateSchema()` with a 200 shape of `{"status": "healthy"|"degraded", "database_type", "schema_validation", "all_tables_valid", "timestamp"}` (503 returns `{"status": "error", "message", "error"?, "timestamp"}`) — **not** the `poolMetrics` shape shown below.

```bash
# Planned, not registered: GET /api/db/pool/health
GET /api/db/pool/health

# Response (200 OK)
{
  "status": "healthy",
  "responseTime": 5,
  "poolMetrics": {
    "totalConnections": 10,
    "totalCount": 5,
    "idleCount": 3,
    "waitingCount": 0,
    "errors": 0,
    "lastHealthCheck": "2025-01-19T12:00:00.000Z",
    "healthCheckStatus": "healthy",
    "status": "active"
  },
  "timestamp": "2025-01-19T12:00:00.000Z"
}

# Response (503 Service Unavailable)
{
  "status": "unhealthy",
  "error": "Connection refused",
  "responseTime": 30000,
  "timestamp": "2025-01-19T12:00:00.000Z"
}
```

### Pool Metrics (planned — not implemented)

```bash
# Planned, not registered: GET /api/db/pool/metrics
GET /api/db/pool/metrics

# Response
{
  "status": "success",
  "metrics": {
    "totalConnections": 10,
    "totalCount": 5,
    "idleCount": 3,
    "waitingCount": 0,
    "errors": 0,
    "lastHealthCheck": "2025-01-19T12:00:00.000Z",
    "healthCheckStatus": "healthy",
    "status": "active"
  },
  "timestamp": "2025-01-19T12:00:00.000Z"
}
```

### Monitoring Status (planned — not implemented)

```bash
# Planned, not registered: GET /api/db/pool/status
GET /api/db/pool/status

# Response
{
  "status": "success",
  "monitoring": {
    "isMonitoring": true,
    "healthCheckInterval": 30000,
    "metricsLogInterval": 60000,
    "exhaustionThreshold": 0.9
  },
  "timestamp": "2025-01-19T12:00:00.000Z"
}
```

## Monitoring

### Automatic Monitoring

The pool monitor automatically:

- Performs health checks every 30 seconds
- Logs metrics every 60 seconds
- Alerts when pool usage exceeds 90%
- Alerts when clients are waiting for connections
- Alerts on health check failures

### Log Messages

**Normal Operation:**

```
🟢 [DB Pool] New client connected
🟡 [DB Pool] Client acquired from pool
📊 [Pool Monitor] Connection pool metrics
```

**Warnings:**

```
⚠️ [Pool Monitor] Connection pool nearing exhaustion
⚠️ [Pool Monitor] Clients waiting for database connections
```

**Errors:**

```
🔴 [DB Pool] Unexpected error on idle client
🔴 [Pool Monitor] Health check failed
🚨 [Pool Monitor] ALERT: Database health check failed
🚨 [Pool Monitor] ALERT: Connection pool exhaustion
```

## Best Practices

### Connection Management

1. **Always release connections:**

```javascript
const client = await getClient();
try {
  // Use client
} finally {
  client.release(); // Always release!
}
```

1. **Use query() for simple queries:**

```javascript
// Good - automatic connection management
const result = await query('SELECT * FROM users');

// Avoid - manual connection management for simple queries
const pool = getPool();
const client = await pool.connect();
const result = await client.query('SELECT * FROM users');
client.release();
```

1. **Use transactions properly:**

```javascript
const client = await getClient();
try {
  await client.query('BEGIN');
  // Multiple queries
  await client.query('COMMIT');
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
} finally {
  client.release();
}
```

### Performance Optimization

1. **Use prepared statements for repeated queries:**

```javascript
const result = await query('SELECT * FROM users WHERE email = $1', [email]);
```

1. **Batch operations when possible:**

```javascript
// Good - single query
await query('INSERT INTO users (email, name) VALUES ($1, $2), ($3, $4)', [
  email1,
  name1,
  email2,
  name2,
]);

// Avoid - multiple queries
await query('INSERT INTO users (email, name) VALUES ($1, $2)', [email1, name1]);
await query('INSERT INTO users (email, name) VALUES ($1, $2)', [email2, name2]);
```

1. **Use indexes for frequently queried columns:**

```sql
CREATE INDEX idx_users_email ON users(email);
```

### Error Handling

```javascript
try {
  const result = await query('SELECT * FROM users WHERE id = $1', [userId]);
  if (result.rows.length === 0) {
    throw new Error('User not found');
  }
  return result.rows[0];
} catch (error) {
  logger.error('Database query failed', {
    error: error.message,
    query: 'SELECT users',
    userId,
  });
  throw error;
}
```

## Troubleshooting

### Pool Exhaustion

**Symptoms:**

- Clients waiting for connections
- Slow API responses
- Pool usage > 90%

**Solutions:**

1. Increase `DB_POOL_MAX` (if database can handle it)
2. Optimize slow queries
3. Check for connection leaks (unreleased clients)
4. Review application code for long-running transactions

### Health Check Failures

**Symptoms:**

- Health check endpoint returns 503
- Logs show connection errors

**Solutions:**

1. Verify database is running
2. Check database credentials
3. Verify network connectivity
4. Check database server logs
5. Verify SSL configuration

### High Error Count

**Symptoms:**

- Increasing error count in metrics
- Frequent pool errors in logs

**Solutions:**

1. Check database server health
2. Review database server logs
3. Verify connection limits on database server
4. Check for network issues
5. Review application code for errors

## Monitoring Integration

### Grafana Metrics

**Verified against code:** `services/api-backend/middleware/admin-metrics.js:236-265` defines exactly three pool gauges, all with the `admin_db_pool_` prefix. They are exported by `GET /api/admin-metrics/metrics` (`services/api-backend/routes/admin-metrics.js:40`, mounted at `services/api-backend/server.js:327`):

- `admin_db_pool_size` - Pool size
- `admin_db_pool_idle_connections` - Idle connections
- `admin_db_pool_waiting_requests` - Requests waiting for a connection

The old `db_pool_*` names are **not emitted by any current code (planned only)**: `db_pool_active_connections`, `db_pool_idle_connections`, `db_pool_waiting_clients`, `db_pool_errors`, `db_pool_health_check_response_time`, `db_pool_usage_percentage`. There is no gauge for error count, health-check latency or usage percentage in `admin-metrics.js`.

### Alert Rules

Set up alerts for:

- Health check failures (critical)
- Pool usage > 90% (warning)
- Waiting clients > 0 for > 1 minute (warning)
- Error count increase > 10/minute (critical)

## References

- [node-postgres Documentation](https://node-postgres.com/)
- [PostgreSQL Connection Pooling](https://www.postgresql.org/docs/current/runtime-config-connection.html)
- Admin Center Requirements
- Task 27 Completion Summary
