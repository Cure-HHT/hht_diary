#!/usr/bin/env python3
"""Build the CUR-1451 legacy-annotation sweep inventory.

Scans the working tree (code + CI, excluding the spec trees and docs) for legacy
URS requirement ids and forbidden file-header `IMPLEMENTS REQUIREMENTS:` blocks,
then emits `inventory.json`: one row per unique legacy id with its citation sites
and — where the URS-v1 migration mapping resolves it — the new `DIARY-*` target.

This is the work-list for the sweep. The hard part is the old->new mapping, so
each id carries a `status` (resolved/unresolved) and a `disposition` slot the
Phase-1 passes fill in (port | rewrite | parent-cite | drop | cross-repo).

Run from the repo root:  python3 tools/requirements/build_inventory.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

# Directories never scanned for the sweep. The spec trees define ids (not
# annotations); spec-archive is the read-only legacy reference; docs are notes
# (docs/archive holds the mapping itself); the rest are build/vendor noise.
EXCLUDE_DIRS = {
    ".git", "spec", "spec-archive", "docs",
    ".dart_tool", "build", ".fvm", "node_modules", ".gradle",
    "tools/requirements",  # our own sweep tooling
}

# The sweep targets code + CI + IaC annotations only. Markdown prose, JSON, and
# config (.toml) are out of scope for this mechanical pass (handled separately).
CODE_EXT = {
    ".dart", ".yml", ".yaml", ".sh", ".bash",
    ".tf", ".tfvars", ".rb", ".py", ".gradle", ".kts",
}
# Generated Dart is rewritten by codegen — sweep its source, not the output.
GENERATED_RE = re.compile(r"\.(?:g|freezed|gr|mocks|config)\.dart$")


def in_scope(rel: Path) -> bool:
    name = rel.name
    if GENERATED_RE.search(name):
        return False
    if name == "Dockerfile" or name.endswith(".Dockerfile"):
        return True
    return rel.suffix in CODE_EXT

# Legacy URS ids: REQ-p/o/d NNNNN and GUI-p NNNNN, each optionally CAL-namespaced.
LEGACY_RE = re.compile(r"\b(?:REQ|GUI)-(?:CAL-)?[pod]\d{5}\b")
HEADER_RE = re.compile(r"IMPLEMENTS REQUIREMENTS")

# New ids by repo convention.
NEW_RE = re.compile(r"\b(?:DIARY|CAL|HHT|EVS)-(?:PRD|GUI|BASE|OPS|DEV)-[a-z0-9][a-z0-9-]*\b")

# Map the legacy id's level/repo from its shape.
def classify(legacy_id: str) -> tuple[str, str]:
    repo = "hht_diary_callisto" if "-CAL-" in legacy_id else "hht_diary"
    if legacy_id.startswith("GUI"):
        level = "GUI"
    else:
        tag = legacy_id.split("-")[-1][0]  # p|o|d
        level = {"p": "PRD", "o": "OPS", "d": "DEV"}[tag]
    return level, repo


def is_excluded(rel: Path) -> bool:
    parts = rel.parts
    for i in range(len(parts)):
        prefix = "/".join(parts[: i + 1])
        if parts[i] in EXCLUDE_DIRS or prefix in EXCLUDE_DIRS:
            return True
    return False


def iter_text_files():
    for path in REPO.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(REPO)
        if is_excluded(rel) or not in_scope(rel):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        yield rel, text


def load_mapping() -> dict[str, dict]:
    """Parse the URS-v1 migration mapping table for old->new resolutions."""
    mapping_path = REPO / "docs" / "archive" / "urs-migration-mapping.md"
    resolved: dict[str, dict] = {}
    if not mapping_path.exists():
        return resolved
    for line in mapping_path.read_text(encoding="utf-8").splitlines():
        if "|" not in line:
            continue
        olds = LEGACY_RE.findall(line)
        news = NEW_RE.findall(line)
        if not olds or not news:
            continue
        # A mapping row resolves its first legacy id to its first new id; the
        # remaining new ids on the line are usually Refines: hints in Notes.
        old = olds[0]
        if old not in resolved:
            resolved[old] = {"target": news[0], "refines_hint": news[1:]}
    return resolved


def load_live_reqs() -> set[str]:
    """Collect current DIARY-* req ids declared as `## DIARY-...:` headings."""
    live: set[str] = set()
    head = re.compile(r"^#{1,3}\s+(DIARY-(?:PRD|GUI|BASE|OPS|DEV)-[a-z0-9-]+)\s*:")
    for md in (REPO / "spec").glob("*.md"):
        for line in md.read_text(encoding="utf-8").splitlines():
            m = head.match(line)
            if m:
                live.add(m.group(1))
    return live


def load_prior_dispositions() -> dict[str, dict]:
    """Carry forward human-entered fields so a rerun never loses Phase-1 work."""
    out_path = REPO / "tools" / "requirements" / "inventory.json"
    prior: dict[str, dict] = {}
    if not out_path.exists():
        return prior
    try:
        data = json.loads(out_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return prior
    for legacy, entry in data.get("ids", {}).items():
        prior[legacy] = {k: entry.get(k) for k in ("disposition", "notes", "deferred")}
        # A manually-set target (not from the mapping doc) is also human work.
        if entry.get("source") == "manual":
            prior[legacy]["target"] = entry.get("target")
            prior[legacy]["source"] = "manual"
    return prior


def main() -> int:
    mapping = load_mapping()
    live = load_live_reqs()
    prior = load_prior_dispositions()

    ids: dict[str, dict] = {}
    header_files: list[str] = []

    for rel, text in iter_text_files():
        relstr = str(rel)
        if HEADER_RE.search(text):
            header_files.append(relstr)
        seen_in_file: set[str] = set()
        for m in LEGACY_RE.finditer(text):
            seen_in_file.add(m.group(0))
        for legacy in seen_in_file:
            entry = ids.setdefault(legacy, {
                "level": None, "repo": None, "ref_files": 0, "files": [],
                "status": "unresolved", "target": None, "target_live": None,
                "disposition": None, "source": "none", "notes": "",
            })
            entry["files"].append(relstr)

    for legacy, entry in ids.items():
        level, repo = classify(legacy)
        entry["level"] = level
        entry["repo"] = repo
        entry["files"].sort()
        entry["ref_files"] = len(entry["files"])
        if legacy in mapping:
            entry["target"] = mapping[legacy]["target"]
            entry["source"] = "mapping"
            entry["status"] = "resolved"
            entry["target_live"] = mapping[legacy]["target"] in live
        # Restore human-entered fields from a prior run (the mapping doc only
        # covers ~15 ids; the rest are dispositioned by hand during Phase 1).
        if legacy in prior:
            for k, v in prior[legacy].items():
                if v not in (None, ""):
                    entry[k] = v
            if entry.get("source") == "manual" and entry.get("target"):
                entry["status"] = "resolved"
                entry["target_live"] = entry["target"] in live

    by_level: dict[str, int] = {}
    by_status: dict[str, int] = {}
    for entry in ids.values():
        by_level[entry["level"]] = by_level.get(entry["level"], 0) + 1
        by_status[entry["status"]] = by_status.get(entry["status"], 0) + 1

    out = {
        "_about": (
            "CUR-1451 legacy-annotation sweep work-list. Each key is a legacy URS "
            "id cited in code/CI. status=resolved means the URS-v1 mapping gives a "
            "target; disposition is filled by the Phase-1 passes "
            "(port|rewrite|parent-cite|drop|cross-repo). Regenerate with "
            "tools/requirements/build_inventory.py; hand-edits to disposition/"
            "notes/target are preserved-by-rerun ONLY if you merge — rerun "
            "overwrites, so make dispositions in a separate sidecar once Phase 1 starts."
        ),
        "summary": {
            "unique_legacy_ids": len(ids),
            "header_block_files": len(header_files),
            "by_level": by_level,
            "by_status": by_status,
            "live_req_count": len(live),
        },
        "header_block_files": sorted(header_files),
        "ids": dict(sorted(ids.items())),
    }

    out_path = REPO / "tools" / "requirements" / "inventory.json"
    out_path.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {out_path.relative_to(REPO)}")
    print(json.dumps(out["summary"], indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
