"""
Review module for trace_view.

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00010: Review Data Models
    REQ-tv-d00011: Review Storage Operations
    REQ-tv-d00012: Position Resolution
    REQ-tv-d00013: Git Branch Management
    REQ-tv-d00014: Review API Server
    REQ-tv-d00015: Status Modifier
"""

from .models import (
    # Enums
    PositionType,
    RequestState,
    ApprovalDecision,
    # Dataclasses
    CommentPosition,
    Comment,
    Thread,
    ReviewFlag,
    StatusRequest,
    Approval,
    ReviewSession,
    ReviewConfig,
    ReviewPackage,
    # Container classes
    ThreadsFile,
    StatusFile,
    PackagesFile,
    # Constants
    VALID_REQ_STATUSES,
    DEFAULT_APPROVAL_RULES,
    # Utility functions
    generate_uuid,
    now_iso,
    parse_iso_datetime,
    validate_req_id,
    validate_hash,
)

from .position import (
    # Enums
    ResolutionConfidence,
    # Dataclasses
    ResolvedPosition,
    # Core resolution function
    resolve_position,
    # Helper functions
    find_line_in_text,
    find_context_in_text,
    find_keyword_occurrence,
    get_line_number_from_char_offset,
    get_line_range_from_char_range,
    get_total_lines,
)

from .storage import (
    # Helper functions
    atomic_write_json,
    read_json,
    normalize_req_id,
    # Path functions
    get_reviews_root,
    get_req_dir,
    get_threads_path,
    get_status_path,
    get_review_flag_path,
    get_config_path,
    get_packages_path,
    # Thread operations
    load_threads,
    save_threads,
    add_thread,
    add_comment_to_thread,
    resolve_thread,
    unresolve_thread,
    # Status request operations
    load_status_requests,
    save_status_requests,
    create_status_request,
    add_approval,
    mark_request_applied,
    # Review flag operations
    load_review_flag,
    save_review_flag,
    # Package operations
    load_packages,
    save_packages,
    create_package,
    update_package,
    delete_package,
    add_req_to_package,
    remove_req_from_package,
    # Config operations
    load_config,
    save_config,
    # Merge operations
    merge_threads,
    merge_status_files,
    merge_review_flags,
)

from .branches import (
    # Constants
    REVIEW_BRANCH_PREFIX,
    # Branch naming
    get_review_branch_name,
    parse_review_branch_name,
    is_review_branch,
    # Git utilities
    get_current_branch,
    get_current_package_context,
    branch_exists,
    remote_branch_exists,
    get_remote_name,
    # Branch discovery
    list_package_branches,
    list_local_review_branches,
    # Branch operations
    create_review_branch,
    checkout_review_branch,
    # Change detection
    has_uncommitted_changes,
    has_reviews_changes,
    has_conflicts,
    # Commit and push
    commit_reviews,
    commit_and_push_reviews,
    # Fetch operations
    fetch_package_branches,
    fetch_review_branches,
)

from .status import (
    # Constants
    VALID_STATUSES,
    # Dataclass
    ReqLocation,
    # Core functions
    find_req_in_file,
    find_req_in_spec_dir,
    get_req_status,
    change_req_status,
    # Hash functions
    compute_req_hash,
    update_req_hash,
)

__all__ = [
    # Enums
    'PositionType',
    'RequestState',
    'ApprovalDecision',
    'ResolutionConfidence',
    # Dataclasses
    'CommentPosition',
    'Comment',
    'Thread',
    'ReviewFlag',
    'StatusRequest',
    'Approval',
    'ReviewSession',
    'ReviewConfig',
    'ReviewPackage',
    'ResolvedPosition',
    # Container classes
    'ThreadsFile',
    'StatusFile',
    'PackagesFile',
    # Constants
    'VALID_REQ_STATUSES',
    'DEFAULT_APPROVAL_RULES',
    'REVIEW_BRANCH_PREFIX',
    # Utility functions (models)
    'generate_uuid',
    'now_iso',
    'parse_iso_datetime',
    'validate_req_id',
    'validate_hash',
    # Position resolution
    'resolve_position',
    'find_line_in_text',
    'find_context_in_text',
    'find_keyword_occurrence',
    'get_line_number_from_char_offset',
    'get_line_range_from_char_range',
    'get_total_lines',
    # Storage helper functions
    'atomic_write_json',
    'read_json',
    'normalize_req_id',
    # Path functions
    'get_reviews_root',
    'get_req_dir',
    'get_threads_path',
    'get_status_path',
    'get_review_flag_path',
    'get_config_path',
    'get_packages_path',
    # Thread operations
    'load_threads',
    'save_threads',
    'add_thread',
    'add_comment_to_thread',
    'resolve_thread',
    'unresolve_thread',
    # Status request operations
    'load_status_requests',
    'save_status_requests',
    'create_status_request',
    'add_approval',
    'mark_request_applied',
    # Review flag operations
    'load_review_flag',
    'save_review_flag',
    # Package operations
    'load_packages',
    'save_packages',
    'create_package',
    'update_package',
    'delete_package',
    'add_req_to_package',
    'remove_req_from_package',
    # Config operations
    'load_config',
    'save_config',
    # Merge operations
    'merge_threads',
    'merge_status_files',
    'merge_review_flags',
    # Branch naming (REQ-tv-d00013)
    'get_review_branch_name',
    'parse_review_branch_name',
    'is_review_branch',
    # Git utilities
    'get_current_branch',
    'get_current_package_context',
    'branch_exists',
    'remote_branch_exists',
    'get_remote_name',
    # Branch discovery
    'list_package_branches',
    'list_local_review_branches',
    # Branch operations
    'create_review_branch',
    'checkout_review_branch',
    # Change detection
    'has_uncommitted_changes',
    'has_reviews_changes',
    'has_conflicts',
    # Commit and push
    'commit_reviews',
    'commit_and_push_reviews',
    # Fetch operations
    'fetch_package_branches',
    'fetch_review_branches',
    # Status modifier (REQ-tv-d00015)
    'VALID_STATUSES',
    'ReqLocation',
    'find_req_in_file',
    'find_req_in_spec_dir',
    'get_req_status',
    'change_req_status',
    'compute_req_hash',
    'update_req_hash',
]
