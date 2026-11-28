# Desktop Session Architecture (proposal)

Status: **proposed**, for the repository owner to decide. Tracks
[#1065](https://github.com/pistisAI/pistisai-app/issues/1065),
[#1066](https://github.com/pistisAI/pistisai-app/issues/1066),
[#1067](https://github.com/pistisAI/pistisai-app/issues/1067) and
[#1068](https://github.com/pistisAI/pistisai-app/issues/1068), under the
Hermes-first direction of [#1042](https://github.com/pistisAI/pistisai-app/issues/1042).

This note describes how desktop chat works today, the target design, and the
order of the pull requests that would get there. It sits next to
[`AGENT_RUNTIME_CONTRACT.md`](AGENT_RUNTIME_CONTRACT.md), which defines the
runtime terms used here.

The contract types in `lib/services/agent_session/` were added with this
note. Since then each `Conversation` carries a `ConversationChannel` (the
`pistisai` conversation is the default `direct` channel), Hermes session ids
are kept in `RuntimeSessionMap` and saved on the conversation, and the chat
sync reads history through `HermesHarnessAdapter` (all capabilities false;
turns are still sent by `HermesStreamingService`). Everything else under
"Target design" is planned work.

## 1. Current state

Line numbers are for `origin/main` when this note was written; they will move.

### One hard-coded channel

- `Conversation.pistisaiChannelId` is the constant `'pistisai'`
  (`lib/models/conversation.dart:40`). Every desktop conversation maps onto
  this one shared direct message.
- `lib/services/hermes/hermes_session_key.dart` keeps a second vocabulary for
  the same thing: platform chat id `pistisai`, local shell ids `main-channel`
  and `pistisai-chat`, and the gateway session key
  `agent:main:pistisai:dm:<chat_id>`.

### Runtime session ids are resolved on every read

- A turn is posted to `POST /api/pistisai/messages`
  (`lib/services/hermes/hermes_streaming_service.dart:255`).
- Hermes stores that chat under a generated session id. The app finds it with
  `_resolvePistisaiSessionId()` (`hermes_streaming_service.dart:552`), which
  lists `GET /api/sessions?source=pistisai&chat=pistisai&limit=20` and picks
  the most recently active row, on every transcript read
  (`fetchSessionMessages`, `hermes_streaming_service.dart:482`).
- Before the first turn there is no runtime session. `main` now returns an
  empty list in that case (`hermes_streaming_service.dart:505-510`), but a
  read that still targets the short id falls back to it and gets HTTP 404
  (`hermes_streaming_service.dart:516-523`). The conversation's identity is
  still whatever Hermes reports.

### Streaming is simulated by polling

- After posting, the reply is read by polling the transcript every **750 ms**
  for up to 10 minutes (`hermes_streaming_service.dart:314-315`) and turning
  the difference between snapshots into chunks.
- In the background, `_startSharedChannelSync()` polls the same transcript
  every **8 s** (`lib/services/streaming_chat_service.dart:230-232`), and
  `_syncSharedChannel()` (`streaming_chat_service.dart:254`) merges it into the
  on-screen thread with `mergeHarnessTranscript()`.
- Because the runtime transcript wins, a local delete or wipe needs a floor
  (`TranscriptImportFloorStore`, `streaming_chat_service.dart:241-243, 1050`)
  so old runtime messages are not imported again. `/new` and `/reset` call
  `resetContext()` and stay on the shared conversation
  (`streaming_chat_service.dart:418-421`).
- Other devices read the same runtime transcript through `RouterServer`, which
  proxies `/api/pistisai/messages` and `/api/sessions...` to Hermes
  (`lib/services/router_server.dart:144-147`).

### Tool events are advertised but never sent

- `HermesStreamingService.agentEventStream` exists
  (`hermes_streaming_service.dart:53, 100`) and the chat UI subscribes to it
  (`streaming_chat_service.dart:644`), but nothing calls
  `_agentEventController.add(...)` on the live path.
- `HermesRuntimeClient` still reports `chatStreaming: true` and
  `agentEvents: true` (`lib/services/agent_runtime/hermes_runtime_client.dart:16, 62, 94`).

### Two local conversation stores

1. **Encrypted JSON file** `conversations.json.enc`
   (`lib/services/local_conversation_storage.dart:13`), used by
   `ConversationStorageService` on native platforms only
   (`lib/services/conversation_storage_service.dart:90, 111, 207`). It holds
   whole `Conversation` objects and is rewritten as a unit.
2. **Drift/SQLite local brain** (`lib/database/drift_local_brain.dart`):
   `Conversations` (L29), `Messages` (L42) and the append-only
   `MainChatTimelineRecords` (L53), schema version 11 (L573). The
   `Conversations`/`Messages` DAO (L1023-1038) has no caller outside the
   file today.

## 2. Target design

```
 devices ──► hub channel store (local, source of truth) ◄── harness adapter ──► Hermes / other harness
                    │                                            │
                    └── channel id ── RuntimeSessionMap ── runtime session id
```

- **Channel = identity, owned by the hub** (#1067). A `ConversationChannel`
  has a stable id, a kind (`direct` or `topic`), a title and a creation time
  (`lib/services/agent_session/channel.dart`). It is created locally and never
  derived from a runtime session id. It is distinct from `GatewayChannel`
  (`lib/models/channel.dart`), which lists messaging platforms connected to
  the Hermes gateway.
- **Harness = whoever answers now** (#1066). A `HarnessAdapter`
  (`lib/services/agent_session/harness_adapter.dart`) sends a turn, emits
  typed `HarnessEvent`s, fetches history and resets its own runtime session,
  always addressed by channel id. Hermes is the first adapter; others follow
  the same contract.
- **Local store = source of truth** (#1065). Turns and completed messages are
  written to the hub's store first. The harness transcript is something to
  reconcile against, not something that replaces the thread. `/new` and
  `/reset` become channel operations (new channel, or `resetChannel` on the
  adapter) instead of transcript reloads.
- **Runtime session ids = adapter mapping** (#1065, #1067). A
  `RuntimeSessionMap` (`lib/services/agent_session/runtime_session_map.dart`)
  maps channel id → harness id → runtime session id. Switching the harness for
  a channel adds a mapping; it never moves or splits history. No mapping yet
  means "no runtime session yet", so nothing is requested and no 404 is
  possible.
- **Real-time channel** (#1068). The adapter receives deltas, completed
  messages and tool events over a persistent stream, and the hub pushes
  channel updates to connected devices. `HarnessCapabilities` flags default to
  `false`; an adapter turns one on only when its code does that work, and the
  runtime manifest follows the same rule (AGENTS.md, "Controls tell the
  truth").
- Local-first stays as it is: Pistisai runs on the client's computer if it has
  enough hardware, otherwise on a local machine we provide. Any cloud sync of
  channels stays opt-in, as today.

## 3. Migration, in order

Each step is its own pull request and leaves the app working.

1. **#1065 – own conversations locally.** `StreamingChatService` stores turns
   and replies in the local store first; the 8 s sync reconciles instead of
   replacing; the runtime session id is kept as a mapping, not as the
   conversation id; no transcript read before a runtime session exists.
   Touches `streaming_chat_service.dart`, `hermes_streaming_service.dart` and
   conversation storage (in progress in a separate pull request).
2. **#1067 – channel identity.** Introduce `ConversationChannel` records in the
   chosen store (see Q1), migrate the single `pistisai` conversation into one
   `direct` channel, route `/new` and `/reset` through channel operations, and
   move `hermes_session_key.dart` vocabulary behind the Hermes adapter. Secondary
   devices read channels from the hub instead of the proxied runtime transcript.
3. **#1066 – harness adapter.** Implement `HarnessAdapter` for Hermes on top of
   the existing HTTP calls (honest capabilities: `streaming: false`,
   `agentEvents: false`, `proactive: false`), persist `RuntimeSessionMap`, and
   make the chat layer talk to the adapter only. This is the step that first
   uses the types added with this note.
4. **#1068 – real-time transport.** Replace the 750 ms and 8 s polls with the
   transport chosen in Q3, emit real `HarnessDelta`/tool events, feed
   `agentEventStream` (or its replacement), and only then set the matching
   capability flags to `true`. Reconnects catch up by reconciling against the
   local channel store.

## 4. Open questions for the owner

### Q1. Which store becomes canonical?

Recommendation: **Drift (`LocalBrain`)**, with `conversations.json.enc` read
once for import and then retired.

- Drift already has `Conversations`, `Messages` and `MainChatTimelineRecords`
  and a migration path (`schemaVersion`), so channels and messages can be
  added as tables with real migrations.
- Appending one message is a row insert; the JSON file is decrypted and
  rewritten whole on every save.
- `LocalBrain` is registered on all platforms, web included
  (`lib/di/locator.dart:194-196`); `LocalConversationStorage` is skipped on
  web (`conversation_storage_service.dart:90`).
- Native builds can encrypt `local_brain.sqlite` when the linked SQLite build
  supports it (`lib/database/local_brain_encryption.dart`); the key store is
  shared with the JSON store (`lib/database/local_brain_key_store.dart`).
- Cost: one import step, and the existing Drift `Conversations` table needs a
  `kind` column (or a new `Channels` table) plus a migration; the `userId`
  foreign key needs a decision for a local-only hub.

### Q2. One-time import of the existing Hermes transcript?

When the `direct` channel is first created, should the app import the
current Hermes `pistisai` transcript into it once (respecting the existing
`TranscriptImportFloorStore` floor, so wiped history is not brought back),
or start the channel empty and leave older history in Hermes? Importing keeps
continuity for existing users; starting empty is simpler and keeps a wipe
final. Recommendation: import once, honouring the floor, then never import
again for that channel.

### Q3. What streaming transport does Hermes offer?

Checked against the public Hermes agent source,
[NousResearch/hermes-agent at `77236c4`](https://github.com/NousResearch/hermes-agent/tree/77236c4ad3b31764732b3d91f7fc5aefbabf5093)
(2026-11-27), mainly
[`gateway/platforms/api_server.py`](https://github.com/NousResearch/hermes-agent/blob/77236c4ad3b31764732b3d91f7fc5aefbabf5093/gateway/platforms/api_server.py)
and
[`website/docs/user-guide/features/api-server.md`](https://github.com/NousResearch/hermes-agent/blob/77236c4ad3b31764732b3d91f7fc5aefbabf5093/website/docs/user-guide/features/api-server.md).
The documentation site itself could not be reached from the environment
where this note was written.

Found in that source:

- **`POST /v1/chat/completions` with `"stream": true`** returns Server-Sent
  Events: standard `chat.completion.chunk` frames plus a named
  `hermes.tool.progress` event for tool starts (docs L214-219; route table in
  `api_server.py` L1587). The tool event can be switched off with
  `gateway.platforms.api_server.tool_progress_events: false`.
- **`POST /v1/responses`** streams OpenAI Responses events over SSE.
- **`POST /api/sessions/{id}/chat/stream`** is an SSE wrapper over one turn
  that emits `assistant.delta`, `assistant.commentary`, `tool.started`,
  `tool.completed`, `tool.failed` and a terminal `run.completed` /
  `run.failed` / `run.cancelled` (docs L729; route L1585). This maps almost
  one-to-one onto `HarnessEvent`.
- **`GET /v1/runs/{run_id}/events`** streams the events of one run over SSE
  (`api_server_runs.py` L288).
- Every SSE stream sends a `: keepalive` comment after 10 s without an event
  (docs L216; `CHAT_COMPLETIONS_SSE_KEEPALIVE_SECONDS = 10.0`,
  `api_server.py` L189).
- The API server refuses to start without a strong `API_SERVER_KEY`
  (`api_server.py`, startup guard near L3880).
- **WebSocket:** the docs mention a separate "gateway WebSocket" (a
  `prompt.submit` on a shared session, docs L511) behind the dashboard/webapp
  authentication described in
  `website/docs/developer-guide/gateway-local-sessions.md`. Its message
  protocol was not reviewed for this note: **unverified**.

Constraints and gaps:

- The API server's session routes only bind sessions the API server owns. A
  session owned by another surface (CLI, desktop, messaging platform) is
  refused with HTTP 409 `permission_denied` (docs L500-512). The current
  `pistisai` chat is posted through a `pistisai` platform route
  (`/api/pistisai/messages`) that is **not** in the upstream `hermes-agent`
  source, so whether `chat/stream` can drive that chat is **unverified** and
  probably not, without changing how the channel is created on the Hermes
  side.
- No endpoint was found that pushes messages a session receives without a
  request from this client (scheduled jobs, other devices). Every SSE stream
  above is scoped to one request or one run. A session-wide subscription is
  **unverified**; it may exist on the gateway WebSocket.

Decision needed: (a) move the desktop channel to an API-server-owned Hermes
session and use `/api/sessions/{id}/chat/stream` per turn, keeping a slower
reconcile for proactive messages until a push source exists; (b) adopt the
gateway WebSocket after its protocol and authentication are reviewed; or (c)
keep the `pistisai` platform route and add streaming there. Option (a) is the
smallest step that gives real deltas and tool events today.

### Q4. Where does the channel store live for secondary devices?

The target says devices read channels from the hub. Today they reach Hermes
through `RouterServer` on port `1337`. Serving channels from the hub means new
private router endpoints; per AGENTS.md they answer loopback callers only
unless an `authSecret` is set. Confirm this is the intended path before #1067
adds them.
