#!/usr/bin/env bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006: Mobile App Build and Release Process
#   REQ-o00043: Automated Deployment Pipeline
set -euo pipefail

FLAVOR="${1:-qa}"
TEST_TARGET="${2:-integration_test/firebase_test_lab_smoke_test.dart}"
OUTPUT_DIR="${3:-build/firebase-test-lab/android}"

case "$FLAVOR" in
  dev|qa|uat) ;;
  *) echo "ERROR: unsupported Firebase Test Lab flavor '$FLAVOR' (expected dev|qa|uat)" >&2; exit 2 ;;
esac

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../apps/daily-diary/clinical_diary" && pwd)"
cd "$APP_DIR"

if [[ ! -f "$TEST_TARGET" ]]; then
  echo "ERROR: integration test target not found: $APP_DIR/$TEST_TARGET" >&2
  exit 1
fi

command -v flutter >/dev/null 2>&1 || { echo "ERROR: flutter is not installed" >&2; exit 1; }
command -v yq     >/dev/null 2>&1 || { echo "ERROR: yq is required"           >&2; exit 1; }

VARIANT="${FLAVOR^}Debug"
ABS_TEST_TARGET="$APP_DIR/$TEST_TARGET"
ABS_OUTPUT_DIR="$APP_DIR/$OUTPUT_DIR"
mkdir -p "$ABS_OUTPUT_DIR"

# The app now resolves its runtime environment from assets/config/env.json.
# Source the existing helper so the selected environment is bundled into both
# the application and test build, then restored automatically on shell exit.
# shellcheck source=/dev/null
source "$APP_DIR/tool/_write_env_pointer.sh" "$FLAVOR"

flutter --version
flutter pub get

# ---------------------------------------------------------------------------
# FIREBASE TEST LAB FIX: add --dart-define=APP_FLAVOR
#
# Without this flag, String.fromEnvironment('APP_FLAVOR') returns '' inside
# the compiled Dart code. The app's environment-resolution logic then cannot
# select the correct Firebase project / backend, causing the instrumentation
# runner to stall indefinitely during app initialisation (observed as "1 test
# started, 0 tests completed, matrix timeout").
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# FIREBASE TEST LAB FIX: add --dart-define=DIARY_SYNC_PERIODIC_SECONDS
#
# The app installs a live Timer.periodic sync poll (default 60s) during
# bootstrap. Under integration_test, this perpetually-pending timer prevents
# tester.pumpAndSettle() from ever reaching widget-tree quiescence, so a
# pumpAndSettle eventually blocks forever and the matrix runs to its 30m
# per-device timeout (confirmed via Firebase Test Lab logcat: tests progress,
# then the Flutter process goes silent at a non-deterministic test and is
# killed at the cap). The DIARY_SYNC_PERIODIC_SECONDS override is exposed by
# the app for exactly this purpose; stretching the poll to ~24h removes the
# never-settling timer for the duration of the test run without disabling the
# feature in production.
# ---------------------------------------------------------------------------
DIARY_SYNC_PERIODIC_SECONDS=86400

# Build the app using the integration-test entrypoint. Flutter's Android
# integration_test bridge is then packaged into the separate androidTest APK.
# This step also generates the Gradle wrapper (gradlew), which is gitignored
# and required by the Gradle invocation below.
flutter build apk \
  --debug \
  --flavor "$FLAVOR" \
  --dart-define=APP_FLAVOR="$FLAVOR" \
  --dart-define=DIARY_SYNC_PERIODIC_SECONDS="$DIARY_SYNC_PERIODIC_SECONDS" \
  --target "$TEST_TARGET"

# The Gradle invocation below assembles the androidTest APK. The
# --dart-define=APP_FLAVOR flag is propagated via -PFLUTTER_DART_DEFINE so
# String.fromEnvironment('APP_FLAVOR') resolves correctly inside the compiled
# Dart code (see FIREBASE TEST LAB FIX above).
pushd android >/dev/null
./gradlew \
  ":app:assemble${VARIANT}AndroidTest" \
  ":app:assemble${VARIANT}" \
  -Ptarget="$ABS_TEST_TARGET" \
  -PFLUTTER_DART_DEFINE="APP_FLAVOR=$FLAVOR,DIARY_SYNC_PERIODIC_SECONDS=$DIARY_SYNC_PERIODIC_SECONDS" \
  --stacktrace
popd >/dev/null

APP_APK="$(find build/app/outputs -type f -name "app-${FLAVOR}-debug.apk" ! -name '*androidTest*' | head -n 1 || true)"
TEST_APK="$(find build/app/outputs -type f -name "app-${FLAVOR}-debug-androidTest.apk" | head -n 1 || true)"

if [[ -z "$APP_APK" || ! -f "$APP_APK" ]]; then
  echo "ERROR: application APK was not produced for $FLAVOR" >&2
  find build/app/outputs -type f -name '*.apk' -print || true
  exit 1
fi
if [[ -z "$TEST_APK" || ! -f "$TEST_APK" ]]; then
  echo "ERROR: instrumentation test APK was not produced for $FLAVOR" >&2
  find build/app/outputs -type f -name '*.apk' -print || true
  exit 1
fi

cp "$APP_APK" "$ABS_OUTPUT_DIR/app-${FLAVOR}-debug.apk"
cp "$TEST_APK" "$ABS_OUTPUT_DIR/app-${FLAVOR}-debug-androidTest.apk"

APP_OUT="$ABS_OUTPUT_DIR/app-${FLAVOR}-debug.apk"
TEST_OUT="$ABS_OUTPUT_DIR/app-${FLAVOR}-debug-androidTest.apk"
METADATA="$ABS_OUTPUT_DIR/build-metadata.txt"

{
  echo "flavor=$FLAVOR"
  echo "test_target=$TEST_TARGET"
  echo "app_apk=$APP_OUT"
  echo "test_apk=$TEST_OUT"
  echo "app_sha256=$(shasum -a 256 "$APP_OUT" | awk '{print $1}')"
  echo "test_sha256=$(shasum -a 256 "$TEST_OUT" | awk '{print $1}')"
  echo "git_sha=${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
  echo "built_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | tee "$METADATA"

APK_ANALYZER="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}/cmdline-tools/latest/bin/apkanalyzer"
if [[ ! -x "$APK_ANALYZER" ]]; then
  APK_ANALYZER="$(command -v apkanalyzer || true)"
fi

if [[ -n "$APK_ANALYZER" && -x "$APK_ANALYZER" ]]; then
  "$APK_ANALYZER" manifest application-id "$APP_OUT" | tee "$ABS_OUTPUT_DIR/app-application-id.txt"
  "$APK_ANALYZER" manifest print "$TEST_OUT" > "$ABS_OUTPUT_DIR/test-manifest.xml"
  if ! grep -q 'androidx.test.runner.AndroidJUnitRunner' "$ABS_OUTPUT_DIR/test-manifest.xml"; then
    echo "ERROR: test APK does not declare AndroidJUnitRunner" >&2
    exit 1
  fi
else
  echo "WARN: apkanalyzer not found; APK manifest validation was skipped" | tee "$ABS_OUTPUT_DIR/apkanalyzer-warning.txt"
fi

printf 'Android Firebase Test Lab artifacts:\n  %s\n  %s\n' "$APP_OUT" "$TEST_OUT"
