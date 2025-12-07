#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00004: Local-First Data Entry Implementation
#   REQ-d00005: Sponsor Configuration Detection Implementation
#
# Coverage script for clinical_diary
# Runs Flutter (Dart) and Firebase Functions (TypeScript) coverage
# Can combine coverage reports using lcov
# Works both locally and in CI/CD

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Parse command line arguments
CONCURRENCY="10"
RUN_FLUTTER_UNIT=false
RUN_FLUTTER_INTEGRATION=false
RUN_TYPESCRIPT=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f,  --flutter              Run all Flutter coverage (unit + integration)"
    echo "  -fu, --flutter-unit         Run Flutter unit tests coverage only"
    echo "  -fi, --flutter-integration  Run Flutter integration tests coverage on desktop"
    echo "  -t,  --typescript           Run TypeScript (Functions) coverage only"
    echo "  --concurrency N             Set Flutter unit test concurrency (default: 10)"
    echo "  -h,  --help                 Show this help message"
    echo ""
    echo "If no flags are specified, Flutter unit and TypeScript coverage are run."
    echo "Integration test coverage must be explicitly requested with -fi or -f."
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--flutter)
      RUN_FLUTTER_UNIT=true
      RUN_FLUTTER_INTEGRATION=true
      shift
      ;;
    -fu|--flutter-unit)
      RUN_FLUTTER_UNIT=true
      shift
      ;;
    -fi|--flutter-integration)
      RUN_FLUTTER_INTEGRATION=true
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

# If no flags specified, run Flutter unit and TypeScript (not integration by default)
if [ "$RUN_FLUTTER_UNIT" = false ] && [ "$RUN_FLUTTER_INTEGRATION" = false ] && [ "$RUN_TYPESCRIPT" = false ]; then
    RUN_FLUTTER_UNIT=true
    RUN_TYPESCRIPT=true
fi

echo "=============================================="
echo "Clinical Diary Coverage"
echo "=============================================="

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

FLUTTER_UNIT_COVERAGE=false
FLUTTER_INTEGRATION_COVERAGE=false
TS_COVERAGE=false

# Run Flutter unit test coverage
if [ "$RUN_FLUTTER_UNIT" = true ]; then
    echo ""
    echo "📱 Running Flutter unit tests with coverage..."
    echo "   Concurrency: $CONCURRENCY"
    echo ""

    flutter test --coverage --concurrency="$CONCURRENCY"

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

# Run TypeScript/Functions coverage
if [ "$RUN_TYPESCRIPT" = true ]; then
    echo ""
    echo "🔥 Running Firebase Functions tests with coverage..."
    echo ""

    if [ -d "functions" ]; then
        cd functions

        # Install dependencies if needed
        if [ ! -d "node_modules" ]; then
            echo "Installing dependencies..."
            npm install
        fi

        # Run tests with coverage
        npm run test:coverage

        if [ -f "coverage/lcov.info" ]; then
            TS_COVERAGE=true
            echo "✅ TypeScript coverage generated: functions/coverage/lcov.info"

            # Copy to main coverage directory with prefix
            mkdir -p ../coverage
            cp coverage/lcov.info ../coverage/lcov-functions.info

            # Copy Jest's HTML report if it exists
            if [ -d "coverage/lcov-report" ]; then
                cp -r coverage/lcov-report ../coverage/html-functions
                echo "✅ TypeScript HTML report: coverage/html-functions/index.html"
            fi
        fi

        cd ..
    else
        echo "⚠️  functions/ directory not found, skipping TypeScript coverage"
    fi
fi

# Combine all coverage reports if multiple were generated and lcov is available
COVERAGE_FILES_TO_COMBINE=""
if [ "$FLUTTER_UNIT_COVERAGE" = true ]; then
    COVERAGE_FILES_TO_COMBINE="$COVERAGE_FILES_TO_COMBINE coverage/lcov-unit.info"
fi
if [ "$FLUTTER_INTEGRATION_COVERAGE" = true ]; then
    COVERAGE_FILES_TO_COMBINE="$COVERAGE_FILES_TO_COMBINE coverage/lcov-integration.info"
fi
if [ "$TS_COVERAGE" = true ]; then
    COVERAGE_FILES_TO_COMBINE="$COVERAGE_FILES_TO_COMBINE coverage/lcov-functions.info"
fi

# Count how many coverage files we have
NUM_COVERAGE_FILES=$(echo "$COVERAGE_FILES_TO_COMBINE" | wc -w | tr -d ' ')

if [ "$NUM_COVERAGE_FILES" -gt 1 ] && command -v lcov &> /dev/null; then
    echo ""
    echo "📊 Combining coverage reports..."

    # Build lcov command with all files
    LCOV_CMD="lcov"
    for file in $COVERAGE_FILES_TO_COMBINE; do
        LCOV_CMD="$LCOV_CMD -a $file"
    done
    LCOV_CMD="$LCOV_CMD -o coverage/lcov-combined.info --ignore-errors unused"

    if eval "$LCOV_CMD" 2>/dev/null; then
        echo "✅ Combined coverage report: coverage/lcov-combined.info"
    fi
fi

# Also create a main lcov.info file (symlink to combined or first available)
if [ -f "coverage/lcov-combined.info" ]; then
    cp coverage/lcov-combined.info coverage/lcov.info
elif [ -f "coverage/lcov-unit.info" ]; then
    cp coverage/lcov-unit.info coverage/lcov.info
elif [ -f "coverage/lcov-integration.info" ]; then
    cp coverage/lcov-integration.info coverage/lcov.info
fi

# Generate HTML reports if lcov is available
# Note: Flutter and TypeScript use incompatible relative paths, so we generate separate HTML reports
FLUTTER_UNIT_HTML_GENERATED=false
FLUTTER_INTEGRATION_HTML_GENERATED=false
if command -v genhtml &> /dev/null; then
    # Generate Flutter unit HTML report if unit coverage exists
    if [ -f "coverage/lcov-unit.info" ]; then
        echo ""
        echo "🌐 Generating Flutter unit HTML report..."
        genhtml coverage/lcov-unit.info -o coverage/html-flutter-unit 2>/dev/null || true

        if [ -f "coverage/html-flutter-unit/index.html" ]; then
            FLUTTER_UNIT_HTML_GENERATED=true
            echo "✅ Flutter unit HTML report: coverage/html-flutter-unit/index.html"
        else
            echo "⚠️  Flutter unit HTML report generation failed (genhtml couldn't resolve source paths)"
        fi
    fi

    # Generate Flutter integration HTML report if integration coverage exists
    if [ -f "coverage/lcov-integration.info" ]; then
        echo ""
        echo "🌐 Generating Flutter integration HTML report..."
        genhtml coverage/lcov-integration.info -o coverage/html-flutter-integration 2>/dev/null || true

        if [ -f "coverage/html-flutter-integration/index.html" ]; then
            FLUTTER_INTEGRATION_HTML_GENERATED=true
            echo "✅ Flutter integration HTML report: coverage/html-flutter-integration/index.html"
        else
            echo "⚠️  Flutter integration HTML report generation failed (genhtml couldn't resolve source paths)"
        fi
    fi

    # Generate combined HTML report if combined coverage exists
    if [ -f "coverage/lcov-combined.info" ]; then
        echo ""
        echo "🌐 Generating combined Flutter HTML report..."
        genhtml coverage/lcov-combined.info -o coverage/html-flutter 2>/dev/null || true

        if [ -f "coverage/html-flutter/index.html" ]; then
            echo "✅ Combined Flutter HTML report: coverage/html-flutter/index.html"
        fi
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

if [ "$FLUTTER_UNIT_COVERAGE" = true ]; then
    echo "📱 Flutter Unit:        coverage/lcov-unit.info"
fi

if [ "$FLUTTER_INTEGRATION_COVERAGE" = true ]; then
    echo "🖥️  Flutter Integration: coverage/lcov-integration.info"
fi

if [ "$TS_COVERAGE" = true ]; then
    echo "🔥 Functions:           coverage/lcov-functions.info"
fi

if [ -f "coverage/lcov-combined.info" ]; then
    echo "📊 Combined:            coverage/lcov-combined.info"
fi

if [ -f "coverage/lcov.info" ]; then
    echo ""
    echo "📄 Main coverage file:  coverage/lcov.info"
fi

# Show available HTML reports (check for actual file existence)
HTML_REPORTS_FOUND=false

if [ -f "coverage/html-flutter/index.html" ]; then
    HTML_REPORTS_FOUND=true
    echo ""
    echo "To view combined Flutter HTML report:"
    echo "  open coverage/html-flutter/index.html (Mac)"
    echo "  xdg-open coverage/html-flutter/index.html (Linux)"
fi

if [ -f "coverage/html-flutter-unit/index.html" ]; then
    HTML_REPORTS_FOUND=true
    echo ""
    echo "To view Flutter unit HTML report:"
    echo "  open coverage/html-flutter-unit/index.html (Mac)"
    echo "  xdg-open coverage/html-flutter-unit/index.html (Linux)"
fi

if [ -f "coverage/html-flutter-integration/index.html" ]; then
    HTML_REPORTS_FOUND=true
    echo ""
    echo "To view Flutter integration HTML report:"
    echo "  open coverage/html-flutter-integration/index.html (Mac)"
    echo "  xdg-open coverage/html-flutter-integration/index.html (Linux)"
fi

if [ -f "coverage/html-functions/index.html" ]; then
    HTML_REPORTS_FOUND=true
    echo ""
    echo "To view Functions (TypeScript) HTML report:"
    echo "  open coverage/html-functions/index.html (Mac)"
    echo "  xdg-open coverage/html-functions/index.html (Linux)"
fi

if [ "$HTML_REPORTS_FOUND" = false ]; then
    if [ "$FLUTTER_UNIT_COVERAGE" = true ] || [ "$FLUTTER_INTEGRATION_COVERAGE" = true ]; then
        echo ""
        echo "💡 To generate HTML coverage reports for Flutter, install lcov:"
        echo "   brew install lcov (Mac) or sudo apt-get install lcov (Linux)"
    fi
    if [ "$TS_COVERAGE" = true ] && [ ! -f "coverage/html-functions/index.html" ]; then
        echo ""
        echo "⚠️  TypeScript HTML report not generated. Check functions/coverage/lcov-report/"
    fi
fi

exit 0
