#!/usr/bin/env python3
"""
Mark Requirement as Verified

Removes a requirement from the outdated-implementations.json tracking file
after implementation has been verified to match the updated requirement.

Usage:
    python3 mark-verified.py REQ-d00027
    python3 mark-verified.py d00027
    python3 mark-verified.py d00027 --dry-run
    python3 mark-verified.py --all  # Mark all as verified (use with caution!)

Features:
    - Thread-safe file locking
    - Validates requirement exists before removing
    - Shows what was removed
    - Supports dry-run mode
"""

import sys
import json
import argparse
import fcntl
import subprocess
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, Optional


def get_repo_root() -> Path:
    """
    Get the repository root using git.

    This works even when the script is run from the Claude Code plugin cache,
    as long as the current working directory is within a git repository.
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
        return Path(__file__).resolve().parents[5]


# Add tools/requirements to Python path
repo_root = get_repo_root()
sys.path.insert(0, str(repo_root / 'tools' / 'requirements'))

# Tracking file location
TRACKING_FILE = repo_root / 'untracked-notes' / 'outdated-implementations.json'


def load_tracking_file() -> Dict:
    """
    Load tracking file with proper locking.

    Returns:
        Dict with version, last_updated, outdated_requirements
    """
    if not TRACKING_FILE.exists():
        raise FileNotFoundError(f"Tracking file not found: {TRACKING_FILE}")

    with TRACKING_FILE.open('r') as f:
        # Acquire shared lock for reading
        fcntl.flock(f.fileno(), fcntl.LOCK_SH)
        try:
            data = json.load(f)
            return data
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)


def save_tracking_file(data: Dict) -> None:
    """
    Save tracking file with proper locking.

    Args:
        data: Tracking data to save
    """
    # Update timestamp
    data['last_updated'] = datetime.now(timezone.utc).isoformat()

    # Write atomically with exclusive lock
    temp_file = TRACKING_FILE.with_suffix('.tmp')
    with temp_file.open('w') as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            json.dump(data, f, indent=2)
            f.write('\n')  # Trailing newline
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)

    # Atomic rename
    temp_file.replace(TRACKING_FILE)


def normalize_req_id(req_id: str) -> str:
    """
    Normalize requirement ID to standard format (without REQ- prefix).

    Args:
        req_id: Requirement ID (e.g., "REQ-d00027" or "d00027")

    Returns:
        Normalized ID (e.g., "d00027")
    """
    if req_id.upper().startswith('REQ-'):
        req_id = req_id[4:]
    return req_id.lower()


def mark_verified(req_id: str, dry_run: bool = False) -> Optional[Dict]:
    """
    Mark a requirement as verified and remove from tracking file.

    Args:
        req_id: Requirement ID (with or without REQ- prefix)
        dry_run: If True, don't write changes

    Returns:
        The removed entry if found, None otherwise
    """
    # Normalize ID
    normalized_id = normalize_req_id(req_id)

    # Load tracking data
    tracking_data = load_tracking_file()

    # Find and remove the requirement
    removed_entry = None
    for i, entry in enumerate(tracking_data['outdated_requirements']):
        if entry['req_id'] == normalized_id:
            removed_entry = tracking_data['outdated_requirements'].pop(i)
            break

    # Save if changed and not dry run
    if removed_entry and not dry_run:
        save_tracking_file(tracking_data)

    return removed_entry


def mark_all_verified(dry_run: bool = False) -> int:
    """
    Mark all requirements as verified (clear tracking file).

    Args:
        dry_run: If True, don't write changes

    Returns:
        Number of requirements that would be removed
    """
    # Load tracking data
    tracking_data = load_tracking_file()

    count = len(tracking_data['outdated_requirements'])

    if count > 0 and not dry_run:
        tracking_data['outdated_requirements'] = []
        save_tracking_file(tracking_data)

    return count


def main():
    """Main entry point for CLI usage."""
    parser = argparse.ArgumentParser(
        description='Mark requirement as verified and remove from tracking',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Mark single requirement as verified:
    %(prog)s REQ-d00027
    %(prog)s d00027

    # Dry run (show what would be removed):
    %(prog)s d00027 --dry-run

    # Mark all requirements as verified:
    %(prog)s --all --dry-run  # Check first!
    %(prog)s --all            # Clear all tracked requirements
        """
    )

    parser.add_argument(
        'req_id',
        nargs='?',
        help='Requirement ID to mark as verified (e.g., REQ-d00027 or d00027)'
    )

    parser.add_argument(
        '--all',
        action='store_true',
        help='Mark ALL requirements as verified (clears tracking file)'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be removed without writing'
    )

    args = parser.parse_args()

    try:
        if args.all:
            # Mark all as verified
            count = mark_all_verified(args.dry_run)

            if count == 0:
                print("ℹ️  No requirements currently tracked")
                return 0

            if args.dry_run:
                print(f"🔍 Dry run: Would remove {count} requirement(s) from tracking")
            else:
                print(f"✅ Marked {count} requirement(s) as verified")
                print(f"   Tracking file cleared: {TRACKING_FILE}")

            return 0

        elif args.req_id:
            # Mark single requirement as verified
            removed_entry = mark_verified(args.req_id, args.dry_run)

            if not removed_entry:
                print(f"ℹ️  REQ-{normalize_req_id(args.req_id)} not found in tracking file",
                      file=sys.stderr)
                print("   (It may have already been verified or never changed)")
                return 1

            if args.dry_run:
                print(f"🔍 Dry run: Would mark as verified:")
                print(f"   REQ-{removed_entry['req_id']}: {removed_entry['title']}")
                print(f"   File: {removed_entry['file']}")
                print(f"   Hash change: {removed_entry['old_hash']} → {removed_entry['new_hash']}")
            else:
                print(f"✅ Marked as verified and removed from tracking:")
                print(f"   REQ-{removed_entry['req_id']}: {removed_entry['title']}")
                print(f"   File: {removed_entry['file']}")
                print(f"   Hash change: {removed_entry['old_hash']} → {removed_entry['new_hash']}")

            return 0

        else:
            parser.print_help()
            print("\n❌ Error: Must provide either a requirement ID or --all",
                  file=sys.stderr)
            return 1

    except FileNotFoundError as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        print("   (No requirements are currently being tracked)")
        return 1
    except json.JSONDecodeError as e:
        print(f"❌ Error: Invalid JSON in tracking file: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"❌ Unexpected error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
