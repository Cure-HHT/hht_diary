#!/usr/bin/env python3
"""CUR-1451 sweep verifier — the definition of done.

elspais does not scan shell/yaml/ruby/tf annotations, so the requirement graph
cannot flag this debt; this script is the source of truth for the sweep. It
fails (non-zero) while any of the following remain in the code/CI tree (the spec
trees and docs are excluded):

  1. legacy URS ids            REQ-{p|o|d}NNNNN / GUI-pNNNNN (incl. CAL-)
  2. file-header blocks        `IMPLEMENTS REQUIREMENTS:`
  3. dangling annotations      `// Implements:` / `# Verifies:` citing a
                               DIARY-* req id or assertion label that does not
                               exist in the current spec/ tree

Cross-repo citations (HHT-*, EVS-*, CAL-*) are not validated locally — only
their syntax is sanity-checked.

Wire into pre-push once green. Run:  python3 tools/requirements/verify_annotations.py
Exit 0 = clean, 1 = violations.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

EXCLUDE_DIRS = {
    ".git", "spec", "spec-archive", "docs",
    ".dart_tool", "build", ".fvm", "node_modules", ".gradle",
    "tools/requirements",
}

# CUR-1451 decision (b): infrastructure / IaC / dev-container trees are deferred
# to the infra-move ticket and left OUT of this PR's verifier scope. Their legacy
# ids remain tracked in inventory.json (disposition=cross-repo, deferred=true) for
# that ticket to consume. build_inventory.py still scans these (full record); only
# the verifier skips them.
DEFERRED_DIRS = {
    "infrastructure", "deployment", ".devcontainer",
    "tools/dev-env", "tools/cost-control",
    "apps/common-dart/grpc_health",
    "apps/common-dart/dart-base-container",
    "apps/common-dart/flutter-base-container",
}

# Code + CI + IaC only (see build_inventory.py for rationale).
CODE_EXT = {
    ".dart", ".yml", ".yaml", ".sh", ".bash",
    ".tf", ".tfvars", ".rb", ".py", ".gradle", ".kts",
}
GENERATED_RE = re.compile(r"\.(?:g|freezed|gr|mocks|config)\.dart$")


def in_scope(rel: Path) -> bool:
    name = rel.name
    if GENERATED_RE.search(name):
        return False
    if name == "Dockerfile" or name.endswith(".Dockerfile"):
        return True
    return rel.suffix in CODE_EXT

LEGACY_RE = re.compile(r"\b(?:REQ|GUI)-(?:CAL-)?[pod]\d{5}\b")
HEADER_RE = re.compile(r"IMPLEMENTS REQUIREMENTS")
# An annotation line: `// Implements: <ref...>` or `# Verifies: <ref...>`.
ANNOT_RE = re.compile(r"(?://|#)\s*(Implements|Verifies):\s*(.+)$")
# A single ref within an annotation: id optionally followed by /A or /A+B+C.
REF_RE = re.compile(
    r"\b((?:DIARY|CAL|HHT|EVS)-(?:PRD|GUI|BASE|OPS|DEV)-[a-z0-9][a-z0-9-]*)"
    r"((?:/[A-Z](?:\+[A-Z])*)*)"
)


_SKIP_DIRS = EXCLUDE_DIRS | DEFERRED_DIRS


def is_excluded(rel: Path) -> bool:
    parts = rel.parts
    for i in range(len(parts)):
        if parts[i] in _SKIP_DIRS or "/".join(parts[: i + 1]) in _SKIP_DIRS:
            return True
    return False


def load_deferred_ids() -> set[str]:
    """Legacy ids deferred to the infra-move ticket (allowed to remain in scope)."""
    inv = REPO / "tools" / "requirements" / "inventory.json"
    if not inv.exists():
        return set()
    try:
        data = json.loads(inv.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return set()
    return {k for k, v in data.get("ids", {}).items() if v.get("deferred")}


def iter_text_files():
    for path in REPO.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(REPO)
        if is_excluded(rel):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        # In scope by extension/name, or an extensionless shell script (git
        # hooks like .githooks/commit-msg have a shebang but no suffix).
        if not in_scope(rel) and not (
            not rel.suffix and text.startswith("#!") and
            ("sh" in text.splitlines()[0])
        ):
            continue
        yield rel, text


def load_assertions() -> dict[str, set[str]]:
    """Map each current DIARY-* req id to the set of its assertion labels."""
    reqs: dict[str, set[str]] = {}
    # Req-id headings are `# DIARY-...` (single-req file) or `## DIARY-...`
    # (multi-req file). Section headings are one level deeper than the req
    # heading (## or ### "Assertions"), so detect any non-req heading.
    head = re.compile(r"^#{1,3}\s+(DIARY-(?:PRD|GUI|BASE|OPS|DEV)-[a-z0-9-]+)\s*:")
    section = re.compile(r"^#{2,4}\s+(.*)")
    assertion = re.compile(r"^\**([A-Z])[.)]\s")
    for md in (REPO / "spec").glob("*.md"):
        current = None
        in_assertions = False
        for line in md.read_text(encoding="utf-8").splitlines():
            if head.match(line):
                current = head.match(line).group(1)
                reqs[current] = set()
                in_assertions = False
                continue
            sm = section.match(line)
            if sm:
                in_assertions = "assertion" in sm.group(1).lower()
                continue
            if current and in_assertions:
                a = assertion.match(line)
                if a:
                    reqs[current].add(a.group(1))
    return reqs


def main() -> int:
    reqs = load_assertions()
    live = set(reqs)
    deferred = load_deferred_ids()

    legacy_hits: dict[str, int] = {}
    header_hits: list[str] = []
    dangling: list[str] = []

    for rel, text in iter_text_files():
        relstr = str(rel)
        # Deferred infra ids (CUR-1451 decision (b)) are allowed to remain.
        n = sum(1 for m in LEGACY_RE.finditer(text) if m.group(0) not in deferred)
        if n:
            legacy_hits[relstr] = n
        if HEADER_RE.search(text):
            header_hits.append(relstr)
        for lineno, line in enumerate(text.splitlines(), 1):
            am = ANNOT_RE.search(line)
            if not am:
                continue
            body = am.group(2)
            if body.strip().upper().startswith("TODO"):
                continue
            for ref in REF_RE.finditer(body):
                req_id = ref.group(1)
                labels = [s for s in ref.group(2).split("/") if s]
                if not req_id.startswith("DIARY-"):
                    continue  # cross-repo; syntax-only
                if req_id not in live:
                    dangling.append(f"{relstr}:{lineno}  unknown req {req_id}")
                    continue
                for grp in labels:
                    for lab in grp.split("+"):
                        if lab and lab not in reqs[req_id]:
                            dangling.append(
                                f"{relstr}:{lineno}  {req_id} has no assertion {lab}")

    ok = not (legacy_hits or header_hits or dangling)

    print("== CUR-1451 annotation verifier ==")
    print(f"legacy-id files:      {len(legacy_hits)}"
          f"  ({sum(legacy_hits.values())} refs)")
    print(f"header-block files:   {len(header_hits)}")
    print(f"dangling annotations: {len(dangling)}")

    if legacy_hits:
        print("\n-- legacy ids remain (top 20) --")
        for f, c in sorted(legacy_hits.items(), key=lambda kv: -kv[1])[:20]:
            print(f"  {c:4d}  {f}")
    if header_hits:
        print("\n-- IMPLEMENTS REQUIREMENTS header blocks (first 20) --")
        for f in sorted(header_hits)[:20]:
            print(f"  {f}")
    if dangling:
        print("\n-- dangling annotations (first 20) --")
        for d in dangling[:20]:
            print(f"  {d}")

    print("\nRESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
