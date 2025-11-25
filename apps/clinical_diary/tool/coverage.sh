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
RUN_FLUTTER=false
RUN_TYPESCRIPT=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f, --flutter      Run Flutter (Dart) coverage only"
    echo "  -t, --typescript   Run TypeScript (Functions) coverage only"
    echo "  --concurrency N    Set Flutter test concurrency (default: 10)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "If neither -f nor -t is specified, both test suites are run"
    echo "and coverage reports are combined (if lcov is installed)."
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--flutter)
      RUN_FLUTTER=true
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

# If neither flag specified, run both
if [ "$RUN_FLUTTER" = false ] && [ "$RUN_TYPESCRIPT" = false ]; then
    RUN_FLUTTER=true
    RUN_TYPESCRIPT=true
fi

echo "=============================================="
echo "Clinical Diary Coverage"
echo "=============================================="

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

FLUTTER_COVERAGE=false
TS_COVERAGE=false

# Run Flutter coverage
if [ "$RUN_FLUTTER" = true ]; then
    echo ""
    echo "📱 Running Flutter tests with coverage..."
    echo "   Concurrency: $CONCURRENCY"
    echo ""

    flutter test --coverage --concurrency="$CONCURRENCY"

    if [ -f "coverage/lcov.info" ]; then
        FLUTTER_COVERAGE=true
        echo "✅ Flutter coverage generated: coverage/lcov.info"

        # Filter out generated files
        if command -v lcov &> /dev/null; then
            echo "Filtering coverage data..."
            lcov --remove coverage/lcov.info \
              '**/*.g.dart' \
              '**/*.freezed.dart' \
              '**/test/**' \
              --ignore-errors unused \
              -o coverage/lcov.info
        fi
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

# Combine coverage reports if both were generated and lcov is available
if [ "$FLUTTER_COVERAGE" = true ] && [ "$TS_COVERAGE" = true ]; then
    if command -v lcov &> /dev/null; then
        echo ""
        echo "📊 Combining coverage reports..."

        # Combine the coverage files
        lcov -a coverage/lcov.info -a coverage/lcov-functions.info \
             -o coverage/lcov-combined.info \
             --ignore-errors unused 2>/dev/null || true

        if [ -f "coverage/lcov-combined.info" ]; then
            echo "✅ Combined coverage report: coverage/lcov-combined.info"
        fi
    fi
fi

# Generate HTML reports if lcov is available
# Note: Flutter and TypeScript use incompatible relative paths, so we generate separate HTML reports
FLUTTER_HTML_GENERATED=false
if command -v genhtml &> /dev/null; then
    # Generate Flutter HTML report if Flutter coverage exists
    if [ -f "coverage/lcov.info" ]; then
        echo ""
        echo "🌐 Generating Flutter HTML report..."
        genhtml coverage/lcov.info -o coverage/html-flutter 2>/dev/null || true

        if [ -f "coverage/html-flutter/index.html" ]; then
            FLUTTER_HTML_GENERATED=true
            echo "✅ Flutter HTML report: coverage/html-flutter/index.html"
        else
            echo "⚠️  Flutter HTML report generation failed (genhtml couldn't resolve source paths)"
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

if [ "$FLUTTER_COVERAGE" = true ]; then
    echo "📱 Flutter:    coverage/lcov.info"
fi

if [ "$TS_COVERAGE" = true ]; then
    echo "🔥 Functions:  coverage/lcov-functions.info"
fi

if [ -f "coverage/lcov-combined.info" ]; then
    echo "📊 Combined:   coverage/lcov-combined.info"
fi

# Show available HTML reports (check for actual file existence)
HTML_REPORTS_FOUND=false

if [ -f "coverage/html-flutter/index.html" ]; then
    HTML_REPORTS_FOUND=true
    echo ""
    echo "To view Flutter HTML report:"
    echo "  open coverage/html-flutter/index.html (Mac)"
    echo "  xdg-open coverage/html-flutter/index.html (Linux)"
fi

if [ -f "coverage/html-functions/index.html" ]; then
    HTML_REPORTS_FOUND=true
    echo ""
    echo "To view Functions (TypeScript) HTML report:"
    echo "  open coverage/html-functions/index.html (Mac)"
    echo "  xdg-open coverage/html-functions/index.html (Linux)"
fi

if [ "$HTML_REPORTS_FOUND" = false ]; then
    if [ "$FLUTTER_COVERAGE" = true ]; then
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
