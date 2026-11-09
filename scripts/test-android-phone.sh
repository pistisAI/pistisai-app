#!/usr/bin/env bash
# Run on-device integration tests on a USB-connected Android phone.
# For hub-in-Docker + on-device tests, use:
#   bash scripts/run_integration_test_rig.sh --android-only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PATH="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools:${PATH:-}"

DEVICE="${ANDROID_DEVICE_ID:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE="$(flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
for d in json.load(sys.stdin):
    if d.get('emulator') is False and str(d.get('targetPlatform', '')).startswith('android'):
        print(d['id'])
        break
" || true)"
fi

if [[ -z "$DEVICE" ]]; then
  echo "No USB Android device found. Plug in the phone, enable USB debugging, and retry." >&2
  flutter devices >&2
  exit 1
fi

echo "Using Android device: $DEVICE"

DART_DEFINES=()
if [[ -n "${PISTISAI_SELF_TEST_HUB_HOST:-}" ]]; then
  DART_DEFINES+=(--dart-define=PISTISAI_SELF_TEST_HUB_HOST="${PISTISAI_SELF_TEST_HUB_HOST}")
  echo "Self-hosted hub probe target: ${PISTISAI_SELF_TEST_HUB_HOST}"
else
  echo "Skipping Tailscale hub probe (set PISTISAI_SELF_TEST_HUB_HOST to enable)."
fi

flutter pub get

echo "Running integration_test/mobile_phone_self_test.dart on device..."
flutter test integration_test/mobile_phone_self_test.dart -d "$DEVICE" "${DART_DEFINES[@]}"

echo "Done."
