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

# Coverage threshold (percentage)
MIN_COVERAGE=80

# Parse command line arguments
RUN_UNIT=false
RUN_INTEGRATION=false
START_DB=false
STOP_DB=false
WITH_COVERAGE=false
CHECK_THRESHOLDS=true

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --unit           Run unit tests only"
    echo "  -i, --integration    Run integration tests only (requires PostgreSQL)"
    echo "  -c, --coverage       Run with coverage collection and reporting"
    echo "  --no-threshold       Skip coverage threshold checks (only with --coverage)"
    echo "  --start-db           Start local PostgreSQL container before tests"
    echo "  --stop-db            Stop local PostgreSQL container after tests"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "If no test flags (-u/-i) are specified, both unit and integration tests are run."
    echo ""
    echo "Coverage Threshold: ${MIN_COVERAGE}%"
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
    -c|--coverage)
      WITH_COVERAGE=true
      shift
      ;;
    --no-threshold)
      CHECK_THRESHOLDS=false
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
if [ "$WITH_COVERAGE" = true ]; then
    echo "Portal Server Test Suite (with Coverage)"
else
    echo "Portal Server Test Suite"
fi
echo "=============================================="

# Clean up coverage directory if running with coverage
if [ "$WITH_COVERAGE" = true ]; then
    rm -rf coverage
    mkdir -p coverage
fi

# No PASSED tracking needed — set -e stops on first failure

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

# Build test command based on coverage flag
if [ "$WITH_COVERAGE" = true ]; then
    TEST_CMD="dart test --coverage=coverage"
else
    TEST_CMD="dart test"
fi

# Run unit tests
if [ "$RUN_UNIT" = true ]; then
    echo ""
    echo "Running unit tests..."
    echo ""

    $TEST_CMD test/

    # Generate lcov report for unit tests
    if [ "$WITH_COVERAGE" = true ] && [ -d "coverage" ]; then
        echo ""
        echo "Generating unit test lcov report..."
        dart pub global activate coverage 2>/dev/null || true
        dart pub global run coverage:format_coverage \
            --lcov \
            --in=coverage \
            --out=coverage/lcov-unit.info \
            --report-on=lib \
            --packages=.dart_tool/package_config.json 2>/dev/null || echo "Warning: Could not generate lcov report"
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

        $TEST_CMD integration_test/

        # Unset emulator for subsequent operations
        unset FIREBASE_AUTH_EMULATOR_HOST

        # Generate lcov report for integration tests
        if [ "$WITH_COVERAGE" = true ] && [ -d "coverage" ]; then
            echo ""
            echo "Generating integration test lcov report..."
            dart pub global run coverage:format_coverage \
                --lcov \
                --in=coverage \
                --out=coverage/lcov-integration.info \
                --report-on=lib \
                --packages=.dart_tool/package_config.json 2>/dev/null || echo "Warning: Could not generate lcov report"
        fi
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

# Coverage report generation and threshold checking
if [ "$WITH_COVERAGE" = true ]; then
    # Combine coverage reports if both exist
    if [ -f "coverage/lcov-unit.info" ] && [ -f "coverage/lcov-integration.info" ]; then
        if command -v lcov &> /dev/null; then
            echo ""
            echo "Combining coverage reports..."
            lcov -a coverage/lcov-unit.info -a coverage/lcov-integration.info \
                -o coverage/lcov.info --ignore-errors unused 2>/dev/null || true
        fi
    elif [ -f "coverage/lcov-unit.info" ]; then
        cp coverage/lcov-unit.info coverage/lcov.info 2>/dev/null || true
    elif [ -f "coverage/lcov-integration.info" ]; then
        cp coverage/lcov-integration.info coverage/lcov.info 2>/dev/null || true
    fi

    # Generate HTML report if genhtml is available
    if [ -f "coverage/lcov.info" ] && command -v genhtml &> /dev/null; then
        echo ""
        echo "Generating HTML report..."
        genhtml coverage/lcov.info -o coverage/html 2>/dev/null || echo "Warning: Could not generate HTML report"
        if [ -f "coverage/html/index.html" ]; then
            echo "HTML report: coverage/html/index.html"
        fi
    fi
fi

# If we get here, all tests passed (set -e would have stopped us)

echo ""
echo "=============================================="
echo "All tests passed!"
echo "=============================================="

EXIT_CODE=0

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
    echo "Coverage Summary"
    echo "=============================================="

    COVERAGE_PCT="0"
    if [ -f "coverage/lcov.info" ]; then
        COVERAGE_PCT=$(get_coverage_percentage "coverage/lcov.info")
        echo ""
        echo "Total Coverage: ${COVERAGE_PCT}%"
        echo "Report: coverage/lcov.info"
    fi

    # Check coverage thresholds
    if [ "$CHECK_THRESHOLDS" = true ] && [ -f "coverage/lcov.info" ]; then
        echo ""
        echo "=============================================="
        echo "Coverage Threshold Check"
        echo "=============================================="

        PASSES=$(echo "$COVERAGE_PCT $MIN_COVERAGE" | awk '{print ($1 >= $2) ? "1" : "0"}')
        if [ "$PASSES" = "1" ]; then
            echo "PASS: ${COVERAGE_PCT}% >= ${MIN_COVERAGE}%"
        else
            echo "FAIL: ${COVERAGE_PCT}% < ${MIN_COVERAGE}%"
            EXIT_CODE=1
        fi
    fi
fi

exit $EXIT_CODE
