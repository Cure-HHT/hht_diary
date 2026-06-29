#!/bin/bash
# =====================================================
# Rebase-proof version bump verification + auto-correction
# =====================================================
# Sourced by pre-push and by tests. Depends on (sourced by the caller):
#   version-utils.sh  verify_version_bumped_for, compute_new_version_for,
#                     has_code_changes, has_any_trigger
#   fetch-cache.sh    main_version_for; MAIN_SHA (set by ensure_main_fresh)
#   project-defs.sh   PROJECT_DEFS
#
# run_version_gate [repo_root]
#   0  every changed package is already bumped > origin/main (or no main ref)
#   1  one or more packages were under-bumped: corrected + a bump commit was
#      created; the caller MUST abort the push so the fix is re-pushed
#   2  a pub get during correction failed; caller must abort

run_version_gate() {
    local repo_root="${1:-$(git rev-parse --show-toplevel)}"
    local main_sha="${MAIN_SHA:-}"
    [ -n "$main_sha" ] || { echo "version-gate: no origin/main ref; skipping" >&2; return 0; }

    local range_files
    range_files="$(git diff --name-only "$main_sha"...HEAD 2>/dev/null || true)"

    local corrected=()
    local project_def name pubspec code_dirs triggers version_mode
    for project_def in "${PROJECT_DEFS[@]}"; do
        IFS='|' read -r name pubspec code_dirs triggers version_mode <<< "$project_def"
        local full_pubspec="$repo_root/$pubspec"
        [ -f "$full_pubspec" ] || continue

        local code_changed=false any_trigger=false
        if has_code_changes "$code_dirs" "$range_files"; then
            code_changed=true; any_trigger=true
        elif has_any_trigger "$triggers" "$range_files"; then
            any_trigger=true
        fi
        [ "$any_trigger" = true ] || continue

        local current main_version new_version
        current="$(grep '^version:' "$full_pubspec" | sed 's/version: //')"
        main_version="$(main_version_for "$pubspec")"

        if verify_version_bumped_for "$version_mode" "$current" "${main_version:-0}" "$code_changed"; then
            continue
        fi

        new_version="$(compute_new_version_for "$version_mode" "$current" "${main_version:-$current}" "$code_changed")"
        [ -n "$new_version" ] || continue

        if sed --version >/dev/null 2>&1; then
            sed -i "s/^version: .*/version: ${new_version}/" "$full_pubspec"
        else
            sed -i '' "s/^version: .*/version: ${new_version}/" "$full_pubspec"
        fi
        git add "$full_pubspec"
        corrected+=("$name: $current -> $new_version")

        local project_dir="$repo_root/$(dirname "$pubspec")"
        local lock_file="$project_dir/pubspec.lock"
        if git ls-files --error-unmatch "$lock_file" >/dev/null 2>&1; then
            if grep -q "flutter:" "$project_dir/pubspec.yaml" 2>/dev/null && command -v flutter >/dev/null 2>&1; then
                (cd "$project_dir" && flutter pub get --suppress-analytics) >/dev/null 2>&1 \
                    || { echo "version-gate: pub get failed in $(dirname "$pubspec")" >&2; return 2; }
            elif command -v dart >/dev/null 2>&1; then
                (cd "$project_dir" && dart pub get) >/dev/null 2>&1 \
                    || { echo "version-gate: pub get failed in $(dirname "$pubspec")" >&2; return 2; }
            fi
            git add "$lock_file"
        fi
    done

    [ "${#corrected[@]}" -gt 0 ] || return 0

    local branch ticket prefix
    branch="$(git branch --show-current 2>/dev/null || echo "")"
    ticket="$(printf '%s' "$branch" | grep -oE 'CUR-[0-9]+' | head -1 || true)"
    prefix=""
    [ -n "$ticket" ] && prefix="[$ticket] "
    git commit -m "${prefix}chore: bump versions to satisfy main-aware gate" --no-verify >/dev/null
    printf 'version-gate: corrected under-bumped package(s):\n' >&2
    printf '   %s\n' "${corrected[@]}" >&2
    return 1
}
