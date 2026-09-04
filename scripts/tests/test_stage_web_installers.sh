#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$(mktemp -d)"
WEB_DIR="$WORK_DIR/web"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WEB_DIR"
printf '<html></html>\n' > "$WEB_DIR/index.html"

WEB_OUTPUT="$WEB_DIR" "$PROJECT_ROOT/scripts/packaging/stage_web_installers.sh"

test -f "$WEB_DIR/install.sh"
test -f "$WEB_DIR/install.ps1"
grep -Fq '#!/bin/bash' "$WEB_DIR/install.sh"
grep -Fq 'Pistisai-Linux-' "$WEB_DIR/install.sh"
grep -Fq 'Pistisai-Windows-x64-Setup.exe' "$WEB_DIR/install.ps1"

echo "[test_stage_web_installers] Passed"
