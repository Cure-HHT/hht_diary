#!/usr/bin/env python3
"""
Update requirement hashes in spec/*.md and INDEX.md files.

This script:
1. Reads all requirements from spec/*.md files
2. Calculates SHA-256 hash for each requirement body
3. Updates the Hash field in metadata lines
4. Updates the Hash column in INDEX.md

Usage:
    python3 update-REQ-hashes.py [--dry-run] [--req-id REQ-d00027]

Options:
    --dry-run    Show what would change without modifying files
    --req-id     Update only specific requirement
    --verify     Check hashes without updating
"""

import re
import sys
import argparse
import hashlib
from pathlib import Path
from typing import Dict, Tuple


def calculate_hash(body: str) -> str:
    """Calculate SHA-256 hash (first 8 chars)."""
    return hashlib.sha256(body.encode('utf-8')).hexdigest()[:8]


def update_spec_file(file_path: Path, dry_run: bool = False, specific_req: str = None) -> Dict[str, Tuple[str, str]]:
    """
    Update hashes in a spec file.
    Returns dict of {req_id: (old_hash, new_hash)}
    """
    content = file_path.read_text(encoding='utf-8')
    updates = {}

    # Pattern to find requirements with metadata
    # Note: There may be blank lines between header and metadata
    req_pattern = re.compile(
        r'(###\s+REQ-([pod]\d{5}):\s+.+?\n+'
        r'\*\*Level\*\*:.+?\|\s*\*\*Implements\*\*:.+?\|\s*\*\*Status\*\*:.+?\|\s*\*\*Hash\*\*:\s*)([a-f0-9]{8}|TBD)',
        re.MULTILINE
    )

    def replace_hash(match):
        full_match = match.group(0)
        prefix = match.group(1)
        req_id = match.group(2)
        old_hash = match.group(3)

        # If specific_req is set, only update that requirement
        if specific_req and req_id != specific_req:
            return full_match

        # Extract body (from after metadata to next ### or end)
        match_end = match.end()
        next_req = re.search(r'\n###\s+REQ-', content[match_end:])
        body_end = match_end + next_req.start() if next_req else len(content)
        body = content[match_end:body_end].strip()

        # Calculate new hash
        new_hash = calculate_hash(body)

        if old_hash != new_hash:
            updates[req_id] = (old_hash, new_hash)

        return prefix + new_hash

    new_content = req_pattern.sub(replace_hash, content)

    if not dry_run and new_content != content:
        file_path.write_text(new_content, encoding='utf-8')
        print(f"✓ Updated {file_path.name}")

    return updates


def update_index_file(index_path: Path, hash_map: Dict[str, str], dry_run: bool = False):
    """Update INDEX.md with new hashes."""
    content = index_path.read_text(encoding='utf-8')
    updated_content = content

    for req_id, new_hash in hash_map.items():
        # Pattern: | REQ-xxx | file | title | old_hash |
        pattern = re.compile(
            rf'(\|\s*REQ-{req_id}\s*\|[^|]+\|[^|]+\|\s*)([a-f0-9]{{8}}|TBD)(\s*\|)',
            re.MULTILINE
        )
        updated_content = pattern.sub(rf'\g<1>{new_hash}\g<3>', updated_content)

    if updated_content != content:
        if not dry_run:
            index_path.write_text(updated_content, encoding='utf-8')
            print(f"✓ Updated INDEX.md")
        return True
    return False


def main():
    parser = argparse.ArgumentParser(description='Update requirement hashes')
    parser.add_argument('--dry-run', action='store_true', help='Show changes without writing')
    parser.add_argument('--req-id', help='Update only specific requirement (e.g., d00027 or REQ-d00027)')
    parser.add_argument('--verify', action='store_true', help='Verify hashes only')
    args = parser.parse_args()

    # Normalize req-id format (remove REQ- prefix if present)
    specific_req = None
    if args.req_id:
        specific_req = args.req_id.replace('REQ-', '').lower()
        # Validate format
        if not re.match(r'^[pod]\d{5}$', specific_req):
            print(f"❌ Invalid requirement ID format: {args.req_id}")
            print("   Expected format: REQ-d00027 or d00027")
            sys.exit(1)

    script_dir = Path(__file__).parent
    spec_dir = script_dir.parent.parent / 'spec'
    index_path = spec_dir / 'INDEX.md'

    if not spec_dir.exists():
        print(f"❌ Spec directory not found: {spec_dir}")
        sys.exit(1)

    all_updates = {}
    changed_count = 0
    files_updated = 0

    print(f"{'🔍 Verifying' if args.verify else '📝 Updating'} requirement hashes...\n")

    for spec_file in sorted(spec_dir.glob('*.md')):
        if spec_file.name in ['INDEX.md', 'requirements-format.md', 'README.md']:
            continue

        updates = update_spec_file(spec_file, dry_run=args.dry_run or args.verify, specific_req=specific_req)

        if updates:
            files_updated += 1
            for req_id, (old_hash, new_hash) in updates.items():
                changed_count += 1
                status = "✓" if old_hash == "TBD" else "⚠"
                print(f"  {status} REQ-{req_id}: {old_hash} → {new_hash}")
                all_updates[req_id] = new_hash

    # Update INDEX.md
    if all_updates and not args.verify:
        print("\n📋 Updating INDEX.md...")
        index_updated = update_index_file(index_path, all_updates, dry_run=args.dry_run)
        if index_updated and not args.dry_run:
            files_updated += 1

    # Summary
    print(f"\n{'='*60}")
    print(f"Summary:")
    print(f"  Requirements updated: {changed_count}")
    print(f"  Files modified: {files_updated}")

    if args.dry_run:
        print("\n💡 Dry run - no files were modified")
        print("   Run without --dry-run to apply changes")
    elif args.verify:
        print("\n🔍 Verification complete")
        if changed_count > 0:
            print("   ⚠ Some hashes are out of date or TBD")
            print("   Run without --verify to update them")
        else:
            print("   ✅ All hashes are up to date")
    else:
        print("\n✅ Hash update complete")
        if changed_count > 0:
            print(f"   Updated {changed_count} requirement(s)")

    sys.exit(0)


if __name__ == '__main__':
    main()
