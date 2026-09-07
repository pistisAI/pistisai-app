# Pi Agent Integration — Deep Research & Plan

> **Status:** Research phase (not yet approved for implementation)
> **Author:** Zoid (with Christopher)
> **Created:** 2026-09-06
> **Revised:** 2026-09-07 (v5 — oh-my-pi extension API, systemd watchdog, pi-a2a config)
> **Location:** `docs/architecture/PI_AGENT_INTEGRATION.md`

---

## Table of Contents

1. [Three Roles — Clarified](#three-roles--clarified)
2. [Two Pi Distinctions — Key Insight](#two-pi-distinctions)
3. [Research Findings](#research-findings)
   - [Pi RPC Protocol (for Harness)](#pi-rpc-protocol)
   - [Pi A2A Extension (for Watcher L2-L3)](#pi-a2a-extension)
   - [oh-my-pi vs @earendil-works/pi](#oh-my-pi-vs-earendil-works)
   - [Local LLM Options (for Watcher)](#local-llm-options)
   - [Pistisai Provider Architecture (integration point)](#pistisai-provider-architecture)
4. [Architecture](#architecture)
5. [Safety Boundaries](#safety-boundaries)
6. [Implementation Phases](#implementation-phases)
7. [Open Questions](#open-questions)

---

## Three Roles — Clarified

| Role | User-facing? | Always-on? | What |
|------|-------------|------------|------|
| **Harness** | Yes — primary chat when selected | No — only when user picks Pi | Pi is the user's conversation engine |
| **Watcher** | No — surfaces to Christopher | Yes — systemd on VPS | Monitors ALL agent instances (including Pi itself) |
| **Subagent** | No — reports to spawning harness | No — on-demand | Does focused coding work, reports back |

**Key insight:** These are NOT the same process. The harness is a Pi session in the Flutter app. The watcher is a separate always-on Pi session on the VPS. Subagents are short-lived Pi print-mode invocations.

---

## Two Pi Distinctions — Key Insight

There are **two fundamentally different Pi setups** in this architecture:

### Pi as Harness (in-app, on-demand)
- **Installed:** `oh-my-pi` (omp) — the FULL extension ecosystem
- **Model:** Borrows from the **currently active agent harness**
  - If Hermes is active → Pi uses Hermes's model/API
  - If OpenClaw is active → Pi uses OpenClaw's backend
  - Pi is a *consumer* of whatever LLM the main harness provides
- **Why oh-my-pi:** When you select Pi as your agent, you want the full IDE-grade tooling (LSP, debugger, hash-anchored edits, browser, subagents). This is the "full experience" you deliberately choose.
- **Only installed when:** User selects Pi as harness in the app

### Pi as Watcher (VPS, always-on)
- **Installed:** Minimal `@earendil-works/pi-coding-agent` (base Pi)
- **Model:** **Local or free model** — self-sufficient, doesn't compete with the main harness
  - llama.cpp server with a small tool-calling model (Qwen 3.6 7B Q4_K_M or similar)
  - Or a free tier from OpenRouter / similar
- **Why minimal:** The watcher only needs a few modules — health checks, A2A queries, anomaly reporting. No need for LSP, debugger, browser, etc.
- **Always running:** systemd unit on server-pistisai

### Summary Table

| | Harness Pi | Watcher Pi |
|---|---|---|
| **Install** | oh-my-pi (full) | @earendil-works/pi (minimal) |
| **Where** | In the Flutter app | VPS systemd service |
| **Model** | Borrows from active harness | Local/free (llama.cpp) |
| **Tools** | Full IDE-grade (LSP, debugger, etc.) | Few modules only |
| **When** | Only when user selects Pi | Always running |
| **Purpose** | Full coding agent experience | Health monitoring + accountability |

---

## Research Findings

### Pi RPC Protocol

**Source:** [pi.ubitools.com/rpc](https://pi.ubitools.com/rpc/) + [pi-agent-docs.pages.dev/rpc](https://pi-agent-docs.pages.dev/rpc/)

Pi's RPC mode is the designed embedding pattern for non-Node clients. It runs as a subprocess communicating via **JSONL over stdin/stdout**.

**Starting:** `pi --mode rpc [options]`

**Framing rules (critical for Dart implementation):**
- Strict JSONL: LF (`\n`) is the ONLY record delimiter
- Strip trailing `\r` from `\r\n` input
- Do NOT use generic line readers that split on U+2028/U+2029 (valid inside JSON strings)
- Node `readline` is explicitly NOT protocol-compliant

**Commands (stdin → Pi):**

| Command | What | Key Fields |
|---------|------|-----------|
| `prompt` | Send user message | `message`, `streamingBehavior?` |
| `steer` | Interrupt mid-run | `message` |
| `follow_up` | Queue after done | `message` |
| `abort` | Cancel current op | — |
| `new_session` | Fresh session | `parentSession?` |
| `get_state` | Session state | Returns model, thinkingLevel, isStreaming, messageCount |
| `get_messages` | Full history | Returns AgentMessage[] |
| `set_model` | Switch model | `provider`, `modelId` |
| `get_available_models` | List models | — |
| `set_thinking_level` | Reasoning level | `level` (off..max) |
| `bash` | Run shell command | `command` — output on NEXT prompt |
| `compact` | Compress context | `customInstructions?` |
| `get_session_stats` | Token/cost usage | Returns full usage stats |

**Events (stdout → Dart, no `id` field):**

| Event | What |
|-------|------|
| `agent_start` / `agent_end` | Processing begins/ends |
| `turn_start` / `turn_end` | One assistant response + tool calls |
| `message_update` | **Streaming deltas** (text_delta, thinking_delta, toolcall_delta) |
| `tool_execution_start` / `_update` / `_end` | Tool progress |
| `compaction_start` / `_end` | Context compression |

**Python reference client (from docs):**
```python
proc = subprocess.Popen(["pi", "--mode", "rpc", "--no-session"],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
proc.stdin.write(json.dumps({"type": "prompt", "message": "Hello"}) + "\n")
proc.stdin.flush()
for line in proc.stdout:
    event = json.loads(line)
    if event.get("type") == "message_update":
        delta = event.get("assistantMessageEvent", {})
        if delta.get("type") == "text_delta":
            print(delta["delta"], end="", flush=True)
```

**Key insight for Dart:** The `dart:io` Process class + manual buffer splitting on `\n` (not readline) gives us exactly what we need. Maps directly to the Python reference.

### Pi A2A Extension

**Source:** [@bacnh85/pi-a2a on pi.dev](https://pi.dev/packages/@bacnh85/pi-a2a)

- **Version:** 0.7.6 (Sep 2026), 1,339 downloads/mo
- **Protocol:** A2A v1.0 — JSON-RPC 2.0 over HTTP
- **Zero runtime deps** — pure Node.js stdlib + global fetch
- **Hermes interop works out of the box** — same wire format bidirectionally
- **Security model ported from Hermes:** localhost-default bind, token-gated remote, outbound redaction, inbound injection filtering, audit log, anti-loop
- **Inbound = isolated sessions:** A2A tasks spawn isolated Pi agent sessions, NOT the interactive TUI

**Configuration** (`~/.pi/agent/settings.json`):
```json
{
  "a2a": {
    "peers": {
      "hermes_desktop": {
        "url": "http://<tailscale-ip>:9900",
        "auth": { "type": "bearer", "token": "..." },
        "timeout": 120
      }
    },
    "server": { "enabled": false, "port": 9910, "host": "127.0.0.1" }
  }
}
```

### oh-my-pi vs @earendil-works/pi

| | @earendil-works/pi-coding-agent | oh-my-pi (omp) |
|---|---|---|
| **What** | Base Pi agent (minimal) | Full fork with IDE tooling |
| **Tools** | 4 core: read, write, edit, bash | 32 built-in + 13 LSP + 27 DAP |
| **Install** | `npm i -g @earendil-works/pi-coding-agent` | `bun i -g @oh-my-pi/pi-coding-agent` |
| **Providers** | Standard | 40+ providers |
| **Subagents** | Via extension | Built-in |
| **Use case** | Lightweight, watcher, simple tasks | Full coding agent experience |
| **Size** | Small | Large (~27k lines Rust core) |

**Decision:** Watcher uses base Pi (minimal, lightweight, always-on). Harness uses oh-my-pi (full experience, installed on-demand when user selects Pi).

### Local LLM Options (for Watcher)

**Source:** Multiple guides on llama.cpp + local models for agent workloads

**Recommended stack for watcher:**
- **Engine:** llama.cpp (`llama-server` exposes OpenAI-compatible endpoint)
- **Model candidates:**
  - Qwen 3.6 27B Q4_K_M (~18GB RAM) — strong coding + tool calling
  - Qwen 3.6 7B Q4_K_M (~5GB RAM) — lighter, sufficient for monitoring tasks
  - DeepSeek Coder V2 Lite — good tool calling
- **Serving:** `llama-server -m model.gguf -c 8192 --port 8080`
- **Pi connects via:** `--provider openai --model <name> --base-url http://localhost:8080/v1`

**Alternative:** Free tier from OpenRouter (no local GPU needed, but data leaves machine).

**Recommendation:** Start with OpenRouter free tier for simplicity, migrate to llama.cpp when privacy/always-on requirements demand it. The watcher tasks (health checks, status queries) are lightweight — even a 7B model handles them fine.

### Pistisai Provider Architecture

**Source:** `/dev/pistisai/pistisai-app/lib/services/` (read during research)

**Integration points identified:**

1. **`ProviderType` enum** (`lib/models/provider_configuration.dart:8`):
   ```dart
   enum ProviderType {
     openclaw, hermes, ollama, lmStudio, openAICompatible, custom,
   }
   ```
   → Need to add `pi` as new enum value, mark as `isAgentRuntime: true`

2. **`LlmProvider` interface** (`lib/services/providers/base_provider.dart:144`):
   ```dart
   abstract class LlmProvider {
     String get name;
     Stream<StreamEvent> streamCompletion(CompletionRequest request);
     Future<CompletionResponse> complete(CompletionRequest request);
   }
   ```
   → Pi adapter implements this. `streamCompletion` maps to RPC `message_update` text_delta events.

3. **`HermesProviderAdapter`** (`lib/services/providers/hermes_adapter.dart`):
   → Closest analog. Uses HTTP POST with SSE. Pi adapter uses subprocess + JSONL instead.

4. **`RouterServer`** (`lib/services/router_server.dart`):
   → Local HTTP server (Shelf) on port 1337 that mimics OpenAI API. Pi gets added as a provider entry.

5. **DI locator** (`lib/di/locator.dart:1040`):
   → Switch on `ProviderType` for auto-configuration. Need to add `case ProviderType.pi:`.

6. **Existing subprocess patterns:**
   - `GatewayControlService` uses `Process.run()` for OpenClaw gateway start/stop
   - `v4l2_camera_service.dart` uses `Process.start()` with stdout streaming
   → Pi harness uses `Process.start()` with bidirectional stdin/stdout (JSONL)

---

## Architecture

### Harness (in-app, on-demand)

```
┌─────────────────────────────────────────────┐
│ Flutter App (Dart)                          │
│                                             │
│  User selects Pi → PiProviderConfiguration  │
│    → PiRpcClient                            │
│      → Process.start("omp", ["--mode","rpc"])│
│      → stdin: JSONL commands                │
│      ← stdout: JSONL events                 │
│                                             │
│  PiRpcClient implements LlmProvider         │
│    → Registered in RouterServer providers   │
│    → /v1/chat/completions routes to Pi      │
│                                             │
│  Model routing:                             │
│    Active harness = Hermes → Pi uses same   │
│    Active harness = OpenClaw → Pi uses same │
└─────────────────────────────────────────────┘
         ↕ JSONL over stdin/stdout
┌─────────────────────────────────────────────┐
│ omp --mode rpc (oh-my-pi subprocess)        │
│  --provider <from-active-harness>           │
│  --model <from-active-harness>              │
│  Full IDE tooling available                 │
└─────────────────────────────────────────────┘
```

### Watcher (VPS systemd, always-on)

```
┌─────────────────────────────────────────────┐
│ VPS (server-pistisai) — systemd service     │
│                                             │
│  Pi Watcher Session (persistent)            │
│    → Minimal pi (no oh-my-pi)               │
│    → Model: llama.cpp local OR free tier    │
│    → pi-observer skill loaded               │
│    → Cron: health checks every 30-60 min    │
│    → A2A: accountability every 2-4 hr       │
│    → Surfaces anomalies to Christopher      │
│                                             │
│  Monitors:                                  │
│    - Hermes (Zoid) process & cron           │
│    - Elencho process & cron                 │
│    - Subagent Pi sessions                   │
│    - Disk, CI state, A2A peer health        │
└─────────────────────────────────────────────┘
         ↕ llama.cpp server (if local)
┌─────────────────────────────────────────────┐
│ llama-server --port 8080                    │
│  Qwen 3.6 7B Q4_K_M (or similar)            │
└─────────────────────────────────────────────┘
```

### Subagent (on-demand)

```
Active Harness (e.g. Hermes/Zoid)
  → pi -p "Fix the null check in foo.dart"
  → Pi executes, returns result
  → Zoid renders "via Pi subagent" in chat
```

---

## Safety Boundaries

**Hard constraints (enforced in code):**

| Can | Cannot |
|-----|--------|
| Read logs, status, health data | Rewrite identity (any agent) |
| Restart paused/stopped processes | Touch secrets or credentials |
| Pause running tasks | Modify another agent's system prompt |
| Send alerts to Christopher | Access another agent's memory |
| Query agents via A2A | Exfiltrate data off-machine |

---

## Implementation Phases

### Phase 1: Pi as Harness — Provider Adapter
**Issue:** #285 | **Effort:** Medium

1. `PiRpcClient` — subprocess lifecycle, JSONL framing, event parsing
2. `ProviderType.pi` + `PiProviderConfiguration` in provider_configuration.dart
3. `PiProviderAdapter` implementing `LlmProvider`
4. Wire into RouterServer + DI locator
5. UI: Pi in agent runtime selector + settings screen
6. Model routing: Pi inherits model/API from the currently active harness
7. oh-my-pi install prompt when user first selects Pi

**Key technical detail:** Must split stdout on `\n` only (not readline). Use `dart:io` Process + `utf8.decoder` + manual line buffer.

### Phase 2: Pi as Watcher — L1 Passive Monitoring
**Issue:** #286 | **Effort:** Small-Medium

1. `pi-observer` skill (SKILL.md + scripts)
2. Health check bash script (process alive, disk, cron, CI)
3. systemd unit on VPS (always-on, auto-restart)
4. llama.cpp setup OR free tier config
5. Anomaly surfacing to Christopher

### Phase 3: Pi as Subagent — On-Demand Delegate
**Issue:** #287 | **Effort:** Small

1. Subagent spawn: `pi -p "<task>"` via Process.run
2. Result parsing + attribution ("via Pi subagent")
3. RPC session mode for multi-turn delegation
4. Timeout handling

### Phase 4: Pi Watcher L2-L3 — A2A + Intervention
**Issue:** #288 | **Effort:** Medium

1. Install `@bacnh85/pi-a2a` in Pi
2. Configure peers (Hermes, Elencho)
3. L2 accountability queries (every 2-4 hr)
4. L3 intervention rules (restart/pause/notify)
5. Pi becomes A2A peer (both observer and observable)

---

## Hardware Compatibility Analysis

### Christopher's PC (right-pc, CachyOS)

| Component | Spec | Verdict |
|-----------|------|---------|
| **CPU** | Intel i5-13600KF (14c/20t) | ✅ Excellent — fast compilation, multi-tasking |
| **GPU** | NVIDIA RTX 4070 (12GB VRAM, sm_89) | ✅ Great for local LLM — see model fits below |
| **RAM** | 62GB DDR4/DDR5 (48GB available) | ✅ Massive headroom for CPU offloading |
| **Disk** | 932GB data drive (399GB free) | ✅ Plenty of room for models |
| **OS** | CachyOS Linux (Arch-based) | ✅ Full package support |
| **Node.js** | v26.8.1 | ✅ Required by oh-my-pi |
| **Bun** | Not installed | ⚠️ Need to install for oh-my-pi |
| **CUDA** | Driver 580.159 (CUDA 13 toolkit on system) | ✅ Ready for llama.cpp CUDA |
| **Docker** | 29.7.2 | ✅ Available for containerized inference |

### Model Fits on RTX 4070 (12GB VRAM)

Based on VRAM requirements with Q4_K_M quantization + KV cache:

| Model | Size (Q4_K_M) | Fits? | Notes |
|-------|---------------|-------|-------|
| **Gemma 4 E4B** | ~5GB | ✅ Easy | 6GB+ VRAM needed. Multimodal. Currently used on this machine via LM Studio. |
| **Phi-4 14B** | ~8.9GB | ✅ Tight | Needs ~12GB total with KV cache. Works with quantized KV. Good generalist. |
| **Qwen 3.6 7B** | ~4.4GB | ✅ Easy | Sufficient for watcher tasks. Fast inference. |
| **Qwen 3.6 14B** | ~8.8GB | ✅ Tight | Better quality than 7B, still fits. |
| **Qwen3-30B-A3B (MoE)** | ~18.6GB | ⚠️ CPU offload | 30B total but only 3B active. Needs `--cpu-moe` flag. Works with 62GB RAM. |
| **Qwen 3.6 27B** | ~16GB | ❌ No | Too large for 12GB. Needs CPU offload (slow). |

### Recommended Watcher Model for This Hardware

**Primary: Phi-4 14B Q4_K_M (~8.9GB)**
- Fits in 12GB VRAM with quantized KV cache
- Strong reasoning for monitoring/analysis tasks
- Good tool-calling support
- ~9GB disk space needed

**Alternative: Qwen 3.6 7B Q4_K_M (~4.4GB)**
- Lighter, faster
- Plenty of VRAM headroom for longer contexts
- Sufficient for simple health checks + A2A queries

**Current state:** No model weights installed on the machine (only vocab files from Turbohaul project). Need to download ~9GB for Phi-4 or ~4.4GB for Qwen 7B.

### oh-my-pi Installation on CachyOS

**Requirements:**
- Bun >= 1.3.14 (not currently installed)
- Node.js (✅ v26.8.1 installed)

**Install path:**
\`\`\`bash
# Install Bun (one curl command)
curl -fsSL https://bun.sh/install | bash

# Install oh-my-pi
bun install -g @oh-my-pi/pi-coding-agent
\`\`\`

**Alternative install methods if Bun is problematic:**
- Shell installer: \`curl -fsSL https://omp.sh/install | sh\` (downloads prebuilt binary)
- Nix: \`nix profile install github:can1357/oh-my-pi\`
- mise: \`mise use -g github:can1357/oh-my-pi\`

**No AUR helper currently installed** (no paru/yay), so Bun install or shell script are the paths.

### llama.cpp Installation on CachyOS

**Two options:**

**Option A: Ollama (simplest)**
\`\`\`bash
# Install Ollama (has CUDA support built-in)
curl -fsSL https://ollama.com/install.sh | sh
# Download model
ollama run phi4
\`\`\`
- Auto-detects CUDA
- No manual build needed
- Currently NOT installed on the machine

**Option B: llama.cpp (more control, better perf)**
\`\`\`bash
# CUDA toolkit already on system (pacman cache shows cuda-13.3.1)
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
make -j$(nproc) GGML_CUDA=1
# Serve
./llama-server -m phi-4-Q4_K_M.gguf -ngl 999 --port 8080
\`\`\`

**Recommendation:** Start with Ollama for simplicity (one command install, auto-CUDA). Migrate to raw llama.cpp if we need the performance optimizations from Turbohaul's TurboQuant fork later.

### What This Hardware CANNOT Do

- **Cannot run 70B+ models** — 12GB VRAM is the hard limit; 70B needs 40GB+
- **Cannot run unquantized 14B+** — BF16 14B = 28GB, exceeds VRAM
- **Cannot run multiple large models simultaneously** — one model at a time in 12GB

### Minimum Hardware for Other Users

For the pistisai app to support Pi as harness with local watcher, minimum specs:

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **GPU** | 8GB VRAM (RTX 4060/3070) | 12GB (RTX 4070/3080) |
| **RAM** | 16GB | 32GB+ |
| **Disk** | 50GB free | 100GB+ free |
| **OS** | Linux/macOS/Windows | — |
| **Node.js** | v18+ | v20+ |
| **Bun** | v1.3.14+ | latest |

**For GPU-less / Apple Silicon machines:**
- CPU inference works (Q4_K_M 7B ~8 tokens/sec on modern CPU)
- Apple Silicon: Metal acceleration via llama.cpp
- 16GB+ unified memory for Apple

---

## Deep Research: oh-my-pi Extension API

**Source:** [github.com/can1357/oh-my-pi/docs/extensions.md](https://github.com/can1357/oh-my-pi/blob/main/docs/extensions.md) (743 lines, fully read)

The oh-my-pi extension system is how we build the **observer** for the harness role. Extensions are TypeScript modules that register tools, event handlers, and commands.

### Extension Lifecycle

```
import paths → import module + run factory (registration only)
  → ExtensionRunner.initialize(mode/session/tool registry)
  → emit session/agent events + wrap tool execution
```

### Key APIs for Observer Extension

**1. Background timers (for periodic health checks):**
```typescript
pi.on("session_start", async (_event, ctx) => {
  const timer = ctx.setInterval(() => {
    // Health check logic here — throw is contained, won't crash session
    checkAgentHealth();
  }, 60_000); // every 60 seconds
});
```
Critical: use `ctx.setInterval` NOT raw `setInterval` — raw timers crash the session on error.

**2. Tool interception (for monitoring what tools are called):**
```typescript
pi.on("tool_call", async (event) => {
  logToolUsage(event.toolName, event.input);
  // Can block dangerous operations: return { block: true, reason: "..." }
});

pi.on("tool_result", async (event) => {
  logToolResult(event.toolName, event.isError);
  // Can patch results: modify event.content
});
```

**3. Custom tools (for exposing observer capabilities to the LLM):**
```typescript
pi.registerTool({
  name: "observer_status",
  label: "Observer Status",
  description: "Check health of all agent instances",
  parameters: z.object({}),
  async execute(_id, _params, _signal, _onUpdate, ctx) {
    return { content: [{ type: "text", text: getHealthReport() }] };
  },
});
```

**4. Message delivery (for sending alerts to the user):**
```typescript
// steer = interrupt current run with alert
pi.sendMessage(alertMessage, { deliverAs: "steer" });

// followUp = queue after current run
pi.sendMessage(alertMessage, { deliverAs: "followUp" });

// nextTurn = inject on next user prompt
pi.sendMessage(alertMessage, { deliverAs: "nextTurn" });
```

**5. Session state (for persistent observer state):**
```typescript
// Save state
pi.appendEntry("com.pistisai.observer.state", healthData);

// Restore on session start
pi.on("session_start", async (_event, ctx) => {
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type === "custom" && entry.customType === "com.pistisai.observer.state") {
      restoreState(entry.data);
    }
  }
});
```

### RPC Mode Constraints

When Pi runs in `--mode rpc` (harness mode from Flutter app):
- `ctx.ui` is backed by RPC `extension_ui_request` events
- Dialog methods (select/confirm/input/editor) round-trip to client
- Fire-and-forget methods (notify/setStatus/setWidget) emit to client
- **Unsupported in RPC:** theme switching, terminal input, autocomplete, editor component
- Extensions CANNOT call `sendMessage` during load phase — must wait for events

### What This Means for the Observer

The observer can be built as an **oh-my-pi extension** that:
1. Uses `ctx.setInterval` for periodic health checks
2. Uses `tool_call`/`tool_result` events to monitor tool usage
3. Uses `pi.sendMessage({ deliverAs: "steer" })` to alert on anomalies
4. Uses `pi.appendEntry` to persist health state across sessions
5. Registers an `observer_status` tool the LLM can call on demand

This is the cleanest approach — the observer lives INSIDE Pi, has full access to Pi's session lifecycle, and requires no external process.

---

## Deep Research: systemd Watchdog for Watcher

**Sources:**
- [os.moda/blog/run-ai-agent-24-7](https://os.moda/blog/run-ai-agent-24-7) — full 24/7 agent supervision guide
- [adhdecode.com/systemd-watchdog-service-health](https://adhdecode.com/articles/systemd/systemd-watchdog-service-health) — watchdog mechanics
- [oneuptime.com/systemd-watchdog-health-checks](https://oneuptime.com/blog/post/2026-03-02-how-to-configure-systemd-watchdog-for-service-health-checks-on-ubuntu/) — Python watchdog pattern

### systemd Watchdog Mechanism

The systemd watchdog detects **hung** processes (not just crashed ones):
1. Service declares `WatchdogSec=N` in unit file
2. systemd sets `WATCHDOG_USEC` env var
3. Service must send `sd_notify("WATCHDOG=1")` periodically
4. If heartbeat stops, systemd kills and restarts the service

**Python watchdog pattern:**
```python
import os, threading, time
from systemd import daemon

watchdog_usec = int(os.environ.get('WATCHDOG_USEC', 0))
if watchdog_usec > 0:
    interval = watchdog_usec / 1_000_000
    threading.Thread(target=watchdog_thread, args=(interval,), daemon=True).start()

def watchdog_thread(interval):
    while True:
        time.sleep(interval / 2)  # Send at half the interval
        daemon.notify('WATCHDOG=1')
```

### Recommended Watcher Unit File

```ini
[Unit]
Description=Pi Watcher Agent
After=network-online.target ollama.service
Wants=network-online.target
Requires=ollama.service

[Service]
Type=simple
User=zoid
WorkingDirectory=/dev/pistisai
ExecStart=/home/zoid/.local/bin/pi --mode rpc --model local/phi-4
Restart=on-failure
RestartSec=10
StartLimitIntervalSec=300
StartLimitBurst=5

# Watchdog — restart if hung (not just crashed)
WatchdogSec=60

# Resource limits
MemoryMax=8G
CPUQuota=300%

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=pi-watcher

# Security
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/dev/pistisai/pi-watcher-data

[Install]
WantedBy=multi-user.target
```

### Key Directives

| Directive | Value | Why |
|-----------|-------|-----|
| `Restart=on-failure` | on-failure | Restart on non-zero exit, not clean shutdown |
| `RestartSec=10` | 10s | Wait between restarts (avoid hammering) |
| `StartLimitBurst=5` | 5 | Stop restarting after 5 failures in 5 min |
| `WatchdogSec=60` | 60s | Kill if heartbeat stops for 60s |
| `MemoryMax=8G` | 8GB | Kill if memory exceeds 8GB |

### Checkpointing for Crash Recovery

The watcher should periodically save state to disk:
- Last known health status of each agent
- Last A2A query timestamp
- Alert history

On restart, load the latest checkpoint and resume. Without this, a crash loses all monitoring context.

### External Monitoring (Layer 2)

Per the os.moda guide, monitor at 3 levels:
1. **Infrastructure:** CPU, memory, disk, network (systemd handles this)
2. **Application:** Health check endpoint, restart count (journald)
3. **AI-specific:** Token usage, reasoning loop depth, A2A response times

A second agent (Zoid/Hermes) should periodically check the watcher's health — "a dead process can't tell you it's dead."

---

## Deep Research: pi-a2a Configuration Reference

**Source:** [pi.dev/packages/@bacnh85/pi-a2a](https://pi.dev/packages/@bacnh85/pi-a2a) + [github.com/bacnh85/pi-extensions](https://github.com/bacnh85/pi-extensions)

### Full Config Schema

```json
{
  "a2a": {
    "peers": {
      "hermes_desktop": {
        "url": "http://172.30.55.31:9900",
        "auth": { "type": "bearer", "token": "..." },
        "timeout": 120,
        "capabilities": ["web_search", "research"]
      }
    },
    "server": {
      "enabled": false,
      "port": 9910,
      "bindAddress": "127.0.0.1",
      "agentName": "pi-watcher",
      "publicUrl": "",
      "sharedToken": "",
      "peerTokens": {},
      "trustedPeers": [],
      "allowAllUsers": false,
      "maxConcurrentSessions": 5,
      "sessionTimeout": 3600,
      "redactOutput": true,
      "filterInjection": true,
      "auditLog": true,
      "antiLoop": true,
      "antiLoopMaxHops": 3
    }
  }
}
```

### Security Model (ported from Hermes)

| Feature | Detail |
|---------|--------|
| **Default bind** | localhost only (inbound off by default) |
| **Remote access** | Token-gated |
| **Output redaction** | Secrets redacted from outbound messages |
| **Injection filtering** | Blocks prompt injection in inbound tasks |
| **Anti-loop** | Max 3 hops, prevents infinite delegation loops |
| **Audit log** | All A2A activity logged |

### Relevant bacnh85 Extensions for Watcher

| Extension | Version | Use for watcher |
|-----------|---------|-----------------|
| `@bacnh85/pi-a2a` | 0.7.6 | Mesh communication, peer discovery |
| `@bacnh85/pi-notify` | — | Desktop notifications for alerts |
| `@bacnh85/pi-munin` | — | System monitoring integration |
| `@bacnh85/pi-checkpoint` | — | Session checkpointing for crash recovery |
| `@bacnh85/pi-budget` | — | Token/cost tracking |

---

## Open Questions

1. **Model for watcher:** Phi-4 14B (best quality, fits tight) vs Qwen 7B (lighter, faster)? RTX 4070 12GB handles both. Leaning Phi-4 for reasoning quality.
2. **Inference runtime:** Ollama (simple, auto-CUDA) vs llama.cpp (more control) vs Turbohaul (when fixed). Leaning Ollama for v1.
3. **oh-my-pi install flow:** How does the Flutter app trigger oh-my-pi install? Shell command to PC via SSH? Bundled installer prompt?
4. **Subagent attribution:** How should "via Pi subagent" appear in chat? Inline badge? Separate message?
5. **A2A port:** Default pi-a2a port is 9910. Hermes A2A is on 9900. Need to ensure no conflicts.
6. **Free tier fallback:** If local model is too heavy for some users, OpenRouter free tier as fallback? Or require local?
7. **Observer architecture:** oh-my-pi extension (runs inside Pi) vs standalone Dart service (runs in app) vs systemd timer?

---

## Key Research Sources

- [Pi RPC Mode](https://pi.ubitools.com/rpc/) — full protocol spec
- [Pi RPC Mode (mirror)](https://pi-agent-docs.pages.dev/rpc/) — same spec, alternate host
- [@bacnh85/pi-a2a](https://pi.dev/packages/@bacnh85/pi-a2a) — A2A extension
- [pi-subagents](https://pi.dev/packages/pi-subagents) — sub-agent delegation
- [oh-my-pi](https://github.com/can1357/oh-my-pi) — full IDE-grade fork of Pi
- [oh-my-pi deep dive](https://agentpedia.codes/blog/oh-my-pi-terminal-coding-agent-guide) — feature breakdown
- [llama.cpp + Qwen 3.6](https://miaggy.com/blog/claude-code-with-llama-cpp-and-qwen) — local agent stack
- [llama.cpp local LLM guide](https://ml4devs.com/articles/llm-local-inference-dev-setup) — inference setup
- [Pistisai provider architecture](/dev/pistisai/pistisai-app/lib/services/providers/) — integration point
- [oh-my-pi extensions.md](https://github.com/can1357/oh-my-pi/blob/main/docs/extensions.md) — full extension API (743 lines)
- [Run AI Agent 24/7](https://os.moda/blog/run-ai-agent-24-7) — systemd supervision guide
- [systemd Watchdog](https://adhdecode.com/articles/systemd/systemd-watchdog-service-health) — hung-process detection
- [systemd Watchdog (Python)](https://oneuptime.com/blog/post/2026-03-02-how-to-configure-systemd-watchdog-for-service-health-checks-on-ubuntu/) — sd_notify pattern
- [bacnh85/pi-extensions](https://github.com/bacnh85/pi-extensions) — full extension catalog
- [Pi settings.json](https://pi.dev/docs/latest/settings) — full config reference
