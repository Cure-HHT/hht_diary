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

# Command Tests
echo "=== Command Tests ==="
run_test "Command file exists" "test -f commands/linear-checklist.md"
run_test "Command file exists" "test -f commands/linear-fetch.md"
run_test "Command file exists" "test -f commands/linear-search.md"


# Scripts Tests
echo ""
echo "=== Scripts Tests ==="
run_test "add-requirement-checklist.js exists" "test -f scripts/add-requirement-checklist.js"
run_test "add-subsystem-checklists.js exists" "test -f scripts/add-subsystem-checklists.js"
run_test "check-duplicates-advanced.js exists" "test -f scripts/check-duplicates-advanced.js"
run_test "check-duplicates.js exists" "test -f scripts/check-duplicates.js"
run_test "create-requirement-tickets.js exists" "test -f scripts/create-requirement-tickets.js"
run_test "create-single-ticket.js exists" "test -f scripts/create-single-ticket.js"
run_test "create-tickets.sh exists" "test -f scripts/create-tickets.sh"
run_test "create-tickets.sh is executable" "test -x scripts/create-tickets.sh"
run_test "fetch-tickets-by-label.js exists" "test -f scripts/fetch-tickets-by-label.js"
run_test "fetch-tickets.js exists" "test -f scripts/fetch-tickets.js"
run_test "list-infrastructure-tickets.js exists" "test -f scripts/list-infrastructure-tickets.js"
run_test "list-labels.js exists" "test -f scripts/list-labels.js"
run_test "list-security-compliance-infrastructure-tickets.js exists" "test -f scripts/list-security-compliance-infrastructure-tickets.js"
run_test "run-dry-run-all.sh exists" "test -f scripts/run-dry-run-all.sh"
run_test "run-dry-run-all.sh is executable" "test -x scripts/run-dry-run-all.sh"
run_test "run-dry-run.sh exists" "test -f scripts/run-dry-run.sh"
run_test "run-dry-run.sh is executable" "test -x scripts/run-dry-run.sh"
run_test "search-tickets.js exists" "test -f scripts/search-tickets.js"
run_test "setup-env.sh exists" "test -f scripts/setup-env.sh"
run_test "setup-env.sh is executable" "test -x scripts/setup-env.sh"
run_test "show-sample-ticket.js exists" "test -f scripts/show-sample-ticket.js"
run_test "test-config.js exists" "test -f scripts/test-config.js"
run_test "update-ticket-status.js exists" "test -f scripts/update-ticket-status.js"
run_test "update-ticket-with-requirement.js exists" "test -f scripts/update-ticket-with-requirement.js"
run_test "update-ticket.js exists" "test -f scripts/update-ticket.js"

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