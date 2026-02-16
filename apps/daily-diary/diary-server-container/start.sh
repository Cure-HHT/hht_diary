#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#   REQ-d00058: Secrets Management via Doppler
#   REQ-o00002: Environment-Specific Configuration Management
#
# Startup script for Diary Server container
# Fetches DOPPLER_TOKEN from Google Cloud Secret Manager, then
# launches the Dart server with Doppler-injected secrets.

set -eo pipefail

# Re-exec with line-buffered stdout/stderr so Cloud Run captures all log output
if [ -z "$_UNBUFFERED" ]; then
    export _UNBUFFERED=1
    exec stdbuf -oL -eL "$0" "$@"
fi

echo "=========================================="
echo "Diary Server Startup"
echo "=========================================="

# Show identity for debugging
echo "Fetching active service account..."
IDENTITY=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || echo "unknown")
echo "Running as: ${IDENTITY}"

# Validate required environment variables
if [ -z "$DOPPLER_PROJECT_ID" ]; then
    echo "ERROR: DOPPLER_PROJECT_ID is not set!"
    exit 1
fi

if [ -z "$DOPPLER_CONFIG_NAME" ]; then
    echo "ERROR: DOPPLER_CONFIG_NAME is not set!"
    exit 2
fi

echo "Doppler Project: ${DOPPLER_PROJECT_ID}"
echo "Doppler Config:  ${DOPPLER_CONFIG_NAME}"

# Fetch DOPPLER_TOKEN from Google Cloud Secret Manager
echo "Fetching DOPPLER_TOKEN from Secret Manager..."
export DOPPLER_TOKEN
DOPPLER_TOKEN="$(gcloud secrets versions access latest --secret=DOPPLER_TOKEN 2>&1)"
if [ $? -ne 0 ] || [ -z "$DOPPLER_TOKEN" ]; then
    echo "ERROR: Failed to fetch DOPPLER_TOKEN from Secret Manager!"
    echo "Ensure the Cloud Run service account has secretmanager.versions.access permission."
    exit 3
fi
echo "DOPPLER_TOKEN fetched (length: ${#DOPPLER_TOKEN} chars)"

# Validate GCP_PROJECT_ID matches expected environment
GCP_PROJECT_ID=$(doppler secrets get GCP_PROJECT_ID --plain --project "${DOPPLER_PROJECT_ID}" --config "${DOPPLER_CONFIG_NAME}" 2>/dev/null)
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "ERROR: GCP_PROJECT_ID secret not found in Doppler!"
    exit 4
fi

if [[ "$GCP_PROJECT_ID" != *"$DOPPLER_CONFIG_NAME" ]]; then
    echo "ERROR: GCP_PROJECT_ID mismatch!"
    echo "  GCP_PROJECT_ID '$GCP_PROJECT_ID' does not end with DOPPLER_CONFIG_NAME '$DOPPLER_CONFIG_NAME'"
    echo "  This may indicate a misconfigured Doppler token for the wrong environment."
    exit 5
fi
echo "GCP_PROJECT_ID '$GCP_PROJECT_ID' matches environment '$DOPPLER_CONFIG_NAME'"

echo "=========================================="
echo "Starting Dart server with Doppler-injected secrets..."
echo "=========================================="

# Use exec so doppler becomes PID 1 and receives signals properly
exec doppler run --project "${DOPPLER_PROJECT_ID}" --config "${DOPPLER_CONFIG_NAME}" -- /app/server
