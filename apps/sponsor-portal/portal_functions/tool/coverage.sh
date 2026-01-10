#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00005: Sponsor Configuration Detection Implementation
#   REQ-p00008: User Account Management
#
# Coverage script for portal_functions
# Runs Dart tests with coverage and generates reports

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
CHECK_THRESHOLDS=true

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --unit           Run unit tests coverage only"
    echo "  -i, --integration    Run integration tests coverage only"
    echo "  --start-db           Start local PostgreSQL container before tests"
    echo "  --stop-db            Stop local PostgreSQL container after tests"
    echo "  --no-threshold       Skip coverage threshold checks"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "If no flags are specified, both unit and integration tests are run."
    echo ""
    echo "Coverage Threshold: ${MIN_COVERAGE}%"
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
    --no-threshold)
      CHECK_THRESHOLDS=false
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

# If no test flags specified, run both unit and integration tests
if [ "$RUN_UNIT" = false ] && [ "$RUN_INTEGRATION" = false ]; then
    RUN_UNIT=true
    RUN_INTEGRATION=true
fi

echo "=============================================="
echo "Portal Functions Coverage"
echo "=============================================="

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

EXIT_CODE=0

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
        echo "Error: docker-compose.db.yml not found"
        exit 1
    fi
fi

# Ensure dependencies are installed
echo ""
echo "Checking dependencies..."
dart pub get

# Run unit tests with coverage
if [ "$RUN_UNIT" = true ]; then
    echo ""
    echo "Running unit tests with coverage..."
    echo ""

    if dart test --coverage=coverage test/; then
        echo "Unit tests passed!"
    else
        echo "Unit tests failed!"
        EXIT_CODE=1
    fi

    # Convert to lcov format if format_coverage is available
    if command -v dart &> /dev/null && [ -d "coverage" ]; then
        echo ""
        echo "Generating lcov report..."
        dart pub global activate coverage 2>/dev/null || true
        dart pub global run coverage:format_coverage \
            --lcov \
            --in=coverage \
            --out=coverage/lcov-unit.info \
            --report-on=lib \
            --packages=.dart_tool/package_config.json 2>/dev/null || echo "Warning: Could not generate lcov report"
    fi
fi

# Run integration tests with coverage
if [ "$RUN_INTEGRATION" = true ]; then
    echo ""
    echo "Running integration tests with coverage..."
    echo ""

    # Check if PostgreSQL is accessible
    if ! docker exec sponsor-portal-postgres pg_isready -U postgres > /dev/null 2>&1; then
        if [ -z "$DB_HOST" ]; then
            echo "Error: PostgreSQL is not running"
            echo "Start it with: --start-db flag"
            exit 1
        fi
    fi

    if dart test --coverage=coverage integration_test/; then
        echo "Integration tests passed!"
    else
        echo "Integration tests failed!"
        EXIT_CODE=1
    fi

    # Convert to lcov format
    if command -v dart &> /dev/null && [ -d "coverage" ]; then
        echo ""
        echo "Generating integration lcov report..."
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

# Calculate coverage percentage
get_coverage_percentage() {
    local lcov_file="$1"
    if [ ! -f "$lcov_file" ]; then
        echo "0"
        return
    fi

    # Count total DA: lines and non-zero hits
    # Use awk for reliable cross-platform counting
    local lines_found
    local lines_hit
    lines_found=$(grep -c "^DA:" "$lcov_file" 2>/dev/null) || lines_found=0
    lines_hit=$(grep "^DA:" "$lcov_file" 2>/dev/null | grep -cv ",0$") || lines_hit=0

    # Ensure we have integers (strip any whitespace/newlines)
    lines_found=$(echo "$lines_found" | tr -d '[:space:]')
    lines_hit=$(echo "$lines_hit" | tr -d '[:space:]')

    # Default to 0 if empty
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

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "Coverage check failed!"
fi

exit $EXIT_CODE
