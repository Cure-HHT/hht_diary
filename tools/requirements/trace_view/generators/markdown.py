"""
Markdown generation for trace-view

Provides functions to generate markdown traceability matrices.
"""

import sys
from datetime import datetime
from typing import Dict, List, Optional

from ..models import Requirement
from ..coverage import count_by_level, find_orphaned_requirements


def generate_legend_markdown() -> str:
    """Generate markdown legend section.

    Returns:
        Markdown string with legend explaining symbols
    """
    return """## Legend

**Requirement Status:**
- ✅ Active requirement
- 🚧 Draft requirement
- ⚠️ Deprecated requirement

**Traceability:**
- 🔗 Has implementation file(s)
- ○ No implementation found

**Interactive (HTML only):**
- ▼ Expandable (has child requirements)
- ▶ Collapsed (click to expand)
"""


def generate_markdown(
    requirements: Dict[str, Requirement],
    base_path: str = ''
) -> str:
    """Generate markdown traceability matrix.

    Args:
        requirements: Dict mapping requirement ID to Requirement
        base_path: Base path for links (e.g., '../' for files in subdirectory)

    Returns:
        Complete markdown traceability matrix
    """
    lines = []
    lines.append("# Requirements Traceability Matrix")
    lines.append(f"\n**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"**Total Requirements**: {len(requirements)}\n")

    # Summary by level (using active counts, excluding deprecated)
    by_level = count_by_level(requirements)
    lines.append("## Summary\n")
    lines.append(f"- **PRD Requirements**: {by_level['active']['PRD']}")
    lines.append(f"- **OPS Requirements**: {by_level['active']['OPS']}")
    lines.append(f"- **DEV Requirements**: {by_level['active']['DEV']}\n")

    # Add legend
    lines.append(generate_legend_markdown())

    # Full traceability tree
    lines.append("## Traceability Tree\n")

    # Start with top-level PRD requirements
    prd_reqs = [req for req in requirements.values() if req.level == 'PRD']
    prd_reqs.sort(key=lambda r: r.id)

    for prd_req in prd_reqs:
        lines.append(format_req_tree_md(
            prd_req, requirements, indent=0, ancestor_path=[], base_path=base_path
        ))

    # Orphaned ops/dev requirements
    orphaned = find_orphaned_requirements(requirements)
    if orphaned:
        lines.append("\n## Orphaned Requirements\n")
        lines.append("*(Requirements not linked from any parent)*\n")
        for req in orphaned:
            lines.append(f"- **REQ-{req.id}**: {req.title} ({req.level}) - {req.file_path.name}")

    return '\n'.join(lines)


def format_req_tree_md(
    req: Requirement,
    requirements: Dict[str, Requirement],
    indent: int,
    ancestor_path: Optional[List[str]] = None,
    base_path: str = ''
) -> str:
    """Format requirement and its children as markdown tree.

    Args:
        req: The requirement to format
        requirements: Dict mapping requirement ID to Requirement
        indent: Current indentation level
        ancestor_path: List of requirement IDs in the current traversal path (for cycle detection)
        base_path: Base path for links

    Returns:
        Formatted markdown string
    """
    if ancestor_path is None:
        ancestor_path = []

    # Cycle detection: check if this requirement is already in our traversal path
    if req.id in ancestor_path:
        cycle_path = ancestor_path + [req.id]
        cycle_str = " -> ".join([f"REQ-{rid}" for rid in cycle_path])
        print(f"⚠️  CYCLE DETECTED: {cycle_str}", file=sys.stderr)
        return "  " * indent + f"- ⚠️ **CYCLE DETECTED**: REQ-{req.id} (path: {cycle_str})"

    # Safety depth limit
    MAX_DEPTH = 50
    if indent > MAX_DEPTH:
        print(f"⚠️  MAX DEPTH ({MAX_DEPTH}) exceeded at REQ-{req.id}", file=sys.stderr)
        return "  " * indent + f"- ⚠️ **MAX DEPTH EXCEEDED**: REQ-{req.id}"

    lines = []
    prefix = "  " * indent

    # Format current requirement
    status_emoji = {
        'Active': '✅',
        'Draft': '🚧',
        'Deprecated': '⚠️'
    }
    emoji = status_emoji.get(req.status, '❓')

    # Create link to source file with REQ anchor
    req_link = f"[REQ-{req.id}]({base_path}spec/{req.file_path.name}#REQ-{req.id})"

    lines.append(
        f"{prefix}- {emoji} **{req_link}**: {req.title}\n"
        f"{prefix}  - Level: {req.level} | Status: {req.status}\n"
        f"{prefix}  - File: {req.file_path.name}:{req.line_number}"
    )

    # Format implementation files as nested list with clickable links
    if req.implementation_files:
        lines.append(f"{prefix}  - **Implemented in**:")
        for file_path, line_num in req.implementation_files:
            # Create markdown link to file with line number anchor
            link = f"[{file_path}:{line_num}]({base_path}{file_path}#L{line_num})"
            lines.append(f"{prefix}    - {link}")

    # Find and format children
    children = [
        r for r in requirements.values()
        if req.id in r.implements
    ]
    children.sort(key=lambda r: r.id)

    if children:
        # Add current req to path before recursing into children
        current_path = ancestor_path + [req.id]
        for child in children:
            lines.append(format_req_tree_md(
                child, requirements, indent + 1, current_path, base_path
            ))

    return '\n'.join(lines)
