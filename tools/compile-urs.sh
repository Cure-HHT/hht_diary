#!/usr/bin/env bash
# tools/compile-urs.sh — wraps tools/compile-urs.py.
# 1) Generate federated elspais graph JSON (run from callisto side so both repos are aggregated).
# 2) Generate federated glossary + term-index (also from callisto, into build/_generated/).
# 3) Run the Python orchestrator.
#
# All elspais commands run from the CAL_WORKTREE so the federated view is
# applied: callisto declares hht_diary as an associate, so running elspais
# from callisto pulls in cross-repo REQs, terms, and references. Running
# from the hht_diary side instead would miss every CAL-* contribution.
#
# build/_generated/ artifacts are recompiled fresh on every run and are
# gitignored. The committed spec/_generated/ files on each repo's side
# represent that repo's local-only view (for in-repo browsing); the
# federated view used in the URS PDF lives only in build/.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAL_WORKTREE="${CAL_WORKTREE:-${REPO_ROOT}/../../hht_diary_callisto-worktrees/URS-1}"

mkdir -p "${REPO_ROOT}/build/_generated"

# 1) Federated graph JSON.
(cd "${CAL_WORKTREE}" && elspais graph -o "${REPO_ROOT}/build/graph.json")

# 2) Federated glossary + term-index. The --output-dir flag overrides
#    the [terms].output_dir config but only takes effect when called
#    through `elspais fix`; bare `elspais glossary` / `elspais term-index`
#    write to stdout regardless. Redirect stdout to the target file.
(cd "${CAL_WORKTREE}" && elspais glossary --format markdown) \
  > "${REPO_ROOT}/build/_generated/glossary.md"
(cd "${CAL_WORKTREE}" && elspais term-index --format markdown) \
  > "${REPO_ROOT}/build/_generated/term-index.md"

python3 "${REPO_ROOT}/tools/compile-urs.py" \
  --graph "${REPO_ROOT}/build/graph.json" \
  --manifest "${REPO_ROOT}/tools/urs-section-map.yaml" \
  --output-md "${REPO_ROOT}/build/urs-assembled.md" \
  --output-pdf "${REPO_ROOT}/docs/urs-compiled.pdf" \
  --template "${REPO_ROOT}/docs/urs-template.latex" \
  --cover "${REPO_ROOT}/docs/urs-cover.tex" \
  --cal-root "${CAL_WORKTREE}"

# 4) Stand-alone Term Index PDF + DOCX. The federated term-index is too
#    large to bundle with the URS body (~200 extra pages, one entry per
#    indexed term with verbatim references) but is still a regulated
#    deliverable; ship it as a sibling file.
pandoc "${REPO_ROOT}/build/_generated/term-index.md" \
  -o "${REPO_ROOT}/docs/urs-term-index.pdf" \
  --pdf-engine xelatex \
  --template "${REPO_ROOT}/docs/urs-template.latex" \
  --variable=cover-tex:"${REPO_ROOT}/docs/urs-term-index-cover.tex" \
  --toc --toc-depth=1 \
  --top-level-division=chapter
pandoc "${REPO_ROOT}/build/_generated/term-index.md" \
  -o "${REPO_ROOT}/docs/urs-term-index.docx"

echo "Done:"
echo "  docs/urs-compiled.pdf"
echo "  docs/urs-term-index.pdf"
