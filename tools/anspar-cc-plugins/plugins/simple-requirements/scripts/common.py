#!/usr/bin/env python3
"""
Common utilities for simple-requirements plugin scripts.

This module provides shared functionality used across multiple scripts:
- Repository root detection
- Tracking file operations (with thread-safe locking)
- Requirement ID normalization and patterns

IMPLEMENTS REQUIREMENTS:
    REQ-d00018: Git Hook Implementation (tracking file utilities)
"""

import sys
import os
import re
import json
import fcntl
import subprocess
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any


# =============================================================================
# Repository Root Detection
# =============================================================================

def get_repo_root() -> Path:
    """
    Get the repository root using git.

    This works even when the script is run from the Claude Code plugin cache,
    as long as the current working directory is within a git repository.

    Returns:
        Path to repository root

    Raises:
        RuntimeError: If not in a git repository and fallback fails
    """
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True,
            text=True,
            check=True
        )
        return Path(result.stdout.strip())
    except subprocess.CalledProcessError:
        # Fallback to relative path traversal (works when run from repo directly)
        # scripts/common.py -> scripts -> simple-requirements -> plugins ->
        # anspar-cc-plugins -> tools -> repo_root
        fallback = Path(__file__).resolve().parents[5]
        if (fallback / '.git').exists():
            return fallback
        raise RuntimeError("Not in a git repository and fallback path invalid")


# =============================================================================
# Constants and Paths
# =============================================================================

# Lazy initialization to avoid issues when module is imported
_repo_root: Optional[Path] = None


def _get_repo_root_cached() -> Path:
    """Get cached repo root (lazy initialization)."""
    global _repo_root
    if _repo_root is None:
        _repo_root = get_repo_root()
    return _repo_root


def get_tracking_file_path() -> Path:
    """
    Get the path to outdated-implementations.json tracking file.

    Returns:
        Path to tracking file
    """
    return _get_repo_root_cached() / 'untracked-notes' / 'outdated-implementations.json'


def get_spec_dir() -> Path:
    """
    Get the path to the spec/ directory.

    Returns:
        Path to spec directory
    """
    return _get_repo_root_cached() / 'spec'


def get_index_path() -> Path:
    """
    Get the path to spec/INDEX.md.

    Returns:
        Path to INDEX.md
    """
    return get_spec_dir() / 'INDEX.md'


# =============================================================================
# Requirement ID Patterns and Normalization
# =============================================================================

# Pattern: REQ-{type}{number} where type is p/o/d and number is 5 digits
REQ_PATTERN = r'REQ-([pdo][0-9]{5})'
REQ_PATTERN_COMPILED = re.compile(REQ_PATTERN, re.IGNORECASE)

# Full REQ reference pattern (with REQ- prefix)
REQ_FULL_PATTERN = r'REQ-[pdo][0-9]{5}'
REQ_FULL_PATTERN_COMPILED = re.compile(REQ_FULL_PATTERN, re.IGNORECASE)


def normalize_req_id(req_id: str) -> str:
    """
    Normalize requirement ID to standard format (without REQ- prefix).

    Args:
        req_id: Requirement ID (e.g., "REQ-d00027" or "d00027")

    Returns:
        Normalized ID in lowercase (e.g., "d00027")
    """
    if req_id.upper().startswith('REQ-'):
        req_id = req_id[4:]
    return req_id.lower()


def format_req_id(req_id: str) -> str:
    """
    Format requirement ID with REQ- prefix.

    Args:
        req_id: Requirement ID (e.g., "d00027" or "REQ-d00027")

    Returns:
        Formatted ID with prefix (e.g., "REQ-d00027")
    """
    normalized = normalize_req_id(req_id)
    return f"REQ-{normalized}"


def extract_req_ids(text: str) -> List[str]:
    """
    Extract all REQ-xxx references from text.

    Args:
        text: Text to search (e.g., commit message, code comment)

    Returns:
        List of normalized requirement IDs (e.g., ['d00027', 'p00042'])
    """
    matches = REQ_PATTERN_COMPILED.findall(text)
    return [m.lower() for m in matches]


def is_valid_req_id(req_id: str) -> bool:
    """
    Check if a requirement ID is valid.

    Args:
        req_id: Requirement ID to validate (with or without REQ- prefix)

    Returns:
        True if valid, False otherwise
    """
    normalized = normalize_req_id(req_id)
    return bool(re.match(r'^[pdo][0-9]{5}$', normalized, re.IGNORECASE))


# =============================================================================
# Tracking File Operations (Thread-Safe)
# =============================================================================

# Current tracking file schema version
TRACKING_VERSION = "1.0"


def load_tracking_file(create_if_missing: bool = False) -> Dict[str, Any]:
    """
    Load tracking file with thread-safe locking.

    Args:
        create_if_missing: If True, return empty structure instead of raising

    Returns:
        Dict with version, last_updated, outdated_requirements

    Raises:
        FileNotFoundError: If file doesn't exist and create_if_missing is False
        json.JSONDecodeError: If file contains invalid JSON
    """
    tracking_file = get_tracking_file_path()

    if not tracking_file.exists():
        if create_if_missing:
            return {
                'version': TRACKING_VERSION,
                'last_updated': datetime.now(timezone.utc).isoformat(),
                'outdated_requirements': []
            }
        raise FileNotFoundError(f"Tracking file not found: {tracking_file}")

    with tracking_file.open('r') as f:
        # Acquire shared lock for reading
        fcntl.flock(f.fileno(), fcntl.LOCK_SH)
        try:
            data = json.load(f)
            return data
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def save_tracking_file(data: Dict[str, Any]) -> None:
    """
    Save tracking file with thread-safe locking and atomic write.

    Args:
        data: Tracking data to save
    """
    tracking_file = get_tracking_file_path()

    # Ensure parent directory exists
    tracking_file.parent.mkdir(parents=True, exist_ok=True)

    # Update timestamp
    data['last_updated'] = datetime.now(timezone.utc).isoformat()

    # Ensure version is set
    if 'version' not in data:
        data['version'] = TRACKING_VERSION

    # Write atomically with exclusive lock
    temp_file = tracking_file.with_suffix('.tmp')
    with temp_file.open('w') as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            json.dump(data, f, indent=2)
            f.write('\n')  # Trailing newline
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)

    # Atomic rename
    temp_file.replace(tracking_file)


def find_outdated_req(req_id: str, tracking_data: Optional[Dict] = None) -> Optional[Dict]:
    """
    Find an outdated requirement entry by ID.

    Args:
        req_id: Requirement ID to find (with or without REQ- prefix)
        tracking_data: Pre-loaded tracking data (loads if None)

    Returns:
        The requirement entry dict if found, None otherwise
    """
    if tracking_data is None:
        try:
            tracking_data = load_tracking_file()
        except FileNotFoundError:
            return None

    normalized = normalize_req_id(req_id)

    for entry in tracking_data.get('outdated_requirements', []):
        if entry.get('req_id', '').lower() == normalized:
            return entry

    return None


def remove_from_tracking(req_id: str) -> Optional[Dict]:
    """
    Remove a requirement from the tracking file.

    Args:
        req_id: Requirement ID to remove (with or without REQ- prefix)

    Returns:
        The removed entry if found, None otherwise
    """
    try:
        tracking_data = load_tracking_file()
    except FileNotFoundError:
        return None

    normalized = normalize_req_id(req_id)
    removed_entry = None

    for i, entry in enumerate(tracking_data.get('outdated_requirements', [])):
        if entry.get('req_id', '').lower() == normalized:
            removed_entry = tracking_data['outdated_requirements'].pop(i)
            break

    if removed_entry:
        save_tracking_file(tracking_data)

    return removed_entry


# =============================================================================
# Utility Functions
# =============================================================================

def get_requirements_via_cli() -> Dict[str, Dict[str, Any]]:
    """
    Get all requirements by running elspais validate --json.

    Returns:
        Dict mapping requirement ID (e.g., 'REQ-d00027') to requirement data dict
        containing: title, status, level, body, file, filePath, line, implements, hash
    """
    try:
        result = subprocess.run(
            ['elspais', 'validate', '--export'],
            capture_output=True,
            text=True,
            cwd=str(_get_repo_root_cached())
        )

        # The JSON starts after the "Found N requirements" line
        output = result.stdout
        json_start = output.find('{')
        if json_start == -1:
            return {}

        json_str = output[json_start:]
        return json.loads(json_str)
    except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Warning: Failed to get requirements via elspais: {e}", file=sys.stderr)
        return {}


def get_git_config(key: str, default: str = '') -> str:
    """
    Get a git config value.

    Args:
        key: Config key (e.g., 'workflow.autoVerifyReq')
        default: Default value if not set

    Returns:
        Config value or default
    """
    try:
        result = subprocess.run(
            ['git', 'config', '--get', key],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except subprocess.CalledProcessError:
        pass
    return default


def get_env_bool(key: str, default: bool = False) -> bool:
    """
    Get a boolean value from environment variable.

    Args:
        key: Environment variable name
        default: Default value if not set

    Returns:
        Boolean value
    """
    value = os.environ.get(key, '').lower()
    if value in ('1', 'true', 'yes'):
        return True
    if value in ('0', 'false', 'no'):
        return False
    return default
