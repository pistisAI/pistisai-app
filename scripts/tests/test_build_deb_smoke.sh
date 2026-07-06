#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_SCRIPT="$PROJECT_ROOT/scripts/packaging/build_deb.sh"
WORK_DIR="$(mktemp -d)"
FAKE_BUILD_DIR="$WORK_DIR/bundle"
FAKE_DPKG_DEB="$WORK_DIR/dpkg-deb"
FAKE_LOG="$WORK_DIR/dpkg-deb.log"
DIST_DIR="$WORK_DIR/dist"
export FAKE_LOG

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$FAKE_BUILD_DIR" "$DIST_DIR"
cat > "$FAKE_BUILD_DIR/pistisai" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKE_BUILD_DIR/pistisai"

cat > "$FAKE_DPKG_DEB" <<'EOF'
#!/bin/bash
set -euo pipefail
root="${3:?missing package root}"
out="${4:?missing output path}"
control="$root/DEBIAN/control"
if [[ ! -f "$control" ]]; then
  echo "missing control file" >&2
  exit 1
fi
printf 'control:%s\n' "$(tr '\n' '|' < "$control")" >> "$FAKE_LOG"
if [[ -f "$root/usr/share/applications/pistisai.desktop" ]]; then
  printf 'desktop:%s\n' "$(tr '\n' '|' < "$root/usr/share/applications/pistisai.desktop")" >> "$FAKE_LOG"
fi
: > "$out"
chmod +x "$out"
EOF
chmod +x "$FAKE_DPKG_DEB"

PATH="$WORK_DIR:/usr/bin:/bin" \
BUILD_DIR="$FAKE_BUILD_DIR" \
DIST_DIR="$DIST_DIR" \
APP_NAME="Pistisai" \
PACKAGE_NAME="pistisai" \
FAKE_LOG="$FAKE_LOG" \
"$TARGET_SCRIPT"

PACKAGE_FILE="$DIST_DIR/pistisai_$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//g' | cut -d'+' -f1)_amd64.deb"

[[ -f "$PACKAGE_FILE" ]]
[[ -x "$PACKAGE_FILE" ]]
grep -Fq 'Package: pistisai|' "$FAKE_LOG"
grep -Fq 'Name=Pistisai|' "$FAKE_LOG"
grep -Fq 'Exec=pistisai %u|' "$FAKE_LOG"
grep -Fq 'MimeType=x-scheme-handler/pistisai;|' "$FAKE_LOG"

echo "[test_build_deb_smoke] Passed"
