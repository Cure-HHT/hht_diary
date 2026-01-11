#!/usr/bin/env bash
# =====================================================
# Unified Local Development Runner for Sponsor Portal
# =====================================================
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00027: Containerized Development Environments
#   REQ-d00031: Identity Platform Integration (local development)
#
# This script starts all services needed for local development:
#   - PostgreSQL database
#   - Firebase Auth Emulator
#   - Portal Server (Dart)
#   - Portal UI (Flutter Web) - optional
#
# Usage:
#   ./tool/run_local.sh              # Start everything with Doppler
#   ./tool/run_local.sh --reset      # Reset database before starting
#   ./tool/run_local.sh --no-ui      # Don't start Flutter web client
#   ./tool/run_local.sh --help       # Show help
#
# Default dev password for all seeded users: "curehht"
# =====================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SPONSOR_PORTAL_DIR="$SCRIPT_DIR/.."
DEV_ENV_DIR="$PROJECT_ROOT/tools/dev-env"
DATABASE_DIR="$PROJECT_ROOT/database"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FIREBASE_HOST="localhost"
FIREBASE_PORT="9099"
FIREBASE_EMULATOR_URL="http://${FIREBASE_HOST}:${FIREBASE_PORT}"
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="sponsor_portal"
DEV_PASSWORD="curehht"  # Default password for all dev users

# Parse arguments
RESET_DB=false
START_UI=true
SHOW_HELP=false

for arg in "$@"; do
    case $arg in
        --reset)
            RESET_DB=true
            shift
            ;;
        --no-ui)
            START_UI=false
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    echo "Unified Local Development Runner for Sponsor Portal"
    echo ""
    echo "Usage: ./tool/run_local.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --reset     Reset database (drop all tables, reapply schema + seed data)"
    echo "  --no-ui     Don't start Flutter web client"
    echo "  --help, -h  Show this help message"
    echo ""
    echo "Services started:"
    echo "  - PostgreSQL:       localhost:5432"
    echo "  - Firebase Emulator: localhost:9099 (UI at localhost:4000)"
    echo "  - Portal Server:    localhost:8080"
    echo "  - Portal UI:        localhost:PORT (Flutter assigns port)"
    echo ""
    echo "Dev credentials:"
    echo "  Email:    mike.bushe@anspar.org (or other seeded dev admins)"
    echo "  Password: curehht"
    echo ""
    echo "Flavors:"
    echo "  local  - Uses Firebase Emulator (this script)"
    echo "  dev    - Development environment (requires Firebase credentials)"
    echo "  qa     - QA/Testing environment (requires Firebase credentials)"
    echo "  uat    - User Acceptance Testing (requires Firebase credentials)"
    echo "  prod   - Production (requires Firebase credentials)"
    echo ""
    echo "For non-local flavors, pass Firebase credentials via --dart-define:"
    echo "  flutter run -d chrome --dart-define=APP_FLAVOR=dev \\"
    echo "    --dart-define=PORTAL_DEV_FIREBASE_API_KEY=your-api-key \\"
    echo "    --dart-define=PORTAL_DEV_FIREBASE_APP_ID=your-app-id \\"
    echo "    --dart-define=PORTAL_DEV_FIREBASE_PROJECT_ID=your-project-id \\"
    echo "    --dart-define=PORTAL_DEV_FIREBASE_AUTH_DOMAIN=your-auth-domain"
    exit 0
fi

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if a port is in use
port_in_use() {
    lsof -i ":$1" >/dev/null 2>&1
}

# Wait for a service to be ready
wait_for_port() {
    local host=$1
    local port=$2
    local service=$3
    local max_attempts=30
    local attempt=0

    log_info "Waiting for $service at $host:$port..."
    while ! nc -z "$host" "$port" 2>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            log_error "$service not ready after $max_attempts attempts"
            return 1
        fi
        sleep 1
    done
    log_success "$service is ready"
}

# Create Firebase Auth user via emulator REST API
create_firebase_user() {
    local email=$1
    local password=$2

    # Check if user already exists by trying to sign in
    local signin_response=$(curl -s -X POST \
        "${FIREBASE_EMULATOR_URL}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${email}\",\"password\":\"${password}\",\"returnSecureToken\":true}")

    if echo "$signin_response" | grep -q "idToken"; then
        log_info "  Firebase user $email already exists"
        return 0
    fi

    # Create user
    local response=$(curl -s -X POST \
        "${FIREBASE_EMULATOR_URL}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${email}\",\"password\":\"${password}\",\"returnSecureToken\":true}")

    if echo "$response" | grep -q "idToken"; then
        log_success "  Created Firebase user: $email"
    else
        log_warn "  Could not create Firebase user $email: $response"
    fi
}

# Clear all Firebase emulator accounts
clear_firebase_users() {
    log_info "Clearing Firebase Auth emulator accounts..."

    local response=$(curl -s -X DELETE \
        "${FIREBASE_EMULATOR_URL}/emulator/v1/projects/demo-sponsor-portal/accounts")

    if echo "$response" | grep -q "error"; then
        log_warn "Could not clear Firebase accounts: $response"
    else
        log_success "Firebase accounts cleared"
    fi
}

# Create all seeded dev admin users in Firebase
create_firebase_users() {
    log_info "Creating Firebase Auth users for dev admins..."

    # Anspar team - these match the seed data in both curehht and callisto repos
    create_firebase_user "mike.bushe@anspar.org" "$DEV_PASSWORD"
    create_firebase_user "michael@anspar.org" "$DEV_PASSWORD"
    create_firebase_user "tom@anspar.org" "$DEV_PASSWORD"
    create_firebase_user "urayoan@anspar.org" "$DEV_PASSWORD"
    create_firebase_user "elvira@anspar.org" "$DEV_PASSWORD"

    log_success "Firebase users created"
}

# Reset the database
reset_database() {
    log_info "Resetting database..."

    # Get password from Doppler
    local db_password=$(doppler secrets get LOCAL_DB_ROOT_PASSWORD --plain 2>/dev/null)
    if [ -z "$db_password" ]; then
        log_error "Could not get LOCAL_DB_ROOT_PASSWORD from Doppler"
        return 1
    fi

    # Drop and recreate the database
    PGPASSWORD="$db_password" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
    PGPASSWORD="$db_password" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null

    # Run schema initialization
    log_info "Applying database schema..."
    cd "$DATABASE_DIR"
    PGPASSWORD="$db_password" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" -f init.sql

    # Apply sponsor-specific seed data
    # Try curehht first, then callisto (depending on which repo is available)
    local seed_applied=false

    if [ -f "$PROJECT_ROOT/../hht_diary_curehht/database/seed_data_dev.sql" ]; then
        log_info "Applying CureHHT seed data..."
        PGPASSWORD="$db_password" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" \
            -f "$PROJECT_ROOT/../hht_diary_curehht/database/seed_data_dev.sql"
        seed_applied=true
    fi

    if [ -f "$PROJECT_ROOT/../hht_diary_callisto/database/seed_data_dev.sql" ] && [ "$seed_applied" = false ]; then
        log_info "Applying Callisto seed data..."
        PGPASSWORD="$db_password" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" \
            -f "$PROJECT_ROOT/../hht_diary_callisto/database/seed_data_dev.sql"
        seed_applied=true
    fi

    # Fallback to core seed data if no sponsor-specific seed found
    if [ "$seed_applied" = false ] && [ -f "$DATABASE_DIR/seed_data.sql" ]; then
        log_info "Applying core seed data..."
        PGPASSWORD="$db_password" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" \
            -f "$DATABASE_DIR/seed_data.sql"
    fi

    log_success "Database reset complete"
}

# Start PostgreSQL via docker-compose
start_postgres() {
    log_info "Starting PostgreSQL..."

    cd "$DEV_ENV_DIR"

    # Check if already running
    if docker ps --format '{{.Names}}' | grep -q 'sponsor-portal-postgres'; then
        log_info "PostgreSQL already running"
    else
        doppler run -- docker compose -f docker-compose.db.yml up -d
    fi

    wait_for_port "$DB_HOST" "$DB_PORT" "PostgreSQL"
}

# Start Firebase Emulator via docker-compose
start_firebase() {
    log_info "Starting Firebase Auth Emulator..."

    cd "$DEV_ENV_DIR"

    # Create network if it doesn't exist
    docker network create clinical-diary-net 2>/dev/null || true

    # Check if already running
    if docker ps --format '{{.Names}}' | grep -q 'firebase-emulator'; then
        log_info "Firebase Emulator already running"
    else
        docker compose -f docker-compose.firebase.yml up -d
    fi

    wait_for_port "$FIREBASE_HOST" "$FIREBASE_PORT" "Firebase Emulator"
}

# Start the portal server
start_server() {
    log_info "Starting Portal Server on port 8080..."

    cd "$SPONSOR_PORTAL_DIR/portal_server"

    # Export environment variables
    export FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_HOST}:${FIREBASE_PORT}"
    export GCP_PROJECT_ID="demo-sponsor-portal"
    export DB_SSL="false"
    export PORT="8080"
    export DB_HOST="$DB_HOST"
    export DB_PORT="$DB_PORT"
    export DB_NAME="$DB_NAME"
    export DB_USER="postgres"

    # Start in background
    doppler run --command 'DB_PASSWORD=$LOCAL_DB_ROOT_PASSWORD dart run bin/server.dart' &
    SERVER_PID=$!

    wait_for_port "localhost" "8080" "Portal Server"
}

# Start the Flutter web UI
start_ui() {
    log_info "Starting Portal UI (Flutter Web) with local flavor..."

    cd "$SPONSOR_PORTAL_DIR/portal-ui"

    # Start Flutter in background with local flavor
    # APP_FLAVOR=local enables Firebase emulator connection
    flutter run -d chrome \
        --dart-define=APP_FLAVOR=local \
        --dart-define=FIREBASE_AUTH_EMULATOR_HOST=${FIREBASE_HOST}:${FIREBASE_PORT} &
    UI_PID=$!
}

# Cleanup function
cleanup() {
    log_info "Shutting down services..."

    # Kill server if we started it
    if [ -n "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null || true
    fi

    # Kill UI if we started it
    if [ -n "$UI_PID" ]; then
        kill $UI_PID 2>/dev/null || true
    fi

    log_info "Services stopped. Docker containers (postgres, firebase) left running."
    log_info "To stop all containers: cd tools/dev-env && docker compose -f docker-compose.db.yml -f docker-compose.firebase.yml down"
}

# Main
main() {
    echo ""
    echo "=========================================="
    echo "  Sponsor Portal Local Development"
    echo "=========================================="
    echo ""

    # Set up cleanup trap
    trap cleanup EXIT

    # Start services
    start_postgres
    start_firebase

    # Reset database and Firebase users if requested
    if [ "$RESET_DB" = true ]; then
        reset_database
        clear_firebase_users
    fi

    # Create Firebase users (creates if missing, skips if exists)
    create_firebase_users

    # Start portal server
    start_server

    echo ""
    log_success "All services started!"
    echo ""
    echo "=========================================="
    echo "  Access Points:"
    echo "=========================================="
    echo "  Portal Server:      http://localhost:8080"
    echo "  Firebase Emulator:  http://localhost:4000"
    echo "  PostgreSQL:         localhost:5432"
    echo ""
    echo "  Dev Login:"
    echo "    Email:    mike.bushe@anspar.org"
    echo "    Password: curehht"
    echo "=========================================="
    echo ""

    # Start UI if requested
    if [ "$START_UI" = true ]; then
        start_ui

        # Wait for UI process
        wait $UI_PID 2>/dev/null || true
    else
        log_info "UI not started (use without --no-ui to start Flutter)"
        log_info "To start manually: cd portal-ui && flutter run -d chrome --dart-define=APP_FLAVOR=local"

        # Wait for server
        wait $SERVER_PID 2>/dev/null || true
    fi
}

main
