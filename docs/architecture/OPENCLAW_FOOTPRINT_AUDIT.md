# OpenClaw footprint audit

Status: proposal for the repository owner (issue #1042). No code changes are made by this document.

Audited tree: `origin/main` at `360737d1` (2026-11-27). Line numbers refer to that commit.

Direction from #1042: Hermes is the primary agent harness. OpenClaw stays a supported harness, but engineering, tests, fixes and CI go to Hermes first. This audit lists every OpenClaw-related piece in the repository, says what it does today, whether it runs by default, whether it gets in the way of Hermes work or CI, and recommends one of:

- **Keep**: shared or harness-neutral; at most a wording change.
- **Gate**: OpenClaw-only behaviour that should run only when the user picks OpenClaw (the gate is described).
- **Remove**: dead or misleading code with no caller.

Anything the audit could not confirm from the code alone is marked **unverified**.

Method: `git grep -i openclaw`, `grep -rn 18789`, and reading each caller from `lib/di/locator.dart` outward. `lib/l10n/*.arb` contains no OpenClaw strings. No Dockerfile mentions OpenClaw.

## Key findings

1. **The app has no OpenClaw runtime path any more.** `BackendType` has only `hermes` (`lib/services/connection_manager_service.dart:19-21`, `lib/services/settings_preference_service.dart:9`), `ProviderType` has no OpenClaw value (`lib/models/provider_configuration.dart:8-14`), and runtime discovery scans Hermes only (`lib/services/provider_discovery_service.dart:39-45`). A saved OpenClaw backend degrades to "No backend selected" (`lib/services/unified_connection_service.dart:40-45`). What remains is OpenClaw-era code wired into the Hermes path, plus docs that still describe OpenClaw as fully supported.
2. **A Hermes connection runs the `openclaw` CLI.** `GatewayControlService` is registered on every platform (`lib/di/locator.dart:580-584`) and wired to the connection manager (`lib/di/locator.dart:983-988`). When the Hermes backend connects, it calls `checkStatus()` (`lib/services/openclaw_manager/gateway_control_service.dart:46-57`), which spawns `openclaw gateway status --json` (`gateway_control_service.dart:160-163`). If that CLI is installed and reports running, a 30-second health timer starts and may call `openclaw gateway start` (`gateway_control_service.dart:197-225`). Nothing in `lib/` calls `start()`, `stop()` or `restart()`.
3. **The "Auto-restart Runtime on Failure" switch does not act on Hermes.** The switch (`lib/screens/config/config_screen.dart:542-545`, label `configAutoRestart` in `lib/l10n/app_en.arb:1339`) is read only by `GatewayControlService` (`config_screen.dart:139-140`), which restarts OpenClaw through its CLI. For a Hermes user the switch changes nothing, which conflicts with "Controls tell the truth".
4. **Desktop startup creates `~/.openclaw/skills/pistisai`** even for Hermes-only users (`lib/di/locator.dart:97-138`, used at `lib/di/locator.dart:224-227`). Hermes receives the personality over HTTP instead (`docs/avatar/PERSONALITY_AND_HERMES.md`).
5. **`AgentLifecycleService` sends OpenClaw-style WebSocket RPC frames** (`agent.list`, `agent.start`, `agent.stop`, `agent.status`) when Hermes is connected (`lib/services/agent_lifecycle_service.dart:184-199`, `:219-226`, `:456-474`). `ConnectionManagerService.wsChannel` is never assigned a channel (`lib/services/connection_manager_service.dart:153`, `:160`, `:233`), so the frames are dropped and each call waits for its 10-second timeout (`agent_lifecycle_service.dart:228-230`). The agent detail screen depends on it (`lib/screens/dashboard/agent_detail_screen.dart:36-105`).
6. **CI cost is small and isolated.** The OpenClaw skill's Vitest suite (added by #1038) runs as the last two steps of the `other-suites` job, after the Hermes plugin tests (`.github/workflows/extended-tests.yml:122-133`). `GatewayControlService` unit tests run in the Flutter security gate (`scripts/ci/flutter_security_basic_tests.sh:60`). Neither blocks Hermes tests from running.

## Summary table

| # | Item | Runs by default? | Blocks or slows Hermes / CI? | Recommendation |
|---|---|---|---|---|
| 1 | `GatewayControlService` (`openclaw` CLI) | Yes, on Hermes connect (desktop) | Spawns a foreign CLI on the Hermes path | Gate, then remove if OpenClaw control is not rebuilt |
| 2 | "Auto-restart Runtime on Failure" switch | Shown in Config | Misleads Hermes users | Hide or relabel with item 1 |
| 3 | `_getOpenClawSkillsPath()` / Markdown sync folder | Yes, desktop startup | Creates a folder Hermes never reads | Gate: app-owned folder by default |
| 4 | `AgentLifecycleService` RPC frames | Yes, on Hermes connect | 10 s timeouts, empty agent detail | Gate or remove; Hermes data via Hermes client |
| 5 | `AgentStatusService` | When the status screen polls | No (returns empty list) | Keep; fix comment |
| 6 | `AppConfig` gateway host/port (`OPENCLAW_GATEWAY_*`, 18789) | Compile-time defaults | Onboarding falls back to 18789 | Gate: rename, Hermes fallback |
| 7 | `GuiAutomationService` endpoint | Only on `/gui-automation` | Points at 18789 | Gate: use selected runtime / router |
| 8 | `SettingsCategoryIds.openClawGateway` | No (ids unused outside the model) | No | Remove |
| 9 | `AgentRuntimeKind.openclaw` | No (never constructed) | No | Keep as optional harness id |
| 10 | Comments naming OpenClaw on shared services | n/a | Confuses readers | Keep code; reword comments |
| 11 | `services/openclaw-skills/pistisai/` | CI only | ~1 extra `npm ci` + Vitest in one job | Keep as optional harness package |
| 12 | `POST /agent/events` webhook (`OPENCLAW_WEBHOOK_SECRET`) | Mounted; 500 without secret | No | Keep; make harness-neutral |
| 13 | `scripts/install.sh` | No (no caller) | No | Remove |
| 14 | `scripts/install-openclaw-skill.sh` | No (docs only) | No | Keep as OpenClaw-only helper; fix paths in docs |
| 15 | Env examples and compose files | Compose passes the variable | No | Keep; rename with item 12 |
| 16 | User and architecture docs | n/a | Overstate OpenClaw support | Docs PR |
| 17 | `AGENTS.md`, `CONTRIBUTING.md`, `README.md`, `.gitignore` | n/a | No | Small wording updates; keep `.gitignore` |
| 18 | Tests that assert "no OpenClaw" in Hermes UI | Yes (CI) | No, they protect Hermes-first | Keep |

## Inventory

### A. Flutter app (`lib/`)

**A1. `GatewayControlService`**: `lib/services/openclaw_manager/gateway_control_service.dart`

- Does today: `start()`, `stop()`, `checkStatus()` run `openclaw gateway start|stop|status --json` through `Process.run` (`:89-91`, `:129-131`, `:160-163`). A health timer every 30 s calls `checkStatus()` and, when auto-restart is on and the gateway had started, calls `start()` up to 5 times (`:197-225`). `_onConnectionChanged()` calls `checkStatus()` whenever the **Hermes** backend is connected and healthy (`:46-57`).
- Registered in `setupCoreServices()` without a platform guard (`lib/di/locator.dart:580-584`), fetched and wired at `lib/di/locator.dart:952` and `:983-988`. No widget or screen in `lib/` reads it (only `test/screens/cockpit_screens_test.dart:78-176` registers a fake).
- Runs by default: yes. On desktop it spawns a process on each Hermes connect. On web, `Process.run` throws and the error is caught (`:188-194`).
- Impact on Hermes: an unrelated CLI is executed on the Hermes path; if that CLI exists and reports "running", a background timer may start an OpenClaw gateway the user did not ask for. **Unverified:** how often `_onConnectionChanged` fires per session.
- Recommendation: **gate**, then **remove** if no OpenClaw control UI is planned. Gate: register it only when a saved runtime of kind OpenClaw exists (today none can be saved, see Key finding 1), and drop the `BackendType.hermes` trigger at `:48`. Lifecycle control for Hermes already lives in `lib/services/hermes_manager/hermes_gateway_control_service.dart` (also unregistered today; **unverified** whether it is meant to replace this service).

**A2. Auto-restart switch**: `lib/screens/config/config_screen.dart:139-140`, `:243-244`, `:258`, `:542-545`; preference at `lib/services/settings_preference_service.dart:429-438`.

- Does today: saves `gateway_auto_restart`; only `GatewayControlService` reads it (`gateway_control_service.dart:67-69`).
- Impact: the label "Auto-restart Runtime on Failure" reads as a Hermes feature but restarts nothing for Hermes.
- Recommendation: **gate** together with A1. Hide the switch until a Hermes restart path reads it, or wire it to the Hermes control service in a separate, tested PR. Keep `config_screen_controls_test.dart:109` in step.

**A3. OpenClaw skills folder for avatar Markdown**: `lib/di/locator.dart:97-138`, used at `:224-227`; `lib/services/avatar/markdown_sync_service.dart:6-10`.

- Does today: on desktop, looks for `~/.openclaw/skills/pistisai` (and two other OpenClaw locations) and **creates** `~/.openclaw/skills/pistisai` if none exists, then writes `personality.md`, `memory.md`, `context.md` there.
- Runs by default: yes, at desktop startup, inside the `!kIsWeb` block (`lib/di/locator.dart:206`).
- Impact on Hermes: creates an OpenClaw folder in the user's home on Hermes-only machines; Hermes does not read it (Hermes gets the personality from `POST /api/pistisai/personality`, see [Personality and Hermes](../avatar/PERSONALITY_AND_HERMES.md)).
- Recommendation: **gate**. Default to an app-owned folder (the app support directory) and write into an OpenClaw skill folder only when that folder already exists or the user selects OpenClaw. The privacy text that names `~/.openclaw/skills/pistisai` (`docs/governance/legal/PRIVACY.md:82-88`, `docs/user-guide/LOCAL_DATA_EXPORT_DELETION.md:13`) and the deletion code must change in the same PR.

**A4. `AgentLifecycleService`**: `lib/services/agent_lifecycle_service.dart:145-199`, `:219-226`, `:456-474`; registered at `lib/di/locator.dart:1032-1039`, provided at `lib/main.dart:450`.

- Does today: when Hermes is connected, sends `{"type":"req","method":"agent.list"}` style frames, the OpenClaw Gateway WebSocket protocol, through `ConnectionManagerService.wsChannel`. That getter is never assigned a channel (`lib/services/connection_manager_service.dart:153`, `:160`, `:233`), so `_sendToGateway` logs "WebSocket not connected" and the caller times out after 10 s.
- Runs by default: yes, `listAgents()` is called automatically on each ready transition (`:189-199`).
- Impact on Hermes: a 10-second timeout and an empty agent list on the agent detail screen (`lib/screens/dashboard/agent_detail_screen.dart:36-105`). **Unverified:** whether Hermes exposes any agent list/start/stop API at all.
- Recommendation: **gate or remove**. Remove the auto-refresh on Hermes, and either back the screen with the Hermes runtime client (`lib/services/agent_runtime/hermes_runtime_client.dart`) or hide the start/stop controls until a Hermes API exists.

**A5. `AgentStatusService`**: `lib/services/agent_status_service.dart:50`, `:141`.

- Does today: polls `ConnectionManagerService.getSessionsList()`, which is a stub returning `[]` (`lib/services/connection_manager_service.dart:601-604`). Only the comment names OpenClaw.
- Recommendation: **keep**; reword the comment. Wiring Hermes sessions is Hermes work, not OpenClaw cleanup.

**A6. Gateway defaults in `AppConfig`**: `lib/config/app_config.dart:126-133`, `:172-186`, `:196-241`, `:243-244`; `lib/models/provider_configuration.dart:48`; `lib/database/drift_local_brain.dart:189-193`.

- Does today: the "gateway" host/port default to `127.0.0.1:18789`, overridable with `OPENCLAW_GATEWAY_HOST|PORT|URL` dart-defines. `AppConfig.gatewayUrl` is read by onboarding as the last fallback (`lib/screens/onboarding/steps/connection_test_step.dart:47-52`) and by GUI automation (A7).
- Impact on Hermes: if the wizard has no Hermes, custom or selected URL, the connection test probes the OpenClaw port instead of Hermes `127.0.0.1:8642` (`app_config.dart:136-139`). **Unverified:** whether the wizard can reach that step with all three empty.
- Recommendation: **gate**. Fall back to `AppConfig.defaultHermesUrl` in onboarding; rename the generic getters away from OpenClaw or move them behind an OpenClaw harness config. Keep the `OPENCLAW_GATEWAY_*` defines readable for one release if anyone builds with them (**unverified**; no workflow passes them).

**A7. `GuiAutomationService`**: `lib/services/gui_automation_service.dart:19`, `:34`, `:82-100`; route `/gui-automation` (`lib/screens/gui_automation_lazy.dart:8-19`, linked from `lib/screens/settings/desktop_settings_screen.dart:59`).

- Does today: probes `$gatewayUrl/status` and posts screenshots to `$gatewayUrl/v1/chat/completions`, i.e. `127.0.0.1:18789` by default.
- Runs by default: only when the screen is opened.
- Recommendation: **gate**. Point it at the selected runtime or the embedded router (port `1337`), and keep the local LM Studio path. Check the data flow against "Nothing leaves the device without consent" when the target changes.

**A8. `SettingsCategoryIds.openClawGateway`**: `lib/models/settings_category.dart:106`, `:126`, `:135`, `:198`, `:232`, `:266`, `:300`.

- Does today: metadata only. No file outside the model references `SettingsCategoryIds`. The comment at `:135` ("using OpenClaw Gateway only") is wrong.
- Recommendation: **remove** the id and its cases; fix the comment.

**A9. `AgentRuntimeKind.openclaw`**: `lib/services/agent_runtime/agent_runtime_client.dart:5-10`.

- Never constructed (only `hermes` is used, `hermes_runtime_client.dart:35`).
- Recommendation: **keep**. It is the natural id for an optional OpenClaw harness client behind the same interface.

**A10. Comments only (no behaviour)**

| Location | Recommendation |
|---|---|
| `lib/services/device_identity_service.dart:8` ("for OpenClaw Gateway authentication"; actually used by `lib/services/cloud_connector_service.dart:133-134`) | Keep code, reword |
| `lib/services/onboarding/setup_wizard_service.dart:42` (`gatewayPassword`) | Keep, reword; **unverified** whether Hermes uses it |
| `lib/services/popout/popout_window.dart:3` | Reword |
| `lib/services/hermes_manager/hermes_gateway_control_service.dart:12` | Reword |
| `lib/database/drift_local_brain.dart:189-192`, `:467` ("OpenClaw-owned") | Reword the comments only; no schema change, no regeneration needed for comments |
| `lib/screens/debug/debug_screen.dart:24`, `:104` | Keep (states Hermes is the default) |
| `lib/services/unified_connection_service.dart:41` | Keep (documents the degrade path) |

### B. OpenClaw skill package: `services/openclaw-skills/pistisai/`

- Does today: a TypeScript OpenClaw skill (`index.ts`, `prompt.ts`, `evolution.ts`, `state.ts`, `drift-adapter.ts`) that injects the avatar personality into OpenClaw agents (`SKILL.md`, `package.json:4`). Dependencies: `sql.js`; dev: `typescript`, `vitest` (`package.json:21-28`). Its lockfile and CI wiring came from #1038.
- Shared value: the Hermes plugin's tone wording mirrors `prompt.ts` (`assets/pistisai/hermes/plugins/pistisai/__init__.py:478`, `docs/avatar/PERSONALITY_AND_HERMES.md:19`).
- Runs by default: not in the app; only in CI (see D1) and when a user installs it with `scripts/install-openclaw-skill.sh`.
- Impact: none on Hermes. CI cost is one `npm ci` plus one Vitest file in the `other-suites` job.
- Recommendation: **keep** as the optional OpenClaw harness package. Do not grow it. When the personality wording changes, change the Hermes plugin first and treat `prompt.ts` as the mirror. **Unverified:** whether any user installs this skill today.

### C. Backend: `services/api-backend/`

**C1. Agent events webhook**: `services/api-backend/routes/agent-events.js:9`, `:38-78`, `:80-140`; `services/api-backend/routes/openclaw-webhook-secret.js:1-9`; mounted at `services/api-backend/server.js:147`, `:370` (`/agent/events` and `/api/agent/events`).

- Does today: accepts `POST` events signed with HMAC-SHA256 in `x-openclaw-signature`, using only `OPENCLAW_WEBHOOK_SECRET` (never `JWT_SECRET`). Without the secret it answers 500 "Webhook secret not configured"; a bad signature answers 401. Valid events upsert `agents` rows, store `agent_events` and broadcast to the owning user.
- Runs by default: mounted on every api-backend; inert without the secret.
- Harness-neutral? The handler is generic; only the header and variable names are OpenClaw-specific. **Unverified:** whether any OpenClaw deployment posts to it; nothing in this repository does.
- Related: `lib/services/brain_sync_service.dart:191-198` posts to the same route with a Bearer token and no signature, and `:256-257` reads `GET /api/agent/events`, which has no handler. Sync only runs when cloud services are enabled (`lib/di/locator.dart:249-254`). **Unverified** end to end, but as written those uploads would be refused by the signature check. That is a sync bug, not an OpenClaw one; track it separately.
- Tests: `test/api-backend/agent-events-webhook-secret.test.js`, `test/api-backend/agent-events-raw-hmac-895.test.js`, in the security gate (`services/api-backend/jest.ci-security.config.js:30`, `:32`).
- Recommendation: **keep** (security tests protect it). Later, make it harness-neutral: accept `AGENT_WEBHOOK_SECRET` and `x-agent-signature`, keep the OpenClaw names as aliases for one release, and update the tests and env examples together.

**C2. Migration comments**: `services/api-backend/database/migrations/021_add_agent_dashboard.sql:12`, `:17`.

- Recommendation: **keep**. Applied migrations are not edited; a later migration or doc can describe `agents` as harness-neutral.

### D. CI and test wiring

**D1. `extended-tests.yml`**: `.github/workflows/extended-tests.yml:79-82` (job `other-suites`, 15-minute timeout), `:122-123` (Hermes plugin unittest), `:127-133` (OpenClaw skill `npm ci` + `npm test`).

- Runs on every pull request and push to `main` (`:8-15`). The OpenClaw steps come after the Hermes steps in the same job, so a failure there marks the job red but does not stop Hermes tests from running. **Unverified:** whether this job is a required check (branch protection could not be read).
- Recommendation: **keep** as merged in #1038. If it ever becomes flaky, move the two steps into their own non-required job rather than deleting them.

**D2. Flutter security gate**: `scripts/ci/flutter_security_basic_tests.sh:60` runs `test/services/openclaw_manager/`.

- Recommendation: **keep** while A1 exists; remove the path in the same PR that removes or moves `GatewayControlService`.

**D3. Tests that guard Hermes-first UI** (keep): `test/screens/onboarding/connection_method_step_test.dart:13-35`, `test/screens/onboarding/mobile_connection_screen_test.dart:36`, `test/widgets/voice/open_voice_ui_control_panel_test.dart:58-62`, `test/screens/debug/debug_screen_hermes_url_test.dart:7-11`, `test/integration/runtime-discovery.test.js:5`, `:86`.

**D4. `test/screens/cockpit_screens_test.dart:9`, `:78-176`**: registers a fake `GatewayControlService`. Update with A1.

### E. Scripts

**E1. `scripts/install.sh`**

- Does today: a placeholder installer. The download is commented out (`:25-37`), it runs `npm install -g openclaw-gateway` when `openclaw` is missing (`:39-48`), edits shell rc files (`:50-58`) and prints "installed successfully" (`:60`). The real Linux installer is `web/install.sh` / `dist/linux/install.sh` (`.github/workflows/build-desktop.yml:163`, `README.md:17`). Nothing references `scripts/install.sh`.
- Impact: reports success for work it does not do, and installs a global npm package the user did not ask for. **Unverified:** what the `openclaw-gateway` npm package is.
- Recommendation: **remove**.

**E2. `scripts/install-openclaw-skill.sh`**

- Does today: copies the skill into an OpenClaw skills folder and probes `http://localhost:18789/health` (`:141-146`). Referenced only by `docs/avatar/README.md:254`, `:463`.
- Recommendation: **keep** as the OpenClaw-only helper. Fix the paths quoted in `docs/avatar/README.md:258-260`, `:453` (`Pistisai/avatar_personality`), which do not match the code (`pistisai`).

### F. Configuration and deployment

| Location | Today | Recommendation |
|---|---|---|
| `.env.example:34-37` | Documents `OPENCLAW_WEBHOOK_SECRET` | Keep; rename with C1 |
| `config/docker-compose.env.example:15-18` | Same | Keep; rename with C1 |
| `docker-compose.yml:134`, `docker-compose.prod.yml:32`, `docker-compose.multi.yml:85` | Pass the variable to api-backend | Keep; rename with C1 |
| Dockerfiles (`Dockerfile.*`, `config/docker/Dockerfile.*`, `services/*/Dockerfile`) | No OpenClaw content | Nothing to do |
| `.gitignore:1-2` (`.openclaw/`) | Keeps a local OpenClaw folder out of git | Keep |

### G. Repository guides

| Location | Today | Recommendation |
|---|---|---|
| `AGENTS.md:37` | Lists `services/openclaw-skills/` | Keep; mark as optional harness |
| `AGENTS.md:39` | Lists OpenClaw Gateway `localhost:18789` first among discovery defaults | Reword: Hermes first; OpenClaw is a configuration target, not discovered (matches `docs/architecture/SYSTEM_ARCHITECTURE.md:104`). Needs the owner's OK since `AGENTS.md` is the shared guide. |
| `CONTRIBUTING.md:109` | Branding rule lists `Pistisai` twice | Keep the rule; remove the duplicate |
| `README.md:21`, `:55` | "Hermes is the primary test path. OpenClaw and compatible agent gateways also work." | Reword after the docs PR settles what "work" means today (see H) |

### H. Documentation (`docs/`, excluding `docs/archive/`)

The guardrail "Docs describe what the code does today" applies. With no OpenClaw backend type (Key finding 1), these claims are ahead of the code:

| Location | Claim | Recommendation |
|---|---|---|
| `docs/LAUNCH.md:21` | OpenClaw "Supported: Gateway control and skill management" | No screen uses gateway control. Reword as "optional harness; reach it as a compatible gateway" or "planned". |
| `docs/user-guide/FEATURES_GUIDE.md:27`, `:133` | "OpenClaw Skill Registry"; OpenClaw is the "Default integration" | Remove "Default"; check the skills screen (`lib/screens/skills/skills_screen.dart`) and reword |
| `docs/user-guide/SETUP_GUIDE.md:35-48`, `USER_GUIDE.md:37`, `:70`, `TROUBLESHOOTING.md:22-23` | OpenClaw Gateway as a setup choice at `localhost:18789` | Move under an "Optional harness" heading; say how it is selected today (**unverified**: as a custom gateway) |
| `docs/deployment/installation/README.md:28`, `LINUX.md:25`, `MACOS.md:69`, `WINDOWS.md:26` | Default port table row | Keep the row, label "optional harness" |
| `docs/architecture/AGENT_RUNTIME_CONTRACT.md:22`, `:49-50`, `:133-137`, `:163` | OpenClaw in the selection order | Keep, but state Hermes-first and that the app has no OpenClaw backend type today |
| `docs/architecture/SYSTEM_ARCHITECTURE.md:69`, `:102`, `:201`, `:236` | Lists `GatewayControlService` and skill package | Update when A1/A3 change |
| `docs/architecture/AVATAR_SYSTEM.md:30`, `:117-124`; `docs/avatar/README.md` (13 mentions) | OpenClaw skill as the integration | Lead with the Hermes plugin; keep the skill as the OpenClaw option; fix paths (E2) |
| `docs/specs/vector-memory-system.md:10`, `:107` | Spec written for "the OpenClaw Agent" | Reword to "the agent runtime" or mark as historical |
| `docs/governance/legal/PRIVACY.md:82-88`, `docs/user-guide/LOCAL_DATA_EXPORT_DELETION.md:13` | Avatar Markdown in `~/.openclaw/skills/pistisai` | Accurate today; change only together with A3 |
| `docs/development/testing/COMPREHENSIVE_TESTING_GUIDE.md:82` | How to run the skill tests | Keep |
| Other orientation lines (`docs/index.md`, `docs/development/QWEN.md`, `docs/deployment/*.md`, `docs/architecture/SECURE_DEVICE_MESH.md`, `docs/governance/legal/CLOUD_PROVIDER_DATA_FLOW.md:19`, `docs/architecture/service_lifecycle.md`) | List OpenClaw next to Hermes | Keep; they already say Hermes is first |
| `docs/archive/**` | Historical | Leave untouched |

## Proposed follow-up PRs

Each is small, single-purpose and Hermes-first. Order puts behaviour on the Hermes path first.

1. **Stop running the `openclaw` CLI on Hermes connect (A1, A2, D2, D4).** Remove the Hermes trigger in `GatewayControlService._onConnectionChanged`, stop registering the service by default, hide the auto-restart switch (or keep it only when a restart path reads it). Tests: a Hermes connection does not call the process runner; the Config screen has no switch that does nothing. Remove `test/services/openclaw_manager/` from the gate only if the service is deleted.
2. **Onboarding falls back to Hermes, not 18789 (A6).** `connection_test_step.dart` uses `AppConfig.defaultHermesUrl`. One widget test.
3. **App-owned folder for avatar Markdown (A3).** Stop creating `~/.openclaw/...`; write there only if it exists or OpenClaw is chosen. Same PR updates `PRIVACY.md`, the matching section of `web/privacy.html`, `LOCAL_DATA_EXPORT_DELETION.md`, and the deletion code.
4. **Agent lifecycle on Hermes (A4).** Remove the OpenClaw RPC auto-refresh; hide start/stop until a Hermes API backs them ("Controls tell the truth").
5. **Dead code and comments (A8, A10, E1).** Delete `SettingsCategoryIds.openClawGateway` and `scripts/install.sh`; reword comments. No behaviour change.
6. **GUI automation target (A7).** Point at the selected runtime or router; check consent text.
7. **Docs truth pass (G, H).** Hermes-first wording, OpenClaw labelled "optional harness", no claim of gateway control that the code does not have. `AGENTS.md` lines need the owner's OK.
8. **Harness-neutral agent events webhook (C1, F).** Generic secret and header with OpenClaw aliases; tests and env examples in the same PR. Track the `BrainSyncService` mismatch as its own issue.

Optional harness gate, for later OpenClaw work: a single `AgentRuntimeKind.openclaw` client behind `AgentRuntimeClient`, registered only when the user saves an OpenClaw runtime, so no OpenClaw code runs on a Hermes-only install.

## Leave untouched

- The #1038 changes (merged): `services/openclaw-skills/pistisai/package-lock.json`, the `other-suites` OpenClaw steps in `.github/workflows/extended-tests.yml:125-133`, and the api-backend suites it enabled. Do not expand OpenClaw scope there.
- `docs/archive/**`.
- Applied migrations (`021_add_agent_dashboard.sql`).
- The Hermes desktop hub and Hermes plugin (`assets/pistisai/hermes/`).
- Generated files (`*.g.dart`, `lib/l10n/app_localizations*.dart`).

## Unverified items to confirm before acting

- How often `GatewayControlService._onConnectionChanged` fires per Hermes session (A1).
- Whether `HermesGatewayControlService` is meant to replace `GatewayControlService` (A1).
- Whether Hermes offers any agent list/start/stop API (A4).
- Whether onboarding can reach the connection test with no Hermes, custom or provider URL (A6).
- Whether any build passes `OPENCLAW_GATEWAY_*` dart-defines (A6).
- Whether any OpenClaw deployment posts to `/agent/events` (C1) and whether `BrainSyncService` uploads are refused in practice (C1).
- Whether `other-suites` is a required status check (D1).
- What the `openclaw-gateway` npm package installed by `scripts/install.sh` is (E1).
- How a user selects OpenClaw in the wizard today, if at all (H).
