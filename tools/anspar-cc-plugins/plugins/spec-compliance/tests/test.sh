#!/bin/bash
# Plugin Test Runner

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


# Scripts Tests
echo ""
echo "=== Scripts Tests ==="
run_test "validate-spec-compliance.sh exists" "test -f scripts/validate-spec-compliance.sh"
run_test "validate-spec-compliance.sh is executable" "test -x scripts/validate-spec-compliance.sh"

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