#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_FILE="$PROJECT_ROOT/scripts/release/create_github_release.sh"

if [[ ! -f "$SCRIPT_FILE" ]]; then
  echo "Missing release creator: $SCRIPT_FILE" >&2
  exit 1
fi

for needle in \
  'pistisai-$version-portable.zip' \
  'pistisai-$version-portable.zip.sha256' \
  'Pistisai-Windows-$version-Setup.exe' \
  'Pistisai-Windows-$version-Setup.exe.sha256' \
  'Missing packages from Phase 3 builds:'; do
  if ! grep -Fq "$needle" "$SCRIPT_FILE"; then
    echo "Release creator missing expected Windows installer publication string: $needle" >&2
    exit 1
  fi
done

echo "[test_create_github_release_windows_installer_assets] Passed"
