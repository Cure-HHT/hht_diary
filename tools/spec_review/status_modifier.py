#!/usr/bin/env python3
"""
Status Modifier Module - Modify REQ status in spec files

Provides functions to change the status field of requirements in spec/*.md files.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration (status change workflow)
"""

import re
from pathlib import Path
from typing import Dict, Any, Optional

# Valid statuses (must match requirement_parser.py)
VALID_STATUSES = {'Active', 'Draft', 'Deprecated', 'Review'}

# Regex pattern to match the status line in a requirement
# Matches: **Level**: Dev | **Implements**: - | **Status**: Draft
STATUS_LINE_PATTERN = re.compile(
    r'^(\*\*Level\*\*:\s+(?:PRD|Ops|Dev)\s+\|\s+'
    r'\*\*Implements\*\*:\s+[^\|]+?\s+\|\s+'
    r'\*\*Status\*\*:\s+)(Active|Draft|Deprecated|Review)(\s*)$',
    re.MULTILINE
)

# Pattern to find a REQ header
REQ_HEADER_PATTERN = re.compile(
    r'^#{1,6}\s+REQ-(?:([A-Z]{2,4})-)?([pod]\d{5}):\s+.+$',
    re.MULTILINE
)


def find_req_in_file(file_path: Path, req_id: str) -> Optional[Dict[str, Any]]:
    """
    Find a requirement in a spec file and return its position info.

    Args:
        file_path: Path to the spec file
        req_id: The requirement ID (without REQ- prefix), e.g., "d00001" or "CAL-d00001"

    Returns:
        Dictionary with req info if found, None otherwise:
        {
            "req_id": str,
            "current_status": str,
            "status_line_start": int,  # character position of status line start
            "status_line_end": int,    # character position of status line end
            "status_value_start": int, # character position of status value start
            "status_value_end": int,   # character position of status value end
        }
    """
    try:
        content = file_path.read_text(encoding='utf-8')
    except (FileNotFoundError, IOError):
        return None

    # Find the REQ header
    # Handle both "d00001" and "CAL-d00001" formats
    if '-' in req_id and not req_id.startswith(('p', 'o', 'd')):
        # Sponsor-prefixed ID like "CAL-d00001"
        parts = req_id.split('-', 1)
        sponsor_prefix = parts[0]
        base_id = parts[1]
        header_pattern = re.compile(
            rf'^#{{1,6}}\s+REQ-{sponsor_prefix}-{base_id}:\s+.+$',
            re.MULTILINE
        )
    else:
        # Core ID like "d00001"
        header_pattern = re.compile(
            rf'^#{{1,6}}\s+REQ-{req_id}:\s+.+$',
            re.MULTILINE
        )

    header_match = header_pattern.search(content)
    if not header_match:
        return None

    # Find the status line after this header
    # Search from after the header to the next REQ or end of file
    search_start = header_match.end()

    # Find the next REQ header to limit our search
    next_req_match = REQ_HEADER_PATTERN.search(content, search_start)
    search_end = next_req_match.start() if next_req_match else len(content)

    # Search for the status line within this range
    status_match = STATUS_LINE_PATTERN.search(content, search_start, search_end)
    if not status_match:
        return None

    current_status = status_match.group(2)

    return {
        "req_id": req_id,
        "current_status": current_status,
        "status_line_start": status_match.start(),
        "status_line_end": status_match.end(),
        "status_value_start": status_match.start(2),
        "status_value_end": status_match.end(2),
    }


def get_spec_file_for_req(repo_root: Path, req_id: str) -> Optional[Path]:
    """
    Find which spec file contains a given requirement.

    Args:
        repo_root: Path to the repository root
        req_id: The requirement ID (without REQ- prefix)

    Returns:
        Path to the spec file containing the REQ, or None if not found
    """
    # Check core spec directory
    spec_dir = repo_root / "spec"
    if spec_dir.exists():
        for spec_file in spec_dir.glob("*.md"):
            if spec_file.name in ('INDEX.md', 'README.md', 'requirements-format.md'):
                continue
            if find_req_in_file(spec_file, req_id):
                return spec_file

    # Check sponsor spec directories
    sponsor_dir = repo_root / "sponsor"
    if sponsor_dir.exists():
        for sponsor in sponsor_dir.iterdir():
            if sponsor.is_dir():
                sponsor_spec = sponsor / "spec"
                if sponsor_spec.exists():
                    for spec_file in sponsor_spec.glob("*.md"):
                        if spec_file.name in ('INDEX.md', 'README.md', 'requirements-format.md'):
                            continue
                        if find_req_in_file(spec_file, req_id):
                            return spec_file

    return None


def get_req_status(repo_root: Path, req_id: str) -> Optional[str]:
    """
    Get the current status of a requirement.

    Args:
        repo_root: Path to the repository root
        req_id: The requirement ID (without REQ- prefix)

    Returns:
        The status string if found, None otherwise
    """
    spec_file = get_spec_file_for_req(repo_root, req_id)
    if not spec_file:
        return None

    result = find_req_in_file(spec_file, req_id)
    if not result:
        return None

    return result["current_status"]


def change_req_status(
    repo_root: Path,
    req_id: str,
    new_status: str,
    user: str
) -> Dict[str, Any]:
    """
    Change the status of a requirement in its spec file.

    Args:
        repo_root: Path to the repository root
        req_id: The requirement ID (without REQ- prefix)
        new_status: The new status to set
        user: Username making the change (for logging/audit)

    Returns:
        Result dictionary:
        {
            "success": bool,
            "old_status": str (if success),
            "new_status": str (if success),
            "file": str (if success),
            "no_change": bool (if status was already the target),
            "error": str (if not success),
        }
    """
    # Validate new_status
    if new_status not in VALID_STATUSES:
        return {
            "success": False,
            "error": f"Invalid status '{new_status}'. Valid statuses: {', '.join(sorted(VALID_STATUSES))}"
        }

    # Find the spec file
    spec_file = get_spec_file_for_req(repo_root, req_id)
    if not spec_file:
        return {
            "success": False,
            "error": f"REQ-{req_id} not found in any spec file"
        }

    # Find the requirement in the file
    req_info = find_req_in_file(spec_file, req_id)
    if not req_info:
        return {
            "success": False,
            "error": f"REQ-{req_id} not found in {spec_file}"
        }

    old_status = req_info["current_status"]

    # Check if already at target status
    if old_status == new_status:
        return {
            "success": True,
            "old_status": old_status,
            "new_status": new_status,
            "file": str(spec_file),
            "no_change": True
        }

    # Read the file content
    content = spec_file.read_text(encoding='utf-8')

    # Replace the status value
    new_content = (
        content[:req_info["status_value_start"]] +
        new_status +
        content[req_info["status_value_end"]:]
    )

    # Write the updated content
    spec_file.write_text(new_content, encoding='utf-8')

    return {
        "success": True,
        "old_status": old_status,
        "new_status": new_status,
        "file": str(spec_file),
        "user": user
    }


if __name__ == "__main__":
    # Simple CLI for testing
    import sys

    if len(sys.argv) < 4:
        print("Usage: python status_modifier.py <repo_root> <req_id> <new_status>")
        print("Example: python status_modifier.py /path/to/repo d00001 Review")
        sys.exit(1)

    repo_root = Path(sys.argv[1])
    req_id = sys.argv[2]
    new_status = sys.argv[3]
    user = "cli_user"

    result = change_req_status(repo_root, req_id, new_status, user)
    print(result)
    sys.exit(0 if result.get("success") else 1)
