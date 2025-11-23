#!/bin/bash
# Test script for trial_data_types
# Works both locally and in CI/CD

set -e  # Exit on any error

# Parse command line arguments
CONCURRENCY="10"

while [[ $# -gt 0 ]]; do
  case $1 in
    --concurrency)
      CONCURRENCY="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--concurrency N]"
      echo "  --concurrency N    Set test concurrency (default: 10)"
      exit 1
      ;;
  esac
done

echo "Running tests with concurrency: $CONCURRENCY"

# Run all tests (pure Dart package)
dart test --concurrency="$CONCURRENCY"

# Check exit code
if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed!"
    exit 1
fi
