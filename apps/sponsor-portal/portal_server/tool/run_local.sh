#!/usr/bin/env bash
# Run portal server locally with Firebase emulator support
#
# Usage:
#   ./tool/run_local.sh              # Uses Doppler for DB secrets
#   ./tool/run_local.sh --no-doppler # Uses hardcoded dev values (no secrets needed)
#
# Prerequisites:
#   - PostgreSQL running (docker compose -f docker-compose.db.yml up -d)
#   - Firebase emulator running (docker compose -f docker-compose.firebase.yml up -d)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Local development config (not secrets)
export FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_AUTH_EMULATOR_HOST:-localhost:9099}"
export GCP_PROJECT_ID="${GCP_PROJECT_ID:-demo-sponsor-portal}"
export DB_SSL="${DB_SSL:-false}"
export PORT="${PORT:-8080}"

# Database config - use postgres superuser for local dev
# Doppler provides LOCAL_DB_ROOT_PASSWORD for the postgres user
export DB_HOST="${DB_HOST:-localhost}"
export DB_PORT="${DB_PORT:-5432}"
export DB_NAME="${DB_NAME:-sponsor_portal}"
export DB_USER="${DB_USER:-postgres}"

if [[ "$1" == "--no-doppler" ]]; then
  # Standalone mode - hardcoded dev values (for quick testing)
  echo "Running without Doppler (using hardcoded dev values)..."
  export DB_PASSWORD="${DB_PASSWORD:-devpassword}"

  dart run bin/server.dart
else
  # Normal mode - use Doppler for DB password
  echo "Running with Doppler..."
  echo "Firebase Auth Emulator: $FIREBASE_AUTH_EMULATOR_HOST"
  echo "Database: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"

  # Map Doppler's LOCAL_DB_ROOT_PASSWORD to DB_PASSWORD
  doppler run --command 'DB_PASSWORD=$LOCAL_DB_ROOT_PASSWORD dart run bin/server.dart'
fi
