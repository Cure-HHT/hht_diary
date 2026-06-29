#!/bin/bash
# =====================================================
# Shared origin/main fetch + version cache for git hooks
# =====================================================
# Sourced by pre-commit and pre-push. Also runnable directly to prime the
# cache right after a known merge:
#   .githooks/fetch-cache.sh --force
#
# Tunables (env):
#   HHT_MAIN_FETCH_TTL    seconds before a re-fetch (default 90)
#   HHT_MAIN_FETCH_FORCE  =1 forces a fetch regardless of TTL
#   HHT_CACHE_DIR         override cache dir (tests; default = git common dir)
#   HHT_NOW_EPOCH         override "now" in seconds (tests; default date +%s)

_fc_cache_dir() {
    if [ -n "${HHT_CACHE_DIR:-}" ]; then
        echo "$HHT_CACHE_DIR"
    else
        git rev-parse --git-common-dir 2>/dev/null || echo ".git"
    fi
}

_fc_now() { echo "${HHT_NOW_EPOCH:-$(date +%s)}"; }

# ensure_main_fresh [--force]  -> sets MAIN_SHA, MAIN_REF_CHANGED
ensure_main_fresh() {
    local force=0
    [ "${1:-}" = "--force" ] && force=1
    [ "${HHT_MAIN_FETCH_FORCE:-}" = "1" ] && force=1

    local ttl="${HHT_MAIN_FETCH_TTL:-90}"
    # Normalize a non-integer TTL back to the default so the numeric -lt below
    # can't emit "integer expression expected".
    [[ "$ttl" =~ ^[0-9]+$ ]] || ttl=90
    local dir; dir="$(_fc_cache_dir)"
    local meta="$dir/hht-main-cache"
    local now; now="$(_fc_now)"

    local last_fetch=0 cached_sha=""
    if [ -f "$meta" ]; then
        read -r last_fetch cached_sha < "$meta" 2>/dev/null || { last_fetch=0; cached_sha=""; }
        [[ "$last_fetch" =~ ^[0-9]+$ ]] || last_fetch=0
    fi

    local age=$(( now - last_fetch ))
    if [ "$force" -eq 0 ] && [ "$last_fetch" -gt 0 ] && [ "$age" -lt "$ttl" ]; then
        : # cache fresh enough — skip fetch
    else
        if ! git fetch --quiet origin main 2>/dev/null; then
            printf 'fetch-cache: warning: could not fetch origin/main; using local ref\n' >&2
        fi
    fi

    MAIN_SHA="$(git rev-parse origin/main 2>/dev/null || git rev-parse main 2>/dev/null || echo "")"
    if [ "$MAIN_SHA" = "$cached_sha" ]; then MAIN_REF_CHANGED=0; else MAIN_REF_CHANGED=1; fi

    mkdir -p "$dir"
    printf '%s %s\n' "$now" "$MAIN_SHA" > "$meta"
    [ "$MAIN_REF_CHANGED" -eq 1 ] && : > "$dir/hht-main-versions"

    export MAIN_SHA MAIN_REF_CHANGED
}

# main_version_for <pubspec_path>  -> echoes origin/main's version: value
main_version_for() {
    local pubspec="$1"
    local dir; dir="$(_fc_cache_dir)"
    local vcache="$dir/hht-main-versions"
    local sha="${MAIN_SHA:-}"
    [ -n "$sha" ] || return 0

    if [ -f "$vcache" ]; then
        local line
        line="$(grep -F "${sha}"$'\t'"${pubspec}"$'\t' "$vcache" 2>/dev/null | head -1)"
        if [ -n "$line" ]; then echo "${line##*$'\t'}"; return 0; fi
    fi

    local version
    version="$(git show "${sha}:${pubspec}" 2>/dev/null | grep '^version:' | sed 's/version: //' || true)"
    mkdir -p "$dir"
    printf '%s\t%s\t%s\n' "$sha" "$pubspec" "$version" >> "$vcache"
    echo "$version"
}

# verify_short_circuit_ok <head_sha> -> 0 if last green verify matches (head, MAIN_SHA)
verify_short_circuit_ok() {
    local head="$1"
    local dir; dir="$(_fc_cache_dir)"
    local f="$dir/hht-verify-state"
    [ -f "$f" ] || return 1
    local v_head v_main
    read -r v_head v_main < "$f" 2>/dev/null || return 1
    [ "$v_head" = "$head" ] && [ "$v_main" = "${MAIN_SHA:-}" ]
}

# record_verify_pass <head_sha>
record_verify_pass() {
    local head="$1"
    local dir; dir="$(_fc_cache_dir)"
    mkdir -p "$dir"
    printf '%s %s\n' "$head" "${MAIN_SHA:-}" > "$dir/hht-verify-state"
}

# Direct invocation: prime/refresh the cache
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    ensure_main_fresh "${1:-}"
    echo "origin/main = ${MAIN_SHA:-<none>} (changed=${MAIN_REF_CHANGED})"
fi
