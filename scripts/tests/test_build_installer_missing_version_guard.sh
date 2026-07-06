#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_installer.sh"
WORK_DIR="$(mktemp -d)"
OUTPUT_FILE="$WORK_DIR/stderr.txt"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$WORK_DIR/scripts/packaging/update-daemon"
cp "$TARGET_SCRIPT" "$WORK_DIR/scripts/packaging/build_installer.sh"
chmod +x "$WORK_DIR/scripts/packaging/build_installer.sh"

cat > "$WORK_DIR/scripts/packaging/installer-template.sh" <<'EOF'
#!/bin/bash
INSTALL_VERSION=""
EOF

cp "$PROJECT_ROOT/scripts/packaging/update-daemon/pistisai-updated" "$WORK_DIR/scripts/packaging/update-daemon/pistisai-updated"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/pistisai-updated.service" "$WORK_DIR/scripts/packaging/update-daemon/pistisai-updated.service"
cp "$PROJECT_ROOT/scripts/packaging/update-daemon/pistisai-updated.timer" "$WORK_DIR/scripts/packaging/update-daemon/pistisai-updated.timer"

cat > "$WORK_DIR/pubspec.yaml" <<'EOF'
name: pistisai
description: Test pubspec without version
EOF

if bash "$WORK_DIR/scripts/packaging/build_installer.sh" > /dev/null 2>"$OUTPUT_FILE"; then
  echo "build_installer.sh unexpectedly succeeded with missing version entry" >&2
  exit 1
fi

if ! grep -q "version entry not found in pubspec.yaml" "$OUTPUT_FILE"; then
  echo "Expected missing version entry error message" >&2
  cat "$OUTPUT_FILE" >&2
  exit 1
fi

echo "[test_build_installer_missing_version_guard] Passed"
