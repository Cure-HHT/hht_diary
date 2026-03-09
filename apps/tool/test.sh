#!/bin/bash
# Run all test suites across the entire apps directory
# Stops on first failure. Passes all arguments to each child test.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=============================================="
echo "All Apps - Test Suites"
echo "=============================================="

PROJECTS=(
    "common-dart/trial_data_types"
    "common-dart/append_only_datastore"
    "daily-diary/diary_functions"
    "daily-diary/diary_server"
    "daily-diary/clinical_diary"
    "sponsor-portal/portal_functions"
    "sponsor-portal/portal_server"
    "sponsor-portal/portal-ui"
    "edc/rave-integration"
)

for project in "${PROJECTS[@]}"; do
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
