#!/usr/bin/env python3
"""Map a Conventional Commit PR title to a semver bump kind.

Rule (every merged PR bumps; the title type sets the size):
  - `type!:` or a `BREAKING CHANGE` footer  -> major
  - `feat` (any scope)                       -> minor
  - anything else (fix, ci, test, docs, ...) -> patch

Release PRs (`chore(release): bump version ...`) are not bumped again: they
are the output of this bump, and bumping them would loop.

Usage:
  version_bump_kind.py "<title>" ["<body>"]   -> prints: major|minor|patch|skip
"""
import re
import sys

TITLE_RE = re.compile(r"^(?P<type>[a-zA-Z]+)(?:\((?P<scope>[^)]*)\))?(?P<bang>!)?:\s+\S")
RELEASE_RE = re.compile(r"^chore\(release\):\s+bump version", re.IGNORECASE)


def bump_kind(title: str, body: str = "") -> str:
    title = (title or "").strip()
    if RELEASE_RE.match(title):
        return "skip"
    m = TITLE_RE.match(title)
    if not m:
        # Not conventional: still bump, default to patch. The title check
        # workflow is what rejects these; the bump should not silently skip.
        return "patch"
    if m.group("bang") or re.search(r"^BREAKING[ -]CHANGE:", body or "", re.MULTILINE):
        return "major"
    if m.group("type").lower() == "feat":
        return "minor"
    return "patch"


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: version_bump_kind.py <title> [body]", file=sys.stderr)
        sys.exit(2)
    print(bump_kind(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ""))
