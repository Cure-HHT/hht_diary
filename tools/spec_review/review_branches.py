#!/usr/bin/env python3
"""
Spec Review Git Branch Management Module

Handles git branch operations for the review system:
- Branch naming and parsing
- Branch creation, checkout, push, fetch
- Branch listing and discovery
- Cleanup operations
- Conflict detection

Branch naming convention: reviews/{user}/{session}

IMPLEMENTS REQUIREMENTS:
    REQ-d00086: Spec Review Data Model
"""

import re
import subprocess
from pathlib import Path
from typing import List, Optional, Tuple


# =============================================================================
# Branch Naming
# =============================================================================

REVIEW_BRANCH_PREFIX = 'reviews/'


def get_review_branch_name(user: str, session: str) -> str:
    """
    Generate a review branch name from user and session.

    Args:
        user: Username
        session: Session name

    Returns:
        Branch name in format: reviews/{user}/{session}
    """
    # Sanitize session name for git branch
    sanitized_session = _sanitize_branch_name(session)
    return f"{REVIEW_BRANCH_PREFIX}{user}/{sanitized_session}"


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


def parse_review_branch_name(branch_name: str) -> Optional[Tuple[str, str]]:
    """
    Parse a review branch name into (user, session).

    Args:
        branch_name: Full branch name

    Returns:
        Tuple of (user, session) or None if not a valid review branch
    """
    if not is_review_branch(branch_name):
        return None

    # Remove prefix
    remainder = branch_name[len(REVIEW_BRANCH_PREFIX):]
    parts = remainder.split('/', 1)

    if len(parts) != 2 or not parts[0] or not parts[1]:
        return None

    return (parts[0], parts[1])


def is_review_branch(branch_name: str) -> bool:
    """
    Check if a branch name is a valid review branch.

    Args:
        branch_name: Branch name to check

    Returns:
        True if valid review branch format
    """
    if not branch_name.startswith(REVIEW_BRANCH_PREFIX):
        return False

    remainder = branch_name[len(REVIEW_BRANCH_PREFIX):]
    parts = remainder.split('/', 1)

    # Must have both user and session
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
# Branch Operations
# =============================================================================

def create_review_branch(repo_root: Path, user: str, session: str) -> str:
    """
    Create a new review branch.

    Args:
        repo_root: Repository root path
        user: Username
        session: Session name

    Returns:
        Created branch name

    Raises:
        ValueError: If branch already exists
    """
    branch_name = get_review_branch_name(user, session)

    if branch_exists(repo_root, branch_name):
        raise ValueError(f"Branch already exists: {branch_name}")

    result = _run_git(repo_root, ['branch', branch_name])
    if result.returncode != 0:
        raise RuntimeError(f"Failed to create branch: {result.stderr}")

    return branch_name


def checkout_review_branch(repo_root: Path, user: str, session: str) -> bool:
    """
    Checkout a review branch.

    Args:
        repo_root: Repository root path
        user: Username
        session: Session name

    Returns:
        True if checkout succeeded, False if branch doesn't exist
    """
    branch_name = get_review_branch_name(user, session)

    if not branch_exists(repo_root, branch_name):
        return False

    result = _run_git(repo_root, ['checkout', branch_name])
    return result.returncode == 0


def push_review_branch(repo_root: Path, user: str, session: str,
                       remote: str = 'origin') -> bool:
    """
    Push a review branch to remote.

    Args:
        repo_root: Repository root path
        user: Username
        session: Session name
        remote: Remote name

    Returns:
        True if push succeeded
    """
    # Check if remote exists
    if get_remote_name(repo_root) is None:
        return False

    branch_name = get_review_branch_name(user, session)
    result = _run_git(repo_root, ['push', '-u', remote, branch_name])
    return result.returncode == 0


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


# =============================================================================
# Listing and Discovery
# =============================================================================

def list_local_review_branches(repo_root: Path,
                               user: Optional[str] = None) -> List[str]:
    """
    List all local review branches.

    Args:
        repo_root: Repository root path
        user: Optional filter by username

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
                if parsed and parsed[0] == user:
                    branches.append(branch)

    return branches


def list_remote_review_branches(repo_root: Path,
                                remote: str = 'origin') -> List[str]:
    """
    List all remote review branches.

    Args:
        repo_root: Repository root path
        remote: Remote name

    Returns:
        List of branch names (with remote/ prefix)
    """
    result = _run_git(repo_root, ['branch', '-r', '--list', f'{remote}/reviews/*'])
    if result.returncode != 0:
        return []

    branches = []
    for line in result.stdout.strip().split('\n'):
        branch = line.strip()
        if branch:
            branches.append(branch)

    return branches


def list_all_review_users(repo_root: Path,
                          include_remote: bool = True) -> List[str]:
    """
    List all users who have review branches.

    Args:
        repo_root: Repository root path
        include_remote: Include users from remote branches

    Returns:
        List of unique usernames
    """
    users = set()

    # Get local branches
    for branch in list_local_review_branches(repo_root):
        parsed = parse_review_branch_name(branch)
        if parsed:
            users.add(parsed[0])

    # Get remote branches
    if include_remote:
        for branch in list_remote_review_branches(repo_root):
            # Remove remote prefix for parsing
            if '/' in branch:
                branch_name = '/'.join(branch.split('/')[1:])
                parsed = parse_review_branch_name(branch_name)
                if parsed:
                    users.add(parsed[0])

    return sorted(list(users))


# =============================================================================
# Cleanup
# =============================================================================

def delete_local_review_branch(repo_root: Path, user: str, session: str) -> bool:
    """
    Delete a local review branch.

    Args:
        repo_root: Repository root path
        user: Username
        session: Session name

    Returns:
        True if deleted, False if not found or couldn't delete
    """
    branch_name = get_review_branch_name(user, session)

    if not branch_exists(repo_root, branch_name):
        return False

    # Can't delete current branch
    current = get_current_branch(repo_root)
    if current == branch_name:
        return False

    result = _run_git(repo_root, ['branch', '-d', branch_name])
    return result.returncode == 0


def delete_remote_review_branch(repo_root: Path, user: str, session: str,
                                remote: str = 'origin') -> bool:
    """
    Delete a remote review branch.

    Args:
        repo_root: Repository root path
        user: Username
        session: Session name
        remote: Remote name

    Returns:
        True if deleted
    """
    branch_name = get_review_branch_name(user, session)
    result = _run_git(repo_root, ['push', remote, '--delete', branch_name])
    return result.returncode == 0


def cleanup_old_branches(repo_root: Path, older_than_days: int = 90,
                         dry_run: bool = True) -> List[str]:
    """
    Find review branches older than specified days.

    Args:
        repo_root: Repository root path
        older_than_days: Age threshold in days
        dry_run: If True, just list branches without deleting

    Returns:
        List of branches that are/would be deleted
    """
    import time

    threshold = time.time() - (older_than_days * 24 * 60 * 60)
    old_branches = []

    for branch in list_local_review_branches(repo_root):
        # Get last commit date
        result = _run_git(repo_root, [
            'log', '-1', '--format=%ct', branch
        ])
        if result.returncode == 0 and result.stdout.strip():
            try:
                commit_time = int(result.stdout.strip())
                if commit_time < threshold:
                    old_branches.append(branch)
                    if not dry_run:
                        parsed = parse_review_branch_name(branch)
                        if parsed:
                            delete_local_review_branch(repo_root, parsed[0], parsed[1])
            except ValueError:
                pass

    return old_branches


# =============================================================================
# Conflict Detection
# =============================================================================

def has_uncommitted_changes(repo_root: Path) -> bool:
    """
    Check if there are uncommitted changes.

    Args:
        repo_root: Repository root path

    Returns:
        True if there are uncommitted changes (staged or unstaged)
    """
    result = _run_git(repo_root, ['status', '--porcelain'])
    return bool(result.stdout.strip())


def check_review_branch_conflicts(repo_root: Path, user: str,
                                  session: str) -> List[str]:
    """
    Check for potential conflicts before switching to a review branch.

    Args:
        repo_root: Repository root path
        user: Username
        session: Session name

    Returns:
        List of conflict/warning messages (empty if safe)
    """
    conflicts = []

    # Check for uncommitted changes
    if has_uncommitted_changes(repo_root):
        conflicts.append("You have uncommitted changes that may be lost")

    # Check if branch exists
    branch_name = get_review_branch_name(user, session)
    if not branch_exists(repo_root, branch_name):
        # Not really a conflict, but informational
        pass

    return conflicts
