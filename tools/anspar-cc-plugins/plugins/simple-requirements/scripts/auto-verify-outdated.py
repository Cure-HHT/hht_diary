#!/usr/bin/env python3
"""
Auto-Verify Outdated Requirements from Commit Message

Checks if any REQ references in a commit message are in the outdated-implementations.json
tracking file. If found, prompts user to mark them as verified (or auto-verifies if
AUTO_VERIFY_REQ=1 or git config workflow.autoVerifyReq is true).

Usage:
    # Interactive mode (default) - prompts for each outdated REQ
    python3 auto-verify-outdated.py <COMMIT-MSG-FILE>

    # Auto-verify mode - marks all without prompting
    AUTO_VERIFY_REQ=1 python3 auto-verify-outdated.py <COMMIT-MSG-FILE>

    # Or via git config:
    git config workflow.autoVerifyReq true

Exit codes:
    0  Success (no outdated REQs, or all handled)
    1  User declined to verify (commit should proceed but REQ stays in tracking)
    2  Error (file not found, etc.)

IMPLEMENTS REQUIREMENTS:
    REQ-d00018: Git Hook Implementation
    REQ-d00027: Workflow plugin state management
"""

import sys
import subprocess
from pathlib import Path
from typing import List, Dict

# Import shared utilities
from common import (
    get_repo_root,
    extract_req_ids,
    load_tracking_file,
    remove_from_tracking,
    get_env_bool,
    get_git_config,
)


def get_auto_verify_setting() -> bool:
    """
    Check if auto-verify is enabled via environment or git config.

    Returns:
        True if auto-verify should be used, False for interactive mode
    """
    if get_env_bool('AUTO_VERIFY_REQ'):
        return True

    value = get_git_config('workflow.autoVerifyReq').lower()
    return value in ('1', 'true', 'yes')


def find_outdated_reqs(req_ids: List[str], tracking_data: Dict) -> List[Dict]:
    """
    Find which REQ IDs are in the outdated tracking list.

    Args:
        req_ids: List of requirement IDs to check
        tracking_data: Loaded tracking file data

    Returns:
        List of outdated requirement entries that match
    """
    if not tracking_data or 'outdated_requirements' not in tracking_data:
        return []

    outdated = []
    for entry in tracking_data['outdated_requirements']:
        if entry.get('req_id', '').lower() in req_ids:
            outdated.append(entry)

    return outdated


def prompt_user(req_entry: Dict) -> bool:
    """
    Prompt user to verify an outdated requirement.

    Args:
        req_entry: The outdated requirement entry

    Returns:
        True if user wants to mark as verified, False otherwise
    """
    req_id = req_entry.get('req_id', 'unknown')
    title = req_entry.get('title', 'Unknown requirement')

    print(f"\n{'='*60}", file=sys.stderr)
    print(f"REQ-{req_id} is in the outdated requirements list.", file=sys.stderr)
    print(f"Title: {title}", file=sys.stderr)
    print(f"{'='*60}", file=sys.stderr)

    if not sys.stdin.isatty():
        print("Non-interactive mode: skipping verification prompt", file=sys.stderr)
        return False

    try:
        response = input("Mark as verified? [Y/n]: ").strip().lower()
        return response in ('', 'y', 'yes')
    except (EOFError, KeyboardInterrupt):
        print("\nSkipping verification", file=sys.stderr)
        return False


def mark_as_verified(req_id: str) -> bool:
    """
    Mark a requirement as verified using the common module.

    Args:
        req_id: Requirement ID to mark

    Returns:
        True if successful, False otherwise
    """
    removed = remove_from_tracking(req_id)
    if removed:
        print(f"✅ Marked as verified and removed from tracking:", file=sys.stderr)
        print(f"   REQ-{removed['req_id']}: {removed.get('title', 'N/A')}", file=sys.stderr)
        return True
    else:
        print(f"ℹ️  REQ-{req_id} not found in tracking file", file=sys.stderr)
        return False


def main() -> int:
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Auto-verify outdated requirements from commit message',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Environment variables:
    AUTO_VERIFY_REQ=1    Auto-verify without prompting

Git config:
    workflow.autoVerifyReq=true    Auto-verify without prompting

Examples:
    # Interactive mode (prompts for each outdated REQ):
    %(prog)s .git/COMMIT_EDITMSG

    # Auto-verify mode:
    AUTO_VERIFY_REQ=1 %(prog)s .git/COMMIT_EDITMSG
        """
    )

    parser.add_argument(
        'commit_msg_file',
        metavar='COMMIT-MSG-FILE',
        help='Path to commit message file'
    )

    args = parser.parse_args()

    msg_file = Path(args.commit_msg_file)
    if not msg_file.exists():
        print(f"Error: Commit message file not found: {msg_file}", file=sys.stderr)
        return 2

    try:
        commit_msg = msg_file.read_text()
    except IOError as e:
        print(f"Error reading commit message: {e}", file=sys.stderr)
        return 2

    # Extract REQ IDs from commit message
    req_ids = extract_req_ids(commit_msg)
    if not req_ids:
        return 0

    # Load tracking file
    try:
        tracking_data = load_tracking_file()
    except FileNotFoundError:
        return 0

    # Find which REQs are outdated
    outdated_reqs = find_outdated_reqs(req_ids, tracking_data)
    if not outdated_reqs:
        return 0

    # Check if auto-verify is enabled
    auto_verify = get_auto_verify_setting()

    # Process each outdated REQ
    verified_count = 0
    skipped_count = 0

    for req_entry in outdated_reqs:
        req_id = req_entry.get('req_id', '')

        if auto_verify:
            print(f"Auto-verifying REQ-{req_id}...", file=sys.stderr)
            if mark_as_verified(req_id):
                verified_count += 1
            else:
                skipped_count += 1
        else:
            if prompt_user(req_entry):
                if mark_as_verified(req_id):
                    verified_count += 1
                else:
                    skipped_count += 1
            else:
                print(f"Skipping REQ-{req_id} (remains in outdated list)", file=sys.stderr)
                skipped_count += 1

    if verified_count > 0 or skipped_count > 0:
        print(f"\nVerification summary: {verified_count} verified, {skipped_count} skipped",
              file=sys.stderr)

    return 0


if __name__ == '__main__':
    sys.exit(main())
