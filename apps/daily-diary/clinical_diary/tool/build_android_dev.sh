#!/bin/bash
# Implements: DIARY-OPS-single-promotable-artifact/C

# Build the Clinical Diary Android app with DEV flavor (unsigned/debug-signed)
# Usage: ./tool/build_android_dev.sh

set -e

echo "Building Clinical Diary for Android (DEV flavor)..."

# For Android, --flavor sets FLUTTER_APP_FLAVOR automatically
# Env = committed default (dev) in assets/config/env.json; no stamp needed.
flutter build apk --flavor dev

echo ""
echo "Build complete! APK at build/app/outputs/flutter-apk/app-dev-release.apk"