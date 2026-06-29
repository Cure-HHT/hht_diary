#!/usr/bin/env bash
# Tests for .githooks/fetch-cache.sh: TTL skip, SHA-change detection,
# version cache hit/miss, force refresh, verify short-circuit.
#
# Usage: ./.githooks/tests/fetch-cache.test.sh
# Exits 0 on all pass, 1 on any failure.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
eq() {
    local actual="$1" expected="$2" label="$3"
    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS + 1)); printf '  ok    %-55s -> %s\n' "$label" "$actual"
    else
        FAIL=$((FAIL + 1)); printf '  FAIL  %-55s expected=%q actual=%q\n' "$label" "$expected" "$actual"
    fi
}

# --- build a throwaway repo with a bare "origin" carrying main ---
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git init -q -b main "$WORK/origin.git" --bare
CLONE="$WORK/clone"
git clone -q "$WORK/origin.git" "$CLONE"
cd "$CLONE"
git config user.email t@t.test; git config user.name tester
mkdir -p pkg
printf 'name: pkg\nversion: 0.1.0+5\n' > pkg/pubspec.yaml
git add -A; git commit -qm "[CUR-1] init"
git push -q origin main

export HHT_CACHE_DIR="$WORK/cache"; mkdir -p "$HHT_CACHE_DIR"
source "$HOOKS_DIR/fetch-cache.sh"

echo "fetch-cache tests"; echo "-----------------"

# First call: no cache yet -> fetches, MAIN_SHA set, treated as changed
HHT_NOW_EPOCH=1000 ensure_main_fresh
eq "$([ -n "$MAIN_SHA" ] && echo set || echo empty)" "set"   "first call sets MAIN_SHA"
eq "$MAIN_REF_CHANGED" "1"                                    "first call: ref changed (was empty)"

# Version lookup populates the cache then serves a hit (no git show needed)
eq "$(main_version_for pkg/pubspec.yaml)" "0.1.0+5"          "main_version_for reads version"
rm -f "$CLONE/../origin.git/unreachable" 2>/dev/null || true
eq "$(main_version_for pkg/pubspec.yaml)" "0.1.0+5"          "main_version_for cache hit"

# Second call within TTL -> skip fetch, MAIN_REF_CHANGED=0 (sha unchanged)
HHT_NOW_EPOCH=1030 HHT_MAIN_FETCH_TTL=90 ensure_main_fresh
eq "$MAIN_REF_CHANGED" "0"                                    "within TTL: ref unchanged"

# Verify short-circuit round-trips on (HEAD, MAIN_SHA)
HEAD_SHA="$(git rev-parse HEAD)"
record_verify_pass "$HEAD_SHA"
if verify_short_circuit_ok "$HEAD_SHA"; then eq ok ok "short-circuit hit after record"; else eq miss ok "short-circuit hit after record"; fi
if verify_short_circuit_ok "deadbeef"; then eq hit miss "short-circuit miss on different HEAD"; else eq miss miss "short-circuit miss on different HEAD"; fi

# Advance origin/main; force refresh detects the SHA change + clears version cache
git commit -q --allow-empty -m "[CUR-1] advance"
printf 'name: pkg\nversion: 0.2.0+9\n' > pkg/pubspec.yaml
git add -A; git commit -qm "[CUR-1] bump"; git push -q origin main
HHT_NOW_EPOCH=1040 ensure_main_fresh --force
eq "$MAIN_REF_CHANGED" "1"                                    "force refresh: detects new origin/main sha"
eq "$(main_version_for pkg/pubspec.yaml)" "0.2.0+9"          "version cache invalidated on sha change"

echo ""; echo "  PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
