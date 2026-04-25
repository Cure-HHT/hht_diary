#!/usr/bin/env bash
# Tests for .github/scripts/lib/elspais-annotations.sh
#
# The helper extracts elspais "info"-downgraded findings (code.no_traceability,
# code.retired_references — both suppressed via .elspais.toml) and emits them
# as GitHub Actions warning annotations so each CI run surfaces a reminder
# that the underlying repo-wide debt is still outstanding.
#
# Usage: ./.githooks/tests/elspais-suppressed-warnings.test.sh
# Exits 0 on all pass, 1 on any failure.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../../.github/scripts/lib/elspais-annotations.sh
source "$REPO_ROOT/.github/scripts/lib/elspais-annotations.sh"

PASS=0
FAIL=0

eq() {
    local actual="$1" expected="$2" label="$3"
    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS + 1))
        printf '  ok    %s\n' "$label"
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL  %s\n        expected=%q\n        actual=%q\n' "$label" "$expected" "$actual"
    fi
}

echo "elspais-annotations.sh tests"
echo "----------------------------"

# ---- Both suppressed checks present + unrelated lines around them --
SAMPLE=$(cat <<'EOF'
✓ CONFIG (7 passed, 0 failed, 1 skipped)
⚠ CODE (1 passed, 2 failed, 4 skipped)
  ~ code.no_traceability: 53 file(s) without traceability markers
  ~ code.retired_references: 157 code reference(s) to retired requirements
  ~ tests.unlinked: 2 test file(s) with no traceability markers
  ✓ tests.retired_references: No tests references to retired requirements
HEALTHY: 33/33 checks passed
EOF
)
EXPECTED='::warning title=Elspais standing issue (suppressed)::code.no_traceability: 53 file(s) without traceability markers
::warning title=Elspais standing issue (suppressed)::code.retired_references: 157 code reference(s) to retired requirements'
ACTUAL=$(emit_suppressed_warnings "$SAMPLE")
eq "$ACTUAL" "$EXPECTED" "extracts both suppressed code.* checks, ignores other ~ lines"

# ---- Only one suppressed check present ------------------------------
SAMPLE_ONE=$(cat <<'EOF'
  ~ code.no_traceability: 53 file(s) without traceability markers
  ✓ code.retired_references: No code references to retired requirements
EOF
)
EXPECTED_ONE='::warning title=Elspais standing issue (suppressed)::code.no_traceability: 53 file(s) without traceability markers'
ACTUAL_ONE=$(emit_suppressed_warnings "$SAMPLE_ONE")
eq "$ACTUAL_ONE" "$EXPECTED_ONE" "extracts only the one suppressed item present"

# ---- No suppressed checks -> no annotations -------------------------
SAMPLE_CLEAN=$(cat <<'EOF'
✓ CODE (5 passed, 0 failed)
  ✓ code.no_traceability: All files have traceability markers
  ✓ code.retired_references: No code references to retired requirements
EOF
)
ACTUAL_CLEAN=$(emit_suppressed_warnings "$SAMPLE_CLEAN")
eq "$ACTUAL_CLEAN" "" "no suppressed-info items -> no annotations"

# ---- Empty input ----------------------------------------------------
ACTUAL_EMPTY=$(emit_suppressed_warnings "")
eq "$ACTUAL_EMPTY" "" "empty input -> no annotations, no error"

# ---- Tabs and varying leading whitespace ----------------------------
SAMPLE_WS=$(printf '\t  ~ code.no_traceability: 99 files\n   ~ code.retired_references: 11 refs\n')
EXPECTED_WS='::warning title=Elspais standing issue (suppressed)::code.no_traceability: 99 files
::warning title=Elspais standing issue (suppressed)::code.retired_references: 11 refs'
ACTUAL_WS=$(emit_suppressed_warnings "$SAMPLE_WS")
eq "$ACTUAL_WS" "$EXPECTED_WS" "handles varying leading whitespace (tabs, spaces)"

echo ""
if [ "$FAIL" -eq 0 ]; then
    printf 'All %d assertions passed.\n' "$PASS"
    exit 0
else
    printf '%d passed, %d failed.\n' "$PASS" "$FAIL"
    exit 1
fi
