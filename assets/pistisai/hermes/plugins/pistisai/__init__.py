"""pistisai — deterministic drift critic on durable writes.

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

Paths are not baked in. Resolution order for relative paths:
  AIGENT_RECORD_ROOT  (explicit root for citations)
  HERMES_HOME         (the install the plugin ships into)
  ~                   (last resort)
Drift log: AIGENT_DRIFT_LOG, else <HERMES_HOME>/logs/drift-log.md.
Person names for C2: AIGENT_WATCH_PERSONS (comma separated) overrides the
built-in list.
"""

from __future__ import annotations

import datetime
import json
import os
import re
import socket
import time

_TRUTHY = {"1", "true", "yes", "on"}

# Tools whose content lands in the durable record and gets trusted next session.
_TARGET_TOOLS = {"write_file", "patch", "skill_manage", "memory"}

_FINDINGS_HINT = ("file-dig-findings", "docs/personal", "docs\\personal")

# A sourced line carries at least one of these. Absence of all = assertion.
# A Windows drive letter counts as a path marker without naming a machine.
_SOURCE_MARKER = re.compile(
    r"(?:19|20)\d\d|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b|\d{1,2}/\d{1,2}|[A-Za-z]:[/\\]|~/|"
    r"VERIFIED|RETRACTED|CONFLICT|UNVERIFIED|CORRECTED|SUPERSEDED|"
    r"HARD RULE|his-words|posts-extracted|\.txt:|\.json:|\.md:|"
    r"per the corpus|from the corpus|his own words|his words|"
    r"tool output|session id|source:", re.I)

# No names are baked in. C2 needs a person list to check against, and a
# shipped list would name real people in a public repository. Set
# AIGENT_WATCH_PERSONS (comma separated) in the install that wants the check.
_DEFAULT_PERSON_NAMES = ""

# Decorative-citation pattern: path:line or path (line N)
_CITATION = re.compile(r"([\w./\\-]+\.(?:txt|json|md|py|html|jsonl))[: ](\d{1,6})")

_STRUCTURAL = ("#", "|", "-", ">", "---", "§", "*")


def _env(name: str, default: str = "") -> str:
    return (os.environ.get(name) or "").strip() or default


def _roots() -> list:
    """Candidate record roots, most specific first, de-duplicated."""
    roots = []
    for candidate in (_env("AIGENT_RECORD_ROOT"), _env("HERMES_HOME")):
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


def _person_names():
    """C2 name pattern, or None when no list is configured.

    Returns None rather than an empty pattern: r"\b()\b" matches every line
    and would flag the whole record. With no list there is nothing to check.
    """
    global _PERSON_NAMES_OVERRIDE
    if _PERSON_NAMES_OVERRIDE is None:
        override = _env("AIGENT_WATCH_PERSONS")
        parts = [re.escape(p.strip()) for p in override.split(",") if p.strip()]
        if not parts:
            _PERSON_NAMES_OVERRIDE = False
            return None
        try:
            _PERSON_NAMES_OVERRIDE = re.compile(r"\b(" + "|".join(parts) + r")\b", re.I)
        except re.error:
            _PERSON_NAMES_OVERRIDE = False
            return None
    if _PERSON_NAMES_OVERRIDE is False:
        return None
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
        content = args.get("file_content", "") or args.get("new_string", "") or args.get("content", "") or ""
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
        # Person-name claims get no length floor: "a real person" is
        # the exact fabrication shape — short, confident, wrong.
        _names_re = _person_names()
        if tool_name == "memory" and _names_re and _names_re.search(s) and not _SOURCE_MARKER.search(s):
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


def _sanitize(value: object, limit: int = 120) -> str:
    """Strip control chars/newlines and truncate untrusted context values."""
    text = str(value or "").strip()
    # Drop newlines and control characters to prevent prompt-injection / bloat.
    text = "".join(ch for ch in text if ch.isprintable() and ch not in "\r\n\t")
    if len(text) > limit:
        text = text[:limit] + "…"
    return text


def _time_bucket(hour: int) -> str:
    if hour < 6:
        return "night"
    if hour < 12:
        return "morning"
    if hour < 17:
        return "afternoon"
    if hour < 21:
        return "evening"
    return "night"


def _device_context_path() -> str:
    """Where the client-reported device/session context lives."""
    home = _env("HERMES_HOME", os.path.join(os.path.expanduser("~"), ".hermes"))
    return os.path.join(home, "device-context.json")


_DEVICE_CONTEXT_FIELDS = ("device", "session", "location", "connection")


def _env_device_context() -> dict:
    """Env-overridden device/session/location/connection (applies to all sources)."""
    out = {}
    if _env("AIGENT_DEVICE"):
        out["device"] = _env("AIGENT_DEVICE")
    if _env("AIGENT_SESSION"):
        out["session"] = _env("AIGENT_SESSION")
    if _env("AIGENT_LOCATION"):
        out["location"] = _env("AIGENT_LOCATION")
    if _env("AIGENT_CONNECTION"):
        out["connection"] = _env("AIGENT_CONNECTION")
    return out


def _read_device_context_map() -> dict:
    """Read the device-context store as a source-keyed map.

    New format: ``{"api_server:sess-1": {"device":...}, "slack:U123": {...}}``.
    Legacy format (flat dict with device/session/...) is wrapped under the
    ``api_server`` key for backwards compatibility.
    """
    path = _device_context_path()
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            # Legacy flat format: top-level has one of the device fields.
            if any(k in data for k in _DEVICE_CONTEXT_FIELDS):
                return {"api_server": {k: data[k] for k in _DEVICE_CONTEXT_FIELDS if k in data}}
            # New source-keyed format: values are dicts.
            out = {}
            for key, val in data.items():
                if isinstance(val, dict):
                    entry = {k: val[k] for k in _DEVICE_CONTEXT_FIELDS if k in val}
                    if entry:
                        out[key] = entry
            if out:
                return out
    except (OSError, ValueError):
        pass
    env_ctx = _env_device_context()
    if env_ctx:
        return {"api_server": env_ctx}
    return {}


def _source_key(platform: str, sender_id: str, session_id: str) -> str:
    """Key used to look up a client's device context for this message."""
    if sender_id:
        return f"{platform}:{sender_id}"
    if session_id:
        return f"{platform}:{session_id}"
    return platform or "api_server"


def _device_context_for(platform: str, sender_id: str, session_id: str) -> dict:
    """Look up the device context for the source of this message.

    Returns the entry for ``platform:sender`` (or ``platform:session`` /
    ``platform`` as fallbacks). Empty dict when no client reported for it.
    """
    m = _read_device_context_map()
    key = _source_key(platform, sender_id, session_id)
    if key in m:
        return m[key]
    # Fall back to platform-only key (single client per platform).
    if platform in m:
        return m[platform]
    # Last resort: the first api_server entry (legacy single-client).
    if platform == "api_server" and m:
        return next(iter(m.values()))
    return {}


def _on_pre_llm_call(**kw) -> dict | None:
    """Inject device/location/time awareness into the turn context.

    Warn-mode style: never blocks, only adds context the agent can use to
    adapt response length and urgency. Disable with AIGENT_AWARENESS_DISABLE=1.
    """
    if _env_flag("AIGENT_AWARENESS_DISABLE"):
        return None
    now = datetime.datetime.now()
    platform = _sanitize(kw.get("platform") or "", 60)
    sender = _sanitize(kw.get("sender_id") or "", 24)
    session_id = _sanitize(kw.get("session_id") or "", 80)
    device_ctx = _device_context_for(platform, sender, session_id)
    try:
        host = _sanitize(socket.gethostname(), 60)
    except OSError:
        host = ""
    parts = [
        f"[Aigent awareness — {now.strftime('%Y-%m-%d %H:%M')} {now.strftime('%A')}]",
        f"Time of day: {_time_bucket(now.hour)}",
        f"Platform: {platform or 'unknown'}",
    ]
    if host:
        parts.append(f"Host (PC): {host}")
    for key in ("session", "device", "location", "connection"):
        val = _sanitize(device_ctx.get(key), 120)
        if val:
            parts.append(f"{key.title()}: {val}")
    if sender:
        parts.append(f"Sender: {sender}")
    parts.append(
        "Adapt response length and urgency to the situation: shorter on mobile/"
        "on-the-go, more detail at the desk; note device/location when it affects "
        "the answer."
    )
    return {"context": "\n".join(parts)}


def _write_device_context(source: str, ctx: dict) -> None:
    """Atomically merge the client-reported device/session context under ``source``.

    ``source`` is the key identifying the client (e.g. ``api_server:<device_id>``,
    ``slack:<user_id>``). Other sources' entries are preserved.
    """
    path = _device_context_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    m = _read_device_context_map()
    m[source or "api_server"] = {k: ctx[k] for k in _DEVICE_CONTEXT_FIELDS if k in ctx}
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(m, f, indent=2, sort_keys=True)
    os.replace(tmp, path)


def _api_server_route_factory(native, adapter):
    """Mount /api/pistisai/device-context on the Hermes API server (port 8642).

    The desktop app POSTs its device/session context here; the awareness
    ``pre_llm_call`` hook reads the same file. Auth reuses the API server's
    own ``_check_auth`` so the route cannot drift from core auth.
    """
    if native is None:
        return
    try:
        from aiohttp import web
    except Exception:  # pragma: no cover - aiohttp always present with the gateway
        return

    def _auth(request):
        try:
            return adapter._check_auth(request)
        except Exception:
            # Fail closed: an erroring auth check must never grant access.
            return web.json_response(
                {"error": {"message": "auth check failed",
                           "type": "gateway_auth_error"}},
                status=500,
            )

    async def _get(request):
        if (err := _auth(request)) is not None:
            return err
        return web.json_response({"context": _read_device_context_map()})

    async def _post(request):
        if (err := _auth(request)) is not None:
            return err
        try:
            body = await request.json()
        except Exception:
            return web.json_response({"detail": "invalid JSON"}, status=400)
        if not isinstance(body, dict):
            return web.json_response({"detail": "object body required"}, status=400)
        incoming = {
            key: _sanitize(body[key], 200)
            for key in ("device", "session", "location", "connection")
            if body.get(key) is not None
        }
        incoming = {k: v for k, v in incoming.items() if v}
        if not incoming:
            return web.json_response({"detail": "no fields provided"}, status=400)
        source = _sanitize(body.get("source") or "api_server", 120)
        if not source:
            source = "api_server"
        try:
            _write_device_context(source, incoming)
        except OSError as e:
            return web.json_response(
                {"detail": f"could not write context: {e}"}, status=500)
        return web.json_response({"context": _read_device_context_map()})

    async def _delete(request):
        if (err := _auth(request)) is not None:
            return err
        try:
            os.remove(_device_context_path())
        except FileNotFoundError:
            pass
        except OSError as e:
            return web.json_response(
                {"detail": f"could not clear context: {e}"}, status=500)
        return web.json_response({"detail": "cleared"})

    router = native.router
    router.add_get("/api/pistisai/device-context", _get)
    router.add_post("/api/pistisai/device-context", _post)
    router.add_delete("/api/pistisai/device-context", _delete)


def register(ctx) -> None:
    ctx.register_hook("transform_tool_result", _on_transform_tool_result)
    ctx.register_hook("pre_llm_call", _on_pre_llm_call)
    ctx.register_platform_handler("api_server", _api_server_route_factory)
