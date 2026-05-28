#!/bin/bash
# Implements: DIARY-OPS-single-promotable-artifact/C

# Build the Clinical Diary iOS app with QA flavor
# Usage: ./tool/build_ios_qa.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building Clinical Diary for iOS (QA flavor)..."

# For iOS, --flavor sets FLUTTER_APP_FLAVOR automatically
# Stamp the bundled env pointer; restored on exit by the sourced helper.
source "$SCRIPT_DIR/_write_env_pointer.sh" qa
flutter build ios --flavor qa

echo ""
echo "Build complete! Open ios/Runner.xcworkspace in Xcode to run on device."
