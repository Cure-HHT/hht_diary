"""
CSV generation for trace-view

Provides functions to generate CSV traceability matrices and planning exports.
"""

import csv
from io import StringIO
from typing import Dict, Callable, List

from ..models import Requirement


def generate_csv(requirements: Dict[str, Requirement]) -> str:
    """Generate CSV traceability matrix.

    Args:
        requirements: Dict mapping requirement ID to Requirement

    Returns:
        CSV string with columns: Requirement ID, Title, Level, Status,
        Implements, Traced By, File, Line, Implementation Files
    """
    output = StringIO()
    writer = csv.writer(output)

    # Header
    writer.writerow([
        'Requirement ID',
        'Title',
        'Level',
        'Status',
        'Implements',
        'Traced By',
        'File',
        'Line',
        'Implementation Files'
    ])

    # Sort requirements by ID
    sorted_reqs = sorted(requirements.values(), key=lambda r: r.id)

    for req in sorted_reqs:
        # Compute children (traced by) dynamically
        children = [
            r.id for r in requirements.values()
            if req.id in r.implements
        ]

        # Format implementation files as "file:line" strings
        impl_files_str = ', '.join(
            [f'{path}:{line}' for path, line in req.implementation_files]
        ) if req.implementation_files else '-'

        writer.writerow([
            req.id,
            req.title,
            req.level,
            req.status,
            ', '.join(req.implements) if req.implements else '-',
            ', '.join(sorted(children)) if children else '-',
            req.file_path.name,
            req.line_number,
            impl_files_str
        ])

    return output.getvalue()


def generate_planning_csv(
    requirements: Dict[str, Requirement],
    get_implementation_status: Callable[[str], str],
    calculate_coverage: Callable[[str], dict]
) -> str:
    """Generate CSV for sprint planning (actionable items only).

    Args:
        requirements: Dict mapping requirement ID to Requirement
        get_implementation_status: Function that takes req_id and returns status string
        calculate_coverage: Function that takes req_id and returns coverage dict

    Returns:
        CSV with columns: REQ ID, Title, Level, Status, Impl Status, Coverage, Code Refs
        Includes only actionable items (Active or Draft status, not deprecated)
    """
    output = StringIO()
    writer = csv.writer(output)

    # Header
    writer.writerow([
        'REQ ID',
        'Title',
        'Level',
        'Status',
        'Impl Status',
        'Coverage',
        'Code Refs'
    ])

    # Filter to actionable requirements (Active or Draft status)
    actionable_reqs = [
        req for req in requirements.values()
        if req.status in ['Active', 'Draft']
    ]

    # Sort by ID
    actionable_reqs.sort(key=lambda r: r.id)

    for req in actionable_reqs:
        impl_status = get_implementation_status(req.id)
        coverage = calculate_coverage(req.id)
        code_refs = len(req.implementation_files)

        writer.writerow([
            req.id,
            req.title,
            req.level,
            req.status,
            impl_status,
            f"{coverage['traced']}/{coverage['children']}",
            code_refs
        ])

    return output.getvalue()
