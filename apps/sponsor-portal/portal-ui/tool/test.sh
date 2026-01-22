#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-p00009: Sponsor-Specific Web Portals
#   REQ-p00024: Portal User Roles and Permissions
#   REQ-d00028: Portal Frontend Framework
#   REQ-CAL-p00010: First Admin Provisioning (integration tests)
#   REQ-CAL-p00029: Create User Account (integration tests)
#
# Test script for portal-ui
# Runs Flutter unit tests and integration tests
# Optionally generates coverage reports

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd "$SCRIPT_DIR"

# Coverage threshold (percentage)
# Currently at ~55% from unit tests only.
# API/E2E tests in integration_test/ don't contribute to lib/ coverage.
# TODO: Add Flutter UI integration tests (like clinical_diary) to increase coverage.
MIN_COVERAGE=54

# Parse command line arguments
RUN_UNIT=false
RUN_INTEGRATION=false
START_SERVICES=false
STOP_SERVICES=false
RESET_DB=false
WITH_COVERAGE=false
CHECK_THRESHOLDS=true
CONCURRENCY="10"
STARTED_SERVER=false
SERVER_PID=""
USE_DEV_IDENTITY=false  # Use GCP Identity Platform instead of Firebase emulator

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --unit           Run unit tests only"
    echo "  -i, --integration    Run integration tests (requires services running)"
    echo "  -c, --coverage       Run with coverage collection and reporting"
    echo "  --concurrency N      Set test concurrency (default: 10)"
    echo "  --no-threshold       Skip coverage threshold checks (only with --coverage)"
    echo "  --start-services     Start local services (PostgreSQL, Portal Server)"
    echo "  --stop-services      Stop local services after tests"
    echo "  --reset              Reset database before tests (use with --start-services)"
    echo "  --dev                Use GCP Identity Platform instead of Firebase emulator"
    echo "                       (Requires PORTAL_IDENTITY_* env vars from Doppler)"
    echo "  --skip-ui-tests      Skip Flutter UI integration tests (API tests still run)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "If no test flags (-u/-i) are specified, unit tests are run."
    echo ""
    echo "Coverage Threshold: ${MIN_COVERAGE}%"
    echo ""
    echo "Integration tests require:"
    echo "  - PostgreSQL running on localhost:5432"
    echo "  - Auth: Firebase emulator (default) or GCP Identity Platform (--dev)"
    echo "  - Portal Server on localhost:8080"
    echo ""
    echo "Quick start for integration tests:"
    echo "  ./tool/test.sh -i --start-services --reset"
    echo ""
    echo "With real GCP Identity Platform (--dev mode):"
    echo "  doppler run -- ./tool/test.sh -i --start-services --reset --dev"
    echo ""
    echo "Or start services manually:"
    echo "  ../tool/run_local.sh --reset"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -u|--unit)
      RUN_UNIT=true
      shift
      ;;
    -i|--integration)
      RUN_INTEGRATION=true
      shift
      ;;
    -c|--coverage)
      WITH_COVERAGE=true
      shift
      ;;
    --concurrency)
      CONCURRENCY="$2"
      shift 2
      ;;
    --no-threshold)
      CHECK_THRESHOLDS=false
      shift
      ;;
    --start-services)
      START_SERVICES=true
      shift
      ;;
    --stop-services)
      STOP_SERVICES=true
      shift
      ;;
    --reset)
      RESET_DB=true
      shift
      ;;
    --dev)
      USE_DEV_IDENTITY=true
      shift
      ;;
    --skip-ui-tests)
      SKIP_UI_TESTS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Default: run unit tests only (integration tests require services)
if [ "$RUN_UNIT" = false ] && [ "$RUN_INTEGRATION" = false ]; then
    RUN_UNIT=true
fi

# Coverage requires unit tests (Dart VM integration tests don't generate Flutter coverage)
if [ "$WITH_COVERAGE" = true ] && [ "$RUN_UNIT" = false ]; then
    echo "Note: Enabling unit tests for coverage collection"
    echo "      (Dart VM integration tests don't generate Flutter coverage)"
    RUN_UNIT=true
fi

echo "=============================================="
if [ "$WITH_COVERAGE" = true ]; then
    echo "Portal UI Test Suite (with Coverage)"
else
    echo "Portal UI Test Suite"
fi
echo "=============================================="

# Clean up coverage directory if running with coverage
if [ "$WITH_COVERAGE" = true ]; then
    rm -rf coverage
    mkdir -p coverage
fi

UNIT_PASSED=true
INTEGRATION_PASSED=true

# Cleanup function for stopping services
cleanup() {
    # Stop portal server
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        echo ""
        echo "Stopping portal server (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
    else
        # Fallback: try to kill any process on port 8080 if we started services
        if [ "$STARTED_SERVER" = true ]; then
            EXISTING_PID=$(lsof -ti:8080 2>/dev/null || true)
            if [ -n "$EXISTING_PID" ]; then
                echo ""
                echo "Stopping portal server (port 8080, PID: $EXISTING_PID)..."
                kill "$EXISTING_PID" 2>/dev/null || true
            fi
        fi
    fi

    if [ "$STOP_SERVICES" = true ]; then
        echo ""
        echo "Stopping services..."

        COMPOSE_DIR="$PROJECT_ROOT/tools/dev-env"
        if [ -d "$COMPOSE_DIR" ]; then
            (cd "$COMPOSE_DIR" && doppler run -- docker compose -f docker-compose.db.yml down 2>/dev/null || true)
            # Only stop Firebase emulator if not using --dev mode
            if [ "$USE_DEV_IDENTITY" = false ]; then
                (cd "$COMPOSE_DIR" && docker compose -f docker-compose.firebase.yml down 2>/dev/null || true)
            fi
        fi
    fi
}

trap cleanup EXIT

# Start services if requested
if [ "$START_SERVICES" = true ]; then
    COMPOSE_DIR="$PROJECT_ROOT/tools/dev-env"
    DATABASE_DIR="$PROJECT_ROOT/database"

    echo ""
    echo "Starting services..."

    # Start PostgreSQL
    if docker exec sponsor-portal-postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo "PostgreSQL already running"
    else
        echo "Starting PostgreSQL..."
        if [ -f "$COMPOSE_DIR/docker-compose.db.yml" ]; then
            (cd "$COMPOSE_DIR" && doppler run -- docker compose -f docker-compose.db.yml up -d)

            echo "Waiting for PostgreSQL..."
            TIMEOUT=30
            ELAPSED=0
            while [ $ELAPSED -lt $TIMEOUT ]; do
                if docker exec sponsor-portal-postgres pg_isready -U postgres > /dev/null 2>&1; then
                    echo "PostgreSQL is ready!"
                    break
                fi
                sleep 1
                ELAPSED=$((ELAPSED + 1))
            done

            if [ $ELAPSED -ge $TIMEOUT ]; then
                echo "Timeout waiting for PostgreSQL"
                exit 1
            fi
        else
            echo "Error: docker-compose.db.yml not found"
            exit 1
        fi
    fi

    # Authentication setup (Firebase emulator or GCP Identity Platform)
    if [ "$USE_DEV_IDENTITY" = true ]; then
        # Using GCP Identity Platform (--dev mode)
        echo ""
        echo "Using GCP Identity Platform (--dev mode)"

        # Verify required environment variables
        if [ -z "$PORTAL_IDENTITY_API_KEY" ]; then
            echo "Error: PORTAL_IDENTITY_API_KEY not set"
            echo "Run with: doppler run -- ./tool/test.sh ..."
            exit 1
        fi

        if [ -z "$PORTAL_IDENTITY_PROJECT_ID" ]; then
            echo "Error: PORTAL_IDENTITY_PROJECT_ID not set"
            exit 1
        fi

        echo "   Project: $PORTAL_IDENTITY_PROJECT_ID"

        # Run cleanup to delete non-dev-admin users from Identity Platform
        TOOL_DIR="$SCRIPT_DIR/../tool"
        if [ -f "$TOOL_DIR/cleanup_identity_users.js" ]; then
            echo ""
            echo "Cleaning up Identity Platform users..."
            (cd "$TOOL_DIR" && npm install --silent && \
                node cleanup_identity_users.js \
                    --project="${PORTAL_IDENTITY_PROJECT_ID%-*}" \
                    --env="${PORTAL_IDENTITY_PROJECT_ID##*-}")
        fi

        # Ensure dev admin users exist in Identity Platform
        if [ -f "$TOOL_DIR/seed_identity_users.js" ]; then
            echo ""
            echo "Seeding Identity Platform dev admins..."
            DEV_PASSWORD=$(doppler secrets get DEV_ADMIN_PASSWORD --plain 2>/dev/null || echo "curehht")
            (cd "$TOOL_DIR" && node seed_identity_users.js \
                --project="${PORTAL_IDENTITY_PROJECT_ID%-*}" \
                --env="${PORTAL_IDENTITY_PROJECT_ID##*-}" \
                --password="$DEV_PASSWORD" \
                --users="mike.bushe@anspar.org,michael@anspar.org,tom@anspar.org,urayoan@anspar.org" \
                --user-names="Mike Bushe,Michael,Tom,Urayoan")
        fi
    else
        # Using Firebase emulator (default)
        if curl -s http://localhost:9099/ > /dev/null 2>&1; then
            echo "Firebase Auth emulator already running"
        else
            echo "Starting Firebase Auth emulator..."
            if [ -f "$COMPOSE_DIR/docker-compose.firebase.yml" ]; then
                (cd "$COMPOSE_DIR" && docker compose -f docker-compose.firebase.yml up -d)

                echo "Waiting for Firebase emulator..."
                TIMEOUT=60
                ELAPSED=0
                while [ $ELAPSED -lt $TIMEOUT ]; do
                    if curl -s http://localhost:9099/ > /dev/null 2>&1; then
                        echo "Firebase Auth emulator is ready!"
                        break
                    fi
                    sleep 1
                    ELAPSED=$((ELAPSED + 1))
                done

                if [ $ELAPSED -ge $TIMEOUT ]; then
                    echo "Timeout waiting for Firebase emulator"
                    exit 1
                fi
            fi
        fi
    fi

    # Reset database if requested
    if [ "$RESET_DB" = true ]; then
        echo ""
        echo "Resetting database..."
        DB_PASSWORD=$(doppler secrets get LOCAL_DB_ROOT_PASSWORD --plain 2>/dev/null)

        if [ -n "$DB_PASSWORD" ]; then
            # Drop and recreate database
            PGPASSWORD="$DB_PASSWORD" psql -h localhost -U postgres -c "DROP DATABASE IF EXISTS sponsor_portal;" 2>/dev/null || true
            PGPASSWORD="$DB_PASSWORD" psql -h localhost -U postgres -c "CREATE DATABASE sponsor_portal;" 2>/dev/null

            # Apply schema
            if [ -f "$DATABASE_DIR/init.sql" ]; then
                PGPASSWORD="$DB_PASSWORD" psql -h localhost -U postgres -d sponsor_portal -f "$DATABASE_DIR/init.sql"
            fi

            # Apply sponsor-specific seed data (callisto)
            if [ -f "$PROJECT_ROOT/../hht_diary_callisto/database/seed_data_dev.sql" ]; then
                PGPASSWORD="$DB_PASSWORD" psql -h localhost -U postgres -d sponsor_portal \
                    -f "$PROJECT_ROOT/../hht_diary_callisto/database/seed_data_dev.sql"
            fi

            echo "Database reset complete"
        else
            echo "Warning: Could not get DB password from Doppler"
        fi
    fi

    # Create test users (Firebase emulator only - Identity Platform users seeded above)
    if [ "$USE_DEV_IDENTITY" = false ]; then
        echo ""
        echo "Creating Firebase test users..."
        FIREBASE_URL="http://localhost:9099"
        DEV_PASSWORD="curehht"

        create_firebase_user() {
            local email=$1
            curl -s -X POST \
                "${FIREBASE_URL}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key" \
                -H "Content-Type: application/json" \
                -d "{\"email\":\"${email}\",\"password\":\"${DEV_PASSWORD}\",\"returnSecureToken\":true}" > /dev/null 2>&1 || true
        }

        create_firebase_user "mike.bushe@anspar.org"
        create_firebase_user "michael@anspar.org"
        create_firebase_user "tom@anspar.org"
        create_firebase_user "urayoan@anspar.org"
        echo "Firebase users created"
    fi

    # Start Portal Server
    # If server is already running, we need to restart it to apply correct auth config
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo "Portal Server already running - stopping it to apply correct auth config..."
        # Find and kill existing dart server on port 8080
        EXISTING_PID=$(lsof -ti:8080 2>/dev/null || true)
        if [ -n "$EXISTING_PID" ]; then
            kill "$EXISTING_PID" 2>/dev/null || true
            sleep 2
        fi
    fi

    if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo ""
        echo "Starting Portal Server..."

        PORTAL_SERVER_DIR="$SCRIPT_DIR/../portal_server"
        if [ -d "$PORTAL_SERVER_DIR" ]; then
            # Save current directory
            SAVED_DIR="$(pwd)"

            cd "$PORTAL_SERVER_DIR"

            # Auth configuration based on --dev flag
            if [ "$USE_DEV_IDENTITY" = true ]; then
                # Use real GCP Identity Platform
                unset FIREBASE_AUTH_EMULATOR_HOST
                export GCP_PROJECT_ID="$PORTAL_IDENTITY_PROJECT_ID"
                echo "   Auth: GCP Identity Platform (project: $GCP_PROJECT_ID)"
            else
                # Use Firebase emulator
                export FIREBASE_AUTH_EMULATOR_HOST="localhost:9099"
                export GCP_PROJECT_ID="demo-sponsor-portal"
                echo "   Auth: Firebase emulator"
            fi

            export DB_SSL="false"
            export PORT="8080"
            export DB_HOST="localhost"
            export DB_PORT="5432"
            export DB_NAME="sponsor_portal"
            export DB_USER="postgres"
            export DB_PASSWORD=$(doppler secrets get LOCAL_DB_ROOT_PASSWORD --plain 2>/dev/null)

            # Start server in background and capture PID
            dart run bin/server.dart &
            SERVER_PID=$!
            echo "   Server PID: $SERVER_PID"

            # Return to saved directory
            cd "$SAVED_DIR"

            # Wait for server
            echo "Waiting for Portal Server..."
            TIMEOUT=30
            ELAPSED=0
            while [ $ELAPSED -lt $TIMEOUT ]; do
                if curl -s http://localhost:8080/health > /dev/null 2>&1; then
                    echo "Portal Server is ready!"
                    STARTED_SERVER=true
                    break
                fi
                sleep 1
                ELAPSED=$((ELAPSED + 1))
            done

            if [ $ELAPSED -ge $TIMEOUT ]; then
                echo "Warning: Portal Server not responding (tests may fail)"
            fi
        else
            echo "Warning: portal_server not found at $PORTAL_SERVER_DIR"
        fi
    fi
fi

# Build test command based on coverage flag
if [ "$WITH_COVERAGE" = true ]; then
    TEST_CMD="flutter test --coverage --concurrency=$CONCURRENCY"
else
    TEST_CMD="flutter test --concurrency=$CONCURRENCY"
fi

# Run unit tests
if [ "$RUN_UNIT" = true ]; then
    echo ""
    echo "Running unit tests..."
    echo "   Concurrency: $CONCURRENCY"
    echo ""

    if $TEST_CMD test/; then
        echo "Unit tests passed!"
    else
        echo "Unit tests failed!"
        UNIT_PASSED=false
    fi

    # Rename coverage file for clarity when combining
    if [ "$WITH_COVERAGE" = true ] && [ -f "coverage/lcov.info" ]; then
        mv coverage/lcov.info coverage/lcov-unit.info
        echo "Coverage captured: coverage/lcov-unit.info"

        # Filter out generated files if lcov is available
        if command -v lcov &> /dev/null; then
            echo "Filtering coverage data..."
            lcov --remove coverage/lcov-unit.info \
                '**/*.g.dart' \
                '**/*.freezed.dart' \
                '**/test/**' \
                --ignore-errors unused \
                -o coverage/lcov-unit.info 2>/dev/null || true
        fi
    fi
fi

# Run integration tests (Dart VM tests against real services)
if [ "$RUN_INTEGRATION" = true ]; then
    echo ""
    echo "=============================================="
    echo "Running Integration Tests"
    echo "=============================================="
    if [ "$USE_DEV_IDENTITY" = true ]; then
        echo "   Auth: GCP Identity Platform ($PORTAL_IDENTITY_PROJECT_ID)"
    else
        echo "   Auth: Firebase emulator"
    fi
    echo ""

    # Check services are running
    if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo "Warning: Portal Server not responding at localhost:8080"
        echo "Start services with: --start-services or ../tool/run_local.sh"
    fi

    if [ "$USE_DEV_IDENTITY" = false ]; then
        if ! curl -s http://localhost:9099/ > /dev/null 2>&1; then
            echo "Warning: Firebase emulator not responding at localhost:9099"
        fi
    fi

    # Set environment for integration tests
    if [ "$USE_DEV_IDENTITY" = true ]; then
        # GCP Identity Platform mode - unset emulator, set Identity Platform vars
        unset FIREBASE_AUTH_EMULATOR_HOST
        export PORTAL_IDENTITY_API_KEY="${PORTAL_IDENTITY_API_KEY}"
        export PORTAL_IDENTITY_PROJECT_ID="${PORTAL_IDENTITY_PROJECT_ID}"
        # Pass dev admin password to tests (must match what was used in seed script)
        export DEV_ADMIN_PASSWORD=$(doppler secrets get DEV_ADMIN_PASSWORD --plain 2>/dev/null || echo "curehht")
    else
        # Firebase emulator mode
        export FIREBASE_AUTH_EMULATOR_HOST="localhost:9099"
    fi

    export PORTAL_SERVER_URL="http://localhost:8080"
    export DB_SSL="false"
    export DB_HOST="localhost"
    export DB_PORT="5432"
    export DB_NAME="sponsor_portal"
    export DB_USER="postgres"
    export DB_PASSWORD=$(doppler secrets get LOCAL_DB_ROOT_PASSWORD --plain 2>/dev/null || echo "postgres")

    if [ -d "integration_test" ]; then
        # Count API test files (in api/ subdirectory)
        API_TEST_FILES=$(find integration_test/api -name "*_test.dart" 2>/dev/null | wc -l | tr -d ' ')
        # Count Flutter UI test files (in root of integration_test/)
        UI_TEST_FILES=$(find integration_test -maxdepth 1 -name "*_test.dart" 2>/dev/null | wc -l | tr -d ' ')
        echo "   Found $API_TEST_FILES API test file(s) in integration_test/api/"
        echo "   Found $UI_TEST_FILES Flutter UI test file(s) in integration_test/"
        echo ""

        # Build test command - add coverage flag if requested
        # IMPORTANT: --concurrency=1 because integration tests share database state
        if [ "$WITH_COVERAGE" = true ]; then
            INTEGRATION_TEST_CMD="dart test --concurrency=1 --coverage=coverage/integration"
            rm -rf coverage/integration
            mkdir -p coverage/integration
        else
            INTEGRATION_TEST_CMD="dart test --concurrency=1"
        fi

        # Run API tests (Dart VM tests in api/ subdirectory)
        if [ "$API_TEST_FILES" -gt 0 ]; then
            echo "----------------------------------------------"
            echo "Running $API_TEST_FILES API integration test files..."
            echo "----------------------------------------------"
            if $INTEGRATION_TEST_CMD integration_test/api/; then
                echo ""
                echo "----------------------------------------------"
                echo "API Integration Tests: PASSED ($API_TEST_FILES files)"
                echo "----------------------------------------------"
            else
                echo ""
                echo "----------------------------------------------"
                echo "API Integration Tests: FAILED"
                echo "----------------------------------------------"
                INTEGRATION_PASSED=false
            fi
        fi

        # Run Flutter UI integration tests (in root of integration_test/)
        # Flutter integration tests require a desktop device (not web)
        # NOTE: These are OPTIONAL - API tests in api/ already cover the same journeys.
        # UI tests require macOS/Linux desktop build which needs CocoaPods setup.
        # Skip with: --skip-ui-tests
        SKIP_UI_TESTS="${SKIP_UI_TESTS:-false}"
        if [ "$UI_TEST_FILES" -gt 0 ] && [ "$SKIP_UI_TESTS" = "true" ]; then
            echo ""
            echo "----------------------------------------------"
            echo "Skipping $UI_TEST_FILES Flutter UI test files (--skip-ui-tests)"
            echo "----------------------------------------------"
        elif [ "$UI_TEST_FILES" -gt 0 ]; then
            echo ""
            echo "----------------------------------------------"
            echo "Running $UI_TEST_FILES Flutter UI integration test files..."
            echo "----------------------------------------------"

            # Detect platform and set device target
            # Web is NOT supported for Flutter integration tests
            XVFB_PREFIX=""
            case "$(uname -s)" in
                Darwin*)
                    UI_DEVICE="macos"
                    ;;
                Linux*)
                    UI_DEVICE="linux"
                    # Use xvfb-run for headless Linux (CI) if available
                    if command -v xvfb-run &> /dev/null; then
                        XVFB_PREFIX="xvfb-run -a"
                        echo "   Using xvfb-run for headless display"
                    fi
                    ;;
                MINGW*|CYGWIN*|MSYS*)
                    UI_DEVICE="windows"
                    ;;
                *)
                    echo "   Unknown platform, defaulting to linux"
                    UI_DEVICE="linux"
                    ;;
            esac
            echo "   Target device: $UI_DEVICE"

            UI_INTEGRATION_FAILED=false
            UI_FILE_INDEX=0

            # Run each UI test file individually (like clinical_diary)
            for test_file in integration_test/*_test.dart; do
                if [ -f "$test_file" ]; then
                    echo ""
                    echo "   Running: $test_file"
                    UI_FILE_INDEX=$((UI_FILE_INDEX + 1))

                    if [ "$WITH_COVERAGE" = true ]; then
                        if $XVFB_PREFIX flutter test "$test_file" -d "$UI_DEVICE" --coverage; then
                            if [ -f "coverage/lcov.info" ]; then
                                mv coverage/lcov.info "coverage/lcov-ui-integration-$UI_FILE_INDEX.info"
                                echo "   Coverage saved: coverage/lcov-ui-integration-$UI_FILE_INDEX.info"
                            fi
                        else
                            UI_INTEGRATION_FAILED=true
                        fi
                    else
                        if ! $XVFB_PREFIX flutter test "$test_file" -d "$UI_DEVICE"; then
                            UI_INTEGRATION_FAILED=true
                        fi
                    fi
                fi
            done

            # Combine UI integration coverage files if any exist
            if [ "$WITH_COVERAGE" = true ]; then
                UI_COVERAGE_FILES=$(ls coverage/lcov-ui-integration-*.info 2>/dev/null || true)
                if [ -n "$UI_COVERAGE_FILES" ]; then
                    if command -v lcov &> /dev/null; then
                        # Build lcov arguments
                        LCOV_ARGS=""
                        for f in $UI_COVERAGE_FILES; do
                            LCOV_ARGS="$LCOV_ARGS -a $f"
                        done
                        # shellcheck disable=SC2086
                        lcov $LCOV_ARGS -o coverage/lcov-ui-integration.info --ignore-errors unused 2>/dev/null || \
                            cat $UI_COVERAGE_FILES > coverage/lcov-ui-integration.info
                    else
                        cat $UI_COVERAGE_FILES > coverage/lcov-ui-integration.info
                    fi
                    echo "   Combined UI coverage: coverage/lcov-ui-integration.info"
                fi
            fi

            if [ "$UI_INTEGRATION_FAILED" = true ]; then
                echo ""
                echo "----------------------------------------------"
                echo "Flutter UI Integration Tests: FAILED"
                echo "----------------------------------------------"
                INTEGRATION_PASSED=false
            else
                echo ""
                echo "----------------------------------------------"
                echo "Flutter UI Integration Tests: PASSED ($UI_FILE_INDEX files)"
                echo "----------------------------------------------"
            fi
        fi

        # Generate lcov report for integration tests
        if [ "$WITH_COVERAGE" = true ] && [ -d "coverage/integration" ]; then
            echo ""
            echo "Generating integration test lcov report..."
            dart pub global activate coverage 2>/dev/null || true
            dart pub global run coverage:format_coverage \
                --lcov \
                --in=coverage/integration \
                --out=coverage/lcov-integration.info \
                --report-on=lib \
                --packages=.dart_tool/package_config.json || echo "Warning: Could not generate integration lcov report"

            if [ -f "coverage/lcov-integration.info" ]; then
                LINES=$(wc -l < coverage/lcov-integration.info | tr -d ' ')
                echo "Integration coverage captured: coverage/lcov-integration.info ($LINES lines)"
            fi
        fi
    else
        echo "integration_test/ directory not found, skipping integration tests"
    fi

    # Clean up environment
    unset FIREBASE_AUTH_EMULATOR_HOST
    unset PORTAL_SERVER_URL
    unset PORTAL_IDENTITY_API_KEY
    unset PORTAL_IDENTITY_PROJECT_ID
    unset DEV_ADMIN_PASSWORD
fi

# Combine coverage reports from all test types
if [ "$WITH_COVERAGE" = true ]; then
    echo ""
    echo "Preparing coverage reports..."
    echo "   Unit coverage: $([ -f coverage/lcov-unit.info ] && echo 'YES' || echo 'NO')"
    echo "   API integration coverage: $([ -f coverage/lcov-integration.info ] && echo 'YES' || echo 'NO')"
    echo "   UI integration coverage: $([ -f coverage/lcov-ui-integration.info ] && echo 'YES' || echo 'NO')"

    # Build list of coverage files to combine
    COVERAGE_FILES=""
    if [ -f "coverage/lcov-unit.info" ]; then
        COVERAGE_FILES="$COVERAGE_FILES -a coverage/lcov-unit.info"
    fi
    if [ -f "coverage/lcov-integration.info" ]; then
        COVERAGE_FILES="$COVERAGE_FILES -a coverage/lcov-integration.info"
    fi
    if [ -f "coverage/lcov-ui-integration.info" ]; then
        COVERAGE_FILES="$COVERAGE_FILES -a coverage/lcov-ui-integration.info"
    fi

    if [ -n "$COVERAGE_FILES" ]; then
        if command -v lcov &> /dev/null; then
            echo ""
            echo "Combining coverage reports..."
            # shellcheck disable=SC2086
            if lcov $COVERAGE_FILES -o coverage/lcov.info --ignore-errors unused; then
                echo "Combined coverage: coverage/lcov.info"
            else
                echo "Warning: lcov combine failed"
                # Fallback: use first available coverage file
                if [ -f "coverage/lcov-unit.info" ]; then
                    cp coverage/lcov-unit.info coverage/lcov.info
                elif [ -f "coverage/lcov-ui-integration.info" ]; then
                    cp coverage/lcov-ui-integration.info coverage/lcov.info
                fi
            fi
        else
            echo "lcov not found, concatenating files..."
            # Concatenate all available coverage files
            cat coverage/lcov-*.info > coverage/lcov.info 2>/dev/null || true
        fi
    else
        echo "Warning: No coverage files found to combine"
    fi

    # Verify coverage file exists
    if [ -f "coverage/lcov.info" ]; then
        echo "Final coverage file: coverage/lcov.info"
    else
        echo "Warning: No coverage file created"
    fi

    # Generate HTML report if genhtml is available
    if [ -f "coverage/lcov.info" ] && command -v genhtml &> /dev/null; then
        echo ""
        echo "Generating HTML report..."
        genhtml coverage/lcov.info -o coverage/html || echo "Warning: Could not generate HTML report"
        if [ -f "coverage/html/index.html" ]; then
            echo "HTML report: coverage/html/index.html"
        fi
    fi
fi

echo ""
echo "=============================================="
echo "Summary"
echo "=============================================="

EXIT_CODE=0

if [ "$RUN_UNIT" = true ]; then
    if [ "$UNIT_PASSED" = true ]; then
        echo "Unit Tests: PASSED"
    else
        echo "Unit Tests: FAILED"
        EXIT_CODE=1
    fi
fi

if [ "$RUN_INTEGRATION" = true ]; then
    if [ "$INTEGRATION_PASSED" = true ]; then
        echo "Integration Tests: PASSED"
    else
        echo "Integration Tests: FAILED"
        EXIT_CODE=1
    fi
fi

# Coverage summary and threshold check
if [ "$WITH_COVERAGE" = true ]; then
    # Calculate coverage percentage
    get_coverage_percentage() {
        local lcov_file="$1"
        if [ ! -f "$lcov_file" ]; then
            echo "0"
            return
        fi

        local lines_found
        local lines_hit
        lines_found=$(grep -c "^DA:" "$lcov_file" 2>/dev/null) || lines_found=0
        lines_hit=$(grep "^DA:" "$lcov_file" 2>/dev/null | grep -cv ",0$") || lines_hit=0

        lines_found=$(echo "$lines_found" | tr -d '[:space:]')
        lines_hit=$(echo "$lines_hit" | tr -d '[:space:]')

        lines_found=${lines_found:-0}
        lines_hit=${lines_hit:-0}

        if [ "$lines_found" -eq 0 ] 2>/dev/null; then
            echo "0"
        else
            awk "BEGIN {printf \"%.1f\", ($lines_hit/$lines_found)*100}"
        fi
    }

    echo ""
    echo "=============================================="
    echo "Coverage Report"
    echo "=============================================="

    COVERAGE_PCT="0"
    if [ -f "coverage/lcov.info" ]; then
        COVERAGE_PCT=$(get_coverage_percentage "coverage/lcov.info")

        echo ""
        echo "  ┌────────────────────────────────────────┐"
        echo "  │                                        │"
        printf "  │     TOTAL COVERAGE: %6s%%            │\n" "$COVERAGE_PCT"
        echo "  │                                        │"
        echo "  └────────────────────────────────────────┘"
        echo ""
        echo "  LCOV Report: coverage/lcov.info"
        if [ -f "coverage/html/index.html" ]; then
            echo "  HTML Report: coverage/html/index.html"
            echo ""
            echo "  View in browser:"
            echo "    open coverage/html/index.html"
        fi
    else
        echo ""
        echo "  Warning: No coverage data generated"
        echo "  (Run unit tests with -u flag to generate coverage)"
    fi

    # Check coverage thresholds
    if [ "$CHECK_THRESHOLDS" = true ] && [ -f "coverage/lcov.info" ]; then
        echo ""
        echo "=============================================="
        echo "Coverage Threshold Check (minimum: ${MIN_COVERAGE}%)"
        echo "=============================================="

        PASSES=$(echo "$COVERAGE_PCT $MIN_COVERAGE" | awk '{print ($1 >= $2) ? "1" : "0"}')
        if [ "$PASSES" = "1" ]; then
            echo ""
            echo "  ✓ PASS: ${COVERAGE_PCT}% >= ${MIN_COVERAGE}%"
        else
            echo ""
            echo "  ✗ FAIL: ${COVERAGE_PCT}% < ${MIN_COVERAGE}%"
            EXIT_CODE=1
        fi
    fi
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "All checks passed!"
else
    echo ""
    echo "Some checks failed!"
fi

exit $EXIT_CODE
