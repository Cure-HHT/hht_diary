"""
Implementation file scanning for trace-view.

Provides functions to scan implementation files for requirement references
and associate them with requirements.
"""

import re
from pathlib import Path
from typing import Dict, List, Set, Optional

from .models import Requirement


def scan_implementation_files(
    requirements: Dict[str, Requirement],
    impl_dirs: List[Path],
    repo_root: Path,
    mode: str = 'core',
    sponsor: Optional[str] = None
) -> None:
    """Scan implementation files for requirement references.

    This function modifies the requirements dict in-place, adding
    implementation file references to each requirement.

    Args:
        requirements: Dict mapping requirement ID to Requirement
        impl_dirs: List of directories to scan for implementations
        repo_root: Repository root for calculating relative paths
        mode: Scanning mode ('core', 'sponsor', 'combined')
        sponsor: Sponsor name for sponsor mode
    """
    # Pattern to match requirement references in code comments
    # Matches: REQ-p00001, REQ-o00042, REQ-d00156, REQ-CAL-d00001
    req_ref_pattern = re.compile(r'REQ-(?:([A-Z]+)-)?([pod]\d{5})')

    total_files_scanned = 0
    total_refs_found = 0

    for impl_dir in impl_dirs:
        if not impl_dir.exists():
            print(f"   ⚠️  Implementation directory not found: {impl_dir}")
            continue

        # Apply mode-based filtering
        if _should_skip_directory(impl_dir, mode, sponsor):
            print(f"   ⏭️  Skipping directory (mode={mode}): {impl_dir}")
            continue

        # Determine file patterns based on directory
        if impl_dir.name == 'database':
            patterns = ['*.sql']
        elif impl_dir.name in ['diary_app', 'portal_app']:
            patterns = ['**/*.dart']
        else:
            # Default: scan common code file types
            patterns = ['**/*.dart', '**/*.sql', '**/*.py', '**/*.js', '**/*.ts']

        for pattern in patterns:
            for file_path in impl_dir.glob(pattern):
                if file_path.is_file():
                    # Skip files in sponsor directories if not in the right mode
                    if _should_skip_file(file_path, mode, sponsor):
                        continue

                    total_files_scanned += 1
                    refs = _scan_file_for_requirements(
                        file_path, req_ref_pattern, requirements, repo_root
                    )
                    total_refs_found += len(refs)

    print(f"   ✅ Scanned {total_files_scanned} implementation files")
    print(f"   📌 Found {total_refs_found} requirement references")


def _scan_file_for_requirements(
    file_path: Path,
    pattern: re.Pattern,
    requirements: Dict[str, Requirement],
    repo_root: Path
) -> Set[str]:
    """Scan a single implementation file for requirement references.

    Args:
        file_path: Path to the file to scan
        pattern: Compiled regex pattern for matching REQ references
        requirements: Dict mapping requirement ID to Requirement
        repo_root: Repository root for calculating relative paths

    Returns:
        Set of requirement IDs found in the file
    """
    try:
        content = file_path.read_text(encoding='utf-8')
    except (UnicodeDecodeError, PermissionError):
        # Skip files that can't be read
        return set()

    # Find all requirement IDs referenced in this file with their line numbers
    referenced_reqs: Set[str] = set()
    rel_path = file_path.relative_to(repo_root)  # Relative to repo root

    for match in pattern.finditer(content):
        sponsor_prefix = match.group(1)  # May be None for core requirements
        req_id_core = match.group(2)  # The core part (e.g., 'd00027')

        # Build full requirement ID (with sponsor prefix if present)
        if sponsor_prefix:
            req_id = f"{sponsor_prefix}-{req_id_core}"
        else:
            req_id = req_id_core

        referenced_reqs.add(req_id)

        # Calculate line number from match position
        line_num = content[:match.start()].count('\n') + 1

        # Add (file_path, line_number) tuple to requirement's implementation_files
        if req_id in requirements:
            impl_entry = (str(rel_path), line_num)
            # Avoid duplicates (same file, same line)
            if impl_entry not in requirements[req_id].implementation_files:
                requirements[req_id].implementation_files.append(impl_entry)

    return referenced_reqs


def _should_skip_directory(dir_path: Path, mode: str, sponsor: Optional[str]) -> bool:
    """Check if a directory should be skipped based on mode.

    Args:
        dir_path: Path to the directory
        mode: Scanning mode ('core', 'sponsor', 'combined')
        sponsor: Sponsor name for sponsor mode

    Returns:
        True if the directory should be skipped
    """
    try:
        parts = dir_path.parts
        if 'sponsor' in parts:
            sponsor_idx = parts.index('sponsor')
            if sponsor_idx + 1 < len(parts):
                dir_sponsor = parts[sponsor_idx + 1]

                # In core mode, skip all sponsor directories
                if mode == 'core':
                    return True

                # In sponsor mode, skip sponsor directories that don't match our sponsor
                if mode == 'sponsor' and sponsor and dir_sponsor != sponsor:
                    return True

        return False
    except (ValueError, IndexError):
        return False


def _should_skip_file(file_path: Path, mode: str, sponsor: Optional[str]) -> bool:
    """Check if a file should be skipped based on mode.

    Args:
        file_path: Path to the file
        mode: Scanning mode ('core', 'sponsor', 'combined')
        sponsor: Sponsor name for sponsor mode

    Returns:
        True if the file should be skipped
    """
    try:
        parts = file_path.parts
        if 'sponsor' in parts:
            sponsor_idx = parts.index('sponsor')
            if sponsor_idx + 1 < len(parts):
                file_sponsor = parts[sponsor_idx + 1]

                # In core mode, skip all sponsor files
                if mode == 'core':
                    return True

                # In sponsor mode, skip sponsor files that don't match our sponsor
                if mode == 'sponsor' and sponsor and file_sponsor != sponsor:
                    return True

        return False
    except (ValueError, IndexError):
        return False
