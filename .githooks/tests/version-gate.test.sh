#!/usr/bin/env bash
# Integration tests for .githooks/version-gate.sh::run_version_gate.
# Builds a throwaway repo with origin/main and exercises the rebase case:
# a code change whose pubspec version still equals main must be auto-corrected.
#
# Usage: ./.githooks/tests/version-gate.test.sh
# Exits 0 on all pass, 1 on any failure.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0; FAIL=0
eq() {
    local actual="$1" expected="$2" label="$3"
    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS + 1)); printf '  ok    %-55s -> %s\n' "$label" "$actual"
    else
        FAIL=$((FAIL + 1)); printf '  FAIL  %-55s expected=%q actual=%q\n' "$label" "$expected" "$actual"
    fi
}

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
git init -q -b main "$WORK/origin.git" --bare
git clone -q "$WORK/origin.git" "$WORK/clone"
cd "$WORK/clone"
git config user.email t@t.test; git config user.name tester

# main has pkg at 0.1.0+5
mkdir -p pkg/lib
printf 'name: pkg\nversion: 0.1.0+5\n' > pkg/pubspec.yaml
echo 'void main() {}' > pkg/lib/x.dart
git add -A; git commit -qm "[CUR-1] init"; git push -q origin main

# feature branch: change code but leave version equal to main (the rebase bug)
git checkout -q -b CUR-9999-feature
echo 'void main() { /* change */ }' > pkg/lib/x.dart
git add -A; git commit -qm "[CUR-9999] edit code, forgot bump"

export HHT_CACHE_DIR="$WORK/cache"; mkdir -p "$HHT_CACHE_DIR"
source "$HOOKS_DIR/version-utils.sh"
source "$HOOKS_DIR/fetch-cache.sh"
# controlled single-project def pointing at the temp repo's pkg
PROJECT_DEFS=("pkg|pkg/pubspec.yaml|pkg/lib/||standard")
source "$HOOKS_DIR/version-gate.sh"

echo "version-gate tests"; echo "------------------"
ensure_main_fresh

run_version_gate "$WORK/clone"; gate_rc=$?
eq "$gate_rc" "1"                                            "under-bump -> returns 1 (corrected)"
eq "$(grep '^version:' pkg/pubspec.yaml | sed 's/version: //')" "0.1.1+6" "pubspec auto-bumped to main_build+1, patch+1"
eq "$(git log -1 --pretty=%s)" "[CUR-9999] chore: bump versions to satisfy main-aware gate" "bump commit created with ticket prefix"

# Second run is now clean -> returns 0, no new commit
before="$(git rev-parse HEAD)"
ensure_main_fresh
run_version_gate "$WORK/clone"; gate_rc2=$?
eq "$gate_rc2" "0"                                           "already-bumped -> returns 0 (clean)"
eq "$(git rev-parse HEAD)" "$before"                        "clean run creates no commit"

echo ""; echo "  PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
