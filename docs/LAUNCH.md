# PistisAI — Public launch guide

> Canonical launch issue: [#39 — PistisAI — public launch](https://github.com/pistisAI/pistisai-app/issues/39)
> Repo: [github.com/pistisAI/pistisai-app](https://github.com/pistisAI/pistisai-app)
> Web app: [app.pistisai.app](https://app.pistisai.app)
> Product page: [PRODUCT.md](PRODUCT.md)

This document is the entry point for anyone arriving from a launch channel. It covers what the product is, what it runs on, and how to try it.

---

## What PistisAI is

PistisAI (ΠΙΣΤΙΣΑΙ — "trust") is the tool stack: a desktop hub built around the Hermes agent, plus skills. The agent runs on the client's own computer. No special hardware is required.

IAClé is Christopher Maltais's Quebec company and the brand that delivers this same stack to Quebec clients. One stack, one company.

The hub adds a secure channel, voice and avatar, permissioned desktop control, and vision. Cloud services the client already uses, and online language models for heavy work, are available when that path is secure, the client agrees, and it complies with Quebec Law 25.

It is not a model. Hermes, OpenClaw, or a compatible gateway is the agent. Ollama, LM Studio, and similar model servers are support providers for app-owned features (memory, embeddings, OCR, speech).

---

## Positioning (one-liner)

> **PistisAI is a desktop hub and skills for a Hermes-based agent. It runs on the client's own computer. IAClé delivers that same stack to Quebec businesses.**

---

## Supported runtimes

| Runtime | Status | Notes |
|---------|--------|-------|
| **Hermes** | Primary test path | Sessions, channels, and tools wired in. |
| **OpenClaw** | Supported | Gateway control and skill management. |
| Compatible agent gateways | Supported | Any agent exposing the runtime contract (see [Agent Runtime Contract](architecture/AGENT_RUNTIME_CONTRACT.md)). |
| Ollama / LM Studio / model servers | Support only | App-owned memory, embeddings, OCR, and speech. Not the agent. |
| Online language models | With consent | Heavy work, when the client agrees and the provider fits Law 25 for Quebec clients. |

The setup wizard chooses where the agent runtime lives: this computer, another computer the client already has, a Tailscale device, or a private URL. There is no universal hardcoded default. The agent is not a hosted PistisAI service.

---

## Platforms

| Platform | Status | How to get it |
|----------|--------|---------------|
| Web | Live | [app.pistisai.app](https://app.pistisai.app). Cloudflare Access protects the host. |
| Linux | CI | AppImage from [releases](https://github.com/pistisAI/pistisai-app/releases/latest). |
| Android | CI | APK from [releases](https://github.com/pistisAI/pistisai-app/releases/latest). |
| Windows | CI | Installer and portable zip from `build-desktop.yml`. |
| macOS | CI | Zip from `build-desktop.yml`. |

---

## Quick start

### Option A — Web

1. Open [app.pistisai.app](https://app.pistisai.app).
2. Sign in only if you are using tunnel or sync. Cloudflare Access protects that host.
3. Run the in-app setup wizard and point it at the agent runtime on the client's computer (Hermes on this computer, another computer the client already has, or a private URL).

The desktop app is the hub for real multi-device use. The web app connects through that hub.

### Option B — Desktop from source (developers / self-hosters)

```bash
# 1. Clone
git clone https://github.com/pistisAI/pistisai-app.git
cd pistisai-app

# 2. Get Flutter dependencies (app + shared package)
flutter pub get
cd lib/shared && flutter pub get && cd ../..

# 3. Run (pick your target)
flutter run -d linux    # Linux desktop
flutter run -d chrome   # Web

# 4. Build release artifacts
flutter build linux --release
flutter build web --release --no-web-resources-cdn
flutter build apk --release --split-per-abi
```

> The Flutter app package is `pistisai` (Dart SDK `>=3.5.0 <4.0.0`). The shared
> package `lib/shared` (`pistisai_shared`) targets Dart `>=3.9.0 <4.0.0` and needs
> its own `flutter pub get`.

### Option C — Backend services (for self-hosted / full stack)

The repo bundles Node.js services. From the repo root:

```bash
# Root tooling
npm install
npm test          # api-backend security CI suite only (see AGENTS.md)
# npm run test:full   # broader Jest run; many suites are ignore-listed

# API backend (default port 8080)
cd services/api-backend && npm install && npm run dev

# Streaming proxy (default port 3001)
cd services/streaming-proxy && npm install && npm run dev
```

Developer onboarding → [development/DEVELOPER_ONBOARDING.md](development/DEVELOPER_ONBOARDING.md).
Command reference → [AGENTS.md](../AGENTS.md).

---

## Connecting your agent runtime

Pistisai does **not** assume a default agent. The connection is made by the
setup wizard, which supports:

- **This computer** — Hermes or OpenClaw running locally. This is the normal path.
- **Another computer the client already has** — a machine on the LAN.
- **Tailscale device** — Business and Enterprise path, on the customer's own network (see [Secure Device Mesh](architecture/SECURE_DEVICE_MESH.md)).
- **Manual / private URL** — a private compatible agent gateway.

Free-tier sync uses the tunnel at `api.pistisai.app` (Cloudflare Access). See [Tunnel and sync sign-in](development/TUNNEL_SIGN_IN.md).

Desktop control, vision, and the secure channel are all scoped to the device
and permissioned per action — explicit consent, fully auditable.

---

## Self-hosting & deployment

- **Overview / strategy**: [deployment/DEPLOYMENT_OVERVIEW.md](deployment/DEPLOYMENT_OVERVIEW.md)
  (agent-runtime-first, Tailscale-first, optional per-user cloud connector).
- **Self-hosting steps**: [deployment/SELF_HOSTING.md](deployment/SELF_HOSTING.md).
- **Security**: [SECURITY.md](../SECURITY.md) — report vulnerabilities privately
  to `security@pistisai.app` or the GitHub security advisories tab.

---

## Security posture (launch-relevant)

- CI runs on every push to `main`; reviewed, owner-/agent-authored commits only
  (direct-push model, per `AGENTS.md`).
- Secret scanning + push protection.
- CodeQL on every push; Dependabot automated updates.
- Free-tier tunnel sign-in is Cloudflare Access on `api.pistisai.app`. Business and Enterprise stay on the customer's Tailscale network or VPN.
- Desktop control is explicit, device-scoped, permissioned, and auditable.

---

## Documentation index

| Guide | Link |
|-------|------|
| System Architecture | [architecture/SYSTEM_ARCHITECTURE.md](architecture/SYSTEM_ARCHITECTURE.md) |
| Agent Runtime Contract | [architecture/AGENT_RUNTIME_CONTRACT.md](architecture/AGENT_RUNTIME_CONTRACT.md) |
| Secure Device Mesh | [architecture/SECURE_DEVICE_MESH.md](architecture/SECURE_DEVICE_MESH.md) |
| Desktop Control | [architecture/DESKTOP_CONTROL.md](architecture/DESKTOP_CONTROL.md) |
| Vision System | [architecture/VISION_SYSTEM.md](architecture/VISION_SYSTEM.md) |
| User Guide | [user-guide/USER_GUIDE.md](user-guide/USER_GUIDE.md) |
| Setup Guide | [user-guide/SETUP_GUIDE.md](user-guide/SETUP_GUIDE.md) |
| Developer Onboarding | [development/DEVELOPER_ONBOARDING.md](development/DEVELOPER_ONBOARDING.md) |
| Deployment Overview | [deployment/DEPLOYMENT_OVERVIEW.md](deployment/DEPLOYMENT_OVERVIEW.md) |
| Contributing | [CONTRIBUTING.md](../CONTRIBUTING.md) |

---

## Launch content & assets

The publish-ready copy backing this launch lives in the repo so it travels with
the code and stays in sync:

| Asset | Link |
|-------|------|
| Content brief (one-liner, positioning, channel plan) | [marketing/LAUNCH_CONTENT_BRIEF.md](marketing/LAUNCH_CONTENT_BRIEF.md) |
| Social thread pack (X + LinkedIn) | [marketing/publish-ready/social-thread-pack.md](marketing/publish-ready/social-thread-pack.md) |
| Community copy pack (Discord/forum FAQ) | [marketing/publish-ready/community-copy-pack.md](marketing/publish-ready/community-copy-pack.md) |
| Measurement plan (Day 1 / Week 1 metrics) | [marketing/publish-ready/measurement-plan.md](marketing/publish-ready/measurement-plan.md) |
| Social announcements (CMO drafts + calendar) | [../cmo-deliverables/launch-social-announcements.md](../cmo-deliverables/launch-social-announcements.md) |
| Community activation plan | [../cmo-deliverables/community-activation-plan.md](../cmo-deliverables/community-activation-plan.md) |

---

## Call to action

Clone the repo, run a workflow, and open an issue or discussion with your real
use case. Feedback, failure reports, and contribution PRs are the lifeblood of
this launch.

- Web: https://app.pistisai.app
- GitHub: https://github.com/pistisAI/pistisai-app
- Launch thread (issues): [#39](https://github.com/pistisAI/pistisai-app/issues/39)
