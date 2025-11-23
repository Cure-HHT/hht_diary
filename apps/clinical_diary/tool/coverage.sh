#!/bin/bash
# Coverage script for clinical_diary
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

echo "Starting test coverage collection..."
echo "Concurrency: $CONCURRENCY"

# Ensure the coverage directory exists and is clean
rm -rf coverage
mkdir -p coverage

# Run tests with coverage
echo "Running tests with coverage..."
flutter test --coverage --concurrency="$CONCURRENCY"

# Check if lcov is installed
if ! command -v lcov &> /dev/null; then
    echo "⚠️  lcov not found. Install with: brew install lcov (Mac) or sudo apt-get install lcov (Linux)"
    echo "Skipping HTML report generation..."
    echo "Coverage data saved to: coverage/lcov.info"
    exit 0
fi

# Remove generated files and test files from coverage
echo "Filtering coverage data..."
lcov --remove coverage/lcov.info \
  '**/*.g.dart' \
  '**/*.freezed.dart' \
  '**/test/**' \
  --ignore-errors unused \
  -o coverage/lcov.info

# Generate HTML report
echo "Generating HTML report..."
genhtml coverage/lcov.info -o coverage/html

echo "✅ Coverage process completed successfully"
echo "📊 Coverage report: coverage/html/index.html"
echo ""
echo "To view coverage:"
echo "  open coverage/html/index.html (Mac)"
echo "  xdg-open coverage/html/index.html (Linux)"

exit 0
