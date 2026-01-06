#!/usr/bin/env python3
"""
Review Storage Operations Module for trace_view

CRUD operations for the review system:
- Config operations (load/save)
- Review flag operations (load/save)
- Thread operations (load/save/add/resolve/unresolve)
- Status request operations (load/save/create/approve/apply)
- Package operations (load/save/create/update/delete)
- Merge operations for combining multiple user branches

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00011: Review Storage Operations
"""

import json
import os
import re
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional

from .models import (
    ReviewConfig,
    ReviewFlag,
    Thread,
    Comment,
    ThreadsFile,
    StatusFile,
    StatusRequest,
    Approval,
    ReviewPackage,
    PackagesFile,
    parse_iso_datetime,
)


# =============================================================================
# Helper Functions
# REQ-tv-d00011-A: Atomic write operations
# =============================================================================

def atomic_write_json(path: Path, data: Dict[str, Any]) -> None:
    """
    Atomically write JSON data to a file.

    REQ-tv-d00011-A: Uses temp file + rename pattern to ensure file is either
    fully written or not changed at all.

    Args:
        path: Target file path
        data: JSON-serializable dictionary
    """
    # Ensure parent directories exist
    path.parent.mkdir(parents=True, exist_ok=True)

    # Write to temp file in same directory (for atomic rename)
    fd, temp_path = tempfile.mkstemp(
        suffix='.json',
        prefix='.tmp_',
        dir=path.parent
    )
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(data, f, indent=2)
        # Atomic rename
        os.rename(temp_path, path)
    except Exception:
        # Clean up temp file on failure
        if os.path.exists(temp_path):
            os.unlink(temp_path)
        raise


def read_json(path: Path) -> Dict[str, Any]:
    """
    Read JSON file and return dictionary.

    Args:
        path: Path to JSON file

    Returns:
        Parsed JSON as dictionary

    Raises:
        FileNotFoundError: If file doesn't exist
        json.JSONDecodeError: If file contains invalid JSON
    """
    with open(path, 'r') as f:
        return json.load(f)


# =============================================================================
# Path Functions
# REQ-tv-d00011-H: Storage paths convention
# REQ-tv-d00011-I: Requirement ID normalization
# =============================================================================

def normalize_req_id(req_id: str) -> str:
    """
    Normalize requirement ID for use in file paths.

    REQ-tv-d00011-I: Replace colons and slashes with underscores.

    Args:
        req_id: Original requirement ID

    Returns:
        Normalized requirement ID safe for file paths
    """
    return re.sub(r'[:/]', '_', req_id)


def get_reviews_root(repo_root: Path) -> Path:
    """
    Get the root directory for review storage.

    REQ-tv-d00011-H: Returns .reviews directory.

    Args:
        repo_root: Repository root path

    Returns:
        Path to .reviews directory
    """
    return repo_root / '.reviews'


def get_req_dir(repo_root: Path, req_id: str) -> Path:
    """
    Get the directory for a specific requirement's review data.

    REQ-tv-d00011-H: Returns .reviews/reqs/{normalized-req-id}/

    Args:
        repo_root: Repository root path
        req_id: Requirement ID

    Returns:
        Path to requirement's review directory
    """
    normalized = normalize_req_id(req_id)
    return get_reviews_root(repo_root) / 'reqs' / normalized


def get_threads_path(repo_root: Path, req_id: str) -> Path:
    """
    Get path to threads.json file for a requirement.

    REQ-tv-d00011-H: Returns .reviews/reqs/{normalized-req-id}/threads.json

    Args:
        repo_root: Repository root path
        req_id: Requirement ID

    Returns:
        Path to threads.json
    """
    return get_req_dir(repo_root, req_id) / 'threads.json'


def get_status_path(repo_root: Path, req_id: str) -> Path:
    """
    Get path to status.json file for a requirement.

    REQ-tv-d00011-H: Returns .reviews/reqs/{normalized-req-id}/status.json

    Args:
        repo_root: Repository root path
        req_id: Requirement ID

    Returns:
        Path to status.json
    """
    return get_req_dir(repo_root, req_id) / 'status.json'


def get_review_flag_path(repo_root: Path, req_id: str) -> Path:
    """
    Get path to flag.json file for a requirement.

    REQ-tv-d00011-H: Returns .reviews/reqs/{normalized-req-id}/flag.json

    Args:
        repo_root: Repository root path
        req_id: Requirement ID

    Returns:
        Path to flag.json
    """
    return get_req_dir(repo_root, req_id) / 'flag.json'


def get_config_path(repo_root: Path) -> Path:
    """
    Get path to config.json file.

    REQ-tv-d00011-H: Returns .reviews/config.json

    Args:
        repo_root: Repository root path

    Returns:
        Path to config.json
    """
    return get_reviews_root(repo_root) / 'config.json'


def get_packages_path(repo_root: Path) -> Path:
    """
    Get path to packages.json file.

    REQ-tv-d00011-H: Returns .reviews/packages.json

    Args:
        repo_root: Repository root path

    Returns:
        Path to packages.json
    """
    return get_reviews_root(repo_root) / 'packages.json'


# =============================================================================
# Config Operations
# REQ-tv-d00011-F: Config storage operations
# =============================================================================

def load_config(repo_root: Path) -> ReviewConfig:
    """
    Load review system configuration.

    REQ-tv-d00011-F: Returns default config if file doesn't exist.

    Args:
        repo_root: Repository root path

    Returns:
        ReviewConfig instance
    """
    config_path = get_config_path(repo_root)
    if not config_path.exists():
        return ReviewConfig.default()
    data = read_json(config_path)
    return ReviewConfig.from_dict(data)


def save_config(repo_root: Path, config: ReviewConfig) -> None:
    """
    Save review system configuration.

    REQ-tv-d00011-F: Uses atomic write for safety.

    Args:
        repo_root: Repository root path
        config: ReviewConfig instance to save
    """
    config_path = get_config_path(repo_root)
    atomic_write_json(config_path, config.to_dict())


# =============================================================================
# Review Flag Operations
# REQ-tv-d00011-D: Review flag storage operations
# =============================================================================

def load_review_flag(repo_root: Path, req_id: str) -> ReviewFlag:
    """
    Load review flag for a requirement.

    REQ-tv-d00011-D: Returns cleared flag if file doesn't exist.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID

    Returns:
        ReviewFlag instance
    """
    flag_path = get_review_flag_path(repo_root, req_id)
    if not flag_path.exists():
        return ReviewFlag.cleared()
    data = read_json(flag_path)
    return ReviewFlag.from_dict(data)


def save_review_flag(repo_root: Path, req_id: str, flag: ReviewFlag) -> None:
    """
    Save review flag for a requirement.

    REQ-tv-d00011-D: Uses atomic write for safety.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID
        flag: ReviewFlag instance to save
    """
    flag_path = get_review_flag_path(repo_root, req_id)
    atomic_write_json(flag_path, flag.to_dict())


# =============================================================================
# Thread Operations
# REQ-tv-d00011-B: Thread storage operations
# =============================================================================

def load_threads(repo_root: Path, req_id: str) -> ThreadsFile:
    """
    Load threads for a requirement.

    REQ-tv-d00011-B: Returns empty threads file if doesn't exist.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID

    Returns:
        ThreadsFile instance
    """
    normalized_id = normalize_req_id(req_id)
    threads_path = get_threads_path(repo_root, req_id)
    if not threads_path.exists():
        return ThreadsFile(reqId=normalized_id, threads=[])
    data = read_json(threads_path)
    return ThreadsFile.from_dict(data)


def save_threads(repo_root: Path, req_id: str, threads_file: ThreadsFile) -> None:
    """
    Save threads file for a requirement.

    REQ-tv-d00011-B: Uses atomic write for safety.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID
        threads_file: ThreadsFile instance to save
    """
    threads_path = get_threads_path(repo_root, req_id)
    atomic_write_json(threads_path, threads_file.to_dict())


def add_thread(repo_root: Path, req_id: str, thread: Thread) -> Thread:
    """
    Add a new thread to a requirement.

    REQ-tv-d00011-B: Creates file if needed and appends thread.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID
        thread: Thread to add

    Returns:
        The added thread
    """
    threads_file = load_threads(repo_root, req_id)
    threads_file.threads.append(thread)
    save_threads(repo_root, req_id, threads_file)
    return thread


def add_comment_to_thread(
    repo_root: Path,
    req_id: str,
    thread_id: str,
    author: str,
    body: str
) -> Comment:
    """
    Add a comment to an existing thread.

    REQ-tv-d00011-B: Persists comment and returns it.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID
        thread_id: Thread UUID
        author: Comment author username
        body: Comment body text

    Returns:
        The created comment

    Raises:
        ValueError: If thread not found
    """
    threads_file = load_threads(repo_root, req_id)

    # Find the thread
    thread = None
    for t in threads_file.threads:
        if t.threadId == thread_id:
            thread = t
            break

    if thread is None:
        raise ValueError(f"Thread not found: {thread_id}")

    comment = thread.add_comment(author, body)
    save_threads(repo_root, req_id, threads_file)
    return comment


def resolve_thread(
    repo_root: Path,
    req_id: str,
    thread_id: str,
    user: str
) -> bool:
    """
    Mark a thread as resolved.

    REQ-tv-d00011-B: Persists resolution state.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID
        thread_id: Thread UUID
        user: Username resolving the thread

    Returns:
        True if resolved, False if thread not found
    """
    threads_file = load_threads(repo_root, req_id)

    for thread in threads_file.threads:
        if thread.threadId == thread_id:
            thread.resolve(user)
            save_threads(repo_root, req_id, threads_file)
            return True

    return False


def unresolve_thread(repo_root: Path, req_id: str, thread_id: str) -> bool:
    """
    Mark a thread as unresolved.

    REQ-tv-d00011-B: Persists unresolved state.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID
        thread_id: Thread UUID

    Returns:
        True if unresolved, False if thread not found
    """
    threads_file = load_threads(repo_root, req_id)

    for thread in threads_file.threads:
        if thread.threadId == thread_id:
            thread.unresolve()
            save_threads(repo_root, req_id, threads_file)
            return True

    return False


# =============================================================================
# Status Request Operations
# REQ-tv-d00011-C: Status request storage operations
# =============================================================================

def load_status_requests(repo_root: Path, req_id: str) -> StatusFile:
    """
    Load status requests for a requirement.

    REQ-tv-d00011-C: Returns empty status file if doesn't exist.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID

    Returns:
        StatusFile instance
    """
    normalized_id = normalize_req_id(req_id)
    status_path = get_status_path(repo_root, req_id)
    if not status_path.exists():
        return StatusFile(reqId=normalized_id, requests=[])
    data = read_json(status_path)
    return StatusFile.from_dict(data)


def save_status_requests(repo_root: Path, req_id: str, status_file: StatusFile) -> None:
    """
    Save status requests file for a requirement.

    REQ-tv-d00011-C: Uses atomic write for safety.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID
        status_file: StatusFile instance to save
    """
    status_path = get_status_path(repo_root, req_id)
    atomic_write_json(status_path, status_file.to_dict())


def create_status_request(
    repo_root: Path,
    req_id: str,
    request: StatusRequest
) -> StatusRequest:
    """
    Create a new status change request.

    REQ-tv-d00011-C: Persists request and returns it.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID
        request: StatusRequest to create

    Returns:
        The created request
    """
    status_file = load_status_requests(repo_root, req_id)
    status_file.requests.append(request)
    save_status_requests(repo_root, req_id, status_file)
    return request


def add_approval(
    repo_root: Path,
    req_id: str,
    request_id: str,
    user: str,
    decision: str,
    comment: Optional[str] = None
) -> Approval:
    """
    Add an approval to a status request.

    REQ-tv-d00011-C: Persists approval and returns it.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID
        request_id: Request UUID
        user: Approving user
        decision: "approve" or "reject"
        comment: Optional comment

    Returns:
        The created approval

    Raises:
        ValueError: If request not found
    """
    status_file = load_status_requests(repo_root, req_id)

    # Find the request
    request = None
    for r in status_file.requests:
        if r.requestId == request_id:
            request = r
            break

    if request is None:
        raise ValueError(f"Status request not found: {request_id}")

    approval = request.add_approval(user, decision, comment)
    save_status_requests(repo_root, req_id, status_file)
    return approval


def mark_request_applied(repo_root: Path, req_id: str, request_id: str) -> bool:
    """
    Mark a status request as applied.

    REQ-tv-d00011-C: Persists applied state.

    Args:
        repo_root: Repository root path
        req_id: Requirement ID
        request_id: Request UUID

    Returns:
        True if marked applied, False if not found

    Raises:
        ValueError: If request is not in approved state
    """
    status_file = load_status_requests(repo_root, req_id)

    for request in status_file.requests:
        if request.requestId == request_id:
            request.mark_applied()  # This raises ValueError if not approved
            save_status_requests(repo_root, req_id, status_file)
            return True

    return False


# =============================================================================
# Package Operations
# REQ-tv-d00011-E: Package storage operations
# =============================================================================

def load_packages(repo_root: Path) -> PackagesFile:
    """
    Load packages file.

    REQ-tv-d00011-E: Returns file with default package if doesn't exist.

    Args:
        repo_root: Repository root path

    Returns:
        PackagesFile instance
    """
    packages_path = get_packages_path(repo_root)
    if not packages_path.exists():
        # Create default package
        default_pkg = ReviewPackage.create_default()
        return PackagesFile(packages=[default_pkg])
    data = read_json(packages_path)
    packages_file = PackagesFile.from_dict(data)

    # Ensure default package exists
    if packages_file.get_default() is None:
        default_pkg = ReviewPackage.create_default()
        packages_file.packages.insert(0, default_pkg)

    return packages_file


def save_packages(repo_root: Path, packages_file: PackagesFile) -> None:
    """
    Save packages file.

    REQ-tv-d00011-E: Uses atomic write for safety.

    Args:
        repo_root: Repository root path
        packages_file: PackagesFile instance to save
    """
    packages_path = get_packages_path(repo_root)
    atomic_write_json(packages_path, packages_file.to_dict())


def create_package(repo_root: Path, package: ReviewPackage) -> ReviewPackage:
    """
    Create a new package.

    REQ-tv-d00011-E: Persists package and returns it.

    Args:
        repo_root: Repository root path
        package: ReviewPackage to create

    Returns:
        The created package
    """
    packages_file = load_packages(repo_root)
    packages_file.packages.append(package)
    save_packages(repo_root, packages_file)
    return package


def update_package(repo_root: Path, package: ReviewPackage) -> bool:
    """
    Update an existing package.

    REQ-tv-d00011-E: Persists updated package.

    Args:
        repo_root: Repository root path
        package: ReviewPackage with updated data

    Returns:
        True if updated, False if package not found
    """
    packages_file = load_packages(repo_root)

    for i, p in enumerate(packages_file.packages):
        if p.packageId == package.packageId:
            packages_file.packages[i] = package
            save_packages(repo_root, packages_file)
            return True

    return False


def delete_package(repo_root: Path, package_id: str) -> bool:
    """
    Delete a package by ID.

    REQ-tv-d00011-E: Removes package and persists change.

    Args:
        repo_root: Repository root path
        package_id: Package UUID

    Returns:
        True if deleted, False if package not found
    """
    packages_file = load_packages(repo_root)

    for i, p in enumerate(packages_file.packages):
        if p.packageId == package_id:
            del packages_file.packages[i]
            save_packages(repo_root, packages_file)
            return True

    return False


def add_req_to_package(repo_root: Path, package_id: str, req_id: str) -> bool:
    """
    Add a requirement ID to a package.

    REQ-tv-d00011-E: Prevents duplicates.

    Args:
        repo_root: Repository root path
        package_id: Package UUID
        req_id: Requirement ID to add

    Returns:
        True if added, False if package not found
    """
    packages_file = load_packages(repo_root)

    for package in packages_file.packages:
        if package.packageId == package_id:
            if req_id not in package.reqIds:
                package.reqIds.append(req_id)
            save_packages(repo_root, packages_file)
            return True

    return False


def remove_req_from_package(repo_root: Path, package_id: str, req_id: str) -> bool:
    """
    Remove a requirement ID from a package.

    REQ-tv-d00011-E: Persists change.

    Args:
        repo_root: Repository root path
        package_id: Package UUID
        req_id: Requirement ID to remove

    Returns:
        True if removed, False if package not found
    """
    packages_file = load_packages(repo_root)

    for package in packages_file.packages:
        if package.packageId == package_id:
            if req_id in package.reqIds:
                package.reqIds.remove(req_id)
            save_packages(repo_root, packages_file)
            return True

    return False


# =============================================================================
# Merge Operations
# REQ-tv-d00011-G: Merge operations
# REQ-tv-d00011-J: Deduplication and timestamp-based conflict resolution
# =============================================================================

def merge_threads(local: ThreadsFile, remote: ThreadsFile) -> ThreadsFile:
    """
    Merge thread files from local and remote.

    REQ-tv-d00011-G: Combines data from multiple user branches.
    REQ-tv-d00011-J: Deduplicates by ID and uses timestamp-based conflict resolution.

    Strategy:
    - Unique threads (by threadId) are combined
    - Matching threads merge their comments (by comment id)
    - Resolution state: if either is resolved, keep resolved

    Args:
        local: Local threads file
        remote: Remote threads file

    Returns:
        Merged ThreadsFile
    """
    # Build map of local threads by ID
    local_map: Dict[str, Thread] = {t.threadId: t for t in local.threads}

    merged_threads: List[Thread] = []

    # Process all remote threads
    for remote_thread in remote.threads:
        if remote_thread.threadId in local_map:
            # Merge the threads
            local_thread = local_map.pop(remote_thread.threadId)
            merged_thread = _merge_single_thread(local_thread, remote_thread)
            merged_threads.append(merged_thread)
        else:
            # Only in remote
            merged_threads.append(remote_thread)

    # Add remaining local-only threads
    for local_thread in local_map.values():
        merged_threads.append(local_thread)

    return ThreadsFile(reqId=local.reqId, threads=merged_threads)


def _merge_single_thread(local: Thread, remote: Thread) -> Thread:
    """
    Merge two versions of the same thread.

    REQ-tv-d00011-J: Deduplicates comments by ID and sorts by timestamp.
    """
    # Merge comments by ID
    local_comment_map = {c.id: c for c in local.comments}
    remote_comment_map = {c.id: c for c in remote.comments}

    all_comment_ids = set(local_comment_map.keys()) | set(remote_comment_map.keys())
    merged_comments = []

    for comment_id in all_comment_ids:
        if comment_id in local_comment_map:
            merged_comments.append(local_comment_map[comment_id])
        else:
            merged_comments.append(remote_comment_map[comment_id])

    # Sort comments by timestamp
    merged_comments.sort(key=lambda c: parse_iso_datetime(c.timestamp))

    # Resolution: if either resolved, keep resolved (prefer whichever has the state)
    resolved = local.resolved or remote.resolved
    resolved_by = remote.resolvedBy if remote.resolved else local.resolvedBy
    resolved_at = remote.resolvedAt if remote.resolved else local.resolvedAt

    return Thread(
        threadId=local.threadId,
        reqId=local.reqId,
        createdBy=local.createdBy,
        createdAt=local.createdAt,
        position=local.position,  # Use local position
        resolved=resolved,
        resolvedBy=resolved_by,
        resolvedAt=resolved_at,
        comments=merged_comments
    )


def merge_status_files(local: StatusFile, remote: StatusFile) -> StatusFile:
    """
    Merge status files from local and remote.

    REQ-tv-d00011-G: Combines data from multiple user branches.
    REQ-tv-d00011-J: Deduplicates by ID and uses timestamp-based conflict resolution.

    Strategy:
    - Unique requests (by requestId) are combined
    - Matching requests merge their approvals
    - State is recalculated based on merged approvals

    Args:
        local: Local status file
        remote: Remote status file

    Returns:
        Merged StatusFile
    """
    # Build map of local requests by ID
    local_map: Dict[str, StatusRequest] = {r.requestId: r for r in local.requests}

    merged_requests: List[StatusRequest] = []

    # Process all remote requests
    for remote_request in remote.requests:
        if remote_request.requestId in local_map:
            # Merge the requests
            local_request = local_map.pop(remote_request.requestId)
            merged_request = _merge_single_request(local_request, remote_request)
            merged_requests.append(merged_request)
        else:
            # Only in remote
            merged_requests.append(remote_request)

    # Add remaining local-only requests
    for local_request in local_map.values():
        merged_requests.append(local_request)

    return StatusFile(reqId=local.reqId, requests=merged_requests)


def _merge_single_request(local: StatusRequest, remote: StatusRequest) -> StatusRequest:
    """
    Merge two versions of the same status request.

    REQ-tv-d00011-J: Uses timestamp-based conflict resolution for approvals.
    """
    # Merge approvals by user (later approval wins)
    local_approval_map = {a.user: a for a in local.approvals}
    remote_approval_map = {a.user: a for a in remote.approvals}

    all_users = set(local_approval_map.keys()) | set(remote_approval_map.keys())
    merged_approvals = []

    for user in all_users:
        local_approval = local_approval_map.get(user)
        remote_approval = remote_approval_map.get(user)

        if local_approval and remote_approval:
            # Take the later one (timestamp-based conflict resolution)
            local_time = parse_iso_datetime(local_approval.at)
            remote_time = parse_iso_datetime(remote_approval.at)
            if remote_time >= local_time:
                merged_approvals.append(remote_approval)
            else:
                merged_approvals.append(local_approval)
        elif local_approval:
            merged_approvals.append(local_approval)
        else:
            merged_approvals.append(remote_approval)

    # Create merged request
    merged = StatusRequest(
        requestId=local.requestId,
        reqId=local.reqId,
        type=local.type,
        fromStatus=local.fromStatus,
        toStatus=local.toStatus,
        requestedBy=local.requestedBy,
        requestedAt=local.requestedAt,
        justification=local.justification,
        approvals=merged_approvals,
        requiredApprovers=local.requiredApprovers,
        state=local.state  # Will be recalculated
    )

    # Recalculate state based on merged approvals
    merged._update_state()

    return merged


def merge_review_flags(local: ReviewFlag, remote: ReviewFlag) -> ReviewFlag:
    """
    Merge review flags from local and remote.

    REQ-tv-d00011-G: Combines data from multiple user branches.
    REQ-tv-d00011-J: Uses timestamp-based conflict resolution.

    Strategy:
    - If neither flagged, return unflagged
    - If only one flagged, return that one
    - If both flagged, take newer flag but merge scopes

    Args:
        local: Local review flag
        remote: Remote review flag

    Returns:
        Merged ReviewFlag
    """
    # Neither flagged
    if not local.flaggedForReview and not remote.flaggedForReview:
        return ReviewFlag.cleared()

    # Only one flagged
    if not local.flaggedForReview:
        return remote
    if not remote.flaggedForReview:
        return local

    # Both flagged - take newer but merge scopes
    local_time = parse_iso_datetime(local.flaggedAt)
    remote_time = parse_iso_datetime(remote.flaggedAt)

    # Merge scopes (unique values)
    merged_scope = list(set(local.scope) | set(remote.scope))

    if remote_time >= local_time:
        # Remote is newer
        return ReviewFlag(
            flaggedForReview=True,
            flaggedBy=remote.flaggedBy,
            flaggedAt=remote.flaggedAt,
            reason=remote.reason,
            scope=merged_scope
        )
    else:
        # Local is newer
        return ReviewFlag(
            flaggedForReview=True,
            flaggedBy=local.flaggedBy,
            flaggedAt=local.flaggedAt,
            reason=local.reason,
            scope=merged_scope
        )
