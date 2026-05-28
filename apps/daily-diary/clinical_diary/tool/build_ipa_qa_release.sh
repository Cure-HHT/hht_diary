#!/bin/bash
# Implements: DIARY-OPS-single-promotable-artifact/C

# Build the Clinical Diary iOS app with QA flavor
# Usage: ./tool/build_ipa_qa_release.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building Clinical Diary for iOS QA release flavor..."

# For iOS, --flavor sets FLUTTER_APP_FLAVOR automatically
# Stamp the bundled env pointer; restored on exit by the sourced helper.
source "$SCRIPT_DIR/_write_env_pointer.sh" qa
flutter build ipa --flavor qa --release

echo ""
echo "Build complete! Open ios/Runner.xcworkspace in Xcode to run on device."
