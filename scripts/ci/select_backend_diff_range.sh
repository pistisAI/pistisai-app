#!/usr/bin/env bash
# Print "BASE_SHA TARGET_SHA" for the commit range that decides which
# backend images to rebuild.
#
# A version-bump commit only touches version files. When TARGET is one of
# those commits, the range ends at its parent (the code that was bumped)
# and starts at the previous bump. Callers then diff BASE..TARGET.
#
# Usage: select_backend_diff_range.sh [REPO] [COMMIT]
# COMMIT defaults to HEAD.
set -euo pipefail

ROOT="${1:-.}"
TARGET="${2:-HEAD}"

if ! git -C "$ROOT" rev-parse --verify "${TARGET}^{commit}" >/dev/null 2>&1; then
  echo "select_backend_diff_range: unknown commit: $TARGET" >&2
  exit 1
fi

subject=$(git -C "$ROOT" log -1 --format=%s "$TARGET")
if printf '%s\n' "$subject" | grep -q 'bump version'; then
  if ! git -C "$ROOT" rev-parse --verify "${TARGET}^" >/dev/null 2>&1; then
    echo "select_backend_diff_range: bump commit has no parent: $TARGET" >&2
    exit 1
  fi
  code_sha=$(git -C "$ROOT" rev-parse "${TARGET}^")
else
  code_sha=$(git -C "$ROOT" rev-parse "$TARGET")
fi

prev_bump=""
if git -C "$ROOT" rev-parse --verify "${code_sha}^" >/dev/null 2>&1; then
  prev_bump=$(git -C "$ROOT" log --grep='bump version' --format=%H -n 1 "${code_sha}^" || true)
fi

if [ -n "$prev_bump" ]; then
  base_sha=$prev_bump
elif git -C "$ROOT" rev-parse --verify "${code_sha}^" >/dev/null 2>&1; then
  base_sha=$(git -C "$ROOT" rev-parse "${code_sha}^")
else
  base_sha=$(git -C "$ROOT" hash-object -t tree /dev/null)
fi

echo "backend diff range: ${base_sha}..${code_sha}" >&2
printf '%s %s\n' "$base_sha" "$code_sha"
