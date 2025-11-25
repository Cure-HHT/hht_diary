#!/bin/bash
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00005: Sponsor Configuration Detection Implementation
#
# Test script for Firebase Functions
# Runs TypeScript linting, compilation, and Jest tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "Firebase Functions Test Suite"
echo "=============================================="

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Run linter
echo ""
echo "Running ESLint..."
npm run lint
if [ $? -ne 0 ]; then
    echo "❌ ESLint found issues"
    exit 1
fi
echo "✅ ESLint passed"

# Run TypeScript compilation
echo ""
echo "Running TypeScript compilation..."
npm run build
if [ $? -ne 0 ]; then
    echo "❌ TypeScript compilation failed"
    exit 1
fi
echo "✅ TypeScript compilation passed"

# Run tests
echo ""
echo "Running Jest tests..."
npm test
if [ $? -ne 0 ]; then
    echo "❌ Tests failed"
    exit 1
fi

echo ""
echo "=============================================="
echo "✅ All checks passed!"
echo "=============================================="
