# Pistisai

**A local-first companion and desktop capability layer for your AI agent.**

Pistisai is the upstream product in this repository: a Flutter desktop/web hub for Hermes, OpenClaw, and compatible gateways, plus skills. The public description is the [README](../README.md).

Pistisai is a local-first companion and desktop capability layer for agent runtimes. It provides a secure agent channel, avatar/voice companion, desktop control, vision, agent runtime management, and multi-device sync. Sign-in is for the tunnel and for sync only: free plans use Cloudflare Access in front of `pistisai.app`; Business/Enterprise use customer VPN or Tailscale. Local desktop use needs no sign-in. Sign-in does not use Supabase.

## What It Does

- **Secure Agent Channel** — Connects to your chosen agent runtime (Hermes, OpenClaw, or a compatible custom gateway). The setup wizard selects the runtime — no universal default.
- **Avatar & Voice Companion (Phase 2)** — Persistent personality, evolution state, long-term memory, visual presence, and voice conversation in a sidecar window. The code is in the app, but it is deferred until chat works well and is not part of the current core scope.
- **Desktop Control** — Explicit, device-scoped, permissioned, and auditable desktop inspection and operation.
- **Vision System** — Screenshots, region capture, camera input, and OCR for visual context.
- **Secure Device Mesh** — Tailscale-first private connectivity across devices, with optional cloud connector containers joined to your tailnet.
- **Multi-Runtime** — Agent runtime management for Hermes, OpenClaw, and compatible custom gateways.

## Current Scope

The current scope is a universal baseline for any business, not a single sector: local-first chat with business context, business knowledge over your own documents, email triage (a person sends), bookkeeping basics (a person approves), document intake and retrieval, tasks and follow-ups, digests, approval with audit and export/delete, local model routing with explicit cloud consent, and onboarding and admin. Several of these are planned work, not shipped yet; the [Features Guide](user-guide/FEATURES_GUIDE.md#-product-scope) marks what is available today and what is planned.

## Architecture At a Glance

| Layer | Technology |
|-------|------------|
| Flutter app | Dart `>=3.5.0 <4.0.0`, package `pistisai` |
| Shared package | `lib/shared` (`shared`), Dart `>=3.9.0 <4.0.0` |
| Local database | Drift / SQLite |
| Embedded router | Shelf server, port `1337` |
| API backend | Express 5 ESM, Node `>=26.0.0 <28.0.0`, port `8080` |
| Streaming proxy | Express 5 ESM, Node `>=26.0.0 <28.0.0`, port `3001` |
| Tailscale relay | Express 4 ESM, port `3002` |
| Auth backend | Express 5 CommonJS, port `3000` |
| SDK | `@Pistisai/sdk` v2, ESM |

## Quick Links

- [Getting Started](user-guide/SETUP_GUIDE.md)
- [Features Guide](user-guide/FEATURES_GUIDE.md)
- [System Architecture](architecture/SYSTEM_ARCHITECTURE.md)
- [Agent Runtime Contract](architecture/AGENT_RUNTIME_CONTRACT.md)
- [Docker Deployment](deployment/DOCKER_DEPLOYMENT.md)
- [Self-Hosting](deployment/SELF_HOSTING.md)
- [Web Deploy](operations/cicd/WEB_DEPLOY.md)

---

**Open source** — [github.com/pistisAI/pistisai-app](https://github.com/pistisAI/pistisai-app)
