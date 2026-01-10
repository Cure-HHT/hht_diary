#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-p00009: Sponsor-Specific Web Portals
#   REQ-p00024: Portal User Roles and Permissions
#   REQ-d00028: Portal Frontend Framework
#
# Coverage script for portal-ui
# Runs Flutter (Dart) and Firebase Functions (TypeScript) coverage
# Generates combined reports per technology stack:
#   - Flutter: unit + integration tests combined
#   - TypeScript: unit + integration tests combined (future)
# Each stack has its own minimum coverage threshold
# Works both locally and in CI/CD

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Coverage thresholds (percentage)
FLUTTER_MIN_COVERAGE=75
TYPESCRIPT_MIN_COVERAGE=95

# Parse command line arguments
CONCURRENCY="10"
RUN_FLUTTER_UNIT=false
RUN_FLUTTER_INTEGRATION=false
RUN_TYPESCRIPT=false
CHECK_THRESHOLDS=true

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f,  --flutter              Run all Flutter coverage (unit + integration)"
    echo "  -fu, --flutter-unit         Run Flutter unit tests coverage only"
    echo "  -fi, --flutter-integration  Run Flutter integration tests coverage on desktop"
    echo "  -t,  --typescript           Run TypeScript (Functions) coverage only"
    echo "  --concurrency N             Set Flutter unit test concurrency (default: 10)"
    echo "  --no-threshold              Skip coverage threshold checks"
    echo "  -h,  --help                 Show this help message"
    echo ""
    echo "If no flags are specified, all tests are run (Flutter unit + integration + TypeScript)."
    echo ""
    echo "Coverage Thresholds:"
    echo "  Flutter:    ${FLUTTER_MIN_COVERAGE}%"
    echo "  TypeScript: ${TYPESCRIPT_MIN_COVERAGE}%"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--flutter)
      RUN_FLUTTER_UNIT=true
      RUN_FLUTTER_INTEGRATION=false #TODO add back in when there are integration tests
      shift
      ;;
    -fu|--flutter-unit)
      RUN_FLUTTER_UNIT=true
      shift
      ;;
    -fi|--flutter-integration)
      RUN_FLUTTER_INTEGRATION=false #TODO add back in when there are integration tests
      shift
      ;;
    -t|--typescript)
      RUN_TYPESCRIPT=true
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

# If no flags specified, run ALL tests (Flutter unit + integration + TypeScript)
if [ "$RUN_FLUTTER_UNIT" = false ] && [ "$RUN_FLUTTER_INTEGRATION" = false ] && [ "$RUN_TYPESCRIPT" = false ]; then
    RUN_FLUTTER_UNIT=true
    RUN_FLUTTER_INTEGRATION=false #TODO add back in when there are integration tests
fi

echo "=============================================="
echo "Clinical Diary Coverage"
echo "=============================================="

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

FLUTTER_UNIT_COVERAGE=false
FLUTTER_INTEGRATION_COVERAGE=false
EXIT_CODE=0

# Run Flutter unit test coverage
if [ "$RUN_FLUTTER_UNIT" = true ]; then
    echo ""
    echo "📱 Running Flutter unit tests with coverage..."
    echo "   Concurrency: $CONCURRENCY"
    echo ""

    if ! flutter test --coverage --concurrency="$CONCURRENCY"; then
        echo "❌ Flutter unit tests failed!"
        EXIT_CODE=1
    fi

    if [ -f "coverage/lcov.info" ]; then
        FLUTTER_UNIT_COVERAGE=true
        # Rename to lcov-unit.info for clarity when combining
        mv coverage/lcov.info coverage/lcov-unit.info
        echo "✅ Flutter unit coverage generated: coverage/lcov-unit.info"

        # Filter out generated files
        if command -v lcov &> /dev/null; then
            echo "Filtering coverage data..."
            lcov --remove coverage/lcov-unit.info \
              '**/*.g.dart' \
              '**/*.freezed.dart' \
              '**/test/**' \
              --ignore-errors unused \
              -o coverage/lcov-unit.info
        fi
    fi
fi

# Run Flutter integration test coverage on desktop
if [ "$RUN_FLUTTER_INTEGRATION" = true ]; then
    echo ""
    echo "🖥️  Running Flutter integration tests with coverage on desktop..."
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
            echo "⚠️  Unknown platform, defaulting to linux"
            DEVICE="linux"
            ;;
    esac

    echo "   Target device: $DEVICE"

    if [ -d "integration_test" ]; then
        # Run each integration test file separately to avoid macOS app lifecycle issues
        # Collect coverage for each file and merge them
        INTEGRATION_COVERAGE_FILES=""
        FILE_INDEX=0

        for test_file in integration_test/*_test.dart; do
            if [ -f "$test_file" ]; then
                echo ""
                echo "   Running: $test_file"
                FILE_INDEX=$((FILE_INDEX + 1))

                # Run with coverage, output to numbered file
                if $XVFB_PREFIX flutter test "$test_file" -d "$DEVICE" --coverage; then
                    if [ -f "coverage/lcov.info" ]; then
                        mv coverage/lcov.info "coverage/lcov-integration-$FILE_INDEX.info"
                        INTEGRATION_COVERAGE_FILES="$INTEGRATION_COVERAGE_FILES coverage/lcov-integration-$FILE_INDEX.info"
                        echo "   ✅ Coverage captured for $test_file"
                    fi
                else
                    echo "   ⚠️  Test failed: $test_file (continuing with other tests)"
                fi
            fi
        done

        # Combine integration test coverage files if lcov is available
        if [ -n "$INTEGRATION_COVERAGE_FILES" ] && command -v lcov &> /dev/null; then
            echo ""
            echo "   Combining integration test coverage..."
            # Build lcov command with all files
            LCOV_CMD="lcov"
            for file in $INTEGRATION_COVERAGE_FILES; do
                LCOV_CMD="$LCOV_CMD -a $file"
            done
            LCOV_CMD="$LCOV_CMD -o coverage/lcov-integration.info --ignore-errors unused"

            if eval "$LCOV_CMD" 2>/dev/null; then
                FLUTTER_INTEGRATION_COVERAGE=true
                echo "✅ Flutter integration coverage generated: coverage/lcov-integration.info"

                # Clean up individual files
                rm -f $INTEGRATION_COVERAGE_FILES

                # Filter out generated files
                lcov --remove coverage/lcov-integration.info \
                  '**/*.g.dart' \
                  '**/*.freezed.dart' \
                  '**/test/**' \
                  '**/integration_test/**' \
                  --ignore-errors unused \
                  -o coverage/lcov-integration.info
            fi
        elif [ -n "$INTEGRATION_COVERAGE_FILES" ]; then
            echo ""
            echo "⚠️  lcov not found - cannot combine integration coverage files"
            echo "   Install lcov: brew install lcov (Mac) or sudo apt-get install lcov (Linux)"
        fi
    else
        echo "⚠️  integration_test/ directory not found, skipping integration coverage"
    fi
fi

# Combine Flutter coverage reports (unit + integration) into one Flutter report
FLUTTER_COVERAGE_FILES=""
if [ "$FLUTTER_UNIT_COVERAGE" = true ]; then
    FLUTTER_COVERAGE_FILES="$FLUTTER_COVERAGE_FILES coverage/lcov-unit.info"
fi
if [ "$FLUTTER_INTEGRATION_COVERAGE" = true ]; then
    FLUTTER_COVERAGE_FILES="$FLUTTER_COVERAGE_FILES coverage/lcov-integration.info"
fi

FLUTTER_COMBINED_COVERAGE=false
NUM_FLUTTER_FILES=$(echo "$FLUTTER_COVERAGE_FILES" | wc -w | tr -d ' ')

if [ "$NUM_FLUTTER_FILES" -gt 1 ] && command -v lcov &> /dev/null; then
    echo ""
    echo "📊 Combining Flutter coverage reports (unit + integration)..."

    # Build lcov command with all Flutter files
    LCOV_CMD="lcov"
    for file in $FLUTTER_COVERAGE_FILES; do
        LCOV_CMD="$LCOV_CMD -a $file"
    done
    LCOV_CMD="$LCOV_CMD -o coverage/lcov-flutter.info --ignore-errors unused"

    if eval "$LCOV_CMD" 2>/dev/null; then
        FLUTTER_COMBINED_COVERAGE=true
        echo "✅ Combined Flutter coverage: coverage/lcov-flutter.info"
    fi
elif [ "$NUM_FLUTTER_FILES" -eq 1 ]; then
    # Only one Flutter coverage file, just copy it
    cp $FLUTTER_COVERAGE_FILES coverage/lcov-flutter.info
    FLUTTER_COMBINED_COVERAGE=true
    echo "✅ Flutter coverage: coverage/lcov-flutter.info"
fi

# Create main lcov.info file from Flutter coverage (primary report)
if [ -f "coverage/lcov-flutter.info" ]; then
    cp coverage/lcov-flutter.info coverage/lcov.info
elif [ -f "coverage/lcov-unit.info" ]; then
    cp coverage/lcov-unit.info coverage/lcov.info
fi

# Function to extract coverage percentage from lcov file
get_coverage_percentage() {
    local lcov_file="$1"
    if [ ! -f "$lcov_file" ]; then
        echo "0"
        return
    fi

    local lines_found=$(grep -c "^DA:" "$lcov_file" 2>/dev/null || echo "0")
    local lines_hit=$(grep "^DA:" "$lcov_file" 2>/dev/null | grep -v ",0$" | wc -l | tr -d ' ')

    if [ "$lines_found" -eq 0 ]; then
        echo "0"
    else
        # Use awk for floating point math, round to 1 decimal
        echo "$lines_hit $lines_found" | awk '{printf "%.1f", ($1/$2)*100}'
    fi
}

# Generate HTML reports if lcov is available
# Note: Flutter and TypeScript use incompatible relative paths, so we generate separate HTML reports
FLUTTER_HTML_GENERATED=false
if command -v genhtml &> /dev/null; then
    # Generate combined Flutter HTML report (primary report)
    if [ -f "coverage/lcov-flutter.info" ]; then
        echo ""
        echo "🌐 Generating Flutter HTML report..."
        genhtml coverage/lcov-flutter.info -o coverage/html-flutter 2>/dev/null || true

        if [ -f "coverage/html-flutter/index.html" ]; then
            FLUTTER_HTML_GENERATED=true
            echo "✅ Flutter HTML report: coverage/html-flutter/index.html"
        else
            echo "⚠️  Flutter HTML report generation failed (genhtml couldn't resolve source paths)"
        fi
    fi

    # Also generate separate unit/integration reports for detailed analysis
    if [ -f "coverage/lcov-unit.info" ]; then
        genhtml coverage/lcov-unit.info -o coverage/html-flutter-unit 2>/dev/null || true
    fi
    if [ -f "coverage/lcov-integration.info" ]; then
        genhtml coverage/lcov-integration.info -o coverage/html-flutter-integration 2>/dev/null || true
    fi
else
    echo ""
    echo "⚠️  genhtml not found. Install lcov for Flutter HTML reports:"
    echo "   brew install lcov (Mac) or sudo apt-get install lcov (Linux)"
    echo "   (TypeScript HTML reports are still available via Jest)"
fi

echo ""
echo "=============================================="
echo "Coverage Summary"
echo "=============================================="

# Calculate and display Flutter coverage
FLUTTER_COVERAGE_PCT="0"
if [ -f "coverage/lcov-flutter.info" ]; then
    FLUTTER_COVERAGE_PCT=$(get_coverage_percentage "coverage/lcov-flutter.info")
    echo ""
    echo "📱 Flutter (unit + integration): ${FLUTTER_COVERAGE_PCT}%"
    echo "   Report: coverage/lcov-flutter.info"
    if [ -f "coverage/lcov-unit.info" ]; then
        UNIT_PCT=$(get_coverage_percentage "coverage/lcov-unit.info")
        echo "   └─ Unit tests:        ${UNIT_PCT}%"
    fi
    if [ -f "coverage/lcov-integration.info" ]; then
        INT_PCT=$(get_coverage_percentage "coverage/lcov-integration.info")
        echo "   └─ Integration tests: ${INT_PCT}%"
    fi
fi

# Show HTML reports
echo ""
echo "HTML Reports:"
if [ -f "coverage/html-flutter/index.html" ]; then
    echo "  📊 Flutter:    coverage/html-flutter/index.html"
fi
if [ -f "coverage/html-functions/index.html" ]; then
    echo "  📊 TypeScript: coverage/html-functions/index.html"
fi

# Check coverage thresholds
THRESHOLD_FAILED=false
if [ "$CHECK_THRESHOLDS" = true ]; then
    echo ""
    echo "=============================================="
    echo "Coverage Threshold Check"
    echo "=============================================="

    # Check Flutter threshold
    if [ -f "coverage/lcov-flutter.info" ]; then
        FLUTTER_PASSES=$(echo "$FLUTTER_COVERAGE_PCT $FLUTTER_MIN_COVERAGE" | awk '{print ($1 >= $2) ? "1" : "0"}')
        if [ "$FLUTTER_PASSES" = "1" ]; then
            echo "✅ Flutter: ${FLUTTER_COVERAGE_PCT}% >= ${FLUTTER_MIN_COVERAGE}% (PASS)"
        else
            echo "❌ Flutter: ${FLUTTER_COVERAGE_PCT}% < ${FLUTTER_MIN_COVERAGE}% (FAIL)"
            THRESHOLD_FAILED=true
            EXIT_CODE=1
        fi
    fi
fi

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "💥 Coverage check failed!"
    if [ "$THRESHOLD_FAILED" = true ]; then
        echo "   One or more coverage thresholds were not met."
        echo "   Add more tests or use --no-threshold to skip checks."
    fi
fi

exit $EXIT_CODE
