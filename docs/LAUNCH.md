# Pistisai — Public Launch Guide

> Canonical launch issue: [#39 — Paperclip AI — public launch](https://github.com/pistisAI/pistisai-app/issues/39)
> Repo: [github.com/pistisAI/pistisai-app](https://github.com/pistisAI/pistisai-app)
> Web app: [pistisai.app](https://pistisai.app)

This document is the single entry point for anyone arriving at Pistisai from a
launch channel. It covers what the product is, what it runs on, and the exact
steps to try it — web, desktop, or self-hosted — and how to connect your own
agent runtime.

---

## What Pistisai is

Pistisai (ΠΙΣΤΙΣΑΙ — "trust") is a **local-first companion and desktop
capability layer for your AI agent**. Your agent runs on hardware you control.
Pistisai gives that agent a secure channel, voice + avatar, desktop control,
vision, and a private device mesh — so no data leaves your network unless you
decide otherwise.

It is **not** a model. It is the layer in front of an agent runtime
(Hermes, OpenClaw, or any compatible agent gateway). Those runtimes are where
the reasoning happens. Ollama, LM Studio, and similar model servers are
*support providers* for app-owned features (memory, embeddings, OCR, speech) —
they are not the primary app runtime.

---

## Positioning (one-liner)

> **Pistisai turns your AI agent into a private desktop companion: voice,
> vision, and audited desktop control, connected over your own Tailscale mesh —
> local-first, no data leaves your network unless you say so.**

---

## Supported runtimes

| Runtime | Status | Notes |
|---------|--------|-------|
| **Hermes** | ✅ Primary test path | First-class integration; sessions, channels, tools wired in. |
| **OpenClaw** | ✅ Supported | Gateway control + skill management built in. |
| Compatible agent gateways | ✅ Supported | Any agent exposing the runtime contract (see [Agent Runtime Contract](docs/architecture/AGENT_RUNTIME_CONTRACT.md)). |
| Ollama / LM Studio / model servers | 🔌 Support only | Used for app-owned memory/embeddings/OCR/speech, not as the main runtime. |
| Pistisai-hosted compute | 🔜 Optional | Paid, opt-in hosted agent runtime (per-user container). |

The **setup wizard** decides where the active agent runtime lives: this device,
another private device, a Tailscale device, a manual/private URL, or optional
paid Pistisai-hosted compute. There is no universal hardcoded default.

---

## Platforms

| Platform | Status | How to get it |
|----------|--------|---------------|
| 🌐 Web | ✅ Live | [pistisai.app](https://pistisai.app) — any browser, log in. |
| 🐧 Linux | ✅ AppImage + auto-update daemon | Releases / CI. |
| 📱 Android | ✅ APK from CI | [Latest release](https://github.com/pistisAI/pistisai-app/releases/latest). |
| 🪟 Windows | 🚧 Installer in development | — |
| 🍎 macOS | 📋 Planned | — |

---

## Quick start

### Option A — Web (fastest, zero install)

1. Open [pistisai.app](https://pistisai.app).
2. Log in.
3. Run the in-app **setup wizard** and point it at your agent runtime
   (Hermes on this device, a Tailscale peer, a private URL, etc.).

That's it. No build step.

### Option B — Desktop from source (developers / self-hosters)

```bash
# 1. Clone
git clone https://github.com/pistisAI/pistisai-app.git
cd pistisai-app

# 2. Get Flutter dependencies
flutter pub get

# 3. Run (pick your target)
flutter run -d linux    # Linux desktop
flutter run -d chrome   # Web

# 4. Build release artifacts
flutter build linux --release
flutter build web --release
flutter build apk --release --split-per-abi
```

> The Flutter app package is `pistisai` (Dart SDK `>=3.5.0 <4.0.0`). A shared
> package `lib/shared` (`pistisai_shared`) has its own `pubspec.yaml`.

### Option C — Backend services (for self-hosted / full stack)

The repo bundles Node.js services. From the repo root:

```bash
# Root tooling
npm install
npm test          # ESM Jest, matches **/test/**/*.test.js

# API backend
cd services/api-backend && npm install && npm run dev

# Streaming proxy
cd services/streaming-proxy && npm install && npm run dev
```

Full backend/dev guide → [docs/development/BUILD_SCRIPTS.md](docs/development/BUILD_SCRIPTS.md).

---

## Connecting your agent runtime

Pistisai does **not** assume a default agent. The connection is made by the
setup wizard, which supports:

- **This device** — Hermes / OpenClaw running locally.
- **Another private device** — a machine on your LAN.
- **Tailscale device** — preferred secure path; one private network across all
  your machines (see [Secure Device Mesh](docs/architecture/SECURE_DEVICE_MESH.md)).
- **Manual / private URL** — bring your own agent gateway endpoint.
- **Pistisai-hosted compute** — optional paid runtime (per-user container joined
  to your tailnet).

Desktop control, vision, and the secure channel are all scoped to the device
and permissioned per action — explicit consent, fully auditable.

---

## Self-hosting & deployment

- **Overview / strategy**: [docs/deployment/DEPLOYMENT_OVERVIEW.md](docs/deployment/DEPLOYMENT_OVERVIEW.md)
  (agent-runtime-first, Tailscale-first, optional per-user cloud connector).
- **Current production path**: Kubernetes / container deployment per the overview.
- **Historical Docker Swarm runbook**: [DEPLOYMENT.md](../DEPLOYMENT.md) (legacy
  streaming-proxy stack; keep only for maintaining that older path).
- **Security**: [SECURITY.md](../SECURITY.md) — report vulnerabilities privately
  to `security@pistisai.app` or the GitHub security advisories tab.

---

## Security posture (launch-relevant)

- CI runs on every push to `main`; reviewed, owner-/agent-authored commits only
  (direct-push model, per `AGENTS.md`).
- Secret scanning + push protection.
- CodeQL on every push; Dependabot automated updates.
- Tailscale-first private connectivity; the cloud connector is one isolated
  container per user, joined to that user's tailnet.
- Desktop control is explicit, device-scoped, permissioned, and auditable.

---

## Documentation index

| Guide | Link |
|-------|------|
| System Architecture | [docs/architecture/SYSTEM_ARCHITECTURE.md](docs/architecture/SYSTEM_ARCHITECTURE.md) |
| Agent Runtime Contract | [docs/architecture/AGENT_RUNTIME_CONTRACT.md](docs/architecture/AGENT_RUNTIME_CONTRACT.md) |
| Secure Device Mesh | [docs/architecture/SECURE_DEVICE_MESH.md](docs/architecture/SECURE_DEVICE_MESH.md) |
| Desktop Control | [docs/architecture/DESKTOP_CONTROL.md](docs/architecture/DESKTOP_CONTROL.md) |
| Vision System | [docs/architecture/VISION_SYSTEM.md](docs/architecture/VISION_SYSTEM.md) |
| User Guide | [docs/user-guide/USER_GUIDE.md](docs/user-guide/USER_GUIDE.md) |
| Setup Guide | [docs/user-guide/SETUP_GUIDE.md](docs/user-guide/SETUP_GUIDE.md) |
| Build Scripts | [docs/development/BUILD_SCRIPTS.md](docs/development/BUILD_SCRIPTS.md) |
| Deployment Overview | [docs/deployment/DEPLOYMENT_OVERVIEW.md](docs/deployment/DEPLOYMENT_OVERVIEW.md) |
| Contributing | [CONTRIBUTING.md](../CONTRIBUTING.md) |

---

## Launch content & assets

The publish-ready copy backing this launch lives in the repo so it travels with
the code and stays in sync:

| Asset | Link |
|-------|------|
| Content brief (one-liner, positioning, channel plan) | [docs/marketing/LAUNCH_CONTENT_BRIEF.md](docs/marketing/LAUNCH_CONTENT_BRIEF.md) |
| Social thread pack (X + LinkedIn) | [docs/marketing/publish-ready/social-thread-pack.md](docs/marketing/publish-ready/social-thread-pack.md) |
| Community copy pack (Discord/forum FAQ) | [docs/marketing/publish-ready/community-copy-pack.md](docs/marketing/publish-ready/community-copy-pack.md) |
| Measurement plan (Day 1 / Week 1 metrics) | [docs/marketing/publish-ready/measurement-plan.md](docs/marketing/publish-ready/measurement-plan.md) |
| Social announcements (CMO drafts + calendar) | [cmo-deliverables/launch-social-announcements.md](cmo-deliverables/launch-social-announcements.md) |
| Community activation plan | [cmo-deliverables/community-activation-plan.md](cmo-deliverables/community-activation-plan.md) |

---

## Call to action

Clone the repo, run a workflow, and open an issue or discussion with your real
use case. Feedback, failure reports, and contribution PRs are the lifeblood of
this launch.

- Web: https://pistisai.app
- GitHub: https://github.com/pistisAI/pistisai-app
- Launch thread (issues): [#39](https://github.com/pistisAI/pistisai-app/issues/39)
