#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00005: Sponsor Configuration Detection Implementation
#
# Coverage script for Firebase Functions
# Runs Jest with coverage and generates lcov report

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "Firebase Functions Coverage"
echo "=============================================="

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Clean previous coverage
rm -rf coverage

# Run tests with coverage
echo ""
echo "Running tests with coverage..."
npm run test:coverage

echo ""
echo "=============================================="
echo "Coverage Summary"
echo "=============================================="

# Check if coverage was generated
if [ -f "coverage/lcov.info" ]; then
    echo "✅ Coverage report generated"
    echo "📊 lcov report: coverage/lcov.info"

    if [ -d "coverage/lcov-report" ]; then
        echo "📊 HTML report: coverage/lcov-report/index.html"
    fi
else
    echo "⚠️  No coverage report generated"
fi

echo ""
echo "To view HTML report:"
echo "  open coverage/lcov-report/index.html  # Mac"
echo "  xdg-open coverage/lcov-report/index.html  # Linux"
