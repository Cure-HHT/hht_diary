#!/bin/bash
# Run all daily-diary test suites
# Stops on first failure. Passes all arguments to each child test.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=============================================="
echo "Daily Diary - All Test Suites"
echo "=============================================="

for project in diary_functions diary_server clinical_diary; do
    TEST_SCRIPT="$SCRIPT_DIR/$project/tool/test.sh"
    if [ -x "$TEST_SCRIPT" ]; then
        echo ""
        echo "----------------------------------------------"
        echo "Running: $project"
        echo "----------------------------------------------"
        "$TEST_SCRIPT" "$@"
    fi
done

echo ""
echo "=============================================="
echo "All suites passed!"
echo "=============================================="
