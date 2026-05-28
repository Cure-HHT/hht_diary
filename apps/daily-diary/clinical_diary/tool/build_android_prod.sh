#!/bin/bash
# Implements: DIARY-OPS-single-promotable-artifact/C

# Build the Clinical Diary Android app with PROD flavor (unsigned/debug-signed)
# Usage: ./tool/build_android_prod.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Building Clinical Diary for Android (PROD flavor)..."

# Use appbundle for Play Store submission
# Stamp the bundled env pointer; restored on exit by the sourced helper.
source "$SCRIPT_DIR/_write_env_pointer.sh" prod
flutter build appbundle --release --flavor prod

echo ""
echo "Build complete! AAB at build/app/outputs/bundle/prodRelease/app-prod-release.aab"
