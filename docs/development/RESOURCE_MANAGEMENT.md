# Resource Management Guide

This document defines the resource management strategy for the Pistisai API Backend.

## Resource Categories

### 1. Network Connections

**Managed by**: the Postgres `pg` pool in `services/api-backend/database/db-pool.js` (see `getPool`, `getPoolMetrics`, `healthCheck` at `db-pool.js:688,714`)

> **Verified against code (2026-11-24):** `undici` is not a declared dependency in `services/api-backend/package.json` or the root `package.json`. The `undici` `Pool` example below is an **aspirational pattern**, not a live API in this repo.

**Capabilities**:

- Connection pooling with configurable pool size
- HTTP/1.1 keep-alive connections
- Request pipelining
- Fine-grained control over HTTP requests

**Usage Example**:

```javascript
import { Pool, request } from 'undici';

// Create a connection pool
const pool = new Pool('https://api.example.com', {
  connections: 100,
  keepAliveTimeout: 60000,
  bodyTimeout: 30000,
});

// Make a request
const { body } = await pool.request({
  method: 'GET',
  path: '/api/resource',
});
```

**Environment Variables** (planned — neither variable is read anywhere in this repo):

- `UNDICI_POOL_SIZE`: Maximum connections in pool (default: 100)
- `UNDICI_KEEP_ALIVE_TIMEOUT`: Keep-alive timeout in ms (default: 60000)

### 2. System Metrics

**Managed by**: `systeminformation`-based metrics are **planned** — `systeminformation` is not a declared dependency. Current pool health metrics come from `services/api-backend/database/db-pool.js` (`getPoolMetrics`, `db-pool.js:688`).

**Capabilities**:

- CPU usage and load averages
- Memory usage (heap, RSS, free memory)
- Disk usage and I/O statistics
- Network interface statistics
- Process information

**Usage Example**:

```javascript
import si from 'systeminformation';

// Get CPU metrics
const cpu = await si.cpu();

// Get memory metrics
const mem = await si.mem();

// Get disk usage
const disk = await si.fsSize();

// Get network statistics
const net = await si.networkStats();

// Get process info
const processInfo = await si.processLoad();
```

**Available Metrics**:

- `si.cpu()` - CPU cores, speed, model
- `si.cpuLoad()` - Current CPU load
- `si.mem()` - Memory usage
- `si.memLayout()` - Memory layout
- `si.fsSize()` - File system sizes
- `si.fsStats()` - File system I/O stats
- `si.networkInterfaces()` - Network interfaces
- `si.networkStats()` - Network I/O statistics
- `si.processLoad()` - Current process load
- `si.dockerContainers()` - Docker container stats

### 3. File Operations

**Managed by**: `fs-extra` (enhanced file system utilities)

**Capabilities**:

- Promise-based file operations
- Directory creation with `recursive: true`
- File copying and moving with metadata
- JSON file reading/writing with formatting
- Error handling for common file issues

**Usage Example**:

```javascript
import fs from 'fs-extra';

// Ensure directory exists
await fs.ensureDir('/path/to/directory');

// Write JSON with formatting
await fs.writeJson('/path/to/file.json', data, { spaces: 2 });

// Read JSON
const data = await fs.readJson('/path/to/file.json');

// Copy with metadata
await fs.copy('/src/file', '/dest/file', {
  preserveTimestamps: true,
});

// Remove safely
await fs.remove('/path/to/file');
```

### 4. Configuration Validation

**Managed by**: `zod` (schema validation)

**Capabilities**:

- Type-safe schema definition
- Runtime validation
- Type inference
- Custom validation rules
- Error messages

**Usage Example**:

```javascript
import { z } from 'zod';

// Define schema
const configSchema = z.object({
  host: z.string().ip(),
  port: z.number().min(1).max(65535),
  maxConnections: z.number().min(1).max(10000),
  timeout: z.number().min(1000).max(300000),
  ssl: z.boolean().optional(),
});

// Validate
const result = configSchema.safeParse({
  host: '192.168.1.1',
  port: 8080,
  maxConnections: 100,
  timeout: 30000,
  ssl: true,
});

if (!result.success) {
  console.error('Validation failed:', result.error.errors);
}
```

## Integration with Existing Code

### Database Pool Monitoring (Existing)

The existing `services/api-backend/database/pool-monitor.js` is live: it imports `getPool`, `getPoolMetrics` and `healthCheck` from `db-pool.js` and `sendAlert` from `../services/alerting-service.js`, with a 30 s health-check interval, a 0.9 exhaustion threshold and 60 s metrics logging (`pool-monitor.js:11-27`). It does **not** import `systeminformation`; the enhancement sketch below is proposed code, not current behavior.

```javascript
import si from 'systeminformation';

export async function getEnhancedMetrics() {
  const [cpu, mem, disk] = await Promise.all([
    si.cpuLoad(),
    si.mem(),
    si.fsSize(),
  ]);

  return {
    cpu: {
      load: cpu.currentLoad,
      cores: cpu.cores,
    },
    memory: {
      total: mem.total,
      used: mem.used,
      free: mem.free,
      usagePercent: (mem.used / mem.total) * 100,
    },
    disk: {
      total: disk[0]?.size,
      used: disk[0]?.used,
      usagePercent: disk[0]?.use,
    },
  };
}
```

### HTTP Requests (Migrating from node-fetch)

Replace `node-fetch` with `undici`:

```javascript
// Before (using node-fetch)
import fetch from 'node-fetch';
const response = await fetch(url);
const data = await response.json();

// After (using undici)
import { request } from 'undici';
const { body } = await request(url, { method: 'GET' });
const data = await body.json();
```

## Best Practices

1. **Connection Pooling**: Always use connection pools for HTTP clients
2. **Resource Cleanup**: Use `try-finally` or cleanup handlers
3. **Monitoring**: Regularly check system metrics for resource exhaustion
4. **Validation**: Validate all configuration before application startup
5. **Error Handling**: Handle file system errors gracefully
6. **Logging**: Log resource-related events for debugging

## Performance Considerations

1. **Undici**: Use `maxConnections` appropriately (default: 100)
2. **Systeminformation**: Cache metrics when possible (refresh every 5-10s)
3. **fs-extra**: Use streaming for large file operations
4. **Zod**: Compile schemas for better performance

## Environment Variables Reference

| Variable | Description | Default |
|----------|-------------|---------|
| `UNDICI_POOL_SIZE` | Maximum HTTP connections | 100 |
| `UNDICI_KEEP_ALIVE_TIMEOUT` | Keep-alive timeout (ms) | 60000 |
| `METRICS_REFRESH_INTERVAL` | System metrics refresh (ms) | 10000 |
| `LOG_LEVEL` | Logging verbosity | info |

## Related Documentation

- Database Connection Pool
- Pool Monitoring
- Graceful Shutdown
