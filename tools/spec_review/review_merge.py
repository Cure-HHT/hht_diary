#!/usr/bin/env python3
"""
Spec Review Merge Module

Handles merging review data from multiple user branches for a package.
Enables consolidated view across all contributors.

IMPLEMENTS REQUIREMENTS:
    REQ-d00086: Spec Review Data Model
"""

import json
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Any

from tools.spec_review.review_branches import (
    list_package_branches,
    parse_review_branch_name,
    get_remote_name,
    _run_git,
)
from tools.spec_review.review_storage import (
    load_threads,
    load_review_flag,
    merge_threads,
)


def get_package_contributors(repo_root: Path, package_id: str) -> List[str]:
    """
    List all users who have branches for this package.

    Args:
        repo_root: Repository root path
        package_id: Package identifier

    Returns:
        Sorted list of unique usernames

    Examples:
        >>> get_package_contributors(repo, 'q1-review')
        ['alice', 'bob', 'charlie']
    """
    branches = list_package_branches(repo_root, package_id)
    users = []

    for branch in branches:
        parsed = parse_review_branch_name(branch)
        if parsed:
            users.append(parsed[1])  # User is second component

    return sorted(list(set(users)))


def fetch_all_package_branches(repo_root: Path, package_id: str,
                               remote: str = 'origin') -> List[str]:
    """
    Fetch all remote branches for a package.

    Args:
        repo_root: Repository root path
        package_id: Package identifier
        remote: Remote name (default: origin)

    Returns:
        List of fetched branch names
    """
    # Check if remote exists
    if get_remote_name(repo_root) is None:
        return []

    # Fetch from remote
    result = _run_git(repo_root, ['fetch', remote, '--prune'])
    if result.returncode != 0:
        return []

    # List remote branches for this package
    pattern = f'{remote}/reviews/{package_id}/*'
    result = _run_git(repo_root, ['branch', '-r', '--list', pattern])
    if result.returncode != 0:
        return []

    branches = []
    for line in result.stdout.strip().split('\n'):
        branch = line.strip()
        if branch:
            branches.append(branch)

    return branches


def merge_package_review_data(repo_root: Path, package_id: str) -> Dict[str, Any]:
    """
    Read .reviews/ data from all package branches and merge into consolidated view.

    This function:
    1. Finds all branches for the package
    2. For each branch, reads .reviews/ data
    3. Merges threads and flags from all contributors

    Args:
        repo_root: Repository root path
        package_id: Package identifier

    Returns:
        Dict with keys:
            - threads: {req_id: [merged_threads]}
            - flags: {req_id: review_flag_dict}
            - contributors: [list of usernames]
    """
    result = {
        'threads': {},
        'flags': {},
        'contributors': []
    }

    # Get all contributors for this package
    contributors = get_package_contributors(repo_root, package_id)
    result['contributors'] = contributors

    if not contributors:
        return result

    # Get all branches for this package
    branches = list_package_branches(repo_root, package_id)

    # Collect data from each branch
    for branch in branches:
        parsed = parse_review_branch_name(branch)
        if not parsed:
            continue

        user = parsed[1]

        # Read review data from this branch
        branch_data = _read_branch_review_data(repo_root, branch)

        # Merge threads
        for req_id, threads in branch_data.get('threads', {}).items():
            if req_id not in result['threads']:
                result['threads'][req_id] = []
            result['threads'][req_id].extend(threads)

        # Merge flags (last write wins for now)
        for req_id, flag in branch_data.get('flags', {}).items():
            if req_id not in result['flags']:
                result['flags'][req_id] = flag
            else:
                # Take the more recently flagged one
                existing = result['flags'][req_id]
                if flag.get('flaggedAt', '') > existing.get('flaggedAt', ''):
                    result['flags'][req_id] = flag

    # Deduplicate threads by threadId
    for req_id in result['threads']:
        seen_ids = set()
        unique_threads = []
        for thread in result['threads'][req_id]:
            tid = thread.get('threadId') if isinstance(thread, dict) else thread.threadId
            if tid not in seen_ids:
                seen_ids.add(tid)
                unique_threads.append(thread)
        result['threads'][req_id] = unique_threads

    return result


def _read_branch_review_data(repo_root: Path, branch: str) -> Dict[str, Any]:
    """
    Read review data from a specific branch.

    Uses git show to read files without checking out the branch.

    Args:
        repo_root: Repository root path
        branch: Branch name to read from

    Returns:
        Dict with threads and flags data
    """
    data = {'threads': {}, 'flags': {}}

    # List all req directories in .reviews/reqs/ on this branch
    result = _run_git(repo_root, ['ls-tree', '-d', '--name-only', f'{branch}:.reviews/reqs'])
    if result.returncode != 0:
        return data

    req_ids = [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]

    for req_id in req_ids:
        # Read threads.json
        threads_result = _run_git(
            repo_root,
            ['show', f'{branch}:.reviews/reqs/{req_id}/threads.json']
        )
        if threads_result.returncode == 0 and threads_result.stdout.strip():
            try:
                threads_data = json.loads(threads_result.stdout)
                if 'threads' in threads_data:
                    data['threads'][req_id] = threads_data['threads']
            except json.JSONDecodeError:
                pass

        # Read review-flag.json
        flag_result = _run_git(
            repo_root,
            ['show', f'{branch}:.reviews/reqs/{req_id}/review-flag.json']
        )
        if flag_result.returncode == 0 and flag_result.stdout.strip():
            try:
                flag_data = json.loads(flag_result.stdout)
                if flag_data.get('flaggedForReview'):
                    data['flags'][req_id] = flag_data
            except json.JSONDecodeError:
                pass

    return data
