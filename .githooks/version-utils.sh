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
# has_code_changes <code_dirs> <changed_files>
# Returns 0 if any file in changed_files lies under any of the declared
# code_dirs (own-project source/ship paths from project-defs.sh, e.g.
# lib/, bin/, assets/, web/). Non-source own-dir changes (test/, tool/,
# README, analysis_options.yaml, pubspec.*) never match because they are
# outside the code_dirs list.
has_code_changes() {
    local code_dirs="$1"
    local changed_files="$2"

    local dir
    for dir in $code_dirs; do
        if echo "$changed_files" | grep -q "^${dir}"; then
            return 0
        fi
    done
    return 1
}

# has_any_trigger <trigger_paths> <changed_files>
# Returns 0 if any file in changed_files lies under any external trigger
# path (dependency lib/assets, infra, platform-native build inputs).
# Triggers are purely external: the project's own root is not a trigger,
# so no self-exclusion logic is needed. Own-dir source is handled by
# has_code_changes; own-dir non-source files (test/, tool/, README)
# produce no bump.
has_any_trigger() {
    local triggers="$1"
    local changed_files="$2"

    local trigger
    for trigger in $triggers; do
        if echo "$changed_files" | grep -q "^${trigger}"; then
            return 0
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
#   1. Semver must never decrease vs main (defends against stale branches
#      whose pubspec was bumped against an old main_semver — git's merge
#      mechanics catch most of these via "branch out of date," but
#      depending on branch protection settings the bad value can
#      otherwise slip through)
#   2. Build number must be greater than main's build number
#   3. If code_changed, semver must be greater than main's semver
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

    # Semver must never go backward, regardless of code_changed
    if _semver_gt "$main_semver" "$current_semver"; then
        return 1
    fi

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

# compute_new_version_semver_only <current_version> <main_version>
# Bumps semver patch when main's semver hasn't moved; preserves a manual
# minor or major bump in current. Strips any inherited +N — semver-only
# projects must never carry a build identifier in pubspec because the
# build identifier is assigned downstream (callisto's portal-final
# Dockerfile composes APP_VERSION = <semver>+cb-<short_sha>).
#
# Caller is responsible for only invoking this when own-source code
# changed; trigger-only invocations on a semver-only project should
# produce no bump (handled by compute_new_version_for).
compute_new_version_semver_only() {
    local current_version="$1"
    local main_version="$2"

    local current_semver main_semver
    current_semver="$(extract_semver "$current_version")"
    main_semver="$(extract_semver "$main_version")"

    if _semver_gt "$current_semver" "$main_semver"; then
        echo "$current_semver"
    else
        _bump_patch "$main_semver"
    fi
}

# verify_version_bumped_semver_only <current_version> <main_version> <code_changed>
# Pass iff (a) current carries no +N, (b) semver never decreases vs main,
# and (c) when code changed, semver strictly increased relative to main.
# Trigger-only changes don't require a bump for semver-only projects, but
# the no-backward-semver invariant still applies.
verify_version_bumped_semver_only() {
    local current_version="$1"
    local main_version="$2"
    local code_changed="$3"

    if [[ "$current_version" == *+* ]]; then
        return 1
    fi

    local current_semver main_semver
    current_semver="$(extract_semver "$current_version")"
    main_semver="$(extract_semver "$main_version")"

    # Semver must never go backward, regardless of code_changed
    if _semver_gt "$main_semver" "$current_semver"; then
        return 1
    fi

    if [ "$code_changed" = "true" ]; then
        if ! _semver_gt "$current_semver" "$main_semver"; then
            return 1
        fi
    fi

    return 0
}

# compute_new_version_for <version_mode> <current> <main> <code_changed>
# Dispatches by version_mode (from PROJECT_DEFS). Standard mode mirrors
# compute_new_version. Semver-only mode bumps semver on a code change and
# emits empty (no bump) on a trigger-only change.
compute_new_version_for() {
    local mode="$1"
    local current="$2"
    local main="$3"
    local code_changed="$4"

    case "$mode" in
        standard)
            compute_new_version "$current" "$main" "$code_changed"
            ;;
        semver-only)
            if [ "$code_changed" = "true" ]; then
                compute_new_version_semver_only "$current" "$main"
            fi
            ;;
        *)
            echo "ERROR: unknown version_mode '$mode'" >&2
            return 1
            ;;
    esac
}

# verify_version_bumped_for <version_mode> <current> <main> <code_changed>
# Dispatches by version_mode. See compute_new_version_for for the modes.
verify_version_bumped_for() {
    local mode="$1"
    local current="$2"
    local main="$3"
    local code_changed="$4"

    case "$mode" in
        standard)
            verify_version_bumped "$current" "$main" "$code_changed"
            ;;
        semver-only)
            verify_version_bumped_semver_only "$current" "$main" "$code_changed"
            ;;
        *)
            echo "ERROR: unknown version_mode '$mode'" >&2
            return 1
            ;;
    esac
}
