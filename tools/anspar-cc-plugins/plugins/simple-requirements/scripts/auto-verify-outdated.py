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
import os
import re
import json
import subprocess
from pathlib import Path
from typing import List, Dict, Optional, Tuple


def get_repo_root() -> Path:
    """Get the repository root using git."""
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True,
            text=True,
            check=True
        )
        return Path(result.stdout.strip())
    except subprocess.CalledProcessError:
        return Path(__file__).resolve().parents[5]


def get_auto_verify_setting() -> bool:
    """
    Check if auto-verify is enabled via environment or git config.

    Returns:
        True if auto-verify should be used, False for interactive mode
    """
    # Check environment variable first
    if os.environ.get('AUTO_VERIFY_REQ', '').lower() in ('1', 'true', 'yes'):
        return True

    # Check git config
    try:
        result = subprocess.run(
            ['git', 'config', '--get', 'workflow.autoVerifyReq'],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            value = result.stdout.strip().lower()
            return value in ('1', 'true', 'yes')
    except subprocess.CalledProcessError:
        pass

    return False


def extract_req_ids(commit_msg: str) -> List[str]:
    """
    Extract all REQ-xxx references from a commit message.

    Args:
        commit_msg: The commit message text

    Returns:
        List of requirement IDs (e.g., ['d00027', 'p00042'])
    """
    # Pattern: REQ-{type}{number} where type is p/o/d and number is 5 digits
    pattern = r'REQ-([pdo][0-9]{5})'
    matches = re.findall(pattern, commit_msg, re.IGNORECASE)
    # Normalize to lowercase
    return [m.lower() for m in matches]


def load_outdated_tracking(repo_root: Path) -> Optional[Dict]:
    """
    Load the outdated-implementations.json tracking file.

    Args:
        repo_root: Repository root path

    Returns:
        Tracking data dict, or None if file doesn't exist
    """
    tracking_file = repo_root / 'untracked-notes' / 'outdated-implementations.json'

    if not tracking_file.exists():
        return None

    try:
        with tracking_file.open('r') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None


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

    # Check if we're in an interactive terminal
    if not sys.stdin.isatty():
        print("Non-interactive mode: skipping verification prompt", file=sys.stderr)
        return False

    try:
        response = input("Mark as verified? [Y/n]: ").strip().lower()
        return response in ('', 'y', 'yes')
    except (EOFError, KeyboardInterrupt):
        print("\nSkipping verification", file=sys.stderr)
        return False


def mark_as_verified(req_id: str, repo_root: Path) -> bool:
    """
    Mark a requirement as verified by calling mark-verified.py.

    Args:
        req_id: Requirement ID to mark
        repo_root: Repository root path

    Returns:
        True if successful, False otherwise
    """
    mark_script = (
        repo_root / 'tools' / 'anspar-cc-plugins' / 'plugins' /
        'simple-requirements' / 'scripts' / 'mark-verified.py'
    )

    if not mark_script.exists():
        print(f"Warning: mark-verified.py not found at {mark_script}", file=sys.stderr)
        return False

    try:
        result = subprocess.run(
            ['python3', str(mark_script), req_id],
            capture_output=True,
            text=True,
            cwd=repo_root
        )
        if result.returncode == 0:
            # Print the success message from mark-verified.py
            if result.stdout:
                print(result.stdout.strip(), file=sys.stderr)
            return True
        else:
            if result.stderr:
                print(result.stderr.strip(), file=sys.stderr)
            return False
    except Exception as e:
        print(f"Error running mark-verified.py: {e}", file=sys.stderr)
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

    # Read commit message
    try:
        commit_msg = msg_file.read_text()
    except IOError as e:
        print(f"Error reading commit message: {e}", file=sys.stderr)
        return 2

    # Get repo root
    repo_root = get_repo_root()

    # Extract REQ IDs from commit message
    req_ids = extract_req_ids(commit_msg)
    if not req_ids:
        # No REQ references, nothing to do
        return 0

    # Load tracking file
    tracking_data = load_outdated_tracking(repo_root)
    if not tracking_data:
        # No tracking file, nothing to do
        return 0

    # Find which REQs are outdated
    outdated_reqs = find_outdated_reqs(req_ids, tracking_data)
    if not outdated_reqs:
        # None of the referenced REQs are in the outdated list
        return 0

    # Check if auto-verify is enabled
    auto_verify = get_auto_verify_setting()

    # Process each outdated REQ
    verified_count = 0
    skipped_count = 0

    for req_entry in outdated_reqs:
        req_id = req_entry.get('req_id', '')

        if auto_verify:
            # Auto-verify mode
            print(f"Auto-verifying REQ-{req_id}...", file=sys.stderr)
            if mark_as_verified(req_id, repo_root):
                verified_count += 1
            else:
                skipped_count += 1
        else:
            # Interactive mode
            if prompt_user(req_entry):
                if mark_as_verified(req_id, repo_root):
                    verified_count += 1
                else:
                    skipped_count += 1
            else:
                print(f"Skipping REQ-{req_id} (remains in outdated list)", file=sys.stderr)
                skipped_count += 1

    # Summary
    if verified_count > 0 or skipped_count > 0:
        print(f"\nVerification summary: {verified_count} verified, {skipped_count} skipped",
              file=sys.stderr)

    # Always return 0 - we don't want to block commits based on verification choices
    return 0


if __name__ == '__main__':
    sys.exit(main())
