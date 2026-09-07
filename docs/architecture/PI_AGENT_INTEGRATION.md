# Pi Agent Integration — Implementation Plan

> **Status:** ✅ Research complete — ready for implementation
> **Author:** Zoid (with Christopher)
> **Created:** 2026-09-06
> **Revised:** 2026-09-07 (v8 — implementation-ready: exact files, code patterns, commands)
> **Location:** `docs/architecture/PI_AGENT_INTEGRATION.md`

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Three Roles](#three-roles)
3. [Technology Stack](#technology-stack)
4. [Architecture](#architecture)
5. [Implementation Plan](#implementation-plan)
   - [Phase 1: Pi as Harness](#phase-1-pi-as-harness)
   - [Phase 2: llama.cpp Infrastructure](#phase-2-llamacpp-infrastructure)
   - [Phase 3: Pi as Watcher](#phase-3-pi-as-watcher)
   - [Phase 4: Pi as Subagent](#phase-4-pi-as-subagent)
   - [Phase 5: Watcher L2-L3 + Mesh](#phase-5-watcher-l2-l3--mesh)
   - [Phase 6: Desktop Control](#phase-6-desktop-control)
6. [Safety Boundaries](#safety-boundaries)
7. [Hardware Compatibility](#hardware-compatibility)
8. [Research Appendix](#research-appendix)

---

## Executive Summary

Pi integrates into the pistisai ecosystem in **three distinct roles**:

1. **Harness** — User-selectable chat engine in the Flutter app (like Hermes/OpenClaw)
2. **Watcher** — Always-on background observer on the VPS (systemd service)
3. **Subagent** — On-demand coding delegate spawned by the active harness

**Stack:** llama.cpp (NOT Ollama) + Gemma 4 E4B-it Q4_K_M + Pi RPC mode + Dart subprocess

**Key insight:** Harness Pi borrows the active harness's model. Watcher Pi runs local llama.cpp. These are fundamentally different setups.

---

## Three Roles

| Role | User-facing? | Always-on? | Process | Model |
|------|-------------|------------|---------|-------|
| **Harness** | Yes — primary chat | No — when selected | Flutter subprocess (RPC) | Borrows from active harness |
| **Watcher** | No — surfaces alerts | Yes — systemd on VPS | Standalone Pi session | Local llama.cpp (Gemma 4 E4B) |
| **Subagent** | No — reports to harness | No — on-demand | `pi --print` one-shot | Same as spawning harness |

---

## Technology Stack

### Inference
- **Runtime:** llama.cpp `llama-server` (OpenAI-compatible API)
- **Model:** Gemma 4 E4B-it Q4_K_M (5.4GB VRAM, fits RTX 4070 12GB)
- **Vision:** mmproj-BF16.gguf (for desktop control screenshots)
- **Server:** `127.0.0.1:8080` (router mode for multi-model)

### Agent
- **Base:** `@earendil-works/pi-coding-agent` (installed at `/home/zoid/.local/bin/pi`)
- **Harness fork:** `oh-my-pi` (can1357) — installed on-demand when Pi selected
- **A2A mesh:** `@bacnh85/pi-a2a` extension
- **Desktop control:** `@agent-sh/computer-use-linux` (MCP server)

### Integration
- **Pi ↔ llama.cpp:** Built-in `llamacpp` provider (auto-discovers llama-server)
- **Pi ↔ Flutter:** RPC mode (`pi --rpc`, JSONL over stdin/stdout)
- **Pi ↔ Mesh:** `@bacnh85/pi-a2a` extension
- **Subagents:** `pi --print` mode or `pi-self` skill

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     right-pc (Desktop, CachyOS)                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Flutter App (pistisai)                        │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │   │
│  │  │  Hermes   │  │ OpenClaw  │  │    Pi     │  │  Ollama  │ │   │
│  │  │  Adapter  │  │  Adapter  │  │  Adapter  │  │  (ref)   │ │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └─────────┘ │   │
│  │       │              │              │                     │   │
│  │       └──────────────┴──────────────┘                     │   │
│  │                      │                                    │   │
│  │              RouterServer + DI Locator                     │   │
│  │              (ProviderType enum → adapter)                 │   │
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
│                     server-pistisai (VPS)                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          Pi Watcher (systemd service)                      │   │
│  │  - Always-on background observer                           │   │
│  │  - Local llama.cpp or free model                           │   │
│  │  - Few modules: health check, A2A, notifications           │   │
│  │  - Heartbeat cron → accountability questions                │   │
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

---

## Implementation Plan

### Phase 1: Pi as Harness (GitHub #285)

**Goal:** Pi selectable as agent harness in Flutter app
**Estimated:** 2-3 days

#### Files to Create/Modify

| File | Action | What |
|------|--------|------|
| `lib/models/provider_configuration.dart` | **Modify** | Add `pi` to `ProviderType` enum |
| `lib/services/providers/pi_adapter.dart` | **Create** | Pi RPC client adapter |
| `lib/services/pi_manager/pi_rpc_client.dart` | **Create** | Low-level JSONL subprocess client |
| `lib/services/router_server.dart` | **Modify** | Add `ProviderType.pi` case |
| `lib/di/locator.dart` | **Modify** | Add Pi adapter instantiation |
| `lib/screens/onboarding/steps/completion_step.dart` | **Modify** | Add Pi label in UI |
| `lib/screens/onboarding/steps/local_detection_step.dart` | **Modify** | Add Pi icon |

#### ProviderType Enum Change

```dart
// lib/models/provider_configuration.dart
enum ProviderType {
  openclaw,
  hermes,
  ollama,
  lmStudio,
  openAICompatible,
  custom,
  pi,  // ← NEW
}
```

Also update the `isAgentRuntime` extension:
```dart
bool get isAgentRuntime {
  return switch (this) {
    ProviderType.openclaw ||
    ProviderType.hermes ||
    ProviderType.custom ||
    ProviderType.pi =>  // ← NEW
      true,
    ProviderType.ollama ||
    ProviderType.lmStudio ||
    ProviderType.openAICompatible =>
      false,
  };
}
```

#### Pi RPC Client (core subprocess handler)

```dart
// lib/services/pi_manager/pi_rpc_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Low-level client for Pi's RPC mode (JSONL over stdin/stdout).
///
/// Spawns `pi --rpc` as a subprocess and communicates via
/// line-delimited JSON. Mirrors the OpenClaw/Hermes subprocess pattern
/// from gateway_control_service.dart.
class PiRpcClient {
  Process? _process;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;
  final _responseController = StreamController<Map<String, dynamic>>.broadcast();
  int _requestId = 0;
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};

  bool get isRunning => _process != null;

  /// Start the Pi subprocess.
  Future<void> start({
    String provider = 'llamacpp',
    String model = 'google_gemma-4-E4B-it',
    String? sessionDir,
  }) async {
    if (_process != null) return;

    final args = ['--mode', 'rpc', '--provider', provider, '--model', model];
    if (sessionDir != null) args.addAll(['--session-dir', sessionDir]);

    _process = await Process.start('pi', args);

    // Read stdout line by line (JSONL protocol)
    _stdoutSub = _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleLine);

    // Forward stderr to logs
    _stderrSub = _process!.stderr
        .transform(utf8.decoder)
        .listen((line) => stderr.writeln('[Pi] $line'));
  }

  void _handleLine(String line) {
    if (line.trim().isEmpty) return;
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      // If it has an id, it's a response to a command
      if (json.containsKey('id') && json['id'] is String) {
        final completer = _pending.remove(json['id']);
        completer?.complete(json);
      } else {
        // It's an event (message_update, tool_execution, etc.)
        _responseController.add(json);
      }
    } catch (e) {
      stderr.writeln('[Pi] Failed to parse JSON: $e');
    }
  }

  /// Send a prompt to Pi. Returns a future that completes when the
  /// agent starts processing. Events stream via [stream].
  Future<void> prompt(String message) async {
    final id = 'req-${_requestId++}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    final payload = jsonEncode({
      'id': id,
      'type': 'prompt',
      'message': message,
    });
    _process!.stdin.writeln(payload);

    await completer.future; // Wait for acceptance
  }

  /// Stream of agent events (message_update, tool_execution, etc.)
  Stream<Map<String, dynamic>> get stream => _responseController.stream;

  /// Abort current operation.
  Future<void> abort() async {
    _process!.stdin.writeln(jsonEncode({'type': 'abort'}));
  }

  /// Start a fresh session.
  Future<void> newSession() async {
    _process!.stdin.writeln(jsonEncode({'type': 'new_session'}));
  }

  /// Stop the subprocess.
  Future<void> stop() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _process?.kill();
    _process = null;
  }
}
```

#### Pi Provider Adapter

```dart
// lib/services/providers/pi_adapter.dart
import 'dart:async';
import 'dart:convert';
import '../providers/base_provider.dart';
import '../pi_manager/pi_rpc_client.dart';

/// Pi provider adapter — implements LlmProvider for the Pi coding agent.
///
/// Unlike Hermes/OpenClaw adapters that talk HTTP/WebSocket,
/// Pi adapter spawns a subprocess and communicates via RPC mode.
class PiProviderAdapter implements LlmProvider {
  final PiRpcClient _client = PiRpcClient();
  final String _model;
  String? _baseUrl;

  PiProviderAdapter({String model = 'google_gemma-4-E4B-it'})
      : _model = model;

  @override
  String get name => 'pi';

  @override
  String get baseUrl => _baseUrl ?? 'subprocess';

  @override
  Future<void> initialize() async {
    await _client.start(provider: 'llamacpp', model: _model);
  }

  @override
  Stream<StreamEvent> streamCompletion(CompletionRequest request) async* {
    // Subscribe to events before sending prompt
    final eventSub = _client.stream.listen((event) {
      // Events are handled via the stream below
    });

    await _client.prompt(request.messages.last['content'] as String);

    await for (final event in _client.stream) {
      final type = event['type'] as String?;

      if (type == 'message_update') {
        final delta = event['assistantMessageEvent']?['delta'];
        if (delta != null) {
          yield(StreamEvent.delta(delta as String));
        }
      } else if (type == 'agent_end') {
        yield(StreamEvent.done());
        break;
      } else if (type == 'tool_execution_start') {
        // Optionally surface tool calls to UI
        yield(StreamEvent.toolCall(
          event['toolName'] as String?,
          event['args'] as Map<String, dynamic>? ?? {},
        ));
      }
    }

    await eventSub.cancel();
  }

  @override
  Future<void> dispose() => _client.stop();
}
```

#### DI Locator Change

```dart
// lib/di/locator.dart — add to the switch statement (around line 1041)
case ProviderType.pi:
  adapter = PiProviderAdapter(
    model: config.model ?? 'google_gemma-4-E4B-it',
  );
  break;
```

#### Testing

```bash
# Verify Pi RPC mode works from command line
echo '{"id":"1","type":"prompt","message":"hello"}' | pi --mode rpc --provider llamacpp --model google_gemma-4-E4B-it

# Run Flutter tests
cd /dev/pistisai/pistisai-app && flutter test test/services/pi_manager/
```

---

### Phase 2: llama.cpp Infrastructure

**Goal:** Local inference running on right-pc
**Estimated:** 1 day (mostly automated)

#### Build llama.cpp (right-pc, CachyOS)

```bash
# SSH to right-pc
ssh right-pc

# Install dependencies (if not present)
sudo pacman -S --needed cmake gcc cuda

# Clone and build
cd /run/media/rightguy/data/dev/tools
git clone https://github.com/ggml-org/llama.cpp
cd llama.cpp
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89
cmake --build build --config Release -j $(nproc)

# Symlink binary
sudo ln -sf $(pwd)/build/bin/llama-server /usr/local/bin/llama-server
```

#### Download Gemma 4 E4B Model

```bash
# Using huggingface-cli or llama-server -hf
llama-server -hf bartowski/google_gemma-4-E4B-it-GGUF:Q4_K_M \
  --port 8080 --host 127.0.0.1 &
# First run downloads the model to ~/.cache/llama.cpp/

# Or download manually:
huggingface-cli download bartowski/google_gemma-4-E4B-it-GGUF \
  google_gemma-4-E4B-it-Q4_K_M.gguf \
  --local-dir /run/media/rightguy/data/ai/models/

# Also download mmproj for vision:
huggingface-cli download bartowski/google_gemma-4-E4B-it-GGUF \
  mmproj-BF16.gguf \
  --local-dir /run/media/rightguy/data/ai/models/
```

#### systemd Unit (llama-server)

```ini
# /etc/systemd/system/llama-server.service
[Unit]
Description=llama.cpp inference server (CUDA)
After=network.target

[Service]
Type=exec
User=rightguy
Group=rightguy
WorkingDirectory=/run/media/rightguy/data/ai/models
ExecStart=/usr/local/bin/llama-server \
  -m /run/media/rightguy/data/ai/models/google_gemma-4-E4B-it-Q4_K_M.gguf \
  --mmproj /run/media/rightguy/data/ai/models/mmproj-BF16.gguf \
  -ngl 99 \
  -c 32768 \
  -fa on \
  --host 127.0.0.1 \
  --port 8080
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now llama-server
curl http://127.0.0.1:8080/health
# → {"status":"ok"}
```

#### Verify Pi ↔ llama.cpp Connection

```bash
# Pi auto-discovers llama-server at default URL
pi --provider llamacpp --model google_gemma-4-E4B-it -p "Hello, what model are you?"
```

---

### Phase 3: Pi as Watcher (GitHub #286)

**Goal:** Always-on background observer on VPS
**Estimated:** 2-3 days

#### Files to Create

| File | What |
|------|------|
| `watcher/observer-extension.ts` | oh-my-pi extension: health checks, notifications |
| `watcher/systemd/pi-watcher.service` | systemd unit with watchdog |
| `watcher/scripts/install.sh` | One-shot install script |

#### Observer Extension

```typescript
// watcher/observer-extension.ts
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export default function observerExtension(pi: ExtensionAPI) {
  const z = pi.zod;

  // Register health check tool
  pi.registerTool({
    name: "check_health",
    label: "Check Health",
    description: "Check health of all agent instances and services",
    parameters: z.object({
      scope: z.enum(["all", "agents", "services", "cron"]).default("all"),
    }),
    async execute(_id, { scope }) {
      // Implementation: check systemd services, cron jobs, agent heartbeats
      const health = await performHealthCheck(scope);
      return { content: [{ type: "text", text: JSON.stringify(health, null, 2) }] };
    },
  });

  // Register notification tool
  pi.registerTool({
    name: "notify_christopher",
    label: "Notify Christopher",
    description: "Send a notification to Christopher",
    parameters: z.object({
      message: z.string(),
      urgency: z.enum(["low", "medium", "high"]).default("medium"),
    }),
    async execute(_id, { message, urgency }) {
      // Implementation: send via Telegram/notification channel
      await sendNotification(message, urgency);
      return { content: [{ type: "text", text: "Notification sent" }] };
    },
  });

  // Passive monitoring: observe all tool calls
  pi.on("tool_call", async (event) => {
    // Log for drift detection
    await pi.appendEntry({
      type: "tool_call_log",
      toolName: event.toolName,
      timestamp: Date.now(),
    });
  });

  // Active monitoring: periodic health check
  pi.setInterval(async () => {
    const health = await performHealthCheck("all");
    if (health.status !== "ok") {
      pi.sendMessage({
        role: "assistant",
        content: `⚠️ Health anomaly detected:\n${JSON.stringify(health.anomalies, null, 2)}`,
        deliverAs: "steer",
      });
    }
  }, 300_000); // Every 5 minutes
}

async function performHealthCheck(scope: string) {
  // Check systemd services, agent heartbeats, cron jobs
  // Returns { status: "ok" | "warning" | "critical", anomalies: [...] }
  return { status: "ok", anomalies: [] };
}

async function sendNotification(message: string, urgency: string) {
  // Send via configured channel (Telegram, etc.)
}
```

#### systemd Unit (Pi Watcher)

```ini
# /etc/systemd/system/pi-watcher.service
[Unit]
Description=Pi Agent Watcher (always-on observer)
After=network.target

[Service]
Type=simple
User=zoid
Group=zoid
WorkingDirectory=/dev/pistisai
ExecStart=/home/zoid/.local/bin/pi \
  --provider llamacpp \
  --model google_gemma-4-E4B-it \
  --extension /dev/pistisai/watcher/observer-extension.ts
Restart=always
RestartSec=10

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

#### Install Script

```bash
#!/bin/bash
# watcher/scripts/install.sh
set -euo pipefail

# Copy extension
mkdir -p /dev/pistisai/watcher
cp observer-extension.ts /dev/pistisai/watcher/

# Install systemd unit
sudo cp systemd/pi-watcher.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now pi-watcher

echo "Pi Watcher installed and started"
sudo systemctl status pi-watcher --no-pager
```

---

### Phase 4: Pi as Subagent (GitHub #287)

**Goal:** On-demand coding delegate
**Estimated:** 1-2 days

#### Approach: `pi --print` Mode

The simplest subagent pattern — spawn Pi in headless print mode for one-shot tasks:

```dart
// lib/services/pi_manager/pi_subagent.dart
import 'dart:io';
import 'dart:convert';

/// Spawns Pi as a subagent for focused coding tasks.
///
/// Uses `pi --print` mode for headless one-shot execution.
/// The active harness delegates work, Pi does it, reports back.
class PiSubagent {
  Future<SubagentResult> execute(String task, {String? cwd}) async {
    final result = await Process.run(
      'pi',
      ['--print', '--provider', 'llamacpp', '--model', 'google_gemma-4-E4B-it', task],
      workingDirectory: cwd ?? '/dev/pistisai',
    );

    return SubagentResult(
      success: result.exitCode == 0,
      output: result.stdout as String,
      error: result.stderr as String,
    );
  }
}

class SubagentResult {
  final bool success;
  final String output;
  final String error;
  SubagentResult({required this.success, required this.output, required this.error});
}
```

#### Integration with Active Harness

When Hermes/OpenClaw/Pi needs coding work:
1. Harness calls `PiSubagent.execute("Fix the login button styling")`
2. Pi spawns, does the work, exits
3. Result returned to harness with attribution: "via Pi subagent"

---

### Phase 5: Watcher L2-L3 + Mesh (GitHub #288)

**Goal:** A2A peer communication + accountability
**Estimated:** 2-3 days

#### Install A2A Extension

```bash
# On VPS (watcher)
pi install npm:@bacnh85/pi-a2a
```

#### Configure A2A Peers

```json
// ~/.pi/agent/settings.json
{
  "a2a": {
    "port": 9910,
    "peers": {
      "hermes": { "url": "http://localhost:9900", "token": "..." },
      "elencho": { "url": "http://localhost:9901", "token": "..." }
    }
  }
}
```

#### Layered Oversight

| Layer | Trigger | Action |
|-------|---------|--------|
| **L1: Passive** | Tool call/result events | Log + self-correct via extension |
| **L2: Active** | Cron heartbeat (every 30 min) | A2A message to peer for second opinion |
| **L3: Intervention** | Anomaly + peer confirms | Surface question to Christopher |

#### Accountability Question Format

From elencho-accountability-cron pattern:
```
🪞 [One pointed question about a specific drift signal]
```

Not a report. A question. Forces engagement without noise.

---

### Phase 6: Desktop Control

**Goal:** Pi can see and control the desktop
**Estimated:** 1-2 days

#### Install computer-use-linux

```bash
# On right-pc
pi install npm:@agent-sh/computer-use-linux
```

#### MCP Configuration

```json
// ~/.pi/agent/settings.json
{
  "mcp": {
    "servers": {
      "computer-use": {
        "command": "npx",
        "args": ["@agent-sh/computer-use-linux"]
      }
    }
  }
}
```

#### Desktop Control Flow

```
User: "Click the Firefox icon"
  → Pi calls screenshot tool
  → computer-use-linux captures screen → returns PNG
  → mmproj encodes image → Gemma 4 E4B analyzes
  → Pi calls click(x, y) tool
  → computer-use-linux executes via AT-SPI/ydotool
  → Desktop action completed
```

#### Safety

- `computer-use-linux` marks tools with `destructiveHint=true`
- Pi should ask user before destructive actions
- Screenshot data stays local
- All desktop actions logged

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

---

## Hardware Compatibility

### Christopher's PC (right-pc)

| Component | Spec | Verdict |
|-----------|------|---------|
| CPU | Intel i5-13600KF (14c/20t) | ✅ Excellent |
| GPU | RTX 4070 (12GB VRAM, sm_89) | ✅ Great for local LLM |
| RAM | 62GB (48GB free) | ✅ Massive headroom |
| Disk | 399GB free | ✅ Plenty of room |
| CUDA | Driver 580.159 + CUDA 13 | ✅ Ready |
| Bun | 1.4.2 installed | ✅ Exceeds 1.3.14 min |

### Minimum for Other Users

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| GPU | 6GB VRAM (RTX 3060) | 12GB (RTX 4070) |
| RAM | 16 GB | 32 GB |
| Disk | 10 GB free | 20 GB |
| CUDA | 12.x driver | 12.8+ |
| Bun | 1.3.14+ | 1.4.x |

---

## Research Appendix

### Key Sources

| Topic | Source | URL |
|-------|--------|-----|
| Pi RPC Protocol | pi.dev/docs | https://pi.dev/docs/latest/rpc |
| Pi SDK | pi.dev/docs | https://pi.dev/docs/latest/sdk |
| oh-my-pi Extensions | GitHub | https://github.com/can1357/oh-my-pi/blob/main/docs/extensions.md |
| Pi ↔ llama.cpp | pi.dev/docs | https://pi.dev/docs/latest/settings |
| A2A Extension | pi.dev | https://pi.dev/packages/@bacnh85/pi-a2a |
| Desktop Control | pi.dev | https://pi.dev/packages/@agent-sh/computer-use-linux |
| llama.cpp Router | HuggingFace Blog | https://huggingface.co/blog/ggml-org/model-management-in-llamacpp |
| systemd + llama.cpp | simplified.guide | https://simplified.guide/llama-cpp/server-run-systemd-service |
| Watchdog Pattern | dev.to | https://dev.to/meridian-ai/the-watchdog-pattern-how-to-build-ai-systems-that-fix-themselves |
| Agent Accountability | therealcat.ai | https://therealcat.ai/lab-notes-when-your-agent-learns-to-lie-about-working |
| Gemma 4 E4B GGUF | HuggingFace | https://huggingface.co/bartowski/google_gemma-4-E4B-it-GGUF |
| pi-skills Ecosystem | GitHub | https://github.com/PSPDFKit-labs/pi-skills |
| Accountability Cron | Skill | elencho-accountability-cron |

### Model Specs (Gemma 4 E4B-it)

| Spec | Value |
|------|-------|
| Effective params | 4.5B |
| Total (with embeddings) | 8B |
| Modalities | text + image + audio |
| Q4_K_M size | 5.41 GB |
| Q8_0 size | 8.03 GB |
| Speed (12GB card) | ~45 tok/s |
| License | Apache-2.0 |
| Context | 32768 tokens |

### Pi CLI Quick Reference

```bash
# Interactive mode
pi

# RPC mode (for Flutter subprocess)
pi --mode rpc --provider llamacpp --model google_gemma-4-E4B-it

# Print mode (for subagent one-shot)
pi --print "Fix the login bug"

# Install extension
pi install npm:@bacnh85/pi-a2a
pi install npm:@agent-sh/computer-use-linux

# List installed
pi list
```

### llama.cpp Build Flags (RTX 4070)

```bash
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89
cmake --build build --config Release -j $(nproc)
```

Architecture `89` = Ada Lovelace (RTX 4070/4080/4090)
