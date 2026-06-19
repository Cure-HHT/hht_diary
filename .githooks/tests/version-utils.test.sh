#!/usr/bin/env bash
# Smoke tests for .githooks/version-utils.sh detection against the
# behavior matrix defined in CUR-1158. Sources project-defs.sh so
# assertions run against the real PROJECT_DEFS.
#
# Usage: ./.githooks/tests/version-utils.test.sh
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

# classify <code_dirs> <triggers> <changed_files>
# Echoes the caller-level outcome: "semver+build", "build-only", or "none".
classify() {
    local code_dirs="$1"
    local triggers="$2"
    local changed="$3"

    if has_code_changes "$code_dirs" "$changed"; then
        echo "semver+build"
    elif has_any_trigger "$triggers" "$changed"; then
        echo "build-only"
    else
        echo "none"
    fi
}

# project_def_for <name>
# Echoes the pipe-delimited PROJECT_DEFS entry for <name>, or empty if missing.
project_def_for() {
    local wanted="$1"
    local def name
    for def in "${PROJECT_DEFS[@]}"; do
        IFS='|' read -r name _ _ _ _ <<< "$def"
        if [ "$name" = "$wanted" ]; then
            printf '%s\n' "$def"
            return 0
        fi
    done
    return 1
}

# assert <project> <changed_files> <expected> <label>
assert() {
    local project="$1"
    local changed="$2"
    local expected="$3"
    local label="$4"

    local def
    if ! def="$(project_def_for "$project")"; then
        FAIL=$((FAIL + 1))
        printf '  FAIL  %-40s project %s not in PROJECT_DEFS\n' "$label" "$project"
        return
    fi

    local name pubspec code_dirs triggers version_mode
    IFS='|' read -r name pubspec code_dirs triggers version_mode <<< "$def"

    local actual
    actual=$(classify "$code_dirs" "$triggers" "$changed")

    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS + 1))
        printf '  ok    %-40s on %-25s -> %s\n' "$label" "$project" "$actual"
    else
        FAIL=$((FAIL + 1))
        printf '  FAIL  %-40s on %-25s expected=%s actual=%s\n' \
            "$label" "$project" "$expected" "$actual"
    fi
}

echo "version-utils.sh behavior matrix tests"
echo "--------------------------------------"

# ---- Own-dir source: semver+build on the owning project -------------
assert clinical_diary  "apps/daily-diary/clinical_diary/lib/foo.dart"       "semver+build" "own lib/*.dart"
assert portal_ui_evs   "apps/sponsor-portal/portal_ui_evs/lib/main.dart"    "semver+build" "own lib/*.dart"
assert portal_ui_evs   "apps/sponsor-portal/portal_ui_evs/assets/logo.png"  "semver+build" "own assets/*"
assert portal_ui_evs   "apps/sponsor-portal/portal_ui_evs/web/index.html"   "semver+build" "own web/*"
assert portal_server_evs "apps/sponsor-portal/portal_server_evs/bin/server.dart" "semver+build" "own bin/*.dart"
assert trial_data_types "apps/common-dart/trial_data_types/lib/x.dart"      "semver+build" "own lib/*.dart"

# ---- Own-dir non-source: no bump ------------------------------------
assert clinical_diary "apps/daily-diary/clinical_diary/test/foo_test.dart"       "none" "own test/*"
assert clinical_diary "apps/daily-diary/clinical_diary/tool/gen.sh"              "none" "own tool/*"
assert clinical_diary "apps/daily-diary/clinical_diary/README.md"                "none" "own README.md"
assert clinical_diary "apps/daily-diary/clinical_diary/analysis_options.yaml"    "none" "own analysis_options.yaml"
assert portal_server_evs "apps/sponsor-portal/portal_server_evs/README.md"       "none" "own README.md (server)"
assert portal_ui_evs  "apps/sponsor-portal/portal_ui_evs/test/widget_test.dart"  "none" "own test/*"

# ---- Unused platform dirs on clinical_diary: no bump ----------------
assert clinical_diary "apps/daily-diary/clinical_diary/macos/Runner/Info.plist" "none" "own macos/* (dev-only)"

# ---- Platform-native build inputs on clinical_diary: build-only -----
assert clinical_diary "apps/daily-diary/clinical_diary/ios/Info.plist"      "build-only" "own ios/* (ships)"
assert clinical_diary "apps/daily-diary/clinical_diary/android/build.gradle" "build-only" "own android/* (ships)"

# ---- Dependency cascade: trial_data_types/lib/ change ---------------
# trial_data_types itself: semver+build. Direct + transitive dependents
# (clinical_diary, portal_server_evs, eq): build-only. Unrelated
# libraries (rave-integration) and non-dependents (portal_ui_evs): none.
echo ""
echo "  -- trial_data_types/lib/ cascade --"
CASCADE_CHANGE="apps/common-dart/trial_data_types/lib/x.dart"
assert trial_data_types  "$CASCADE_CHANGE" "semver+build" "dep origin"
assert clinical_diary    "$CASCADE_CHANGE" "build-only"   "cascade downstream"
assert portal_server_evs "$CASCADE_CHANGE" "build-only"   "cascade downstream"
assert eq                "$CASCADE_CHANGE" "build-only"   "cascade downstream"
assert rave-integration      "$CASCADE_CHANGE" "none"     "non-dependent"

# ---- trial_data_types/test/ non-source: no cascade ------------------
echo ""
echo "  -- trial_data_types/test/ non-cascade --"
NONCASCADE_CHANGE="apps/common-dart/trial_data_types/test/x_test.dart"
assert trial_data_types "$NONCASCADE_CHANGE" "none" "own test/*"
assert clinical_diary   "$NONCASCADE_CHANGE" "none" "test/ does not cascade"
assert portal_server_evs "$NONCASCADE_CHANGE" "none" "test/ does not cascade"

# ---- database/ migration: no live project depends on database/ ------
echo ""
echo "  -- database/ migration --"
DB_CHANGE="database/migrations/0001_add_column.sql"
assert clinical_diary    "$DB_CHANGE" "none" "migration does not affect client"
assert portal_server_evs "$DB_CHANGE" "none" "EVS server has no database/ trigger"
assert portal_ui_evs     "$DB_CHANGE" "none" "migration does not affect UI"

# ---- tools/build/ infra: build-only on deployable apps only ---------
echo ""
echo "  -- tools/build/ infra --"
TOOLS_CHANGE="tools/build/deploy.sh"
assert portal_ui_evs     "$TOOLS_CHANGE" "build-only" "deployable app"
assert portal_server_evs "$TOOLS_CHANGE" "build-only" "deployable app"
assert clinical_diary "$TOOLS_CHANGE" "none"       "clinical_diary has no tools/build trigger"

# ---- Summary --------------------------------------------------------
echo ""
if [ "$FAIL" -eq 0 ]; then
    printf 'All %d assertions passed.\n' "$PASS"
    exit 0
else
    printf '%d passed, %d failed.\n' "$PASS" "$FAIL"
    exit 1
fi
