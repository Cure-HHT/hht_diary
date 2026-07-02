#!/usr/bin/env bash
set -euo pipefail
unset CLOUDSDK_CORE_PROJECT  # prevent auth step env override

PROJECT_ID="${GCP_PROJECT_ID:-cure-hht-qa}"
FLAVOR="${FLAVOR:-qa}"
TIMEOUT="${TEST_TIMEOUT:-15m}"
XCTEST_ZIP="${XCTEST_ZIP:?XCTEST_ZIP is required}"
RESULTS_DIR="${RESULTS_DIR:?RESULTS_DIR is required}"
EVIDENCE_DIR="${EVIDENCE_DIR:-build/firebase-test-lab/ios/evidence}"
DEVICE_SPECS="${IOS_DEVICES:-}"
XCODE_VERSION="${IOS_XCODE_VERSION:-}"
RESULTS_BUCKET="${FIREBASE_RESULTS_BUCKET:-}"

mkdir -p "$EVIDENCE_DIR"
[[ -f "$XCTEST_ZIP" ]] || { echo "ERROR: XCTest ZIP not found: $XCTEST_ZIP" >&2; exit 1; }

gcloud config set project "$PROJECT_ID"
ACTIVE_PROJECT="$(gcloud config get-value project 2>/dev/null)"
if [[ "$ACTIVE_PROJECT" != "$PROJECT_ID" ]]; then
  echo "ERROR: active gcloud project '$ACTIVE_PROJECT' does not match '$PROJECT_ID'" >&2
  exit 1
fi

# Implements: DIARY-OPS-automated-test-execution/B
cmd=(
  gcloud firebase test ios run
  --project="$PROJECT_ID"
  --type=xctest
  --test="$XCTEST_ZIP"
  --timeout="$TIMEOUT"
  --results-dir="$RESULTS_DIR"
)

if [[ -n "$RESULTS_BUCKET" ]]; then
  RESULTS_BUCKET="${RESULTS_BUCKET#gs://}"
  cmd+=(--results-bucket="$RESULTS_BUCKET")
fi
if [[ -n "$XCODE_VERSION" ]]; then
  cmd+=(--xcode-version="$XCODE_VERSION")
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
  "platform": "ios",
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
