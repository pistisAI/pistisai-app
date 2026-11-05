#!/usr/bin/env bash
# PistisAI integration test rig — one Docker test-desktop hub, Linux + Android clients.
#
# Usage:
#   bash scripts/run_integration_test_rig.sh              # hub + desktop tests + Android (if device)
#   bash scripts/run_integration_test_rig.sh --desktop-only
#   bash scripts/run_integration_test_rig.sh --android-only
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/test_rig_lib.sh
source "$SCRIPT_DIR/test_rig_lib.sh"

PROJECT_ROOT="$(test_rig_project_root)"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DART_BIN="${DART_BIN:-dart}"

RUN_DESKTOP=true
RUN_ANDROID=true
FLUTTER_BUILD=true
START_HUB=true
BUILD_IMAGE=true
RUN_TESTS=true
KEEP_RUNNING=false
CLEANUP_ON_EXIT=true
COMPOSE_FILE="$(test_rig_default_compose_file)"
HUB_HOST="${PISTISAI_SELF_TEST_HUB_HOST:-}"
TEST_RIG_PREFER_EMULATOR="${TEST_RIG_PREFER_EMULATOR:-true}"
ENSURE_EMULATOR=false

DESKTOP_EXIT=0
ANDROID_EXIT=0

usage() {
  cat <<EOF
Usage: $0 [options]

Starts the test-desktop hub (docker-compose.test.yml) and runs client tests:
  • Linux: dart test against localhost:1337 (router in the hub container)
  • Android: integration_test/mobile_phone_self_test.dart on device/emulator

Options:
  --desktop-only        Run Linux host integration tests only
  --android-only        Run Android integration tests only
  --no-desktop          Skip desktop tests (default rig runs both when possible)
  --no-android          Skip Android tests
  --usb-android         Use USB phone instead of emulator (default: emulator when available)
  --no-flutter-build    Skip flutter build linux --release before desktop tests
  --no-build            Alias for --no-flutter-build (compat with run_local_integration_tests.sh)
  --no-docker-build     Skip docker image build (use existing pistisai-test-desktop:ci)
  --no-hub              Hub already running on localhost:1337
  --no-tests            Start hub only (VNC :5900)
  --keep-running        Leave hub running after tests
  --no-cleanup          Do not docker compose down on exit
  --hub-host HOST       Hub host for Android probe (default: auto)
  --compose-file FILE   Docker compose file (default: docker-compose.test.yml)
  --flutter-bin PATH
  --dart-bin PATH
  --help

Environment:
  PISTISAI_SELF_TEST_HUB_HOST   Hub hostname/IP for Android Tailscale probe
  ANDROID_DEVICE_ID             Flutter / ADB device id
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --desktop-only) RUN_DESKTOP=true; RUN_ANDROID=false; shift ;;
    --android-only) RUN_DESKTOP=false; RUN_ANDROID=true; shift ;;
    --no-desktop) RUN_DESKTOP=false; shift ;;
    --no-android) RUN_ANDROID=false; shift ;;
    --usb-android) TEST_RIG_PREFER_EMULATOR=false; shift ;;
    --emulator-android) TEST_RIG_PREFER_EMULATOR=true; ENSURE_EMULATOR=true; shift ;;
    --no-flutter-build|--no-build) FLUTTER_BUILD=false; shift ;;
    --no-docker-build) BUILD_IMAGE=false; shift ;;
    --no-hub) START_HUB=false; shift ;;
    --no-tests) RUN_TESTS=false; shift ;;
    --keep-running) KEEP_RUNNING=true; shift ;;
    --no-cleanup) CLEANUP_ON_EXIT=false; shift ;;
    --hub-host) HUB_HOST="$2"; shift 2 ;;
    --compose-file) COMPOSE_FILE="$2"; shift 2 ;;
    --flutter-bin) FLUTTER_BIN="$2"; shift 2 ;;
    --dart-bin) DART_BIN="$2"; shift 2 ;;
    --help) usage; exit 0 ;;
    *)
      test_rig_log_err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

cleanup() {
  if [[ "$CLEANUP_ON_EXIT" == "true" && "$KEEP_RUNNING" != "true" ]]; then
    test_rig_log_info "Cleaning up test environment..."
    test_rig_stop_hub "$COMPOSE_FILE"
    test_rig_log_ok "Cleanup complete"
  fi
}
trap cleanup EXIT INT TERM

cd "$PROJECT_ROOT"
export TEST_RIG_PREFER_EMULATOR
export PATH="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools:${PATH:-}"

if [[ "$RUN_ANDROID" == "true" && "$RUN_TESTS" == "true" && "$TEST_RIG_PREFER_EMULATOR" == "true" ]]; then
  _rig_dev="$(test_rig_pick_android_device 2>/dev/null || true)"
  if [[ -z "$_rig_dev" || "$_rig_dev" != emulator-* ]]; then
    if [[ "$ENSURE_EMULATOR" == "true" ]] || [[ -n "${TEST_RIG_AUTO_START_EMULATOR:-}" ]]; then
      test_rig_start_android_emulator >/dev/null || true
    fi
  fi
fi

if [[ "$RUN_DESKTOP" == "true" && "$FLUTTER_BUILD" == "true" && "$RUN_TESTS" == "true" ]]; then
  test_rig_log_info "Building Flutter Linux release (host compile check)..."
  if ! "$FLUTTER_BIN" build linux --release; then
    test_rig_log_err "Flutter build failed"
    exit 1
  fi
  test_rig_log_ok "Flutter Linux build complete"
elif [[ "$RUN_DESKTOP" == "true" && "$FLUTTER_BUILD" == "false" && "$RUN_TESTS" == "true" ]]; then
  if [[ ! -f "build/linux/x64/release/bundle/pistisai" ]]; then
    test_rig_log_warn "No host Linux build; hub still uses image built inside Docker."
  fi
fi

if [[ "$START_HUB" == "true" ]]; then
  if ! test_rig_start_hub "$COMPOSE_FILE" "$BUILD_IMAGE"; then
    exit 1
  fi
elif [[ "$RUN_TESTS" == "true" ]]; then
  if ! test_rig_wait_for_hub "$COMPOSE_FILE"; then
    exit 1
  fi
fi

if [[ "$RUN_TESTS" != "true" ]]; then
  test_rig_log_ok "Hub ready. VNC: localhost:5900  Hub: http://localhost:1337/api/pistisai/hub"
  if [[ "$KEEP_RUNNING" == "true" ]]; then
    CLEANUP_ON_EXIT=false
    while true; do sleep 1; done
  fi
  exit 0
fi

if [[ "$RUN_DESKTOP" == "true" ]]; then
  test_rig_log_info "Running Linux integration tests (host → localhost:1337)..."
  if "$DART_BIN" test test/archive/integration/app_running_integration_test.dart --reporter expanded; then
    test_rig_log_ok "Desktop integration tests passed."
  else
    DESKTOP_EXIT=$?
    test_rig_log_err "Desktop integration tests failed (exit $DESKTOP_EXIT)."
    test_rig_capture_failure_screenshot "$COMPOSE_FILE" failure_screenshot.png
  fi
fi

if [[ "$RUN_ANDROID" == "true" ]]; then
  DEVICE="$(test_rig_pick_android_device)"
  if [[ -z "$DEVICE" ]]; then
    if [[ "$RUN_DESKTOP" == "false" ]]; then
      test_rig_log_err "No Android device or emulator."
      "$FLUTTER_BIN" devices
      ANDROID_EXIT=1
    else
      test_rig_log_warn "No Android emulator — skipping mobile tests (run setup-android-test-emulator.sh or test-android-phone.sh for USB)."
    fi
  else
    if [[ -n "$HUB_HOST" ]]; then
      export PISTISAI_SELF_TEST_HUB_HOST="$HUB_HOST"
    fi
    HUB_HOST="$(test_rig_resolve_hub_host)"
    test_rig_log_info "Android device: $DEVICE"
    test_rig_log_info "Hub host for probe: $HUB_HOST"

    "$FLUTTER_BIN" pub get

    DART_DEFINES=(
      --dart-define=PISTISAI_ANDROID_TEST_RIG=true
      --dart-define=PISTISAI_SELF_TEST_HUB_HOST="$HUB_HOST"
    )

    test_rig_log_info "Running Android integration tests..."
    if "$FLUTTER_BIN" test integration_test/mobile_phone_self_test.dart -d "$DEVICE" "${DART_DEFINES[@]}"; then
      test_rig_log_ok "Android integration tests passed."
    else
      ANDROID_EXIT=$?
      test_rig_log_err "Android integration tests failed (exit $ANDROID_EXIT)."
      test_rig_capture_failure_screenshot "$COMPOSE_FILE" android_failure_screenshot.png
    fi
  fi
fi

if [[ "$KEEP_RUNNING" == "true" ]]; then
  CLEANUP_ON_EXIT=false
  test_rig_log_ok "Hub still running (VNC :5900, hub :1337). Press Ctrl+C to stop."
  while true; do sleep 1; done
fi

if [[ $DESKTOP_EXIT -ne 0 || $ANDROID_EXIT -ne 0 ]]; then
  exit 1
fi

test_rig_log_ok "Integration test rig complete."
