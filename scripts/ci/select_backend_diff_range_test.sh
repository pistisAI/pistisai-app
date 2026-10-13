#!/usr/bin/env bash
# Checks select_backend_diff_range.sh against this repository's history.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/ci/select_backend_diff_range.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

bump_sha=$(git -C "$ROOT" log --grep='bump version' --format=%H -n 1)
[ -n "$bump_sha" ] || fail "no version bump commit found"
bump_subject=$(git -C "$ROOT" log -1 --format=%s "$bump_sha")
parent_sha=$(git -C "$ROOT" rev-parse "${bump_sha}^")
read -r base target < <("$SCRIPT" "$ROOT" "$bump_sha")

[ "$target" = "$parent_sha" ] || fail "bump $bump_sha target was $target, expected parent $parent_sha"
[ "$target" != "$bump_sha" ] || fail "version bump commit was the only diff target ($bump_subject)"
[ "$base" != "$target" ] || fail "bump range is empty"

echo "bump commit range ($bump_subject): $base..$target"
echo "files since previous bump (not the bump commit):"
git -C "$ROOT" diff --name-only "$base" "$target" | head -20

api_commit=$(git -C "$ROOT" log --format=%H -n 1 -- services/api-backend)
[ -n "$api_commit" ] || fail "no commit touches services/api-backend"
read -r api_base api_target < <("$SCRIPT" "$ROOT" "$api_commit")
if ! git -C "$ROOT" diff --name-only "$api_base" "$api_target" | grep -q '^services/api-backend/'; then
  echo "range $api_base..$api_target" >&2
  git -C "$ROOT" diff --name-only "$api_base" "$api_target" | head -20 >&2
  fail "commit $api_commit did not select services/api-backend"
fi

echo "api-backend commit $api_commit selects services/api-backend ($api_base..$api_target)"
echo "ok"
