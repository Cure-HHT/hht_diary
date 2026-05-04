#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process

# Build the Clinical Diary SIGNED Android app with PROD flavor
# Usage: doppler run -- ./tool/build_android_prod_signed.sh
#
# Requires Doppler secrets:
#   ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD,
#   ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYSTORE_PATH="$PROJECT_DIR/android/app/key.jks"
KEY_PROPS_PATH="$PROJECT_DIR/android/key.properties"

cleanup() {
  rm -f "$KEYSTORE_PATH" "$KEY_PROPS_PATH"
}
trap cleanup EXIT

# Validate Doppler secrets are available
if [ -z "$ANDROID_KEYSTORE_BASE64" ]; then
  echo "ERROR: Doppler secrets not available. Run with: doppler run -- $0"
  exit 1
fi

echo "Setting up release signing..."
printf "%s" "$ANDROID_KEYSTORE_BASE64" | base64 --decode > "$KEYSTORE_PATH"
cat > "$KEY_PROPS_PATH" <<EOF
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
storeFile=key.jks
EOF

echo "Building Clinical Diary for Android (PROD flavor, signed)..."
# Use appbundle for Play Store submission
flutter build appbundle --release --flavor prod --dart-define=APP_FLAVOR=prod

echo ""
echo "Build complete! Signed AAB at build/app/outputs/bundle/prodRelease/app-prod-release.aab"
