#!/usr/bin/env python3
"""
Add missing requirements to INDEX.md

This script finds all requirements in spec/*.md files and adds any missing
ones to INDEX.md with their proper hash, file, and title.
"""

import re
import sys
import hashlib
from pathlib import Path
from typing import Dict, List, Tuple


def calculate_hash(body: str) -> str:
    """Calculate SHA-256 hash (first 8 chars)."""
    return hashlib.sha256(body.encode('utf-8')).hexdigest()[:8]


def parse_requirements_from_file(file_path: Path) -> List[Tuple[str, str, str, str]]:
    """
    Parse requirements from a spec file.
    Returns list of (req_id, file_name, title, hash)
    """
    content = file_path.read_text(encoding='utf-8')
    requirements = []

    # Pattern to find requirements with metadata
    req_pattern = re.compile(
        r'###\s+REQ-([pod]\d{5}):\s+(.+?)\n+'
        r'\*\*Level\*\*:.+?\n'
        r'(.+?)(?=\n###|\Z)',
        re.MULTILINE | re.DOTALL
    )

    for match in req_pattern.finditer(content):
        req_id = match.group(1)
        title = match.group(2).strip()
        body = match.group(3).strip()

        # Calculate hash from body
        req_hash = calculate_hash(body)

        requirements.append((req_id, file_path.name, title, req_hash))

    return requirements


def parse_index_md(index_path: Path) -> Dict[str, Tuple[str, str, str]]:
    """
    Parse INDEX.md file.
    Returns dict of {req_id: (file_name, title, hash)}
    """
    content = index_path.read_text(encoding='utf-8')
    index_reqs = {}

    # Find the table rows
    table_pattern = re.compile(
        r'\|\s*REQ-([pod]\d{5})\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*([a-f0-9]{8}|TBD)\s*\|',
        re.MULTILINE
    )

    for match in table_pattern.finditer(content):
        req_id = match.group(1)
        file_name = match.group(2).strip()
        title = match.group(3).strip()
        req_hash = match.group(4).strip()

        index_reqs[req_id] = (file_name, title, req_hash)

    return index_reqs


def add_missing_requirements(index_path: Path, all_reqs: List[Tuple[str, str, str, str]],
                              index_reqs: Dict[str, Tuple[str, str, str]]) -> int:
    """
    Add missing requirements to INDEX.md.
    Returns number of requirements added.
    """
    # Find missing requirements
    missing = []
    for req_id, file_name, title, req_hash in all_reqs:
        if req_id not in index_reqs:
            missing.append((req_id, file_name, title, req_hash))

    if not missing:
        print("✅ No missing requirements found")
        return 0

    # Sort missing requirements by ID
    missing.sort(key=lambda x: x[0])

    # Read current INDEX.md
    content = index_path.read_text(encoding='utf-8')

    # Find the table
    lines = content.split('\n')
    table_start = -1
    table_end = -1

    for i, line in enumerate(lines):
        if line.startswith('| Requirement ID'):
            table_start = i
        elif table_start != -1 and (not line.startswith('|') or line.strip() == ''):
            table_end = i
            break

    if table_start == -1:
        print("❌ Could not find table in INDEX.md")
        return 0

    # Insert missing requirements in sorted order
    new_rows = []
    for req_id, file_name, title, req_hash in missing:
        new_rows.append(f"| REQ-{req_id} | {file_name} | {title} | {req_hash} |")
        print(f"  + REQ-{req_id}: {title}")

    # Combine all existing rows with new rows and sort
    all_rows = []
    for i in range(table_start + 2, table_end):  # Skip header and separator
        if lines[i].strip():
            all_rows.append(lines[i])

    all_rows.extend(new_rows)
    all_rows.sort()

    # Rebuild the file
    new_content = '\n'.join(lines[:table_start + 2]) + '\n'
    new_content += '\n'.join(all_rows) + '\n'
    if table_end < len(lines):
        new_content += '\n'.join(lines[table_end:])

    # Write back
    index_path.write_text(new_content, encoding='utf-8')

    return len(missing)


def main():
    script_dir = Path(__file__).parent
    spec_dir = script_dir.parent.parent / 'spec'
    index_path = spec_dir / 'INDEX.md'

    if not spec_dir.exists():
        print(f"❌ Spec directory not found: {spec_dir}")
        sys.exit(1)

    if not index_path.exists():
        print(f"❌ INDEX.md not found: {index_path}")
        sys.exit(1)

    print("📖 Scanning spec/ files for requirements...\n")

    # Parse all requirements from spec files
    all_reqs = []
    for spec_file in sorted(spec_dir.glob('*.md')):
        if spec_file.name in ['INDEX.md', 'README.md']:
            continue

        reqs = parse_requirements_from_file(spec_file)
        all_reqs.extend(reqs)
        if reqs:
            print(f"  Found {len(reqs)} in {spec_file.name}")

    print(f"\n  Total: {len(all_reqs)} requirements\n")

    # Parse INDEX.md
    print("📋 Parsing INDEX.md...\n")
    index_reqs = parse_index_md(index_path)
    print(f"  Found {len(index_reqs)} entries in INDEX.md\n")

    # Add missing requirements
    print("✏️  Adding missing requirements to INDEX.md...\n")
    added = add_missing_requirements(index_path, all_reqs, index_reqs)

    print(f"\n{'='*60}")
    print(f"✅ Added {added} requirement(s) to INDEX.md")

    return 0


if __name__ == '__main__':
    sys.exit(main())
