#!/usr/bin/env python3
"""
Review Branch Management Module for trace_view

Handles git branch operations for the review system:
- Branch naming and parsing
- Branch creation, checkout, push, fetch
- Branch listing and discovery
- Conflict detection

Branch naming convention: reviews/{package_id}/{username}
- Package-first naming enables discovery of all branches for a package
- User-specific branches enable isolated work without merge conflicts

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00013: Git Branch Management
"""

import re
import subprocess
from pathlib import Path
from typing import List, Optional, Tuple


# =============================================================================
# Constants
# =============================================================================

REVIEW_BRANCH_PREFIX = 'reviews/'


# =============================================================================
# Branch Naming (REQ-tv-d00013-A, B)
# =============================================================================

def get_review_branch_name(package_id: str, user: str) -> str:
    """
    Generate a review branch name from package and user.

    REQ-tv-d00013-A: Review branches SHALL follow the naming convention
                     `reviews/{package_id}/{username}`.
    REQ-tv-d00013-B: This function SHALL return the formatted branch name.

    Args:
        package_id: Review package identifier (e.g., 'default', 'q1-2025-review')
        user: Username

    Returns:
        Branch name in format: reviews/{package}/{user}

    Examples:
        >>> get_review_branch_name('default', 'alice')
        'reviews/default/alice'
        >>> get_review_branch_name('q1-review', 'bob')
        'reviews/q1-review/bob'
    """
    # Sanitize both package and user for git branch
    sanitized_package = _sanitize_branch_name(package_id)
    sanitized_user = _sanitize_branch_name(user)
    return f"{REVIEW_BRANCH_PREFIX}{sanitized_package}/{sanitized_user}"


def _sanitize_branch_name(name: str) -> str:
    """
    Sanitize a string for use in a git branch name.

    Replaces spaces with hyphens and removes invalid characters.
    """
    # Replace spaces with hyphens
    name = name.replace(' ', '-')
    # Remove invalid characters (keep alphanumeric, hyphen, underscore)
    name = re.sub(r'[^a-zA-Z0-9_-]', '', name)
    # Remove leading/trailing hyphens
    name = name.strip('-')
    # Convert to lowercase
    return name.lower()


# =============================================================================
# Branch Parsing (REQ-tv-d00013-C, D)
# =============================================================================

def parse_review_branch_name(branch_name: str) -> Optional[Tuple[str, str]]:
    """
    Parse a review branch name into (package_id, user).

    REQ-tv-d00013-C: This function SHALL extract and return a tuple of
                     `(package_id, username)` from a valid branch name.

    Args:
        branch_name: Full branch name

    Returns:
        Tuple of (package_id, user) or None if not a valid review branch

    Examples:
        >>> parse_review_branch_name('reviews/default/alice')
        ('default', 'alice')
        >>> parse_review_branch_name('reviews/q1-review/bob')
        ('q1-review', 'bob')
        >>> parse_review_branch_name('main')
        None
    """
    if not is_review_branch(branch_name):
        return None

    # Remove prefix
    remainder = branch_name[len(REVIEW_BRANCH_PREFIX):]
    parts = remainder.split('/', 1)

    if len(parts) != 2 or not parts[0] or not parts[1]:
        return None

    # Returns (package_id, user)
    return (parts[0], parts[1])


def is_review_branch(branch_name: str) -> bool:
    """
    Check if a branch name is a valid review branch.

    REQ-tv-d00013-D: This function SHALL return True only for branches
                     matching the `reviews/{package}/{user}` pattern.

    Args:
        branch_name: Branch name to check

    Returns:
        True if valid review branch format (reviews/{package}/{user})

    Examples:
        >>> is_review_branch('reviews/default/alice')
        True
        >>> is_review_branch('reviews/q1-review/bob')
        True
        >>> is_review_branch('main')
        False
        >>> is_review_branch('reviews/default')  # Missing user
        False
    """
    if not branch_name.startswith(REVIEW_BRANCH_PREFIX):
        return False

    remainder = branch_name[len(REVIEW_BRANCH_PREFIX):]
    parts = remainder.split('/', 1)

    # Must have both package and user
    return len(parts) == 2 and bool(parts[0]) and bool(parts[1])


# =============================================================================
# Git Utilities
# =============================================================================

def _run_git(repo_root: Path, args: List[str],
             check: bool = False) -> subprocess.CompletedProcess:
    """
    Run a git command in the repository.

    Args:
        repo_root: Repository root path
        args: Git command arguments
        check: If True, raise on non-zero exit code

    Returns:
        CompletedProcess result
    """
    try:
        return subprocess.run(
            ['git'] + args,
            cwd=repo_root,
            capture_output=True,
            text=True,
            check=check
        )
    except (subprocess.CalledProcessError, FileNotFoundError, OSError):
        # Return a fake failed result
        return subprocess.CompletedProcess(
            args=['git'] + args,
            returncode=1,
            stdout='',
            stderr='Error running git'
        )


def get_current_branch(repo_root: Path) -> Optional[str]:
    """
    Get the current git branch name.

    Args:
        repo_root: Repository root path

    Returns:
        Branch name or None if not in a git repo
    """
    result = _run_git(repo_root, ['rev-parse', '--abbrev-ref', 'HEAD'])
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def get_remote_name(repo_root: Path) -> Optional[str]:
    """
    Get the default remote name (usually 'origin').

    Args:
        repo_root: Repository root path

    Returns:
        Remote name or None if no remotes configured
    """
    result = _run_git(repo_root, ['remote'])
    if result.returncode != 0 or not result.stdout.strip():
        return None
    # Return first remote
    return result.stdout.strip().split('\n')[0]


def branch_exists(repo_root: Path, branch_name: str) -> bool:
    """
    Check if a local branch exists.

    Args:
        repo_root: Repository root path
        branch_name: Branch name to check

    Returns:
        True if branch exists locally
    """
    result = _run_git(repo_root, ['rev-parse', '--verify', f'refs/heads/{branch_name}'])
    return result.returncode == 0


def remote_branch_exists(repo_root: Path, branch_name: str,
                         remote: str = 'origin') -> bool:
    """
    Check if a remote branch exists.

    Args:
        repo_root: Repository root path
        branch_name: Branch name to check
        remote: Remote name

    Returns:
        True if branch exists on remote
    """
    result = _run_git(repo_root, ['rev-parse', '--verify', f'refs/remotes/{remote}/{branch_name}'])
    return result.returncode == 0


# =============================================================================
# Package Context (REQ-tv-d00013-F)
# =============================================================================

def get_current_package_context(repo_root: Path) -> Tuple[Optional[str], Optional[str]]:
    """
    Get current (package_id, user) from branch name.

    REQ-tv-d00013-F: This function SHALL return `(package_id, username)` when
                     on a review branch, or `(None, None)` otherwise.

    Args:
        repo_root: Repository root path

    Returns:
        Tuple of (package_id, user) or (None, None) if not on a review branch

    Examples:
        >>> get_current_package_context(repo)
        ('q1-review', 'alice')  # When on reviews/q1-review/alice
        >>> get_current_package_context(repo)
        (None, None)  # When on main branch
    """
    current_branch = get_current_branch(repo_root)
    if not current_branch:
        return (None, None)

    parsed = parse_review_branch_name(current_branch)
    if parsed:
        return parsed
    return (None, None)


# =============================================================================
# Branch Discovery (REQ-tv-d00013-E)
# =============================================================================

def list_package_branches(repo_root: Path, package_id: str) -> List[str]:
    """
    List all local review branches for a specific package.

    REQ-tv-d00013-E: This function SHALL return all branch names for a given
                     package across all users.

    Args:
        repo_root: Repository root path
        package_id: Package identifier (e.g., 'default', 'q1-review')

    Returns:
        List of branch names matching reviews/{package_id}/*

    Examples:
        >>> list_package_branches(repo, 'default')
        ['reviews/default/alice', 'reviews/default/bob']
    """
    sanitized_package = _sanitize_branch_name(package_id)
    pattern = f"{REVIEW_BRANCH_PREFIX}{sanitized_package}/*"
    return _list_branches_by_pattern(repo_root, pattern)


def _list_branches_by_pattern(repo_root: Path, pattern: str) -> List[str]:
    """
    List local branches matching a pattern.

    Args:
        repo_root: Repository root path
        pattern: Git branch pattern (e.g., 'reviews/default/*')

    Returns:
        List of matching branch names
    """
    result = _run_git(repo_root, ['branch', '--list', pattern])
    if result.returncode != 0:
        return []

    branches = []
    for line in result.stdout.strip().split('\n'):
        branch = line.strip().lstrip('* ')
        if branch and is_review_branch(branch):
            branches.append(branch)

    return branches


def list_local_review_branches(repo_root: Path,
                               user: Optional[str] = None) -> List[str]:
    """
    List all local review branches.

    Args:
        repo_root: Repository root path
        user: Optional filter by username (matches second component of branch)

    Returns:
        List of branch names
    """
    result = _run_git(repo_root, ['branch', '--list', 'reviews/*'])
    if result.returncode != 0:
        return []

    branches = []
    for line in result.stdout.strip().split('\n'):
        # Remove leading * and whitespace
        branch = line.strip().lstrip('* ')
        if branch and is_review_branch(branch):
            if user is None:
                branches.append(branch)
            else:
                parsed = parse_review_branch_name(branch)
                # User is second component: reviews/{package}/{user}
                if parsed and parsed[1] == user:
                    branches.append(branch)

    return branches


# =============================================================================
# Branch Operations
# =============================================================================

def create_review_branch(repo_root: Path, package_id: str, user: str) -> str:
    """
    Create a new review branch.

    Args:
        repo_root: Repository root path
        package_id: Review package identifier
        user: Username

    Returns:
        Created branch name (reviews/{package}/{user})

    Raises:
        ValueError: If branch already exists
        RuntimeError: If branch creation fails
    """
    branch_name = get_review_branch_name(package_id, user)

    if branch_exists(repo_root, branch_name):
        raise ValueError(f"Branch already exists: {branch_name}")

    result = _run_git(repo_root, ['branch', branch_name])
    if result.returncode != 0:
        raise RuntimeError(f"Failed to create branch: {result.stderr}")

    return branch_name


def checkout_review_branch(repo_root: Path, package_id: str, user: str) -> bool:
    """
    Checkout a review branch.

    Args:
        repo_root: Repository root path
        package_id: Review package identifier
        user: Username

    Returns:
        True if checkout succeeded, False if branch doesn't exist
    """
    branch_name = get_review_branch_name(package_id, user)

    if not branch_exists(repo_root, branch_name):
        return False

    result = _run_git(repo_root, ['checkout', branch_name])
    return result.returncode == 0


# =============================================================================
# Change Detection
# =============================================================================

def has_uncommitted_changes(repo_root: Path) -> bool:
    """
    Check if there are uncommitted changes.

    REQ-tv-d00013-H: Part of conflict detection - detects local changes.

    Args:
        repo_root: Repository root path

    Returns:
        True if there are uncommitted changes (staged or unstaged)
    """
    result = _run_git(repo_root, ['status', '--porcelain'])
    return bool(result.stdout.strip())


def has_reviews_changes(repo_root: Path) -> bool:
    """
    Check if there are uncommitted changes in .reviews/ directory.

    Args:
        repo_root: Repository root path

    Returns:
        True if .reviews/ has uncommitted changes
    """
    reviews_dir = repo_root / '.reviews'
    if not reviews_dir.exists():
        return False

    result = _run_git(repo_root, ['status', '--porcelain', '.reviews/'])
    return bool(result.stdout.strip())


def has_conflicts(repo_root: Path) -> bool:
    """
    Check if there are merge conflicts in the repository.

    REQ-tv-d00013-H: Branch operations SHALL detect and report conflicts.

    Args:
        repo_root: Repository root path

    Returns:
        True if there are unresolved merge conflicts
    """
    # Check for merge in progress
    git_dir = repo_root / '.git'
    if (git_dir / 'MERGE_HEAD').exists():
        # Merge in progress, check for conflict markers
        result = _run_git(repo_root, ['diff', '--check'])
        return result.returncode != 0

    # Check for conflict markers in staged files
    result = _run_git(repo_root, ['diff', '--cached', '--check'])
    if result.returncode != 0:
        return True

    # Also check working tree
    result = _run_git(repo_root, ['diff', '--check'])
    return result.returncode != 0


# =============================================================================
# Commit and Push Operations (REQ-tv-d00013-G)
# =============================================================================

def commit_reviews(repo_root: Path, message: str, user: str = 'system') -> bool:
    """
    Commit changes to .reviews/ directory.

    Args:
        repo_root: Repository root path
        message: Commit message
        user: Username for commit attribution

    Returns:
        True if commit succeeded (or no changes to commit)
    """
    # Check if there are changes to commit
    if not has_reviews_changes(repo_root):
        return True  # No changes, success

    # Stage .reviews/ changes
    result = _run_git(repo_root, ['add', '.reviews/'])
    if result.returncode != 0:
        return False

    # Commit with message
    full_message = f"[review] {message}\n\nBy: {user}"
    result = _run_git(repo_root, ['commit', '-m', full_message])
    return result.returncode == 0


def commit_and_push_reviews(
    repo_root: Path,
    message: str,
    user: str = 'system',
    remote: str = 'origin'
) -> Tuple[bool, str]:
    """
    Commit changes to .reviews/ and push to remote.

    REQ-tv-d00013-G: This function SHALL commit all changes in `.reviews/`
                     and push to the remote tracking branch.

    Args:
        repo_root: Repository root path
        message: Commit message describing the change
        user: Username for commit attribution
        remote: Remote name to push to

    Returns:
        Tuple of (success: bool, message: str)
    """
    # Check if there are changes
    if not has_reviews_changes(repo_root):
        return (True, 'No changes to commit')

    # Stage .reviews/ changes
    result = _run_git(repo_root, ['add', '.reviews/'])
    if result.returncode != 0:
        return (False, f'Failed to stage changes: {result.stderr}')

    # Commit with message
    full_message = f"[review] {message}\n\nBy: {user}"
    result = _run_git(repo_root, ['commit', '-m', full_message])
    if result.returncode != 0:
        return (False, f'Failed to commit: {result.stderr}')

    # Check if remote exists
    if get_remote_name(repo_root) is None:
        return (True, 'Committed locally (no remote configured)')

    # Push to remote
    current_branch = get_current_branch(repo_root)
    if current_branch:
        push_result = _run_git(repo_root, ['push', remote, current_branch])
        if push_result.returncode == 0:
            return (True, 'Committed and pushed successfully')
        else:
            # Commit succeeded but push failed - still return success for commit
            return (True, f'Committed locally (push failed: {push_result.stderr})')

    return (True, 'Committed locally')


# =============================================================================
# Fetch Operations (REQ-tv-d00013-I)
# =============================================================================

def fetch_package_branches(repo_root: Path, package_id: str,
                           remote: str = 'origin') -> List[str]:
    """
    Fetch all remote branches for a package.

    REQ-tv-d00013-I: This function SHALL fetch all remote branches for a
                     package to enable merge operations.

    Args:
        repo_root: Repository root path
        package_id: Package identifier
        remote: Remote name

    Returns:
        List of fetched branch names for the package
    """
    # Check if remote exists
    if get_remote_name(repo_root) is None:
        return []

    sanitized_package = _sanitize_branch_name(package_id)
    refspec = f'refs/heads/{REVIEW_BRANCH_PREFIX}{sanitized_package}/*:refs/remotes/{remote}/{REVIEW_BRANCH_PREFIX}{sanitized_package}/*'

    # Fetch the specific package branches
    result = _run_git(repo_root, ['fetch', remote, refspec])

    # Even if fetch fails (e.g., no matching refs), list what we have
    branches = []
    list_result = _run_git(repo_root, ['branch', '-r', '--list', f'{remote}/{REVIEW_BRANCH_PREFIX}{sanitized_package}/*'])

    if list_result.returncode == 0:
        for line in list_result.stdout.strip().split('\n'):
            branch = line.strip()
            if branch:
                branches.append(branch)

    return branches


def fetch_review_branches(repo_root: Path, remote: str = 'origin') -> bool:
    """
    Fetch all review branches from remote.

    Args:
        repo_root: Repository root path
        remote: Remote name

    Returns:
        True if fetch succeeded
    """
    if get_remote_name(repo_root) is None:
        return False

    result = _run_git(repo_root, ['fetch', remote, '--prune'])
    return result.returncode == 0
