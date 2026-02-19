#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#   REQ-d00058: Secrets Management via Doppler
#   REQ-o00002: Environment-Specific Configuration Management
#
# Startup script for Sponsor Portal container
# Fetches DOPPLER_TOKEN from Google Cloud Secret Manager, then
# Runs Dart API server and nginx together

set -eo pipefail

# Re-exec with line-buffered stdout/stderr so Cloud Run captures all log output
if [ -z "$_UNBUFFERED" ]; then
    export _UNBUFFERED=1
    exec stdbuf -oL -eL "$0" "$@"
fi

# Dart server listens on internal port 8081
# nginx listens on external port 8080 and proxies to Dart
export PORT=8081

# Function to handle shutdown signals
cleanup() {
    echo "Shutting down..."
    # Kill the Dart server if running
    if [ -n "$DART_PID" ]; then
        kill -TERM "$DART_PID" 2>/dev/null || true
        wait "$DART_PID" 2>/dev/null || true
    fi
    # nginx will be terminated by the signal
    exit 0
}

# Trap shutdown signals
trap cleanup SIGTERM SIGINT SIGQUIT

echo "=========================================="
echo "Sponsor Portal Startup"
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

# Check if SPONSOR_ID is set
if [ -z "$SPONSOR_ID" ]; then
    echo "❌ ERROR: SPONSOR_ID variable is not set!"
    echo "Cloud Run service must have SPONSOR_ID configured (e.g., callisto)."
    exit 9
fi
echo "✅ SPONSOR_ID ${SPONSOR_ID} detected."

# Verify sponsor content exists in container
if [ ! -f "/app/sponsor-content/${SPONSOR_ID}/sponsor-config.json" ]; then
    echo "❌ ERROR: Sponsor content not found for '${SPONSOR_ID}'!"
    echo "Expected: /app/sponsor-content/${SPONSOR_ID}/sponsor-config.json"
    echo "Ensure collect-sponsor-content.sh was run before docker build."
    exit 10
fi
echo "✅ Sponsor content verified for ${SPONSOR_ID}."

# Check if DOPPLER_TOKEN is set
if [ -z "$DOPPLER_TOKEN" ]; then
    echo "❌ ERROR: DOPPLER_TOKEN environment variable is not set!"
    echo "Cloud Run service must have DOPPLER_TOKEN configured for this environment."
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
    echo "ERROR $?: Failed to fetch DOPPLER_TOKEN from Secret Manager!"
    echo "stderr: ${DOPPLER_TOKEN}"
    echo "Ensure the Cloud Run service account has secretmanager.versions.access permission."
    exit 3
fi
echo "DOPPLER_TOKEN fetched (length: ${#DOPPLER_TOKEN} chars)"

# Validate GCP_PROJECT_ID matches expected environment
GCP_PROJECT_ID=$(doppler secrets get GCP_PROJECT_ID --plain --project "${DOPPLER_PROJECT_ID}" --config "${DOPPLER_CONFIG_NAME}" 2>/dev/null)
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "❌ ERROR: GCP_PROJECT_ID secret not found in Doppler!"
    exit 4
fi

if [[ "$GCP_PROJECT_ID" != *"$DOPPLER_CONFIG_NAME" ]]; then
    echo "❌ ERROR: GCP_PROJECT_ID mismatch!"
    echo "  GCP_PROJECT_ID '$GCP_PROJECT_ID' does not end with DOPPLER_CONFIG_NAME '$DOPPLER_CONFIG_NAME'"
    echo "  This may indicate a misconfigured Doppler token for the wrong environment."
    exit 5
fi
echo "✅ GCP_PROJECT_ID '$GCP_PROJECT_ID' matches environment '$DOPPLER_CONFIG_NAME'"

echo "=========================================="
echo "Starting Dart API server with Doppler-injected secrets..."
echo "=========================================="

# Start server with Doppler injecting secrets
doppler run --project "${DOPPLER_PROJECT_ID}" --config "${DOPPLER_CONFIG_NAME}" -- /app/server &
DART_PID=$!

# Wait for Dart server to be ready
echo "Waiting for Dart server..."
for _ in $(seq 1 60); do
    if curl -sf http://127.0.0.1:$PORT/health > /dev/null 2>&1; then
        echo "Dart server is ready!"
        break
    fi
    if ! kill -0 "$DART_PID" 2>/dev/null; then
        echo "Dart server failed to start!"
        exit 7
    fi
    sleep 1
done

# Check if Dart server started successfully
if ! curl -sf http://127.0.0.1:$PORT/health > /dev/null 2>&1; then
    echo "Dart server failed to respond to health check!"
    exit 8
fi

# Start nginx in foreground (receives external traffic on port 8080)
echo "Starting nginx on port 8080..."
exec nginx -g 'daemon off;'
