#!/usr/bin/env python3
"""
Analyze PRD requirements hierarchy and propose restructuring.

This script:
1. Parses all requirements via elspais CLI (elspais validate --json)
2. Identifies orphaned requirements (missing or incorrect implements field)
3. Proposes parent assignment based on content analysis
4. Generates proposals compatible with elspais edit --from-json

IMPLEMENTS REQUIREMENTS:
    REQ-p00020: System Validation and Traceability
"""

import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple


# The hierarchy structure we want to enforce
HIERARCHY_STRUCTURE = {
    # Level 1: Top-level (implements nothing)
    "p00044": {"level": 1, "title": "Clinical Trial Diary Platform", "implements": None},
    "p01041": {"level": 1, "title": "Open Source Licensing", "implements": None},

    # Level 2: Major System Components (implement p00044)
    "p00043": {"level": 2, "title": "Diary Mobile Application", "implements": ["p00044"]},
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


def get_requirements_via_cli() -> Dict[str, Dict]:
    """
    Get all requirements by running elspais validate --json.

    Returns:
        Dict mapping requirement ID (e.g., 'REQ-d00027') to requirement data
    """
    try:
        result = subprocess.run(
            ['elspais', 'validate', '--json'],
            capture_output=True,
            text=True
        )

        output = result.stdout
        json_start = output.find('{')
        if json_start == -1:
            return {}

        json_str = output[json_start:]
        return json.loads(json_str)
    except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Error: Failed to get requirements via elspais: {e}", file=sys.stderr)
        sys.exit(1)


def normalize_req_id(req_id: str) -> str:
    """Normalize requirement ID (remove REQ- prefix if present)."""
    if req_id.upper().startswith('REQ-'):
        return req_id[4:].lower()
    return req_id.lower()


def is_orphaned(req: Dict) -> bool:
    """Check if a requirement is orphaned (no implements or implements nothing)."""
    implements = req.get('implements', [])
    if not implements:
        return True
    # Check for placeholder values
    if len(implements) == 1 and implements[0] in ('-', 'null', 'none', 'N/A'):
        return True
    return False


def classify_requirement(req_id: str, req: Dict) -> Tuple[str, str, float]:
    """Classify a requirement into a domain category.

    Returns: (category_name, suggested_parent, confidence)
    """
    scores = defaultdict(float)

    file_path = req.get('file', '').lower()
    title = req.get('title', '')
    body = req.get('body', '')[:500]  # First 500 chars for analysis

    # Check file patterns first (high confidence)
    for cat, info in DOMAIN_CATEGORIES.items():
        for pattern in info["file_patterns"]:
            if pattern in file_path:
                scores[cat] += 5.0

    # Check keywords in title and body
    text = (title + " " + body).lower()
    for cat, info in DOMAIN_CATEGORIES.items():
        for keyword in info["keywords"]:
            if keyword.lower() in text:
                scores[cat] += 1.0

    if not scores:
        return ("unknown", "p00044", 0.0)  # Default to platform level

    best_cat = max(scores, key=scores.get)
    return (best_cat, DOMAIN_CATEGORIES[best_cat]["parent"], scores[best_cat])


def analyze_hierarchy(requirements: Dict[str, Dict]) -> List[Dict]:
    """Analyze requirements and propose hierarchy changes."""
    proposals = []

    for full_req_id, req in sorted(requirements.items()):
        # Only analyze PRD requirements
        req_id = normalize_req_id(full_req_id)
        if not req_id.startswith('p'):
            continue

        current_implements = req.get('implements', [])

        # Check against known hierarchy structure
        if req_id in HIERARCHY_STRUCTURE:
            expected = HIERARCHY_STRUCTURE[req_id]
            if expected["implements"] is None and current_implements:
                proposals.append({
                    "req_id": full_req_id,
                    "title": req.get('title', ''),
                    "file": req.get('file', ''),
                    "line": req.get('line', 0),
                    "current_implements": current_implements,
                    "proposed_implements": "",  # Empty string clears implements
                    "reason": "Should be top-level (Level 1)",
                    "confidence": "HIGH",
                    "action": "REMOVE_IMPLEMENTS"
                })
            elif expected["implements"] and current_implements != expected["implements"]:
                proposals.append({
                    "req_id": full_req_id,
                    "title": req.get('title', ''),
                    "file": req.get('file', ''),
                    "line": req.get('line', 0),
                    "current_implements": current_implements,
                    "proposed_implements": ",".join(expected["implements"]),
                    "reason": f"Level 2 component should implement {expected['implements']}",
                    "confidence": "HIGH",
                    "action": "UPDATE_IMPLEMENTS"
                })
        elif is_orphaned(req):
            # Classify and propose parent
            category, parent, confidence = classify_requirement(req_id, req)
            conf_level = "HIGH" if confidence > 3 else "MEDIUM" if confidence > 1 else "LOW"

            proposals.append({
                "req_id": full_req_id,
                "title": req.get('title', ''),
                "file": req.get('file', ''),
                "line": req.get('line', 0),
                "current_implements": current_implements if current_implements else None,
                "proposed_implements": parent,
                "reason": f"Classified as {category} domain",
                "confidence": conf_level,
                "action": "ADD_IMPLEMENTS"
            })

    return proposals


def generate_report(requirements: Dict[str, Dict], proposals: List[Dict]) -> str:
    """Generate a markdown report of the analysis."""
    # Count PRD requirements
    prd_count = sum(1 for rid in requirements if normalize_req_id(rid).startswith('p'))

    lines = [
        "# PRD Requirements Hierarchy Analysis Report",
        "",
        f"**Total PRD Requirements**: {prd_count}",
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
        proposed = p["proposed_implements"] if p["proposed_implements"] else "-"
        title = p["title"][:40] + "..." if len(p["title"]) > 40 else p["title"]
        lines.append(f"| {p['req_id']} | {title} | {current} | {proposed} | {p['confidence']} | {p['reason']} |")

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


def generate_elspais_edits(proposals: List[Dict]) -> List[Dict]:
    """Generate edit commands compatible with elspais edit --from-json."""
    edits = []

    for p in proposals:
        edit = {
            "req_id": p["req_id"],
            "implements": p["proposed_implements"]
        }
        edits.append(edit)

    return edits


def main():
    print("Fetching requirements via elspais...", file=sys.stderr)
    requirements = get_requirements_via_cli()
    prd_count = sum(1 for rid in requirements if normalize_req_id(rid).startswith('p'))
    print(f"Found {prd_count} PRD requirements", file=sys.stderr)

    print("\nAnalyzing hierarchy...", file=sys.stderr)
    proposals = analyze_hierarchy(requirements)
    print(f"Generated {len(proposals)} proposed changes", file=sys.stderr)

    # Output based on arguments
    if len(sys.argv) > 1:
        if sys.argv[1] == "--report":
            print(generate_report(requirements, proposals))
        elif sys.argv[1] == "--json":
            print(json.dumps(proposals, indent=2))
        elif sys.argv[1] == "--elspais":
            # Output format for: elspais edit --from-json
            edits = generate_elspais_edits(proposals)
            print(json.dumps(edits, indent=2))
        elif sys.argv[1] == "--apply":
            # Apply changes via elspais edit
            edits = generate_elspais_edits(proposals)
            if not edits:
                print("No changes to apply")
                return

            # Write to temp file and apply
            import tempfile
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
                json.dump(edits, f)
                temp_path = f.name

            print(f"Applying {len(edits)} changes via elspais edit...")
            result = subprocess.run(
                ['elspais', 'edit', '--from-json', temp_path],
                capture_output=False
            )
            Path(temp_path).unlink()
            sys.exit(result.returncode)
        elif sys.argv[1] == "--dry-run":
            # Dry run via elspais edit
            edits = generate_elspais_edits(proposals)
            if not edits:
                print("No changes to apply")
                return

            import tempfile
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
                json.dump(edits, f)
                temp_path = f.name

            print(f"Dry run: {len(edits)} changes")
            result = subprocess.run(
                ['elspais', 'edit', '--from-json', temp_path, '--dry-run'],
                capture_output=False
            )
            Path(temp_path).unlink()
            sys.exit(result.returncode)
        else:
            print(f"Unknown option: {sys.argv[1]}", file=sys.stderr)
            print_usage()
    else:
        print_usage()


def print_usage():
    print("\nUsage:")
    print("  --report    Generate markdown report")
    print("  --json      Output proposals as JSON (internal format)")
    print("  --elspais   Output proposals for elspais edit --from-json")
    print("  --apply     Apply changes via elspais edit")
    print("  --dry-run   Preview changes without applying")


if __name__ == "__main__":
    main()
