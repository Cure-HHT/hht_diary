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

The script uses a two-phase approach to handle multiple moves from the same file:
1. Phase 1: Extract all REQ blocks from source files
2. Phase 2: Remove all moved REQs from source files and add to targets
"""

import re
import sys
import json
from pathlib import Path
from datetime import date
from dataclasses import dataclass, field
from typing import Dict, List, Tuple, Optional
from collections import defaultdict

from requirement_parser import RequirementParser, make_req_filter


@dataclass
class MoveOperation:
    """Represents a single move operation with extracted data"""
    req_id: str
    source_file: str
    target_file: str
    block_text: str = ''
    start_pos: int = 0
    end_pos: int = 0
    title: str = ''
    success: bool = False
    error: str = ''


def find_req_block(content: str, req_id: str, file_path: Path) -> tuple[str, int, int, str] | None:
    """Find a requirement block in file content.

    Uses RequirementParser to find the requirement and extract its raw block.
    Returns (block_text, start_pos, end_pos, title) or None if not found.
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

    return block_text, req.start_pos, req.block_end_pos, req.title


def extract_all_blocks(moves: List[MoveOperation], spec_dir: Path) -> Tuple[int, int]:
    """Phase 1: Extract all REQ blocks from source files.

    Reads each source file once and extracts all REQ blocks that need to be moved.
    Updates the MoveOperation objects with block_text, positions, and title.

    Returns (success_count, failure_count)
    """
    success = 0
    failure = 0

    # Group moves by source file for efficient reading
    moves_by_source: Dict[str, List[MoveOperation]] = defaultdict(list)
    for move in moves:
        moves_by_source[move.source_file].append(move)

    # Process each source file once
    for source_file, file_moves in moves_by_source.items():
        source_path = spec_dir / source_file

        if not source_path.exists():
            for move in file_moves:
                move.error = f"Source file not found: {source_path}"
                failure += 1
            continue

        # Read file content once
        content = source_path.read_text(encoding='utf-8')

        # Find each REQ block
        for move in file_moves:
            result = find_req_block(content, move.req_id, source_path)
            if result:
                move.block_text, move.start_pos, move.end_pos, move.title = result
                move.success = True
                success += 1
            else:
                move.error = f"Could not find REQ-{move.req_id} in {source_file}"
                failure += 1

    return success, failure


def apply_moves(moves: List[MoveOperation], spec_dir: Path) -> Tuple[int, int]:
    """Phase 2: Apply all moves - remove from sources and add to targets.

    For each source file, removes all moved REQs in one pass (from end to start
    to preserve positions). Then adds blocks to target files.

    Returns (success_count, failure_count)
    """
    success = 0
    failure = 0

    # Get only successful extractions
    valid_moves = [m for m in moves if m.success and m.block_text]

    # Group by source file for removal
    moves_by_source: Dict[str, List[MoveOperation]] = defaultdict(list)
    for move in valid_moves:
        moves_by_source[move.source_file].append(move)

    # Group by target file for addition
    moves_by_target: Dict[str, List[MoveOperation]] = defaultdict(list)
    for move in valid_moves:
        moves_by_target[move.target_file].append(move)

    # Phase 2a: Remove all moved REQs from each source file
    for source_file, file_moves in moves_by_source.items():
        source_path = spec_dir / source_file
        content = source_path.read_text(encoding='utf-8')

        # Sort by position descending so we remove from end first
        # This preserves positions for earlier removals
        sorted_moves = sorted(file_moves, key=lambda m: m.start_pos, reverse=True)

        for move in sorted_moves:
            # Remove the block
            content = content[:move.start_pos] + content[move.end_pos:]

        # Clean up multiple blank lines
        content = re.sub(r'\n{3,}', '\n\n', content)

        # Write updated source file
        source_path.write_text(content, encoding='utf-8')

    # Phase 2b: Add all REQ blocks to each target file
    for target_file, file_moves in moves_by_target.items():
        target_path = spec_dir / target_file
        target_path.parent.mkdir(parents=True, exist_ok=True)

        # Combine all blocks for this target
        blocks_to_add = [m.block_text for m in file_moves]

        if target_path.exists():
            target_content = target_path.read_text(encoding='utf-8')
            # Insert before ## References section or append at end
            if '## References' in target_content:
                combined_blocks = '\n'.join(blocks_to_add)
                target_content = target_content.replace(
                    '## References',
                    combined_blocks + '\n## References'
                )
            else:
                # Append at end
                target_content = target_content.rstrip() + '\n\n' + '\n'.join(blocks_to_add)
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

            combined_blocks = '\n'.join(blocks_to_add)
            target_content = f"""# {header}

**Version**: 1.0
**Audience**: {audience}
**Last Updated**: {date.today().isoformat()}
**Status**: Draft

---

{combined_blocks}

---

## References

(No references yet)
"""

        target_path.write_text(target_content, encoding='utf-8')

        # Mark all moves to this target as complete
        for move in file_moves:
            print(f"  ✅ Moved REQ-{move.req_id}: {move.source_file} → {move.target_file}")
            success += 1

    return success, failure


def process_moves(moves_data: List[dict], spec_dir: Path, dry_run: bool = False) -> Tuple[int, int]:
    """Process a list of move operations using two-phase approach.

    Phase 1: Extract all REQ blocks from source files
    Phase 2: Remove from sources and add to targets

    Returns (success_count, failure_count)
    """
    # Convert to MoveOperation objects
    moves: List[MoveOperation] = []
    invalid_count = 0

    for move_dict in moves_data:
        req_id = move_dict.get('reqId') or move_dict.get('req_id')
        source = move_dict.get('source') or move_dict.get('sourceFile')
        target = move_dict.get('target') or move_dict.get('targetFile')

        if not all([req_id, source, target]):
            print(f"  ❌ Invalid move entry: {move_dict}")
            invalid_count += 1
            continue

        moves.append(MoveOperation(
            req_id=req_id,
            source_file=source,
            target_file=target
        ))

    if not moves:
        return 0, invalid_count

    # Phase 1: Extract all blocks
    print("Phase 1: Extracting REQ blocks...")
    extract_success, extract_failure = extract_all_blocks(moves, spec_dir)

    # Report extraction errors
    for move in moves:
        if move.error:
            print(f"  ❌ {move.error}")

    if dry_run:
        # Just show what would be done
        print("\nPhase 2: Would apply the following moves:")
        for move in moves:
            if move.success:
                target_path = spec_dir / move.target_file
                target_exists = target_path.exists()
                is_roadmap_move = 'roadmap/' in move.target_file and 'roadmap/' not in move.source_file
                is_from_roadmap = 'roadmap/' in move.source_file and 'roadmap/' not in move.target_file

                print(f"  📋 Would move REQ-{move.req_id}:")
                print(f"     Title:  {move.title}")
                print(f"     From:   {move.source_file}")
                print(f"     To:     {move.target_file}")
                print(f"     Target: {'exists' if target_exists else 'will be created'}")
                print(f"     Block:  {len(move.block_text)} chars")
                if is_roadmap_move:
                    print(f"     Status: Will show ↝ (moved to roadmap)")
                elif is_from_roadmap:
                    print(f"     Status: Will show ↝ (moved from roadmap)")
                else:
                    print(f"     Status: Will show ↝ (moved between files)")

        return extract_success, extract_failure + invalid_count

    # Phase 2: Apply moves
    print("\nPhase 2: Applying moves...")
    apply_success, apply_failure = apply_moves(moves, spec_dir)

    return apply_success, extract_failure + invalid_count + apply_failure


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
