#!/usr/bin/env bash
# Smoke tests for the version-bump logic in .githooks/version-utils.sh
# and the version_mode dispatch added per the CUR-1160 Part B subsumption
# (semver-only build flow for portal-ui, where callisto's portal-final
# Dockerfile assigns the build identifier).
#
# Usage: ./.githooks/tests/version-bump.test.sh
# Exits 0 on all pass, 1 on any failure.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../version-utils.sh
source "$HOOKS_DIR/version-utils.sh"
# shellcheck source=../project-defs.sh
source "$HOOKS_DIR/project-defs.sh"

PASS=0
FAIL=0

# eq <actual> <expected> <label>
eq() {
    local actual="$1" expected="$2" label="$3"
    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS + 1))
        printf '  ok    %-60s -> %s\n' "$label" "$actual"
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL  %-60s expected=%q actual=%q\n' "$label" "$expected" "$actual"
    fi
}

# rc <command...> # final arg is expected return code, label is captured
# Usage: rc <expected_rc> <label> <command...>
rc() {
    local expected_rc="$1"; shift
    local label="$1"; shift
    "$@"
    local actual_rc=$?
    if [ "$actual_rc" = "$expected_rc" ]; then
        PASS=$((PASS + 1))
        printf '  ok    %-60s -> rc=%s\n' "$label" "$actual_rc"
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL  %-60s expected_rc=%s actual_rc=%s\n' "$label" "$expected_rc" "$actual_rc"
    fi
}

echo "version-bump smoke tests"
echo "------------------------"

# ===== compute_new_version_semver_only =====
echo ""
echo "  -- compute_new_version_semver_only --"
eq "$(compute_new_version_semver_only '1.0.14' '1.0.14')"     "1.0.15" "basic patch bump on equal semvers"
eq "$(compute_new_version_semver_only '1.0.14+5' '1.0.14')"   "1.0.15" "strips +N from current, bumps patch"
eq "$(compute_new_version_semver_only '1.1.0' '1.0.14')"      "1.1.0"  "preserves manual minor bump (no patch added)"
eq "$(compute_new_version_semver_only '2.0.0+9' '1.0.14')"    "2.0.0"  "preserves manual major bump and strips +N"
eq "$(compute_new_version_semver_only '1.0.14' '1.0.13')"     "1.0.14" "preserves manual patch bump"

# ===== verify_version_bumped_semver_only =====
echo ""
echo "  -- verify_version_bumped_semver_only --"
rc 0 "no +N, no code change, semvers equal -> pass"        verify_version_bumped_semver_only "1.0.14" "1.0.14" "false"
rc 1 "no +N, code change, semvers equal -> fail"           verify_version_bumped_semver_only "1.0.14" "1.0.14" "true"
rc 0 "no +N, code change, semver bumped -> pass"           verify_version_bumped_semver_only "1.0.15" "1.0.14" "true"
rc 1 "+N present, no code change -> fail"                  verify_version_bumped_semver_only "1.0.14+1" "1.0.14" "false"
rc 1 "+N present, code change with semver bump -> fail"    verify_version_bumped_semver_only "1.0.15+1" "1.0.14" "true"

# ===== Backward-semver guard (both modes) =====
# A stale branch can stage a bumped pubspec whose semver is BEHIND main's
# (e.g. main has been advanced since the branch was last rebased). The
# verifiers must reject this regardless of code_changed, otherwise CI
# greenlights a backward-semver merge.
echo ""
echo "  -- backward-semver guard (standard) --"
rc 1 "standard cascade: current_semver < main_semver -> reject"  verify_version_bumped "0.9.16+37" "0.9.17+36" "false"
rc 1 "standard code change: current_semver < main_semver -> reject" verify_version_bumped "0.9.16+38" "0.9.17+36" "true"
rc 0 "standard cascade: current_semver == main_semver -> pass"   verify_version_bumped "0.9.17+37" "0.9.17+36" "false"
rc 0 "standard cascade: current_semver > main_semver -> pass"    verify_version_bumped "0.9.18+37" "0.9.17+36" "false"

echo ""
echo "  -- backward-semver guard (semver-only) --"
rc 1 "semver-only cascade: current_semver < main_semver -> reject" verify_version_bumped_semver_only "1.0.13" "1.0.14" "false"
rc 1 "semver-only code change: current_semver < main_semver -> reject" verify_version_bumped_semver_only "1.0.13" "1.0.14" "true"
rc 0 "semver-only cascade: current_semver > main_semver -> pass"   verify_version_bumped_semver_only "1.0.15" "1.0.14" "false"

echo ""
echo "  -- backward-semver guard via dispatcher --"
rc 1 "verify_for(standard) catches backward-semver cascade"      verify_version_bumped_for "standard" "0.9.16+37" "0.9.17+36" "false"
rc 1 "verify_for(semver-only) catches backward-semver cascade"   verify_version_bumped_for "semver-only" "1.0.13" "1.0.14" "false"

# ===== compute_new_version_for (dispatcher) =====
echo ""
echo "  -- compute_new_version_for dispatcher --"
eq "$(compute_new_version_for 'standard' '0.1.0+11' '0.1.0+11' 'true')"     "0.1.1+12" "standard + code change -> patch + build bump"
eq "$(compute_new_version_for 'standard' '0.1.0+11' '0.1.0+11' 'false')"    "0.1.0+12" "standard + trigger only -> build bump"
eq "$(compute_new_version_for 'semver-only' '1.0.14' '1.0.14' 'true')"      "1.0.15"   "semver-only + code change -> patch bump no +N"
eq "$(compute_new_version_for 'semver-only' '1.0.14+3' '1.0.14' 'true')"    "1.0.15"   "semver-only + code change strips inherited +N"
eq "$(compute_new_version_for 'semver-only' '1.0.14' '1.0.14' 'false')"     ""         "semver-only + trigger only -> empty (no bump)"

# ===== verify_version_bumped_for (dispatcher) =====
echo ""
echo "  -- verify_version_bumped_for dispatcher --"
rc 0 "standard verify dispatches: properly bumped passes"  verify_version_bumped_for "standard" "0.1.1+12" "0.1.0+11" "true"
rc 1 "standard verify dispatches: not bumped fails"        verify_version_bumped_for "standard" "0.1.0+11" "0.1.0+11" "true"
rc 0 "semver-only verify dispatches: passes when correct"  verify_version_bumped_for "semver-only" "1.0.15" "1.0.14" "true"
rc 1 "semver-only verify dispatches: rejects +N"           verify_version_bumped_for "semver-only" "1.0.15+1" "1.0.14" "true"

# ===== Unknown mode is an error =====
echo ""
echo "  -- unknown version_mode -> error --"
rc 1 "compute dispatcher rejects unknown mode"             bash -c "source $HOOKS_DIR/version-utils.sh; compute_new_version_for 'bogus' '1.0.0' '1.0.0' 'true' >/dev/null 2>&1"
rc 1 "verify dispatcher rejects unknown mode"              bash -c "source $HOOKS_DIR/version-utils.sh; verify_version_bumped_for 'bogus' '1.0.0' '1.0.0' 'true' >/dev/null 2>&1"

# ===== PROJECT_DEFS schema =====
echo ""
echo "  -- PROJECT_DEFS 5-field schema --"

# Every entry must parse cleanly into 5 fields with non-empty mode.
schema_failures=0
for project_def in "${PROJECT_DEFS[@]}"; do
    IFS='|' read -r name pubspec code_dirs triggers version_mode <<< "$project_def"
    if [ -z "$version_mode" ]; then
        printf '  FAIL  PROJECT_DEFS row %-25s missing version_mode field\n' "$name"
        schema_failures=$((schema_failures + 1))
    fi
done
if [ "$schema_failures" -eq 0 ]; then
    PASS=$((PASS + 1))
    printf '  ok    %-60s -> all entries have version_mode\n' "every PROJECT_DEFS row has 5 fields"
else
    FAIL=$((FAIL + schema_failures))
fi

# portal-ui must be semver-only.
portal_ui_mode=""
for project_def in "${PROJECT_DEFS[@]}"; do
    IFS='|' read -r name _ _ _ mode <<< "$project_def"
    if [ "$name" = "portal-ui" ]; then
        portal_ui_mode="$mode"
        break
    fi
done
eq "$portal_ui_mode" "semver-only" "portal-ui is semver-only"

# Every other project must be explicitly standard (no implicit default).
non_standard_others=()
for project_def in "${PROJECT_DEFS[@]}"; do
    IFS='|' read -r name _ _ _ mode <<< "$project_def"
    if [ "$name" != "portal-ui" ] && [ "$mode" != "standard" ]; then
        non_standard_others+=("$name=$mode")
    fi
done
if [ "${#non_standard_others[@]}" -eq 0 ]; then
    PASS=$((PASS + 1))
    printf '  ok    %-60s -> all standard\n' "non-portal-ui projects are explicitly standard"
else
    FAIL=$((FAIL + 1))
    printf '  FAIL  %-60s offenders: %s\n' "non-portal-ui projects are explicitly standard" "${non_standard_others[*]}"
fi

# ===== End-to-end: combine detection + dispatch =====
echo ""
echo "  -- end-to-end: detection + dispatch --"

# Helper: classify_and_bump <project_name> <changed_files> <current> <main>
# Mimics the pre-commit caller flow. Echoes "<new_version>" or empty.
classify_and_bump() {
    local wanted="$1" changed="$2" current="$3" main="$4"
    local def name pubspec code_dirs triggers mode
    for def in "${PROJECT_DEFS[@]}"; do
        IFS='|' read -r name pubspec code_dirs triggers mode <<< "$def"
        if [ "$name" = "$wanted" ]; then
            local code_changed=false any_trigger=false
            if has_code_changes "$code_dirs" "$changed"; then
                code_changed=true; any_trigger=true
            elif has_any_trigger "$triggers" "$changed"; then
                any_trigger=true
            fi
            if [ "$any_trigger" != true ]; then return 0; fi
            if verify_version_bumped_for "$mode" "$current" "$main" "$code_changed"; then
                return 0
            fi
            compute_new_version_for "$mode" "$current" "$main" "$code_changed"
            return 0
        fi
    done
    return 1
}

# portal-ui: own-source change bumps semver and emits no +N
eq "$(classify_and_bump portal-ui 'apps/sponsor-portal/portal-ui/lib/main.dart' '1.0.14' '1.0.14')" \
    "1.0.15" "portal-ui lib/ change -> 1.0.15 (semver-only)"

# portal-ui: trigger-only cascade does NOT bump
eq "$(classify_and_bump portal-ui 'apps/common-dart/trial_data_types/lib/x.dart' '1.0.14' '1.0.14')" \
    "" "portal-ui trial_data_types cascade -> no bump (semver-only)"

# portal-ui: own-source change with inherited +N strips it
eq "$(classify_and_bump portal-ui 'apps/sponsor-portal/portal-ui/lib/main.dart' '1.0.14+51' '1.0.14')" \
    "1.0.15" "portal-ui lib/ change strips inherited +51"

# portal-ui: README change -> no bump (own non-source)
eq "$(classify_and_bump portal-ui 'apps/sponsor-portal/portal-ui/README.md' '1.0.14' '1.0.14')" \
    "" "portal-ui README change -> no bump"

# clinical_diary (standard mode): own-source change still bumps semver+build
eq "$(classify_and_bump clinical_diary 'apps/daily-diary/clinical_diary/lib/foo.dart' '0.1.0+11' '0.1.0+11')" \
    "0.1.1+12" "clinical_diary lib/ change -> +N still applied (standard)"

# clinical_diary (standard mode): cascade -> build-only bump
eq "$(classify_and_bump clinical_diary 'apps/common-dart/trial_data_types/lib/x.dart' '0.1.0+11' '0.1.0+11')" \
    "0.1.0+12" "clinical_diary cascade -> build-only bump (standard)"

# diary_server (standard mode): bin/ change -> +N applied
eq "$(classify_and_bump diary_server 'apps/daily-diary/diary_server/bin/server.dart' '0.1.0+11' '0.1.0+11')" \
    "0.1.1+12" "diary_server bin/ change -> +N applied (standard)"

# ===== Summary =====
echo ""
if [ "$FAIL" -eq 0 ]; then
    printf 'All %d assertions passed.\n' "$PASS"
    exit 0
else
    printf '%d passed, %d failed.\n' "$PASS" "$FAIL"
    exit 1
fi
