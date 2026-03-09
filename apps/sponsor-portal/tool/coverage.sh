#!/bin/bash
# Rollup coverage for all sponsor-portal projects
# Stops on first failure. Rewrites paths and combines reports.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=============================================="
echo "Sponsor Portal - Rollup Coverage"
echo "=============================================="

LCOV_FILES=()

# Clean rollup output
rm -rf "$SCRIPT_DIR/coverage"
mkdir -p "$SCRIPT_DIR/coverage"

for project in portal_functions portal_server portal-ui; do
    TEST_SCRIPT="$SCRIPT_DIR/$project/tool/test.sh"
    if [ -x "$TEST_SCRIPT" ]; then
        echo ""
        echo "----------------------------------------------"
        echo "Running coverage: $project"
        echo "----------------------------------------------"
        "$TEST_SCRIPT" --coverage --no-threshold "$@"

        # Rewrite SF: paths to be repo-relative and collect
        CHILD_LCOV="$SCRIPT_DIR/$project/coverage/lcov.info"
        if [ -f "$CHILD_LCOV" ]; then
            REWRITTEN="$SCRIPT_DIR/coverage/lcov-${project}.info"
            sed "s|^SF:|SF:apps/sponsor-portal/$project/|" "$CHILD_LCOV" > "$REWRITTEN"
            LCOV_FILES+=("$REWRITTEN")
        fi
    fi
done

# Combine all lcov files
if [ ${#LCOV_FILES[@]} -gt 0 ]; then
    echo ""
    echo "----------------------------------------------"
    echo "Combining coverage reports"
    echo "----------------------------------------------"

    if command -v lcov &> /dev/null; then
        LCOV_ARGS=""
        for f in "${LCOV_FILES[@]}"; do
            LCOV_ARGS="$LCOV_ARGS -a $f"
        done
        lcov $LCOV_ARGS -o "$SCRIPT_DIR/coverage/lcov.info" --ignore-errors unused 2>/dev/null || true
    else
        cat "${LCOV_FILES[@]}" > "$SCRIPT_DIR/coverage/lcov.info"
    fi

    if [ -f "$SCRIPT_DIR/coverage/lcov.info" ] && command -v genhtml &> /dev/null; then
        genhtml "$SCRIPT_DIR/coverage/lcov.info" \
            -o "$SCRIPT_DIR/coverage/html" \
            --prefix "$REPO_ROOT" \
            2>/dev/null || echo "Warning: Could not generate HTML report"
    fi
fi

# Coverage summary
get_coverage_percentage() {
    local lcov_file="$1"
    [ ! -f "$lcov_file" ] && echo "0" && return
    local lines_found lines_hit
    lines_found=$(grep -c "^DA:" "$lcov_file" 2>/dev/null) || lines_found=0
    lines_hit=$(grep "^DA:" "$lcov_file" 2>/dev/null | grep -cv ",0$") || lines_hit=0
    lines_found=$(echo "$lines_found" | tr -d '[:space:]')
    lines_hit=$(echo "$lines_hit" | tr -d '[:space:]')
    [ "${lines_found:-0}" -eq 0 ] 2>/dev/null && echo "0" && return
    awk "BEGIN {printf \"%.1f\", ($lines_hit/$lines_found)*100}"
}

echo ""
echo "=============================================="
echo "Sponsor Portal Coverage Summary"
echo "=============================================="

for project in portal_functions portal_server portal-ui; do
    CHILD_LCOV="$SCRIPT_DIR/coverage/lcov-${project}.info"
    if [ -f "$CHILD_LCOV" ]; then
        PCT=$(get_coverage_percentage "$CHILD_LCOV")
        printf "  %-25s %s%%\n" "$project" "$PCT"
    fi
done

if [ -f "$SCRIPT_DIR/coverage/lcov.info" ]; then
    TOTAL_PCT=$(get_coverage_percentage "$SCRIPT_DIR/coverage/lcov.info")
    echo "  -------------------------"
    printf "  %-25s %s%%\n" "COMBINED" "$TOTAL_PCT"
    echo ""
    echo "  Report: apps/sponsor-portal/coverage/lcov.info"
    [ -f "$SCRIPT_DIR/coverage/html/index.html" ] && echo "  HTML:   apps/sponsor-portal/coverage/html/index.html"
fi
