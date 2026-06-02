#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Build the Clinical Diary iOS app with PROD flavor
# Usage: ./tool/build_ios_prod.sh

set -e

echo "Building Clinical Diary for iOS (PROD flavor)..."

# For iOS, --flavor sets FLUTTER_APP_FLAVOR automatically
flutter build ios --release --flavor prod --dart-define=APP_FLAVOR=prod

echo ""
echo "Build complete! Open ios/Runner.xcworkspace in Xcode to archive and submit."
