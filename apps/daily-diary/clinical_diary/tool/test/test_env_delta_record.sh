#!/bin/bash
# Verifies: DIARY-OPS-single-promotable-artifact/D
# Tests the controlled-delta generator: (1) committed record is current,
# (2) an undeclared per-flavor key makes generation fail.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="$SCRIPT_DIR/../generate_env_delta_record.sh"
FLAVORIZR="$SCRIPT_DIR/../../android/app/flavorizr.gradle.kts"
pass=0; fail=0
check() { # name, command
  if eval "$2"; then echo "PASS: $1"; pass=$((pass+1));
  else echo "FAIL: $1"; fail=$((fail+1)); fi
}

# 1. Committed record matches a fresh generation.
check "committed record is current" "'$GEN' --check >/dev/null 2>&1"

# 2. Inject an undeclared per-flavor key into the dev block -> generation fails.
tmp="$(mktemp)"
awk '1; /create\("dev"\)/{print "        versionNameSuffix = \"-x\""}' \
  "$FLAVORIZR" > "$tmp"
check "undeclared per-flavor key fails generation" \
  "! CDIARY_FLAVORIZR='$tmp' CDIARY_RECORD=/dev/null '$GEN' >/dev/null 2>&1"
rm -f "$tmp"

echo "----"; echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
