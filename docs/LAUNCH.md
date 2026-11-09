# IAClé — run the hub from source

> Product description: [README](../README.md) ([English](../README.en.md))
> Repo: [github.com/iacle-solutions/iacle-app](https://github.com/iacle-solutions/iacle-app)

This page is how to run the software. The offer is in the [README](../README.md) ([English](../README.en.md)).

---

## What this repository is

The IAClé desktop hub, delivered by IAClé. It is the layer in front of an agent runtime. Hermes is the primary path. OpenClaw and compatible gateways work too. Ollama and LM Studio support memory, embeddings, OCR, and speech. The main runtime stays the agent gateway.

The agent runs on a computer at the client's site. The readiness audit checks whether their current PC can host it. If it can, it runs there. If not, IAClé provides a dedicated mini PC (standard: Beelink GTi15). Custom hardware only when the audit shows the need.

---

## Supported runtimes

| Runtime | Status | Notes |
|---------|--------|-------|
| **Hermes** | Primary path | Sessions, channels, and tools. |
| **OpenClaw** | Supported | Gateway control and skill management. |
| Compatible agent gateways | Supported | Any agent exposing the [runtime contract](architecture/AGENT_RUNTIME_CONTRACT.md). |
| Ollama / LM Studio | Support only | Memory, embeddings, OCR, speech. Not the main runtime. |

The setup wizard chooses where the agent lives: this device, another private device, a Tailscale device, or a manual private URL.

Sign-in is for the tunnel and for sync. The network is a tunnel behind Cloudflare Access, Tailscale, or the customer's VPN.

---

## Platforms

CI builds these targets. To run a copy yourself, build from source.

| Platform | CI |
|----------|----|
| Linux | `flutter build linux`, AppImage script in `scripts/packaging/build_appimage.sh` |
| Windows | `flutter build windows`, Inno Setup script at `windows/installer/IAClé.iss` |
| macOS | `flutter build macos` |
| Android | `flutter build apk` via `.github/workflows/build-mobile.yml` |
| Web | `flutter build web --release --no-web-resources-cdn` |

---

## Quick start

```bash
git clone https://github.com/iacle-solutions/iacle-app.git
cd iacle-app

flutter pub get
cd lib/shared && flutter pub get && cd ../..

flutter run -d linux
flutter run -d chrome
```

The app package is `IAClé` (Dart `>=3.5.0 <4.0.0`). `lib/shared` (`shared`) targets Dart `>=3.9.0 <4.0.0` and needs its own `flutter pub get`. Flutter is pinned to `3.47.7` in `pubspec.yaml`.

Release builds:

```bash
flutter build linux --release
flutter build web --release --no-web-resources-cdn
flutter build apk --release --split-per-abi
flutter build windows --release
flutter build macos --release
```

Backend services, from the repo root after `npm install`:

```bash
cd services/api-backend && npm install && npm run dev
cd services/streaming-proxy && npm install && npm run dev
```

`backend/auth/` has no `dev` script. Start it with `node handlers.js`.

Developer onboarding: [development/DEVELOPER_ONBOARDING.md](development/DEVELOPER_ONBOARDING.md).
Command reference: [AGENTS.md](../AGENTS.md).

---

## Connecting an agent runtime

The setup wizard supports:

- **This device** — Hermes or OpenClaw running locally.
- **Another private device** — a machine on the LAN.
- **Tailscale device** — private path across the client's computers ([Secure Device Mesh](architecture/SECURE_DEVICE_MESH.md)).
- **Manual / private URL** — a private agent gateway endpoint.

Desktop control, vision, and the channel are scoped to a device and permissioned per action.

---

## Self-hosting

- [deployment/DEPLOYMENT_OVERVIEW.md](deployment/DEPLOYMENT_OVERVIEW.md)
- [deployment/SELF_HOSTING.md](deployment/SELF_HOSTING.md)
- [SECURITY.md](../SECURITY.md) — report vulnerabilities privately to `ops@example.com` or [this repo's security advisories](https://github.com/iacle-solutions/iacle-app/security/advisories).

---

## Documentation

| Guide | Link |
|-------|------|
| Product description | [README](../README.md) |
| System Architecture | [architecture/SYSTEM_ARCHITECTURE.md](architecture/SYSTEM_ARCHITECTURE.md) |
| Agent Runtime Contract | [architecture/AGENT_RUNTIME_CONTRACT.md](architecture/AGENT_RUNTIME_CONTRACT.md) |
| Secure Device Mesh | [architecture/SECURE_DEVICE_MESH.md](architecture/SECURE_DEVICE_MESH.md) |
| Desktop Control | [architecture/DESKTOP_CONTROL.md](architecture/DESKTOP_CONTROL.md) |
| Vision System | [architecture/VISION_SYSTEM.md](architecture/VISION_SYSTEM.md) |
| User Guide | [user-guide/USER_GUIDE.md](user-guide/USER_GUIDE.md) |
| Setup Guide | [user-guide/SETUP_GUIDE.md](user-guide/SETUP_GUIDE.md) |
| Developer Onboarding | [development/DEVELOPER_ONBOARDING.md](development/DEVELOPER_ONBOARDING.md) |
| Contributing | [CONTRIBUTING.md](../CONTRIBUTING.md) |
