#!/usr/bin/env bash
# Local PC integration rig: Docker desktop hub + Linux tests + **Android emulator** (not USB phone).
#
# For manual testing on your physical phone, use scripts/test-android-phone.sh instead.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/test_rig_lib.sh
source "$ROOT/scripts/test_rig_lib.sh"

cd "$ROOT"

export TEST_RIG_PREFER_EMULATOR=true
export PISTISAI_SELF_TEST_HUB_HOST="${PISTISAI_SELF_TEST_HUB_HOST:-10.0.2.2}"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  test_rig_log_err "Docker is required and must be running."
  exit 1
fi

if ! test_rig_start_android_emulator >/dev/null; then
  test_rig_log_err "Could not start Android emulator for the rig."
  exit 1
fi

export TEST_RIG_AUTO_START_EMULATOR=true
exec bash "$ROOT/scripts/run_integration_test_rig.sh" --no-flutter-build --emulator-android "$@"
