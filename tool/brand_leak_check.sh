#!/usr/bin/env bash
# Fail when a white-label web build still carries upstream hosts or names.
#
#   tool/brand.sh example && flutter build web --release --dart-define=BRAND=example
#   tool/brand_leak_check.sh build/web
#
# A hit means a host, link, URL scheme, or visible name is hardcoded instead of
# coming from brand/<id>/brand.yaml (api_base_url, ws_endpoint, tunnel_ssh_url,
# app_url, url_scheme, releases_url, product_name, ...). Fix the source, then
# re-bake. See docs/WHITE_LABEL.md.
#
# Allowed on purpose: the lowercase Dart package / Hermes plugin id
# `pistisai`, the Windows binary name `Pistisai.exe` (not renamed yet), and the
# upstream licence text in NOTICES.
set -euo pipefail

DIR="${1:-build/web}"
if [ ! -f "$DIR/main.dart.js" ]; then
  echo "No web build at $DIR (missing main.dart.js)" >&2
  exit 2
fi

status=0
check() {
  local label="$1" pattern="$2" flags="$3"
  local hits
  hits="$(grep -rnoE $flags --exclude=NOTICES -e "$pattern" "$DIR" \
    | grep -v 'Pistisai\.exe' || true)"
  if [ -n "$hits" ]; then
    echo "::error::White-label build contains upstream $label:"
    echo "$hits" | cut -c1-200 | sort | uniq -c | sort -rn | head -20
    status=1
  fi
}

check "hosts" '[A-Za-z0-9.-]*pistisai\.app' -i
check "repository links" 'pistisai/pistisai-app' -i
check "URL schemes" 'pistisai://' -i
check "product name" '.{0,30}(Pistisai|PistisAI|PISTISAI|ΠΙΣΤΙΣΑΙ).{0,30}' ''

if [ "$status" -ne 0 ]; then
  echo "Move the value into brand/<id>/brand.yaml and read it via Brand.current." >&2
  exit 1
fi
echo "No upstream hosts, links, schemes, or names in $DIR."
