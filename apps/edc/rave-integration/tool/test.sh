#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00005: Sponsor Configuration Detection Implementation
#   REQ-p00008: User Account Management
#
# Test script for rave-integration library.
# Runs Dart unit tests and integration tests against RAVE EDC.
# Uses Doppler internally for RAVE credentials.
# Optionally generates coverage reports.
#
# Usage:
#   ./tool/test.sh           # Run both unit and integration tests (default)
#   ./tool/test.sh -u        # Run unit tests only
#   ./tool/test.sh -i        # Run integration tests only
#   ./tool/test.sh -c        # Run with coverage

# Re-execute under Doppler if not already running with it.
# This makes RAVE credentials available for integration tests.
if [ -z "$DOPPLER_ENVIRONMENT" ]; then
    exec doppler run -- "$0" "$@"
fi

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
    echo "  -i, --integration    Run integration tests (auto-starts PostgreSQL + Firebase)"
    echo "  -c, --coverage       Run with coverage collection and reporting"
    echo "  --no-threshold       Skip coverage threshold checks (only with --coverage)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "If no test flags (-u/-i) are specified, both unit and integration tests are run."
    echo ""
    echo "Coverage Threshold: ${MIN_COVERAGE}%"
    echo ""
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
    echo "RAVE Integration Test Suite (with Coverage)"
else
    echo "RAVE Integration Test Suite"
fi
echo "=============================================="

# Clean up coverage directory if running with coverage
if [ "$WITH_COVERAGE" = true ]; then
    rm -rf coverage
    mkdir -p coverage
fi

UNIT_PASSED=true
INTEGRATION_PASSED=true

# Ensure dependencies are installed
echo ""
echo "Checking dependencies..."
dart pub get

# Build test commands based on coverage flag
# Doppler credentials are available via the self-invoking wrapper at the top
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

# Run integration tests (RAVE credentials available via Doppler wrapper)
if [ "$RUN_INTEGRATION" = true ]; then
    echo ""
    echo "Running integration tests..."
    echo ""

    if $TEST_CMD integration_test/; then
        echo "Integration tests passed!"
    else
        echo "Integration tests failed!"
        INTEGRATION_PASSED=false
    fi

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
