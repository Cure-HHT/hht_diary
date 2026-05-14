#!/usr/bin/env bash
# Reproduce the cross-file REQ ID collision bug in a clean temp directory.
# Requires elspais to be on PATH.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d -t elspais-dup-repro.XXXXXX)"
trap 'echo ""; echo "Repro left in: $TMP"' EXIT

echo "=== Copying repro into $TMP ==="
cp -r "$HERE"/.elspais.toml "$HERE"/spec "$TMP"/

cd "$TMP"
git init -q
git add .
git -c user.email=repro@example.com -c user.name=repro commit -qm "repro init"

echo ""
echo "=== elspais version ==="
elspais --version

echo ""
echo "=== Step 1: elspais checks ==="
echo "Expected bug: spec.no_duplicates passes despite cross-file collision."
echo ""
elspais checks 2>&1 | grep -E "no_duplicates|^✓ SPEC|^⚠ SPEC|^✗ SPEC" || true

echo ""
echo "=== Step 2: graph shows REQ-d00001 with merged parents ==="
elspais graph 2>/dev/null | python3 -c '
import json, sys
g = json.load(sys.stdin)
n = g["nodes"].get("REQ-d00001")
if not n:
    print("REQ-d00001 not found in graph")
    sys.exit(1)
c = n["content"]
print("  label:                   ", repr(n["label"]))
print("  source:                  ", n["source"])
print("  content.implements_refs: ", c.get("implements_refs"))
print("  content.refines_refs:    ", c.get("refines_refs"))
print("  parents (merged across both files):")
for p in n["parents"]:
    print("                            ", p)
'

echo ""
echo "=== Step 3: elspais fix materializes the merge on disk ==="
echo "Before:"
echo "--- spec/dev-file-b.md (lines 5-7) ---"
sed -n "5,7p" spec/dev-file-b.md
echo ""

elspais fix 2>&1 | grep -E "Fixing|Rewrote" | head -5

echo ""
echo "After:"
echo "--- spec/dev-file-b.md (frontmatter) ---"
sed -n "5,8p" spec/dev-file-b.md
echo ""

if grep -q "^\*\*Refines\*\*: REQ-p00001" spec/dev-file-b.md; then
    echo "BUG REPRODUCED: 'Refines: REQ-p00001' appeared in spec/dev-file-b.md"
    echo "even though it was never written there by a human. It was inherited"
    echo "from spec/dev-file-a.md via the silent cross-file REQ ID merge."
else
    echo "Could not reproduce - elspais behavior may have changed."
    exit 1
fi
