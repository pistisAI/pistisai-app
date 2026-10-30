# Pistisai

**A local-first companion and desktop capability layer for agent runtimes.**

Pistisai is a Flutter desktop/web application with optional Node.js backend services. It provides a secure agent channel, avatar/voice companion, desktop control, vision system, agent runtime management, and multi-device sync through a Tailscale-first secure device mesh.

## What It Does

- **Secure Agent Channel** — Connects to your chosen agent runtime (Hermes, OpenClaw, or a compatible custom gateway). The setup wizard selects the runtime — no universal default.
- **Avatar & Voice Companion** — Persistent personality, evolution state, long-term memory, visual presence, and voice conversation in a sidecar window.
- **Desktop Control** — Explicit, device-scoped, permissioned, and auditable desktop inspection and operation.
- **Vision System** — Screenshots, region capture, camera input, and OCR for visual context.
- **Secure Device Mesh** — Tailscale-first private connectivity across devices, with optional cloud connector containers joined to your tailnet.
- **Multi-Runtime** — Agent runtime management for Hermes, OpenClaw, and compatible custom gateways.

## Architecture At a Glance

| Layer | Technology |
|-------|------------|
| Flutter app | Dart `>=3.5.0 <4.0.0`, package `pistisai` |
| Shared package | `lib/shared` (`pistisai_shared`), Dart `>=3.9.0 <4.0.0` |
| Local database | Drift / SQLite |
| Embedded router | Shelf server, port `1337` |
| API backend | Express 5 ESM, Node `>=26.0.0 <28.0.0`, port `8080` |
| Streaming proxy | Express 5 ESM, Node `>=26.0.0 <28.0.0`, port `3001` |
| Tailscale relay | Express 4 ESM, port `3002` |
| Auth backend | Express 5 CommonJS, port `3000` |
| SDK | `@Pistisai/sdk` v2, ESM, Node `>=26.0.0 <28.0.0` |

## Quick Links

- [Getting Started](user-guide/SETUP_GUIDE.md)
- [Features Guide](user-guide/FEATURES_GUIDE.md)
- [System Architecture](architecture/SYSTEM_ARCHITECTURE.md)
- [Agent Runtime Contract](architecture/AGENT_RUNTIME_CONTRACT.md)
- [Docker Deployment](deployment/DOCKER_DEPLOYMENT.md)
- [Self-Hosting](deployment/SELF_HOSTING.md)
- [Web Deploy](operations/cicd/WEB_DEPLOY.md)

---

**Open source** — [GitHub repo](https://github.com/pistisAI/pistisai-app)
