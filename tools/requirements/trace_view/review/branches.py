#!/usr/bin/env python3
"""
Review Git Branch Management Module

Handles git branch operations for the review system:
- Branch naming and parsing
- Branch creation, checkout, push, fetch
- Branch listing and discovery
- Cleanup operations
- Conflict detection

Branch naming convention: reviews/{package}/{user}
- Package-first naming enables discovery of all branches for a package
- User-specific branches enable isolated work without merge conflicts

IMPLEMENTS REQUIREMENTS:
    REQ-d00027: Workflow plugin state management
"""

import re
import subprocess
from contextlib import contextmanager
from pathlib import Path
from typing import Dict, List, Optional, Tuple


# =============================================================================
# Branch Naming
# =============================================================================

REVIEW_BRANCH_PREFIX = 'reviews/'


def get_review_branch_name(package_id: str, user: str) -> str:
    """
    Generate a review branch name from package and user.

    Args:
        package_id: Review package identifier (e.g., 'default', 'q1-2025-review')
        user: Username

    Returns:
        Branch name in format: reviews/{package}/{user}
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


def parse_review_branch_name(branch_name: str) -> Optional[Tuple[str, str]]:
    """
    Parse a review branch name into (package_id, user).

    Args:
        branch_name: Full branch name

    Returns:
        Tuple of (package_id, user) or None if not a valid review branch
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

    Args:
        branch_name: Branch name to check

    Returns:
        True if valid review branch format (reviews/{package}/{user})
    """
    if not branch_name.startswith(REVIEW_BRANCH_PREFIX):
        return False

    remainder = branch_name[len(REVIEW_BRANCH_PREFIX):]
    parts = remainder.split('/', 1)

    # Must have both package and user
    return len(parts) == 2 and bool(parts[0]) and bool(parts[1])


# =============================================================================
# Package-Aware Discovery
# =============================================================================

def list_package_branches(repo_root: Path, package_id: str) -> List[str]:
    """
    List all local review branches for a specific package.

    Args:
        repo_root: Repository root path
        package_id: Package identifier (e.g., 'default', 'q1-review')

    Returns:
        List of branch names matching reviews/{package_id}/*
    """
    sanitized_package = _sanitize_branch_name(package_id)
    pattern = f"{REVIEW_BRANCH_PREFIX}{sanitized_package}/*"
    return _list_branches_by_pattern(repo_root, pattern)


def list_user_branches(repo_root: Path, user: str) -> List[str]:
    """
    List all local review branches for a specific user across all packages.

    Args:
        repo_root: Repository root path
        user: Username

    Returns:
        List of branch names matching reviews/*/{user}
    """
    branches = []
    sanitized_user = _sanitize_branch_name(user)

    # Get all review branches and filter by user (second component)
    for branch in list_local_review_branches(repo_root):
        parsed = parse_review_branch_name(branch)
        if parsed and parsed[1] == sanitized_user:
            branches.append(branch)

    return branches


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


def ensure_package_branch(repo_root: Path, package_id: str, user: str) -> str:
    """
    Ensure user is on correct package branch.

    Creates the branch if it doesn't exist, checks out if it does.

    Args:
        repo_root: Repository root path
        package_id: Review package identifier
        user: Username

    Returns:
        Branch name (reviews/{package}/{user})
    """
    branch_name = get_review_branch_name(package_id, user)

    if not branch_exists(repo_root, branch_name):
        # Create the branch
        result = _run_git(repo_root, ['branch', branch_name])
        if result.returncode != 0:
            raise RuntimeError(f"Failed to create branch: {result.stderr}")

    # Checkout the branch
    result = _run_git(repo_root, ['checkout', branch_name])
    if result.returncode != 0:
        raise RuntimeError(f"Failed to checkout branch: {result.stderr}")

    return branch_name


def switch_to_package_branch(repo_root: Path, package_id: str, user: str) -> bool:
    """
    Switch to the package branch for a user.

    Stashes any uncommitted changes before switching.

    Args:
        repo_root: Repository root path
        package_id: Review package identifier
        user: Username

    Returns:
        True if switch succeeded
    """
    # Stash any uncommitted changes
    if has_uncommitted_changes(repo_root):
        result = _run_git(repo_root, ['stash', 'push', '-m', 'Auto-stash before package switch'])
        if result.returncode != 0:
            return False

    try:
        ensure_package_branch(repo_root, package_id, user)
        return True
    except RuntimeError:
        return False


def get_current_package_context(repo_root: Path) -> Optional[Tuple[str, str]]:
    """
    Get current (package_id, user) from branch name.

    Returns:
        Tuple of (package_id, user) or None if not on a review branch
    """
    current_branch = get_current_branch(repo_root)
    if not current_branch:
        return None

    return parse_review_branch_name(current_branch)


@contextmanager
def temporary_branch_switch(repo_root: Path, target_branch: str):
    """
    Context manager for temporary branch switching.

    Saves the current branch, switches to target_branch, yields,
    then switches back to the original branch.

    Args:
        repo_root: Repository root path
        target_branch: Branch to temporarily switch to

    Yields:
        True if switch succeeded, False otherwise
    """
    original_branch = get_current_branch(repo_root)

    # If already on target branch, no switch needed
    if original_branch == target_branch:
        yield True
        return

    # Try to switch to target branch
    result = _run_git(repo_root, ['checkout', target_branch])
    switched = result.returncode == 0

    try:
        yield switched
    finally:
        # Always try to switch back
        if switched and original_branch:
            _run_git(repo_root, ['checkout', original_branch])


def commit_and_return(
    repo_root: Path,
    package_id: str,
    user: str,
    message: str,
    remote: str = 'origin'
) -> Dict:
    """
    Commit review changes to a package branch, then return to original branch.

    Args:
        repo_root: Repository root path
        package_id: Review package identifier
        user: Username
        message: Commit message
        remote: Remote name to push to

    Returns:
        dict with keys: success, committed, pushed, error, returned
    """
    branch_name = get_review_branch_name(package_id, user)

    result = {
        'success': False,
        'committed': False,
        'pushed': False,
        'returned': False,
        'error': None
    }

    with temporary_branch_switch(repo_root, branch_name) as switched:
        if not switched:
            result['error'] = f'Failed to switch to branch: {branch_name}'
            return result

        # Commit and push
        commit_result = commit_and_push_reviews(repo_root, message, user, remote)
        result.update(commit_result)

    # If we got here, we're back on original branch
    result['returned'] = True
    return result


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


def push_review_branch(repo_root: Path, package_id: str, user: str,
                       remote: str = 'origin') -> bool:
    """
    Push a review branch to remote.

    Args:
        repo_root: Repository root path
        package_id: Review package identifier
        user: Username
        remote: Remote name

    Returns:
        True if push succeeded
    """
    # Check if remote exists
    if get_remote_name(repo_root) is None:
        return False

    branch_name = get_review_branch_name(package_id, user)
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
            # User is second component: reviews/{package}/{user}
            users.add(parsed[1])

    # Get remote branches
    if include_remote:
        for branch in list_remote_review_branches(repo_root):
            # Remove remote prefix for parsing
            if '/' in branch:
                branch_name = '/'.join(branch.split('/')[1:])
                parsed = parse_review_branch_name(branch_name)
                if parsed:
                    # User is second component: reviews/{package}/{user}
                    users.add(parsed[1])

    return sorted(list(users))


# =============================================================================
# Cleanup
# =============================================================================

def delete_local_review_branch(repo_root: Path, package_id: str, user: str) -> bool:
    """
    Delete a local review branch.

    Args:
        repo_root: Repository root path
        package_id: Review package identifier
        user: Username

    Returns:
        True if deleted, False if not found or couldn't delete
    """
    branch_name = get_review_branch_name(package_id, user)

    if not branch_exists(repo_root, branch_name):
        return False

    # Can't delete current branch
    current = get_current_branch(repo_root)
    if current == branch_name:
        return False

    result = _run_git(repo_root, ['branch', '-d', branch_name])
    return result.returncode == 0


def delete_remote_review_branch(repo_root: Path, package_id: str, user: str,
                                remote: str = 'origin') -> bool:
    """
    Delete a remote review branch.

    Args:
        repo_root: Repository root path
        package_id: Review package identifier
        user: Username
        remote: Remote name

    Returns:
        True if deleted
    """
    branch_name = get_review_branch_name(package_id, user)
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


def check_review_branch_conflicts(repo_root: Path, package_id: str,
                                  user: str) -> List[str]:
    """
    Check for potential conflicts before switching to a review branch.

    Args:
        repo_root: Repository root path
        package_id: Review package identifier
        user: Username

    Returns:
        List of conflict/warning messages (empty if safe)
    """
    conflicts = []

    # Check for uncommitted changes
    if has_uncommitted_changes(repo_root):
        conflicts.append("You have uncommitted changes that may be lost")

    return conflicts


# =============================================================================
# Auto-Sync Operations
# =============================================================================

def has_reviews_changes(repo_root: Path) -> bool:
    """
    Check if there are uncommitted changes in .reviews/ directory.

    Args:
        repo_root: Repository root path

    Returns:
        True if .reviews/ has uncommitted changes
    """
    result = _run_git(repo_root, ['status', '--porcelain', '.reviews/'])
    return bool(result.stdout.strip())


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
) -> Dict:
    """
    Commit changes to .reviews/ and push to remote.

    Args:
        repo_root: Repository root path
        message: Commit message describing the change
        user: Username for commit attribution
        remote: Remote name to push to

    Returns:
        dict with keys: success, committed, pushed, error
    """
    result = {
        'success': False,
        'committed': False,
        'pushed': False,
        'error': None
    }

    # Check if there are changes
    if not has_reviews_changes(repo_root):
        result['success'] = True
        return result  # No changes, nothing to do

    # Commit changes
    if not commit_reviews(repo_root, message, user):
        result['error'] = 'Failed to commit review changes'
        return result

    result['committed'] = True

    # Push to remote
    current_branch = get_current_branch(repo_root)
    if current_branch:
        push_result = _run_git(repo_root, ['push', remote, current_branch])
        if push_result.returncode == 0:
            result['pushed'] = True
            result['success'] = True
        else:
            # Commit succeeded but push failed - partial success
            result['error'] = f'Push failed: {push_result.stderr}'
            result['success'] = True  # Commit worked, push can retry
    else:
        result['error'] = 'Could not determine current branch'
        result['success'] = True  # Commit worked

    return result


def fetch_and_merge_reviews(
    repo_root: Path,
    remote: str = 'origin'
) -> Dict:
    """
    Fetch latest review data from remote and merge.

    Args:
        repo_root: Repository root path
        remote: Remote name

    Returns:
        dict with keys: success, fetched, merged, error
    """
    result = {
        'success': False,
        'fetched': False,
        'merged': False,
        'error': None
    }

    # Check for remote
    if get_remote_name(repo_root) is None:
        result['error'] = 'No remote configured'
        return result

    current_branch = get_current_branch(repo_root)
    if not current_branch:
        result['error'] = 'Could not determine current branch'
        return result

    # Fetch from remote
    fetch_result = _run_git(repo_root, ['fetch', remote])
    if fetch_result.returncode != 0:
        result['error'] = f'Fetch failed: {fetch_result.stderr}'
        return result

    result['fetched'] = True

    # Check if remote branch exists
    if not remote_branch_exists(repo_root, current_branch, remote):
        # No remote branch, nothing to merge
        result['success'] = True
        return result

    # Try to merge (fast-forward only for safety)
    remote_ref = f'{remote}/{current_branch}'
    merge_result = _run_git(repo_root, ['merge', '--ff-only', remote_ref])
    if merge_result.returncode == 0:
        result['merged'] = True
        result['success'] = True
    else:
        # Can't fast-forward, might have conflicts
        result['error'] = 'Merge conflict - manual resolution required'
        result['success'] = False

    return result


def get_sync_status(repo_root: Path, remote: str = 'origin') -> Dict:
    """
    Get the current sync status of review data.

    Args:
        repo_root: Repository root path
        remote: Remote name

    Returns:
        dict with keys: has_local_changes, ahead, behind, branch, last_sync
    """
    status = {
        'has_local_changes': has_reviews_changes(repo_root),
        'ahead': 0,
        'behind': 0,
        'branch': get_current_branch(repo_root),
        'last_sync': None
    }

    branch = status['branch']
    if not branch:
        return status

    # Check ahead/behind
    remote_ref = f'{remote}/{branch}'
    if remote_branch_exists(repo_root, branch, remote):
        # Get commit counts
        result = _run_git(repo_root, [
            'rev-list', '--left-right', '--count',
            f'{branch}...{remote_ref}'
        ])
        if result.returncode == 0 and result.stdout.strip():
            parts = result.stdout.strip().split()
            if len(parts) == 2:
                try:
                    status['ahead'] = int(parts[0])
                    status['behind'] = int(parts[1])
                except ValueError:
                    pass

    return status
