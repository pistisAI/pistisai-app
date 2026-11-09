#!/usr/bin/env bash
# One-time setup: Android emulator AVD for the local integration test rig (matches CI: API 34, Pixel 6).
set -euo pipefail

AVD_NAME="${TEST_RIG_AVD_NAME:-pistisai_test}"
SYSTEM_IMAGE="${TEST_RIG_SYSTEM_IMAGE:-system-images;android-34;google_apis;x86_64}"
DEVICE_PROFILE="${TEST_RIG_DEVICE_PROFILE:-pixel_6}"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$SDK" ]]; then
  SDK="$(flutter doctor -v 2>/dev/null | sed -n 's/.*Android SDK at \(.*\)$/\1/p' | head -1)"
fi
if [[ -z "$SDK" || ! -d "$SDK" ]]; then
  echo "Android SDK not found. Set ANDROID_HOME or run flutter doctor." >&2
  exit 1
fi

export ANDROID_HOME="$SDK" ANDROID_SDK_ROOT="$SDK"
export PATH="$SDK/cmdline-tools/latest/bin:$SDK/platform-tools:$SDK/emulator:$PATH"

SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
AVDMANAGER="$SDK/cmdline-tools/latest/bin/avdmanager"
if [[ ! -x "$SDKMANAGER" ]]; then
  echo "Install cmdline-tools (Android Studio → SDK Manager → Command-line Tools)." >&2
  exit 1
fi

echo "SDK: $SDK"
echo "Creating AVD: $AVD_NAME ($SYSTEM_IMAGE)"

yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
"$SDKMANAGER" "platform-tools" "emulator" "platforms;android-34" "$SYSTEM_IMAGE"

if "$SDK/emulator/emulator" -list-avds | grep -qx "$AVD_NAME"; then
  echo "AVD $AVD_NAME already exists."
  exit 0
fi

echo no | "$AVDMANAGER" create avd \
  --name "$AVD_NAME" \
  --package "$SYSTEM_IMAGE" \
  --device "$DEVICE_PROFILE"

echo "Done. Start the rig with: bash scripts/run_pc_integration_test_rig.sh"
