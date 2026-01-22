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
#   ./tool/run_local.sh              # Start everything (uses Doppler internally)
#   ./tool/run_local.sh --reset      # Reset database before starting
#   ./tool/run_local.sh --no-ui      # Don't start Flutter web client
#   ./tool/run_local.sh --dev        # Use GCP Identity Platform instead of Firebase emulator
#   ./tool/run_local.sh --offline    # Run without Doppler (uses local password)
#   ./tool/run_local.sh --help       # Show help
#
# OFFLINE MODE (for airplane/disconnected development):
#   ./tool/run_local.sh --offline --reset
#
#   In offline mode:
#   - Doppler is bypassed
#   - Database password defaults to 'postgres' (local Docker)
#   - No external API calls required
#
# Default dev password for all seeded users: "curehht"
# =====================================================

# Check for offline mode BEFORE Doppler re-exec
OFFLINE_MODE=false
for arg in "$@"; do
    if [ "$arg" = "--offline" ]; then
        OFFLINE_MODE=true
        break
    fi
done

# Re-execute under Doppler if not already running with it (unless offline mode)
if [ "$OFFLINE_MODE" = false ] && [ -z "$DOPPLER_ENVIRONMENT" ]; then
    exec doppler run -- "$0" "$@"
fi

# In offline mode, source the dumped env file
if [ "$OFFLINE_MODE" = true ]; then
    SCRIPT_DIR_TEMP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ENV_FILE="$SCRIPT_DIR_TEMP/.env.offline"

    if [ -f "$ENV_FILE" ]; then
        echo "Loading offline secrets from $ENV_FILE"
        set -a  # Export all variables
        source "$ENV_FILE"
        set +a
    else
        echo ""
        echo "WARNING: Offline env file not found: $ENV_FILE"
        echo ""
        echo "To create it, run while online:"
        echo "  ./tool/doppler-dump.sh"
        echo ""
        echo "Continuing with fallback defaults (may not work)..."
        echo ""
    fi
fi

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

# Fallback password (only used if env file missing)
FALLBACK_DB_PASSWORD="postgres"

# Parse arguments
RESET_DB=false
START_UI=true
SHOW_HELP=false
USE_DEV_IDENTITY=false

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
        --dev)
            USE_DEV_IDENTITY=true
            shift
            ;;
        --offline)
            # Already handled above, but shift it
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
    echo "  --dev       Use GCP Identity Platform (dev project) instead of Firebase emulator"
    echo "  --offline   Run without Doppler (uses local password 'postgres')"
    echo "  --help, -h  Show this help message"
    echo ""
    echo "Services started:"
    echo "  - PostgreSQL:        localhost:5432"
    echo "  - Firebase Emulator: localhost:9099 (UI at localhost:4000) - skipped with --dev"
    echo "  - Portal Server:     localhost:8080"
    echo "  - Portal UI:         localhost:PORT (Flutter assigns port)"
    echo ""
    echo "Dev credentials:"
    echo "  Email:    mike.bushe@anspar.org (or other seeded dev admins)"
    echo "  Password: curehht"
    echo ""
    echo "GCP IDENTITY PLATFORM MODE (--dev):"
    echo "  ./tool/run_local.sh --dev"
    echo ""
    echo "  Uses real GCP Identity Platform instead of Firebase emulator."
    echo "  This is GDPR/FDA compliant and recommended for testing real auth flows."
    echo ""
    echo "  Required Doppler secrets:"
    echo "    PORTAL_IDENTITY_API_KEY     - GCP Identity Platform API key (AIza...)"
    echo "    PORTAL_IDENTITY_APP_ID      - Identity Platform web app ID"
    echo "    PORTAL_IDENTITY_PROJECT_ID  - GCP project ID"
    echo "    PORTAL_IDENTITY_AUTH_DOMAIN - Auth domain (project.firebaseapp.com)"
    echo ""
    echo "OFFLINE MODE (airplane/disconnected development):"
    echo "  ./tool/run_local.sh --offline --reset"
    echo ""
    echo "  In offline mode:"
    echo "  - Doppler is bypassed"
    echo "  - Database password defaults to 'postgres'"
    echo "  - All services run locally with Docker"
    echo "  - No external API calls required"
    echo ""
    echo "Flavors:"
    echo "  local  - Uses Firebase Emulator (default)"
    echo "  dev    - GCP Identity Platform (--dev flag, uses callisto4-dev project)"
    echo "  qa     - QA/Testing environment"
    echo "  uat    - User Acceptance Testing"
    echo "  prod   - Production"
    exit 0
fi

# Set database password based on mode
# In offline mode, LOCAL_DB_ROOT_PASSWORD comes from sourced .env.offline
# In online mode, it comes from Doppler
DB_PASSWORD="${LOCAL_DB_ROOT_PASSWORD:-$FALLBACK_DB_PASSWORD}"

if [ "$OFFLINE_MODE" = true ]; then
    echo -e "${YELLOW}[OFFLINE MODE]${NC} Using secrets from .env.offline"
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

    if [ -z "$DB_PASSWORD" ]; then
        log_error "Database password not set"
        return 1
    fi

    # Drop and recreate the database
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -c "CREATE DATABASE $DB_NAME;" 2>/dev/null

    # Run schema initialization
    log_info "Applying database schema..."
    cd "$DATABASE_DIR"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" -f init.sql

    # Apply local dev role grants (allows postgres to assume service_role)
    log_info "Applying local development role grants..."
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" -f local_roles.sql

    # Apply sponsor-specific seed data
    # Try callisto first, then curehht (depending on which repo is available)
    local seed_applied=false

    if [ -f "$PROJECT_ROOT/../hht_diary_callisto/database/seed_data_dev.sql" ]; then
        log_info "Applying Callisto seed data..."
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" \
            -f "$PROJECT_ROOT/../hht_diary_callisto/database/seed_data_dev.sql"
        seed_applied=true
    fi

    if [ -f "$PROJECT_ROOT/../hht_diary_curehht/database/seed_data_dev.sql" ] && [ "$seed_applied" = false ]; then
        log_info "Applying CureHHT seed data..."
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" \
            -f "$PROJECT_ROOT/../hht_diary_curehht/database/seed_data_dev.sql"
        seed_applied=true
    fi

    # Fallback to core seed data if no sponsor-specific seed found
    if [ "$seed_applied" = false ] && [ -f "$DATABASE_DIR/seed_data.sql" ]; then
        log_info "Applying core seed data..."
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d "$DB_NAME" \
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
        # In offline mode, set required env vars for docker-compose
        if [ "$OFFLINE_MODE" = true ]; then
            export LOCAL_DB_ROOT_PASSWORD="$OFFLINE_DB_PASSWORD"
            export LOCAL_DB_PASSWORD="$OFFLINE_DB_PASSWORD"
            docker compose -f docker-compose.db.yml up -d
        else
            docker compose -f docker-compose.db.yml up -d
        fi
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

    # Export environment variables for the server
    export DB_SSL="false"
    export PORT="8080"
    export DB_HOST="$DB_HOST"
    export DB_PORT="$DB_PORT"
    export DB_NAME="$DB_NAME"
    export DB_USER="postgres"
    export DB_PASSWORD="$DB_PASSWORD"

    if [ "$USE_DEV_IDENTITY" = true ]; then
        # Use real GCP Identity Platform for token verification
        # Unset emulator host to force real verification
        unset FIREBASE_AUTH_EMULATOR_HOST
        export GCP_PROJECT_ID="$PORTAL_IDENTITY_PROJECT_ID"
        log_info "Server using GCP Identity Platform: $GCP_PROJECT_ID"
    else
        # Use Firebase emulator for token verification
        export FIREBASE_AUTH_EMULATOR_HOST="${FIREBASE_HOST}:${FIREBASE_PORT}"
        export GCP_PROJECT_ID="demo-sponsor-portal"
        log_info "Server using Firebase Emulator: $FIREBASE_AUTH_EMULATOR_HOST"
    fi

    # Start in background
    dart run bin/server.dart &
    SERVER_PID=$!

    wait_for_port "localhost" "8080" "Portal Server"
}

# Start the Flutter web UI
start_ui() {
    cd "$SPONSOR_PORTAL_DIR/portal-ui"

    if [ "$USE_DEV_IDENTITY" = true ]; then
        # Use dev flavor with GCP Identity Platform (real auth, local backend)
        log_info "Starting Portal UI (Flutter Web) with GCP Identity Platform..."

        # These env vars should be set in Doppler (same keys used across envs)
        if [ -z "$PORTAL_IDENTITY_API_KEY" ]; then
            log_error "PORTAL_IDENTITY_API_KEY not set in Doppler"
            log_error "Required Doppler secrets for --dev mode:"
            log_error "  PORTAL_IDENTITY_API_KEY"
            log_error "  PORTAL_IDENTITY_APP_ID"
            log_error "  PORTAL_IDENTITY_PROJECT_ID"
            log_error "  PORTAL_IDENTITY_AUTH_DOMAIN"
            exit 1
        fi

        flutter run -d chrome \
            --dart-define=APP_FLAVOR=dev \
            --dart-define=PORTAL_API_URL=http://localhost:8080 \
            --dart-define=PORTAL_DEV_FIREBASE_API_KEY="$PORTAL_IDENTITY_API_KEY" \
            --dart-define=PORTAL_DEV_FIREBASE_APP_ID="$PORTAL_IDENTITY_APP_ID" \
            --dart-define=PORTAL_DEV_FIREBASE_PROJECT_ID="$PORTAL_IDENTITY_PROJECT_ID" \
            --dart-define=PORTAL_DEV_FIREBASE_AUTH_DOMAIN="$PORTAL_IDENTITY_AUTH_DOMAIN" \
            --dart-define=PORTAL_DEV_FIREBASE_MESSAGING_SENDER_ID="${PORTAL_IDENTITY_MESSAGING_SENDER_ID:-}" &
        UI_PID=$!
    else
        # Use local flavor with Firebase emulator
        log_info "Starting Portal UI (Flutter Web) with local flavor (emulator)..."

        flutter run -d chrome \
            --dart-define=APP_FLAVOR=local \
            --dart-define=FIREBASE_AUTH_EMULATOR_HOST=${FIREBASE_HOST}:${FIREBASE_PORT} &
        UI_PID=$!
    fi
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
    if [ "$OFFLINE_MODE" = true ]; then
        echo "  (OFFLINE MODE - No Doppler)"
    fi
    if [ "$USE_DEV_IDENTITY" = true ]; then
        echo "  (DEV MODE - GCP Identity Platform)"
    fi
    echo "=========================================="
    echo ""

    # Set up cleanup trap
    trap cleanup EXIT

    # Start services
    start_postgres

    # Only start Firebase emulator if not using GCP Identity Platform
    if [ "$USE_DEV_IDENTITY" = false ]; then
        start_firebase

        # Create Firebase users (creates if missing, skips if exists)
        create_firebase_users
    else
        log_info "Skipping Firebase Emulator (using GCP Identity Platform)"
    fi

    # Reset database if requested
    if [ "$RESET_DB" = true ]; then
        reset_database
        # Only clear Firebase users if using emulator
        if [ "$USE_DEV_IDENTITY" = false ]; then
            clear_firebase_users
        fi
    fi

    # Start portal server
    start_server

    echo ""
    log_success "All services started!"
    echo ""
    echo "=========================================="
    echo "  Access Points:"
    echo "=========================================="
    echo "  Portal Server:      http://localhost:8080"
    if [ "$USE_DEV_IDENTITY" = false ]; then
        echo "  Firebase Emulator:  http://localhost:4000"
    else
        echo "  Auth:               GCP Identity Platform (callisto4-dev)"
    fi
    echo "  PostgreSQL:         localhost:5432"
    echo ""
    if [ "$USE_DEV_IDENTITY" = false ]; then
        echo "  Dev Login:"
        echo "    Email:    mike.bushe@anspar.org"
        echo "    Password: curehht"
    else
        echo "  Auth via GCP Identity Platform (dev project)"
        echo "  Create test users in GCP Console or use existing dev accounts"
    fi
    echo "=========================================="
    echo ""

    # Start UI if requested
    if [ "$START_UI" = true ]; then
        start_ui

        # Wait for UI process
        wait $UI_PID 2>/dev/null || true
    else
        log_info "UI not started (use without --no-ui to start Flutter)"
        if [ "$USE_DEV_IDENTITY" = true ]; then
            log_info "To start manually: cd portal-ui && flutter run -d chrome --dart-define=APP_FLAVOR=dev ..."
        else
            log_info "To start manually: cd portal-ui && flutter run -d chrome --dart-define=APP_FLAVOR=local"
        fi

        # Wait for server
        wait $SERVER_PID 2>/dev/null || true
    fi
}

main
