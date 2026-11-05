# Pistisai — ΠΙΣΤΙΣΑΙ

**A local-first companion and desktop capability layer for your AI agent. Private, secure, yours.**

> *Πίστις (Pistis) — the ancient spirit of trust, honesty, and good faith. After fleeing Pandora's box, she returned to Olympus. Pistisai builds a Stoa worthy of her return.*

Your AI runs on your hardware. The app gives it voice, vision, desktop control, and a secure channel across all your devices — no data leaves your network unless you decide otherwise.

---

## Try It Now

🖥️ **Start with the desktop app.** Your first Pistisai desktop install becomes your **primary desktop hub** — the main node that your web, mobile, and other desktop clients connect through. See [Desktop-as-Hub Topology](#desktop-as-hub-topology).

🌐 **[pistisai.app](https://pistisai.app)** — Web app, works in any browser. Handy for a quick look, but for real multi-device use the web app should connect through your primary desktop hub (not straight to your agent runtime).

🐧 **Linux** — `curl -fsSL https://pistisai.app/install.sh | bash` (AppImage + auto-update daemon; rolling out).

📱 **Android** — APK builds from CI. Grab the latest from [Releases](https://github.com/pistisAI/pistisai-app/releases/latest).

**You need an agent runtime.** Hermes is the primary test path. OpenClaw and compatible agent gateways also work. The primary desktop hub connects to the runtime; your other Pistisai clients connect to the hub.

> 🚀 **Public launch is live.** Full quick-start, supported runtimes, and self-hosting steps → [docs/LAUNCH.md](docs/LAUNCH.md). Primary CTA: clone the repo, run a workflow, and open an issue or discussion with your real use case. Track the launch → [GitHub issue #39](https://github.com/pistisAI/pistisai-app/issues/39).
>
> 🏛️ **Why we exist** → [docs/governance/manifesto.md](docs/governance/manifesto.md) — the meaning of Πίστις and the Four Pillars behind the product.

---

## What Sets It Apart

| Layer | What it gives you |
|-------|-------------------|
| **Secure Channel** | Direct line to your agent, synced across devices |
| **Voice + Avatar** | Sidecar companion with personality, memory, natural conversation |
| **Desktop Control** | Permissioned access to apps, windows, keyboard, files |
| **Vision** | Screen awareness, OCR, camera — explicit per-action consent |
| **Device Mesh** | Tailscale-first private network across all your machines |
| **Runtime Manager** | Manage agents, skills, sessions, tools, diagnostics |

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                  Pistisai App                     │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐    │
│  │  Agent   │  │  Avatar  │  │  Desktop Control   │    │
│  │  Channel │  │  Voice   │  │  Vision            │    │
│  └────┬─────┘  └────┬─────┘  └───────┬────────────┘    │
│       └──────────────┼────────────────┘                  │
│                      ▼                                   │
│           ┌──────────────────────┐                       │
│           │   Agent Adapter     │                        │
│           │  Hermes / OpenClaw  │                        │
│           └──────────┬──────────┘                        │
└──────────────────────┼───────────────────────────────────┘
                       │
              ┌────────┴────────┐
              │                 │
         ┌────▼────┐     ┌─────▼──────┐
         │  Local  │     │  Model     │
         │  Agent  │     │  Providers │
         │  Runtime│     │  (Ollama,  │
         │         │     │  LM Studio)│
         └─────────┘     └────────────┘
```

### Desktop-as-Hub Topology

```text
  Telegram / Slack / Discord / ...          (messaging platforms)
              │
              ▼
  ┌──────────────────────────┐
  │  Hermes gateway          │  messaging-platform hub: owns Telegram/Slack/etc. adapters
  │  (agent runtime)         │
  └────────────┬─────────────┘
               │ agent channel (local or Tailscale)
               ▼
  ┌──────────────────────────┐
  │  Primary Pistisai desktop│  device/client hub: first installed app, main node
  │  (embedded router :1337, │  exposes GET /api/pistisai/hub for discovery
  │   desktop control,       │
  │   vision, local brain)   │
  └──┬──────────┬─────────┬──┘
     │          │         │   Tailscale / private mesh
     ▼          ▼         ▼
   Web app   Mobile app  Secondary desktops     (Pistisai clients)
```

- **Hermes = messaging-platform hub.** The Hermes gateway still owns its Telegram, Slack, and other messaging adapters directly; those do not route through the Pistisai app.
- **Pistisai desktop = device/client hub.** The primary desktop install is required for web, mobile, and secondary desktop clients; they reach the agent runtime through it. Mobile finds it over Tailscale via `GET /api/pistisai/hub`.
- **Transitional:** existing paths where a web/mobile/secondary client talks directly to Hermes are transitional and will be removed ([#492](https://github.com/pistisAI/pistisai-app/issues/492)).

Technical deep-dive → [System Architecture](docs/architecture/SYSTEM_ARCHITECTURE.md)

---

## Platforms

| Platform | Status |
|----------|--------|
| 🐧 Linux | ✅ AppImage + auto-update daemon |
| 🌐 Web | [pistisai.app](https://pistisai.app) |
| 📱 Android | ✅ APK builds from CI |
| 🪟 Windows | ✅ Installer (InnoSetup) + CI |
| 🍎 macOS | ✅ Installer + CI |

---

## Development

```bash
git clone https://github.com/pistisAI/pistisai-app.git
cd pistisai-app
flutter pub get

# The app depends on a separate shared package — get its deps too:
cd lib/shared && flutter pub get && cd ../..

# Run

flutter run -d linux   # Desktop
flutter run -d chrome  # Web
```

```bash
# Build

flutter build linux --release
flutter build web --release --no-web-resources-cdn
flutter build apk --release --split-per-abi
flutter build windows --release
flutter build macos --release
```

### Backend Services

```bash
cd services/api-backend && npm install && npm run dev
cd services/streaming-proxy && npm install && npm run dev
```

Developer onboarding → [docs/development/DEVELOPER_ONBOARDING.md](docs/development/DEVELOPER_ONBOARDING.md).
Command reference → [AGENTS.md](AGENTS.md).

---

## Documentation

📖 [docs.pistisai.app](https://docs.pistisai.app)

| Guide | What's in it |
|-------|-------------|
| [User Guide](docs/user-guide/USER_GUIDE.md) | Features and usage |
| [Setup Guide](docs/user-guide/SETUP_GUIDE.md) | Step-by-step installation |
| [Troubleshooting](docs/user-guide/TROUBLESHOOTING.md) | Common issues |
| [System Architecture](docs/architecture/SYSTEM_ARCHITECTURE.md) | Technical deep-dive |
| [Deployment Guide](docs/operations/backend/) | Production setup |
| [Security Guide](SECURITY.md) | Reporting policy + security posture |
| [Public Launch Guide](docs/LAUNCH.md) | Quick-start, runtimes, self-hosting |
| [Contributing](CONTRIBUTING.md) | How to file issues, set up, and open PRs |

---

## License

Business Source License 1.1 — see [LICENSE](LICENSE).
