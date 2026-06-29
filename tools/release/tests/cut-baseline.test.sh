#!/usr/bin/env bash
# Verifies: DIARY-OPS-neutral-baseline-branch/A+B
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/cut-baseline.sh"
fails=0
assert() { if eval "$2"; then echo "ok - $1"; else echo "FAIL - $1"; fails=$((fails+1)); fi; }

# Fresh throwaway repo with two commits.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
git -C "$TMP" -c user.email=t@t -c user.name=t commit -q --allow-empty -m c1
SHA="$(git -C "$TMP" rev-parse HEAD)"
git -C "$TMP" -c user.email=t@t -c user.name=t commit -q --allow-empty -m c2

# 1. Happy path: branch created at the requested SHA.
( cd "$TMP" && bash "$SCRIPT" 2026-06 "$SHA" ) >/dev/null
assert "creates baseline/2026-06" "git -C '$TMP' rev-parse --verify baseline/2026-06 >/dev/null 2>&1"
assert "branch points at source sha" "[ \"\$(git -C '$TMP' rev-parse baseline/2026-06)\" = \"$SHA\" ]"

# 2. Rejects a sponsor-like version token.
( cd "$TMP" && bash "$SCRIPT" acme-2026-06 "$SHA" ) >/dev/null 2>&1
assert "rejects sponsor token in version" "[ \$? -ne 0 ]"

# 3. Rejects a malformed version.
( cd "$TMP" && bash "$SCRIPT" June2026 "$SHA" ) >/dev/null 2>&1
assert "rejects malformed version" "[ \$? -ne 0 ]"

[ "$fails" -eq 0 ] || { echo "$fails test(s) failed"; exit 1; }
