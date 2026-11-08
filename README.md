# PistisAI — ΠΙΣΤΙΣΑΙ

**A desktop hub for a Hermes-based agent, plus skills. The agent runs on a local machine at the client's site.**

PistisAI is the tool stack. IAClé is Christopher Maltais's Quebec company and the brand that delivers this same stack to Quebec clients. One stack, one company. IAClé is not a separate product.

A free readiness audit checks whether the client's current PC can host the agent. If it can, the agent runs there. Otherwise IAClé provides a dedicated local mini PC, the Beelink GTi15, for purchase or rental. Custom hardware is sized case by case. The stack can use cloud services the client already uses, and online language models for heavy work, only when that is secure, the client agrees, and it complies with Quebec Law 25.

Full positioning: [docs/PRODUCT.md](docs/PRODUCT.md). French: [docs/PRODUCT.fr.md](docs/PRODUCT.fr.md).

---

## Try it

Install the **desktop app** first. That install is the hub. Web, mobile, and other desktops connect through it. See [Your devices, one hub](#your-devices-one-hub).

- Web app: [app.pistisai.app](https://app.pistisai.app)
- API and free-tier tunnel: [api.pistisai.app](https://api.pistisai.app)
- Desktop and mobile builds: [Releases](https://github.com/pistisAI/pistisai-app/releases/latest) (Linux, Windows, macOS, and Android are built in CI)

Sign-in is only for tunnel and sync. Local desktop use does not require an account. The free tier uses the pistisai.app tunnel, protected by Cloudflare Access. Business and Enterprise use the customer's own Tailscale network or VPN. See [Tunnel and sync sign-in](docs/development/TUNNEL_SIGN_IN.md).

You need an agent runtime. Hermes is the main one. OpenClaw and compatible gateways also work. Messaging apps such as Telegram and Slack stay on Hermes. They do not route through this app.

Launch steps: [docs/LAUNCH.md](docs/LAUNCH.md). Why the name exists: [docs/governance/manifesto.md](docs/governance/manifesto.md).

---

## What you get

| Layer | What it gives you |
| --- | --- |
| Desktop hub | The machine that stays on. Other PistisAI clients connect through it. |
| Agent channel | Hermes, OpenClaw, or a compatible gateway on a computer the client controls. |
| Voice and avatar | Sidecar companion with a persistent presence. |
| Desktop control | Permissioned access to apps, windows, keyboard, and files. |
| Vision | Screen awareness and OCR, with permission on that device. |
| Skills | Scheduled tasks, sessions, and added capabilities. Same stack, not new products. |
| Device mesh | Free tier through the Access-protected tunnel. Business and Enterprise on the customer's Tailscale or VPN. |

---

## Architecture

```text
  Telegram / Slack / ...        Hermes owns these adapters
              │
              ▼
        Hermes (agent runtime)  on the client's computer
              │
              ▼
     PistisAI desktop hub       voice, vision, desktop control, skills
              │
              ├── Web app, mobile, other desktops
              │
              └── Tunnel / sync, only when needed
                    Free: api.pistisai.app (Cloudflare Access)
                    Business / Enterprise: customer Tailscale or VPN
```

### Your devices, one hub

- Install the desktop app on the computer that stays on. It connects to the agent and becomes the hub.
- Web, mobile, and other desktops connect through that hub.
- The agent still talks to messaging apps directly.

Technical map: [System architecture](docs/architecture/SYSTEM_ARCHITECTURE.md).

---

## Platforms

| Platform | Status |
| --- | --- |
| Linux | AppImage built in CI |
| Windows | Installer and portable zip built in CI |
| macOS | Zip built in CI |
| Android | APK built in CI |
| Web | [app.pistisai.app](https://app.pistisai.app) |

---

## Development

```bash
git clone https://github.com/pistisAI/pistisai-app.git
cd pistisai-app
flutter pub get

# The app depends on a separate shared package — get its deps too:
cd lib/shared && flutter pub get && cd ../..

flutter run -d linux   # Desktop
flutter run -d chrome  # Web
```

```bash
flutter build linux --release
flutter build web --release --no-web-resources-cdn
flutter build apk --release --split-per-abi
flutter build windows --release
flutter build macos --release
```

### Backend services

```bash
cd services/api-backend && npm install && npm run dev
cd services/streaming-proxy && npm install && npm run dev
```

Developer onboarding: [docs/development/DEVELOPER_ONBOARDING.md](docs/development/DEVELOPER_ONBOARDING.md).
Command reference: [AGENTS.md](AGENTS.md).

---

## Documentation

| Guide | What's in it |
| --- | --- |
| [Product](docs/PRODUCT.md) | PistisAI, IAClé, tiers, hosts |
| [Produit (français)](docs/PRODUCT.fr.md) | Same page for Quebec clients |
| [User guide](docs/user-guide/USER_GUIDE.md) | Features and usage |
| [Setup guide](docs/user-guide/SETUP_GUIDE.md) | Installation |
| [Troubleshooting](docs/user-guide/TROUBLESHOOTING.md) | Common issues |
| [System architecture](docs/architecture/SYSTEM_ARCHITECTURE.md) | Technical map |
| [Tunnel sign-in](docs/development/TUNNEL_SIGN_IN.md) | Cloudflare Access and customer VPN |
| [Security](SECURITY.md) | Reporting policy |
| [Launch guide](docs/LAUNCH.md) | Quick start |
| [Contributing](CONTRIBUTING.md) | Issues, setup, and pull requests |

---

## License

Business Source License 1.1. See [LICENSE](LICENSE).
