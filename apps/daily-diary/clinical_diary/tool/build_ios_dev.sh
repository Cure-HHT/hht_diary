#!/bin/bash
# Implements: DIARY-OPS-single-promotable-artifact/C

# Build the Clinical Diary iOS app with DEV flavor
# Usage: ./tool/build_ios_dev.sh

set -e

echo "Building Clinical Diary for iOS (DEV flavor)..."

# For iOS, --flavor sets FLUTTER_APP_FLAVOR automatically
# Env = committed default (dev) in assets/config/env.json; no stamp needed.
flutter build ios --flavor dev

echo ""
echo "Build complete! Open ios/Runner.xcworkspace in Xcode to run on device."
