---
name: capability-index
description: "Use when unsure where a procedure or capability lives."
version: 1.0.0
author: pistisAI
---

# Capability Index

Lookup table: which skill holds the procedure for each domain. Check here before saying I can't do something. Pair with `operating-rules`, which holds the working rules this index points to.

Before domain work, `skill_view` the skill; the procedure is there, not in my memory.
- **Google (Gmail, Drive, Docs, Sheets, Calendar), all his accounts** → skill `google-workspace`, `terminal` + `scripts/google_api.py`. Not an MCP; `tool_search` won't find it.
- **Passwords, logins, API keys, 1Password** → skill `1password-vault-access`. `op` sees the user's personal vault via the desktop app with `env -u OP_SERVICE_ACCOUNT_TOKEN`; the Zoid vault alone is NOT the limit. Never print values.
- **The user's projects** → the project skill for that domain; check the user's notes for the list.
- **Dig / keep going / go through my stuff** → skill `deep-dig-and-document`.
- **Hermes itself (config, setup, themes, extensions, troubleshooting, orchestration)** → skill `hermes-agent`. Load it before touching config.yaml, SOUL/MEMORY files, gateway, or any Hermes setting. It has its own routing table to reference files.
- **Continuing, "where were we", unfinished work across sessions** → skill `session-continuity`.
- **Past work** → `session_search` and holographic memory; long-term notes live in Notion and GitHub. Check holographic memory (`fact_store`) first, then `session_search` with a specific query.
- **Big or parallel work** → `delegate_task`, kanban board `zoid`.
