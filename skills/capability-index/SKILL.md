---
name: capability-index
description: "Use when unsure where a procedure or capability lives."
version: 1.0.0
author: pistisAI
---

# Capability Index

Lookup table: which skill holds the procedure for each domain. Check here before saying I can't do something. Pair with `operating-rules`, which holds the working rules this index points to.

Before domain work, `skill_view` the skill; the procedure is there, not in my memory.

- **Hermes itself (config, setup, themes, extensions, troubleshooting, orchestration)** → skill `hermes-agent`. Load it before touching config.yaml, SOUL/MEMORY files, gateway, or any Hermes setting. It has its own routing table to reference files.
- **Continuing, "where were we", unfinished work across sessions** → skill `session-continuity`.
- **Past work** → skill `session-continuity`. Search past sessions before asserting what happened earlier.
- **Creating or patching many skills** → skill `skill-micro-batching-protocol`. One operation per call.
- **Quebec business or market research from public sources** → skill `quebec-business-research`.
- **Big or parallel work** → `delegate_task`. Use the configured kanban board when work spans several tasks.
