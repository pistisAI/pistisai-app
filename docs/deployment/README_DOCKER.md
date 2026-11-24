# Pistisai Docker Development Environment

> **Current orientation**: Docker development can include optional support model providers for testing memory/background features, but the main app channel still requires an agent runtime such as Hermes, OpenClaw, or a compatible agent gateway. Do not treat Ollama/LM Studio containers as primary app runtimes unless wrapped by a compatible agent runtime.

> **No `docker-compose.dev.yml` and no Flutter dev container exist in this repository.** Development uses a local Flutter SDK pinned in `pubspec.yaml` (`environment.flutter: 3.47.9`, consumed by CI via `flutter-version-file: pubspec.yaml`) plus the repo-root `docker-compose.yml` for backing services. The old `docker-compose.dev.yml`, `flutter` service, `flutter-health`/`flutter-build`/`flutter-web` wrappers, `Pistisai:dev` image and `/opt/flutter` SDK path have no counterparts in the tree.

## Quick Start

### 1. Validate the local environment

```bash
./scripts/docker/validate_dev_environment.sh
```

The script checks for Docker Compose, a local `flutter` and Chrome for web testing (`flutter devices`), and validates the repo-root `docker-compose.yml` with `docker compose config` (see `scripts/docker/validate_dev_environment.sh`). It does not build a dev image.

### 2. Start backing services

```bash
# Services defined in docker-compose.yml: database, redis, cloudflared,
# tailscale-relay, webapp, api-backend, postfix-mail, certbot
docker compose up -d database redis api-backend
docker compose ps
```

### 3. Develop Pistisai locally

```bash
flutter pub get
flutter doctor
flutter analyze
flutter test
flutter build linux --release   # desktop
flutter build web --release --no-web-resources-cdn
```

Node-backed services require Node 26 (`.nvmrc`; service engines `>=26 <28`, e.g. `services/api-backend/package.json`).

## Toolchain

| Component | Version / source |
|-----------|------------------|
| Flutter SDK | `3.47.9` — `pubspec.yaml` `environment.flutter` |
| Dart SDK | Constraint `>=3.5.0 <4.0.0` — `pubspec.yaml` |
| Node | 26 — `.nvmrc`; service engines `>=26 <28` |
| Compose services | `docker-compose.yml` (repositories root) |
| App Dockerfiles | `config/docker/Dockerfile.flutter-app`, `config/docker/Dockerfile.web`, `Dockerfile.web` (production web build) |

## Useful Commands

| Command | Description |
|---------|-------------|
| `flutter doctor` | Check the local Flutter toolchain |
| `docker compose ps` | Check backing-service health |
| `docker compose logs -f api-backend` | Follow API backend logs |
| `flutter test` | Run the Flutter test suite |

## GUI / System Tray Testing

Run the desktop app on the host (system tray needs the host's GTK/session libraries); Docker is only used for backing services:

```bash
sudo apt-get install -y libgtk-3-0 libglib2.0-0 libnss3 libatk-bridge2.0-0
flutter config --enable-linux-desktop
flutter run -d linux
```

For web testing, use Chrome on the host; for remote devices use Tailscale rather than an X11-forwarded container.

## Troubleshooting

1. **Permission errors on mounted files**

   ```bash
   sudo chown -R $(id -u):$(id -g) .
   ```

2. **Compose health check fails**

   ```bash
   docker compose ps
   docker compose logs -f api-backend
   ```

3. **Build failures**

   ```bash
   flutter clean
   flutter pub get
   ```

4. **Flutter version mismatch** — use the pinned SDK in `pubspec.yaml` (3.47.9); CI reads the same file via `flutter-version-file: pubspec.yaml`.

## Validation

```bash
./scripts/docker/validate_dev_environment.sh
```

## Documentation

- [Docker Deployment Guide](DOCKER_DEPLOYMENT.md)
- [Web Deploy (production image)](../operations/cicd/WEB_DEPLOY.md)
- [Pistisai Architecture](../architecture/SYSTEM_ARCHITECTURE.md)
- [Self-Hosting Guide](SELF_HOSTING.md)

## Support

For Docker environment issues:

1. Run validation: `./scripts/docker/validate_dev_environment.sh`
2. Check services: `docker compose ps`
3. Review logs: `docker compose logs -f api-backend`
