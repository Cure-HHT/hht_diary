"""
Validation utilities for trace-view.

Provides functions to detect issues in requirements that could cause
problems in traceability reports, such as duplicate REQ IDs.
"""

import re
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass


@dataclass
class DuplicateReq:
    """Represents a duplicate requirement ID found in multiple files."""
    req_id: str
    locations: List[Tuple[str, int]]  # List of (file_path, line_number)

    def __str__(self) -> str:
        locations_str = '\n'.join(
            f'    - {path}:{line}' for path, line in self.locations
        )
        return f'REQ-{self.req_id} defined in {len(self.locations)} files:\n{locations_str}'


def find_duplicate_req_definitions(
    spec_dir: Path,
    exclude_patterns: Optional[List[str]] = None
) -> List[DuplicateReq]:
    """Find REQ IDs that are defined in multiple files.

    Scans all markdown files in the spec directory for REQ definition headers
    (e.g., "# REQ-d00027: Title") and identifies any REQ ID that appears
    in more than one file.

    This detects a common issue where requirements are copied between files
    (e.g., to a roadmap/ subdirectory) but the original is not removed,
    causing false "MOVED" indicators and confusion about the authoritative source.

    Args:
        spec_dir: Path to the spec directory to scan
        exclude_patterns: List of filename patterns to exclude (default: INDEX.md, README.md)

    Returns:
        List of DuplicateReq objects, each containing the REQ ID and all
        locations where it is defined. Empty list if no duplicates found.

    Example:
        >>> duplicates = find_duplicate_req_definitions(Path('spec'))
        >>> for dup in duplicates:
        ...     print(dup)
        REQ-d00027 defined in 2 files:
            - spec/dev-environment.md:30
            - spec/roadmap/dev-environment.md:10
    """
    if exclude_patterns is None:
        exclude_patterns = ['INDEX.md', 'README.md', 'requirements-format.md']

    # Pattern matches REQ definition headers: # REQ-d00027: Title
    # Captures the ID part (e.g., 'd00027') and handles optional sponsor prefix
    req_pattern = re.compile(
        r'^(#{1,6})\s+REQ-(?:[A-Z]{2,4}-)?([pod]\d{5}):',
        re.MULTILINE
    )

    # Map of REQ ID -> list of (file_path, line_number)
    req_locations: Dict[str, List[Tuple[str, int]]] = {}

    # Find all markdown files recursively
    for md_file in spec_dir.rglob('*.md'):
        # Skip excluded files
        if any(pattern in md_file.name for pattern in exclude_patterns):
            continue

        try:
            content = md_file.read_text(encoding='utf-8')
        except (IOError, UnicodeDecodeError):
            continue

        # Find all REQ definitions in this file
        for match in req_pattern.finditer(content):
            req_id = match.group(2)  # The ID part (e.g., 'd00027')

            # Calculate line number from match position
            line_number = content[:match.start()].count('\n') + 1

            # Get relative path from spec_dir's parent (to include 'spec/' prefix)
            try:
                rel_path = md_file.relative_to(spec_dir.parent)
            except ValueError:
                rel_path = md_file

            if req_id not in req_locations:
                req_locations[req_id] = []
            req_locations[req_id].append((str(rel_path), line_number))

    # Filter to only duplicates (more than one location)
    duplicates = [
        DuplicateReq(req_id=req_id, locations=locations)
        for req_id, locations in sorted(req_locations.items())
        if len(locations) > 1
    ]

    return duplicates


def validate_no_duplicate_reqs(
    spec_dir: Path,
    print_results: bool = True
) -> bool:
    """Validate that no REQ IDs are defined in multiple files.

    This is a convenience wrapper around find_duplicate_req_definitions
    that prints results and returns a pass/fail status.

    Args:
        spec_dir: Path to the spec directory to scan
        print_results: If True, print findings to stdout

    Returns:
        True if no duplicates found (validation passed), False otherwise
    """
    duplicates = find_duplicate_req_definitions(spec_dir)

    if not duplicates:
        if print_results:
            print('✅ No duplicate REQ definitions found')
        return True

    if print_results:
        print(f'❌ Found {len(duplicates)} REQ ID(s) defined in multiple files:\n')
        for dup in duplicates:
            print(dup)
            print()
        print('Each REQ ID must be defined in exactly one file.')
        print('Remove duplicates or consolidate into a single authoritative file.')

    return False
