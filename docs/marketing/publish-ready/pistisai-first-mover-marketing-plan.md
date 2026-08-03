# Pistisai.app — First-Mover Marketing Plan

> Drafted by CMO to establish first-mover positioning ahead of public launch.
> Final gate: CEO/UX/Legal approval before channel execution.

---

## 1. Positioning

Pistisai is not another AI wrapper. It is a **local-first companion and desktop capability layer for your AI agent runtime: private, secure, yours.**

Elevator pitch:
> Your AI runs on your hardware. Pistisai gives it a secure channel, voice, vision, desktop control, and a Tailscale-first device mesh.

One-liner for bios/launch:
> Local-first companion for Hermes, OpenClaw, and compatible agent runtimes: secure channel, voice, vision, desktop control, and private device mesh.

Value pillars from product truth:
1. Privacy/local-first — core experience stays on your machine
2. Secure agent channel — direct, permissioned line to your runtime
3. Desktop control — hands and eyes on selected devices, with explicit consent
4. Voice/avatar companion — separate sidecar surface with memory and conversation state
5. Multi-device private mesh — Tailscale-first sync across your authorized machines
6. Runtime-agnostic — Hermes is the first test path; OpenClaw and compatible gateways also work

---

## 2. Audience Definition

Primary:
- Solo developers and power users running local models via Ollama/LM Studio/Hermes/OpenClaw
- Privacy-conscious operators who do not want secrets or chats leaving their environment
- Multi-device users who already use Tailscale or want a private mesh

Secondary:
- Open-source contributors interested in agent-channel plumbing, Flutter desktop, or Node backend services
- Technical founders evaluating local-first architectures for internal tools

Anti-persona:
- Casual users expecting hosted SaaS signup
- Users who need broad consumer integrations over privacy guarantees

---

## 3. Messaging Framework

Headline:
> What if your AI stayed on your machine?

Support lines:
- “Local-first means your data stays local.”
- “Secure agent channel, not just another API client.”
- “Voice, vision, and desktop control in one companion layer.”
- “Your runtime, your network, your rules.”

Objection handlers:
- “Is it cloud-dependent?” -> Core experience is local; cloud connector is opt-in and isolated per tailnet.
- “Do I have to use a specific model?” -> No. Hermes, OpenClaw, and compatible agent runtimes are supported; first-class path is configurable at runtime.
- “Is it open?” -> Public repo with visible standards, CI, and issues.

---

## 4. Channel Plan

Channel | Owner | Pacing | Goal
Twitter/X | CMO or delegated social | 1 thread + replies/week | ownership/developer awareness
LinkedIn | CMO or delegated social | 1 post/week | operator/early-adopter credibility
Reddit | CMO or delegated social | 1 post/week in r/LocalLLaMA, r/selfhosted | product discussion and installs
Discord | CMO + devrel | continuous | onboarding, issue reports, community proof
GitHub | CMO + CTO | continuous | public trust, engagement, issue velocity
Blog/docs | CMO or contracted writer | 1 post/week | organic search, messaging depth

First-mover window:
- Week 1: launch anchor issue/announcement
- Week 2: standards/CI/engineering story
- Week 3: offline/failover + privacy story
- Week 4: contributor onboarding + roadmap preview

---

## 5. Content Pillars

1. Reality anchor — what it is, what it is not
2. Trust builder — security review, SECURITY.md, secrets handling
3. Operator proof — standards, CI, branch protection, real engineering baseline
4. Use-case playbooks — local model routing, avatar/voice setup, Tailscale device mesh
5. Community activation — contribution path, issue templates, roadmap transparency

---

## 6. Publisher Guardrails

- Never claim cloud independence while implying offline parity that is not yet shipped.
- Always link authoritative sources: repo, docs, SECURITY.md, issues.
- No fabricated benchmarks, user counts, or press logos.
- All public copy should pass UX/Legal review before publication.

---

## 7. Success Metrics

- GitHub: new issues/discussions with real use-case reports
- Social: replies/quote posts mentioning the repo or install path
- Community: new contributor issues and PRs within 14 days
- Blog/docs: session time and click-through to install path
- Install path: tracked via web install CTA clicks and GitHub repo visits

---

## 8. Next Actions

1. Finalize publish-ready blog outline and review copy against existing launch assets.
2. Confirm UX/Legal approval on first public channel copy.
3. Select Week 1 anchor channel and schedule publication.
4. Assign delegated social/Discord coverage if volume exceeds capacity.
