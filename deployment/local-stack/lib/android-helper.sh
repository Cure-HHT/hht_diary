#!/usr/bin/env bash
# Android emulator diagnostic for local-stack full-system mode.
# Prints guidance to stderr/stdout; never mutates anything; always returns 0.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

android_diagnostic() {
  local core="$1"

  echo
  echo "-- Android emulator diagnostic --------------------------------"

  if [ -z "${ANDROID_HOME:-}" ] && [ -z "${ANDROID_SDK_ROOT:-}" ]; then
    cat <<'HINT'
No ANDROID_HOME or ANDROID_SDK_ROOT set in env.

Install Android Studio: https://developer.android.com/studio
Then add to ~/.bashrc or ~/.zshrc:
  export ANDROID_HOME="$HOME/Android/Sdk"
  export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
Skipping emulator guidance.
HINT
    return 0
  fi

  local sdk="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
  local adb="$sdk/platform-tools/adb"
  local emu="$sdk/emulator/emulator"

  if [ ! -x "$adb" ] && ! command -v adb >/dev/null 2>&1; then
    echo "adb not found at $adb or on PATH. Run 'sdkmanager platform-tools'."
    return 0
  fi
  # Prefer the SDK's adb; fall back to PATH
  [ -x "$adb" ] || adb="$(command -v adb)"

  local connected
  connected="$("$adb" devices | awk 'NR>1 && $2=="device" && $1 ~ /^emulator-/ { print $1 }')"

  if [ -n "$connected" ]; then
    echo "Connected Android emulator(s):"
    # shellcheck disable=SC2086  # intentional word-splitting on $connected
    printf '  %s\n' $connected
    return 0
  fi

  # No emulator connected -- list AVDs
  if [ ! -x "$emu" ] && ! command -v emulator >/dev/null 2>&1; then
    echo "No emulator binary found. Run 'sdkmanager emulator'."
    return 0
  fi
  [ -x "$emu" ] || emu="$(command -v emulator)"

  local avds
  avds="$("$emu" -list-avds 2>/dev/null | grep -v '^$' || true)"

  if [ -z "$avds" ]; then
    cat <<'HINT'
No AVDs found. Create one in Android Studio:
  Tools -> Device Manager -> Create Device
Recommended: Pixel 7 / API 34 / Google Play.

Re-run ./local-stack full-system after creating an AVD.
HINT
    return 0
  fi

  echo "No Android emulator currently connected. Available AVDs:"
  while IFS= read -r avd; do
    echo "  $avd"
    echo "    boot it:   $emu -avd $avd &"
  done <<< "$avds"
  echo "(Then re-run ./local-stack full-system once the emulator has finished booting.)"
  return 0
}
