#!/usr/bin/env bash
# Run portal server locally with Firebase emulator support
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00027: Containerized Development Environments
#
# Usage:
#   ./tool/run_local.sh              # Uses Doppler for DB secrets
#   ./tool/run_local.sh --reset      # Reset database, apply seed data, then run
#   ./tool/run_local.sh --no-doppler # Uses hardcoded dev values (no secrets needed)
#
# Prerequisites:
#   - PostgreSQL running (docker compose -f docker-compose.db.yml up -d)
#   - Firebase emulator running (docker compose -f docker-compose.firebase.yml up -d)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
cd "$SCRIPT_DIR/.."

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color
echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Handle --reset flag
if [[ "$1" == "--reset" ]]; then
    echo_info "Resetting database and applying seed data..."

    # Run the reset script
    "$REPO_ROOT/apps/sponsor-portal/tool/reset_local_db.sh" --force

    # Apply local dev seed data
    echo_info "Applying local dev seed data..."
    docker exec -i sponsor-portal-postgres psql -U postgres -d sponsor_portal < "$REPO_ROOT/database/seed_local_dev.sql"

    echo_info "Database reset complete. Starting server..."
    shift  # Remove --reset from args
fi

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
