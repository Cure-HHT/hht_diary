"""
Coverage calculation for trace-view

Provides functions to calculate implementation coverage and status
for requirements.
"""

from typing import Dict, List

from .models import Requirement


def count_by_level(requirements: Dict[str, Requirement]) -> Dict[str, Dict[str, int]]:
    """Count requirements by level, both including and excluding Deprecated.

    Args:
        requirements: Dict mapping requirement ID to Requirement

    Returns:
        Dict with 'active' (excludes Deprecated) and 'all' (includes Deprecated) counts
        Each contains counts for 'PRD', 'OPS', 'DEV'
    """
    counts = {
        'active': {'PRD': 0, 'OPS': 0, 'DEV': 0},
        'all': {'PRD': 0, 'OPS': 0, 'DEV': 0}
    }
    for req in requirements.values():
        counts['all'][req.level] = counts['all'].get(req.level, 0) + 1
        if req.status != 'Deprecated':
            counts['active'][req.level] = counts['active'].get(req.level, 0) + 1
    return counts


def find_orphaned_requirements(requirements: Dict[str, Requirement]) -> List[Requirement]:
    """Find requirements not linked from any parent.

    Args:
        requirements: Dict mapping requirement ID to Requirement

    Returns:
        List of orphaned requirements (non-PRD requirements with no implements)
    """
    implemented = set()
    for req in requirements.values():
        implemented.update(req.implements)

    orphaned = []
    for req in requirements.values():
        # Skip PRD requirements (they're top-level)
        if req.level == 'PRD':
            continue
        # Skip if this requirement is implemented by someone
        if req.id in implemented:
            continue
        # Skip if it has no parent (should have one)
        if not req.implements:
            orphaned.append(req)

    return sorted(orphaned, key=lambda r: r.id)


def calculate_coverage(requirements: Dict[str, Requirement], req_id: str) -> dict:
    """Calculate coverage for a requirement.

    Args:
        requirements: Dict mapping requirement ID to Requirement
        req_id: ID of requirement to calculate coverage for

    Returns:
        Dict with 'children' (total child count) and 'traced' (children with implementation)
    """
    # Find all requirements that implement this requirement (children)
    children = [
        r for r in requirements.values()
        if req_id in r.implements
    ]

    # Count how many children have implementation files or their own children with implementation
    traced = 0
    for child in children:
        child_status = get_implementation_status(requirements, child.id)
        if child_status in ['Full', 'Partial']:
            traced += 1

    return {
        'children': len(children),
        'traced': traced
    }


def get_implementation_status(requirements: Dict[str, Requirement], req_id: str) -> str:
    """Get implementation status for a requirement.

    Args:
        requirements: Dict mapping requirement ID to Requirement
        req_id: ID of requirement to check

    Returns:
        'Unimplemented': No children AND no implementation_files
        'Partial': Some but not all children traced
        'Full': Has implementation_files OR all children traced
    """
    req = requirements.get(req_id)
    if not req:
        return 'Unimplemented'

    # If requirement has implementation files, it's fully implemented
    if req.implementation_files:
        return 'Full'

    # Find children
    children = [
        r for r in requirements.values()
        if req_id in r.implements
    ]

    # No children and no implementation files = Unimplemented
    if not children:
        return 'Unimplemented'

    # Check how many children are traced
    coverage = calculate_coverage(requirements, req_id)

    if coverage['traced'] == 0:
        return 'Unimplemented'
    elif coverage['traced'] == coverage['children']:
        return 'Full'
    else:
        return 'Partial'


def generate_coverage_report(
    requirements: Dict[str, Requirement],
    get_status_fn=None
) -> str:
    """Generate text-based coverage report with summary statistics.

    Args:
        requirements: Dict mapping requirement ID to Requirement
        get_status_fn: Optional function to get implementation status.
                       If None, uses get_implementation_status.

    Returns:
        Formatted text report showing:
        - Total requirements count
        - Breakdown by level (PRD, OPS, DEV) with percentages
        - Breakdown by implementation status (Full/Partial/Unimplemented)
    """
    if get_status_fn is None:
        get_status_fn = lambda req_id: get_implementation_status(requirements, req_id)

    lines = []
    lines.append("=== Coverage Report ===")
    lines.append(f"Total Requirements: {len(requirements)}")
    lines.append("")

    # Count by level
    by_level = {'PRD': 0, 'OPS': 0, 'DEV': 0}
    implemented_by_level = {'PRD': 0, 'OPS': 0, 'DEV': 0}

    for req in requirements.values():
        level = req.level
        by_level[level] = by_level.get(level, 0) + 1

        impl_status = get_status_fn(req.id)
        if impl_status in ['Full', 'Partial']:
            implemented_by_level[level] = implemented_by_level.get(level, 0) + 1

    lines.append("By Level:")
    for level in ['PRD', 'OPS', 'DEV']:
        total = by_level[level]
        implemented = implemented_by_level[level]
        percentage = (implemented / total * 100) if total > 0 else 0
        lines.append(f"  {level}: {total} ({percentage:.0f}% implemented)")

    lines.append("")

    # Count by implementation status
    status_counts = {'Full': 0, 'Partial': 0, 'Unimplemented': 0}
    for req in requirements.values():
        impl_status = get_status_fn(req.id)
        status_counts[impl_status] = status_counts.get(impl_status, 0) + 1

    lines.append("By Status:")
    lines.append(f"  Full: {status_counts['Full']}")
    lines.append(f"  Partial: {status_counts['Partial']}")
    lines.append(f"  Unimplemented: {status_counts['Unimplemented']}")

    return '\n'.join(lines)
