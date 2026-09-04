#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEB_OUTPUT="${WEB_OUTPUT:-$PROJECT_ROOT/build/web}"

log() {
  echo "[stage-web-installers] $*"
}

if [[ ! -d "$WEB_OUTPUT" ]]; then
  log "Web output directory not found: $WEB_OUTPUT"
  exit 1
fi

log "Generating Linux install.sh..."
chmod +x "$SCRIPT_DIR/build_installer.sh"
"$SCRIPT_DIR/build_installer.sh"

if [[ ! -f "$PROJECT_ROOT/dist/linux/install.sh" ]]; then
  log "Expected dist/linux/install.sh after build_installer.sh"
  exit 1
fi

cp "$PROJECT_ROOT/dist/linux/install.sh" "$WEB_OUTPUT/install.sh"
chmod 755 "$WEB_OUTPUT/install.sh"
log "Staged install.sh ($(wc -c < "$WEB_OUTPUT/install.sh") bytes)"

VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)
PS1_OUTPUT="$WEB_OUTPUT/install.ps1"

log "Generating Windows install.ps1 for v$VERSION..."
sed "s/INSTALL_VERSION=\"\"/INSTALL_VERSION=\"$VERSION\"/" \
  "$SCRIPT_DIR/installer-template.ps1" > "$PS1_OUTPUT"
chmod 644 "$PS1_OUTPUT"
log "Staged install.ps1 ($(wc -c < "$PS1_OUTPUT") bytes)"

for file in install.sh install.ps1; do
  if [[ ! -s "$WEB_OUTPUT/$file" ]]; then
    log "Missing or empty staged file: $WEB_OUTPUT/$file"
    exit 1
  fi
done

log "Done."
