#!/usr/bin/env bash
# Verifies: DIARY-OPS-hotfix-source-recovery/C
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/forward-port-notice.sh"
fails=0
assert() { if eval "$2"; then echo "ok - $1"; else echo "FAIL - $1"; fails=$((fails+1)); fi; }
G() { git -C "$TMP" -c user.email=t@t -c user.name=t "$@"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
G init -q
G commit -q --allow-empty -m base
G branch -m main 2>/dev/null || G checkout -q -b main
ROOT="$(G rev-parse HEAD)"
G branch baseline/2026-06 "$ROOT"
G checkout -q baseline/2026-06
echo fix > "$TMP/fix.txt"; G add fix.txt; G commit -q -m "[CUR-1552] hotfix: thing"
FIX="$(G rev-parse HEAD)"

# Snapshot repo state (branches + HEAD + status) before running.
BEFORE_BRANCHES="$(G for-each-ref --format='%(refname)' refs/heads | sort)"
BEFORE_HEAD="$(G rev-parse HEAD)"
BEFORE_STATUS="$(G status --porcelain)"

OUT="$( cd "$TMP" && bash "$SCRIPT" "$FIX" baseline/2026-06 )"

# 1. Notice names both targets and the fix sha in cherry-pick commands.
# Assert the cherry-pick verb and the fix SHA independently so the test is
# robust to the SHA being quoted in the printed command.
assert "mentions cherry-pick"               "printf '%s' \"\$OUT\" | grep -q 'cherry-pick -x'"
assert "names the fix sha"                  "printf '%s' \"\$OUT\" | grep -q '${FIX}'"
assert "mentions main target"               "printf '%s' \"\$OUT\" | grep -q 'main'"
assert "mentions baseline target"           "printf '%s' \"\$OUT\" | grep -q 'baseline/2026-06'"
assert "suggests a worktree"                "printf '%s' \"\$OUT\" | grep -qi 'worktree'"
assert "shows the fix subject"              "printf '%s' \"\$OUT\" | grep -q 'hotfix: thing'"

# 2. Read-only: nothing in git changed.
assert "no new branches created" "[ \"\$BEFORE_BRANCHES\" = \"\$(G for-each-ref --format='%(refname)' refs/heads | sort)\" ]"
assert "HEAD did not move"       "[ \"\$BEFORE_HEAD\" = \"\$(G rev-parse HEAD)\" ]"
assert "working tree unchanged"  "[ \"\$BEFORE_STATUS\" = \"\$(G status --porcelain)\" ]"

# 3. Invalid sha fails.
( cd "$TMP" && bash "$SCRIPT" deadbeefdeadbeef baseline/2026-06 ) >/dev/null 2>&1
assert "invalid sha exits non-zero" "[ \$? -ne 0 ]"

[ "$fails" -eq 0 ] || { echo "$fails test(s) failed"; exit 1; }
