#!/bin/bash
# Plugin Test Runner

# Get the plugin root directory (parent of tests/)
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PLUGIN_ROOT" || exit 1

TESTS_PASSED=0
TESTS_FAILED=0

# Color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"

    echo -n "Running: $test_name... "
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        ((TESTS_FAILED++))
    fi
}

# Metadata Tests
echo "=== Metadata Tests ==="
run_test "Valid plugin.json structure" "test -f .claude-plugin/plugin.json && jq '.' .claude-plugin/plugin.json > /dev/null"

# Command Tests
echo "=== Command Tests ==="
run_test "Command file exists" "test -f commands/create-plugin.md"


# Custom Tests for Plugin-Expert Utilities

## Builders Tests
run_test "command-builder.js exists" "test -f builders/command-builder.js"
run_test "docs-builder.js exists" "test -f builders/docs-builder.js"
run_test "hook-builder.js exists" "test -f builders/hook-builder.js"
run_test "metadata-builder.js exists" "test -f builders/metadata-builder.js"
run_test "test-builder.js exists" "test -f builders/test-builder.js"

## Coordinators Tests
run_test "interview-conductor.js exists" "test -f coordinators/interview-conductor.js"
run_test "plugin-assembler.js exists" "test -f coordinators/plugin-assembler.js"
run_test "validator.js exists" "test -f coordinators/validator.js"

## Utilities Tests
run_test "path-manager.js exists" "test -f utilities/path-manager.js"
run_test "string-helpers.js exists" "test -f utilities/string-helpers.js"
run_test "validation.js exists" "test -f utilities/validation.js"
run_test "escape-helpers.js exists" "test -f utilities/escape-helpers.js"

## Node.js Module Load Tests
if command -v node &>/dev/null; then
    echo ""
    echo "=== Node.js Module Tests ==="

    run_test "test-builder loads" "cd '$PLUGIN_ROOT' && node -e 'require(\"./builders/test-builder\")'"
    run_test "command-builder loads" "cd '$PLUGIN_ROOT' && node -e 'require(\"./builders/command-builder\")'"
    run_test "path-manager loads" "cd '$PLUGIN_ROOT' && node -e 'require(\"./utilities/path-manager\")'"
    run_test "string-helpers loads" "cd '$PLUGIN_ROOT' && node -e 'require(\"./utilities/string-helpers\")'"
fi


# Summary
echo ""
echo "=== Test Summary ==="
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi