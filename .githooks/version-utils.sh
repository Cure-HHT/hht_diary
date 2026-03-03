#!/bin/bash
# =====================================================
# Shared Version Utilities for Git Hooks and CI
# =====================================================
#
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00006-C: Increment version numbers following semantic versioning
#   REQ-d00057-E: Build commands reproducible across local and CI environments
#   REQ-o00017-F: Pre-commit hooks run automatically before accepting commits
#
# Single source of truth for all version logic.
# Sourced by .githooks/pre-commit and .github/scripts/validate-pr.sh
#
# Two independent concerns:
#   Code changed  → semver bump (patch) + build bump
#   Build trigger → build bump only
# Both can happen together. Build numbers never reset on semver bumps.

# extract_build_number "0.1.0+11" → "11"
# extract_build_number "0.1.0"    → "0"
extract_build_number() {
    local version="$1"
    if [[ "$version" == *"+"* ]]; then
        echo "${version##*+}"
    else
        echo "0"
    fi
}

# extract_semver "0.1.0+11" → "0.1.0"
# extract_semver "0.1.0"    → "0.1.0"
extract_semver() {
    local version="$1"
    echo "${version%%+*}"
}

# IMPLEMENTS: REQ-o00017-G (validate requirements before accepting commits)
# has_code_changes <own_dir> <changed_files>
# Returns 0 if files in the project's own directory changed
# (excluding pubspec.yaml/pubspec.lock to avoid self-trigger).
has_code_changes() {
    local own_dir="$1"
    local changed_files="$2"

    local relevant
    relevant=$(echo "$changed_files" | grep "^${own_dir}" | grep -v "pubspec\.yaml" | grep -v "pubspec\.lock" || true)
    [ -n "$relevant" ]
}

# has_any_trigger <trigger_paths> <changed_files> <own_dir>
# Returns 0 if any trigger path matches (code, dependency, or infra).
# Uses self-trigger exclusion for own_dir.
has_any_trigger() {
    local triggers="$1"
    local changed_files="$2"
    local own_dir="$3"

    local trigger relevant
    for trigger in $triggers; do
        if echo "$changed_files" | grep -q "^${trigger}"; then
            if [ "$trigger" = "$own_dir" ]; then
                # Own directory: exclude pubspec changes (avoid self-trigger)
                relevant=$(echo "$changed_files" | grep "^${trigger}" | grep -v "pubspec\.yaml" | grep -v "pubspec\.lock" || true)
            else
                # Dependency/infra directory: allow all changes including pubspec bumps (cascade)
                relevant=$(echo "$changed_files" | grep "^${trigger}" || true)
            fi
            if [ -n "$relevant" ]; then
                return 0
            fi
        fi
    done
    return 1
}

# _bump_patch "0.1.0" → "0.1.1"
_bump_patch() {
    local semver="$1"
    local major minor patch
    IFS='.' read -r major minor patch <<< "$semver"
    echo "${major}.${minor}.$((patch + 1))"
}

# _semver_gt "0.2.0" "0.1.0" → returns 0 (true)
# Returns 0 if $1 > $2 using numeric dot-separated comparison
_semver_gt() {
    local IFS=.
    local i a=($1) b=($2)
    for ((i=0; i<${#a[@]}; i++)); do
        [[ -z "${b[i]}" ]] && b[i]=0
        if ((10#${a[i]} > 10#${b[i]})); then return 0; fi
        if ((10#${a[i]} < 10#${b[i]})); then return 1; fi
    done
    return 1
}

# compute_new_version <current_version> <main_version> <code_changed>
# Returns the new version string.
#
# code_changed=true:  bump semver patch (if dev hasn't bumped minor/major) + build
#   "0.1.0+11" (main: "0.1.0+11") → "0.1.1+12"
#   "0.2.0"    (main: "0.1.0+11") → "0.2.0+12"  (dev already bumped minor)
#
# code_changed=false: bump build number only
#   "0.1.0+11" (main: "0.1.0+11") → "0.1.0+12"
compute_new_version() {
    local current_version="$1"
    local main_version="$2"
    local code_changed="$3"

    local main_build current_semver main_semver new_build new_semver

    main_build=$(extract_build_number "$main_version")
    new_build=$((main_build + 1))

    current_semver=$(extract_semver "$current_version")
    main_semver=$(extract_semver "$main_version")

    if [ "$code_changed" = "true" ]; then
        # Check if dev already bumped semver (minor or major)
        if _semver_gt "$current_semver" "$main_semver"; then
            # Dev manually bumped — keep their semver, add build number
            new_semver="$current_semver"
        else
            # Auto-bump patch
            new_semver=$(_bump_patch "$main_semver")
        fi
    else
        # Infra/dependency only — keep semver, bump build
        new_semver="$current_semver"
    fi

    echo "${new_semver}+${new_build}"
}

# IMPLEMENTS: REQ-o00052-A (CI/CD validation on every PR to protected branches)
# verify_version_bumped <current_version> <main_version> <code_changed>
# Returns 0 if properly bumped, 1 if not. Used by CI (check, don't fix).
#
# Checks:
#   1. Build number must be greater than main's build number
#   2. If code_changed, semver must be greater than main's semver
#      (unless dev manually bumped, in which case any higher semver is fine)
verify_version_bumped() {
    local current_version="$1"
    local main_version="$2"
    local code_changed="$3"

    local current_build main_build current_semver main_semver

    current_build=$(extract_build_number "$current_version")
    main_build=$(extract_build_number "$main_version")
    current_semver=$(extract_semver "$current_version")
    main_semver=$(extract_semver "$main_version")

    # Build number must have increased
    if [ "$current_build" -le "$main_build" ]; then
        return 1
    fi

    # If code changed, semver must have increased
    if [ "$code_changed" = "true" ]; then
        if ! _semver_gt "$current_semver" "$main_semver"; then
            return 1
        fi
    fi

    return 0
}
