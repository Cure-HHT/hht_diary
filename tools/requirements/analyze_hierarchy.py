#!/usr/bin/env python3
"""
Analyze PRD requirements hierarchy and propose restructuring.

This script:
1. Parses all PRD requirements from spec/
2. Identifies orphaned requirements (missing or incorrect implements field)
3. Proposes parent assignment based on content analysis
4. Generates a report of proposed changes

IMPLEMENTS REQUIREMENTS:
    REQ-p00020: System Validation and Traceability
"""

import re
import csv
import json
from pathlib import Path
from dataclasses import dataclass
from typing import Dict, List, Optional, Set, Tuple
from collections import defaultdict

# The hierarchy structure we want to enforce
HIERARCHY_STRUCTURE = {
    # Level 1: Top-level (implements nothing)
    "p00044": {"level": 1, "title": "Clinical Trial Diary Platform", "implements": None},
    "p01041": {"level": 1, "title": "Open Source Licensing", "implements": None},

    # Level 2: Major System Components (implement p00044)
    "p00043": {"level": 2, "title": "Clinical Diary Mobile Application", "implements": ["p00044"]},
    "p00045": {"level": 2, "title": "Sponsor Portal Application", "implements": ["p00044"]},
    "p00046": {"level": 2, "title": "Clinical Data Storage System", "implements": ["p00044"]},
    "p00047": {"level": 2, "title": "Data Backup and Archival", "implements": ["p00044"]},
    "p00048": {"level": 2, "title": "Platform Operations and Monitoring", "implements": ["p00044"]},
    "p00049": {"level": 2, "title": "Ancillary Platform Services", "implements": ["p00044"]},
    "p01042": {"level": 2, "title": "Web Diary Application", "implements": ["p00044"]},

    # Level 2: Cross-cutting Concerns (implement p00044)
    "p00001": {"level": 2, "title": "Complete Multi-Sponsor Data Separation", "implements": ["p00044"]},
    "p00010": {"level": 2, "title": "FDA 21 CFR Part 11 Compliance", "implements": ["p00044"]},
    "p00041": {"level": 2, "title": "CDISC Standards Compliance", "implements": ["p00044"]},
    "p00021": {"level": 2, "title": "Architecture Decision Documentation", "implements": ["p00044"]},
}

# Domain categories for classification
DOMAIN_CATEGORIES = {
    "mobile_app": {
        "parent": "p00043",
        "keywords": ["mobile", "diary app", "offline", "calendar", "questionnaire", "epistaxis", "entry"],
        "file_patterns": ["prd-diary-app", "prd-epistaxis"]
    },
    "web_diary": {
        "parent": "p01042",
        "keywords": ["web diary", "linking code", "browser", "web session"],
        "file_patterns": ["prd-diary-web"]
    },
    "portal": {
        "parent": "p00045",
        "keywords": ["portal", "investigator", "admin", "dashboard", "enrollment", "monitoring"],
        "file_patterns": ["prd-portal"]
    },
    "database": {
        "parent": "p00046",
        "keywords": ["database", "event sourcing", "storage", "schema", "audit trail", "event store", "materialized view"],
        "file_patterns": ["prd-database", "prd-event-sourcing"]
    },
    "multi_sponsor": {
        "parent": "p00001",
        "keywords": ["sponsor", "multi-sponsor", "tenant", "isolation", "separation"],
        "file_patterns": ["prd-architecture-multi-sponsor"]
    },
    "compliance": {
        "parent": "p00010",
        "keywords": ["fda", "21 cfr", "alcoa", "compliance", "retention", "validation", "regulatory"],
        "file_patterns": ["prd-clinical-trials", "prd-evidence"]
    },
    "security": {
        "parent": "p00010",  # Security flows up to compliance
        "keywords": ["security", "rbac", "rls", "access control", "authentication", "encryption", "mfa"],
        "file_patterns": ["prd-security"]
    },
    "operations": {
        "parent": "p00048",
        "keywords": ["operations", "sla", "monitoring", "incident", "availability", "disaster recovery"],
        "file_patterns": ["prd-sla", "prd-devops"]
    },
    "backup": {
        "parent": "p00047",
        "keywords": ["backup", "archival", "retention", "recovery"],
        "file_patterns": ["prd-backup"]
    },
    "services": {
        "parent": "p00049",
        "keywords": ["notification", "email", "push", "service"],
        "file_patterns": ["prd-services"]
    }
}


@dataclass
class Requirement:
    id: str
    title: str
    implements: List[str]
    file_path: str
    line_number: int
    body: str

    @property
    def number(self) -> str:
        return self.id.replace("p", "")

    @property
    def is_orphaned(self) -> bool:
        """Requirement is orphaned if it has no implements or implements -"""
        return not self.implements or self.implements == ["-"]


def parse_requirements(spec_dir: Path) -> Dict[str, Requirement]:
    """Parse all PRD requirements from spec directory."""
    requirements = {}

    for md_file in spec_dir.glob("*.md"):
        if not md_file.name.startswith("prd-"):
            continue

        content = md_file.read_text()

        # Find all requirements in the file
        # Pattern: # REQ-p{id}: {title}
        pattern = r'^# REQ-(p\d{5}):\s*(.+?)$'

        for match in re.finditer(pattern, content, re.MULTILINE):
            req_id = match.group(1)
            title = match.group(2).strip()
            line_number = content[:match.start()].count('\n') + 1

            # Find the implements field
            impl_pattern = r'\*\*Implements\*\*:\s*([^\n|]+)'
            pos = match.end()
            next_req = content.find("# REQ-", pos)
            if next_req == -1:
                next_req = len(content)

            body_section = content[pos:next_req]
            impl_match = re.search(impl_pattern, body_section)

            implements = []
            if impl_match:
                impl_text = impl_match.group(1).strip()
                if impl_text and impl_text != "-":
                    # Parse comma-separated or space-separated IDs
                    impl_ids = re.findall(r'p\d{5}', impl_text)
                    implements = impl_ids

            requirements[req_id] = Requirement(
                id=req_id,
                title=title,
                implements=implements,
                file_path=str(md_file.name),
                line_number=line_number,
                body=body_section[:500]  # First 500 chars for analysis
            )

    # Also check roadmap directory
    roadmap_dir = spec_dir / "roadmap"
    if roadmap_dir.exists():
        for md_file in roadmap_dir.glob("*.md"):
            content = md_file.read_text()
            pattern = r'^# REQ-(p\d{5}):\s*(.+?)$'

            for match in re.finditer(pattern, content, re.MULTILINE):
                req_id = match.group(1)
                if req_id not in requirements:
                    title = match.group(2).strip()
                    line_number = content[:match.start()].count('\n') + 1

                    # Find implements
                    impl_pattern = r'\*\*Implements\*\*:\s*([^\n|]+)'
                    pos = match.end()
                    next_req = content.find("# REQ-", pos)
                    if next_req == -1:
                        next_req = len(content)

                    body_section = content[pos:next_req]
                    impl_match = re.search(impl_pattern, body_section)

                    implements = []
                    if impl_match:
                        impl_text = impl_match.group(1).strip()
                        if impl_text and impl_text != "-":
                            impl_ids = re.findall(r'p\d{5}', impl_text)
                            implements = impl_ids

                    requirements[req_id] = Requirement(
                        id=req_id,
                        title=title,
                        implements=implements,
                        file_path=f"roadmap/{md_file.name}",
                        line_number=line_number,
                        body=body_section[:500]
                    )

    return requirements


def classify_requirement(req: Requirement) -> Tuple[str, str, float]:
    """Classify a requirement into a domain category.

    Returns: (category_name, suggested_parent, confidence)
    """
    scores = defaultdict(float)

    # Check file patterns first (high confidence)
    for cat, info in DOMAIN_CATEGORIES.items():
        for pattern in info["file_patterns"]:
            if pattern in req.file_path.lower():
                scores[cat] += 5.0

    # Check keywords in title and body
    text = (req.title + " " + req.body).lower()
    for cat, info in DOMAIN_CATEGORIES.items():
        for keyword in info["keywords"]:
            if keyword.lower() in text:
                scores[cat] += 1.0

    if not scores:
        return ("unknown", "p00044", 0.0)  # Default to platform level

    best_cat = max(scores, key=scores.get)
    return (best_cat, DOMAIN_CATEGORIES[best_cat]["parent"], scores[best_cat])


def analyze_hierarchy(requirements: Dict[str, Requirement]) -> List[Dict]:
    """Analyze requirements and propose hierarchy changes."""
    proposals = []

    for req_id, req in sorted(requirements.items()):
        # Skip non-orphaned requirements for now (unless they have wrong parent)
        if req_id in HIERARCHY_STRUCTURE:
            expected = HIERARCHY_STRUCTURE[req_id]
            if expected["implements"] is None and req.implements:
                proposals.append({
                    "req_id": req_id,
                    "title": req.title,
                    "file": req.file_path,
                    "line": req.line_number,
                    "current_implements": req.implements,
                    "proposed_implements": None,
                    "reason": "Should be top-level (Level 1)",
                    "confidence": "HIGH",
                    "action": "REMOVE_IMPLEMENTS"
                })
            elif expected["implements"] and req.implements != expected["implements"]:
                proposals.append({
                    "req_id": req_id,
                    "title": req.title,
                    "file": req.file_path,
                    "line": req.line_number,
                    "current_implements": req.implements,
                    "proposed_implements": expected["implements"],
                    "reason": f"Level 2 component should implement {expected['implements']}",
                    "confidence": "HIGH",
                    "action": "UPDATE_IMPLEMENTS"
                })
        elif req.is_orphaned:
            # Classify and propose parent
            category, parent, confidence = classify_requirement(req)
            conf_level = "HIGH" if confidence > 3 else "MEDIUM" if confidence > 1 else "LOW"

            proposals.append({
                "req_id": req_id,
                "title": req.title,
                "file": req.file_path,
                "line": req.line_number,
                "current_implements": req.implements if req.implements else None,
                "proposed_implements": [parent],
                "reason": f"Classified as {category} domain",
                "confidence": conf_level,
                "action": "ADD_IMPLEMENTS"
            })

    return proposals


def generate_report(requirements: Dict[str, Requirement], proposals: List[Dict]) -> str:
    """Generate a markdown report of the analysis."""
    lines = [
        "# PRD Requirements Hierarchy Analysis Report",
        "",
        f"**Total PRD Requirements**: {len(requirements)}",
        f"**Proposed Changes**: {len(proposals)}",
        "",
        "## Summary by Action",
        ""
    ]

    by_action = defaultdict(list)
    for p in proposals:
        by_action[p["action"]].append(p)

    for action, items in by_action.items():
        lines.append(f"- **{action}**: {len(items)} requirements")

    lines.extend([
        "",
        "## Proposed Hierarchy Changes",
        "",
        "| REQ ID | Title | Current | Proposed | Confidence | Reason |",
        "|--------|-------|---------|----------|------------|--------|"
    ])

    for p in proposals:
        current = ", ".join(p["current_implements"]) if p["current_implements"] else "-"
        proposed = ", ".join(p["proposed_implements"]) if p["proposed_implements"] else "-"
        lines.append(f"| {p['req_id']} | {p['title'][:40]}... | {current} | {proposed} | {p['confidence']} | {p['reason']} |")

    lines.extend([
        "",
        "## Orphaned Requirements by Domain",
        ""
    ])

    by_domain = defaultdict(list)
    for p in proposals:
        if p["action"] == "ADD_IMPLEMENTS":
            reason = p["reason"]
            domain = reason.replace("Classified as ", "").replace(" domain", "")
            by_domain[domain].append(p)

    for domain, items in sorted(by_domain.items()):
        lines.append(f"### {domain.replace('_', ' ').title()}")
        for p in items:
            lines.append(f"- {p['req_id']}: {p['title']}")
        lines.append("")

    return "\n".join(lines)


def generate_edit_commands(proposals: List[Dict], spec_dir: Path) -> List[Dict]:
    """Generate edit commands for updating requirements."""
    edits = []

    for p in proposals:
        file_path = spec_dir / p["file"]

        # Read the file to find the exact line to edit
        if not file_path.exists():
            continue

        content = file_path.read_text()
        lines = content.split("\n")

        # Find the implements line near the requirement
        req_line = p["line"] - 1  # 0-indexed

        # Search within next 5 lines for **Implements**
        for i in range(req_line, min(req_line + 6, len(lines))):
            if "**Implements**" in lines[i]:
                old_line = lines[i]

                if p["proposed_implements"] is None:
                    new_impl = "-"
                else:
                    new_impl = ", ".join(p["proposed_implements"])

                # Replace the implements value
                new_line = re.sub(
                    r'(\*\*Implements\*\*:\s*)[^\n|]+',
                    f'\\1{new_impl}',
                    old_line
                )

                edits.append({
                    "file": str(file_path),
                    "line": i + 1,
                    "old": old_line,
                    "new": new_line,
                    "req_id": p["req_id"]
                })
                break

    return edits


def main():
    import sys

    spec_dir = Path(__file__).parent.parent.parent / "spec"

    print(f"Parsing requirements from {spec_dir}...")
    requirements = parse_requirements(spec_dir)
    print(f"Found {len(requirements)} PRD requirements")

    print("\nAnalyzing hierarchy...")
    proposals = analyze_hierarchy(requirements)
    print(f"Generated {len(proposals)} proposed changes")

    # Generate report
    report = generate_report(requirements, proposals)

    # Output to stdout or file
    if len(sys.argv) > 1:
        if sys.argv[1] == "--report":
            print(report)
        elif sys.argv[1] == "--json":
            print(json.dumps(proposals, indent=2))
        elif sys.argv[1] == "--edits":
            edits = generate_edit_commands(proposals, spec_dir)
            print(json.dumps(edits, indent=2))
    else:
        print("\nUsage:")
        print("  --report   Generate markdown report")
        print("  --json     Output proposals as JSON")
        print("  --edits    Generate edit commands as JSON")


if __name__ == "__main__":
    main()
