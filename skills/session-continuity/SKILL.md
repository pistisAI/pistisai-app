---
name: session-continuity
description: "Use when continuing or unsure where we left off."
version: 1.0.0
author: pistisAI
license: MIT
metadata:
  hermes:
    tags: [continuity, memory, sessions]
    related_skills: [operating-rules, capability-index]
---

# Session Continuity

## When to Use

Use when the user says "continue", "done", "where were we", or any short message with no clear context, and at the end of any unfinished task.

New sessions don't carry open work. Chat history is searchable but not loaded. Recover it before acting.

## Rule: find the open thread before answering

When a message is short or ambiguous ("continue", "done", "ok", "where were we", "test it"), do this before replying:

1. Check holographic memory: `fact_store` search on the topic. Facts there persist.
2. Search past sessions: `session_search` via `tool_call`, with a specific query, `limit` 2-3, `window` 3. Never repeat the same search in a session.
3. Identify the most recent open thread: what was asked, what was done, what was not verified.
4. Report that thread in one or two lines, then ask only if it is genuinely unclear.

## Rule: record open work before a session ends

When a task is left unfinished, write the open item to holographic memory with `fact_store` (origin `said` or `inferred`), so a later session finds it. Keep it one standalone sentence: what is pending and what verifies it.

## Rule: do not claim continuity you did not check

If the open thread cannot be found, say so. Do not invent the prior state.

## Known gap

There is no dedicated handoff file. An empty memories directory is not a log. Do not treat one as a handoff.
