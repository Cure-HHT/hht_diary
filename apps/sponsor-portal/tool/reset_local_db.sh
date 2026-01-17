#!/usr/bin/env bash
# Reset the local PostgreSQL database for sponsor-portal development
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00027: Containerized Development Environments
#
# Usage:
#   ./tool/reset_db.sh           # Reset database (destroys all data)
#   ./tool/reset_db.sh --force   # Skip confirmation prompt
#
# This script:
#   1. Stops the PostgreSQL container
#   2. Removes the postgres-data volume (destroys all data)
#   3. Restarts the container (triggers schema init from database/init.sql)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DEV_ENV_DIR="$REPO_ROOT/tools/dev-env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if docker is running
if ! docker info &>/dev/null; then
    echo_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Confirmation unless --force
if [[ "$1" != "--force" ]]; then
    echo_warn "This will DESTROY all data in the local sponsor_portal database!"
    echo ""
    read -p "Are you sure you want to continue? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Aborted."
        exit 0
    fi
fi

cd "$DEV_ENV_DIR"

echo_info "Stopping PostgreSQL container..."
doppler run -- docker compose -f docker-compose.db.yml down 2>/dev/null || true

echo_info "Removing postgres-data volume..."
docker volume rm dev-env_postgres-data 2>/dev/null || docker volume rm tools_dev-env_postgres-data 2>/dev/null || true

echo_info "Starting PostgreSQL container (this will run schema init)..."
doppler run -- docker compose -f docker-compose.db.yml up -d

echo_info "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker exec sponsor-portal-postgres pg_isready -U postgres -d sponsor_portal &>/dev/null; then
        echo_info "PostgreSQL is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo_error "Timed out waiting for PostgreSQL"
        exit 1
    fi
    sleep 1
done

# Wait a bit more for init scripts to complete
sleep 3

echo_info "Verifying database schema..."
TABLE_COUNT=$(docker exec sponsor-portal-postgres psql -U postgres -d sponsor_portal -tAc "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public'" 2>/dev/null || echo "0")

if [ "$TABLE_COUNT" -gt 10 ]; then
    echo_info "Database reset complete! Found $TABLE_COUNT tables."
else
    echo_warn "Database may not have initialized correctly. Found only $TABLE_COUNT tables."
    echo_warn "Check logs with: docker logs sponsor-portal-postgres"
fi

echo ""
echo_info "You can now run the portal server:"
echo "  cd apps/sponsor-portal/portal_server"
echo "  ./tool/run_local.sh"
