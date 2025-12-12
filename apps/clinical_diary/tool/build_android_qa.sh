#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Build the Clinical Diary Android app with QA flavor
# Usage: ./tool/build_android_qa.sh

set -e

echo "Building Clinical Diary for Android (QA flavor)..."

# For Android, --flavor sets FLUTTER_APP_FLAVOR automatically
flutter build apk --flavor qa --dart-define=APP_FLAVOR=qa

echo ""
echo "Build complete! APK at build/app/outputs/flutter-apk/app-qa-release.apk"
