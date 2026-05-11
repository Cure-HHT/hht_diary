#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Build the Clinical Diary Android app with UAT flavor (unsigned/debug-signed)
# Usage: ./tool/build_android_uat.sh

set -e

echo "Building Clinical Diary for Android (UAT flavor)..."

# For Android, --flavor sets FLUTTER_APP_FLAVOR automatically
flutter build apk --flavor uat --dart-define=APP_FLAVOR=uat

echo ""
echo "Build complete! APK at build/app/outputs/flutter-apk/app-uat-release.apk"
