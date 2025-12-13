#!/usr/bin/env python3
"""
REQ Move Script - Move requirements between spec files

This script moves requirements between spec files based on a JSON moves list.
It can read moves from:
1. A JSON file passed as argument
2. Stdin (pipe JSON directly)
3. Inline JSON argument

Usage:
    python3 move_reqs.py moves.json
    python3 move_reqs.py '[{"reqId": "d00001", "source": "dev-app.md", "target": "roadmap/dev-app.md"}]'
    cat moves.json | python3 move_reqs.py

Move format:
    {
        "reqId": "d00001",           # Requirement ID (without REQ- prefix)
        "source": "dev-app.md",      # Source file (relative to spec/)
        "target": "roadmap/dev-app.md"  # Target file (relative to spec/)
    }
"""

import re
import sys
import json
from pathlib import Path
from datetime import date

from requirement_parser import RequirementParser, make_req_filter


def find_req_block(content: str, req_id: str, file_path: Path) -> tuple[str, int, int] | None:
    """Find a requirement block in file content.

    Uses RequirementParser to find the requirement and extract its raw block.
    Returns (block_text, start_pos, end_pos) or None if not found.
    """
    # Use the shared parser with a filter for just this req_id
    parser = RequirementParser(file_path.parent)
    req_filter = make_req_filter(req_id)
    result = parser.parse_file(file_path, content, req_filter)

    if req_id not in result.requirements:
        return None

    req = result.requirements[req_id]
    block_text = req.get_raw_block(content)

    if not block_text:
        return None

    return block_text, req.start_pos, req.block_end_pos


def move_req_to_file(req_id: str, source_file: str, target_file: str, spec_dir: Path, dry_run: bool = False) -> bool:
    """Move a requirement from source to target file.

    Args:
        req_id: Requirement ID (e.g., "d00001")
        source_file: Source filename relative to spec/ (e.g., "dev-app.md")
        target_file: Target filename relative to spec/ (e.g., "roadmap/dev-app.md")
        spec_dir: Path to spec directory
        dry_run: If True, only print what would be done

    Returns:
        True if successful, False otherwise
    """
    # Build paths
    source_path = spec_dir / source_file
    target_path = spec_dir / target_file

    # Validate source exists
    if not source_path.exists():
        print(f"  ❌ Source file not found: {source_path}")
        return False

    # Read source content
    source_content = source_path.read_text(encoding='utf-8')

    # Find the requirement block using the shared parser
    result = find_req_block(source_content, req_id, source_path)
    if not result:
        print(f"  ❌ Could not find REQ-{req_id} in {source_file}")
        return False

    req_block, start_pos, end_pos = result

    # Extract title from the REQ block for display
    import re as re_module
    title_match = re_module.search(r'^#{1,6}\s+REQ-[^:]+:\s*(.+)$', req_block, re_module.MULTILINE)
    title = title_match.group(1).strip() if title_match else '(unknown)'

    if dry_run:
        target_exists = target_path.exists()
        is_roadmap_move = 'roadmap/' in target_file and 'roadmap/' not in source_file
        is_from_roadmap = 'roadmap/' in source_file and 'roadmap/' not in target_file

        print(f"  📋 Would move REQ-{req_id}:")
        print(f"     Title:  {title}")
        print(f"     From:   {source_file}")
        print(f"     To:     {target_file}")
        print(f"     Target: {'exists' if target_exists else 'will be created'}")
        print(f"     Block:  {len(req_block)} chars")
        if is_roadmap_move:
            print(f"     Status: Will show ↝ (moved to roadmap)")
        elif is_from_roadmap:
            print(f"     Status: Will show ↝ (moved from roadmap)")
        else:
            print(f"     Status: Will show ↝ (moved between files)")
        return True

    # Remove from source
    new_source_content = source_content[:start_pos] + source_content[end_pos:]
    # Clean up double blank lines
    new_source_content = re.sub(r'\n{3,}', '\n\n', new_source_content)

    # Prepare target
    target_path.parent.mkdir(parents=True, exist_ok=True)

    if target_path.exists():
        target_content = target_path.read_text(encoding='utf-8')
        # Insert before ## References section or append at end
        if '## References' in target_content:
            target_content = target_content.replace(
                '## References',
                req_block + '\n## References'
            )
        else:
            # Append at end, before any trailing whitespace
            target_content = target_content.rstrip() + '\n\n' + req_block
    else:
        # Create new file with header
        header = target_path.stem.replace('-', ' ').title()
        # Determine audience from filename prefix
        if target_path.stem.startswith('prd-'):
            audience = 'Product Requirements'
        elif target_path.stem.startswith('ops-'):
            audience = 'Operations'
        elif target_path.stem.startswith('dev-'):
            audience = 'Development'
        else:
            audience = 'Requirements'

        target_content = f"""# {header}

**Version**: 1.0
**Audience**: {audience}
**Last Updated**: {date.today().isoformat()}
**Status**: Draft

---

{req_block}

---

## References

(No references yet)
"""

    # Write files
    source_path.write_text(new_source_content, encoding='utf-8')
    target_path.write_text(target_content, encoding='utf-8')

    print(f"  ✅ Moved REQ-{req_id}: {source_file} → {target_file}")
    return True


def process_moves(moves: list[dict], spec_dir: Path, dry_run: bool = False) -> tuple[int, int]:
    """Process a list of move operations.

    Returns (success_count, failure_count)
    """
    success = 0
    failure = 0

    for move in moves:
        req_id = move.get('reqId') or move.get('req_id')
        source = move.get('source') or move.get('sourceFile')
        target = move.get('target') or move.get('targetFile')

        if not all([req_id, source, target]):
            print(f"  ❌ Invalid move entry: {move}")
            failure += 1
            continue

        if move_req_to_file(req_id, source, target, spec_dir, dry_run):
            success += 1
        else:
            failure += 1

    return success, failure


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description='Move requirements between spec files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        'input',
        nargs='?',
        help='JSON file path or inline JSON string. Reads from stdin if not provided.'
    )
    parser.add_argument(
        '--spec-dir',
        type=Path,
        default=None,
        help='Path to spec directory (default: auto-detect from script location)'
    )
    parser.add_argument(
        '--dry-run', '-n',
        action='store_true',
        help='Show what would be done without making changes'
    )

    args = parser.parse_args()

    # Determine spec directory
    if args.spec_dir:
        spec_dir = args.spec_dir
    else:
        # Auto-detect: script is in tools/requirements/, spec is at ../../spec/
        script_dir = Path(__file__).parent
        spec_dir = script_dir.parent.parent / 'spec'

    if not spec_dir.exists():
        print(f"❌ Spec directory not found: {spec_dir}")
        sys.exit(1)

    # Read moves JSON
    if args.input:
        input_path = Path(args.input)
        if input_path.exists():
            # It's a file
            moves_json = input_path.read_text(encoding='utf-8')
        else:
            # Assume it's inline JSON
            moves_json = args.input
    else:
        # Read from stdin
        if sys.stdin.isatty():
            print("Reading moves from stdin (paste JSON then Ctrl+D)...")
        moves_json = sys.stdin.read()

    # Parse JSON
    try:
        moves = json.loads(moves_json)
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON: {e}")
        sys.exit(1)

    if not isinstance(moves, list):
        moves = [moves]  # Allow single move object

    if not moves:
        print("No moves to process.")
        sys.exit(0)

    # Process moves
    print(f"{'[DRY RUN] ' if args.dry_run else ''}Processing {len(moves)} move(s)...")
    print(f"Spec directory: {spec_dir}")
    print()

    success, failure = process_moves(moves, spec_dir, args.dry_run)

    print()
    print(f"Results: {success} successful, {failure} failed")

    if not args.dry_run and success > 0:
        print("\n💡 Review changes with: git diff spec/")

    sys.exit(0 if failure == 0 else 1)


if __name__ == '__main__':
    main()
