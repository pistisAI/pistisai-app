# ADR 003: Monitoring Strategy

## Status

Accepted

## Context

Assessment of whether Grafana is required for Pistisai operations.

## Decision

Adopt a hybrid monitoring approach:

1. **Sentry**: For error tracking and exception management.
2. **Prometheus (self-hosted)**: For metrics collection and time-series data.
3. **Grafana (self-hosted)**: For visualization and alerting.

As deployed today, `docker-compose.prod.yml` runs `prom/prometheus:latest` (lines 178-187) and `grafana/grafana:latest` (lines 207-215) behind Traefik at `prometheus.pistisai.app` / `grafana.pistisai.app` (lines 201-204, 228-231). This is **not** Grafana Cloud SaaS; the earlier SaaS wording in this ADR was stale.

## Consequences

- **Positive**: Maintains provider-agnostic portability (no Azure Monitor lock-in).
- **Positive**: Metrics and dashboards stay under the operator's control in the production compose stack.
- **Negative**: Metrics retention is local — Prometheus uses the `prometheus-data` volume (`docker-compose.prod.yml:187,245`) and Grafana uses `grafana-data` (lines 213,246); the operator owns retention and storage.
- **Negative**: Requires Prometheus to be running alongside the stack.
