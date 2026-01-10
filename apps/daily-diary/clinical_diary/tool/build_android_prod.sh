#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Build the Clinical Diary Android app with PROD flavor
# Usage: ./tool/build_android_prod.sh

set -e

echo "Building Clinical Diary for Android (PROD flavor)..."

# For Android, --flavor sets FLUTTER_APP_FLAVOR automatically
# Use appbundle for Play Store submission
flutter build appbundle --release --flavor prod --dart-define=APP_FLAVOR=prod

echo ""
echo "Build complete! AAB at build/app/outputs/bundle/prodRelease/app-prod-release.aab"
