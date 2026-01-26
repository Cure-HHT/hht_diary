#!/usr/bin/env bash
# =====================================================
# Local Development Runner for Portal UI
# =====================================================
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00028: Portal Frontend Framework
#   REQ-d00031: Identity Platform Integration (local development)
#
# Runs the Flutter web UI with local flavor settings.
# Uses Doppler internally for any required secrets.
#
# Usage:
#   ./tool/run_local.sh              # Run in Chrome (default)
#   ./tool/run_local.sh --device web-server  # Run as web server
#   ./tool/run_local.sh -d edge      # Run in Edge browser
#
# Prerequisites:
#   - Portal server running (../portal_server or ../tool/run_local.sh)
#   - Firebase emulator running (localhost:9099)
#
# =====================================================

# Re-execute under Doppler if not already running with it.
# This makes all Doppler secrets available as environment variables.
if [ -z "$DOPPLER_ENVIRONMENT" ]; then
    exec doppler run -- "$0" "$@"
fi

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Configuration
FIREBASE_HOST="${FIREBASE_HOST:-localhost}"
FIREBASE_PORT="${FIREBASE_PORT:-9099}"
PORTAL_API_URL="${PORTAL_API_URL:-http://localhost:8080}"

# Default device
DEVICE="chrome"

# Parse arguments - pass through to flutter
FLUTTER_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Portal UI Local Development Runner"
            echo ""
            echo "Usage: ./tool/run_local.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -d, --device DEVICE  Target device (default: chrome)"
            echo "                       Examples: chrome, edge, web-server"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "All other arguments are passed to 'flutter run'."
            echo ""
            echo "Environment (via Doppler or defaults):"
            echo "  FIREBASE_HOST:  $FIREBASE_HOST"
            echo "  FIREBASE_PORT:  $FIREBASE_PORT"
            echo "  PORTAL_API_URL: $PORTAL_API_URL"
            echo ""
            echo "Prerequisites:"
            echo "  1. Start database and Firebase emulator:"
            echo "     cd tools/dev-env && doppler run -- docker compose -f docker-compose.db.yml up -d"
            echo "     docker compose -f docker-compose.firebase.yml up -d"
            echo ""
            echo "  2. Start portal server:"
            echo "     cd apps/sponsor-portal/portal_server && doppler run -- dart run bin/server.dart"
            echo ""
            echo "  3. Run this script:"
            echo "     ./tool/run_local.sh"
            exit 0
            ;;
        *)
            FLUTTER_ARGS+=("$1")
            shift
            ;;
    esac
done

echo "=========================================="
echo "  Portal UI - Local Development"
echo "=========================================="
echo ""
echo "  Firebase Emulator: ${FIREBASE_HOST}:${FIREBASE_PORT}"
echo "  Portal API:        ${PORTAL_API_URL}"
echo "  Device:            ${DEVICE}"
echo ""
echo "=========================================="
echo ""

# Ensure dependencies are up to date
echo "Checking dependencies..."
flutter pub get

echo ""
echo "Starting Flutter..."
echo ""

# Extract version from pubspec.yaml
APP_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //;s/+.*//')

# Run Flutter with local flavor
# APP_FLAVOR=local enables Firebase emulator connection
flutter run -d "$DEVICE" \
    --dart-define=APP_FLAVOR=local \
    --dart-define=APP_VERSION="$APP_VERSION" \
    --dart-define=PORTAL_API_URL="$PORTAL_API_URL" \
    --dart-define=FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_HOST}:${FIREBASE_PORT}" \
    "${FLUTTER_ARGS[@]}"
