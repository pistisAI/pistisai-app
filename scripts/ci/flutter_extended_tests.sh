#!/usr/bin/env bash
# Extended Flutter tests: every test/**/*_test.dart that the security gate
# (scripts/ci/flutter_security_basic_tests.sh) does not already run, minus the
# EXCLUDE list below. New test files are picked up automatically.
#
# Usage:
#   bash scripts/ci/flutter_extended_tests.sh          # run the tests
#   bash scripts/ci/flutter_extended_tests.sh --list   # print the file list only
set -euo pipefail

cd "$(dirname "$0")/../.."

GATE_SCRIPT=scripts/ci/flutter_security_basic_tests.sh

# Files that cannot run on a plain CI runner. Each needs a reason.
EXCLUDE=(
  # Needs real camera hardware (skipped unless PISTISAI_HARDWARE_E2E=1).
  test/camera_probe_test.dart
  test/v4l2_capture_test.dart
  # Needs network downloads (skipped unless PISTISAI_NETWORK_E2E=1).
  test/download_functionality_test.dart
  # Needs native desktop plugins (skipped unless PISTISAI_NATIVE_E2E=1).
  test/native/native_platform_e2e_test.dart
  # Talks to a live Hermes gateway on 127.0.0.1:8642.
  test/services/hermes_connection_test.dart
)

# Paths the gate already runs: every `test/...` argument in the gate script,
# files or directories.
mapfile -t gate_paths < <(grep -oE '^[[:space:]]*test/[^[:space:]]+' "$GATE_SCRIPT" | sed -E 's/^[[:space:]]+//')
if [ "${#gate_paths[@]}" -eq 0 ]; then
  echo "Could not read any test paths from $GATE_SCRIPT" >&2
  exit 1
fi

is_covered() {
  local file="$1" path
  for path in "${gate_paths[@]}"; do
    if [ -d "$path" ]; then
      [[ "$file" == "${path%/}/"* ]] && return 0
    else
      [[ "$file" == "$path" ]] && return 0
    fi
  done
  for path in "${EXCLUDE[@]}"; do
    [[ "$file" == "$path" ]] && return 0
  done
  return 1
}

files=()
while IFS= read -r file; do
  is_covered "$file" || files+=("$file")
done < <(find test -name '*_test.dart' -type f | LC_ALL=C sort)

if [ "${#files[@]}" -eq 0 ]; then
  echo "No extended Flutter tests to run."
  exit 0
fi

if [ "${1:-}" = "--list" ]; then
  printf '%s\n' "${files[@]}"
  exit 0
fi

echo "Running ${#files[@]} extended Flutter test files."
flutter test \
  --dart-define=BRAND=pistisai \
  "${files[@]}" \
  --reporter expanded \
  --timeout 30s
