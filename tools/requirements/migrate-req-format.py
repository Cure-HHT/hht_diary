#!/usr/bin/env python3
"""
Migrate requirements to new format with hash at end.

Old format:
    ### REQ-d00008: Title

    **Level**: Dev | **Implements**: o00006 | **Status**: Active | **Hash**: abc12345
    Body content...

New format:
    ### REQ-d00008: Title

    **Level**: Dev | **Implements**: o00006 | **Status**: Active

    Body content...

    *End* *Title* | **Hash**: abc12345

Usage:
    python3 migrate-req-format.py [--dry-run] [--file spec/dev-api.md]
"""

import re
import sys
import hashlib
import argparse
from pathlib import Path
from typing import List, Tuple, Optional


def calculate_hash(body: str) -> str:
    """Calculate SHA-256 hash (first 8 chars) from requirement body."""
    return hashlib.sha256(body.encode('utf-8')).hexdigest()[:8]


def get_heading_level(line: str) -> int:
    """Get heading level from markdown heading (1-6)."""
    match = re.match(r'^(#{1,6})\s+', line)
    return len(match.group(1)) if match else 0


def validate_body_headings(body: str, req_heading_level: int) -> List[str]:
    """
    Check for headings at same or higher level in body.
    Returns list of violations.
    """
    violations = []
    lines = body.split('\n')

    for i, line in enumerate(lines, 1):
        heading_level = get_heading_level(line)
        if heading_level > 0 and heading_level <= req_heading_level:
            violations.append(f"Line {i}: {line.strip()}")

    return violations


def extract_title_from_req_line(req_line: str) -> str:
    """Extract title from REQ header line."""
    match = re.match(r'^#{1,6}\s+REQ-[pod]\d{5}:\s*(.+)$', req_line.strip())
    return match.group(1).strip() if match else ""


def migrate_single_requirement(lines: List[str], start_idx: int, end_idx: int) -> Tuple[List[str], Optional[str]]:
    """
    Migrate a single requirement to new format.

    Args:
        lines: All lines in the file
        start_idx: Index of REQ header line
        end_idx: Index after last line of this requirement

    Returns:
        (new_lines, error_message)
    """
    req_line = lines[start_idx].strip()
    heading_level = get_heading_level(req_line)
    title = extract_title_from_req_line(req_line)

    if not title:
        return None, f"Could not extract title from: {req_line}"

    # Find status line (should be first non-blank line after header)
    status_idx = start_idx + 1
    while status_idx < end_idx and not lines[status_idx].strip():
        status_idx += 1

    if status_idx >= end_idx:
        return None, f"No status line found for {req_line}"

    status_line = lines[status_idx].strip()

    # Parse status line to extract hash and remove it
    # Pattern: **Level**: X | **Implements**: Y | **Status**: Z | **Hash**: abc12345
    # Or:      **Level**: X | **Implements**: Y | **Status**: Z
    status_pattern = re.compile(
        r'^\*\*Level\*\*:\s+(.+?)\s+\|\s+'
        r'\*\*Implements\*\*:\s+(.+?)\s+\|\s+'
        r'\*\*Status\*\*:\s+(.+?)'
        r'(?:\s+\|\s+\*\*Hash\*\*:\s+([a-f0-9]{8}|TBD))?$'
    )

    match = status_pattern.match(status_line)
    if not match:
        return None, f"Invalid status line format: {status_line}"

    level = match.group(1).strip()
    implements = match.group(2).strip()
    status = match.group(3).strip()
    old_hash = match.group(4) if match.group(4) else "TBD"

    new_status_line = f"**Level**: {level} | **Implements**: {implements} | **Status**: {status}"

    # Extract body (everything after status line until end of requirement)
    body_start = status_idx + 1
    body_lines = lines[body_start:end_idx]

    # For hash calculation, remove trailing blank lines
    hash_body_lines = body_lines[:]
    while hash_body_lines and not hash_body_lines[-1].strip():
        hash_body_lines.pop()

    body_text = '\n'.join(hash_body_lines)

    # Validate no high-level headings in body
    violations = validate_body_headings(body_text, heading_level)
    if violations:
        return None, f"Heading level violations in {req_line}:\n  " + "\n  ".join(violations)

    # Calculate hash from body (without trailing blanks)
    new_hash = calculate_hash(body_text)

    # For output, use original body_lines but trim trailing blanks
    while body_lines and not body_lines[-1].strip():
        body_lines.pop()

    # Build new requirement
    new_lines = []
    new_lines.append(lines[start_idx])  # REQ header

    # Add blank lines between header and status (preserve existing)
    for i in range(start_idx + 1, status_idx):
        new_lines.append(lines[i])

    # Status line without hash
    new_lines.append(new_status_line)
    new_lines.append('')  # Blank line after status

    # Body content
    if body_lines:
        new_lines.extend(body_lines)
        new_lines.append('')  # Blank line before end marker

    # End marker
    end_marker = f"*End* *{title}* | **Hash**: {new_hash}"
    new_lines.append(end_marker)

    return new_lines, None


def migrate_file(file_path: Path, dry_run: bool = False) -> Tuple[int, List[str]]:
    """
    Migrate all requirements in a file.

    Returns:
        (count_migrated, errors)
    """
    content = file_path.read_text(encoding='utf-8')
    lines = content.split('\n')

    # Find all REQ headers
    req_pattern = re.compile(r'^(#{1,6})\s+REQ-([pod]\d{5}):\s*(.+)$')
    req_positions = []

    for i, line in enumerate(lines):
        match = req_pattern.match(line)
        if match:
            req_positions.append(i)

    if not req_positions:
        return 0, []

    # Process requirements in reverse order (so indices don't shift)
    new_lines = lines[:]
    migrated_count = 0
    errors = []

    for i in range(len(req_positions) - 1, -1, -1):
        start_idx = req_positions[i]

        # Find end of this requirement
        # Look for:
        # 1. Next --- separator
        # 2. Next REQ header
        # 3. EOF
        end_idx = len(lines)

        # Search for --- separator after this REQ
        for j in range(start_idx + 1, len(lines)):
            if lines[j].strip() == '---':
                end_idx = j
                break
            # Also stop at next REQ if found before ---
            if req_pattern.match(lines[j]):
                end_idx = j
                break

        # Migrate this requirement
        migrated_lines, error = migrate_single_requirement(new_lines, start_idx, end_idx)

        if error:
            errors.append(f"{file_path.name}: {error}")
            continue

        if migrated_lines:
            # Replace lines in new_lines
            new_lines[start_idx:end_idx] = migrated_lines
            migrated_count += 1

    # Write back if not dry run
    if not dry_run and migrated_count > 0:
        new_content = '\n'.join(new_lines)
        file_path.write_text(new_content, encoding='utf-8')

    return migrated_count, errors


def main():
    parser = argparse.ArgumentParser(
        description='Migrate requirements to new format',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('--dry-run', action='store_true', help='Show changes without writing')
    parser.add_argument('--file', type=Path, help='Migrate single file')

    args = parser.parse_args()

    script_dir = Path(__file__).parent
    spec_dir = script_dir.parent.parent / 'spec'

    if not spec_dir.exists():
        print(f"❌ Spec directory not found: {spec_dir}")
        sys.exit(1)

    # Get files to migrate
    if args.file:
        files = [args.file]
    else:
        files = sorted(spec_dir.glob('*.md'))
        files = [f for f in files if f.name not in ['INDEX.md', 'README.md']]

    print(f"{'🔍 DRY RUN - ' if args.dry_run else ''}📝 Migrating requirements to new format...\n")

    total_migrated = 0
    all_errors = []

    for file_path in files:
        count, errors = migrate_file(file_path, dry_run=args.dry_run)

        if count > 0:
            print(f"  ✓ {file_path.name}: {count} requirement(s)")
            total_migrated += count

        if errors:
            all_errors.extend(errors)

    print(f"\n{'='*60}")
    print(f"Summary:")
    print(f"  Requirements migrated: {total_migrated}")

    if all_errors:
        print(f"\n❌ Errors encountered:")
        for error in all_errors:
            print(f"  {error}")
        sys.exit(1)

    if args.dry_run:
        print("\n💡 Dry run complete - no files were modified")
        print("   Run without --dry-run to apply changes")
    else:
        print(f"\n✅ Migration complete!")
        print(f"   Next: python3 tools/requirements/update-REQ-hashes.py --verify")

    return 0


if __name__ == '__main__':
    sys.exit(main())
