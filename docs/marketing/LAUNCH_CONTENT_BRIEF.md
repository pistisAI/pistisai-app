# Launch Content Brief — Pistisai Public Launch

> Canonical launch issue: [#39 — Pistisai — public launch](https://github.com/pistisAI/pistisai-app/issues/39)
> Companion guide: docs/LAUNCH.md

This brief governs all outward-facing launch copy. Keep every channel consistent with the
positioning, supported runtimes, and tone defined here.

## Product at a glance

Follow [docs/PRODUCT.md](../PRODUCT.md). Do not publish a different product story.

- **What it is:** PistisAI, a desktop hub for a Hermes-based agent, plus skills. It runs on the client's own computer. No special hardware.
- **Who delivers it in Quebec:** IAClé, Christopher Maltais's company. Same stack, not a second product.
- **What it is not:** A model, a hosted agent, or a separate IAClé application.
- **Cloud:** Services the client already uses, and online models for heavy work, only when that is secure, the client agrees, and it fits Quebec Law 25.
- **Sign-in:** Tunnel and sync only. Free tier: Cloudflare Access on `api.pistisai.app`. Business and Enterprise: the customer's Tailscale network or VPN.

## One-liner (canonical)

> **PistisAI is a desktop hub and skills for a Hermes-based agent. It runs on the client's own computer. IAClé delivers that same stack to Quebec businesses.**

Use this verbatim across channels. Short variants live in `publish-ready/social-thread-pack.md`.

## Primary CTA

Clone the repo, run a workflow, and open an issue or discussion with your real use case.

- Web: https://app.pistisai.app
- API and tunnel: https://api.pistisai.app
- GitHub: https://github.com/pistisAI/pistisai-app

## Voice and tone

- Plain, confident, technical but not jargon-heavy.
- Lead with the user's control and privacy, not features for their own sake.
- No hype superlatives ("revolutionary", "world's first"). Show, don't claim.
- Windows, macOS, Linux, and Android builds come from CI. The web app is https://app.pistisai.app.
- Do not link `pistisai.app`, `docs.pistisai.app`, or `adminmatrix.pistisai.app`. Those hosts are not current.

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
