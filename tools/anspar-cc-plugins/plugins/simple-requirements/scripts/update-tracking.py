#!/usr/bin/env python3
"""
Update Tracking File

Manages outdated-implementations.json by adding newly detected changed requirements
and maintaining the tracking file structure.

Usage:
    python3 update-tracking.py --input changes.json
    python3 update-tracking.py --input changes.json --dry-run
    python3 update-tracking.py --req-id d00027 --old-hash abc123 --new-hash def456

Input Formats:
    - JSON file from detect-changes.py (--input)
    - Individual requirement update (--req-id, --old-hash, --new-hash)

Features:
    - Thread-safe file locking
    - Prevents duplicate entries
    - Maintains chronological order
    - Validates input data
"""

import sys
import json
import argparse
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, List, Any

# Import shared utilities
from common import (
    normalize_req_id,
    format_req_id,
    load_tracking_file,
    save_tracking_file,
    get_tracking_file_path,
    get_repo_root,
    get_requirements_via_cli,
)


def add_changed_requirement(
    tracking_data: Dict,
    req_id: str,
    old_hash: str,
    new_hash: str,
    file: str,
    title: str
) -> bool:
    """
    Add a changed requirement to tracking data.

    Args:
        tracking_data: Current tracking data
        req_id: Requirement ID (without REQ- prefix)
        old_hash: Previous hash from INDEX.md
        new_hash: Current hash from spec file
        file: Source file name
        title: Requirement title

    Returns:
        True if added, False if already exists
    """
    # Check if already tracked
    for entry in tracking_data['outdated_requirements']:
        if entry['req_id'] == req_id:
            # Update if hash changed further
            if entry['new_hash'] != new_hash:
                entry['new_hash'] = new_hash
                entry['updated_at'] = datetime.now(timezone.utc).isoformat()
                return True
            return False  # Already tracked with same hash

    # Add new entry
    entry = {
        'req_id': req_id,
        'old_hash': old_hash,
        'new_hash': new_hash,
        'detected_at': datetime.now(timezone.utc).isoformat(),
        'file': file,
        'title': title,
        'linear_ticket': None,  # Populated by Linear integration if enabled
        'verified_at': None     # Set when implementation verified
    }

    tracking_data['outdated_requirements'].append(entry)
    return True


def update_from_json(json_file: Path, dry_run: bool = False) -> int:
    """
    Update tracking file from detect-changes.py JSON output.

    Args:
        json_file: Path to JSON file with change detection results
        dry_run: If True, don't write changes

    Returns:
        Number of requirements added/updated
    """
    with json_file.open('r') as f:
        changes = json.load(f)

    tracking_data = load_tracking_file(create_if_missing=True)

    added_count = 0
    for item in changes.get('changed_requirements', []):
        if add_changed_requirement(
            tracking_data,
            item['req_id'],
            item['old_hash'],
            item['new_hash'],
            item['file'],
            item['title']
        ):
            added_count += 1

    # Also track new requirements (hash was TBD in INDEX)
    for item in changes.get('new_requirements', []):
        if add_changed_requirement(
            tracking_data,
            item['req_id'],
            'TBD',
            item['hash'],
            item['file'],
            item['title']
        ):
            added_count += 1

    if added_count > 0 and not dry_run:
        save_tracking_file(tracking_data)

    return added_count


def update_single_requirement(
    req_id: str,
    old_hash: str,
    new_hash: str,
    dry_run: bool = False
) -> bool:
    """
    Update tracking file for a single requirement.

    Args:
        req_id: Requirement ID (with or without REQ- prefix)
        old_hash: Previous hash
        new_hash: Current hash
        dry_run: If True, don't write changes

    Returns:
        True if added/updated, False otherwise
    """
    normalized_id = normalize_req_id(req_id)
    full_id = format_req_id(normalized_id)

    # Fetch requirement to get file and title via elspais CLI
    all_reqs = get_requirements_via_cli()

    if not all_reqs:
        raise ValueError("Failed to get requirements from elspais CLI")

    if full_id not in all_reqs:
        raise ValueError(f"Requirement '{normalized_id}' not found")

    req = all_reqs[full_id]
    tracking_data = load_tracking_file(create_if_missing=True)

    result = add_changed_requirement(
        tracking_data,
        normalized_id,
        old_hash,
        new_hash,
        req['file'],
        req['title']
    )

    if result and not dry_run:
        save_tracking_file(tracking_data)

    return result


def main():
    """Main entry point for CLI usage."""
    parser = argparse.ArgumentParser(
        description='Update tracking file with changed requirements',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Update from detect-changes.py output:
    %(prog)s --input changes.json

    # Dry run (show what would be added):
    %(prog)s --input changes.json --dry-run

    # Add single requirement:
    %(prog)s --req-id d00027 --old-hash abc12345 --new-hash def67890
        """
    )

    parser.add_argument('--input', type=Path, help='JSON file from detect-changes.py')
    parser.add_argument('--req-id', help='Single requirement ID to update')
    parser.add_argument('--old-hash', help='Previous hash value (8-char hex)')
    parser.add_argument('--new-hash', help='Current hash value (8-char hex)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be updated')

    args = parser.parse_args()
    tracking_file = get_tracking_file_path()

    try:
        if args.input:
            if not args.input.exists():
                print(f"❌ Error: File not found: {args.input}", file=sys.stderr)
                return 1

            added_count = update_from_json(args.input, args.dry_run)

            if args.dry_run:
                print(f"🔍 Dry run: Would add/update {added_count} requirement(s)")
            else:
                if added_count > 0:
                    print(f"✅ Updated tracking file: {added_count} requirement(s) added/updated")
                    print(f"   File: {tracking_file}")
                else:
                    print("ℹ️  No new changes to track")

            return 0

        elif args.req_id and args.old_hash and args.new_hash:
            result = update_single_requirement(
                args.req_id, args.old_hash, args.new_hash, args.dry_run
            )

            if args.dry_run:
                action = "Would add/update" if result else "Would not change"
                print(f"🔍 Dry run: {action} REQ-{args.req_id}")
            else:
                if result:
                    print(f"✅ Updated tracking file: REQ-{args.req_id}")
                    print(f"   Old hash: {args.old_hash}")
                    print(f"   New hash: {args.new_hash}")
                else:
                    print(f"ℹ️  REQ-{args.req_id} already tracked with same hash")

            return 0

        else:
            parser.print_help()
            print("\n❌ Error: Must provide either --input or all of --req-id, --old-hash, --new-hash",
                  file=sys.stderr)
            return 1

    except FileNotFoundError as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return 1
    except ValueError as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as e:
        print(f"❌ Error: Invalid JSON: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"❌ Unexpected error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
