#!/usr/bin/env python3
"""
Status Modifier Module - Modify REQ status in spec files

Provides functions to change the status field of requirements in spec/*.md files.
Supports finding requirements, reading status, changing status atomically,
and updating content hashes.

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00015: Status Modifier
"""

import hashlib
import os
import re
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Tuple

# =============================================================================
# Constants
# REQ-tv-d00015-D: Status values SHALL be validated against allowed set
# =============================================================================

VALID_STATUSES = {"Draft", "Active", "Deprecated"}

# Regex pattern to match the status line in a requirement
# Matches: **Level**: Dev | **Status**: Draft | **Implements**: REQ-xxx
STATUS_LINE_PATTERN = re.compile(
    r'^(\*\*Level\*\*:\s+(?:PRD|Ops|Dev)\s+\|\s+'
    r'\*\*Status\*\*:\s+)(Draft|Active|Deprecated)'
    r'(\s+\|\s+\*\*Implements\*\*:\s+[^\n]*?)$',
    re.MULTILINE
)

# Pattern to find a REQ header (supports both REQ-tv-xxx and REQ-SPONSOR-xxx formats)
REQ_HEADER_PATTERN = re.compile(
    r'^#{1,6}\s+REQ-(?:([A-Za-z]{2,4})-)?([pod]\d{5}):\s+(.+)$',
    re.MULTILINE
)

# Pattern to find the End footer with hash
REQ_FOOTER_PATTERN = re.compile(
    r'^\*End\* \*([^*]+)\* \| \*\*Hash\*\*: ([a-f0-9]{8})$',
    re.MULTILINE
)


# =============================================================================
# Data Classes
# REQ-tv-d00015-A: Return structured location information
# =============================================================================

@dataclass
class ReqLocation:
    """Location of a requirement in a spec file."""
    file_path: Path
    line_number: int  # 1-based line number of status line
    current_status: str
    req_id: str


# =============================================================================
# Hash Functions
# REQ-tv-d00015-F: Content hash computation and update
# =============================================================================

def compute_req_hash(content: str) -> str:
    """
    Compute an 8-character hex hash of requirement content.

    REQ-tv-d00015-F: The status modifier SHALL update the requirement's
    content hash footer after status changes.

    Args:
        content: The content to hash

    Returns:
        8-character lowercase hex string
    """
    return hashlib.sha256(content.encode('utf-8')).hexdigest()[:8]


def _extract_req_content(file_content: str, req_id: str) -> Optional[Tuple[str, int, int]]:
    """
    Extract the content of a requirement from the file.

    Returns the content between header and footer (exclusive of footer hash),
    along with the footer start position and hash start position.
    """
    # Normalize req_id (remove REQ- prefix if present)
    normalized_id = req_id
    if normalized_id.startswith("REQ-"):
        normalized_id = normalized_id[4:]

    # Build pattern for this specific requirement
    # Handle both "tv-d00010" and "HHT-d00001" formats
    if '-' in normalized_id:
        parts = normalized_id.split('-', 1)
        prefix = parts[0]
        base_id = parts[1]
        header_pattern = re.compile(
            rf'^#{{1,6}}\s+REQ-{re.escape(prefix)}-{re.escape(base_id)}:\s+(.+)$',
            re.MULTILINE
        )
    else:
        header_pattern = re.compile(
            rf'^#{{1,6}}\s+REQ-{re.escape(normalized_id)}:\s+(.+)$',
            re.MULTILINE
        )

    header_match = header_pattern.search(file_content)
    if not header_match:
        return None

    header_start = header_match.start()
    req_title = header_match.group(1).strip()

    # Find the footer for this requirement
    # The footer format is: *End* *{title}* | **Hash**: {hash}
    footer_pattern = re.compile(
        rf'^\*End\* \*{re.escape(req_title)}\* \| \*\*Hash\*\*: ([a-f0-9]{{8}})$',
        re.MULTILINE
    )

    # Search from after the header
    footer_match = footer_pattern.search(file_content, header_match.end())
    if not footer_match:
        return None

    # Content is from header start to just before the hash value
    footer_start = footer_match.start()
    hash_start = footer_match.start(1)

    # Content for hashing: everything from header to before the hash value
    # This includes the "*End* *Title* | **Hash**: " but not the actual hash
    content = file_content[header_start:hash_start]

    return content, footer_start, hash_start


def update_req_hash(file_path: Path, req_id: str) -> bool:
    """
    Update the content hash for a requirement in a spec file.

    REQ-tv-d00015-F: The status modifier SHALL update the requirement's
    content hash footer after status changes.

    Args:
        file_path: Path to the spec file
        req_id: The requirement ID (with or without REQ- prefix)

    Returns:
        True if hash was updated, False if requirement not found
    """
    try:
        content = file_path.read_text(encoding='utf-8')
    except (FileNotFoundError, IOError):
        return False

    result = _extract_req_content(content, req_id)
    if result is None:
        return False

    req_content, footer_start, hash_start = result

    # Compute new hash
    new_hash = compute_req_hash(req_content)

    # Find the end of the old hash (8 characters after hash_start)
    hash_end = hash_start + 8

    # Replace the hash
    new_content = content[:hash_start] + new_hash + content[hash_end:]

    # Write atomically
    _atomic_write_file(file_path, new_content)

    return True


# =============================================================================
# File Search Functions
# REQ-tv-d00015-A: find_req_in_file() SHALL locate a requirement
# =============================================================================

def find_req_in_file(file_path: Path, req_id: str) -> Optional[ReqLocation]:
    """
    Find a requirement in a spec file and return its position info.

    REQ-tv-d00015-A: find_req_in_file(file_path, req_id) SHALL locate a
    requirement in a spec file and return the status line information.

    Args:
        file_path: Path to the spec file
        req_id: The requirement ID (with or without REQ- prefix),
                e.g., "tv-d00001" or "REQ-tv-d00001" or "HHT-d00001"

    Returns:
        ReqLocation with req info if found, None otherwise
    """
    try:
        content = file_path.read_text(encoding='utf-8')
    except (FileNotFoundError, IOError):
        return None

    # Normalize req_id (remove REQ- prefix if present)
    normalized_id = req_id
    if normalized_id.startswith("REQ-"):
        normalized_id = normalized_id[4:]

    # Build pattern for this specific requirement
    # Handle both "tv-d00010" and "HHT-d00001" formats
    if '-' in normalized_id:
        parts = normalized_id.split('-', 1)
        prefix = parts[0]
        base_id = parts[1]
        header_pattern = re.compile(
            rf'^#{{1,6}}\s+REQ-{re.escape(prefix)}-{re.escape(base_id)}:\s+.+$',
            re.MULTILINE
        )
    else:
        header_pattern = re.compile(
            rf'^#{{1,6}}\s+REQ-{re.escape(normalized_id)}:\s+.+$',
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

    # Calculate 1-based line number
    line_number = content[:status_match.start()].count('\n') + 1

    return ReqLocation(
        file_path=file_path,
        line_number=line_number,
        current_status=current_status,
        req_id=normalized_id
    )


def find_req_in_spec_dir(repo_root: Path, req_id: str) -> Optional[ReqLocation]:
    """
    Find which spec file contains a given requirement.

    Searches both core spec/ directory and sponsor/*/spec/ directories.

    Args:
        repo_root: Path to the repository root
        req_id: The requirement ID (with or without REQ- prefix)

    Returns:
        ReqLocation if found, None otherwise
    """
    # Check core spec directory
    spec_dir = repo_root / "spec"
    if spec_dir.exists():
        for spec_file in spec_dir.glob("*.md"):
            if spec_file.name in ('INDEX.md', 'README.md', 'requirements-format.md'):
                continue
            location = find_req_in_file(spec_file, req_id)
            if location:
                return location

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
                        location = find_req_in_file(spec_file, req_id)
                        if location:
                            return location

    return None


# =============================================================================
# Status Read Function
# REQ-tv-d00015-B: get_req_status() SHALL read and return current status
# =============================================================================

def get_req_status(repo_root: Path, req_id: str) -> Optional[str]:
    """
    Get the current status of a requirement.

    REQ-tv-d00015-B: get_req_status(repo_root, req_id) SHALL read and return
    the current status value from the spec file.

    Args:
        repo_root: Path to the repository root
        req_id: The requirement ID (with or without REQ- prefix)

    Returns:
        The status string if found, None otherwise
    """
    location = find_req_in_spec_dir(repo_root, req_id)
    if not location:
        return None
    return location.current_status


# =============================================================================
# Atomic File Operations
# REQ-tv-d00015-G: Failed status changes SHALL NOT corrupt the file
# =============================================================================

def _atomic_write_file(file_path: Path, content: str) -> None:
    """
    Atomically write content to a file.

    REQ-tv-d00015-G: Uses temp file + rename pattern to ensure file is either
    fully written or not changed at all.

    Args:
        file_path: Target file path
        content: Content to write
    """
    # Ensure parent directories exist
    file_path.parent.mkdir(parents=True, exist_ok=True)

    # Write to temp file in same directory (for atomic rename)
    fd, temp_path = tempfile.mkstemp(
        suffix='.md',
        prefix='.tmp_',
        dir=file_path.parent
    )
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(content)
        # Atomic rename
        os.rename(temp_path, file_path)
    except Exception:
        # Clean up temp file on failure
        if os.path.exists(temp_path):
            os.unlink(temp_path)
        raise


# =============================================================================
# Status Change Function
# REQ-tv-d00015-C: change_req_status() SHALL update status atomically
# =============================================================================

def change_req_status(
    repo_root: Path,
    req_id: str,
    new_status: str,
    user: str
) -> Tuple[bool, str]:
    """
    Change the status of a requirement in its spec file.

    REQ-tv-d00015-C: change_req_status(repo_root, req_id, new_status, user)
    SHALL update the status value in the spec file atomically.

    REQ-tv-d00015-D: Status values SHALL be validated against the allowed set.

    REQ-tv-d00015-E: The status modifier SHALL preserve all other content.

    REQ-tv-d00015-F: The status modifier SHALL update the requirement's
    content hash footer after status changes.

    REQ-tv-d00015-G: Failed status changes SHALL NOT leave the spec file
    in a corrupted or partial state.

    Args:
        repo_root: Path to the repository root
        req_id: The requirement ID (with or without REQ- prefix)
        new_status: The new status to set
        user: Username making the change (for logging/audit)

    Returns:
        Tuple of (success: bool, message: str)
    """
    # Validate new_status (REQ-tv-d00015-D)
    if new_status not in VALID_STATUSES:
        valid_list = ', '.join(sorted(VALID_STATUSES))
        return (False, f"Invalid status '{new_status}'. Valid statuses: {valid_list}")

    # Find the requirement
    location = find_req_in_spec_dir(repo_root, req_id)
    if not location:
        return (False, f"REQ-{req_id} not found in any spec file")

    # Check if already at target status
    if location.current_status == new_status:
        return (True, f"REQ-{req_id} already has status '{new_status}'")

    # Read the file content
    try:
        content = location.file_path.read_text(encoding='utf-8')
    except IOError as e:
        return (False, f"Failed to read spec file: {e}")

    # Normalize req_id for pattern matching
    normalized_id = req_id
    if normalized_id.startswith("REQ-"):
        normalized_id = normalized_id[4:]

    # Build pattern for this specific requirement header
    if '-' in normalized_id:
        parts = normalized_id.split('-', 1)
        prefix = parts[0]
        base_id = parts[1]
        header_pattern = re.compile(
            rf'^#{{1,6}}\s+REQ-{re.escape(prefix)}-{re.escape(base_id)}:\s+.+$',
            re.MULTILINE
        )
    else:
        header_pattern = re.compile(
            rf'^#{{1,6}}\s+REQ-{re.escape(normalized_id)}:\s+.+$',
            re.MULTILINE
        )

    header_match = header_pattern.search(content)
    if not header_match:
        return (False, f"REQ-{req_id} header not found in {location.file_path}")

    # Find the status line
    search_start = header_match.end()
    next_req_match = REQ_HEADER_PATTERN.search(content, search_start)
    search_end = next_req_match.start() if next_req_match else len(content)

    status_match = STATUS_LINE_PATTERN.search(content, search_start, search_end)
    if not status_match:
        return (False, f"Status line not found for REQ-{req_id}")

    # Build the new status line (REQ-tv-d00015-E: preserve formatting)
    new_line = status_match.group(1) + new_status + status_match.group(3)

    # Replace the status line in content
    new_content = (
        content[:status_match.start()] +
        new_line +
        content[status_match.end():]
    )

    # Write atomically (REQ-tv-d00015-G)
    try:
        _atomic_write_file(location.file_path, new_content)
    except IOError as e:
        return (False, f"Failed to write spec file: {e}")

    # Update the hash (REQ-tv-d00015-F)
    update_req_hash(location.file_path, req_id)

    old_status = location.current_status
    return (True, f"Changed REQ-{req_id} status from '{old_status}' to '{new_status}'")
