# PistisAI user guide

PistisAI is a desktop hub for a Hermes-based agent, plus skills. The agent runs on a local machine at the client's site. A free readiness audit checks whether the current PC can host it. If not, IAClé provides a dedicated Beelink GTi15 mini PC. IAClé is the Quebec company that delivers this same stack. See [Product](../PRODUCT.md).

The setup wizard chooses the agent runtime. Hermes is the agent runtime. OpenClaw is also supported.

Ollama and LM Studio are optional support providers for memory, embeddings, summarization, classification, OCR cleanup, and speech. They are not the agent. Online language models can do heavy work when you agree, and for Quebec clients that path has to fit Law 25.

Sign-in is only for tunnel and sync. See [Tunnel and sync sign-in](../development/TUNNEL_SIGN_IN.md).

---

## Overview

Pistisai is organized around core capabilities:

1. **Secure Agent Channel** - The main window is a direct, low-friction channel to the selected agent runtime.
2. **Avatar And Voice Companion** - A sidecar companion window for avatar presence and voice interaction.
3. **Desktop Control** - Permissioned hands-on access to the current desktop.
4. **Vision** - Screen, region, OCR, and camera understanding.
5. **Agent Runtime Management** - Runtime discovery, health, tools, sessions, and agent lifecycle.
6. **Local Intelligence Support** - Optional local model providers for app-owned memory and background features.
7. **Secure Device Mesh** - Tailscale-first connectivity and optional cloud sync across your devices.

Agent management is still available, but it is not the first thing in the interface. The first screen should feel like a secure conversation path to the active agent runtime.

---

## Getting Started

### First Run

When you first launch Pistisai, the setup wizard guides you through the decisions that matter:

1. **Choose an agent runtime**
   - Hermes on the local machine at the site (current PC, or the dedicated mini PC)
   - OpenClaw Gateway
   - Compatible custom agent gateway

2. **Choose where the agent runtime lives**
   - This computer
   - The dedicated mini PC at the site, when the current PC cannot host the agent
   - A machine on your own Tailscale network (Business and Enterprise)

3. **Test the agent connection**
   - The wizard checks health, sessions, tools, streaming, and exposed capabilities.
   - Hermes is the first agent runtime path to validate during current testing.

4. **Optionally configure local model support**
   - Ollama, LM Studio, or a custom local model endpoint can support memory and background intelligence.
   - These providers do not become the main agent endpoint.

5. **Set desktop permissions**
   - Desktop control, clipboard, file actions, vision, and command execution are enabled per device.
   - Remote devices cannot receive desktop actions unless that device grants them.

6. **Enable optional sync**
   - Conversation state and presence can sync between installed devices.
   - Local desktop permissions and action approvals remain device-scoped.

### Agent Runtime Discovery

The app can discover or configure agent runtimes:

| Runtime | Typical Endpoint | Notes |
| --- | --- | --- |
| Hermes | `127.0.0.1:8642` (wizard-configured) | First agent runtime path for current testing |
| OpenClaw Gateway | `localhost:18789` | Supported original integration |
| Custom agent gateway | User supplied | Private compatible agent runtime |

### Support Model Discovery

Optional local model providers are configured separately:

| Provider | Typical Endpoint | Use |
| --- | --- | --- |
| LM Studio | `localhost:1234` | Local model support for app features |
| Ollama | `localhost:11434` | Local model support for memory/background features |
| Custom model endpoint | User supplied | Local support model provider |

---

## Secure Agent Channel

The main app window is the direct channel to the selected agent runtime.

### Chat Features

- Streaming responses
- Conversation history
- Agent session selection when the runtime exposes sessions
- Model selection only when exposed by the active agent runtime
- Search across conversations
- Import and export
- Runtime status and connection health

### Runtime Switching

Agent runtime management lives behind settings, setup, and management views. Use it to:

- Add or remove agent runtime endpoints
- Test health and streaming
- Inspect active agent sessions
- Review available tools and capabilities
- Configure optional local model providers for app support features

---

## Avatar And Voice Companion

The avatar and voice companion are one feature surface. The companion can appear as a sidecar or pop-out window, so it can stay open beside the main app or another desktop workflow.

### Companion Features

- Avatar state: idle, listening, thinking, speaking, working, error
- Voice conversation mode
- Push-to-talk and planned wake/listening flows
- Text-to-speech through the selected agent runtime or Pistisai fallback services
- Personality, memory, and evolution features as they mature

The companion should not replace the main secure channel. It provides presence, voice, and side conversation while the main window remains focused on the active agent runtime conversation.

---

## Desktop Control

Desktop control is a core feature. It gives the selected agent runtime controlled hands-on capability on the current device.

### Capabilities

- Screenshot capture
- Region capture
- Vision analysis
- Click, type, and keyboard actions
- Clipboard actions
- Window management
- System notifications
- Command execution when explicitly enabled

### Safety Model

- Desktop actions are local to the device granting permission.
- The agent runtime can request actions; the local app approves, executes, and audits them.
- Visual indicators show when automation or capture is active.
- Sensitive actions should require explicit user approval.
- Action history should be reviewable.
- Cloud sync does not imply permission to control every synced device.
- Local model providers never receive desktop-control authority.

---

## Vision

Vision features let the active agent runtime understand what is on the current device.

- Full-screen capture
- Region capture
- OCR and text extraction
- Camera input where supported
- Continuous watch modes for selected regions

Vision permissions are per device and should be visible while active.

---

## Secure Device Mesh

Pistisai is designed to be installed on all your devices and kept in sync.

The desktop app is the hub. Free-tier sync uses the tunnel at `api.pistisai.app` (Cloudflare Access). Business and Enterprise use the customer's Tailscale network or VPN.

### Typical layouts

- The desktop app connects to Hermes on the same computer.
- The dedicated mini PC at the site runs Hermes or OpenClaw, and the hub reaches it on the local network.
- Phone or web connects through the desktop hub.
- Ollama or LM Studio, if you use them, stay support providers for memory and background features.

### What Syncs

- Conversation state
- Agent runtime presence
- Device availability
- Avatar state and preferences
- Non-sensitive settings selected for sync

### What Stays Device-Scoped

- Desktop control permissions
- Clipboard access
- File access
- Screen and camera capture
- Shell command permissions
- Runtime secrets and local tokens unless explicitly stored in an approved secure vault

---

## Settings

### Agent Runtime Settings

- Add, remove, and test agent runtime endpoints
- Configure Hermes, OpenClaw, or a custom agent gateway on the local machine at the site
- Set preferred agent runtime per device
- Review detected capabilities

### Local Model Provider Settings

- Configure Ollama, LM Studio, or a custom local model endpoint.
- Choose which app-owned features may use local model support.
- Keep local model providers separate from the main agent channel.

### Companion Settings

- Show or hide avatar
- Open companion sidecar
- Configure voice mode
- Choose text-to-speech voice when available

### Mesh And Cloud Settings

- Free tier: pistisai.app tunnel with Cloudflare Access
- Business and Enterprise: your Tailscale network or VPN
- Review connected devices
- Enable or disable conversation sync

### Privacy

- Offline mode
- Local-only storage
- Per-device desktop permissions
- Data export and deletion

---

## Troubleshooting

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

### Agent Runtime Not Found

- Confirm the agent runtime is running.
- Check the endpoint and port in runtime settings.
- Use the setup wizard connection test.
- For remote devices, check that both devices are on the expected Tailscale tailnet.
- Do not use raw Ollama or LM Studio endpoints as the agent runtime.

### Connection Lost

- Check agent runtime health.
- Verify Tailscale status for remote agent runtime paths.
- Re-run the wizard connection test.
- Switch to another configured agent runtime if available.

### Desktop Control Not Working

- Confirm desktop permissions were granted on that specific device.
- Check platform support for the requested action.
- Verify that the desktop control service is running.
- Review action approvals and denied permissions.

### Voice Companion Not Working

- Confirm the companion window is open.
- Check microphone permission where voice input is enabled.
- Verify that the agent runtime or fallback TTS service supports speech output.

---

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Ctrl + N` | New conversation |
| `Ctrl + /` | Focus search |
| `Ctrl + S` | Open settings |
| `Escape` | Close modal or drawer |
