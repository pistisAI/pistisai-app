# Launch Content Brief — Pistisai Public Launch

> Canonical launch issue: [#39 — Paperclip AI — public launch](https://github.com/pistisAI/pistisai-app/issues/39)
> Companion guide: [docs/LAUNCH.md](docs/LAUNCH.md)

This brief governs all outward-facing launch copy. Keep every channel consistent with the
positioning, supported runtimes, and tone defined here.

## Product at a glance

- **What it is:** A local-first companion and desktop capability layer for your AI agent.
  Private, secure, yours.
- **What it is NOT:** A model, and not a hosted chatbot. It is the layer in front of an agent
  runtime (Hermes, OpenClaw, or any compatible agent gateway).
- **Core promise:** Voice, vision, and audited desktop control over your own private
  (Tailscale-first) mesh. No data leaves your network unless you decide otherwise.

## One-liner (canonical)

> **Pistisai turns your AI agent into a private desktop companion: voice, vision, and audited
> desktop control, connected over your own Tailscale mesh — local-first, no data leaves your
> network unless you say so.**

Use this verbatim across all channels. Variations for space-constrained surfaces (e.g. social
bio) live in `publish-ready/social-thread-pack.md`.

## Primary CTA

Clone the repo, run a workflow, and open an issue or discussion with your real use case.

- Web: https://pistisai.app
- GitHub: https://github.com/pistisAI/pistisai-app

## Voice and tone

- Plain, confident, technical but not jargon-heavy.
- Lead with the user's control and privacy, not features for their own sake.
- No hype superlatives ("revolutionary", "world's first"). Show, don't claim.
- Acknowledge what's in development (Windows installer, macOS) honestly.

## Channels and owners

| Channel | Asset | Owner |
|---------|-------|-------|
| GitHub issue thread | issue #39 (this post) | Founder |
| Twitter/X thread | `publish-ready/social-thread-pack.md` | CMO |
| LinkedIn operator post | `publish-ready/social-thread-pack.md` | CMO |
| Discord announcement | `publish-ready/social-thread-pack.md` | DevRel |
| Community copy set | `publish-ready/community-copy-pack.md` | DevRel |
| Measurement plan | `publish-ready/measurement-plan.md` | DevRel |

## Messaging pillars (rotate across the week-1 plan)

1. **Install/try path** — it runs in a browser, zero install.
2. **Standards / CI gates** — branch protection, CodeQL, Dependabot, secret scanning.
3. **Offline / failover** — local-first means it keeps working without the cloud.
4. **Contributor onboarding** — how to wire your own agent runtime.
5. **Week summary + next preview** — recap and a teaser.

## Guardrails

- Every post links to either pistisai.app or the GitHub repo.
- Never claim a platform status that contradicts `docs/LAUNCH.md` or the README.
- Report security issues to `security@pistisai.app`, never in public threads.
- Keep copy in the repo so it is reviewable and version-controlled.
