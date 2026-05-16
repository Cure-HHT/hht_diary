#!/usr/bin/env bash
# Compile the URS PDF from spec/ in hht_diary and hht_diary_callisto, then
# concatenate the two halves into a single document mirroring the original
# Google-doc URS-v1.0 structure.
#
# Usage:
#   tools/compile-urs.sh [output_path]
#
# Requires: elspais (with associates configured), pdfunite (poppler-utils),
# pandoc + xelatex (TeX Live for the elspais pdf engine).

set -euo pipefail

OUT="${1:-docs/urs-compiled.pdf}"
DIARY_ROOT="$(git rev-parse --show-toplevel)"
CAL_ROOT="${CAL_ROOT:-${DIARY_ROOT%/hht_diary*}/hht_diary_callisto-worktrees/$(git -C "$DIARY_ROOT" rev-parse --abbrev-ref HEAD)}"

if [ ! -d "$CAL_ROOT" ]; then
    echo "error: callisto worktree not found at $CAL_ROOT" >&2
    echo "set CAL_ROOT environment variable to override" >&2
    exit 1
fi

DIARY_PDF="$(mktemp -t urs-diary-XXXX.pdf)"
CAL_PDF="$(mktemp -t urs-callisto-XXXX.pdf)"
trap "rm -f '$DIARY_PDF' '$CAL_PDF'" EXIT

# elspais's nested-associates restriction means only one side declares
# associates when pdf-compiling. Move the other side's .elspais.local.toml
# out of the way during each compile.

COVER="$DIARY_ROOT/docs/urs-cover.tex"
TEMPLATE="$DIARY_ROOT/docs/urs-template.latex"

# Federation convention: only the callisto repo declares .elspais.local.toml
# associating hht_diary. hht_diary does NOT declare a callisto associate
# (would create a circular nested-associates error). This keeps elspais
# happy without the toggle dance the script previously needed.

echo "[compile-urs] Building hht_diary PDF (with URS cover + template)..."
elspais -C "$DIARY_ROOT" pdf \
    --output "$DIARY_PDF" \
    --title "eCOA User Requirements Specification" \
    --cover "$COVER" \
    --template "$TEMPLATE" 2>&1 | tail -3

echo "[compile-urs] Building hht_diary_callisto PDF (template only, no cover)..."
elspais -C "$CAL_ROOT" pdf \
    --output "$CAL_PDF" \
    --title "eCOA User Requirements Specification — Callisto Overlays" \
    --template "$TEMPLATE" 2>&1 | tail -3

echo "[compile-urs] Merging halves into $OUT..."
pdfunite "$DIARY_PDF" "$CAL_PDF" "$OUT"

PAGES=$(pdfinfo "$OUT" 2>/dev/null | awk '/^Pages:/{print $2}')
SIZE=$(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT")
echo "[compile-urs] Done. $PAGES pages, $SIZE bytes -> $OUT"
