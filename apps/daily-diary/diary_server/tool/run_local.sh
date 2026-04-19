#!/usr/bin/env bash
# Local diary server startup.
# Run with: doppler run -- ./tool/run_local.sh
# Doppler provides LOCAL_DB_PASSWORD for app_user.
#
# Options:
#   --no-otel   Disable OpenTelemetry (LGTM stack not started, traces disabled)
#
# By default, OTel is enabled and exports to the local LGTM stack.
# Start the LGTM stack first:
#   cd tools/dev-env && docker compose -f docker-compose.otel.yml up -d
# Or use the otel_common demo:
#   apps/common-dart/otel_common/tool/local_otel_demo.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# OTel is on by default; --no-otel disables it
ENABLE_OTEL=true
for arg in "$@"; do
    case $arg in
        --no-otel) ENABLE_OTEL=false; shift ;;
    esac
done

# Start LGTM stack if OTel is enabled
if [ "$ENABLE_OTEL" = true ]; then
    COMPOSE_FILE="$PROJECT_ROOT/tools/dev-env/docker-compose.otel.yml"
    if [ -f "$COMPOSE_FILE" ]; then
        if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'otel-lgtm'; then
            echo "[OTEL] Starting Grafana LGTM stack..."
            docker compose -f "$COMPOSE_FILE" up -d 2>/dev/null || echo "[OTEL] WARNING: Could not start LGTM stack"
        else
            echo "[OTEL] Grafana LGTM stack already running"
        fi
        echo "[OTEL] Grafana UI: http://localhost:3000/explore"
    fi
    export OTEL_EXPORTER_OTLP_PROTOCOL="grpc"
    export ENVIRONMENT="development"
fi

# Extract component versions for local dev
DIARY_SERVER_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
DIARY_FUNCTIONS_VERSION=$(grep '^version:' ../diary_functions/pubspec.yaml | sed 's/version: //')
TRIAL_DATA_TYPES_VERSION=$(grep '^version:' ../../common-dart/trial_data_types/pubspec.yaml | sed 's/version: //')

DB_HOST=localhost \
DB_PORT=5432 \
DB_NAME=sponsor_portal \
DB_USER=app_user \
DB_PASSWORD="${LOCAL_DB_PASSWORD:?Set LOCAL_DB_PASSWORD in Doppler}" \
DB_SSL=false \
JWT_SECRET=test-secret-for-local-dev \
PORT=8080 \
dart run \
  -DDIARY_SERVER_VERSION="$DIARY_SERVER_VERSION" \
  -DDIARY_FUNCTIONS_VERSION="$DIARY_FUNCTIONS_VERSION" \
  -DTRIAL_DATA_TYPES_VERSION="$TRIAL_DATA_TYPES_VERSION" \
  bin/server.dart
