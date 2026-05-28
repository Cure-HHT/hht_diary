#!/bin/bash
# Implements: DIARY-OPS-single-promotable-artifact/C

# Build the Clinical Diary iOS app with QA flavor
# Usage: ./tool/build_ipa_dev_release.sh

set -e

echo "Building Clinical Diary for iOS DEV release flavor..."

# For iOS, --flavor sets FLUTTER_APP_FLAVOR automatically
# Env = committed default (dev) in assets/config/env.json; no stamp needed.
flutter build ipa --flavor dev --release

echo ""
echo "Build complete! Drop into Transporter to distribute."
