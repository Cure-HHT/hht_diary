#!/usr/bin/env python3
"""
Convert all REQ headers to heading level 1 (#).

This standardizes on the convention that all requirements use level 1 headings,
freeing up levels 2-6 for structured content within requirement bodies.

Usage:
    python3 convert-req-to-level1.py [--dry-run] [--verbose]
"""

import re
import sys
import argparse
from pathlib import Path
from typing import Dict, List


def convert_file(file_path: Path, dry_run: bool = False, verbose: bool = False) -> Dict[str, int]:
    """
    Convert all REQ headers in a file to level 1.
    Returns dict with conversion statistics.
    """
    content = file_path.read_text(encoding='utf-8')
    original = content

    # Pattern to match REQ headers at any level
    req_pattern = re.compile(r'^(#{1,6})\s+(REQ-[pod]\d{5}:\s+.+)$', re.MULTILINE)

    stats = {
        'total_reqs': 0,
        'converted': 0,
        'already_level1': 0
    }

    def replace_heading(match):
        heading_marks = match.group(1)
        req_text = match.group(2)
        level = len(heading_marks)

        stats['total_reqs'] += 1

        if level == 1:
            stats['already_level1'] += 1
            return match.group(0)  # No change
        else:
            stats['converted'] += 1
            if verbose:
                print(f"  {file_path.name}: Converting level {level} → 1: {req_text[:50]}...")
            return f"# {req_text}"

    content = req_pattern.sub(replace_heading, content)

    if content != original and not dry_run:
        file_path.write_text(content, encoding='utf-8')

    return stats


def main():
    parser = argparse.ArgumentParser(description='Convert REQ headers to level 1')
    parser.add_argument('--dry-run', action='store_true', help='Show changes without writing')
    parser.add_argument('--verbose', '-v', action='store_true', help='Show each conversion')
    args = parser.parse_args()

    script_dir = Path(__file__).parent
    spec_dir = script_dir.parent.parent / 'spec'

    if not spec_dir.exists():
        print(f"❌ Spec directory not found: {spec_dir}")
        sys.exit(1)

    total_stats = {
        'files_processed': 0,
        'files_changed': 0,
        'total_reqs': 0,
        'converted': 0,
        'already_level1': 0
    }

    print(f"{'🔍 Analyzing' if args.dry_run else '📝 Converting'} REQ headers to level 1...\n")

    for spec_file in sorted(spec_dir.glob('*.md')):
        if spec_file.name in ['INDEX.md', 'requirements-format.md', 'README.md']:
            continue

        total_stats['files_processed'] += 1
        stats = convert_file(spec_file, dry_run=args.dry_run, verbose=args.verbose)

        total_stats['total_reqs'] += stats['total_reqs']
        total_stats['converted'] += stats['converted']
        total_stats['already_level1'] += stats['already_level1']

        if stats['converted'] > 0:
            total_stats['files_changed'] += 1
            if not args.verbose:
                print(f"  {spec_file.name}: {stats['converted']} requirements converted to level 1")

    # Summary
    print(f"\n{'='*60}")
    print(f"Summary:")
    print(f"  Files processed: {total_stats['files_processed']}")
    print(f"  Files changed: {total_stats['files_changed']}")
    print(f"  Total requirements: {total_stats['total_reqs']}")
    print(f"  Converted to level 1: {total_stats['converted']}")
    print(f"  Already level 1: {total_stats['already_level1']}")

    if args.dry_run:
        print("\n💡 Dry run - no files were modified")
        print("   Run without --dry-run to apply changes")
    else:
        print("\n✅ Conversion complete")
        if total_stats['converted'] > 0:
            print("\n⚠️  Next steps:")
            print("   1. Run: python3 tools/requirements/update-REQ-hashes.py")
            print("   2. Run: python3 tools/requirements/validate_requirements.py")

    return 0


if __name__ == '__main__':
    sys.exit(main())
