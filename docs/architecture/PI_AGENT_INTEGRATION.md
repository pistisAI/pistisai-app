# Pi Agent Integration — Deep Research & Plan

> **Status:** Research phase (not yet approved for implementation)
> **Author:** Zoid (with Christopher)
> **Created:** 2026-09-06
> **Revised:** 2026-09-07 (v7 — consolidated: desktop control, SDK, systemd, watchdog, accountability)
> **Location:** `docs/architecture/PI_AGENT_INTEGRATION.md`

---

## Table of Contents

1. [Three Roles — Clarified](#three-roles--clarified)
2. [Two Pi Distinctions](#two-pi-distinctions)
3. [Technology Stack](#technology-stack)
4. [Architecture](#architecture)
5. [Deep Research Findings](#deep-research-findings)
6. [Safety Boundaries](#safety-boundaries)
7. [Implementation Phases](#implementation-phases)
8. [Open Questions](#open-questions)

---

## Three Roles — Clarified

| Role | User-facing? | Always-on? | What |
|------|-------------|------------|------|
| **Harness** | Yes — primary chat when selected | No — only when user picks Pi | Pi is the user's conversation engine |
| **Watcher** | No — surfaces to Christopher | Yes — systemd on VPS | Monitors ALL agent instances |
| **Subagent** | No — reports to spawning harness | No — on-demand | Does focused coding work |

**Key insight:** These are NOT the same process. The harness is a Pi session in the Flutter app. The watcher is a separate always-on Pi session on the VPS. Subagents are short-lived Pi print-mode invocations.

---

## Two Pi Distinctions

### Pi as Harness (in-app, on-demand)
- **Installed:** `oh-my-pi` (omp) — the FULL extension ecosystem
- **Model:** Borrows from the **currently active agent harness**
- **Why oh-my-pi:** Full IDE-grade tooling (LSP, debugger, browser, subagents)

### Pi as Watcher (VPS, always-on)
- **Installed:** Base `pi` (minimal)
- **Model:** Local llama.cpp with Gemma 4 E4B (or free tier fallback)
- **Tools:** Few modules only — health checks, notifications, A2A
- **Runs as:** systemd service with watchdog

---

## Technology Stack

### Inference
- **Runtime:** llama.cpp (NOT Ollama) — Christopher wants the control
- **Model:** Gemma 4 E4B-it Q4_K_M (5.4GB VRAM, fits RTX 4070 12GB)
- **Multimodal:** mmproj-BF16.gguf for vision/audio (desktop control)
- **Server:** `llama-server` at `127.0.0.1:8080` (OpenAI-compatible API)

### Agent
- **Base:** `@earendil-works/pi-coding-agent` (already installed at `/home/zoid/.local/bin/pi`)
- **Harness fork:** `oh-my-pi` (can1357) — installed on-demand when Pi selected
- **A2A mesh:** `@bacnh85/pi-a2a` extension (A2A v1.0, Hermes interop)
- **Desktop control:** `@agent-sh/computer-use-linux` (MCP server, Wayland-first)

### Integration
- **Pi ↔ llama.cpp:** Built-in `llamacpp` provider — zero config
- **Pi ↔ Flutter:** RPC mode (JSONL over stdin/stdout) OR SDK (`createAgentSession`)
- **Pi ↔ Mesh:** `@bacnh85/pi-a2a` extension
- **Subagents:** `pi-subagents` extension (scout/worker/reviewer/oracle)

### Infrastructure
- **Watcher:** systemd service with WatchdogSec
- **Accountability:** Cron-based heartbeat (pattern from elencho-accountability-cron skill)
- **Host:** server-pistisai (VPS) for watcher, right-pc (desktop) for harness

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        right-pc (Desktop)                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Flutter App (pistisai)                        │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │   │
│  │  │   Hermes     │  │   OpenClaw   │  │   Pi          │      │   │
│  │  │   Adapter    │  │   Adapter    │  │   Adapter     │      │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘      │   │
│  │         │                │                │               │   │
│  │         └────────────────┴────────────────┘               │   │
│  │                          │                                │   │
│  │                   RouterServer                             │   │
│  │                   (ProviderType enum)                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│         ┌────────────────────┼────────────────────┐             │
│         │                    │                    │             │
│  ┌──────▼──────┐   ┌────────▼───────┐   ┌───────▼──────────┐ │
│  │ llama-server │   │ computer-use-  │   │ oh-my-pi          │ │
│  │ (Gemma 4 E4B)│   │ linux (MCP)    │   │ extensions        │ │
│  │ :8080        │   │ screenshots,   │   │ LSP, debugger,    │ │
│  │              │   │ clicks, typing │   │ browser, etc.     │ │
│  └──────────────┘   └────────────────┘   └──────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        server-pistisai (VPS)                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          Pi Watcher (systemd service)                      │   │
│  │  - Always-on background observer                           │   │
│  │  - Local llama.cpp or free model                           │   │
│  │  - Few modules: health check, A2A, notifications           │   │
│  │  - Heartbeat cron → accountability questions                │   │
│  │  - A2A peer: @bacnh85/pi-a2a extension                     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                    ┌─────────▼──────────┐                       │
│                    │   A2A Mesh          │                       │
│                    │   (port 9910)       │                       │
│                    │   ↔ Hermes (9900)   │                       │
│                    │   ↔ Elencho (9901)  │                       │
│                    └────────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

### Desktop Control Flow

```
User: "Click the Firefox icon"
  → Pi (harness) calls screenshot tool
  → computer-use-linux captures screen → returns PNG
  → mmproj encodes image → Gemma 4 E4B analyzes
  → Pi calls click(x, y) tool
  → computer-use-linux executes via AT-SPI/ydotool
  → Desktop action completed
```

### Watcher Accountability Flow

```
Every 15-30 min (cron):
  → Pi watcher reads heartbeat files
  → Checks: service health, agent liveness, drift signals
  → If anomaly detected:
    L1: Log + self-correct
    L2: A2A message to peer agent for second opinion
    L3: Surface question to Christopher (via Telegram/notification)
```

---

## Deep Research Findings

### 1. Pi RPC Protocol (for Harness Integration)

**Source:** [pi.ubitools.com/rpc](https://pi.ubitools.com/rpc/) + [pi-agent-docs.pages.dev/rpc](https://pi-agent-docs.pages.dev/rpc/) — full protocol spec (33,463 chars)

- JSONL framing over stdin/stdout
- LF (`\n`) is the ONLY record delimiter
- Commands: `prompt`, `abort`, `new_session`, `resume`, `fork`, `compact`
- Events: `message_update`, `tool_call`, `tool_result`, `session_info`
- **Dart mapping:** `dart:io` `Process.start` + line-delimited JSONL

### 2. Pi SDK (Alternative to RPC)

**Source:** [pi.dev/docs/latest/sdk](https://pi.dev/docs/latest/sdk) + [oh-my-pi/sdk.md](https://github.com/can1357/oh-my-pi/blob/main/docs/sdk.md)

```typescript
import { createAgentSession, SessionManager } from "@earendil-works/pi-coding-agent";

const { session } = await createAgentSession({
  sessionManager: SessionManager.inMemory(),
  model: myModel,
  tools: [readTool, bashTool],
});

session.subscribe((event) => {
  if (event.type === "message_update") {
    // stream tokens
  }
});

await session.prompt("Fix the login bug");
```

**Decision:** Flutter app uses **RPC mode** (subprocess), not SDK. Reason: Dart can't import TypeScript SDK directly. RPC gives clean process isolation.

### 3. Pi ↔ llama.cpp Wiring

**Source:** [pi.dev/docs/latest/settings](https://pi.dev/docs/latest/settings)

**Critical finding:** Pi has built-in llama.cpp provider support:

```bash
# Auto-discovers llama-server at default URL
pi --provider llamacpp --model google_gemma-4-E4B-it -p "Hello"
```

- Default base URL: `http://127.0.0.1:8080`
- API type: `openai-responses`
- Auth: keyless
- Auto-discovers models via `GET /models`

**For custom config** (`~/.pi/agent/models.json`):
```json
{
  "providers": {
    "llamacpp": {
      "baseUrl": "http://127.0.0.1:8080/v1",
      "api": "openai-completions",
      "apiKey": "none",
      "models": [{
        "id": "gemma-4-E4B-it",
        "name": "Gemma 4 E4B (local)",
        "contextWindow": 32768,
        "reasoning": false
      }]
    }
  }
}
```

### 4. llama.cpp Build & Run (RTX 4070)

RTX 4070 = Ada Lovelace = compute capability 8.9 (sm_89)

```bash
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89
cmake --build build --config Release -j $(nproc)
```

**llama-server launch:**
```bash
# Multimodal mode (for desktop control)
llama-server \
  -hf bartowski/google_gemma-4-E4B-it-GGUF:Q4_K_M \
  --mmproj mmproj-BF16.gguf \
  -ngl 99 \
  -c 32768 \
  --host 127.0.0.1 \
  --port 8080
```

### 5. Gemma 4 E4B Model

**Source:** [HuggingFace](https://huggingface.co/bartowski/google_gemma-4-E4B-it-GGUF) + [Smeltcore recipes](https://smeltcore.com/recipes/gemma-4-e4b-on-rtx-4070)

| Spec | Value |
|------|-------|
| Effective params | 4.5B |
| Total (with embeddings) | 8B |
| Modalities | text + image + audio |
| Q4_K_M size | 5.41 GB |
| Q8_0 size | 8.03 GB |
| BF16 size | 15.05 GB |
| Min RAM | 8 GB |
| Speed (12GB card) | ~45 tok/s |
| License | Apache-2.0 |

**Why Gemma 4 E4B:**
- Multimodal (can SEE desktop via screenshots)
- Tiny (fits anything, runs fast)
- Apache 2.0 (commercial-friendly)
- Tool calling confirmed with llama.cpp `--jinja` mode

### 6. Desktop Control: computer-use-linux

**Source:** [pi.dev/packages/@agent-sh/computer-use-linux](https://pi.dev/packages/@agent-sh/computer-use-linux) (32,594 chars)

Rust MCP server for Linux desktop control:
- **Screenshots:** GNOME DBus → portal → fallback chain
- **Input:** click, drag, scroll, press_key, type_text
- **Window management:** activate, move, resize
- **Semantic selectors:** AT-SPI (role/name/text/states), not pixel coords
- **Wayland-first:** org.freedesktop.portal.RemoteDesktop + ydotool fallback
- **Compositor support:** GNOME, KDE/KWin, Hyprland, i3, COSMIC

**MCP Tools:** `doctor`, `screenshot`, `click`, `drag`, `scroll`, `press_key`, `type_text`, `perform_action`, `set_value`, `activate_window`, `move_window`, `resize_window`, `list_apps`, `list_windows`, `focused_window`, `get_app_state`

**Install:** `pi install npm:@agent-sh/computer-use-linux`

### 7. A2A Mesh: @bacnh85/pi-a2a

**Source:** [pi.dev/packages/@bacnh85/pi-a2a](https://pi.dev/packages/@bacnh85/pi-a2a) (13,292 chars)

- A2A v1.0 spec compliant
- Hermes interop out of the box
- Default port: 9910
- Token-gated remote access
- Output redaction, injection filtering
- Anti-loop: 3-hop max

### 8. oh-my-pi Extension API

**Source:** [github.com/can1357/oh-my-pi/docs/extensions.md](https://github.com/can1357/oh-my-pi/blob/main/docs/extensions.md) (743 lines)

Extension capabilities:
- `pi.registerTool()` — LLM-callable tools with Zod schemas
- `pi.on("tool_call")` — intercept/block tool calls
- `pi.on("tool_result")` — observe results
- `pi.setInterval()` — recurring tasks (errors contained)
- `pi.sendMessage()` — inject messages (deliverAs: "steer" | "nextTurn" | "followUp")
- `pi.appendEntry()` — persistent state across sessions

**For the watcher observer extension:**
```typescript
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export default function observerExtension(pi: ExtensionAPI) {
  const z = pi.zod;

  // Health check every 5 minutes
  pi.setInterval(async () => {
    const health = await checkAgentHealth();
    if (health.status !== "ok") {
      pi.sendMessage({
        role: "assistant",
        content: `⚠️ Health anomaly: ${health.summary}`,
        deliverAs: "steer",
      });
    }
  }, 300_000);

  // Tool for manual health check
  pi.registerTool({
    name: "check_health",
    label: "Check Health",
    description: "Check health of all agent instances",
    parameters: z.object({}),
    async execute() {
      const health = await checkAgentHealth();
      return { content: [{ type: "text", text: JSON.stringify(health, null, 2) }] };
    },
  });
}
```

### 9. systemd Service Pattern

**Source:** [simplified.guide](https://simplified.guide/llama-cpp/server-run-systemd-service) + [NixOS llama-server module](https://ramdi.fr/post/ai-llm/local-llm-nixos-llama-server-module)

**llama-server systemd unit:**
```ini
[Unit]
Description=llama.cpp inference server (CUDA)
After=network.target

[Service]
Type=exec
User=llama
Group=llama
WorkingDirectory=/srv/llama
ExecStart=/usr/local/bin/llama-server \
  -m /srv/llama/models/gemma-4-E4B-it-Q4_K_M.gguf \
  --mmproj /srv/llama/models/mmproj-BF16.gguf \
  -ngl 99 -c 32768 \
  --host 127.0.0.1 --port 8080
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

**Pi watcher systemd unit (with watchdog):**
```ini
[Unit]
Description=Pi Agent Watcher (always-on observer)
After=network.target llama-server.service
Requires=llama-server.service

[Service]
Type=notify
User=zoid
Group=zoid
WorkingDirectory=/dev/pistisai
ExecStart=/home/zoid/.local/bin/pi \
  --provider llamacpp \
  --model google_gemma-4-E4B-it \
  --extension /dev/pistisai/watcher/observer-extension.ts
Restart=always
RestartSec=10
WatchdogSec=60
NotifyAccess=all

# Resource limits
MemoryMax=2G
CPUQuota=50%

# Security
ProtectSystem=strict
ReadWritePaths=/dev/pistisai /home/zoid/.pi /tmp
PrivateTmp=true
NoNewPrivileges=true
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
```

**Watchdog mechanism:**
- systemd sends `sd_notify("WATCHDOG=1")` every 30s from Pi extension
- If systemd doesn't receive heartbeat in 60s → SIGABRT → restart
- Catches hung processes (not just crashed)

### 10. Watchdog / Accountability Pattern

**Source:** [dev.to Watchdog Pattern](https://dev.to/meridian-ai/the-watchdog-pattern-how-to-build-ai-systems-that-fix-themselves) + [ricotan.com Heartbeat](https://ricotan.com/heartbeat-architecture-monitor-ai-agent) + [therealcat.ai](https://therealcat.ai/lab-notes-when-your-agent-learns-to-lie-about-working) + [elencho-accountability-cron skill](skill:elencho-accountability-cron)

**Lessons from production agent monitoring:**

1. **Silent failure is worse than crash.** An agent that's running but stuck in a loop is invisible to traditional monitoring.
2. **Self-report is unreliable.** Agents learn to say "all good" while doing nothing (Goodhart's Law).
3. **Diff-only output.** If nothing changed, return `HEARTBEAT_OK`. No noise.
4. **Independent observers.** Multiple watchers with different perspectives catch what one misses.
5. **Read-only heartbeats.** Cron sessions that can mark tasks "done" without doing them is a foot-gun.

**Layered oversight model:**

| Layer | What | Action |
|-------|------|--------|
| **L1: Passive** | Pi extension monitors tool calls, results, timing | Log + self-correct |
| **L2: Active** | Cron heartbeat checks health, cross-references with A2A peer | A2A message to peer agent |
| **L3: Intervention** | Anomaly detected, peer confirms | Surface question to Christopher |

**Accountability question format (from elencho pattern):**
```
🪞 [One pointed question about a specific drift signal]
```

Not a report. A question. Forces engagement without noise.

### 11. pi-skills Ecosystem

**Source:** [PSPDFKit-labs/pi-skills](https://github.com/PSPDFKit-labs/pi-skills) + [awesome-pi-agent](https://github.com/qualisero/awesome-pi-agent)

Relevant packages for our use:
- `pi-self` — `pi_run` tool for spawning pi subprocesses (subagent pattern)
- `cronjob` — `/cron` command for scheduled prompts
- `notify` — desktop notification when agent finishes
- `ssh` — delegate all tools to remote machine via SSH
- `loop` — keep follow-up loop running until breakout condition
- `@agent-sh/computer-use-linux` — desktop control (MCP)
- `brave-search` — web search
- `gmcli` — Gmail integration

### 12. Hardware Compatibility

**Christopher's PC (right-pc, CachyOS):**

| Component | Spec | Verdict |
|-----------|------|---------|
| CPU | Intel i5-13600KF (14c/20t) | ✅ Excellent |
| GPU | RTX 4070 (12GB VRAM, sm_89) | ✅ Great for local LLM |
| RAM | 62GB (48GB free) | ✅ Massive headroom |
| Disk | 399GB free | ✅ Plenty of room |
| CUDA | Driver 580.159 + CUDA 13 toolkit | ✅ Ready |
| Bun | 1.4.2 installed | ✅ Exceeds 1.3.14 min |

**Minimum for other users:**

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| GPU | 6GB VRAM (RTX 3060, RTX 4060) | 12GB (RTX 4070) |
| RAM | 16 GB | 32 GB |
| Disk | 10 GB free | 20 GB |
| CUDA | 12.x driver | 12.8+ |
| Bun | 1.3.14+ | 1.4.x |

---

## Safety Boundaries

### Pi Can:
- Read files, explore, organize, learn
- Run health checks on services
- Restart paused/crashed agent instances
- Send notifications to Christopher
- Communicate with peer agents via A2A
- Control desktop (when user explicitly directs)

### Pi Must NEVER:
- Rewrite its own identity or system prompt
- Modify another agent's system prompt or identity
- Touch secrets, credentials, or auth tokens
- Modify safety boundaries without explicit human approval
- Self-escalate privileges (sudo, chmod, etc.)
- Install system packages without approval

### Desktop Control Safety:
- `computer-use-linux` marks tools with `destructiveHint=true`
- MCP hosts should ask user before destructive actions
- Screenshot data stays local (never uploaded)
- All desktop actions are logged

---

## Implementation Phases

### Phase 1: Pi as Harness (GitHub #285)
**Goal:** Pi selectable as agent harness in Flutter app

1. Add `ProviderType.pi` to enum
2. Create `PiRpcClient` (Dart subprocess + JSONL)
3. Create `PiAdapter` implementing `BaseProvider`
4. Wire into RouterServer + DI locator
5. Add UI: provider selection screen shows "Pi"
6. Model routing: Pi borrows model from active harness

**Dependencies:** None (pure Dart + existing Pi install)
**Estimated:** 2-3 days

### Phase 2: llama.cpp Infrastructure (NEW)
**Goal:** Local inference running on right-pc

1. Build llama.cpp with CUDA sm_89
2. Download Gemma 4 E4B-it Q4_K_M + mmproj
3. Create systemd unit for llama-server
4. Test Pi ↔ llama.cpp connection
5. Install computer-use-linux for desktop control

**Dependencies:** None
**Estimated:** 1 day (mostly automated)

### Phase 3: Pi as Watcher (GitHub #286)
**Goal:** Always-on background observer on VPS

1. Create observer extension (health checks, notifications)
2. Create systemd unit with watchdog
3. Configure llama-server on VPS (or free tier fallback)
4. Set up heartbeat cron
5. Test: kill an agent → watcher detects → notifies

**Dependencies:** Phase 2 (llama.cpp pattern)
**Estimated:** 2-3 days

### Phase 4: Pi as Subagent (GitHub #287)
**Goal:** On-demand coding delegate

1. Implement `pi_run` tool (spawns pi subprocess)
2. Create subagent task protocol (JSON over stdin/stdout)
3. Add attribution in chat ("via Pi subagent")
4. Test: Hermes spawns Pi → Pi fixes bug → reports back

**Dependencies:** Phase 1 (RPC client)
**Estimated:** 1-2 days

### Phase 5: Watcher L2-L3 + Mesh (GitHub #288)
**Goal:** A2A peer communication + accountability

1. Install @bacnh85/pi-a2a on watcher
2. Configure A2A peers (Hermes, Elencho)
3. Implement L2: cross-agent health verification
4. Implement L3: escalation to Christopher
5. Test full chain: anomaly → peer confirm → notification

**Dependencies:** Phase 3 (watcher)
**Estimated:** 2-3 days

### Phase 6: Desktop Control (NEW)
**Goal:** Pi can see and control the desktop

1. Install computer-use-linux MCP
2. Configure Pi to use MCP tools
3. Test: screenshot → analyze → click/type
4. Add safety gates (confirm before destructive)

**Dependencies:** Phase 2 (mmproj), Phase 1 (Pi harness)
**Estimated:** 1-2 days

---

## Open Questions

1. **Model for watcher:** Gemma 4 E4B confirmed for harness/desktop. Watcher could use same model OR a cheaper/free tier. Decision: same model for simplicity, free tier as fallback.
2. **Observer location:** oh-my-pi extension (inside Pi) vs standalone Dart service vs systemd timer? Leaning: oh-my-pi extension for L1, cron for L2, A2A for L3.
3. **oh-my-pi install flow:** How does Flutter app trigger oh-my-pi install on PC? SSH command? Bundled installer?
4. **Subagent attribution:** "via Pi subagent" — inline badge or separate message?
5. **A2A port conflict:** pi-a2a default 9910, Hermes 9900, Elencho 9901. No conflict but verify.
6. **Desktop control safety:** Should every desktop action require user confirmation, or only destructive ones?
7. **VPS llama.cpp:** Does the VPS have a GPU? If not, watcher uses free tier or CPU inference.

---

## Key Research Sources

- [Pi RPC Mode](https://pi.ubitools.com/rpc/) — full protocol spec
- [Pi RPC Mode (mirror)](https://pi-agent-docs.pages.dev/rpc/) — alternate host
- [Pi SDK](https://pi.dev/docs/latest/sdk) — programmatic embedding
- [oh-my-pi SDK](https://github.com/can1357/oh-my-pi/blob/main/docs/sdk.md) — Bun/Node embedding
- [@bacnh85/pi-a2a](https://pi.dev/packages/@bacnh85/pi-a2a) — A2A extension
- [pi-subagents](https://pi.dev/packages/pi-subagents) — sub-agent delegation
- [oh-my-pi](https://github.com/can1357/oh-my-pi) — full IDE-grade fork
- [oh-my-pi extensions.md](https://github.com/can1357/oh-my-pi/blob/main/docs/extensions.md) — extension API (743 lines)
- [@agent-sh/computer-use-linux](https://pi.dev/packages/@agent-sh/computer-use-linux) — desktop control MCP
- [PSPDFKit-labs/pi-skills](https://github.com/PSPDFKit-labs/pi-skills) — skill/extension catalog
- [awesome-pi-agent](https://github.com/qualisero/awesome-pi-agent) — community package list
- [Gemma 4 E4B-it GGUF](https://huggingface.co/bartowski/google_gemma-4-E4B-it-GGUF) — model quants
- [Gemma 4 E4B on RTX 4070](https://smeltcore.com/recipes/gemma-4-e4b-on-rtx-4070) — hardware recipe
- [Pi settings: llama.cpp provider](https://pi.dev/docs/latest/settings) — built-in wiring
- [llama.cpp + systemd](https://simplified.guide/llama-cpp/server-run-systemd-service) — service pattern
- [NixOS llama-server module](https://ramdi.fr/post/ai-llm/local-llm-nixos-llama-server-module) — declarative config reference
- [Watchdog Pattern](https://dev.to/meridian-ai/the-watchdog-pattern-how-to-build-ai-systems-that-fix-themselves) — self-healing agents
- [Heartbeat Architecture](https://ricotan.com/heartbeat-architecture-monitor-ai-agent) — agent monitoring
- [Agent Lies About Working](https://therealcat.ai/lab-notes-when-your-agent-learns-to-lie-about-working) — Goodhart's Law in agents
- [elencho-accountability-cron](skill:elencho-accountability-cron) — accountability pattern
- [Pistisai provider architecture](/dev/pistisai/pistisai-app/lib/services/providers/) — integration point
