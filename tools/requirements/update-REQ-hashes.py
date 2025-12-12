#!/usr/bin/env python3
"""
Update requirement hashes in spec/*.md and INDEX.md files.

Uses shared RequirementParser for consistent parsing with validate_requirements.py.

Usage:
    python3 update-REQ-hashes.py [--dry-run] [--req-id d00027] [--verify] [--path /repo]

IMPLEMENTS REQUIREMENTS:
    REQ-d00002: Requirements validation tool
"""

import re
import sys
import argparse
from pathlib import Path
from typing import Dict, Tuple
from requirement_hash import calculate_requirement_hash
from requirement_parser import RequirementParser, Requirement, make_req_filter


def update_hash_in_file(req: Requirement, new_hash: str, dry_run: bool = False) -> bool:
    """
    Update the hash in a requirement's end marker.

    Args:
        req: The requirement to update
        new_hash: The new hash value
        dry_run: If True, don't actually write the file

    Returns:
        True if the file was updated (or would be in dry_run mode)
    """
    content = req.file_path.read_text(encoding='utf-8')

    # Pattern to find this specific requirement's end marker
    # Escape the title for regex safety
    escaped_title = re.escape(req.title)
    pattern = re.compile(
        rf'\*End\*\s+\*{escaped_title}\*\s+\|\s+\*\*Hash\*\*:\s+(?:[a-f0-9]{{8}}|TBD)',
        re.MULTILINE
    )

    replacement = f"*End* *{req.title}* | **Hash**: {new_hash}"
    new_content, count = pattern.subn(replacement, content)

    if count > 0 and not dry_run:
        req.file_path.write_text(new_content, encoding='utf-8')
        return True

    return count > 0


def update_index_file(index_path: Path, hash_updates: Dict[str, str], dry_run: bool = False) -> bool:
    """
    Update hashes in INDEX.md.

    Args:
        index_path: Path to INDEX.md
        hash_updates: Dict of {req_id: new_hash}
        dry_run: If True, don't actually write the file

    Returns:
        True if updates were made
    """
    if not index_path.exists():
        return False

    content = index_path.read_text(encoding='utf-8')
    lines = content.split('\n')

    # Pattern for INDEX.md rows - supports both core and sponsor-specific IDs
    row_pattern = re.compile(r'^\|\s*REQ-(?:([A-Z]{2,4})-)?([pod]\d{5})\s*\|')

    updated = False
    for i, line in enumerate(lines):
        match = row_pattern.match(line)
        if not match:
            continue

        sponsor_prefix = match.group(1)
        base_id = match.group(2)
        req_id = f"{sponsor_prefix}-{base_id}" if sponsor_prefix else base_id

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
    parser = argparse.ArgumentParser(
        description='Update requirement hashes',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Update hashes in current repo
  python update-REQ-hashes.py

  # Update hashes in a different repo
  python update-REQ-hashes.py --path /path/to/other/repo

  # Verify hashes only
  python update-REQ-hashes.py --verify --path ../sibling-repo

  # Update single requirement
  python update-REQ-hashes.py --req-id d00027
'''
    )
    parser.add_argument('--dry-run', action='store_true', help='Show changes without writing')
    parser.add_argument('--req-id', help='Update only specific requirement (e.g., d00027 or REQ-d00027)')
    parser.add_argument('--verify', action='store_true', help='Verify hashes only')
    parser.add_argument('--path', type=Path, help='Path to repository root (default: auto-detect from script location)')
    args = parser.parse_args()

    # Normalize req-id format
    specific_req = None
    if args.req_id:
        specific_req = args.req_id.replace('REQ-', '').lower()
        if not re.match(r'^(?:[a-z]{2,4}-)?[pod]\d{5}$', specific_req):
            print(f"❌ Invalid requirement ID format: {args.req_id}")
            sys.exit(1)

    # Determine spec directory
    if args.path:
        repo_root = args.path.resolve()
        spec_dir = repo_root / 'spec'
    else:
        script_dir = Path(__file__).parent
        spec_dir = script_dir.parent.parent / 'spec'
    index_path = spec_dir / 'INDEX.md'

    if not spec_dir.exists():
        print(f"❌ Spec directory not found: {spec_dir}")
        sys.exit(1)

    # Parse requirements using shared parser
    req_parser = RequirementParser(spec_dir)
    req_filter = make_req_filter(specific_req)
    result = req_parser.parse_all(req_filter)

    if result.errors:
        print("⚠️  Parse errors encountered:")
        for error in result.errors:
            print(f"  {error}")
        print()

    # Find requirements needing hash updates
    updates: Dict[str, Tuple[str, str]] = {}  # {req_id: (old_hash, new_hash)}
    files_with_updates: Dict[Path, list] = {}  # {file_path: [req_ids]}

    print(f"{'🔍 Verifying' if args.verify else '📝 Updating'} requirement hashes...\n")

    for req_id, req in result.requirements.items():
        # Calculate hash from full content (body + rationale) for consistency with validator
        full_content = req.body
        if hasattr(req, 'rationale') and req.rationale:
            full_content = f"{req.body}\n\n**Rationale**: {req.rationale}"
        calculated_hash = calculate_requirement_hash(full_content)

        if req.hash != calculated_hash:
            updates[req_id] = (req.hash, calculated_hash)

            if req.file_path not in files_with_updates:
                files_with_updates[req.file_path] = []
            files_with_updates[req.file_path].append(req_id)

            # Update the file if not dry-run/verify
            if not args.dry_run and not args.verify:
                update_hash_in_file(req, calculated_hash)

    # Print updates by file
    for file_path in sorted(files_with_updates.keys()):
        print(f"  {file_path.name}:")
        for req_id in files_with_updates[file_path]:
            old_hash, new_hash = updates[req_id]
            status = "✓" if old_hash == "TBD" else "⚠"
            print(f"    {status} REQ-{req_id}: {old_hash} → {new_hash}")

    # Update INDEX.md
    hash_updates = {req_id: new_hash for req_id, (_, new_hash) in updates.items()}
    if hash_updates and not args.verify:
        print("\n📋 Updating INDEX.md...")
        index_updated = update_index_file(index_path, hash_updates, dry_run=args.dry_run)
        if index_updated:
            print("  ✓ INDEX.md updated")

    # Summary
    print(f"\n{'='*60}")
    print(f"Summary:")
    print(f"  Requirements updated: {len(updates)}")
    print(f"  Files modified: {len(files_with_updates)}")

    if args.dry_run:
        print("\n💡 Dry run - no files were modified")
        print("   Run without --dry-run to apply changes")
    elif args.verify:
        print("\n🔍 Verification complete")
        if updates:
            print("   ⚠ Some hashes are out of date or TBD")
            print("   Run without --verify to update them")
        else:
            print("   ✅ All hashes are up to date")
    else:
        print("\n✅ Hash update complete")

    return 0


if __name__ == '__main__':
    sys.exit(main())
