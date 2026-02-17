#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#   REQ-d00058: Secrets Management via Doppler
#
# Test script for Cloud Run Job — validates that the service account
# can fetch DOPPLER_TOKEN from Google Cloud Secret Manager.
# Exit 0 = success, non-zero = failure (reported in Cloud Run Job logs).

set -eo pipefail

# Redirect stdout to stderr to avoid buffering — stderr is unbuffered by default.
# Cloud Run treats both streams identically in Cloud Logging.
# exec 1>&2

# Re-exec with line-buffered stdout/stderr so Cloud Run captures all log output
if [ -z "$_UNBUFFERED" ]; then
    export _UNBUFFERED=1
    exec stdbuf -oL -eL "$0" "$@"
fi

echo "=========================================="
echo "GCP Secret Manager Access Test"
echo "=========================================="

# Show identity for debugging
echo "Fetching active service account..."
IDENTITY=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || echo "unknown")
echo "Running as: ${IDENTITY}"

# Test: fetch DOPPLER_TOKEN from Secret Manager
echo ""
echo "Testing: gcloud secrets versions access latest --secret=DOPPLER_TOKEN"
echo "------------------------------------------"
DOPPLER_TOKEN="$(gcloud secrets versions access latest --secret=DOPPLER_TOKEN 2>&1)"
if [ $? -ne 0 ] || [ -z "$DOPPLER_TOKEN" ]; then
    echo "FAIL: Could not fetch DOPPLER_TOKEN from Secret Manager!"
    echo "stderr=$DOPPLER_TOKEN"
    echo "Ensure the Cloud Run service account has secretmanager.versions.access permission."
    exit 1
fi

echo "PASS: DOPPLER_TOKEN fetched successfully (length: ${#DOPPLER_TOKEN} chars)"
echo ""
echo "=========================================="
echo "All tests passed."
echo "=========================================="
