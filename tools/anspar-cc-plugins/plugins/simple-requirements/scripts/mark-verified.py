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
from typing import Dict, Optional

# Import shared utilities
from common import (
    normalize_req_id,
    load_tracking_file,
    save_tracking_file,
    get_tracking_file_path,
)


def mark_verified(req_id: str, dry_run: bool = False) -> Optional[Dict]:
    """
    Mark a requirement as verified and remove from tracking file.

    Args:
        req_id: Requirement ID (with or without REQ- prefix)
        dry_run: If True, don't write changes

    Returns:
        The removed entry if found, None otherwise
    """
    normalized_id = normalize_req_id(req_id)
    tracking_data = load_tracking_file()

    # Find and remove the requirement
    removed_entry = None
    for i, entry in enumerate(tracking_data['outdated_requirements']):
        if entry['req_id'] == normalized_id:
            removed_entry = tracking_data['outdated_requirements'].pop(i)
            break

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
    tracking_file = get_tracking_file_path()

    try:
        if args.all:
            count = mark_all_verified(args.dry_run)

            if count == 0:
                print("ℹ️  No requirements currently tracked")
                return 0

            if args.dry_run:
                print(f"🔍 Dry run: Would remove {count} requirement(s) from tracking")
            else:
                print(f"✅ Marked {count} requirement(s) as verified")
                print(f"   Tracking file cleared: {tracking_file}")

            return 0

        elif args.req_id:
            removed_entry = mark_verified(args.req_id, args.dry_run)

            if not removed_entry:
                print(f"ℹ️  REQ-{normalize_req_id(args.req_id)} not found in tracking file",
                      file=sys.stderr)
                print("   (It may have already been verified or never changed)")
                return 1

            if args.dry_run:
                print(f"🔍 Dry run: Would mark as verified:")
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
