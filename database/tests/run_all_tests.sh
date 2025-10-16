#!/bin/bash
# =====================================================
# Run All Database Tests
# =====================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "========================================="
echo "Clinical Trial Diary Database Test Suite"
echo "========================================="
echo ""

# Check if database specified
DB_NAME="${1:-dbtest_test}"
DB_USER="${2:-postgres}"

echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo ""

# Check if database exists
if ! psql -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    echo -e "${YELLOW}WARNING: Database '$DB_NAME' does not exist${NC}"
    echo "Creating test database..."
    psql -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;"
    echo "Initializing schema..."
    psql -U "$DB_USER" -d "$DB_NAME" -f ../../init.sql > /dev/null
    echo ""
fi

# Run tests
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

run_test() {
    local test_file=$1
    local test_name=$(basename "$test_file" .sql)

    echo -e "${YELLOW}Running: $test_name${NC}"

    TEST_COUNT=$((TEST_COUNT + 1))

    if output=$(psql -U "$DB_USER" -d "$DB_NAME" -f "$test_file" 2>&1); then
        # Count PASS and FAIL in output
        pass=$(echo "$output" | grep -c "PASS:" || true)
        fail=$(echo "$output" | grep -c "FAIL:" || true)

        if [ "$fail" -gt 0 ]; then
            echo -e "${RED}✗ FAILED${NC} ($pass passed, $fail failed)"
            echo "$output" | grep -E "(PASS|FAIL|ERROR)"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        else
            echo -e "${GREEN}✓ PASSED${NC} ($pass tests)"
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
    else
        echo -e "${RED}✗ ERROR${NC}"
        echo "$output"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    echo ""
}

# Run all test files
for test in test_*.sql; do
    if [ -f "$test" ]; then
        run_test "$test"
    fi
done

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Total test suites: $TEST_COUNT"
echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
else
    echo -e "Failed: $FAIL_COUNT"
fi
echo ""

# Exit with appropriate code
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
