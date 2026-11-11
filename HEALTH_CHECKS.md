# Health Check Endpoints Documentation

This document describes the standardized health check endpoints implemented across all PistisAI backend services. These endpoints follow Kubernetes-style health check conventions with separate **liveness** and **readiness** probes.

## Overview

Health checks are critical for monitoring and orchestration systems to:
- **Liveness probes** (`/health`): Detect if a service is still running and not in a broken state
- **Readiness probes** (`/ready`): Determine if a service is ready to accept new requests

## HTTP Status Codes

- **200 OK**: Service is healthy/ready
- **503 Service Unavailable**: Service is unhealthy/not ready
- **Content-Type**: Always `application/json`

## Global Health Check Endpoints

All services implement the following standardized endpoints:

### `GET /health` (Liveness Probe)

Indicates whether the service is still running. A 200 response means the service can be kept alive; a 503 response indicates the service needs to be restarted.

**Response (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2026-11-10T20:30:00.000Z",
  "uptime": 3600.5,
  "service": "pistisai-api"  // service-specific
}
```

**Response (503 Service Unavailable):**
```json
{
  "status": "unhealthy",
  "timestamp": "2026-11-10T20:30:00.000Z",
  "error": "Database connection failed",
  "message": "Connection timeout"
}
```

### `GET /ready` (Readiness Probe)

Indicates whether the service is ready to handle new requests. A 200 response means traffic can be routed to this service; a 503 response means traffic should be held until initialization completes.

**Response (200 OK):**
```json
{
  "status": "ready",
  "timestamp": "2026-11-10T20:30:00.000Z",
  "message": "Service is ready to handle requests",
  "uptime": 3600.5
}
```

**Response (503 Service Unavailable):**
```json
{
  "status": "not_ready",
  "timestamp": "2026-11-10T20:30:00.000Z",
  "message": "Service is still initializing"
}
```

## Service-Specific Implementations

### 1. API Backend (`services/api-backend`)

**Endpoints:**
- `GET /health` - Full health status with database and cache checks
- `GET /healthz` - Simple liveness check (returns OK)
- `GET /ready` - Readiness check during initialization

**Health Status Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-11-10T20:30:00.000Z",
  "service": "pistisai-api",
  "uptime": 3600.5,
  "dependencies": {
    "database": {
      "status": "healthy",
      "message": "Database is healthy"
    },
    "cache": {
      "status": "healthy",
      "message": "Cache is healthy"
    },
    "services": {}
  }
}
```

**Notes:**
- Database and cache health are checked on `/health` endpoint
- `/ready` checks the `isInitializing` flag set during server startup
- Returns `503` if initializing, otherwise `200`

### 2. Streaming Proxy (`services/streaming-proxy`)

**Endpoints:**
- `GET /health` - Basic liveness check with tunnel configuration status
- `GET /ready` - Readiness check with tunnel connectivity verification

**Health Response:**
```json
{
  "status": "healthy",
  "userId": "user-123",
  "proxyId": "proxy-456",
  "tunnelConfigured": true,
  "uptime": 3600.5,
  "timestamp": "2026-11-10T20:30:00.000Z"
}
```

**Readiness Response:**
```json
{
  "status": "ready",
  "message": "Service is ready to handle requests",
  "tunnelConnected": true,
  "uptime": 3600.5,
  "timestamp": "2026-11-10T20:30:00.000Z"
}
```

**Notes:**
- `/health` always returns 200 if service is running
- `/ready` checks:
  - HTTP client is initialized (`httpClient` exists)
  - OLLAMA_BASE_URL is configured
  - Tunnel connectivity test passes
- Returns `503` if any check fails

### 3. Tailscale Relay (`services/tailscale-relay`)

**Endpoints:**
- `GET /health` - Liveness check with active connection count
- `GET /ready` - Readiness check

**Health Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-11-10T20:30:00.000Z",
  "uptime": 3600.5,
  "activeConnections": 2
}
```

**Readiness Response:**
```json
{
  "status": "ready",
  "message": "Service is ready to accept connections",
  "timestamp": "2026-11-10T20:30:00.000Z",
  "uptime": 3600.5,
  "activeConnections": 2
}
```

**Notes:**
- Tracks `activeConnections` via WebSocket connection tracking
- `isReady` flag set after server listener starts
- Returns `503` during initialization phase
- Connection counting is decremented on `close` and `error` events

## Shared Health Check Module

A reusable `HealthCheckFactory` class is available at `shared/health-checks/health-check-factory.js` for implementing standardized health checks in other services.

### Usage Example

```javascript
import { HealthCheckFactory } from '../../shared/health-checks/health-check-factory.js';

const healthCheck = new HealthCheckFactory(logger);

// Register dependencies
healthCheck.registerDatabase(dbConnection);
healthCheck.registerCache(cacheClient);

// Add custom checks
healthCheck.registerReadinessCheck('migrations', async () => ({
  status: 'ready',
  message: 'All migrations completed'
}));

// Mark service as ready
healthCheck.markReady();

// Use in Express
app.get('/health', healthCheck.createLivenessMiddleware());
app.get('/ready', healthCheck.createReadinessMiddleware());

// Or get full health status
const status = await healthCheck.getHealthStatus('my-service');
```

## Kubernetes Deployment Configuration

Example `deployment.yaml` with health checks:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pistisai-api
spec:
  template:
    spec:
      containers:
      - name: api-backend
        image: pistisai/api-backend:latest
        ports:
        - containerPort: 3000
        
        # Liveness probe: restart if unhealthy
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        # Readiness probe: remove from load balancer if not ready
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 15
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 2
```

## Testing Health Checks

### Test Liveness Probe
```bash
curl -v http://localhost:3000/health
```

### Test Readiness Probe
```bash
curl -v http://localhost:3000/ready
```

### Check Status Codes
```bash
# Should return 200
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/health

# Should return 503 during initialization
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/ready
```

## Integration with Monitoring Systems

These endpoints integrate with:
- **Kubernetes**: livenessProbe and readinessProbe
- **Docker Compose**: healthcheck directive
- **Prometheus**: Scrape endpoints for monitoring
- **Load Balancers**: Health check backends
- **Observability Tools**: Uptime monitoring

## Acceptance Criteria Met

✅ Health check endpoints working (`/health` implemented on all services)
✅ Readiness checks pass (`/ready` implemented on all services)
✅ Liveness checks working (`/health` with comprehensive checks on api-backend)
✅ Standardized response format with status codes and JSON payloads
✅ Service-specific implementations with appropriate checks
✅ Reusable `HealthCheckFactory` for future services
