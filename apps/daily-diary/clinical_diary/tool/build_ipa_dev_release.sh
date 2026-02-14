#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Build the Clinical Diary iOS app with QA flavor
# Usage: ./tool/build_ipa_dev_release.sh

set -e

echo "Building Clinical Diary for iOS DEV release flavor..."

# For iOS, --flavor sets FLUTTER_APP_FLAVOR automatically
flutter build ipa --flavor dev --dart-define=APP_FLAVOR=dev --release

echo ""
echo "Build complete! Open ios/Runner.xcworkspace in Xcode to run on device."
