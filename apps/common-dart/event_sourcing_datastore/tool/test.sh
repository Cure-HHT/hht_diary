#!/bin/bash
# Test script for append_only_datastore
# Works both locally and in CI/CD

set -e  # Exit on any error

# Change to the package root directory (parent of tool/)
cd "$(dirname "$0")/.."

# Parse command line arguments
CONCURRENCY="10"
WITH_COVERAGE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --concurrency)
      CONCURRENCY="$2"
      shift 2
      ;;
    -u)
      # Unit-only flag (no-op: all tests in this package are unit tests)
      shift
      ;;
    -c|--coverage)
      WITH_COVERAGE=true
      shift
      ;;
    --no-threshold)
      # Accepted for compatibility, no-op for this package
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [-u] [-c|--coverage] [--concurrency N]"
      echo "  -u               Run unit tests only (default, all tests are unit tests)"
      echo "  -c, --coverage   Run with coverage collection"
      echo "  --concurrency N  Set test concurrency (default: 10)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [-u] [-c|--coverage] [--concurrency N]"
      exit 1
      ;;
  esac
done

echo "Running tests with concurrency: $CONCURRENCY"

# Build test command
if [ "$WITH_COVERAGE" = true ]; then
    rm -rf coverage
    mkdir -p coverage
    flutter test --coverage --concurrency="$CONCURRENCY"
else
    flutter test --concurrency="$CONCURRENCY"
fi

EXIT_CODE=$?

# Generate coverage reports if requested
if [ "$WITH_COVERAGE" = true ] && [ $EXIT_CODE -eq 0 ] && [ -f "coverage/lcov.info" ]; then
    if command -v lcov &> /dev/null; then
        echo ""
        echo "Filtering coverage data..."
        lcov --remove coverage/lcov.info \
          '**/*.g.dart' \
          '**/*.freezed.dart' \
          '**/test/**' \
          --ignore-errors unused \
          -o coverage/lcov.info 2>/dev/null || true
    fi

    if command -v genhtml &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html 2>/dev/null || true
        echo "HTML report: coverage/html/index.html"
    fi
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "All tests passed!"
else
    echo "Some tests failed!"
fi

exit $EXIT_CODE
