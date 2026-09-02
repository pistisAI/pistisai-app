#!/usr/bin/env bash
# Local-only quality gate for Pistisai.
# Runs the fast, hermetic slices of the Flutter and Node suites.
# Hardware/integration/e2e tests are skipped unless their opt-in env flags are set.
set -euo pipefail

# Allow overriding the Flutter/Dart binary and pub cache via env vars.
# Fall back to sensible defaults for the standard development container.
export FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
export PUB_CACHE="${PUB_CACHE:-${HOME}/.pub-cache}"
export DART_BIN="${DART_BIN:-dart}"

# Ensure flutter is on PATH if FLUTTER_BIN is a full path
FLUTTER_DIR="$(dirname "${FLUTTER_BIN}")"
if [[ -d "$FLUTTER_DIR" ]]; then
    export PATH="${FLUTTER_DIR}:${PATH}"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> flutter pub get"
flutter pub get

echo "==> flutter analyze"
flutter analyze

echo "==> flutter test (excluding hardware/integration/e2e)"
flutter test \
  --exclude-tags=hardware,integration,e2e \
  test/services \
  test/theme_extensions_test.dart \
  test/models

echo "==> npm test (backend security scope)"
BYPASS_AUTH="${BYPASS_AUTH:-test-only}" \
  node --experimental-vm-modules ./node_modules/jest/bin/jest.js \
  test/api-backend/security \
  --runInBand \
  --passWithNoTests

echo "==> Quality gates complete"
