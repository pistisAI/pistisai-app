#!/usr/bin/env bash
# Bake brand/<id>/brand.yaml into the app and native metadata.
# Default id is the upstream product. Run this before a branded Flutter build.
#
# Paid whitelabel brands require a licence:
#   tool/brand.sh iacle --license /path/to/iacle.licence
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRAND="${1:-pistisai}"
shift || true

cd "$ROOT"
exec dart run tool/brand_codegen.dart "$BRAND" "$@"
