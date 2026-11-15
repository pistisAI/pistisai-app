---
name: skill-micro-batching-protocol
description: >-
  One operation per call: prevent rate-limit loops.
version: 1.0.0
author: Zoid Maltek
platforms: [linux, macos, windows]
license: MIT
metadata:
  hermes:
    tags: [curator, skill-management, rate-limits, batching, operations]
---

# Skill Micro-Batching Protocol

## When to Use

Use when calling skill_manage or creating/patching multiple skills. Prevents rate-limit loops like the 2026-11-08 curator incident.

## The Rule

**One operation per call. Always.**

```python
# BAD: 8 operations in one call
skill_manage(operations=[
  {"action": "create", "name": "skill1", ...},
  {"action": "patch", "name": "skill2", ...},
  {"action": "patch", "name": "skill3", ...},
  # ... 5 more operations
])

# GOOD: 8 separate calls
skill_manage(operations=[{"action": "create", "name": "skill1", ...}])
skill_manage(operations=[{"action": "patch", "name": "skill2", ...}])
skill_manage(operations=[{"action": "patch", "name": "skill3", ...}])
# ... 5 more single-operation calls
```

## Why This Matters

### The 2026-11-08 Incident

Curator tried to consolidate 5 specialized skills with 8 skill_manage operations batched into one call:
1. Each patch was multi-KB (large)
2. The batched call exceeded rate limits or API constraints
3. Curator detected the state was unsettled (partial write)
4. Curator retried the SAME 8-operation batch immediately
5. No backoff, no splitting → loop until watchdog stopped it after 8 retries

**Result:** ~14-16 tool calls wasted, 15-30K tokens leaked (caught by prompt caching + compression).

### Why Single Operations Work

- **Atomic:** Either succeeds or fails cleanly. No partial state.
- **Retryable:** If one operation fails, only that one is retried.
- **Rate-limit safe:** Small payloads stay under API size/complexity limits.
- **Debuggable:** You know exactly which operation failed.

## How to Apply This

### Creating Multiple Skills

```python
# Create one skill per call
for skill_content in skill_list:
    skill_manage(operations=[{
        "action": "create",
        "name": skill_content["name"],
        "content": skill_content["body"]
    }])
    # Optional: pause between calls if rate-limiting is aggressive
```

### Patching One Skill Multiple Times

```python
# Patch once per call, not 5 patches in one batch
skill_manage(operations=[{
    "action": "patch",
    "name": "my-skill",
    "old_string": "section 1",
    "new_string": "new section 1"
}])
# ... wait for result ...

skill_manage(operations=[{
    "action": "patch",
    "name": "my-skill",
    "old_string": "section 2",
    "new_string": "new section 2"
}])
```

### Multi-File Operations (Exception)

If you are writing supporting files (scripts, templates, references) for a single skill create, you MAY batch them:

```python
# OK: Tightly coupled — all part of one skill setup
skill_manage(operations=[
    {
        "action": "create",
        "name": "my-skill",
        "content": "..."
    },
    {
        "action": "write_file",
        "name": "my-skill",
        "file_path": "references/api.md",
        "file_content": "..."
    },
    {
        "action": "write_file",
        "name": "my-skill",
        "file_path": "scripts/setup.sh",
        "file_content": "..."
    }
])
```

**NOT OK:** Separate, unrelated patches to different skills in one batch.

## Detecting the Problem Early

If you see:
- skill_manage with 5+ operations in one call → split them
- Curator running skill_view + skill_manage in tight loop → curator hit a batch limit
- Same tool call retried immediately with no backoff → rate limit, not architectural issue

## Curator's Default Behavior

Curator runs once per week (interval_hours: 168) and:
1. Loads all 40+ skills
2. Detects overlaps or consolidation opportunities
3. Generates patches and consolidation plans
4. Calls skill_manage with batched operations

**Your responsibility:** Don't create skills that curator wants to consolidate (i.e., don't make overlapping skills that curator sees as duplicates). If curator tries to consolidate your 5 specialized skills again, it will hit the same rate limit.

## Prevention

1. **Keep skills focused and non-overlapping**
   - `operational-workflow`: core procedures only
   - Don't create `operational-workflow-v2` or `workflow-backup`
   - Curator will try to merge them

2. **Use skill consolidation deliberately**
   - If you intentionally want skills merged, do it manually with micro-batching
   - Don't let curator auto-consolidate large skills

3. **Monitor curator logs**
   ```bash
   tail -50 ~/.hermes/logs/curator/*/run.json | grep -E 'tool_calls|llm_final'
   ```
   If you see >8 skill_manage calls in one run, curator is struggling.

## Reference

- Hermes skill_manage API: skill_manage(operations=[{...}])
- Curator config: `hermes config get curator`
- Curator logs: `~/.hermes/logs/curator/`
