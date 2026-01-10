#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Build the Clinical Diary Android app with DEV flavor
# Usage: ./tool/build_android_dev.sh

set -e

echo "Building Clinical Diary for Android (DEV flavor)..."

# For Android, --flavor sets FLUTTER_APP_FLAVOR automatically
flutter build apk --flavor dev --dart-define=APP_FLAVOR=dev

echo ""
echo "Build complete! APK at build/app/outputs/flutter-apk/app-dev-release.apk"
