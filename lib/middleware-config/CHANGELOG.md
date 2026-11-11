# Changelog - @pistisai/middleware-config

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-10

### Added
- Initial unified middleware configuration module
- **Auth Module**: JWT validation, admin auth, API key auth, infrastructure auth
- **Security Module**: CORS configuration, RBAC, rate limiting, Helmet security headers
- **Logging Module**: Request logging, metrics collection, audit logging
- **Validation Module**: Request validation, schema validation, API versioning
- **Operational Module**: Graceful shutdown, request timeout, request queuing, health checks
- **Pipeline Module**: Main orchestration function for setting up middleware

### Changed
- Consolidated middleware from `services/api-backend/middleware/` into shared module
- Consolidated middleware from `services/streaming-proxy/src/middleware/` into shared module

### Migration Path
- **API Backend**: Use `lib/middleware-config/pipeline` instead of local `setupMiddlewarePipeline()`
- **Streaming Proxy**: Use `lib/middleware-config/auth` and `lib/middleware-config/security` instead of local middleware

### Breaking Changes
- None. This is an additive consolidation with backward compatibility wrapper support.
