#!/bin/bash
# Implements: DIARY-OPS-single-promotable-artifact/C

# Build the Clinical Diary Android app with UAT flavor (unsigned/debug-signed)
# Usage: ./tool/build_android_uat.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building Clinical Diary for Android (UAT flavor)..."

# For Android, --flavor sets FLUTTER_APP_FLAVOR automatically
# Stamp the bundled env pointer; restored on exit by the sourced helper.
source "$SCRIPT_DIR/_write_env_pointer.sh" uat
flutter build apk --flavor uat

echo ""
echo "Build complete! APK at build/app/outputs/flutter-apk/app-uat-release.apk"
