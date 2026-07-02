#!/usr/bin/env bash
set -euo pipefail

FLAVOR="${1:-qa}"
TEST_TARGET="${2:-integration_test/firebase_test_lab_smoke_test.dart}"
OUTPUT_DIR="${3:-build/firebase-test-lab/ios}"

case "$FLAVOR" in
  dev|qa|uat) ;;
  *) echo "ERROR: unsupported Firebase Test Lab flavor '$FLAVOR' (expected dev|qa|uat)" >&2; exit 2 ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$REPO_ROOT/apps/daily-diary/clinical_diary"
IOS_DIR="$APP_DIR/ios"
RUNNER_SOURCE="$REPO_ROOT/firebase-test-lab/ios/RunnerTests.m"
OUTPUT_ABS="$APP_DIR/$OUTPUT_DIR"
DERIVED_DATA="$APP_DIR/build/ios_integ"
PRODUCTS="$DERIVED_DATA/Build/Products"

cd "$APP_DIR"

[[ -f "$TEST_TARGET" ]] || { echo "ERROR: test target not found: $APP_DIR/$TEST_TARGET" >&2; exit 1; }
[[ -f "$RUNNER_SOURCE" ]] || { echo "ERROR: iOS integration-test runner not found: $RUNNER_SOURCE" >&2; exit 1; }
[[ -f "$IOS_DIR/Runner/$FLAVOR/GoogleService-Info.plist" ]] || {
  echo "ERROR: missing iOS Firebase config for flavor '$FLAVOR'" >&2
  exit 1
}

mkdir -p "$OUTPUT_ABS"

# Preserve all tracked files changed transiently by the test build.
cleanup() {
  git -C "$APP_DIR" checkout -- \
    assets/config/env.json \
    ios/Runner/GoogleService-Info.plist \
    ios/Runner.xcodeproj/project.pbxproj \
    ios/RunnerTests/RunnerTests.swift 2>/dev/null || true
  rm -f "$IOS_DIR/RunnerTests/RunnerTests.m"
}
trap cleanup EXIT

printf '{ "env": "%s" }\n' "$FLAVOR" > assets/config/env.json
cp "$IOS_DIR/Runner/$FLAVOR/GoogleService-Info.plist" "$IOS_DIR/Runner/GoogleService-Info.plist"

# The checked-in target is currently the default Swift unit-test stub. For the
# CI checkout only, swap its project reference to Flutter's Objective-C
# integration_test bridge. This leaves the production iOS project unchanged.
cp "$RUNNER_SOURCE" "$IOS_DIR/RunnerTests/RunnerTests.m"
python3 - "$IOS_DIR/Runner.xcodeproj/project.pbxproj" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
if "RunnerTests.swift" not in text:
    raise SystemExit("RunnerTests.swift reference was not found in project.pbxproj")
text = text.replace("RunnerTests.swift", "RunnerTests.m")
text = text.replace(
    "lastKnownFileType = sourcecode.swift; path = RunnerTests.m;",
    "lastKnownFileType = sourcecode.c.objc; path = RunnerTests.m;",
)
path.write_text(text, encoding="utf-8")
PY
rm -f "$IOS_DIR/RunnerTests/RunnerTests.swift"

flutter --version
flutter clean
flutter pub get

# Configure Flutter with the integration-test Dart entrypoint, then let Xcode
# build the app and RunnerTests products for a physical iOS device.
# Implements: DIARY-OPS-single-promotable-artifact/C
flutter build ios "$TEST_TARGET" --release --no-codesign

pushd "$IOS_DIR" >/dev/null
bundle exec pod install
mkdir -p "$OUTPUT_ABS"
xcodebuild build-for-testing \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -xcconfig Flutter/Release.xcconfig \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  IPHONEOS_DEPLOYMENT_TARGET=15.0 \
  | tee "$OUTPUT_ABS/xcodebuild.log"
popd >/dev/null

XCTESTRUN="$(find "$PRODUCTS" -maxdepth 1 -type f -name 'Runner_*.xctestrun' | head -n 1 || true)"
PRODUCT_DIR="$PRODUCTS/Release-iphoneos"
ZIP_PATH="$OUTPUT_ABS/ios-${FLAVOR}-xctest.zip"

[[ -n "$XCTESTRUN" && -f "$XCTESTRUN" ]] || {
  echo "ERROR: xcodebuild did not produce a Runner_*.xctestrun file" >&2
  find "$PRODUCTS" -maxdepth 2 -print || true
  exit 1
}
[[ -d "$PRODUCT_DIR" ]] || { echo "ERROR: missing $PRODUCT_DIR" >&2; exit 1; }

rm -f "$ZIP_PATH"
pushd "$PRODUCTS" >/dev/null
zip -qry "$ZIP_PATH" "Release-iphoneos" "$(basename "$XCTESTRUN")"
popd >/dev/null

unzip -l "$ZIP_PATH" > "$OUTPUT_ABS/zip-contents.txt"
grep -q '\.xctestrun' "$OUTPUT_ABS/zip-contents.txt" || { echo "ERROR: XCTest ZIP lacks .xctestrun" >&2; exit 1; }
grep -q 'Runner\.app/' "$OUTPUT_ABS/zip-contents.txt" || { echo "ERROR: XCTest ZIP lacks Runner.app" >&2; exit 1; }
grep -q 'RunnerTests\.xctest/' "$OUTPUT_ABS/zip-contents.txt" || { echo "ERROR: XCTest ZIP lacks RunnerTests.xctest" >&2; exit 1; }

{
  echo "flavor=$FLAVOR"
  echo "test_target=$TEST_TARGET"
  echo "xctest_zip=$ZIP_PATH"
  echo "xctest_zip_sha256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
  echo "xcode_version=$(xcodebuild -version | tr '\n' ' ')"
  echo "git_sha=${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
  echo "built_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | tee "$OUTPUT_ABS/build-metadata.txt"

printf 'iOS Firebase Test Lab XCTest package:\n  %s\n' "$ZIP_PATH"
