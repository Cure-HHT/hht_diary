#!/usr/bin/env bash
# tools/compile-urs.sh — wraps tools/compile-urs.py.
# 1) Generate federated elspais graph JSON (run from callisto side so both repos are aggregated).
# 2) Run the Python orchestrator.
#
# PREREQUISITE: spec/_generated/glossary.md and spec/_generated/term-index.md
# must be up to date. These are committed to the repo and refreshed by
# `elspais fix` (which the pre-commit hook runs automatically). If you've
# edited spec/ files outside the normal commit flow, run `elspais fix`
# manually before invoking this script.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CAL_WORKTREE="${CAL_WORKTREE:-${REPO_ROOT}/../../hht_diary_callisto-worktrees/URS-1}"

mkdir -p "${REPO_ROOT}/build"

# Run elspais graph from the callisto side to capture federation
(cd "${CAL_WORKTREE}" && elspais graph -o "${REPO_ROOT}/build/graph.json")

python3 "${REPO_ROOT}/tools/compile-urs.py" \
  --graph "${REPO_ROOT}/build/graph.json" \
  --manifest "${REPO_ROOT}/tools/urs-section-map.yaml" \
  --output-md "${REPO_ROOT}/build/urs-assembled.md" \
  --output-pdf "${REPO_ROOT}/docs/urs-compiled.pdf" \
  --template "${REPO_ROOT}/docs/urs-template.latex" \
  --cover "${REPO_ROOT}/docs/urs-cover.tex" \
  --cal-root "${CAL_WORKTREE}"

echo "Done: docs/urs-compiled.pdf"
