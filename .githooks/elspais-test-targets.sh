#!/bin/bash
# =====================================================
# elspais test-target discovery for the pre-push backstop (CUR-1556)
# =====================================================
#
# Single source of truth for "which test targets exist" = the
# [[scanning.test.targets]] list in .elspais.toml — the SAME 17 targets the CI
# traceability-matrix job runs through `elspais checks --run-tests`. The pre-push
# hook runs the affected subset so a developer can't push a test regression that
# CI would later catch. Reading the target list from .elspais.toml (rather than a
# second hand-maintained list) keeps the hook and CI from drifting: add a target
# to .elspais.toml and both pick it up.
#
# Pure bash/sed/awk only — no `realpath --relative-to` (GNU-only) and no
# associative arrays (bash 4+), so it runs on developers' macOS bash 3.2.
#
# Functions:
#   elspais_test_target_dirs <toml>            -> repo-relative target dirs
#   pkg_path_deps <repo_root> <pkg_dir>        -> direct local path: dep dirs
#   pkg_dep_closure <repo_root> <pkg_dir>      -> transitive local path: dep dirs
#   affected_test_targets <repo_root> <toml> <changed_files>
#                                              -> targets whose own dir or any
#                                                 transitive path dep changed

# Collapse '.'/'..' segments in "$base/$rel" to a normalized repo-relative path,
# without touching the filesystem (so it is testable on fixture trees).
_resolve_rel() {
    local combined="$1/$2"
    local seg result_count=0
    local -a out=()
    local OLDIFS="$IFS"
    IFS=/
    for seg in $combined; do
        case "$seg" in
            '' | .) ;;
            ..) [ "${#out[@]}" -gt 0 ] && out=("${out[@]:0:${#out[@]}-1}") ;;
            *) out+=("$seg") ;;
        esac
    done
    result_count=${#out[@]}
    IFS=/
    [ "$result_count" -gt 0 ] && printf '%s' "${out[*]}"
    IFS="$OLDIFS"
}

# Emit each test target's repo-relative dir (the `cwd` of every
# [[scanning.test.targets]]). `cwd` appears only on targets in this config.
elspais_test_target_dirs() {
    local toml="$1"
    [ -f "$toml" ] || return 0
    sed -nE 's/^[[:space:]]*cwd[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/p' "$toml"
}

# Emit the repo-relative dirs of a package's DIRECT local path: dependencies.
pkg_path_deps() {
    local repo_root="$1" pkg_dir="$2"
    local pubspec="$repo_root/$pkg_dir/pubspec.yaml"
    [ -f "$pubspec" ] || return 0
    local rel
    sed -nE 's/^[[:space:]]+path:[[:space:]]*//p' "$pubspec" \
        | sed -E 's/[[:space:]]*#.*$//; s/["'\'']//g; s/[[:space:]]+$//' \
        | while IFS= read -r rel; do
            [ -n "$rel" ] || continue
            _resolve_rel "$pkg_dir" "$rel"
            echo
        done
}

# Transitive closure of local path deps (repo-relative dirs), excluding the
# package itself. Newline-set membership instead of an associative array.
pkg_dep_closure() {
    local repo_root="$1" start="$2"
    local seen="" queue="$start"$'\n' result="" cur d
    while [ -n "$queue" ]; do
        cur="${queue%%$'\n'*}"
        queue="${queue#*$'\n'}"
        [ -n "$cur" ] || continue
        while IFS= read -r d; do
            [ -n "$d" ] || continue
            case $'\n'"$seen" in
                *$'\n'"$d"$'\n'*) continue ;;
            esac
            seen="$seen$d"$'\n'
            result="$result$d"$'\n'
            queue="$queue$d"$'\n'
        done < <(pkg_path_deps "$repo_root" "$cur")
    done
    printf '%s' "$result"
}

# Emit the test targets affected by a set of changed files: a target is affected
# when a changed .dart file (or its tool/test.sh) lives under the target dir OR
# under any of the target's transitive local path dependencies.
affected_test_targets() {
    local repo_root="$1" toml="$2" changed="$3"
    local tdir watch d hit
    while IFS= read -r tdir; do
        [ -n "$tdir" ] || continue
        watch="$tdir"$'\n'"$(pkg_dep_closure "$repo_root" "$tdir")"
        hit=""
        while IFS= read -r d; do
            [ -n "$d" ] || continue
            if printf '%s\n' "$changed" | grep -qE "^${d}/.*(\.dart|tool/test\.sh)$"; then
                hit=1
                break
            fi
        done <<< "$watch"
        [ -n "$hit" ] && echo "$tdir"
    done < <(elspais_test_target_dirs "$toml")
    # Never leak grep's no-match status to a `set -e` caller.
    return 0
}
