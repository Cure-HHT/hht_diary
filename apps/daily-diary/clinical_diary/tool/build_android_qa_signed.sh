#!/bin/bash
# Implements: DIARY-OPS-single-promotable-artifact/C

# Build the Clinical Diary SIGNED Android app with QA flavor
# Usage: doppler run -- ./tool/build_android_qa_signed.sh
#
# Requires Doppler secrets:
#   ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD,
#   ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYSTORE_PATH="$PROJECT_DIR/android/app/key.jks"
KEY_PROPS_PATH="$PROJECT_DIR/android/key.properties"

# Stamp the bundled env pointer (env name == flavor name); the helper also
# registers an EXIT trap to restore env.json. Re-trap so BOTH the keystore
# cleanup and the env-pointer restore run on exit.
source "$SCRIPT_DIR/_write_env_pointer.sh" qa
cleanup() {
  rm -f "$KEYSTORE_PATH" "$KEY_PROPS_PATH"
  restore_env_pointer
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

echo "Building Clinical Diary for Android (QA flavor, signed)..."
flutter build apk --flavor qa

echo ""
echo "Build complete! Signed APK at build/app/outputs/flutter-apk/app-qa-release.apk"
