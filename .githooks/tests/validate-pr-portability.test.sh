#!/usr/bin/env bash
# Verifies that the file-scanning loops in .github/scripts/validate-pr.sh
# correctly find files at arbitrary depth without depending on bash 4+'s
# `globstar` shopt. Devs run validate-pr.sh locally on macOS, where the
# system /bin/bash is 3.2 and `globstar` is unavailable — under that
# shell, `database/**/*.sql` silently degrades to depth-2 matching with
# `nullglob` swallowing the pattern, so files at deeper paths get skipped
# without the header validator noticing.
#
# We simulate bash 3.2 by disabling globstar in this bash run, then run
# the actual scanning idiom from validate-pr.sh against a fixture tree.
#
# Usage: ./.githooks/tests/validate-pr-portability.test.sh
# Exits 0 on all pass, 1 on any failure.

set -u

PASS=0
FAIL=0

assert_eq() {
    local actual="$1" expected="$2" label="$3"
    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS + 1))
        printf '  ok    %-65s -> %s\n' "$label" "$actual"
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL  %-65s expected=%s actual=%s\n' "$label" "$expected" "$actual"
    fi
}

# Build a fixture tree under a tmpdir. All non-migration files live
# deeper than depth 2 so that the OLD idiom — which under bash 3.2
# degrades `**` to a single `*` — finds nothing.
#
# database/migrations/0001/create_table.sql  — depth 3, skipped (migrations)
# database/audit/v2/forms/intake.sql          — depth 4, no header (should be flagged)
# database/audit/v3/forms/followup.sql        — depth 4, no header (should be flagged)
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$TMPDIR/database/migrations/0001"
mkdir -p "$TMPDIR/database/audit/v2/forms"
mkdir -p "$TMPDIR/database/audit/v3/forms"
echo "-- migration only" > "$TMPDIR/database/migrations/0001/create_table.sql"
echo "SELECT 1;"          > "$TMPDIR/database/audit/v2/forms/intake.sql"
echo "SELECT 2;"          > "$TMPDIR/database/audit/v3/forms/followup.sql"

# Disable globstar to mimic macOS default bash 3.2. nullglob remains
# available (it exists in bash 3.2) and matches what the script enables.
shopt -u globstar 2>/dev/null || true

# ---- Implementation under test ------------------------------------
# Mirrors the actual loop body in .github/scripts/validate-pr.sh (the
# one we're about to fix). If a deep file is missing the header, the
# new scan idiom must catch it.
scan_with_find() {
    local root="$1"
    local missing=()
    local total=0
    local file
    while IFS= read -r -d '' file; do
        if [[ "$file" =~ /tests/ ]] || [[ "$file" =~ /migrations/ ]]; then
            continue
        fi
        total=$((total + 1))
        if ! grep -q "IMPLEMENTS REQUIREMENTS:" "$file"; then
            missing+=("$file")
        fi
    done < <(find "$root" -type f -name '*.sql' -print0 2>/dev/null)
    printf '%s\n' "$total" "${#missing[@]}"
}

# ---- Old implementation (for contrast) ----------------------------
# This is the current validate-pr.sh idiom. Kept here so the test
# documents *why* the change is needed: under shopt -u globstar +
# shopt -s nullglob, deep files are silently invisible.
scan_with_globstar() {
    local root="$1"
    local missing=()
    local total=0
    shopt -s nullglob
    local file
    for file in "$root"/**/*.sql; do
        if [[ "$file" =~ /tests/ ]] || [[ "$file" =~ /migrations/ ]]; then
            continue
        fi
        total=$((total + 1))
        if ! grep -q "IMPLEMENTS REQUIREMENTS:" "$file"; then
            missing+=("$file")
        fi
    done
    shopt -u nullglob
    printf '%s\n' "$total" "${#missing[@]}"
}

echo "validate-pr.sh portability tests (simulating macOS bash 3.2)"
echo "-------------------------------------------------------------"

# Old idiom: globstar OFF, nullglob ON. With globstar disabled,
# `**` is just `*`, so root/**/*.sql matches files at depth 2 only.
# Our fixture has its non-migration files at depths 1 and 3, neither
# of which is depth 2, so old idiom finds zero.
old_result=$(scan_with_globstar "$TMPDIR/database")
old_total=$(echo "$old_result" | sed -n 1p)
old_missing=$(echo "$old_result" | sed -n 2p)
assert_eq "$old_total"   "0" "OLD globstar idiom (bash 3.2): scanned count"
assert_eq "$old_missing" "0" "OLD globstar idiom (bash 3.2): missing-header count"

# New idiom: find-based, depth-agnostic. Should scan both depth-4 files
# and skip the depth-3 migration. Both lack the header.
new_result=$(scan_with_find "$TMPDIR/database")
new_total=$(echo "$new_result" | sed -n 1p)
new_missing=$(echo "$new_result" | sed -n 2p)
assert_eq "$new_total"   "2" "NEW find-based scan: scanned count (depth 4)"
assert_eq "$new_missing" "2" "NEW find-based scan: missing-header count"

# Filename-with-spaces sanity (the find -print0 + read -d '' contract)
mkdir -p "$TMPDIR/database/has space/inner/extra"
echo "SELECT 3;" > "$TMPDIR/database/has space/inner/extra/file with space.sql"
new_with_space=$(scan_with_find "$TMPDIR/database")
new_with_space_total=$(echo "$new_with_space" | sed -n 1p)
assert_eq "$new_with_space_total" "3" "NEW find-based scan: handles paths with spaces"

# ---- Verify .github/scripts/validate-pr.sh is using the new idiom --
# Once the fix lands, the file should no longer enable globstar.
echo ""
echo "  -- validate-pr.sh source ---"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if grep -vE '^\s*#' "$REPO_ROOT/.github/scripts/validate-pr.sh" \
        | grep -qE "shopt -s globstar|shopt -s nullglob globstar"; then
    FAIL=$((FAIL + 1))
    printf '  FAIL  %-65s validate-pr.sh still enables globstar (non-comment line)\n' "validate-pr.sh has dropped globstar"
else
    PASS=$((PASS + 1))
    printf '  ok    %-65s -> no globstar enable in non-comment lines\n' "validate-pr.sh has dropped globstar"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    printf 'All %d assertions passed.\n' "$PASS"
    exit 0
else
    printf '%d passed, %d failed.\n' "$PASS" "$FAIL"
    exit 1
fi
