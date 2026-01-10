#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-o00056: Container infrastructure for Cloud Run
#
# Startup script for Sponsor Portal container
# Runs Dart API server and nginx together

set -e

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

# Start Dart server in background
echo "Starting Dart API server on port $PORT..."
/app/server &
DART_PID=$!

# Wait for Dart server to be ready
echo "Waiting for Dart server..."
for i in $(seq 1 30); do
    if curl -sf http://127.0.0.1:$PORT/health > /dev/null 2>&1; then
        echo "Dart server is ready!"
        break
    fi
    if ! kill -0 "$DART_PID" 2>/dev/null; then
        echo "Dart server failed to start!"
        exit 1
    fi
    sleep 1
done

# Check if Dart server started successfully
if ! curl -sf http://127.0.0.1:$PORT/health > /dev/null 2>&1; then
    echo "Dart server failed to respond to health check!"
    exit 1
fi

# Start nginx in foreground (receives external traffic on port 8080)
echo "Starting nginx on port 8080..."
exec nginx -g 'daemon off;'
