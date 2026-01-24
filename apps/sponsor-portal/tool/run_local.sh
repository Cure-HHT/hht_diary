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
    echo "Email handling:"
    echo "  Emails are logged to console (EMAIL_CONSOLE_MODE=true)"
    echo "  Look for OTP codes in server output"
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
    echo "  How it works:"
    echo "    1. Server reads Identity config from Doppler env vars"
    echo "    2. Server exposes config at /api/v1/portal/config/identity"
    echo "    3. Flutter app fetches config from server at startup"
    echo "    4. Flutter initializes Firebase with fetched config"
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

# Clear Identity Platform test users (for --dev mode)
# Deletes all users except protected dev admins
# Uses REST API with gcloud auth token (no firebase-admin SDK needed)
clear_identity_platform_users() {
    log_info "Clearing Identity Platform test users..."

    local project_id="${PORTAL_IDENTITY_PROJECT_ID:-callisto4-dev}"

    # Protected emails - never delete these dev admins
    local protected_emails=(
        "mike.bushe@anspar.org"
        "michael@anspar.org"
        "tom@anspar.org"
        "urayoan@anspar.org"
        "elvira@anspar.org"
    )

    # Get access token
    local token=$(gcloud auth print-access-token 2>/dev/null)
    if [ -z "$token" ]; then
        log_error "Could not get gcloud access token"
        log_error "Run: gcloud auth login"
        return 1
    fi

    log_info "Listing users in project: $project_id"

    # List all users using Identity Platform REST API
    # Use batchGet with no filter to get all users (queryAccounts requires expression)
    local next_page_token=""
    local deleted_count=0
    local protected_count=0
    local error_count=0

    while true; do
        # Use the download endpoint which lists all users
        local url="https://identitytoolkit.googleapis.com/v1/projects/${project_id}/accounts:batchGet?maxResults=500"
        if [ -n "$next_page_token" ]; then
            url="${url}&nextPageToken=${next_page_token}"
        fi

        local list_response=$(curl -s -X GET "$url" \
            -H "Authorization: Bearer $token" \
            -H "x-goog-user-project: ${project_id}")

        # Debug: show response structure
        if [ "$DEBUG" = "true" ]; then
            log_info "API Response: $list_response"
        fi

        # Check for errors
        if echo "$list_response" | grep -q '"error"'; then
            log_error "Failed to list users: $list_response"
            return 1
        fi

        # Extract user records from "users" array (localId and email)
        # Parse JSON with simple grep/sed (avoid jq dependency)
        local users=$(echo "$list_response" | grep -o '"localId" *: *"[^"]*"' | sed 's/"localId" *: *"//g' | sed 's/"//g')
        local emails=$(echo "$list_response" | grep -o '"email" *: *"[^"]*"' | sed 's/"email" *: *"//g' | sed 's/"//g')

        # Convert to arrays
        local user_ids=($users)
        local user_emails=($emails)

        log_info "Found ${#user_ids[@]} users in this batch"

        # Process each user
        for i in "${!user_ids[@]}"; do
            local uid="${user_ids[$i]}"
            local email="${user_emails[$i]:-unknown}"

            # Check if protected (case-insensitive comparison, compatible with bash 3.x)
            local is_protected=false
            local email_lower=$(echo "$email" | tr '[:upper:]' '[:lower:]')
            for protected in "${protected_emails[@]}"; do
                local protected_lower=$(echo "$protected" | tr '[:upper:]' '[:lower:]')
                if [ "$email_lower" = "$protected_lower" ]; then
                    is_protected=true
                    break
                fi
            done

            if [ "$is_protected" = true ]; then
                log_info "  [PROTECTED] $email"
                ((protected_count++))
            else
                # Delete the user
                local delete_response=$(curl -s -X POST \
                    "https://identitytoolkit.googleapis.com/v1/projects/${project_id}/accounts:delete" \
                    -H "Authorization: Bearer $token" \
                    -H "Content-Type: application/json" \
                    -H "x-goog-user-project: ${project_id}" \
                    -d "{\"localId\": \"$uid\"}")

                if echo "$delete_response" | grep -q '"error"'; then
                    log_warn "  [ERROR] Failed to delete $email: $delete_response"
                    ((error_count++))
                else
                    log_success "  [DELETED] $email"
                    ((deleted_count++))
                fi
            fi
        done

        # Check for next page
        next_page_token=$(echo "$list_response" | grep -o '"nextPageToken" *: *"[^"]*"' | sed 's/"nextPageToken" *: *"//g' | sed 's/"//g')
        if [ -z "$next_page_token" ]; then
            break
        fi
        log_info "Fetching next page..."
    done

    echo ""
    log_info "Summary: Deleted $deleted_count, Protected $protected_count, Errors $error_count"

    if [ $error_count -gt 0 ]; then
        log_warn "Some users failed to delete"
        return 1
    fi

    log_success "Identity Platform test users cleared"
}

# Create a user in Identity Platform via REST API
create_identity_platform_user() {
    local email=$1
    local password=$2
    local project_id="${PORTAL_IDENTITY_PROJECT_ID:-callisto4-dev}"

    # Get access token
    local token=$(gcloud auth print-access-token 2>/dev/null)
    if [ -z "$token" ]; then
        log_warn "  Could not get access token for $email"
        return 1
    fi

    # Check if user exists by trying to look them up
    local lookup_response=$(curl -s -X POST \
        "https://identitytoolkit.googleapis.com/v1/projects/${project_id}/accounts:lookup" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "x-goog-user-project: ${project_id}" \
        -d "{\"email\":[\"${email}\"]}")

    if echo "$lookup_response" | grep -q "\"email\""; then
        log_info "  Identity Platform user $email already exists"
        return 0
    fi

    # Create user via Identity Platform REST API
    local response=$(curl -s -X POST \
        "https://identitytoolkit.googleapis.com/v1/projects/${project_id}/accounts" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "x-goog-user-project: ${project_id}" \
        -d "{\"email\":\"${email}\",\"password\":\"${password}\",\"emailVerified\":true}")

    if echo "$response" | grep -q "\"localId\""; then
        log_success "  Created Identity Platform user: $email"
    else
        log_warn "  Could not create Identity Platform user $email: $response"
    fi
}

# Ensure dev admin users exist in Identity Platform
ensure_identity_platform_dev_admins() {
    log_info "Ensuring dev admin users exist in Identity Platform..."

    # Same dev admins as in seed data and Firebase emulator setup
    create_identity_platform_user "mike.bushe@anspar.org" "$DEV_PASSWORD"
    create_identity_platform_user "michael@anspar.org" "$DEV_PASSWORD"
    create_identity_platform_user "tom@anspar.org" "$DEV_PASSWORD"
    create_identity_platform_user "urayoan@anspar.org" "$DEV_PASSWORD"
    create_identity_platform_user "elvira@anspar.org" "$DEV_PASSWORD"

    log_success "Dev admin users verified"
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

    # Enable email console mode for local development
    # Emails are logged to console instead of being sent via Gmail API
    export EMAIL_CONSOLE_MODE="true"
    log_info "Email console mode enabled - emails will be logged to console"

    if [ "$USE_DEV_IDENTITY" = true ]; then
        # Use real GCP Identity Platform for token verification
        # Unset emulator host to force real verification
        unset FIREBASE_AUTH_EMULATOR_HOST
        export GCP_PROJECT_ID="$PORTAL_IDENTITY_PROJECT_ID"

        # Export Identity Platform config for the /api/v1/portal/config/identity endpoint
        # These are read by the server and served to the Flutter client at runtime
        export PORTAL_IDENTITY_API_KEY="${PORTAL_IDENTITY_API_KEY}"
        export PORTAL_IDENTITY_APP_ID="${PORTAL_IDENTITY_APP_ID}"
        export PORTAL_IDENTITY_PROJECT_ID="${PORTAL_IDENTITY_PROJECT_ID}"
        export PORTAL_IDENTITY_AUTH_DOMAIN="${PORTAL_IDENTITY_AUTH_DOMAIN}"
        export PORTAL_IDENTITY_MESSAGING_SENDER_ID="${PORTAL_IDENTITY_MESSAGING_SENDER_ID:-}"

        log_info "Server using GCP Identity Platform: $GCP_PROJECT_ID"
        log_info "Server will serve Identity config via /api/v1/portal/config/identity"
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
        # The Flutter app fetches Identity config from server at runtime
        # via /api/v1/portal/config/identity (no dart-define for Firebase)
        log_info "Starting Portal UI (Flutter Web) with GCP Identity Platform..."

        # Verify server has Identity config available
        if [ -z "$PORTAL_IDENTITY_API_KEY" ]; then
            log_error "PORTAL_IDENTITY_API_KEY not set in Doppler"
            log_error "Required Doppler secrets for --dev mode:"
            log_error "  PORTAL_IDENTITY_API_KEY"
            log_error "  PORTAL_IDENTITY_APP_ID"
            log_error "  PORTAL_IDENTITY_PROJECT_ID"
            log_error "  PORTAL_IDENTITY_AUTH_DOMAIN"
            exit 1
        fi

        # APP_FLAVOR=dev tells the app to fetch Identity config from server
        # PORTAL_API_URL points to the local server (which has the Identity config)
        flutter run -d chrome \
            --dart-define=APP_FLAVOR=dev \
            --dart-define=PORTAL_API_URL=http://localhost:8080 &
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

    # Ensure terminal prompt returns cleanly
    echo ""
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
        # Ensure dev admin users exist in Identity Platform
        ensure_identity_platform_dev_admins
    fi

    # Reset database if requested
    if [ "$RESET_DB" = true ]; then
        reset_database
        # Clear auth users based on mode
        if [ "$USE_DEV_IDENTITY" = false ]; then
            clear_firebase_users
            # Re-create users after clearing
            create_firebase_users
        else
            # Clear Identity Platform test users (keeps protected dev admins)
            clear_identity_platform_users
            # Ensure dev admin users exist in Identity Platform
            ensure_identity_platform_dev_admins
        fi

        echo ""
        log_success "Database reset complete!"
        echo ""
        echo "=========================================="
        echo "  Reset Summary:"
        echo "=========================================="
        echo "  - Database dropped and recreated"
        echo "  - Schema and seed data applied"
        if [ "$USE_DEV_IDENTITY" = false ]; then
            echo "  - Firebase emulator accounts reset"
        else
            echo "  - Identity Platform test users cleared"
        fi
        echo ""
        echo "  Run './tool/run_local.sh' (without --reset) to start"
        echo "  the development environment."
        echo "=========================================="
        echo ""
        exit 0
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

    # Start UI if requested (but not during --reset, which is just for DB initialization)
    if [ "$START_UI" = true ] && [ "$RESET_DB" = false ]; then
        start_ui

        # Wait for UI process
        wait $UI_PID 2>/dev/null || true
        echo ""  # Ensure prompt returns cleanly
    elif [ "$RESET_DB" = true ]; then
        log_info "Database reset complete. UI not started during --reset."
        log_info "Run without --reset to start the full development environment."
        echo ""
    else
        log_info "UI not started (use without --no-ui to start Flutter)"
        if [ "$USE_DEV_IDENTITY" = true ]; then
            log_info "To start manually: cd portal-ui && flutter run -d chrome --dart-define=APP_FLAVOR=dev ..."
        else
            log_info "To start manually: cd portal-ui && flutter run -d chrome --dart-define=APP_FLAVOR=local"
        fi

        # Wait for server
        wait $SERVER_PID 2>/dev/null || true
        echo ""  # Ensure prompt returns cleanly
    fi
}

main
