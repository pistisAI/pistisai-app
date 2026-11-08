# PistisAI

**Desktop hub for a Hermes-based agent, plus skills. It runs on the client's own computer.**

PistisAI is the tool stack. IAClé is the Quebec company that delivers it. See [Product](PRODUCT.md) and [Produit (français)](PRODUCT.fr.md).

The repository is a Flutter desktop/web application with optional Node.js services for the API and tunnel. Sign-in is only for tunnel and sync: Cloudflare Access on the free tier, the customer's Tailscale network or VPN for Business and Enterprise. See [Tunnel and sync sign-in](development/TUNNEL_SIGN_IN.md).

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
| API backend | Express 5 ESM, Node `>=22 <27`, port `8080` |
| Streaming proxy | Express 5 ESM, Node `>=22 <27`, port `3001` |
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

**Open source** — [GitHub repo](https://github.com/pistisAI/pistisai-app)
