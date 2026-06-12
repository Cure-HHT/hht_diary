#!/usr/bin/env bash
set -euo pipefail

# Builds an AWS Device Farm / Firebase Test Lab compatible iOS XCTest package.
#
# Device Farm expects the uploaded XCTest zip to contain exactly the contents of
# DerivedData/Build/Products, with one .xctestrun file at the zip root.
# Do not upload a zipped .ipa to the XCTest slot.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKSPACE="${WORKSPACE:-$APP_DIR/ios/Runner.xcworkspace}"
SCHEME="${SCHEME:-Runner}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$APP_DIR/build/device-farm/DerivedData}"
OUTPUT_DIR="${OUTPUT_DIR:-$APP_DIR/build/device-farm}"
OUTPUT_ZIP="${OUTPUT_ZIP:-$OUTPUT_DIR/clinical-diary-ios-xctest.zip}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"
INTEGRATION_TARGET="${INTEGRATION_TARGET:-integration_test/mobile_qa_smoke_test.dart}"
FLAVOR="${FLAVOR:-qa}"
QA_DART_DEFINE="${QA_DART_DEFINE:-QA_EVIDENCE_OVERLAY=true}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is required. Run this script on macOS with Xcode installed." >&2
  exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "error: zip is required." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -rf "$DERIVED_DATA_PATH"
rm -f "$OUTPUT_ZIP"

ENV_JSON="$APP_DIR/assets/config/env.json"
FIREBASE_SRC="$APP_DIR/ios/Runner/$FLAVOR/GoogleService-Info.plist"
FIREBASE_DST="$APP_DIR/ios/Runner/GoogleService-Info.plist"

cleanup() {
  git -C "$APP_DIR" checkout -- \
    assets/config/env.json \
    ios/Runner/GoogleService-Info.plist >/dev/null 2>&1 || true
}
trap cleanup EXIT

if [[ ! -f "$FIREBASE_SRC" ]]; then
  echo "error: expected Firebase plist not found for flavor '$FLAVOR': $FIREBASE_SRC" >&2
  exit 1
fi

printf '{ "env": "%s" }\n' "$FLAVOR" > "$ENV_JSON"
cp "$FIREBASE_SRC" "$FIREBASE_DST"

echo "Building XCTest products..."
echo "  workspace:      $WORKSPACE"
echo "  scheme:         $SCHEME"
echo "  configuration:  $CONFIGURATION"
echo "  destination:    $DESTINATION"
echo "  derived data:   $DERIVED_DATA_PATH"
echo "  flavor:         $FLAVOR"
echo "  target:         $INTEGRATION_TARGET"
echo "  dart define:    $QA_DART_DEFINE"

QA_DART_DEFINE_B64="$(printf '%s' "$QA_DART_DEFINE" | base64 | tr -d '\n')"
if [[ -n "${DART_DEFINES:-}" ]]; then
  export DART_DEFINES="$DART_DEFINES,$QA_DART_DEFINE_B64"
else
  export DART_DEFINES="$QA_DART_DEFINE_B64"
fi

flutter build ios --config-only --dart-define="$QA_DART_DEFINE" "$INTEGRATION_TARGET"

xcodebuild build-for-testing \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"

PRODUCTS_DIR="$DERIVED_DATA_PATH/Build/Products"
if [[ ! -d "$PRODUCTS_DIR" ]]; then
  echo "error: expected products directory not found: $PRODUCTS_DIR" >&2
  exit 1
fi

mapfile -t XCTESTRUN_FILES < <(find "$PRODUCTS_DIR" -maxdepth 1 -name "*.xctestrun" -type f)
if [[ "${#XCTESTRUN_FILES[@]}" -ne 1 ]]; then
  echo "error: expected exactly one .xctestrun at $PRODUCTS_DIR root; found ${#XCTESTRUN_FILES[@]}" >&2
  printf 'found: %s\n' "${XCTESTRUN_FILES[@]:-<none>}" >&2
  exit 1
fi

echo "Packaging Device Farm XCTest zip..."
(
  cd "$PRODUCTS_DIR"
  zip -r "$OUTPUT_ZIP" .
)

echo "Created: $OUTPUT_ZIP"
echo "Contents check:"
unzip -l "$OUTPUT_ZIP" | sed -n '1,80p'
