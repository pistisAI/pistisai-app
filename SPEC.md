# PistisAI specification

Positioning: [docs/PRODUCT.md](docs/PRODUCT.md). This file is the technical specification of the stack.

## Project vision

**PistisAI** is a desktop hub for a Hermes-based agent, plus skills. The agent runs on the client's own computer. No special hardware is required. IAClé is the Quebec company that delivers this same stack. One stack, one company.

The hub gives the agent a secure channel and permissioned hands and eyes on that computer. Web, mobile, and other desktops connect through the hub.

The main app does not connect directly to raw local model providers as its primary experience. Ollama, LM Studio, and similar endpoints are support model providers for app-owned features such as memory, embeddings, summarization, classification, OCR cleanup, and speech helpers. Online language models may be used for heavy work when the client agrees and, for Quebec clients, the provider fits Law 25.

Hermes is the agent runtime. OpenClaw is also supported.

## Product model

1. **Agent on the client's computer**: the normal path. Hermes, OpenClaw, or a compatible gateway runs on a computer the client already has.
2. **Support model provider**: optional local model infrastructure such as Ollama or LM Studio for memory and other app-owned background features.
3. **Tunnel and sync**: sign-in exists only for this. Free tier uses Cloudflare Access on `api.pistisai.app`. Business and Enterprise use the customer's Tailscale network or VPN (`PISTISAI_TUNNEL_AUTH=customer`).

Local desktop use does not require an account. The agent runs on a computer the client already has.

## Core Pillars

### 1. Secure Agent Channel

- Main window is a direct, secure channel to the selected active agent runtime.
- Hermes is the first target for development and testing.
- Channel state can sync across authorized devices when cloud mode is enabled.
- Device presence, runtime status, session state, and action approvals attach to the channel.
- The UI should be calm and direct, not a management dashboard first.

### 2. Avatar And Voice Companion

- The avatar is the companion surface, not only an in-app decoration.
- Voice belongs with the avatar companion.
- The avatar/voice companion should be able to open as its own sidecar window.
- It reflects listening, engaged, speaking, thinking, working, and error states.
- It can escalate from lightweight conversation to the active agent runtime when needed.

### 3. Desktop Control

- Desktop control is a core feature.
- The active agent runtime can request permissioned hands-on access to a selected device.
- The local Pistisai device node approves, executes, and audits the action through a capability broker.
- Capabilities include app launch, window control, click/type/keyboard actions, clipboard, file operations, system state, and command execution where supported.
- Risky actions must remain explicit, device-scoped, auditable, and user-controlled.

### 4. Vision

- Vision gives the active agent runtime controlled eyes on selected devices.
- Capabilities include screen capture, region capture, OCR, camera input, and later continuous monitoring.
- Camera and screen monitoring must be visible, opt-in, and device-scoped.

### 5. Agent Runtime And Session Management

- Agent/runtime management remains important, but it is not the first surface.
- Management covers Hermes, OpenClaw, compatible agent gateways, sessions, skills, tools, models exposed by the runtime, diagnostics, and lifecycle controls.
- Users should be able to start, stop, restart, inspect, and troubleshoot runtimes when needed.

### 6. Local Intelligence Support

- Local model providers are optional support infrastructure.
- Ollama, LM Studio, and similar providers can power embeddings, memory summarization, semantic search, classification, OCR cleanup, local STT/TTS helpers, and other app-owned background intelligence.
- Local model providers are not primary agent runtime targets unless wrapped by a compatible agent gateway.

### 7. Multi-Device Sync And Secure Mesh

- Pistisai can be installed on all of a user's devices.
- Tailscale is the preferred private transport for device-to-device and cloud-connector communication.
- Conversation/channel state can sync globally.
- Desktop actions, vision, files, clipboard, and commands are always targeted to a specific authorized device.

## Setup Wizard

The first-run setup wizard must guide users through agent runtime selection without assuming a default.

Agent runtime setup paths:

1. **This device**: Hermes, OpenClaw, or a compatible agent gateway running locally.
2. **Another private device**: agent runtime running on another desktop, workstation, or server.
3. **Tailscale device**: agent runtime discovered through the user's tailnet.
4. **Manual/private URL**: custom LAN, VPN, tailnet DNS, or private compatible agent gateway.
5. **No runtime yet**: guide the user through installing or configuring Hermes, OpenClaw, or another compatible agent gateway on a computer the client already has.

Optional support model setup paths:

1. **None**: use only the active agent runtime and built-in app features.
2. **Ollama**: local model provider for memory and background intelligence.
3. **LM Studio**: local OpenAI-compatible model provider for support tasks.
4. **Custom local model endpoint**: support model provider for app-owned features.

The wizard must not present Ollama or LM Studio as primary agent runtime choices.

## Technical Architecture

### Flutter App

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App entry point |
| `lib/di/locator.dart` | GetIt service registration and two-phase DI |
| `lib/database/` | Drift/SQLite local brain and platform database connections |
| `lib/services/` | Service layer |
| `lib/services/hermes_manager/` | Hermes agent runtime management and streaming |
| `lib/services/openclaw_manager/` | OpenClaw agent runtime control |
| `lib/services/avatar/` | Avatar state, personality, memory, evolution, markdown sync |
| `lib/services/voice/` | Avatar companion voice state and TTS foundation |
| `lib/services/desktop_control/` | Clipboard and desktop window control |
| `lib/services/vision/` | Camera, OCR, region capture, vision orchestration |
| `lib/services/providers/` | Support model and router provider adapters |
| `lib/screens/` | Main app screens |
| `lib/widgets/` | Shared widgets and companion controls |

### Backend And Cloud

| Service | Role |
| --- | --- |
| API Backend | Auth, user/device metadata, admin APIs, optional cloud coordination |
| Streaming Proxy | Legacy/fallback streaming path and web transport support |
| Tailscale relay | Customer-network path for Business and Enterprise. |
| Tunnel sign-in | Cloudflare Access for the free tier. Customer Tailscale or VPN for Business and Enterprise. See [Tunnel and sync sign-in](docs/development/TUNNEL_SIGN_IN.md). |
| Auth service | `backend/auth/`, CommonJS, port 3000. |
| SDK | TypeScript SDK |
| OpenClaw Skills | Avatar personality/evolution skill package |

### Agent Runtime Contract

See [Agent Runtime Contract](docs/architecture/AGENT_RUNTIME_CONTRACT.md).

The minimum required capabilities are:

- runtime health
- agent session list/create/resume/end
- chat streaming
- agent status
- tool list
- desktop action requests through the device capability broker
- vision context requests through the device capability broker

Memory and voice integration are important but may phase in behind the first Hermes/OpenClaw connection work.

### Secure Device Mesh

The desktop app is the hub. Other clients connect through it. See [Desktop-as-hub topology](docs/architecture/SYSTEM_ARCHITECTURE.md#desktop-as-hub-topology).

```text
Hermes on the client's computer
        |
PistisAI desktop hub
        |
Web, mobile, other desktops
        |
Free tier: api.pistisai.app (Cloudflare Access)
Business and Enterprise: customer Tailscale or VPN
```

Rules:

- Use one isolated cloud connector container per user.
- The connector joins only that user's tailnet.
- The connector should use a narrow service identity such as a Tailscale tag.
- ACLs should allow only the device APIs needed by Pistisai.
- The cloud connector coordinates channel sync and presence; it does not bypass local desktop permissions.
- Custom SSH/WebSocket tunnel infrastructure should be treated as legacy or fallback unless a specific use case still requires it.

## Privacy And Security Model

- Core single-computer use works without an account.
- The active agent runtime location is chosen by setup, and it is a computer the client already has.
- Desktop control and vision are always device-scoped and permissioned.
- Cloud services and online models are used when the client agrees. For Quebec clients, that path has to fit Law 25.
- Free-tier sync uses Cloudflare Access. Business and Enterprise stay on the customer's network.
- Cloud sync must not grant direct desktop access without local app approval.
- Local model providers do not receive desktop-control authority.
- Local data ownership remains central through LocalBrain/SQLite and explicit sync settings.

## Success Metrics

1. **Agent runtime setup**: user can connect Hermes, OpenClaw, or another compatible agent gateway through setup without editing config files.
2. **Secure channel**: main window provides a reliable direct channel to the active agent runtime.
3. **Companion**: avatar/voice companion can run as a sidecar and reflect channel/runtime state.
4. **Desktop control**: runtime can complete useful permissioned desktop actions on a selected device.
5. **Vision**: runtime can inspect selected screen/camera context with user consent.
6. **Local intelligence**: optional local model providers can support memory and background features without becoming the main agent endpoint.
7. **Multi-device sync**: channel state can continue across authorized devices.
8. **Tunnel isolation**: free-tier Access and customer-network relays do not grant desktop actions without local approval.

## Out Of Scope For The Immediate MVP

- Treating any one runtime as universal default.
- Treating raw Ollama or LM Studio endpoints as primary app runtimes.
- Public, unauthenticated desktop access.
- Background desktop control without user-visible state.
- Mandatory cloud-hosted agent runtime.
- Full mobile-native apps beyond web/cloud channel access.
- Advanced 3D avatar rendering.
