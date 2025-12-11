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
import fcntl
import subprocess
from pathlib import Path
from datetime import datetime, timezone
from typing import Dict, List, Optional


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

from validate_requirements import RequirementValidator

# Tracking file location
TRACKING_FILE = repo_root / 'untracked-notes' / 'outdated-implementations.json'

# Current tracking file schema version
TRACKING_VERSION = "1.0"


def load_tracking_file() -> Dict:
    """
    Load tracking file with proper locking.

    Returns:
        Dict with version, last_updated, outdated_requirements
    """
    if not TRACKING_FILE.exists():
        # Initialize new tracking file
        return {
            'version': TRACKING_VERSION,
            'last_updated': datetime.now(timezone.utc).isoformat(),
            'outdated_requirements': []
        }

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
    # Ensure directory exists
    TRACKING_FILE.parent.mkdir(parents=True, exist_ok=True)

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
    # Load change detection results
    with json_file.open('r') as f:
        changes = json.load(f)

    # Load current tracking data
    tracking_data = load_tracking_file()

    # Add changed requirements
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
            'TBD',  # No previous hash
            item['hash'],
            item['file'],
            item['title']
        ):
            added_count += 1

    # Save if changes made and not dry run
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
    # Normalize req_id
    if req_id.upper().startswith('REQ-'):
        req_id = req_id[4:]
    req_id = req_id.lower()

    # Fetch requirement to get file and title
    spec_dir = repo_root / 'spec'
    validator = RequirementValidator(spec_dir)
    validator._parse_requirements()

    if req_id not in validator.requirements:
        raise ValueError(f"Requirement '{req_id}' not found")

    req = validator.requirements[req_id]

    # Load tracking data
    tracking_data = load_tracking_file()

    # Add/update
    result = add_changed_requirement(
        tracking_data,
        req_id,
        old_hash,
        new_hash,
        req.file_path.name,
        req.title
    )

    # Save if changed and not dry run
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

    parser.add_argument(
        '--input',
        type=Path,
        help='JSON file from detect-changes.py'
    )

    parser.add_argument(
        '--req-id',
        help='Single requirement ID to update (e.g., REQ-d00027 or d00027)'
    )

    parser.add_argument(
        '--old-hash',
        help='Previous hash value (8-char hex)'
    )

    parser.add_argument(
        '--new-hash',
        help='Current hash value (8-char hex)'
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be updated without writing'
    )

    args = parser.parse_args()

    try:
        if args.input:
            # Update from JSON file
            if not args.input.exists():
                print(f"❌ Error: File not found: {args.input}", file=sys.stderr)
                return 1

            added_count = update_from_json(args.input, args.dry_run)

            if args.dry_run:
                print(f"🔍 Dry run: Would add/update {added_count} requirement(s)")
            else:
                if added_count > 0:
                    print(f"✅ Updated tracking file: {added_count} requirement(s) added/updated")
                    print(f"   File: {TRACKING_FILE}")
                else:
                    print("ℹ️  No new changes to track")

            return 0

        elif args.req_id and args.old_hash and args.new_hash:
            # Update single requirement
            result = update_single_requirement(
                args.req_id,
                args.old_hash,
                args.new_hash,
                args.dry_run
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
