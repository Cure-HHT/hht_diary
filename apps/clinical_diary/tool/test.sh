#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00004: Local-First Data Entry Implementation
#   REQ-d00005: Sponsor Configuration Detection Implementation
#
# Test script for clinical_diary
# Runs Flutter (Dart) and Firebase Functions (TypeScript) tests
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
    echo "  -f, --flutter      Run Flutter (Dart) tests only"
    echo "  -t, --typescript   Run TypeScript (Functions) tests only"
    echo "  --concurrency N    Set Flutter test concurrency (default: 10)"
    echo "  -h, --help         Show this help message"
    echo ""
    echo "If neither -f nor -t is specified, both test suites are run."
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
echo "Clinical Diary Test Suite"
echo "=============================================="

FLUTTER_PASSED=true
TS_PASSED=true

# Run Flutter tests
if [ "$RUN_FLUTTER" = true ]; then
    echo ""
    echo "📱 Running Flutter tests..."
    echo "   Concurrency: $CONCURRENCY"
    echo ""

    if flutter test --concurrency="$CONCURRENCY"; then
        echo "✅ Flutter tests passed!"
    else
        echo "❌ Flutter tests failed!"
        FLUTTER_PASSED=false
    fi
fi

# Run TypeScript/Functions tests
if [ "$RUN_TYPESCRIPT" = true ]; then
    echo ""
    echo "🔥 Running Firebase Functions tests..."
    echo ""

    if [ -d "functions" ]; then
        cd functions

        # Install dependencies if needed
        if [ ! -d "node_modules" ]; then
            echo "Installing dependencies..."
            npm install
        fi

        # Run lint
        echo "Running ESLint..."
        if ! npm run lint; then
            echo "❌ ESLint found issues!"
            TS_PASSED=false
        else
            echo "✅ ESLint passed"
        fi

        # Run TypeScript compilation
        echo ""
        echo "Running TypeScript compilation..."
        if ! npm run build; then
            echo "❌ TypeScript compilation failed!"
            TS_PASSED=false
        else
            echo "✅ TypeScript compilation passed"
        fi

        # Run Jest tests
        echo ""
        echo "Running Jest tests..."
        if npm test; then
            echo "✅ Jest tests passed!"
        else
            echo "❌ Jest tests failed!"
            TS_PASSED=false
        fi

        cd ..
    else
        echo "⚠️  functions/ directory not found, skipping TypeScript tests"
    fi
fi

echo ""
echo "=============================================="
echo "Summary"
echo "=============================================="

EXIT_CODE=0

if [ "$RUN_FLUTTER" = true ]; then
    if [ "$FLUTTER_PASSED" = true ]; then
        echo "✅ Flutter: PASSED"
    else
        echo "❌ Flutter: FAILED"
        EXIT_CODE=1
    fi
fi

if [ "$RUN_TYPESCRIPT" = true ]; then
    if [ "$TS_PASSED" = true ]; then
        echo "✅ TypeScript/Functions: PASSED"
    else
        echo "❌ TypeScript/Functions: FAILED"
        EXIT_CODE=1
    fi
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "🎉 All tests passed!"
else
    echo ""
    echo "💥 Some tests failed!"
fi

exit $EXIT_CODE
