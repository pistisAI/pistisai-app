# Pistisai Features Guide

Pistisai is a local-first, privacy-first companion shell and desktop capability layer for user-selected agent runtimes. It gives your chosen agent runtime (Hermes, OpenClaw, or custom compatible gateways) a secure connection channel to your desktop, combined with structured permissions for GUI automation, voice conversation, vision capabilities, and multi-device Tailscale mesh coordination.

---

## 🗺️ Application Map

The Pistisai interface is divided into functional modules designed around a secure conversation model:

```
Pistisai App Shell
├── 💬 Chat Interface (Home)
│   ├── Streaming Timeline & Thinking Previews
│   ├── Model Selector (Exposed by Active Runtime)
│   └── Session Selector (Historical Conversation Contexts)
├── 📊 Navigation Dashboard
│   ├── Overview (App & Connection Health Metrics)
│   ├── Channels (Configuration of Secure API Endpoints)
│   ├── Sessions (Management of Conversations & Timelines)
│   ├── Runtimes (Detailed Node Latency & Capability Review)
│   └── Usage (Token Utilization, System Resources & Request Counters)
├── ⚙️ Management Panels
│   ├── Agents (List & Toggle Active Run Configurations)
│   ├── Skills (OpenClaw Skill Registry, Usage Logs & Settings)
│   ├── Nodes (Mesh Connection Nodes & Tailscale Peers)
│   └── Cron Jobs (Scheduled Background Agent Workflows)
├── 🛡️ Admin Center (Authorized Access Only)
│   ├── User Management, Roles & Custom Permissions
│   ├── Payments & Subscriptions Audit logs
│   ├── Financial Reports & Analytics Charts
│   └── Email Configurations, Metrics & DNS Settings
└── 🛠️ Settings & Advanced Config
    ├── General, Appearance & Themes
    ├── Desktop Permissions & Vision Settings
    └── Debugging Dashboard & Live App Logs
```

---

## 💬 1. Secure Agent Channel (Chat)

The primary interface is a direct, secure line of communication to your active agent runtime.

*   **Streaming Responses:** Direct token-by-token message rendering with real-time stream state tracking.
*   **Thinking Artifact Previews:** Shows model "thinking" timelines and artifact states inline before output generation (for supported reasoning runtimes).
*   **Model Selection:** Dynamic model switching based on models exposed by the active agent gateway (e.g. Hermes or OpenClaw models).
*   **Session Management:** Create, delete, search, and toggle sessions directly from the sidebar.
*   **Local Storage:** All conversations are persisted locally in your encrypted [LocalBrain SQLite](file:///data/dev/projects/pistisai-app/lib/database/drift_local_brain.dart) database.

---

## 🦞 2. Avatar & Voice Companion

The avatar and voice companion provide presence and a hands-free conversational interface. The companion can be popped out into an independent sidecar window.

### 🎭 Visual Avatar & Trait-Based Pulsing
The companion features an expressive avatar (defaulting to a lobster `🦞` style) that reacts dynamically to the agent's personality traits and conversational states:
*   **Agent States:** `idle`, `listening`, `thinking`, `speaking`, `working`, `error`, `success`.
*   **Trait-Driven Aesthetics:**
    *   **Color (HSL):** Derived from personality traits. Empathy controls hue, enthusiasm controls saturation, and humor controls lightness.
    *   **Pulse Speed:** Enthusiasm controls the speed of the visual pulsing animation (ranging from 1.0s down to 0.2s).
    *   **Bounce Scale:** Humor controls the scale of the avatar's bounce animation.
*   **State Emojis:** Custom emoji states adapt based on traits (e.g. high-humor agents use `😜`/`🤪`/`🎉` while high-empathy agents use `🤗`/`💭`/`🥰`).

### 🧬 Evolution & Traits
The avatar evolves along four stages based on the complexity and depth of your conversations:
1.  `curious_explorer` (Initial stage)
2.  `knowledge_seeker`
3.  `wise_companion`
4.  `enlightened_guide`
*   **Evolution Criteria:** Monitored collaboratively. Requires at least **5 deep conversations** (complexity score > 0.7) and an **average novelty score > 0.5** to upgrade stages.

### 🏆 Achievements
Earn visual achievements based on conversation history and evolution:
*   **First Conversation:** Completed first conversation with the avatar.
*   **Getting to Know You:** Achieved 5 deep conversations.
*   **Deep Thinker:** Achieved 15 deep conversations.
*   **Conversational Master:** Achieved 30 deep conversations.
*   **Novelty Seeker:** Maintained high novelty (60%+) across conversations.
*   **Evolution Tiers:** Unlocked as the avatar evolves to `knowledge_seeker`, `wise_companion`, or `enlightened_guide`.

### 🎙️ Voice & Audio
*   **Speech Input:** Microphone capture with Voice Activity Detection (VAD) and push-to-talk capability.
*   **Text-to-Speech (TTS):** Generates speech output through either the active agent runtime or local/cloud TTS providers (such as Google TTS or local OS synthesizers).

---

## 🖥️ 3. Desktop Control (GUI Automation)

Pistisai provides a sandboxed native desktop bridge allowing your agent runtime to perform controlled desktop operations.

*   **Screenshot Capture:** Programmatic desktop captures triggered via a custom native MethodChannel.
*   **Action Execution:** Supports a range of GUI interactions:
    *   `click(x, y)`: Clicks exact screen coordinates.
    *   `type(text)`: Types keyboard text inputs.
    *   `scroll(direction)`: Scrolls window contents (`up`/`down`).
    *   `keypress(key)`: Triggers custom keyboard key presses.
*   **Permission Control:** Desktop actions are strictly device-scoped. You must explicitly authorize click/type, system notifications, clipboard read/write, window manipulation, and command execution on each local device. Remote devices or cloud connections cannot control a device unless permission is explicitly granted.

---

## 👁️ 4. Vision Capabilities

Pistisai allows the agent runtime to "see" and interpret the environment on your device.

*   **Full Screen Capture:** Captures complete desktop viewports for multimodal analysis.
*   **Region Selection:** Select and crop specific screen regions.
*   **Multilingual OCR Engine:** Extract text from screen regions using an integrated [Tesseract OCR Service](file:///data/dev/projects/pistisai-app/lib/services/vision/ocr_engine_service.dart). Supports multi-language configs (default: English `eng` + Simplified Chinese `chi_sim`).
*   **Continuous Watch Modes:** Continuous regional screen captures to monitor specific workflows and alert the agent.

---

## ⏰ 5. Scheduled Tasks (Cron Jobs)

Automate routine interactions and data checks using scheduled agent workflows.

*   **Active Job Registry:** View lists of all scheduled background jobs.
*   **Interval Triggers:** Configure cron schedules to run tasks at defined intervals.
*   **Immediate Execution:** Manually run any scheduled background job instantly.
*   **Status Toggles:** Enable or disable scheduled tasks at any time.

---

## 🔗 6. Agent Runtimes & Node Management

Define and monitor where the active agent computing actually takes place.

*   **Tailscale Integration:** Connect securely to agent runtimes running on other computers, home servers, or VPS instances inside your private Tailscale network mesh.
*   **Hermes Gateway:** Configures custom endpoint connections for the Hermes agent runtime.
*   **OpenClaw Gateway:** Default integration to `http://localhost:18789` for running local openclaw skills.
*   **Health & Latency Checkers:** Monitor gateway status, latency, available system tools, and connection availability.

---

## 🧠 7. Local Intelligence Support

Optional local model servers can be configured to support app-owned background intelligence tasks without routing traffic to external APIs.

*   **LM Studio support:** Connects to `http://localhost:1234` for local text models.
*   **Ollama support:** Connects to `http://localhost:11434` for local models and embeddings.
*   **Core Uses:**
    *   **Memory Embeddings:** Generates vector embeddings for your memory service.
    *   **Summaries:** Compiles and summarizes long chat histories locally.
    *   **Semantic Search:** Indexes local brain tables for keyword search.
    *   **Lightweight Classification:** Performs category tagging.

---

## 📊 8. Usage & Resource Metrics

Keep track of the costs and resource utilization on your device.

*   **Rate Limit Utilization:** Monitors your current token usage relative to model concurrent limits.
*   **API Performance:** Measures requests per minute, latency, and success rates.
*   **Resource Monitoring:** Real-time feedback on CPU and Memory usage for local model execution.
*   **Historical Trends:** Displays usage charts segmented by Day, Week, or Month.

---

## 🛡️ 9. Admin Center

A centralized workspace for project owners and system administrators. Access is strictly authorized (restricted to `christopher.maltais@gmail.com` on Web, or open under local Guest Mode on desktop).

*   **Dashboard Overview:** Displays high-level platform stats.
*   **User Management:** Edit, search, and assign user roles or admin permissions (`viewUsers`, `viewPayments`, `viewConfiguration`, etc.).
*   **Payment Audits:** Logs transactions and tracks payment success.
*   **Subscription Management:** Adjust customer tiers and subscription configurations.
*   **Financial Reports:** Track revenues, refunds, and cost margins.
*   **Audit Logs Viewer:** Real-time log of administrative actions.
*   **Email Setup:** Configure custom SMTP, SendGrid, or mail relay hosts, edit templates, and track delivery metrics.
*   **DNS Configuration:** Manage domains, records, and hostname redirects.

---

## ⚙️ 10. Settings & Preferences

Fine-tune your local workspace appearance and parameters:

*   **Appearance:** Toggle light/dark/system themes, customize color schemes, and adjust UI text scale.
*   **Vision & Desktop:** Configure screenshot storage locations, OCR defaults, and automation permission toggles.
*   **Daemon Settings:** Manage the background processes that run Tailscale relays or local proxy servers.
*   **Database Diagnostics:** Review the SQLite local database size, table rows, and connection states.
