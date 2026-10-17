"""aigent-watch — deterministic drift critic on durable writes.

Warn-mode only. Scans write_file / patch / skill_manage / memory content for
assertions written to the durable record (findings board, memory, skills)
that carry no resolvable source, and appends an ⚠️ Aigent critic block to the
tool result. The write still lands; the nudge rides back to the agent in the
next turn so it self-corrects — the same shape as security-guidance.

Why warn, never block: the first scanner iteration flagged 56 noise items on
a clean file. Precision must be earned through telemetry (drift-log.md)
before any block mode is considered.

Checks:
  C1  findings-record prose assertion with no source marker
  C2  memory write about a person/relationship with no source annotation
  C3  cited path:line that does not resolve (decorative citation)
Telemetry: every trigger appends one line to the drift log.

Paths are not baked in. Resolution order for relative paths and the drift log:
  AIGENT_RECORD_ROOT  (explicit root for citations)
  HERMES_HOME         (the install the plugin ships into)
  D:/ZOID             (legacy default; used only when it exists)
  ~                   (last resort)
Drift log: AIGENT_DRIFT_LOG, else the legacy path when its directory exists,
else <HERMES_HOME>/logs/drift-log.md.
Person names for C2: AIGENT_WATCH_PERSONS (comma separated) overrides the
built-in list.
"""

from __future__ import annotations

import os
import re
import time

_TRUTHY = {"1", "true", "yes", "on"}

# Tools whose content lands in the durable record and gets trusted next session.
_TARGET_TOOLS = {"write_file", "patch", "skill_manage", "memory"}

_FINDINGS_HINT = ("file-dig-findings", "docs/personal", "docs\\personal")

# A sourced line carries at least one of these. Absence of all = assertion.
_SOURCE_MARKER = re.compile(
    r"(?:19|20)\d\d|\bJan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|\d{1,2}/\d{1,2}|D:/|D:\\|~/|"
    r"VERIFIED|RETRACTED|CONFLICT|UNVERIFIED|CORRECTED|SUPERSEDED|"
    r"HARD RULE|his-words|posts-extracted|\.txt:|\.json:|\.md:|"
    r"per the corpus|from the corpus|his own words|his words|"
    r"tool output|session id|source:", re.I)

_DEFAULT_PERSON_NAMES = (
    "Marilyn|Sandra|Emma|Côté|Cote|Majo|Majogodi|Frederik|Frédérik|"
    "Coralie|Tremblay|Elizabethgaulin|Érik|Erik|Michèle|Michele"
)

# Decorative-citation pattern: path:line or path (line N)
_CITATION = re.compile(r"([\w./\\-]+\.(?:txt|json|md|py|html|jsonl))[: ](\d{1,6})")

_STRUCTURAL = ("#", "|", "-", ">", "---", "§", "*")


def _env(name: str, default: str = "") -> str:
    return (os.environ.get(name) or "").strip() or default


def _roots() -> list:
    """Candidate record roots, most specific first, de-duplicated."""
    roots = []
    for candidate in (_env("AIGENT_RECORD_ROOT"), _env("HERMES_HOME"), "D:/ZOID"):
        if candidate and os.path.isdir(candidate) and candidate not in roots:
            roots.append(candidate)
    home = os.path.expanduser("~")
    if home and home not in roots:
        roots.append(home)
    return roots or ["."]


def _resolve(path: str) -> str:
    """Absolute path for a citation, tried against each known record root."""
    if os.path.isabs(path):
        return path
    for root in _roots():
        candidate = os.path.join(root, path)
        if os.path.exists(candidate):
            return candidate
    return os.path.join(_roots()[0], path)


def _default_drift_log() -> str:
    explicit = _env("AIGENT_DRIFT_LOG")
    if explicit:
        return explicit
    legacy = "D:/ZOID/docs/personal/drift-log.md"
    if os.path.isdir(os.path.dirname(legacy)):
        return legacy
    home = _env("HERMES_HOME", os.path.join(os.path.expanduser("~"), ".hermes"))
    return os.path.join(home, "logs", "drift-log.md")


_DRIFT_LOG_PATH = None


def _drift_log_path() -> str:
    """Resolved lazily so AIGENT_DRIFT_LOG is honoured on first write."""
    global _DRIFT_LOG_PATH
    if _DRIFT_LOG_PATH is None:
        _DRIFT_LOG_PATH = _default_drift_log()
    return _DRIFT_LOG_PATH

_PERSON_NAMES_RE = re.compile(
    r"\b(" + _DEFAULT_PERSON_NAMES + r")\b", re.I
)
_PERSON_NAMES_OVERRIDE = None


def _person_names() -> re.Pattern:
    """C2 name pattern, resolved lazily so an env override applies on first use."""
    global _PERSON_NAMES_OVERRIDE
    if _PERSON_NAMES_OVERRIDE is None:
        override = _env("AIGENT_WATCH_PERSONS")
        _PERSON_NAMES_OVERRIDE = re.compile(
            r"\b(" + (override or _DEFAULT_PERSON_NAMES) + r")\b", re.I
        )
    return _PERSON_NAMES_OVERRIDE


def _env_flag(name: str) -> bool:
    return os.environ.get(name, "").lower() in _TRUTHY


def _is_prose(s: str) -> bool:
    """Structural lines (tables, bullets, headings, backticked) are exempt.
    Action/plan lines (numbered items, imperatives, to-do phrasing) are
    exempt too — they state intent, not facts about the world."""
    if len(s) < 60 or s.startswith(_STRUCTURAL) or s.count("`") >= 2:
        return False
    if not (" " in s and len(s.split()) >= 8):
        return False
    if re.match(r"^\d+[\.\)]\s", s):          # numbered list item
        return False
    if re.match(r"^(Pick|Choose|Build|Draft|Update|Download|Resolve|Merge|Fix|Add|Create|Set up|Wire|Write)\b", s, re.I):
        return False
    if "→" in s or "-->" in s:                  # mappings, not assertions
        return False
    if s.endswith(":") or s.endswith("—") or s.endswith("--"):
        return False                             # list/section intro lines
    return True


def _log_trigger(check: str, tool: str, detail: str) -> None:
    try:
        os.makedirs(os.path.dirname(_drift_log_path()), exist_ok=True)
        ts = time.strftime("%Y-%m-%d %H:%M")
        with open(_drift_log_path(), "a", encoding="utf-8") as f:
            f.write(f"- {ts} | {check} | {tool} | {detail[:160]}\n")
    except OSError:
        pass


def _citation_resolves(citation_text: str) -> bool:
    """A cited path:line must exist and share tokens with the claim."""
    for m in _CITATION.finditer(citation_text):
        path, lineno = m.group(1), int(m.group(2))
        try:
            with open(_resolve(path), encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
            if lineno > len(lines):
                return False
        except OSError:
            return False
    return True


def _scan(tool_name: str, args) -> list:
    """Return [(check_id, nudge), ...] for one gated write."""
    if _env_flag("AIGENT_WATCH_DISABLE") or not isinstance(args, dict):
        return []
    path = ""
    content = ""
    if tool_name == "write_file":
        path = args.get("path", "") or ""
        content = args.get("content", "") or ""
    elif tool_name == "patch":
        path = args.get("path", "") or ""
        content = args.get("new_string", "") or ""
    elif tool_name == "skill_manage":
        path = args.get("file_path", "") or ""
        content = args.get("file_content", "") or args.get("new_string", "") or ""
    elif tool_name == "memory":
        content = args.get("content", "") or args.get("new_text", "") or ""
        path = "memory"
    if not isinstance(content, str) or not content:
        return []

    findings = []
    for line in content.splitlines():
        s = line.strip()
        if not s:
            continue
        # C2 — memory assertion about a person with no source annotation.
        # Person-name claims get no length floor: "Sandra is his fiancee" is
        # the exact fabrication shape — short, confident, wrong.
        if tool_name == "memory" and _person_names().search(s) and not _SOURCE_MARKER.search(s):
            findings.append(("C2", s))
            continue
        # C1 — findings-record assertion with no source marker (prose only)
        if not _is_prose(s):
            continue
        if any(h in path for h in _FINDINGS_HINT) and not _SOURCE_MARKER.search(s):
            findings.append(("C1", s))
            continue
        # C3 — decorative citation that does not resolve
        if _CITATION.search(s) and not _citation_resolves(s):
            findings.append(("C3", s))

    out = []
    for check, s in findings[:5]:
        out.append((check, s))
        _log_trigger(check, tool_name, f"{path} :: {s}")
    return out


def _format_block(findings: list) -> str:
    lines = ["", "---", f"⚠️ Aigent critic — {len(findings)} unsourced assertion(s) flagged", ""]
    nudges = {
        "C1": "Findings line asserts a fact with no source marker. Name the source "
              "(file:line, tool output, his words this session) or mark it UNVERIFIED — "
              "or cut the line. A gap stays blank.",
        "C2": "Memory write about a person with no source annotation. His direct word "
              "or a file+line is the only source. If the record is silent, the entry "
              "does not get written.",
        "C3": "A cited path:line does not resolve. A citation that cannot be checked "
              "is a decorative citation — verify it or remove it.",
    }
    for check, s in findings:
        lines.append(f"[{check}] {s[:140]}")
        lines.append(nudges[check])
        lines.append("")
    lines.append("Warn-mode: the write landed. Self-correct next turn — fix the "
                 "annotation or retract the claim, then move on.")
    return "\n".join(lines)


def _on_transform_tool_result(tool_name: str = "", args=None, result=None, **_) -> str | None:
    findings = _scan(tool_name, args)
    if not findings or not isinstance(result, str):
        return None
    return result + "\n\n" + _format_block(findings)


def register(ctx) -> None:
    ctx.register_hook("transform_tool_result", _on_transform_tool_result)
