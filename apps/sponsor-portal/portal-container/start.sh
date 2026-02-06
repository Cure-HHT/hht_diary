#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#
# Startup script for Sponsor Portal container
# Runs Dart API server and nginx together

set -eo pipefail

# Dart server listens on internal port 8081
# nginx listens on external port 8080 and proxies to Dart
export PORT=8081

echo "Starting Sponsor Portal..."

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
echo "Environment: ${ENVIRONMENT:-not-set}"
echo "Port: $PORT"

# Check if ENVIRONMENT is set
if [ -z "$ENVIRONMENT" ]; then
    echo "❌ ERROR: ENVIRONMENT variable is not set!"
    echo "Cloud Run service must have ENVIRONMENT configured (e.g., dev, staging, prod)."
    exit 1
fi
echo "✅ ENVIRONMENT ${ENVIRONMENT} detected."

# Check if DOPPLER_TOKEN is set
if [ -z "$DOPPLER_TOKEN" ]; then
    echo "❌ ERROR: DOPPLER_TOKEN environment variable is not set!"
    echo "Cloud Run service must have DOPPLER_TOKEN configured for this environment."
    exit 2
fi

echo "✅ DOPPLER_TOKEN detected (length: ${#DOPPLER_TOKEN} chars)"

# Verify Doppler CLI is available
if ! command -v doppler &> /dev/null; then
    echo "❌ ERROR: Doppler CLI not found in PATH!"
    exit 3
fi

echo "✅ Doppler CLI version: $(doppler --version)"

# Fetch and display Doppler configuration info (without exposing secrets)
echo "Fetching Doppler configuration info..."
export DOPPLER_PROJECT="hht-diary"
export DOPPLER_CONFIG="${ENVIRONMENT}"
echo "  Project: ${DOPPLER_PROJECT}"
echo "  Config: ${DOPPLER_CONFIG}"

# Test Doppler connection by listing secret names (not values)
echo "Testing Doppler connection..."
if ! doppler secrets --only-names 2>&1 | head -5; then
    echo "❌ ERROR: Failed to connect to Doppler!"
    echo "Check that DOPPLER_TOKEN is valid for the target environment."
    exit 4
fi

echo "✅ Doppler connection successful"

# Validate GCP_PROJECT_ID matches expected environment
GCP_PROJECT_ID=$(doppler secrets get GCP_PROJECT_ID --plain 2>/dev/null)
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "❌ ERROR: GCP_PROJECT_ID secret not found in Doppler!"
    exit 5
fi

if [[ "$GCP_PROJECT_ID" != *"$ENVIRONMENT" ]]; then
    echo "❌ ERROR: GCP_PROJECT_ID mismatch!"
    echo "  GCP_PROJECT_ID '$GCP_PROJECT_ID' does not end with ENVIRONMENT '$ENVIRONMENT'"
    echo "  This may indicate a misconfigured Doppler token for the wrong environment."
    exit 6
fi
echo "✅ GCP_PROJECT_ID '$GCP_PROJECT_ID' matches environment '$ENVIRONMENT'"

echo "=========================================="
echo "Starting Dart API server with Doppler-injected secrets..."
echo "=========================================="

# Start server with Doppler injecting secrets
doppler run -- /app/server &
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
