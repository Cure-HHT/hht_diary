#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00004: Local-First Data Entry Implementation
#   REQ-d00005: Sponsor Configuration Detection Implementation
#
# Test script for clinical_diary
# Runs Flutter (Dart) tests with optional coverage
# Works both locally and in CI/CD

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Coverage threshold (percentage)
MIN_COVERAGE=75

# Parse command line arguments
CONCURRENCY="10"
RUN_UNIT=false
RUN_INTEGRATION=false
WITH_COVERAGE=false
CHECK_THRESHOLDS=true

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --unit           Run unit tests only"
    echo "  -i, --integration    Run integration tests only (desktop)"
    echo "  -c, --coverage       Run with coverage collection and reporting"
    echo "  --concurrency N      Set test concurrency (default: 10)"
    echo "  --no-threshold       Skip coverage threshold checks (only with --coverage)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "If no test flags (-u/-i) are specified, both unit and integration tests are run."
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
    echo "Clinical Diary Test Suite (with Coverage)"
else
    echo "Clinical Diary Test Suite"
fi
echo "=============================================="

# Clean up coverage directory if running with coverage
if [ "$WITH_COVERAGE" = true ]; then
    rm -rf coverage
    mkdir -p coverage
fi

UNIT_PASSED=true
INTEGRATION_PASSED=true
UNIT_COVERAGE=false
INTEGRATION_COVERAGE=false
EXIT_CODE=0

# Build test command based on coverage flag
if [ "$WITH_COVERAGE" = true ]; then
    FLUTTER_TEST_CMD="flutter test --coverage"
else
    FLUTTER_TEST_CMD="flutter test"
fi

# Run unit tests
if [ "$RUN_UNIT" = true ]; then
    echo ""
    echo "Running unit tests..."
    echo "   Concurrency: $CONCURRENCY"
    echo ""

    if $FLUTTER_TEST_CMD --concurrency="$CONCURRENCY"; then
        echo "Unit tests passed!"
    else
        echo "Unit tests failed!"
        UNIT_PASSED=false
        EXIT_CODE=1
    fi

    # Handle coverage file if generated
    if [ "$WITH_COVERAGE" = true ] && [ -f "coverage/lcov.info" ]; then
        UNIT_COVERAGE=true
        mv coverage/lcov.info coverage/lcov-unit.info
        echo "Coverage generated: coverage/lcov-unit.info"

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

# Run integration tests on desktop
if [ "$RUN_INTEGRATION" = true ]; then
    echo ""
    echo "Running integration tests on desktop..."
    echo ""

    # Detect platform and set device target
    XVFB_PREFIX=""
    case "$(uname -s)" in
        Darwin*)
            DEVICE="macos"
            ;;
        Linux*)
            DEVICE="linux"
            # Use xvfb-run for headless Linux (CI) if available
            if command -v xvfb-run &> /dev/null; then
                XVFB_PREFIX="xvfb-run -a"
                echo "   Using xvfb-run for headless display"
            fi
            ;;
        MINGW*|CYGWIN*|MSYS*)
            DEVICE="windows"
            ;;
        *)
            echo "Unknown platform, defaulting to linux"
            DEVICE="linux"
            ;;
    esac

    echo "   Target device: $DEVICE"

    if [ -d "integration_test" ]; then
        INTEGRATION_FAILED=false
        INTEGRATION_COVERAGE_FILES=""
        FILE_INDEX=0

        for test_file in integration_test/*_test.dart; do
            if [ -f "$test_file" ]; then
                echo ""
                echo "   Running: $test_file"
                FILE_INDEX=$((FILE_INDEX + 1))

                if [ "$WITH_COVERAGE" = true ]; then
                    if $XVFB_PREFIX flutter test "$test_file" -d "$DEVICE" --coverage; then
                        if [ -f "coverage/lcov.info" ]; then
                            mv coverage/lcov.info "coverage/lcov-integration-$FILE_INDEX.info"
                            INTEGRATION_COVERAGE_FILES="$INTEGRATION_COVERAGE_FILES coverage/lcov-integration-$FILE_INDEX.info"
                        fi
                    else
                        INTEGRATION_FAILED=true
                    fi
                else
                    if ! $XVFB_PREFIX flutter test "$test_file" -d "$DEVICE"; then
                        INTEGRATION_FAILED=true
                    fi
                fi
            fi
        done

        if [ "$INTEGRATION_FAILED" = true ]; then
            echo "Integration tests failed!"
            INTEGRATION_PASSED=false
            EXIT_CODE=1
        else
            echo "Integration tests passed!"
        fi

        # Combine integration coverage files if lcov is available
        if [ "$WITH_COVERAGE" = true ] && [ -n "$INTEGRATION_COVERAGE_FILES" ] && command -v lcov &> /dev/null; then
            echo ""
            echo "Combining integration test coverage..."
            LCOV_CMD="lcov"
            for file in $INTEGRATION_COVERAGE_FILES; do
                LCOV_CMD="$LCOV_CMD -a $file"
            done
            LCOV_CMD="$LCOV_CMD -o coverage/lcov-integration.info --ignore-errors unused"

            if eval "$LCOV_CMD" 2>/dev/null; then
                INTEGRATION_COVERAGE=true
                rm -f $INTEGRATION_COVERAGE_FILES

                # Filter out generated files
                lcov --remove coverage/lcov-integration.info \
                  '**/*.g.dart' \
                  '**/*.freezed.dart' \
                  '**/test/**' \
                  '**/integration_test/**' \
                  --ignore-errors unused \
                  -o coverage/lcov-integration.info 2>/dev/null || true
            fi
        fi
    else
        echo "integration_test/ directory not found, skipping integration tests"
    fi
fi

# Combine coverage reports if running with coverage
if [ "$WITH_COVERAGE" = true ]; then
    COVERAGE_FILES=""
    if [ "$UNIT_COVERAGE" = true ]; then
        COVERAGE_FILES="$COVERAGE_FILES coverage/lcov-unit.info"
    fi
    if [ "$INTEGRATION_COVERAGE" = true ]; then
        COVERAGE_FILES="$COVERAGE_FILES coverage/lcov-integration.info"
    fi

    NUM_FILES=$(echo "$COVERAGE_FILES" | wc -w | tr -d ' ')

    if [ "$NUM_FILES" -gt 1 ] && command -v lcov &> /dev/null; then
        echo ""
        echo "Combining coverage reports (unit + integration)..."
        LCOV_CMD="lcov"
        for file in $COVERAGE_FILES; do
            LCOV_CMD="$LCOV_CMD -a $file"
        done
        LCOV_CMD="$LCOV_CMD -o coverage/lcov.info --ignore-errors unused"
        eval "$LCOV_CMD" 2>/dev/null || true
    elif [ "$NUM_FILES" -eq 1 ]; then
        cp $COVERAGE_FILES coverage/lcov.info
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

if [ "$RUN_UNIT" = true ]; then
    if [ "$UNIT_PASSED" = true ]; then
        echo "Unit Tests: PASSED"
    else
        echo "Unit Tests: FAILED"
    fi
fi

if [ "$RUN_INTEGRATION" = true ]; then
    if [ "$INTEGRATION_PASSED" = true ]; then
        echo "Integration Tests: PASSED"
    else
        echo "Integration Tests: FAILED"
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

        if [ -f "coverage/lcov-unit.info" ]; then
            UNIT_PCT=$(get_coverage_percentage "coverage/lcov-unit.info")
            echo "  Unit tests:        ${UNIT_PCT}%"
        fi
        if [ -f "coverage/lcov-integration.info" ]; then
            INT_PCT=$(get_coverage_percentage "coverage/lcov-integration.info")
            echo "  Integration tests: ${INT_PCT}%"
        fi
    fi

    # Check coverage threshold
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
