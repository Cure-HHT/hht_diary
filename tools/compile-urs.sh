#!/usr/bin/env bash
# Compile the URS PDF from spec/ in hht_diary and hht_diary_callisto plus
# a URS-shaped frontmatter (Cover + Introduction + Revision History +
# Signatures) and Appendices (URS §7), merged into a single document that
# mirrors the original Google-doc URS-v1.0 structure.
#
# Pipeline:
#   1. pandoc:  cover + frontmatter (intro/revision/signatures) -> front.pdf
#   2. elspais: hht_diary spec/ -> diary.pdf       (no cover, no maketitle)
#   3. elspais: callisto spec/  -> callisto.pdf    (no cover, no maketitle)
#   4. pandoc:  appendices.md   -> appendices.pdf  (no cover)
#   5. pypdf:   merge in order, preserving hyperlinks
#
# Usage:
#   tools/compile-urs.sh [output_path]
#
# Requires: elspais, pandoc, xelatex (TeX Live), python3 + pypdf.

set -euo pipefail

OUT="${1:-docs/urs-compiled.pdf}"
DIARY_ROOT="$(git rev-parse --show-toplevel)"
CAL_ROOT="${CAL_ROOT:-${DIARY_ROOT%/hht_diary*}/hht_diary_callisto-worktrees/$(git -C "$DIARY_ROOT" rev-parse --abbrev-ref HEAD)}"

if [ ! -d "$CAL_ROOT" ]; then
    echo "error: callisto worktree not found at $CAL_ROOT" >&2
    echo "set CAL_ROOT environment variable to override" >&2
    exit 1
fi

FRONT_PDF="$(mktemp -t urs-front-XXXX.pdf)"
DIARY_PDF="$(mktemp -t urs-diary-XXXX.pdf)"
CAL_PDF="$(mktemp -t urs-callisto-XXXX.pdf)"
APP_PDF="$(mktemp -t urs-appendices-XXXX.pdf)"
trap "rm -f '$FRONT_PDF' '$DIARY_PDF' '$CAL_PDF' '$APP_PDF'" EXIT

COVER="$DIARY_ROOT/docs/urs-cover.tex"
TEMPLATE="$DIARY_ROOT/docs/urs-template.latex"
FRONTMATTER="$DIARY_ROOT/docs/urs-frontmatter.md"
APPENDICES="$DIARY_ROOT/docs/urs-appendices.md"

# Federation convention: only the callisto repo declares .elspais.local.toml
# associating hht_diary. hht_diary does NOT declare a callisto associate
# (would create a circular nested-associates error).

# 1. Cover + Frontmatter (Introduction / Revision History / Signatures)
echo "[compile-urs] Building cover + frontmatter PDF (pandoc direct)..."
pandoc "$FRONTMATTER" \
    --pdf-engine=xelatex \
    --template="$TEMPLATE" \
    --from=markdown+raw_tex \
    --top-level-division=chapter \
    --toc \
    -V cover-tex="$COVER" \
    -V title="eCOA User Requirements Specification" \
    -o "$FRONT_PDF" 2>&1 | tail -3

# 2. hht_diary body (no cover, no maketitle, no TOC — single TOC in cover half)
echo "[compile-urs] Building hht_diary body PDF (elspais, no cover)..."
elspais -C "$DIARY_ROOT" pdf \
    --output "$DIARY_PDF" \
    --title "eCOA User Requirements Specification" \
    --template "$TEMPLATE" 2>&1 | tail -3

# 3. callisto body (no cover, no TOC)
echo "[compile-urs] Building hht_diary_callisto body PDF (elspais, no cover)..."
elspais -C "$CAL_ROOT" pdf \
    --output "$CAL_PDF" \
    --title "eCOA User Requirements Specification — Callisto Overlays" \
    --template "$TEMPLATE" 2>&1 | tail -3

# 4. Appendices (§7) via pandoc directly so --resource-path resolves the
# extracted URS images. elspais's pdf compile doesn't accept extra pandoc
# args, so we bypass it for this half.
echo "[compile-urs] Building appendices PDF (pandoc direct, images in scope)..."
pandoc "$APPENDICES" \
    --pdf-engine=xelatex \
    --template="$TEMPLATE" \
    --from=markdown+raw_tex \
    --top-level-division=chapter \
    --resource-path="$DIARY_ROOT/docs/urs-extracted-images" \
    -V title="eCOA User Requirements Specification — Appendices" \
    -o "$APP_PDF" 2>&1 | tail -3

# 5. Merge in order (pypdf preserves hyperlinks; pdfunite would strip them)
echo "[compile-urs] Merging halves into $OUT (pypdf, preserves links)..."
/usr/bin/python3 "$DIARY_ROOT/tools/pdf-merge-with-links.py" "$OUT" \
    "$FRONT_PDF" "$DIARY_PDF" "$CAL_PDF" "$APP_PDF" 2>&1 | grep -v "Annotation sizes differ" || true

PAGES=$(pdfinfo "$OUT" 2>/dev/null | awk '/^Pages:/{print $2}')
SIZE=$(stat -c%s "$OUT" 2>/dev/null || stat -f%z "$OUT")
echo "[compile-urs] Done. $PAGES pages, $SIZE bytes -> $OUT"
