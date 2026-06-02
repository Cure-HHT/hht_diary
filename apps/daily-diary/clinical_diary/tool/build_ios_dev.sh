#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Build the Clinical Diary iOS app with DEV flavor
# Usage: ./tool/build_ios_dev.sh

set -e

echo "Building Clinical Diary for iOS (DEV flavor)..."

# For iOS, --flavor sets FLUTTER_APP_FLAVOR automatically
flutter build ios --flavor dev --dart-define=APP_FLAVOR=dev

echo ""
echo "Build complete! Open ios/Runner.xcworkspace in Xcode to run on device."
