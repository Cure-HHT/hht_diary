#!/usr/bin/env python3
"""
Update requirement hashes in spec/*.md and INDEX.md files (New Format).

New format has hash at end marker:
    ### REQ-d00008: Title

    **Level**: Dev | **Implements**: o00006 | **Status**: Active

    Body content...

    *End* *Title* | **Hash**: abc12345

Usage:
    python3 update-REQ-hashes.py [--dry-run] [--req-id d00027] [--verify]
"""

import re
import sys
import argparse
from pathlib import Path
from typing import Dict, Tuple, Set
from requirement_hash import calculate_requirement_hash, clean_requirement_body


# calculate_requirement_hash and clean_requirement_body are now imported from requirement_hash module


def update_spec_file(file_path: Path, dry_run: bool = False, specific_req: str = None) -> Dict[str, Tuple[str, str]]:
    """
    Update hashes in a spec file (new format with end markers).
    Returns dict of {req_id: (old_hash, new_hash)}
    """
    content = file_path.read_text(encoding='utf-8')
    lines = content.split('\n')
    updates = {}

    # Pattern to find REQ headers
    req_pattern = re.compile(r'^(#{1,6})\s+REQ-([pod]\d{5}):\s+(.+)$')

    # Pattern to find status line
    status_pattern = re.compile(
        r'^\*\*Level\*\*:\s+(.+?)\s+\|\s+'
        r'\*\*Implements\*\*:\s+(.+?)\s+\|\s+'
        r'\*\*Status\*\*:\s+(.+?)\s*$'
    )

    # Pattern to find end marker
    end_pattern = re.compile(r'^\*End\*\s+\*(.+?)\*\s+\|\s+\*\*Hash\*\*:\s+([a-f0-9]{8}|TBD)\s*$')

    i = 0
    while i < len(lines):
        req_match = req_pattern.match(lines[i])
        if not req_match:
            i += 1
            continue

        req_id = req_match.group(2)
        title = req_match.group(3).strip()

        # Skip if specific_req set and doesn't match
        if specific_req and req_id != specific_req:
            i += 1
            continue

        # Find status line
        j = i + 1
        while j < len(lines) and not lines[j].strip():
            j += 1

        if j >= len(lines) or not status_pattern.match(lines[j]):
            i += 1
            continue

        status_idx = j

        # Find end marker
        k = status_idx + 1
        end_idx = None
        while k < len(lines):
            end_match = end_pattern.match(lines[k])
            if end_match:
                end_idx = k
                break
            # Stop at next REQ
            if req_pattern.match(lines[k]):
                break
            k += 1

        if end_idx is None:
            i += 1
            continue

        # Extract body (between status and end marker)
        body_text = '\n'.join(lines[status_idx + 1:end_idx])

        # Clean body using shared function
        body = clean_requirement_body(body_text)

        # Calculate hash using shared function
        new_hash = calculate_requirement_hash(body)
        old_hash = end_pattern.match(lines[end_idx]).group(2)

        if old_hash != new_hash:
            updates[req_id] = (old_hash, new_hash)

            if not dry_run:
                # Update hash in end marker
                end_title = end_pattern.match(lines[end_idx]).group(1)
                lines[end_idx] = f"*End* *{end_title}* | **Hash**: {new_hash}"

        i = end_idx + 1

    # Write back if changes made
    if updates and not dry_run:
        new_content = '\n'.join(lines)
        file_path.write_text(new_content, encoding='utf-8')

    return updates


def update_index_file(index_path: Path, hash_updates: Dict[str, str], dry_run: bool = False) -> bool:
    """
    Update hashes in INDEX.md.
    Returns True if updates were made.
    """
    if not index_path.exists():
        return False

    content = index_path.read_text(encoding='utf-8')
    lines = content.split('\n')

    # Pattern for INDEX.md rows
    row_pattern = re.compile(r'^\|\s*REQ-([pod]\d{5})\s*\|')

    updated = False
    for i, line in enumerate(lines):
        match = row_pattern.match(line)
        if not match:
            continue

        req_id = match.group(1)
        if req_id in hash_updates:
            new_hash = hash_updates[req_id]
            # Replace hash in last column
            parts = line.split('|')
            if len(parts) >= 5:
                parts[-2] = f" {new_hash} "
                lines[i] = '|'.join(parts)
                updated = True

    if updated and not dry_run:
        new_content = '\n'.join(lines)
        index_path.write_text(new_content, encoding='utf-8')

    return updated


def main():
    parser = argparse.ArgumentParser(description='Update requirement hashes (new format)')
    parser.add_argument('--dry-run', action='store_true', help='Show changes without writing')
    parser.add_argument('--req-id', help='Update only specific requirement (e.g., d00027 or REQ-d00027)')
    parser.add_argument('--verify', action='store_true', help='Verify hashes only')
    args = parser.parse_args()

    # Normalize req-id format
    specific_req = None
    if args.req_id:
        specific_req = args.req_id.replace('REQ-', '').lower()
        if not re.match(r'^[pod]\d{5}$', specific_req):
            print(f"❌ Invalid requirement ID format: {args.req_id}")
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
            print(f"  {spec_file.name}:")
            for req_id, (old_hash, new_hash) in updates.items():
                changed_count += 1
                status = "✓" if old_hash == "TBD" else "⚠"
                print(f"    {status} REQ-{req_id}: {old_hash} → {new_hash}")
                all_updates[req_id] = new_hash

    # Update INDEX.md
    if all_updates and not args.verify:
        print("\n📋 Updating INDEX.md...")
        index_updated = update_index_file(index_path, all_updates, dry_run=args.dry_run)
        if index_updated:
            print("  ✓ INDEX.md updated")

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

    return 0


if __name__ == '__main__':
    sys.exit(main())
