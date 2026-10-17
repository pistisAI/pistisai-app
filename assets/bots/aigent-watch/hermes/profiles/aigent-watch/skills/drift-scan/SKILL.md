---
name: drift-scan
description: "Scan durable writes for unsourced or misattributed assertions (C1-C4)."
---

# drift-scan

Use when: the Bot's routine fires, or when checking the durable record for drift.

## What it does

Scans the durable record (vault, docs/personal, docs) for:

- **C1** — findings-record prose assertion with no source marker
- **C2** — memory write about a person/relationship with no source annotation
- **C3** — cited path:line that does not resolve (decorative citation)
- **C4** — a file written by **past-Zoid** cited as Christopher's own authority

## How to run

```bash
python ~/.hermes/profiles/aigent-watch/drift_scanner.py
```

## Output

JSON array of findings: `[{"check": "C1|C2|C3|C4", "path": "...", "line": "..."}]`

Every trigger also logs to `D:/ZOID/docs/personal/drift-log.md`.

## C2 — context filtering

Person names are *expected* in identity/bio docs, so raw C2 checking there produces mostly noise.
In high-person-density files the check requires meaningful context (relationship verbs, legal
terminology, dates, roles) before flagging. Elsewhere C2 stays strict.

## C4 — the misattribution check

Signature: a self-authored filename **plus a line-number citation** (`DAD.md L25`,
`zoid-read-on-christopher.md:8`). That is the shape of handing my own writing to
Christopher as his rule.

In-scope filenames: `vault/Identity/*`, `DAD.md`, `MOM.md`, `WHO-I-AM.md`, `ELENCHOS.md`,
`SIMON.md`, `ERIK-GRAVEL.md`, `The Long Birth`, `C2L Framework`, `zoid-read-on-christopher.md`,
`habits-dossier*`.

**Pitfalls**

- A ±N-line window test over-flags: a document that *explains* the provenance rule names
  those files legitimately. Keep C4 narrow. Precision first.
- Never let the scanner read its own `drift-log.md` — it quotes findings, re-flags every run,
  and grows without bound (86 phantom hits observed).
- `scan_file` uses `_person_names()` (a function), not `_PERSON_NAMES`. A fuzzy patch
  once replaced the call with a bare name and broke the scanner with a `NameError` —
  always re-run the scanner after editing it.

## Scheduling — cron, not an invented heartbeat

The scan is self-contained, so `hermes cron` is the right primitive (job `11c4741339fb`, every 6h).
Hermes's real session heartbeat (`/heartbeat`) is a different feature: it fires inside the session
that armed it, with that conversation's context. Do not describe this job as a "heartbeat" and do
not write heartbeat prose as if it were a mechanism.

## After scanning

If findings exist and any are C3 or C4, message the main agent:
- cite the file and line
- state the check and what's wrong
- for C4, name who actually wrote the cited file

If only C1/C2 findings exist: stay quiet (they are logged).
If no findings exist: remain silent.
