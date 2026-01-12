#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00005: Sponsor Configuration Detection Implementation
#   REQ-p00008: User Account Management
#
# Test script for portal_server
# Runs Dart unit tests and integration tests against PostgreSQL
# Works both locally and in CI/CD

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Parse command line arguments
RUN_UNIT=false
RUN_INTEGRATION=false
START_DB=false
STOP_DB=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --unit           Run unit tests only"
    echo "  -i, --integration    Run integration tests only (requires PostgreSQL)"
    echo "  --start-db           Start local PostgreSQL container before tests"
    echo "  --stop-db            Stop local PostgreSQL container after tests"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "If no test flags (-u/-i) are specified, both unit and integration tests are run."
    echo ""
    echo "Integration tests require PostgreSQL. Either:"
    echo "  1. Use --start-db to auto-start the container"
    echo "  2. Start manually: doppler run -- docker compose -f ../../tools/dev-env/docker-compose.db.yml up -d"
    echo "  3. In CI: PostgreSQL is provided as a GitHub Actions service"
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
    --start-db)
      START_DB=true
      shift
      ;;
    --stop-db)
      STOP_DB=true
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

# Default: run both unit and integration tests
if [ "$RUN_UNIT" = false ] && [ "$RUN_INTEGRATION" = false ]; then
    RUN_UNIT=true
    RUN_INTEGRATION=true
fi

echo "=============================================="
echo "Portal Server Test Suite"
echo "=============================================="

UNIT_PASSED=true
INTEGRATION_PASSED=true

# Start database if requested
if [ "$START_DB" = true ]; then
    echo ""
    echo "Starting PostgreSQL container..."
    COMPOSE_FILE="$(cd "$SCRIPT_DIR/../../../tools/dev-env" && pwd)/docker-compose.db.yml"

    if [ -f "$COMPOSE_FILE" ]; then
        (cd "$(dirname "$COMPOSE_FILE")" && doppler run -- docker compose -f docker-compose.db.yml up -d)

        # Wait for database to be ready
        echo "Waiting for PostgreSQL to be ready..."
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
        echo "Error: docker-compose.db.yml not found at $COMPOSE_FILE"
        exit 1
    fi
fi

# Ensure dependencies are installed
echo ""
echo "Checking dependencies..."
dart pub get --directory=../portal_functions
dart pub get

# Run unit tests
if [ "$RUN_UNIT" = true ]; then
    echo ""
    echo "Running unit tests..."
    echo ""

    if dart test test/; then
        echo "Unit tests passed!"
    else
        echo "Unit tests failed!"
        UNIT_PASSED=false
    fi
fi

# Run integration tests
if [ "$RUN_INTEGRATION" = true ]; then
    echo ""
    echo "Running integration tests..."
    echo ""

    # Check if there are any integration test files
    if ! find integration_test -name '*_test.dart' 2>/dev/null | grep -q .; then
        echo "No integration tests found (directory is empty)"
        echo "Skipping integration tests"
    else
        # Check if PostgreSQL is accessible
        if ! docker exec sponsor-portal-postgres pg_isready -U postgres > /dev/null 2>&1; then
            # Try CI environment variables
            if [ -n "$DB_HOST" ]; then
                echo "Using CI database configuration"
            else
                echo "Error: PostgreSQL is not running"
                echo "Start it with: --start-db flag or manually with docker compose"
                exit 1
            fi
        fi

        # Set environment for integration tests
        echo "Running with Firebase Auth emulator..."
        export FIREBASE_AUTH_EMULATOR_HOST="localhost:9099"
        export DB_SSL="false"

        # Export DB password for tests
        if [ -z "$DB_PASSWORD" ]; then
            DB_PASSWORD=$(doppler secrets get LOCAL_DB_ROOT_PASSWORD --plain 2>/dev/null || echo "postgres")
        fi
        export DB_PASSWORD

        if dart test integration_test/; then
            echo "Integration tests passed!"
        else
            echo "Integration tests failed!"
            INTEGRATION_PASSED=false
        fi

        # Unset emulator for subsequent operations
        unset FIREBASE_AUTH_EMULATOR_HOST
    fi
fi

# Stop database if requested
if [ "$STOP_DB" = true ]; then
    echo ""
    echo "Stopping PostgreSQL container..."
    COMPOSE_FILE="$(cd "$SCRIPT_DIR/../../../tools/dev-env" && pwd)/docker-compose.db.yml"

    if [ -f "$COMPOSE_FILE" ]; then
        (cd "$(dirname "$COMPOSE_FILE")" && doppler run -- docker compose -f docker-compose.db.yml down)
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

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "All tests passed!"
else
    echo ""
    echo "Some tests failed!"
fi

exit $EXIT_CODE
