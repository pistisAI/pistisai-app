# Self-Hosting Guide

This guide explains how to deploy Pistisai for self-hosted, privacy-first operation.

## Overview

Pistisai is designed to run primarily on local devices with optional cloud/SaaS features. Self-hosting allows you to run backend services on your own infrastructure while maintaining control over your data.

Current orientation is agent-runtime-first and Tailscale-first. The setup wizard selects an agent runtime such as Hermes, OpenClaw, a compatible custom agent gateway, or an optional hosted agent runtime. Ollama, LM Studio, and similar model servers are optional support model providers for app-owned memory/background features, not primary app runtimes. Remote agent runtimes and cloud connectors should live inside the user's Tailscale tailnet where possible.

## Prerequisites

- Docker and Docker Compose
- Node.js >=26.0.0 <28.0.0 (for backend development; `.nvmrc` is 26)
- Flutter SDK >=3.5.0 <4.0.0 (for frontend development; shared package needs Dart >=3.9.0)
- PostgreSQL >=14
- Redis >=7
- Git

## Architecture Overview

When self-hosted, Pistisai consists of:

1. **Frontend**: Flutter application (runs locally on user's device)
2. **Backend Services** (optional, for cloud features):
   - API Backend (Express 5, PostgreSQL)
   - Tailscale Relay and cloud connector support for secure device mesh
   - Streaming Proxy (legacy/fallback WebSocket proxy for tunnel-heavy paths)
   - Auth Backend (JWT validation)
   - SDK (TypeScript service SDK)

## Deployment Options

### Option 1: Local-First Only (Recommended for Privacy)

Run only the Flutter frontend with local SQLite storage. No backend services required.

```bash
# Get the code
git clone https://github.com/pistisAI/pistisai-app.git
cd pistisai-app

# Install Flutter dependencies (app + shared package)
flutter pub get
cd lib/shared && flutter pub get && cd ../..

# Run the app (local-first mode)
flutter run -d linux  # or windows, macos, chrome
```

In this mode:
- All data stored locally via encrypted SQLite (Drift)
- No external dependencies
- Full functionality for the selected local agent runtime where its capabilities are available
- Optional features requiring backend services are disabled

### Option 2: Full Self-Hosted Stack

Run both frontend and backend services on your infrastructure.

#### Step 1: Configure Environment

```bash
cp .env.example .env
# Edit .env with your configuration:
# - Database connection strings
# - Redis configuration
# - JWT secrets
# - API keys for external LLM providers (optional)
# - Tailscale configuration for secure device mesh
```

#### Step 2: Start Infrastructure Services

```bash
# Start PostgreSQL and Redis (compose service names)
docker compose up -d database redis

# Validate database connectivity / schema helpers from api-backend
# (there is no npm run db:migrate — see AGENTS.md)
cd services/api-backend && npm install && npm run db:validate && cd ../..
```

#### Step 3: Start Backend Services

```bash
# Root docker-compose.yml services include api-backend + tailscale-relay
# (not streaming-proxy or auth-backend — those run from their own directories when needed)
docker compose up -d api-backend tailscale-relay

# Optional legacy/fallback streaming proxy (separate service folder):
# cd services/streaming-proxy && npm install && npm run dev

# Optional auth backend (CommonJS; no npm run dev):
# cd backend/auth && npm install && node handlers.js
```

#### Step 4: Build and Configure Frontend

```bash
# Get Flutter dependencies
flutter pub get
cd lib/shared && flutter pub get && cd ../..

# Point the app at your self-hosted API (see lib/config/app_config.dart)

# Run the app
flutter run -d linux  # or your target platform
```

#### Step 5: Production Build

```bash
# Build frontend for production
flutter build linux --release  # or windows, macos, web
# For web builds matching CI:
# flutter build web --release --no-web-resources-cdn

# Restart / redeploy api-backend after Node changes (no npm run build script)
cd services/api-backend
npm start
```

## Configuration

### Environment Variables

Key environment variables in `.env`:

```
# Database
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=pistisai
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=pistisai

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# JWT
JWT_ACCESS_TOKEN_SECRET=your_access_token_secret
JWT_REFRESH_TOKEN_SECRET=your_refresh_token_secret

# API
API_PORT=8080
STREAMING_PROXY_PORT=3001

# External LLM Providers (optional)
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key
# Add others as needed

# Tailscale (optional)
TAILSCALE_AUTHKEY=your_tailscale_authkey
```

### Flutter Configuration

Update endpoint constants in `lib/config/app_config.dart` (for example `apiBaseUrl`
and related admin/router URLs) so the Flutter app targets your self-hosted services.
Default local ports: API backend `8080`, embedded router `1337`, streaming proxy
`3001` (when used), auth backend `3000`, Tailscale relay `3002`.

## Security Considerations

1. **Network Security**:
   - Use firewalls to restrict access to backend services
   - Consider using a reverse proxy (NGINX, Traefik) with SSL termination
   - Enable CORS restrictions on API endpoints

2. **Data Protection**:
   - Enable full-disk encryption on your server
   - Regularly backup PostgreSQL database
   - Use strong, unique passwords for all services
   - Consider enabling PostgreSQL column-level encryption for sensitive data

3. **Updates**:
   - Regularly update Docker images and dependencies
   - Monitor security advisories for used technologies
   - Keep Flutter and Node.js versions current

## Maintenance

### Backups

```bash
# Backup PostgreSQL database
pg_dump -h localhost -U pistisai pistisai > backup.sql

# Backup Redis (optional, mainly for caching)
redis-cli BGSAVE
```

### Logs

Backend services log to stdout/stderr, captured by Docker Compose:

```bash
# View logs
docker compose logs -f api-backend
docker compose logs -f tailscale-relay
```

### Updates

```bash
# Pull latest code
git pull origin main

# Update Flutter dependencies
flutter pub get

# Update Node.js dependencies
npm ci  # in each service directory

# Validate database helpers from api-backend
cd services/api-backend && npm run db:validate && cd ../..

# Restart services
docker compose restart
```

## Troubleshooting

### Common Issues

1. **Database Connection Failures**:
   - Verify PostgreSQL is running: `docker compose ps database`
   - Check `.env` database credentials
   - Validate from api-backend: `cd services/api-backend && npm run db:validate`

2. **Service Startup Failures**:
   - Check logs: `docker compose logs <service-name>`
   - Verify required environment variables are set
   - Check port conflicts (8080 for API, 3001 for streaming proxy when used)

3. **Frontend Cannot Connect to Backend**:
   - Verify `lib/config/app_config.dart` points to correct URLs
   - Check network connectivity between frontend and backend devices
   - Ensure backend services are exposed on the correct network interface

## Getting Help

- Check the [Troubleshooting Guide](../user-guide/TROUBLESHOOTING.md)
- Review existing tests in `test/api-backend/` for service behavior
- Consult the [API Reference](../development/API_DOCUMENTATION.md)
- Join community forums for self-hosting discussions

## Support

This is community-supported software. For enterprise support options, please refer to the project's funding and sponsorship page.
