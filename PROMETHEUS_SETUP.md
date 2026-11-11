# Prometheus Metrics Exporter - Setup & Testing Guide

## Overview

This guide provides instructions for setting up, testing, and using the Prometheus metrics exporter for PistisAI backend services. The system integrates health monitoring, latency tracking, error rates, and throughput metrics with comprehensive Grafana dashboards.

## Quick Start

### 1. Start Monitoring Stack

```bash
cd /home/rightguy/pistisai-app

# Start Prometheus and Grafana
docker-compose -f config/docker/docker-compose.prometheus.yml up -d

# Verify services are running
docker-compose -f config/docker/docker-compose.prometheus.yml ps
```

### 2. Access Services

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (default credentials: admin/admin)
- **API Backend**: http://api-backend:8080/prometheus/metrics

### 3. Test Metrics Collection

```bash
# Test API Backend metrics endpoint
curl http://localhost:8080/prometheus/metrics

# Test health check
curl http://localhost:8080/prometheus/health/metrics

# View Prometheus targets
curl http://localhost:9090/api/v1/targets
```

## Integration Details

### Services Being Monitored

#### 1. API Backend Service
- **Location**: `/services/api-backend`
- **Metrics Endpoint**: `/prometheus/metrics`
- **Health Endpoint**: `/prometheus/health/metrics`
- **Port**: 8080

**Metrics Exported**:
- HTTP request throughput (requests/sec)
- HTTP request latency (p50, p95, p99)
- HTTP error rates
- Database query metrics
- Connection pool statistics
- Authentication metrics
- Rate limiting metrics
- System metrics

**Implementation**:
- Middleware: `middleware/metrics-collection.js` (automatically collects all HTTP metrics)
- Service: `services/metrics-service.js` (manages Prometheus metrics registry)
- Routes: `routes/prometheus-metrics.js` (exposes `/metrics` endpoint)

#### 2. Streaming Proxy Service
- **Location**: `/services/streaming-proxy`
- **Metrics Endpoint**: `/metrics`
- **Port**: 3001

**Metrics Exported**:
- Tunnel request statistics
- Tunnel latency
- Connection metrics
- Error tracking

**Implementation**:
- Source: `src/monitoring/prometheus-metrics.ts`

### Grafana Dashboard

**Name**: Backend Health & Performance Monitoring
**File**: `config/grafana/dashboards/backend-health-performance.json`
**Auto-Import**: Yes (via provisioning)

**Key Panels**:
1. API Request Throughput
2. API Request Latency (p95, p99)
3. API Error Rate
4. Active Tunnel Connections
5. Active Proxy Instances
6. Database Query Latency
7. Database Query Throughput
8. Database Connection Pool Availability
9. Database Query Errors
10. Active User Sessions
11. Rate Limit Violations
12. Active Users
13. API Uptime

### Alert Rules

**File**: `docker/prometheus/alerts.yml`

**Configured Alerts**:
- HighHTTPErrorRate (> 1% errors)
- HighRequestLatency (p95 > 1s)
- SlowDatabaseQueries (avg latency > 50ms)
- LowDatabaseConnectionPool (< 20% available)
- HighDatabaseErrorRate
- NoActiveTunnelConnections
- HighRateLimitViolations
- ServiceDown
- LowAPIUptime (< 99.5%)
- SlowQueryDetected (p99 > 1s)
- HighMemoryUsage (> 80%)
- HighCPUUsage (> 80%)
- HighAuthFailureRate

## Testing

### Test Prometheus Endpoints

```bash
cd /home/rightguy/pistisai-app/services/api-backend

# Run endpoint test
node scripts/test-prometheus-endpoints.js
```

Expected output:
```
🔍 Prometheus Metrics Endpoint Test

════════════════════════════════════════════════════════════════════════════════

📊 Testing: API Backend
────────────────────────────────────────────────────────────────────────────────

📈 Metrics Endpoint: http://api-backend:8080/prometheus/metrics
✅ Status: 200
📊 Metrics Found: 1523
📝 Content-Type: text/plain; version=0.0.4; charset=utf-8

📋 Sample Metrics:
   1. http_requests_total{method="GET",route="/api/users",status="200"} 42
   2. http_request_duration_seconds_bucket{method="GET",route="/api/users",status="200",le="0.01"} 5
   ...

💚 Health Endpoint: http://api-backend:8080/prometheus/health/metrics
✅ Status: 200
📊 Health Check OK

════════════════════════════════════════════════════════════════════════════════

📊 Test Summary: 2/2 passed
✅ All tests passed! Prometheus metrics are being collected.
```

### Query Prometheus Directly

```bash
# Get request throughput
curl 'http://localhost:9090/api/v1/query?query=rate(http_requests_total[5m])'

# Get p95 latency
curl 'http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,rate(http_request_duration_seconds_bucket[5m]))'

# Get error rate
curl 'http://localhost:9090/api/v1/query?query=rate(http_request_errors_total[5m])'
```

### Manual Testing

```bash
# Test with curl
curl -H "Accept: text/plain" http://api-backend:8080/prometheus/metrics | head -50

# Filter specific metrics
curl http://api-backend:8080/prometheus/metrics | grep "http_requests_total"

# Health check
curl http://api-backend:8080/prometheus/health/metrics | jq .
```

## Configuration Files

### Prometheus Configuration
**File**: `docker/prometheus/prometheus.yml`

- Global scrape interval: 15 seconds
- Storage retention: 30 days
- Scrape jobs:
  - api-backend: `/prometheus/metrics`
  - streaming-proxy: `/metrics`
  - traefik: `/metrics`

### Grafana Provisioning
**Files**:
- Datasources: `docker/grafana/datasources/prometheus.yml`
- Dashboards: `docker/grafana/dashboards/`
- Dashboard provisioning: `docker/grafana/dashboards/dashboard.yml`

### Docker Compose
**File**: `config/docker/docker-compose.prometheus.yml`

Services:
- Prometheus (port 9090)
- Grafana (port 3000)

## Accessing Grafana Dashboard

### Step 1: Login
- URL: http://localhost:3000
- Username: admin
- Password: admin

### Step 2: Navigate to Dashboard
- Dashboards → Browse
- Select "Backend Health & Performance Monitoring"

### Step 3: Monitor Metrics
- Panels auto-refresh every 30 seconds
- Hover over panels for detailed values
- Click panels for detailed view

## Troubleshooting

### No Metrics Appearing

1. **Verify service is running**:
   ```bash
   docker ps | grep api-backend
   curl http://localhost:8080/prometheus/health/metrics
   ```

2. **Check Prometheus targets**:
   - Open: http://localhost:9090/targets
   - Look for failed scrapes

3. **Review service logs**:
   ```bash
   docker logs pistisai_api-backend | grep -i metrics
   ```

### Grafana Can't Find Data

1. **Verify datasource**:
   - Configuration → Data sources
   - Check "Prometheus" is configured
   - Test connection

2. **Check Prometheus retention**:
   ```bash
   curl http://localhost:9090/api/v1/query?query=time()
   ```

### High Scrape Failures

1. **Verify network connectivity**:
   ```bash
   docker network ls
   docker inspect pistisai-network
   ```

2. **Check service URLs**:
   ```bash
   docker exec pistisai_prometheus curl http://api-backend:8080/prometheus/metrics
   ```

## Performance Baselines

These baselines are targets for healthy system operation:

| Metric | p50 | p95 | p99 | Target |
|--------|-----|-----|-----|--------|
| HTTP Request Latency | < 50ms | < 500ms | < 1s | < 100ms |
| Database Query Latency | < 5ms | < 50ms | < 100ms | < 10ms |
| HTTP Error Rate | 0% | < 0.5% | < 1% | < 0.1% |
| Connection Pool Util. | < 50% | < 80% | < 95% | < 60% |
| API Uptime | 99.99% | 99.95% | 99.9% | > 99.9% |

## Advanced Queries

### Calculate Error Rate Percentage
```promql
(sum(rate(http_request_errors_total[5m])) / sum(rate(http_requests_total[5m]))) * 100
```

### Database Connection Pool Utilization
```promql
((db_connection_pool_size - db_connection_pool_available) / db_connection_pool_size) * 100
```

### Request Success Rate
```promql
(sum(rate(http_requests_total{status=~"2.."}[5m])) / sum(rate(http_requests_total[5m]))) * 100
```

### Average Response Time by Endpoint
```promql
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
```

### Peak Traffic Time
```promql
topk(5, rate(http_requests_total[5m]))
```

## Exporting Metrics

### Export to File
```bash
curl http://localhost:9090/api/v1/query?query=http_requests_total \
  | jq . > metrics.json
```

### Export Dashboard JSON
Via Grafana UI:
- Dashboard settings (gear icon)
- Export
- Download JSON

## Security Considerations

### Current Setup
- ⚠️ Prometheus: No authentication (localhost only)
- ⚠️ Grafana: Default credentials (change admin password)
- ⚠️ Metrics endpoints: No authentication

### Production Recommendations
1. Put Prometheus behind reverse proxy with authentication
2. Restrict Grafana access (HTTPS, strong auth)
3. Add authentication to metrics endpoints
4. Use network policies to restrict access
5. Enable HTTPS for all connections
6. Rotate default Grafana credentials

## Maintenance

### Regular Tasks
- Monitor disk usage (metrics retention)
- Review alert firing frequency
- Update alert thresholds based on SLOs
- Archive old metrics (if needed)

### Disk Usage Management
```bash
# Prometheus data size
du -sh ./prometheus-storage

# Reduce retention (if needed)
# Edit: docker/prometheus/prometheus.yml
# storage.tsdb.retention.time=30d → 14d
```

### Backups
```bash
# Backup Prometheus data
docker exec pistisai_prometheus tar -czf /prometheus/backup.tar.gz /prometheus

# Backup Grafana dashboards
docker exec pistisai_grafana grafana-cli admin export-dashboard backup.json
```

## Related Documentation

- [Prometheus Official Docs](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [prom-client Library](https://github.com/siimon/prom-client)
- [PromQL Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Alert Rules](./docker/prometheus/alerts.yml)
- [Monitoring Guide](./docs/operations/backend/prometheus-monitoring.md)

## Support

For issues or questions:
1. Check the [Prometheus Documentation](https://prometheus.io/docs/)
2. Review [Alert Rules](./docker/prometheus/alerts.yml)
3. Check service logs: `docker logs pistisai_api-backend`
4. Verify network connectivity: `docker network inspect pistisai-network`
5. Open an issue referencing GitHub #470

## References

- Issue: #470 - Add Prometheus metrics exporter for backend health & performance monitoring
- Implementation Date: 2026-11-10
- Version: 1.0
