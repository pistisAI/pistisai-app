#!/usr/bin/env bash
# Shared helpers for the PistisAI integration test rig (desktop hub + clients).
# Sourced by scripts/run_integration_test_rig.sh — not executed directly.

test_rig_project_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  cd "$(cd "$script_dir/.." && pwd)" && pwd
}

test_rig_default_compose_file() {
  echo "${TEST_RIG_COMPOSE_FILE:-$(test_rig_project_root)/docker-compose.test.yml}"
}

test_rig_log_info() { echo -e "\033[0;34m[test-rig]\033[0m $*"; }
test_rig_log_ok() { echo -e "\033[0;32m[test-rig]\033[0m $*"; }
test_rig_log_warn() { echo -e "\033[1;33m[test-rig]\033[0m $*"; }
test_rig_log_err() { echo -e "\033[0;31m[test-rig]\033[0m $*" >&2; }

test_rig_wait_for_hub() {
  local compose_file="$1"
  local i
  for i in $(seq 1 60); do
    if curl -sf "http://127.0.0.1:1337/health" >/dev/null 2>&1; then
      if curl -sf "http://127.0.0.1:1337/api/pistisai/hub" | grep -q primary_hub; then
        test_rig_log_ok "Hub healthy (:1337 health + /api/pistisai/hub)"
        return 0
      fi
    fi
    if [[ $i -eq 60 ]]; then
      test_rig_log_err "Hub did not become healthy on localhost:1337"
      docker compose -f "$compose_file" logs test-desktop 2>/dev/null || true
      return 1
    fi
    sleep 2
  done
}

test_rig_start_hub() {
  local compose_file="$1"
  local build_image="$2"
  if [[ "$build_image" == "true" ]]; then
    test_rig_log_info "Building test-desktop image..."
    docker compose -f "$compose_file" build test-desktop
  fi
  test_rig_log_info "Starting test-desktop hub..."
  docker compose -f "$compose_file" up -d test-desktop
  test_rig_wait_for_hub "$compose_file"
}

test_rig_stop_hub() {
  local compose_file="$1"
  docker compose -f "$compose_file" down -v --remove-orphans 2>/dev/null || true
}

test_rig_android_sdk() {
  if [[ -n "${ANDROID_HOME:-}" ]]; then
    echo "$ANDROID_HOME"
    return
  fi
  if [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    echo "$ANDROID_SDK_ROOT"
    return
  fi
  flutter doctor -v 2>/dev/null | sed -n 's/.*Android SDK at \(.*\)$/\1/p' | head -1
}

# TEST_RIG_PREFER_EMULATOR=true (default): use AVD, never a USB phone.
test_rig_pick_android_device() {
  if [[ -n "${ANDROID_DEVICE_ID:-}" ]]; then
    echo "$ANDROID_DEVICE_ID"
    return
  fi
  PREFER="${TEST_RIG_PREFER_EMULATOR:-true}"
  flutter devices --machine 2>/dev/null | python3 -c "
import json, os, sys
prefer = os.environ.get('TEST_RIG_PREFER_EMULATOR', 'true').lower() in ('1', 'true', 'yes')
devices = [d for d in json.load(sys.stdin) if str(d.get('targetPlatform', '')).startswith('android')]
emus = [d for d in devices if d.get('emulator')]
phys = [d for d in devices if not d.get('emulator')]
if prefer:
    if emus:
        print(emus[0]['id'])
elif phys:
    print(phys[0]['id'])
elif emus:
    print(emus[0]['id'])
elif devices:
    print(devices[0]['id'])
" 
}

test_rig_start_android_emulator() {
  local sdk avd emulator_bin
  sdk="$(test_rig_android_sdk)"
  if [[ -z "$sdk" || ! -d "$sdk" ]]; then
    test_rig_log_err "Android SDK not found."
    return 1
  fi
  export ANDROID_HOME="$sdk" ANDROID_SDK_ROOT="$sdk"
  export PATH="$sdk/emulator:$sdk/platform-tools:$sdk/cmdline-tools/latest/bin:${PATH:-}"

  local running
  running="$(TEST_RIG_PREFER_EMULATOR=true test_rig_pick_android_device 2>/dev/null || true)"
  if [[ -n "$running" && "$running" == emulator-* ]]; then
    test_rig_log_ok "Emulator already running: $running"
    echo "$running"
    return 0
  fi

  avd="${TEST_RIG_AVD_NAME:-pistisai_test}"
  emulator_bin="$sdk/emulator/emulator"
  if [[ ! -x "$emulator_bin" ]]; then
    test_rig_log_err "Android emulator not installed. Run: bash scripts/setup-android-test-emulator.sh"
    return 1
  fi
  if ! "$emulator_bin" -list-avds | grep -qx "$avd"; then
    test_rig_log_err "No AVD '$avd'. Run: bash scripts/setup-android-test-emulator.sh"
    return 1
  fi

  test_rig_log_info "Starting emulator AVD '$avd' (USB phones are ignored)..."
  "$emulator_bin" -avd "$avd" -no-snapshot-load -gpu swiftshader_indirect -no-audio -no-boot-anim \
    >/tmp/pistisai-test-emulator.log 2>&1 &
  local i
  for i in $(seq 1 120); do
    running="$(TEST_RIG_PREFER_EMULATOR=true test_rig_pick_android_device 2>/dev/null || true)"
    if [[ -n "$running" && "$running" == emulator-* ]]; then
      adb -s "$running" wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done' 2>/dev/null || true
      test_rig_log_ok "Emulator ready: $running"
      echo "$running"
      return 0
    fi
    sleep 2
  done
  test_rig_log_err "Emulator failed to start. See /tmp/pistisai-test-emulator.log"
  return 1
}

test_rig_resolve_hub_host() {
  local hub_host="${PISTISAI_SELF_TEST_HUB_HOST:-}"
  if [[ -n "$hub_host" ]]; then
    echo "$hub_host"
    return
  fi
  local device
  device="$(test_rig_pick_android_device 2>/dev/null || true)"
  if [[ "$device" == emulator-* ]] || [[ "${TEST_RIG_PREFER_EMULATOR:-true}" == "true" ]]; then
    echo "10.0.2.2"
    return
  fi
  if command -v tailscale >/dev/null 2>&1; then
    local ts_ip
    ts_ip="$(tailscale ip -4 2>/dev/null | head -1 || true)"
    if [[ -n "$ts_ip" ]]; then
      echo "$ts_ip"
      return
    fi
  fi
  echo "127.0.0.1"
}

test_rig_capture_failure_screenshot() {
  local compose_file="$1"
  local dest="${2:-failure_screenshot.png}"
  docker compose -f "$compose_file" exec -T test-desktop \
    bash -c "DISPLAY=:99 import -window root /recordings/failure_screenshot.png" 2>/dev/null || true
  docker compose -f "$compose_file" cp \
    test-desktop:/recordings/failure_screenshot.png "./$dest" 2>/dev/null || true
}
