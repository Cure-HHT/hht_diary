#!/usr/bin/env bash
# IMPLEMENTS REQUIREMENTS:
# REQ-o00043: Automated Deployment Pipeline
set -euo pipefail
unset CLOUDSDK_CORE_PROJECT # prevent auth step env override

PROJECT_ID="${GCP_PROJECT_ID:-cure-hht-qa}"
FLAVOR="${FLAVOR:-qa}"
TIMEOUT="${TEST_TIMEOUT:-15m}"
APP_APK="${APP_APK:?APP_APK is required}"
TEST_APK="${TEST_APK:?TEST_APK is required}"
RESULTS_DIR="${RESULTS_DIR:?RESULTS_DIR is required}"
EVIDENCE_DIR="${EVIDENCE_DIR:-build/firebase-test-lab/android/evidence}"
# Default device matrix (validated 2026-06-25; incompatible combos removed).
# Removed: r0q/33, g0q/31, redfin/31, redfin/28 (FTL skipped these in run #35).
# One spec per line: model=<id>,version=<api>,locale=en,orientation=portrait
# Override at runtime via the android_devices workflow_dispatch input.
DEFAULT_DEVICE_SPECS=$(printf '%s\n' \
'model=shiba,version=34,locale=en,orientation=portrait' \
'model=cheetah,version=33,locale=en,orientation=portrait' \
'model=redfin,version=30,locale=en,orientation=portrait' \
'model=MediumPhone.arm,version=32,locale=en,orientation=portrait' \
'model=MediumPhone.arm,version=31,locale=en,orientation=portrait' \
'model=MediumPhone.arm,version=30,locale=en,orientation=portrait' \
'model=MediumPhone.arm,version=33,locale=en,orientation=portrait' \
'model=MediumPhone.arm,version=28,locale=en,orientation=portrait' \
)
DEVICE_SPECS="${ANDROID_DEVICES:-${DEFAULT_DEVICE_SPECS}}"
USE_ORCHESTRATOR="${USE_ORCHESTRATOR:-false}"
RESULTS_BUCKET="${FIREBASE_RESULTS_BUCKET:-}"

# Directory on the device where the AndroidX Test Storage Service writes
# per-test screenshots. It is pulled into the Test Lab results tree so the
# snapshots land in the evidence artifact alongside the recorded video.
SCREENSHOT_DIR="/sdcard/Android/data/com.google.android.apps.common.testing.services/files/test_data/screenshots"

mkdir -p "$EVIDENCE_DIR"

[[ -f "$APP_APK" ]] || { echo "ERROR: app APK not found: $APP_APK" >&2; exit 1; }
[[ -f "$TEST_APK" ]] || { echo "ERROR: test APK not found: $TEST_APK" >&2; exit 1; }

ACTIVE_PROJECT="$(gcloud config get-value project 2>/dev/null)"
if [[ "$ACTIVE_PROJECT" != "$PROJECT_ID" ]]; then
  echo "ERROR: active gcloud project '$ACTIVE_PROJECT' does not match '$PROJECT_ID'" >&2
  exit 1
fi

cmd=(
  gcloud firebase test android run
  --project="$PROJECT_ID"
  --type=instrumentation
  --app="$APP_APK"
  --test="$TEST_APK"
  --timeout="$TIMEOUT"
  --results-dir="$RESULTS_DIR"
  --client-details="matrixLabel=hht-${FLAVOR}-${GITHUB_RUN_ID:-local}-${GITHUB_SHA:-unknown}"
  # Video evidence (recorded by default; kept explicit for clarity).
  --record-video
  # Snapshot evidence: enable the AndroidX Test Storage Service so the
  # instrumentation runner captures per-test screenshots, and pull the
  # screenshot directory back into the Test Lab results tree.
  --environment-variables=clearPackageData=true,useTestStorageService=true
  --directories-to-pull="$SCREENSHOT_DIR"
)

if [[ -n "$RESULTS_BUCKET" ]]; then
  RESULTS_BUCKET="${RESULTS_BUCKET#gs://}"
  cmd+=(--results-bucket="$RESULTS_BUCKET")
fi

if [[ "$USE_ORCHESTRATOR" == "true" ]]; then
  cmd+=(--use-orchestrator)
else
  cmd+=(--no-use-orchestrator)
fi

while IFS= read -r spec; do
  spec="${spec%$'\r'}"
  [[ -z "${spec//[[:space:]]/}" ]] && continue
  cmd+=(--device="$spec")
done <<< "$DEVICE_SPECS"

printf '%q ' "${cmd[@]}" > "$EVIDENCE_DIR/command.txt"
printf '\n' >> "$EVIDENCE_DIR/command.txt"

set +e
"${cmd[@]}" 2>&1 | tee "$EVIDENCE_DIR/gcloud-output.log"
status=${PIPESTATUS[0]}
set -e

printf '%s\n' "$status" > "$EVIDENCE_DIR/exit-code.txt"

# When a dedicated bucket is configured, copy the complete Firebase result tree
# (JUnit, logs, screenshots, videos, and performance files when present) into
# the GitHub evidence artifact. A copy failure must not hide the matrix result.
if [[ -n "$RESULTS_BUCKET" ]]; then
  BUCKET_NAME="${RESULTS_BUCKET#gs://}"
  mkdir -p "$EVIDENCE_DIR/raw-results"
  set +e
  gcloud storage cp --recursive \
    "gs://${BUCKET_NAME}/${RESULTS_DIR}" \
    "$EVIDENCE_DIR/raw-results/" \
    > "$EVIDENCE_DIR/result-download.log" 2>&1
  download_status=$?
  set -e
  if [[ $download_status -ne 0 ]]; then
    echo "WARN: Firebase result download failed; results remain in Cloud Storage/Test Lab." \
      | tee -a "$EVIDENCE_DIR/result-download.log"
  fi
fi

cat > "$EVIDENCE_DIR/execution-summary.json" <<JSON
{
  "platform": "android",
  "project": "$PROJECT_ID",
  "flavor": "$FLAVOR",
  "resultsDir": "$RESULTS_DIR",
  "timeout": "$TIMEOUT",
  "exitCode": $status,
  "gitSha": "${GITHUB_SHA:-unknown}",
  "runId": "${GITHUB_RUN_ID:-local}"
}
JSON

exit "$status"
