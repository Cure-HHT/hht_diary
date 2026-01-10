#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00005: Sponsor Configuration Detection Implementation
#   REQ-p00008: User Account Management
#
# Test script for portal_functions
# Runs Dart unit tests and integration tests against PostgreSQL
# Optionally generates coverage reports

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Coverage threshold (percentage)
MIN_COVERAGE=85

# Parse command line arguments
RUN_UNIT=false
RUN_INTEGRATION=false
START_DB=false
STOP_DB=false
WITH_COVERAGE=false
CHECK_THRESHOLDS=true
STARTED_EMULATOR=false

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
    echo "If no test flags (-u/-i) are specified, unit tests are run."
    echo "With --coverage, both unit and integration tests are run by default."
    echo ""
    echo "Coverage Threshold: ${MIN_COVERAGE}%"
    echo ""
    echo "Note: Firebase Auth emulator is auto-started for integration tests."
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

# Default behavior depends on coverage mode
if [ "$RUN_UNIT" = false ] && [ "$RUN_INTEGRATION" = false ]; then
    if [ "$WITH_COVERAGE" = true ]; then
        # Coverage mode: run both by default
        RUN_UNIT=true
        RUN_INTEGRATION=true
    else
        # Normal mode: run unit tests only by default
        RUN_UNIT=true
    fi
fi

echo "=============================================="
if [ "$WITH_COVERAGE" = true ]; then
    echo "Portal Functions Test Suite (with Coverage)"
else
    echo "Portal Functions Test Suite"
fi
echo "=============================================="

# Clean up coverage directory if running with coverage
if [ "$WITH_COVERAGE" = true ]; then
    rm -rf coverage
    mkdir -p coverage
fi

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

# Start Firebase emulator if integration tests will run
if [ "$RUN_INTEGRATION" = true ]; then
    FIREBASE_COMPOSE="$SCRIPT_DIR/../../../tools/dev-env/docker-compose.firebase.yml"

    if curl -s http://localhost:9099/ > /dev/null 2>&1; then
        echo ""
        echo "Firebase Auth emulator already running at localhost:9099"
    else
        echo ""
        echo "Starting Firebase Auth emulator..."
        if [ -f "$FIREBASE_COMPOSE" ]; then
            (cd "$(dirname "$FIREBASE_COMPOSE")" && docker compose -f docker-compose.firebase.yml up -d)
            STARTED_EMULATOR=true

            # Wait for emulator to be ready
            echo "Waiting for Firebase Auth emulator..."
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
                echo "Timeout waiting for Firebase Auth emulator"
                exit 1
            fi
        else
            echo "Error: docker-compose.firebase.yml not found at $FIREBASE_COMPOSE"
            exit 1
        fi
    fi
fi

# Ensure dependencies are installed
echo ""
echo "Checking dependencies..."
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

    if $TEST_CMD test/; then
        echo "Unit tests passed!"
    else
        echo "Unit tests failed!"
        UNIT_PASSED=false
    fi

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

    # Check if PostgreSQL is accessible
    if ! docker exec sponsor-portal-postgres pg_isready -U postgres > /dev/null 2>&1; then
        if [ -z "$DB_HOST" ]; then
            echo "Error: PostgreSQL is not running"
            echo "Start it with: --start-db flag or manually with docker compose"
            exit 1
        fi
    fi

    # Set Firebase emulator for integration tests
    echo "Running with Firebase Auth emulator..."
    export FIREBASE_AUTH_EMULATOR_HOST="localhost:9099"

    if $TEST_CMD integration_test/; then
        echo "Integration tests passed!"
    else
        echo "Integration tests failed!"
        INTEGRATION_PASSED=false
    fi

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

# Stop database if requested
if [ "$STOP_DB" = true ]; then
    echo ""
    echo "Stopping PostgreSQL container..."
    COMPOSE_FILE="$(cd "$SCRIPT_DIR/../../../tools/dev-env" && pwd)/docker-compose.db.yml"

    if [ -f "$COMPOSE_FILE" ]; then
        (cd "$(dirname "$COMPOSE_FILE")" && doppler run -- docker compose -f docker-compose.db.yml down)
    fi
fi

# Stop Firebase emulator if we started it
if [ "$STARTED_EMULATOR" = true ]; then
    echo ""
    echo "Stopping Firebase Auth emulator..."
    FIREBASE_COMPOSE="$SCRIPT_DIR/../../../tools/dev-env/docker-compose.firebase.yml"

    if [ -f "$FIREBASE_COMPOSE" ]; then
        (cd "$(dirname "$FIREBASE_COMPOSE")" && docker compose -f docker-compose.firebase.yml down)
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

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "All checks passed!"
else
    echo ""
    echo "Some checks failed!"
fi

exit $EXIT_CODE
