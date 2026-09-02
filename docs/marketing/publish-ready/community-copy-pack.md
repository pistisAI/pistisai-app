# Community Copy Pack — Pistisai Public Launch

Reusable snippets for replies, issue templates, discussions, and community FAQs. Keep this
consistent with [LAUNCH_CONTENT_BRIEF.md](../LAUNCH_CONTENT_BRIEF.md).

## Elevator pitch (short)

Pistisai is a local-first companion and desktop layer for your AI agent — voice, vision, and
audited desktop control over your own private mesh. Your agent, your hardware, your rules.

## FAQ-ready answers

**Is Pistisai a model?**
No. It's the layer in front of an agent runtime (Hermes, OpenClaw, or any compatible gateway).
The runtime does the reasoning; Pistisai adds voice, vision, desktop control, and a secure
channel.

**Which runtimes are supported?**
Hermes (primary test path) and OpenClaw are first-class. Any agent exposing the runtime
contract works. Ollama / LM Studio are support providers for app-owned features
(memory, embeddings, OCR, speech) — not the main runtime.

**Where does my data go?**
Nowhere off your network unless you choose. Connectivity is Tailscale-first. The optional
cloud connector is one isolated container per user, joined to your tailnet.

**Is desktop control safe?**
It's explicit, device-scoped, permissioned per action, and fully auditable. No action runs
without consent.

**How do I self-host?**
Web app needs no install. Desktop from source: `flutter pub get` then `flutter run -d linux`
(or `chrome`). Backend services live under `services/` with their own `npm install && npm run dev`.
Full steps in [docs/LAUNCH.md](../../LAUNCH.md).

## Issue / discussion reply templates

**Welcome reply (newcomer):**
> Welcome! The fastest path is https://pistisai.app — log in and run the setup wizard. Point
> it at your agent runtime and you're set. If you hit anything, open an issue with your runtime
> + OS and we'll dig in.

**Failure-report acknowledgement:**
> Thanks for the report — this is exactly the signal we need at launch. Can you confirm your
> agent runtime, OS, and the step where it failed? Logs from the wizard help a lot.

**Contributor onboarding:**
> Glad you're interested. Start with the [dev guide](../../development/BUILD_SCRIPTS.md) and
> [Agent Runtime Contract](../../architecture/AGENT_RUNTIME_CONTRACT.md). Pick a labelled
> `good first issue` and open a PR to `main` — we push directly, no ceremony.

## Call to action (standard)

Clone the repo, run a workflow, and open an issue or discussion with your real use case.
Web: https://pistisai.app · GitHub: https://github.com/pistisAI/pistisai-app
