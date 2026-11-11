# Prometheus Metrics & Monitoring Setup

## Overview

This document describes the Prometheus metrics exporter integration for PistisAI backend services. The system exports health metrics, latency measurements, error rates, and throughput data for comprehensive monitoring and alerting.

## Architecture

### Metrics Collection Pipeline

1. **Application Level**: Services emit metrics via `prom-client` library
2. **Metrics Endpoints**: Each service exposes `/metrics` endpoint at Prometheus-compatible format
3. **Prometheus Scraper**: Centralized Prometheus instance scrapes metrics from all services
4. **Grafana Dashboard**: Visualizes metrics for monitoring and alerting

### Monitored Services

#### 1. API Backend (`/services/api-backend`)
- **Endpoint**: `http://api-backend:8080/prometheus/metrics`
- **Health Endpoint**: `http://api-backend:8080/prometheus/health/metrics`
- **Scrape Interval**: 15 seconds (configurable in `docker/prometheus/prometheus.yml`)

#### 2. Streaming Proxy (`/services/streaming-proxy`)
- **Endpoint**: `http://streaming-proxy:3001/metrics`
- **Scrape Interval**: 15 seconds

#### 3. Database Health Checks
- **Endpoint**: `http://api-backend:8080/db/health`
- **Type**: JSON health status (supplementary to Prometheus metrics)

## Available Metrics

### HTTP Request Metrics (API Backend)

**Namespace**: `http_*`

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `http_requests_total` | Counter | method, route, status | Total HTTP requests received |
| `http_request_duration_seconds` | Histogram | method, route, status | Request latency in seconds (p50, p95, p99) |
| `http_request_errors_total` | Counter | method, route, error_type | Total HTTP request errors |

**Buckets**: 0.01s, 0.05s, 0.1s, 0.5s, 1s, 2s, 5s

**Example Queries**:
```promql
# Request throughput (requests/sec)
rate(http_requests_total[5m])

# p95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate
rate(http_request_errors_total[5m])
```

### Connection Metrics

**Namespace**: `tunnel_*`, `proxy_*`

| Metric | Type | Description |
|--------|------|-------------|
| `tunnel_connections_active` | Gauge | Currently active tunnel connections |
| `tunnel_connections_total` | Counter | Total tunnel connections created (lifetime) |
| `tunnel_request_latency_ms` | Histogram | Tunnel request latency in milliseconds |
| `tunnel_active_connections` | Gauge (Streaming) | Active connections by user tier |
| `proxy_instances_active` | Gauge | Currently active proxy instances |
| `proxy_instances_total` | Counter | Total proxy instances created (lifetime) |

### Database Metrics

**Namespace**: `db_*`

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `db_connection_pool_size` | Gauge | pool_type | Total connection pool size |
| `db_connection_pool_available` | Gauge | pool_type | Available connections in pool |
| `db_query_duration_seconds` | Histogram | query_type | Query latency in seconds |
| `db_queries_total` | Counter | query_type | Total queries executed |
| `db_query_errors_total` | Counter | query_type, error_type | Database query errors |

**Buckets**: 0.001s, 0.005s, 0.01s, 0.05s, 0.1s, 0.5s, 1s

**Example Queries**:
```promql
# Average query latency
rate(db_query_duration_seconds_sum[5m]) / rate(db_query_duration_seconds_count[5m])

# Query throughput
rate(db_queries_total[5m])

# Connection pool utilization
(db_connection_pool_size - db_connection_pool_available) / db_connection_pool_size * 100
```

### Authentication Metrics

**Namespace**: `auth_*`

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `auth_attempts_total` | Counter | auth_type, result | Total authentication attempts |
| `active_sessions` | Gauge | | Current active user sessions |

### Rate Limiting Metrics

**Namespace**: `rate_limit_*`

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `rate_limit_violations_total` | Counter | violation_type, user_tier | Rate limit violations |
| `rate_limited_users_active` | Gauge | | Currently rate limited users |

### System Metrics

**Namespace**: `api_*`, `system_*`

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `api_uptime_seconds` | Gauge | | API service uptime in seconds |
| `active_users` | Gauge | | Current active users |
| `system_load` | Gauge | load_type (cpu, memory, disk) | System resource load |

## Prometheus Configuration

**File**: `docker/prometheus/prometheus.yml`

### Scrape Jobs

```yaml
scrape_configs:
  # API Backend
  - job_name: 'api-backend'
    static_configs:
      - targets: ['api-backend:8080']
        labels:
          service: 'api-backend'
          component: 'backend'

  # Streaming Proxy
  - job_name: 'streaming-proxy'
    static_configs:
      - targets: ['streaming-proxy:3001']
        labels:
          service: 'streaming-proxy'
          component: 'proxy'

  # Traefik (reverse proxy)
  - job_name: 'traefik'
    static_configs:
      - targets: ['traefik:8080']
        labels:
          service: 'traefik'
          component: 'reverse-proxy'
```

**Scrape Interval**: 15 seconds
**Evaluation Interval**: 15 seconds
**Global Labels**:
- `cluster`: pistisai-prod
- `environment`: production

## Grafana Dashboard

**Dashboard Name**: Backend Health & Performance Monitoring
**File**: `config/grafana/dashboards/backend-health-performance.json`
**UID**: `pistisai-backend-health`

### Panels

1. **API Request Throughput** (requests/sec)
   - Query: `rate(http_requests_total[5m])`
   - Breakdown: By method and route

2. **API Request Latency** (p95, p99)
   - Queries: 
     - `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`
     - `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))`

3. **API Error Rate** (errors/sec)
   - Query: `rate(http_request_errors_total[5m])`
   - Breakdown: By error type

4. **Active Tunnel Connections**
   - Query: `tunnel_connections_active`

5. **Active Proxy Instances**
   - Query: `proxy_instances_active`

6. **Database Query Latency**
   - Query: `rate(db_query_duration_seconds_sum[5m]) / rate(db_query_duration_seconds_count[5m])`
   - Breakdown: By query type

7. **Database Query Throughput** (queries/sec)
   - Query: `rate(db_queries_total[5m])`

8. **Database Connection Pool Availability**
   - Query: `db_connection_pool_available`
   - Shows available connections by pool type

9. **Database Query Errors** (errors/sec)
   - Query: `rate(db_query_errors_total[5m])`

10. **Active User Sessions**
    - Query: `active_sessions`

11. **Rate Limit Violations** (violations/sec)
    - Query: `rate(rate_limit_violations_total[5m])`

12. **Active Users**
    - Query: `active_users`

13. **API Uptime** (seconds)
    - Query: `api_uptime_seconds`

### Dashboard Settings

- **Refresh**: 30 seconds
- **Time Range**: Last 1 hour (default)
- **Time Zone**: Browser local
- **Theme**: Dark

## Health Check Endpoints

### 1. Prometheus Metrics Health

**Endpoint**: `GET /prometheus/health/metrics`

**Response (Healthy)**:
```json
{
  "status": "healthy",
  "message": "Metrics collection is working",
  "metricsSize": 1523,
  "timestamp": "2026-11-10T20:16:00.000Z"
}
```

**Response (Unhealthy)**:
```json
{
  "status": "unhealthy",
  "message": "Metrics collection is not working",
  "timestamp": "2026-11-10T20:16:00.000Z"
}
```

### 2. API Health

**Endpoint**: `GET /health`

**Response (Healthy)**:
```json
{
  "status": "healthy",
  "message": "API is healthy",
  "services": {
    "database": "healthy",
    "auth": "healthy",
    "cache": "healthy"
  },
  "timestamp": "2026-11-10T20:16:00.000Z"
}
```

### 3. Database Health

**Endpoint**: `GET /db/health`

Returns comprehensive database connection pool and query statistics.

### 4. Quick Health Check

**Endpoint**: `GET /healthz`

Lightweight endpoint for basic connectivity checks.

## Integration with Docker Compose

### Starting Monitoring Stack

```bash
# Start all services including Prometheus and Grafana
docker-compose up -d

# Or specific monitoring services
docker-compose -f config/docker/docker-compose.monitoring.yml up -d
```

### Verifying Metrics Collection

```bash
# Check if Prometheus can scrape metrics
curl http://localhost:9090/api/v1/targets

# Query a specific metric
curl 'http://localhost:9090/api/v1/query?query=http_requests_total'

# View metrics endpoint directly
curl http://localhost:8080/prometheus/metrics
```

## Performance Baselines & SLOs

### Expected Performance Targets

**API Response Latency**:
- p50: < 100ms
- p95: < 500ms
- p99: < 1000ms

**Error Rate**:
- Target: < 0.1% (< 1 error per 1000 requests)
- Alert threshold: > 1% of requests

**Database Queries**:
- p95 latency: < 50ms
- Error rate: < 0.01%

**Connection Pool**:
- Target: < 80% utilization
- Alert threshold: > 90% utilization

**Uptime**:
- Target: 99.9% (43.2 seconds downtime per day)
- Alert threshold: < 99.5%

## Troubleshooting

### No Metrics Appearing

1. **Verify metrics endpoint is accessible**:
   ```bash
   curl -v http://api-backend:8080/prometheus/metrics
   ```

2. **Check Prometheus scrape status**:
   - Open Prometheus UI: `http://localhost:9090`
   - Navigate to Status → Targets
   - Look for failed scrape attempts

3. **Check service is running**:
   ```bash
   docker ps | grep api-backend
   ```

### Metrics Not Updating

1. **Verify metrics collection middleware is installed**:
   - Check `middleware/pipeline.js` includes `metricsCollectionMiddleware`
   - Check middleware is registered before routes

2. **Check metrics service is initialized**:
   ```bash
   curl http://api-backend:8080/prometheus/health/metrics
   ```

3. **Review server logs**:
   ```bash
   docker logs pistisai_api-backend
   ```

### High Latency in Metrics

1. **Reduce scrape interval** (if Prometheus can handle it):
   ```yaml
   global:
     scrape_interval: 10s  # Default is 15s
   ```

2. **Check database connection pool**:
   - Monitor: `db_connection_pool_available`
   - Alert if < 20% available

3. **Review slow queries**:
   - Query: `rate(db_query_duration_seconds_sum[5m]) / rate(db_query_duration_seconds_count[5m])`

## Related Documentation

- [Performance Baselines & SLOs](../PERFORMANCE_BASELINES.md)
- [Prometheus Official Docs](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [prom-client Library](https://github.com/siimon/prom-client)

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2026-11-10 | 1.0 | Initial Prometheus metrics integration |

## References

- Issue #470: Add Prometheus metrics exporter for backend health & performance monitoring
- Middleware: `services/api-backend/middleware/metrics-collection.js`
- Service: `services/api-backend/services/metrics-service.js`
- Routes: `services/api-backend/routes/prometheus-metrics.js`
- Streaming Proxy: `services/streaming-proxy/src/monitoring/prometheus-metrics.ts`
