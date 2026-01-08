"""
File editing utilities for in-place requirement replacement.

Provides functions to locate requirements in files, create backups,
and replace content while preserving surrounding text.
"""

import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Tuple

from .hierarchy import get_repo_root


def backup_file(file_path: str) -> str:
    """
    Create a backup of the file with .bak extension.

    Args:
        file_path: Path to file to backup

    Returns:
        Path to backup file
    """
    backup_path = f"{file_path}.bak"
    shutil.copy2(file_path, backup_path)
    return backup_path


def find_requirement_in_file(file_path: str, req_id: str) -> Tuple[int, int, str]:
    """
    Find the start and end lines of a requirement in a file.

    Args:
        file_path: Path to spec file
        req_id: Requirement ID (e.g., 'REQ-p00046')

    Returns:
        Tuple of (start_line, end_line, current_content)
        Lines are 0-indexed for array access

    Raises:
        ValueError: If requirement boundaries not found
    """
    with open(file_path, 'r') as f:
        lines = f.readlines()

    start_line = None
    end_line = None

    # Pattern for requirement header: # REQ-xxx: Title or ## REQ-xxx: Title
    # Need to escape the req_id properly for regex
    header_pattern = re.compile(
        rf'^#+\s+{re.escape(req_id)}:\s+',
        re.IGNORECASE
    )

    # Pattern for end marker: *End* *Title* | **Hash**: value
    end_pattern = re.compile(
        r'^\*End\*\s+\*[^*]+\*\s+\|\s+\*\*Hash\*\*:',
        re.IGNORECASE
    )

    for i, line in enumerate(lines):
        if start_line is None and header_pattern.match(line):
            start_line = i
        elif start_line is not None and end_pattern.match(line.strip()):
            end_line = i
            break

    if start_line is None:
        raise ValueError(f"Could not find header for {req_id} in {file_path}")
    if end_line is None:
        raise ValueError(f"Could not find end marker for {req_id} in {file_path}")

    # Include the end marker line in the content
    content = ''.join(lines[start_line:end_line + 1])
    return start_line, end_line, content


def replace_requirement_in_file(
    file_path: str,
    req_id: str,
    new_content: str,
    create_backup: bool = False
) -> bool:
    """
    Replace a requirement in a file with new content.

    Args:
        file_path: Path to spec file
        req_id: Requirement ID to replace
        new_content: New requirement content (full markdown)
        create_backup: Whether to create .bak file

    Returns:
        True if successful

    Raises:
        ValueError: If requirement not found
        IOError: If file cannot be written
    """
    if create_backup:
        backup_file(file_path)

    start_line, end_line, _ = find_requirement_in_file(file_path, req_id)

    with open(file_path, 'r') as f:
        lines = f.readlines()

    # Ensure new content ends with newline
    if not new_content.endswith('\n'):
        new_content += '\n'

    # Replace lines: before + new content + after
    # Note: end_line is inclusive, so we skip to end_line + 1
    new_lines = lines[:start_line] + [new_content] + lines[end_line + 1:]

    with open(file_path, 'w') as f:
        f.writelines(new_lines)

    return True


def update_hash(req_id: str, verbose: bool = False) -> bool:
    """
    Update requirement hash using elspais CLI.

    Args:
        req_id: Requirement ID (e.g., 'REQ-p00046')
        verbose: Print command output

    Returns:
        True if successful
    """
    repo_root = get_repo_root()

    try:
        # elspais hash update takes req_id as positional argument
        result = subprocess.run(
            ['elspais', 'hash', 'update', req_id],
            capture_output=True,
            text=True,
            cwd=str(repo_root)
        )

        if verbose and result.stdout:
            print(result.stdout, file=sys.stderr)

        return result.returncode == 0

    except FileNotFoundError:
        print("Warning: elspais not found - hash not updated", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Warning: Hash update failed: {e}", file=sys.stderr)
        return False


def get_file_for_req(req_id: str, requirements: dict) -> str:
    """
    Get the file path for a requirement.

    Args:
        req_id: Requirement ID
        requirements: Dict of RequirementNode objects

    Returns:
        File path string

    Raises:
        KeyError: If requirement not found
    """
    if req_id not in requirements:
        raise KeyError(f"Requirement {req_id} not found")
    return requirements[req_id].file_path
