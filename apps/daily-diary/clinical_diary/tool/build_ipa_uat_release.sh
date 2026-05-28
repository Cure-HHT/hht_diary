#!/bin/bash
# Implements: DIARY-OPS-single-promotable-artifact/C

# Build the Clinical Diary iOS app with QA flavor
# Usage: ./tool/build_ipa_uat_release.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building Clinical Diary for iOS UAT release flavor..."

# For iOS, --flavor sets FLUTTER_APP_FLAVOR automatically
# Stamp the bundled env pointer; restored on exit by the sourced helper.
source "$SCRIPT_DIR/_write_env_pointer.sh" uat
flutter build ipa --flavor uat --release

echo ""
echo "Build complete! Open ios/Runner.xcworkspace in Xcode to run on device."
