#!/bin/bash
# Fails if the forbidden hardcoded dev bypass literal appears in the tree.
# Issue #241: that known bypass string must never be committed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Split so this script itself does not contain the contiguous forbidden literal.
FORBIDDEN="mock_dev_"'access_token'

cd "$PROJECT_ROOT"

matches="$(git grep -n -F "$FORBIDDEN" -- . 2>/dev/null || true)"

if [[ -n "$matches" ]]; then
  echo "Found forbidden hardcoded dev bypass literal:" >&2
  echo "$matches" >&2
  echo "Use DEV_BYPASS_TOKEN from the environment instead (issue #241)." >&2
  exit 1
fi

echo "[test_no_hardcoded_dev_bypass_token] Passed — forbidden bypass literal absent from tracked files"
