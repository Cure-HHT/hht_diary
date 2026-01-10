#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Build the Clinical Diary iOS app with QA flavor
# Usage: ./tool/build_ios_qa.sh

set -e

echo "Building Clinical Diary for iOS (QA flavor)..."

# For iOS, --flavor sets FLUTTER_APP_FLAVOR automatically
flutter build ios --flavor qa --dart-define=APP_FLAVOR=qa

echo ""
echo "Build complete! Open ios/Runner.xcworkspace in Xcode to run on device."
