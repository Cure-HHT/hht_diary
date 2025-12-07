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
RUN_FLUTTER_UNIT=false
RUN_FLUTTER_INTEGRATION=false
RUN_TYPESCRIPT_UNIT=false
RUN_TYPESCRIPT_INTEGRATION=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -f,  --flutter              Run all Flutter tests (unit + integration)"
    echo "  -fu, --flutter-unit         Run Flutter unit tests only"
    echo "  -fi, --flutter-integration  Run Flutter integration tests on desktop"
    echo "  -t,  --typescript           Run all TypeScript tests (unit + integration)"
    echo "  -tu, --typescript-unit      Run TypeScript unit tests only"
    echo "  -ti, --typescript-integration  Run TypeScript integration tests (future)"
    echo "  --concurrency N             Set Flutter test concurrency (default: 10)"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "If no flags are specified, Flutter unit and TypeScript unit tests are run."
    echo "Integration tests must be explicitly requested."
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
      RUN_TYPESCRIPT_UNIT=true
      RUN_TYPESCRIPT_INTEGRATION=true
      shift
      ;;
    -tu|--typescript-unit)
      RUN_TYPESCRIPT_UNIT=true
      shift
      ;;
    -ti|--typescript-integration)
      RUN_TYPESCRIPT_INTEGRATION=true
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

# If no test flags specified, run Flutter unit and TypeScript unit (not integration)
if [ "$RUN_FLUTTER_UNIT" = false ] && [ "$RUN_FLUTTER_INTEGRATION" = false ] && \
   [ "$RUN_TYPESCRIPT_UNIT" = false ] && [ "$RUN_TYPESCRIPT_INTEGRATION" = false ]; then
    RUN_FLUTTER_UNIT=true
    RUN_TYPESCRIPT_UNIT=true
fi

echo "=============================================="
echo "Clinical Diary Test Suite"
echo "=============================================="

FLUTTER_UNIT_PASSED=true
FLUTTER_INTEGRATION_PASSED=true
TS_UNIT_PASSED=true
TS_INTEGRATION_PASSED=true

# Run Flutter unit tests
if [ "$RUN_FLUTTER_UNIT" = true ]; then
    echo ""
    echo "📱 Running Flutter unit tests..."
    echo "   Concurrency: $CONCURRENCY"
    echo ""

    if flutter test --concurrency="$CONCURRENCY"; then
        echo "✅ Flutter unit tests passed!"
    else
        echo "❌ Flutter unit tests failed!"
        FLUTTER_UNIT_PASSED=false
    fi
fi

# Run Flutter integration tests on desktop
if [ "$RUN_FLUTTER_INTEGRATION" = true ]; then
    echo ""
    echo "🖥️  Running Flutter integration tests on desktop..."
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
        # Running all files together can cause "Unable to start the app on the device" errors
        INTEGRATION_FAILED=false
        for test_file in integration_test/*_test.dart; do
            if [ -f "$test_file" ]; then
                echo ""
                echo "   Running: $test_file"
                if ! $XVFB_PREFIX flutter test "$test_file" -d "$DEVICE"; then
                    INTEGRATION_FAILED=true
                fi
            fi
        done

        if [ "$INTEGRATION_FAILED" = true ]; then
            echo "❌ Flutter integration tests failed!"
            FLUTTER_INTEGRATION_PASSED=false
        else
            echo "✅ Flutter integration tests passed!"
        fi
    else
        echo "⚠️  integration_test/ directory not found, skipping integration tests"
    fi
fi

# Run TypeScript/Functions unit tests
if [ "$RUN_TYPESCRIPT_UNIT" = true ]; then
    echo ""
    echo "🔥 Running TypeScript/Functions unit tests..."
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
            TS_UNIT_PASSED=false
        else
            echo "✅ ESLint passed"
        fi

        # Run TypeScript compilation
        echo ""
        echo "Running TypeScript compilation..."
        if ! npm run build; then
            echo "❌ TypeScript compilation failed!"
            TS_UNIT_PASSED=false
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
            TS_UNIT_PASSED=false
        fi

        cd ..
    else
        echo "⚠️  functions/ directory not found, skipping TypeScript tests"
    fi
fi

# Run TypeScript/Functions integration tests (future)
if [ "$RUN_TYPESCRIPT_INTEGRATION" = true ]; then
    echo ""
    echo "🔥 Running TypeScript/Functions integration tests..."
    echo ""
    echo "⚠️  TypeScript integration tests not yet implemented"
    # Future: Add TypeScript integration test runner here
fi

echo ""
echo "=============================================="
echo "Summary"
echo "=============================================="

EXIT_CODE=0

if [ "$RUN_FLUTTER_UNIT" = true ]; then
    if [ "$FLUTTER_UNIT_PASSED" = true ]; then
        echo "✅ Flutter Unit: PASSED"
    else
        echo "❌ Flutter Unit: FAILED"
        EXIT_CODE=1
    fi
fi

if [ "$RUN_FLUTTER_INTEGRATION" = true ]; then
    if [ "$FLUTTER_INTEGRATION_PASSED" = true ]; then
        echo "✅ Flutter Integration: PASSED"
    else
        echo "❌ Flutter Integration: FAILED"
        EXIT_CODE=1
    fi
fi

if [ "$RUN_TYPESCRIPT_UNIT" = true ]; then
    if [ "$TS_UNIT_PASSED" = true ]; then
        echo "✅ TypeScript Unit: PASSED"
    else
        echo "❌ TypeScript Unit: FAILED"
        EXIT_CODE=1
    fi
fi

if [ "$RUN_TYPESCRIPT_INTEGRATION" = true ]; then
    if [ "$TS_INTEGRATION_PASSED" = true ]; then
        echo "✅ TypeScript Integration: PASSED"
    else
        echo "❌ TypeScript Integration: FAILED"
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
