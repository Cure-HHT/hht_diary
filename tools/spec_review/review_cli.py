#!/usr/bin/env python3
"""
Spec Review CLI Interface

Command-line interface for the spec review system:
- Session management: init-session, list-sessions, delete-session
- Review flags: flag, unflag
- Comments: comment, reply, resolve, unresolve, list-threads
- Status requests: request-status, approve, reject, list-requests
- Branches: create-branch, checkout-branch, push, fetch, list-branches

IMPLEMENTS REQUIREMENTS:
    REQ-d00086: Spec Review Data Model
"""

import argparse
import json
import sys
from pathlib import Path
from typing import List, Optional

from tools.spec_review.review_data import (
    ReviewSession,
    ReviewFlag,
    Thread,
    StatusRequest,
    CommentPosition,
)
from tools.spec_review.review_storage import (
    create_session,
    load_session,
    list_sessions,
    delete_session as storage_delete_session,
    load_review_flag,
    save_review_flag,
    load_threads,
    add_thread,
    add_comment_to_thread,
    resolve_thread as storage_resolve_thread,
    unresolve_thread as storage_unresolve_thread,
    load_status_requests,
    create_status_request as storage_create_status_request,
    add_approval as storage_add_approval,
)
from tools.spec_review.review_branches import (
    create_review_branch,
    checkout_review_branch,
    push_review_branch,
    fetch_review_branches,
    list_local_review_branches,
    has_uncommitted_changes,
    get_current_branch,
)


# =============================================================================
# Parser Creation
# =============================================================================

def create_parser() -> argparse.ArgumentParser:
    """Create the CLI argument parser"""
    parser = argparse.ArgumentParser(
        prog='review-cli',
        description='Spec Review System CLI'
    )

    parser.add_argument(
        '--repo',
        type=str,
        default='.',
        help='Repository root path (default: current directory)'
    )

    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # --- Session commands ---
    init_session = subparsers.add_parser('init-session', help='Create a new review session')
    init_session.add_argument('--user', required=True, help='Username')
    init_session.add_argument('--name', required=True, help='Session name')
    init_session.add_argument('--description', help='Session description')

    list_sessions_cmd = subparsers.add_parser('list-sessions', help='List all sessions')
    list_sessions_cmd.add_argument('--format', choices=['summary', 'json'], default='summary')

    delete_session_cmd = subparsers.add_parser('delete-session', help='Delete a session')
    delete_session_cmd.add_argument('session_id', help='Session ID to delete')

    # --- Flag commands ---
    flag_cmd = subparsers.add_parser('flag', help='Flag a requirement for review')
    flag_cmd.add_argument('req_id', help='Requirement ID')
    flag_cmd.add_argument('--user', required=True, help='Username')
    flag_cmd.add_argument('--reason', required=True, help='Reason for flagging')
    flag_cmd.add_argument('--scope', nargs='*', default=['all'], help='Review scope')

    unflag_cmd = subparsers.add_parser('unflag', help='Clear review flag')
    unflag_cmd.add_argument('req_id', help='Requirement ID')

    # --- Comment commands ---
    comment_cmd = subparsers.add_parser('comment', help='Add a comment (creates new thread)')
    comment_cmd.add_argument('req_id', help='Requirement ID')
    comment_cmd.add_argument('--user', required=True, help='Username')
    comment_cmd.add_argument('--body', required=True, help='Comment text')
    comment_cmd.add_argument('--hash', dest='hash', required=True, help='REQ hash when commenting')
    comment_cmd.add_argument('--line', type=int, help='Line number')
    comment_cmd.add_argument('--block-start', type=int, help='Block start line')
    comment_cmd.add_argument('--block-end', type=int, help='Block end line')
    comment_cmd.add_argument('--keyword', help='Keyword to anchor to')
    comment_cmd.add_argument('--keyword-occurrence', type=int, default=1)

    reply_cmd = subparsers.add_parser('reply', help='Reply to an existing thread')
    reply_cmd.add_argument('thread_id', help='Thread ID to reply to')
    reply_cmd.add_argument('--req', required=True, help='Requirement ID')
    reply_cmd.add_argument('--user', required=True, help='Username')
    reply_cmd.add_argument('--body', required=True, help='Reply text')

    resolve_cmd = subparsers.add_parser('resolve', help='Mark thread as resolved')
    resolve_cmd.add_argument('thread_id', help='Thread ID')
    resolve_cmd.add_argument('--req', required=True, help='Requirement ID')
    resolve_cmd.add_argument('--user', required=True, help='Username')

    unresolve_cmd = subparsers.add_parser('unresolve', help='Mark thread as unresolved')
    unresolve_cmd.add_argument('thread_id', help='Thread ID')
    unresolve_cmd.add_argument('--req', required=True, help='Requirement ID')

    list_threads_cmd = subparsers.add_parser('list-threads', help='List threads for a REQ')
    list_threads_cmd.add_argument('req_id', help='Requirement ID')
    list_threads_cmd.add_argument('--format', choices=['summary', 'json'], default='summary')

    # --- Status request commands ---
    request_status_cmd = subparsers.add_parser('request-status', help='Request status change')
    request_status_cmd.add_argument('req_id', help='Requirement ID')
    request_status_cmd.add_argument('--user', required=True, help='Username')
    request_status_cmd.add_argument('--from', dest='from_status', required=True,
                                    choices=['Draft', 'Active', 'Deprecated'])
    request_status_cmd.add_argument('--to', required=True,
                                    choices=['Draft', 'Active', 'Deprecated'])
    request_status_cmd.add_argument('--justification', required=True, help='Justification')
    request_status_cmd.add_argument('--approvers', nargs='*', help='Required approvers')

    approve_cmd = subparsers.add_parser('approve', help='Approve a status request')
    approve_cmd.add_argument('request_id', help='Request ID')
    approve_cmd.add_argument('--req', required=True, help='Requirement ID')
    approve_cmd.add_argument('--user', required=True, help='Username')
    approve_cmd.add_argument('--comment', help='Optional comment')

    reject_cmd = subparsers.add_parser('reject', help='Reject a status request')
    reject_cmd.add_argument('request_id', help='Request ID')
    reject_cmd.add_argument('--req', required=True, help='Requirement ID')
    reject_cmd.add_argument('--user', required=True, help='Username')
    reject_cmd.add_argument('--comment', help='Optional comment')

    list_requests_cmd = subparsers.add_parser('list-requests', help='List status requests')
    list_requests_cmd.add_argument('req_id', help='Requirement ID')
    list_requests_cmd.add_argument('--format', choices=['summary', 'json'], default='summary')

    # --- Branch commands ---
    create_branch_cmd = subparsers.add_parser('create-branch', help='Create review branch')
    create_branch_cmd.add_argument('--user', required=True, help='Username')
    create_branch_cmd.add_argument('--session', required=True, help='Session name')

    checkout_branch_cmd = subparsers.add_parser('checkout-branch', help='Checkout review branch')
    checkout_branch_cmd.add_argument('--user', required=True, help='Username')
    checkout_branch_cmd.add_argument('--session', required=True, help='Session name')

    push_cmd = subparsers.add_parser('push', help='Push review branch to remote')
    push_cmd.add_argument('--user', required=True, help='Username')
    push_cmd.add_argument('--session', required=True, help='Session name')

    fetch_cmd = subparsers.add_parser('fetch', help='Fetch review branches from remote')

    list_branches_cmd = subparsers.add_parser('list-branches', help='List review branches')
    list_branches_cmd.add_argument('--user', help='Filter by user')
    list_branches_cmd.add_argument('--format', choices=['summary', 'json'], default='summary')

    return parser


# =============================================================================
# Command Handlers - Sessions
# =============================================================================

def cmd_init_session(
    repo_root: Path,
    user: str,
    name: str,
    description: Optional[str]
) -> int:
    """Handle init-session command"""
    session = ReviewSession.create(user, name, description)
    create_session(repo_root, session)
    print(f"Created session: {session.sessionId}")
    print(f"  Name: {name}")
    print(f"  User: {user}")
    return 0


def cmd_list_sessions(repo_root: Path, format: str) -> int:
    """Handle list-sessions command"""
    sessions = list_sessions(repo_root)

    if not sessions:
        print("No sessions found.")
        return 0

    if format == 'json':
        print(json.dumps([s.to_dict() for s in sessions], indent=2))
    else:
        print(f"Found {len(sessions)} session(s):\n")
        for s in sessions:
            print(f"  [{s.sessionId[:8]}...] {s.name}")
            print(f"    User: {s.user}, Created: {s.createdAt}")
            if s.description:
                print(f"    Description: {s.description}")
            print()

    return 0


def cmd_delete_session(repo_root: Path, session_id: str) -> int:
    """Handle delete-session command"""
    if storage_delete_session(repo_root, session_id):
        print(f"Deleted session: {session_id}")
        return 0
    else:
        print(f"Session not found: {session_id}")
        return 1


# =============================================================================
# Command Handlers - Flags
# =============================================================================

def cmd_flag(
    repo_root: Path,
    req_id: str,
    user: str,
    reason: str,
    scope: List[str]
) -> int:
    """Handle flag command"""
    flag = ReviewFlag.create(user, reason, scope)
    save_review_flag(repo_root, req_id, flag)
    print(f"Flagged {req_id} for review")
    print(f"  Reason: {reason}")
    print(f"  Scope: {', '.join(scope)}")
    return 0


def cmd_unflag(repo_root: Path, req_id: str) -> int:
    """Handle unflag command"""
    flag = ReviewFlag.cleared()
    save_review_flag(repo_root, req_id, flag)
    print(f"Cleared review flag for {req_id}")
    return 0


# =============================================================================
# Command Handlers - Comments
# =============================================================================

def cmd_comment(
    repo_root: Path,
    req_id: str,
    user: str,
    body: str,
    hash_value: str,
    line: Optional[int] = None,
    block_start: Optional[int] = None,
    block_end: Optional[int] = None,
    keyword: Optional[str] = None,
    keyword_occurrence: int = 1
) -> int:
    """Handle comment command - creates new thread"""
    # Create position based on provided args
    if line is not None:
        position = CommentPosition.create_line(hash_value, line)
    elif block_start is not None and block_end is not None:
        position = CommentPosition.create_block(hash_value, block_start, block_end)
    elif keyword is not None:
        position = CommentPosition.create_word(hash_value, keyword, keyword_occurrence)
    else:
        position = CommentPosition.create_general(hash_value)

    thread = Thread.create(req_id, user, position, body)
    add_thread(repo_root, req_id, thread)

    print(f"Created thread: {thread.threadId}")
    print(f"  REQ: {req_id}")
    print(f"  Position type: {position.type}")
    return 0


def cmd_reply(
    repo_root: Path,
    req_id: str,
    thread_id: str,
    user: str,
    body: str
) -> int:
    """Handle reply command"""
    try:
        comment = add_comment_to_thread(repo_root, req_id, thread_id, user, body)
        print(f"Added reply: {comment.id}")
        return 0
    except ValueError as e:
        print(f"Error: {e}")
        return 1


def cmd_resolve(
    repo_root: Path,
    req_id: str,
    thread_id: str,
    user: str
) -> int:
    """Handle resolve command"""
    if storage_resolve_thread(repo_root, req_id, thread_id, user):
        print(f"Resolved thread: {thread_id}")
        return 0
    else:
        print(f"Thread not found: {thread_id}")
        return 1


def cmd_unresolve(repo_root: Path, req_id: str, thread_id: str) -> int:
    """Handle unresolve command"""
    if storage_unresolve_thread(repo_root, req_id, thread_id):
        print(f"Unresolved thread: {thread_id}")
        return 0
    else:
        print(f"Thread not found: {thread_id}")
        return 1


def cmd_list_threads(repo_root: Path, req_id: str, format: str) -> int:
    """Handle list-threads command"""
    threads_file = load_threads(repo_root, req_id)

    if not threads_file.threads:
        print(f"No threads for {req_id}.")
        return 0

    if format == 'json':
        print(json.dumps([t.to_dict() for t in threads_file.threads], indent=2))
    else:
        print(f"Found {len(threads_file.threads)} thread(s) for {req_id}:\n")
        for t in threads_file.threads:
            status = "[RESOLVED]" if t.resolved else "[OPEN]"
            print(f"  {status} {t.threadId[:8]}...")
            print(f"    Created by: {t.createdBy} at {t.createdAt}")
            print(f"    Position: {t.position.type}")
            print(f"    Comments: {len(t.comments)}")
            if t.comments:
                print(f"    First comment: {t.comments[0].body[:50]}...")
            print()

    return 0


# =============================================================================
# Command Handlers - Status Requests
# =============================================================================

def cmd_request_status(
    repo_root: Path,
    req_id: str,
    user: str,
    from_status: str,
    to_status: str,
    justification: str,
    required_approvers: Optional[List[str]] = None
) -> int:
    """Handle request-status command"""
    request = StatusRequest.create(
        req_id, from_status, to_status, user, justification,
        required_approvers=required_approvers
    )
    storage_create_status_request(repo_root, req_id, request)

    print(f"Created status request: {request.requestId}")
    print(f"  {from_status} -> {to_status}")
    print(f"  Justification: {justification}")
    return 0


def cmd_approve(
    repo_root: Path,
    req_id: str,
    request_id: str,
    user: str,
    comment: Optional[str] = None
) -> int:
    """Handle approve command"""
    try:
        approval = storage_add_approval(repo_root, req_id, request_id, user, 'approve', comment)
        print(f"Approved request: {request_id}")
        if comment:
            print(f"  Comment: {comment}")
        return 0
    except ValueError as e:
        print(f"Error: {e}")
        return 1


def cmd_reject(
    repo_root: Path,
    req_id: str,
    request_id: str,
    user: str,
    comment: Optional[str] = None
) -> int:
    """Handle reject command"""
    try:
        approval = storage_add_approval(repo_root, req_id, request_id, user, 'reject', comment)
        print(f"Rejected request: {request_id}")
        if comment:
            print(f"  Comment: {comment}")
        return 0
    except ValueError as e:
        print(f"Error: {e}")
        return 1


def cmd_list_requests(repo_root: Path, req_id: str, format: str) -> int:
    """Handle list-requests command"""
    status_file = load_status_requests(repo_root, req_id)

    if not status_file.requests:
        print(f"No requests for {req_id}.")
        return 0

    if format == 'json':
        print(json.dumps([r.to_dict() for r in status_file.requests], indent=2))
    else:
        print(f"Found {len(status_file.requests)} request(s) for {req_id}:\n")
        for r in status_file.requests:
            print(f"  [{r.state.upper()}] {r.requestId[:8]}...")
            print(f"    {r.fromStatus} -> {r.toStatus}")
            print(f"    Requested by: {r.requestedBy} at {r.requestedAt}")
            print(f"    Justification: {r.justification}")
            print(f"    Approvals: {len(r.approvals)}/{len(r.requiredApprovers)}")
            print()

    return 0


# =============================================================================
# Command Handlers - Branches
# =============================================================================

def cmd_create_branch(repo_root: Path, user: str, session: str) -> int:
    """Handle create-branch command"""
    try:
        branch_name = create_review_branch(repo_root, user, session)
        print(f"Created branch: {branch_name}")
        return 0
    except ValueError as e:
        print(f"Error: {e}")
        return 1
    except RuntimeError as e:
        print(f"Error: {e}")
        return 1


def cmd_checkout_branch(repo_root: Path, user: str, session: str) -> int:
    """Handle checkout-branch command"""
    if checkout_review_branch(repo_root, user, session):
        print(f"Switched to branch: reviews/{user}/{session}")
        return 0
    else:
        print(f"Branch not found: reviews/{user}/{session}")
        return 1


def cmd_push(repo_root: Path, user: str, session: str) -> int:
    """Handle push command"""
    if push_review_branch(repo_root, user, session):
        print(f"Pushed branch: reviews/{user}/{session}")
        return 0
    else:
        print("Failed to push (no remote configured?)")
        return 1


def cmd_fetch(repo_root: Path) -> int:
    """Handle fetch command"""
    if fetch_review_branches(repo_root):
        print("Fetched review branches from remote")
        return 0
    else:
        print("Failed to fetch (no remote configured?)")
        return 1


def cmd_list_branches(
    repo_root: Path,
    user: Optional[str] = None,
    format: str = 'summary'
) -> int:
    """Handle list-branches command"""
    branches = list_local_review_branches(repo_root, user)

    if not branches:
        print("No review branches found.")
        return 0

    if format == 'json':
        print(json.dumps(branches, indent=2))
    else:
        current = get_current_branch(repo_root)
        print(f"Found {len(branches)} review branch(es):\n")
        for b in branches:
            marker = "* " if b == current else "  "
            print(f"{marker}{b}")

    return 0


# =============================================================================
# Main Entry Point
# =============================================================================

def main(argv: Optional[List[str]] = None) -> int:
    """Main entry point"""
    parser = create_parser()
    args = parser.parse_args(argv)

    if not args.command:
        parser.print_help()
        return 0

    repo_root = Path(args.repo).resolve()

    # Dispatch to command handlers
    if args.command == 'init-session':
        return cmd_init_session(
            repo_root, args.user, args.name, args.description
        )

    elif args.command == 'list-sessions':
        return cmd_list_sessions(repo_root, args.format)

    elif args.command == 'delete-session':
        return cmd_delete_session(repo_root, args.session_id)

    elif args.command == 'flag':
        return cmd_flag(
            repo_root, args.req_id, args.user, args.reason, args.scope
        )

    elif args.command == 'unflag':
        return cmd_unflag(repo_root, args.req_id)

    elif args.command == 'comment':
        return cmd_comment(
            repo_root, args.req_id, args.user, args.body, args.hash,
            line=args.line,
            block_start=getattr(args, 'block_start', None),
            block_end=getattr(args, 'block_end', None),
            keyword=getattr(args, 'keyword', None),
            keyword_occurrence=getattr(args, 'keyword_occurrence', 1)
        )

    elif args.command == 'reply':
        return cmd_reply(
            repo_root, args.req, args.thread_id, args.user, args.body
        )

    elif args.command == 'resolve':
        return cmd_resolve(
            repo_root, args.req, args.thread_id, args.user
        )

    elif args.command == 'unresolve':
        return cmd_unresolve(repo_root, args.req, args.thread_id)

    elif args.command == 'list-threads':
        return cmd_list_threads(repo_root, args.req_id, args.format)

    elif args.command == 'request-status':
        return cmd_request_status(
            repo_root, args.req_id, args.user,
            args.from_status, args.to,
            args.justification,
            required_approvers=args.approvers
        )

    elif args.command == 'approve':
        return cmd_approve(
            repo_root, args.req, args.request_id, args.user, args.comment
        )

    elif args.command == 'reject':
        return cmd_reject(
            repo_root, args.req, args.request_id, args.user, args.comment
        )

    elif args.command == 'list-requests':
        return cmd_list_requests(repo_root, args.req_id, args.format)

    elif args.command == 'create-branch':
        return cmd_create_branch(repo_root, args.user, args.session)

    elif args.command == 'checkout-branch':
        return cmd_checkout_branch(repo_root, args.user, args.session)

    elif args.command == 'push':
        return cmd_push(repo_root, args.user, args.session)

    elif args.command == 'fetch':
        return cmd_fetch(repo_root)

    elif args.command == 'list-branches':
        return cmd_list_branches(
            repo_root,
            user=getattr(args, 'user', None),
            format=args.format
        )

    else:
        parser.print_help()
        return 1


if __name__ == '__main__':
    sys.exit(main())
