# IAClé

**The desktop hub IAClé delivers to Quebec SMBs.**

IAClé is Christopher Maltais's Quebec sole proprietorship and the brand on this stack. The software in this repository is that stack: a Flutter desktop/web hub for Hermes, OpenClaw, and compatible gateways, plus skills. One stack, one company. The public description is the French [README](../README.md) ([English](../README.en.md)).

IAClé is a local-first companion and desktop capability layer for agent runtimes. It provides a secure agent channel, avatar/voice companion, desktop control, vision, agent runtime management, and multi-device sync. Sign-in is for the tunnel and for sync. The network is a tunnel behind Cloudflare Access, Tailscale, or the customer's VPN. Sign-in does not use Supabase.

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
| Flutter app | Dart `>=3.5.0 <4.0.0`, package `IAClé` |
| Shared package | `lib/shared` (`shared`), Dart `>=3.9.0 <4.0.0` |
| Local database | Drift / SQLite |
| Embedded router | Shelf server, port `1337` |
| API backend | Express 5 ESM, Node `>=22 <27`, port `8080` |
| Streaming proxy | Express 5 ESM, Node `>=22 <27`, port `3001` |
| Tailscale relay | Express 4 ESM, port `3002` |
| Auth backend | Express 5 CommonJS, port `3000` |
| SDK | `@IAClé/sdk` v2, ESM |

## Quick Links

- [Getting Started](user-guide/SETUP_GUIDE.md)
- [Features Guide](user-guide/FEATURES_GUIDE.md)
- [System Architecture](architecture/SYSTEM_ARCHITECTURE.md)
- [Agent Runtime Contract](architecture/AGENT_RUNTIME_CONTRACT.md)
- [Docker Deployment](deployment/DOCKER_DEPLOYMENT.md)
- [Self-Hosting](deployment/SELF_HOSTING.md)
- [Web Deploy](operations/cicd/WEB_DEPLOY.md)

---

**Open source** — [github.com/iacle-solutions/iacle-app](https://github.com/iacle-solutions/iacle-app)
