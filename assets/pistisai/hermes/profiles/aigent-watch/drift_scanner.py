"""aigent-watch — deterministic drift scanner.

Scans durable writes for unsourced assertions (C1/C2/C3/C4 checks).
Logs every trigger to the resolved drift log (AIGENT_DRIFT_LOG, else
<HERMES_HOME>/logs/drift-log.md).
Prints findings as JSON for the Bot to act on.

Record roots (most specific first, de-duplicated): AIGENT_RECORD_ROOT,
HERMES_HOME, then the user home.
Person names for C2: AIGENT_WATCH_PERSONS (comma separated) overrides the
built-in list.
"""
import json, os, re, time

_FINDINGS_HINT = ("file-dig-findings", "docs/personal", "docs\\personal")

_SOURCE_MARKER = re.compile(
    r"(?:19|20)\d\d|\bJan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|\d{1,2}/\d{1,2}|[A-Za-z]:[/\\]|~/|"
    r"VERIFIED|RETRACTED|CONFLICT|UNVERIFIED|CORRECTED|SUPERSEDED|"
    r"HARD RULE|his-words|posts-extracted|\.txt:|\.json:|\.md:|"
    r"per the corpus|from the corpus|his own words|his words|"
    r"tool output|session id|source:", re.I)

_DEFAULT_PERSON_NAMES = (
    "Marilyn|Sandra|Emma|Côté|Cote|Majo|Majogodi|Frederik|Frédérik|"
    "Coralie|Tremblay|Elizabethgaulin|Érik|Erik|Michèle|Michele"
)

_CITATION = re.compile(r"([\w./\\-]+\.(?:txt|json|md|py|html|jsonl))[: ](\d{1,6})")

# C4 — files written by a past agent, not by the person. Citing one of these
# as their authority is circular.
_SELF_AUTHORED = re.compile(
    r"(DAD\.md|MOM\.md|WHO-I-AM\.md|ELENCHOS\.md|SIMON\.md|ERIK-GRAVEL\.md|"
    r"The Long Birth|C2L Framework|zoid-read-on-christopher|habits-dossier|"
    r"vault[/\\]Identity)", re.I)

# Language that hands a claim to the person as THEIR rule/word.
_ATTRIBUTION = re.compile(
    r"(his own standard|his standard|his rule|his words|his word|his directive|"
    r"his instruction|he said|he wrote|he states|stated by him|per his)", re.I)


_STRUCTURAL = ("#", "|", "-", ">", "---", "§", "*")


def _env(name, default=""):
    return (os.environ.get(name) or "").strip() or default


def _roots():
    roots = []
    for candidate in (_env("AIGENT_RECORD_ROOT"), _env("HERMES_HOME")):
        if candidate and os.path.isdir(candidate) and candidate not in roots:
            roots.append(candidate)
    home = os.path.expanduser("~")
    if home and home not in roots:
        roots.append(home)
    return roots or ["."]


def _resolve(path):
    if os.path.isabs(path):
        return path
    for root in _roots():
        candidate = os.path.join(root, path)
        if os.path.exists(candidate):
            return candidate
    return os.path.join(_roots()[0], path)


def _default_drift_log():
    explicit = _env("AIGENT_DRIFT_LOG")
    if explicit:
        return explicit
    home = _env("HERMES_HOME", os.path.join(os.path.expanduser("~"), ".hermes"))
    return os.path.join(home, "logs", "drift-log.md")


_DRIFT_LOG_PATH = None


def _drift_log():
    """Resolved lazily so AIGENT_DRIFT_LOG is honoured on first write."""
    global _DRIFT_LOG_PATH
    if _DRIFT_LOG_PATH is None:
        _DRIFT_LOG_PATH = _default_drift_log()
    return _DRIFT_LOG_PATH

_PERSON_NAMES_RE = re.compile(
    r"\b(" + _DEFAULT_PERSON_NAMES + r")\b", re.I
)
_PERSON_NAMES_OVERRIDE = None

# Files where person name density is naturally high - C2 checking here creates noise
# We still scan these files but apply smarter logic to reduce false positives
_HIGH_PERSON_DENSITY_FILES = re.compile(
    r"(DAD\.md|MOM\.md|WHO-I-AM\.md|ELENCHOS\.md|SIMON\.md|ERIK-GRAVEL\.md|"
    r"The Long Birth|C2L Framework|Identity/|vault/Identity/)")


def _person_names():
    global _PERSON_NAMES_OVERRIDE
    if _PERSON_NAMES_OVERRIDE is None:
        override = _env("AIGENT_WATCH_PERSONS")
        if override:
            parts = [re.escape(p.strip()) for p in override.split(",") if p.strip()]
            pattern = "|".join(parts) if parts else _DEFAULT_PERSON_NAMES
        else:
            pattern = _DEFAULT_PERSON_NAMES
        try:
            _PERSON_NAMES_OVERRIDE = re.compile(r"\b(" + pattern + r")\b", re.I)
        except re.error:
            _PERSON_NAMES_OVERRIDE = re.compile(
                r"\b(" + _DEFAULT_PERSON_NAMES + r")\b", re.I
            )
    return _PERSON_NAMES_OVERRIDE


def is_prose(s):
    if len(s) < 60 or s.startswith(_STRUCTURAL) or s.count("`") >= 2:
        return False
    if not (" " in s and len(s.split()) >= 8):
        return False
    if re.match(r"^\d+[\.\)]\s", s):
        return False
    if re.match(r"^(Pick|Choose|Build|Draft|Update|Download|Resolve|Merge|Fix|Add|Create|Set up|Wire|Write)\b", s, re.I):
        return False
    if "→" in s or "-->" in s:
        return False
    if s.endswith(":") or s.endswith("—") or s.endswith("--"):
        return False
    return True


def citation_resolves(citation_text):
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


def scan_file(path, content):
    findings = []
    raw = content.splitlines()

    # C4 — misattributed voice: a self-authored file cited as the person's authority.
    # Signature = self-authored filename + a line-number citation ("DAD.md L25",
    # "zoid-read-on-christopher.md:8").
    # A +-4 line window test was tried and over-flagged badly.
    # C4 stays narrow on purpose — precision first, widen only with telemetry.
    _AUTH_CITE = re.compile(r"(L\d{1,5}|:\d{1,5})")
    c4_lines = set()
    for i, line in enumerate(raw):
        if _SELF_AUTHORED.search(line) and _AUTH_CITE.search(line):
            c4_lines.add(i)

    for i in sorted(c4_lines):
        s = raw[i].strip()
        if s:
            findings.append(("C4", s))

    for i, line in enumerate(raw):
        if i in c4_lines:
            continue
        s = line.strip()
        if not s:
            continue
        # C2 check with intelligence to reduce noise in high-person-density files
        person_match = _person_names().search(s)
        if person_match and not _SOURCE_MARKER.search(s):
            # In high-person-density files (identity files, bios, etc.), apply smarter logic
            # to reduce false positives while preserving signal
            if _HIGH_PERSON_DENSITY_FILES.search(path):
                # Check if this is likely a legitimate person claim vs. just expected naming
                # Look for relationship verbs, legal terminology, or other context that suggests
                # this is a meaningful assertion rather than just a name in a bio/list
                meaningful_context_patterns = [
                    r"\b(is|was|has been|became|married to|divorced from|father of|mother of|son of|daughter of)\b",
                    r"\b(relationship|role|position|title|alias|also known as|aka)\b",
                    r"\b(born|died|lived|resides)\b",
                    r"\b(plaintiff|defendant|witness|victim|suspect|officer|agent)\b",
                    r"\b(contact|communication|call|message|email|letter)\b",
                    r"\b(date|time|year|month|day)\s*\d",
                    r"\b(section|article|paragraph|clause|law|act|regulation)\b",
                    r"\d{4}",  # Years
                    r"\b(January|February|March|April|May|June|July|August|September|October|November|December)\b",
                ]

                has_meaningful_context = any(
                    re.search(pattern, s, re.IGNORECASE)
                    for pattern in meaningful_context_patterns
                )

                if not has_meaningful_context:
                    # Skip only the C2 flag; still allow C1/C3 below.
                    person_match = None

            if person_match:
                findings.append(("C2", s))
                continue
        if not is_prose(s):
            continue
        if any(h in path for h in _FINDINGS_HINT) and not _SOURCE_MARKER.search(s):
            findings.append(("C1", s))
            continue
        if _CITATION.search(s) and not citation_resolves(s):
            findings.append(("C3", s))
    return findings


def log_trigger(check, path, detail):
    try:
        os.makedirs(os.path.dirname(_drift_log()), exist_ok=True)
        ts = time.strftime("%Y-%m-%d %H:%M")
        with open(_drift_log(), "a", encoding="utf-8") as f:
            f.write(f"- {ts} | {check} | {path} :: {detail[:160]}\n")
    except OSError:
        pass


def scan_targets(targets=None):
    """Scan a list of (path, content) tuples. Returns findings."""
    if targets is None:
        targets = _default_targets()
    all_findings = []
    for path, content in targets:
        if not isinstance(content, str) or not content:
            continue
        for check, line in scan_file(path, content):
            all_findings.append({"check": check, "path": path, "line": line[:200]})
            log_trigger(check, path, line)
    return all_findings


def _default_targets():
    targets = []
    scan_dirs = []
    for base in _roots():
        scan_dirs.append((os.path.join(base, "ZoidBot", "vault"), ".md"))
        scan_dirs.append((os.path.join(base, "docs", "personal"), ".md"))
        scan_dirs.append((os.path.join(base, "docs"), ".md"))
    for base, ext in scan_dirs:
        if not os.path.isdir(base):
            continue
        for root, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d not in (".git", ".obsidian", "__pycache__", ".venv")]
            for f in files:
                if not f.endswith(ext):
                    continue
                # Never scan our own output log. Findings are appended there, so
                # scanning it makes the log quote itself and re-flag on every run.
                if os.path.basename(f) == os.path.basename(_drift_log()):
                    continue
                path = os.path.join(root, f)
                try:
                    with open(path, encoding="utf-8", errors="replace") as fh:
                        targets.append((path, fh.read()))
                except OSError:
                    pass
    return targets


if __name__ == "__main__":
    findings = scan_targets()
    print(json.dumps(findings, indent=2, ensure_ascii=False))
