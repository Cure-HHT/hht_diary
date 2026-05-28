#!/bin/bash
# Implements: DIARY-OPS-single-promotable-artifact/C

# Build the Clinical Diary Android app with QA flavor (unsigned/debug-signed)
# Usage: ./tool/build_android_qa.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building Clinical Diary for Android (QA flavor)..."

# For Android, --flavor sets FLUTTER_APP_FLAVOR automatically
# Stamp the bundled env pointer; restored on exit by the sourced helper.
source "$SCRIPT_DIR/_write_env_pointer.sh" qa
flutter build apk --flavor qa

echo ""
echo "Build complete! APK at build/app/outputs/flutter-apk/app-qa-release.apk"
