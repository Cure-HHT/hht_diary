#!/usr/bin/env python3
"""
REQ Reformatting Tool - CLI Entry Point

Traverses the requirement hierarchy and reformats REQs from old format
(with Acceptance Criteria) to new format (with labeled Assertions).

Usage:
    python -m tools.requirements.reformat_reqs [OPTIONS]

Examples:
    # Dry run to preview what would change
    python -m tools.requirements.reformat_reqs --dry-run --verbose

    # Process just the top level
    python -m tools.requirements.reformat_reqs --depth 1 --backup

    # Start from specific REQ
    python -m tools.requirements.reformat_reqs --start-req REQ-p00046 --depth 2

IMPLEMENTS REQUIREMENTS:
    REQ-d00018: Git Hook Implementation (requirement formatting)
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List

from .hierarchy import (
    get_all_requirements,
    build_hierarchy,
    traverse_top_down,
    normalize_req_id,
    RequirementNode
)
from .detector import detect_format, needs_reformatting
from .transformer import (
    reformat_requirement,
    assemble_new_format,
    validate_reformatted_content
)
from .file_editor import replace_requirement_in_file, update_hash
from .line_breaks import (
    normalize_line_breaks,
    fix_requirement_line_breaks,
    detect_line_break_issues
)


def create_parser() -> argparse.ArgumentParser:
    """Create the argument parser."""
    parser = argparse.ArgumentParser(
        description='Reformat requirements from old to new assertion-based format',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Dry run to preview changes
  python -m tools.requirements.reformat_reqs --dry-run --verbose

  # Process top level only
  python -m tools.requirements.reformat_reqs --depth 1 --backup

  # Start from specific REQ with depth limit
  python -m tools.requirements.reformat_reqs --start-req REQ-p00046 --depth 2

  # Force reformat already-formatted REQs
  python -m tools.requirements.reformat_reqs --force-reformat

  # Fix line breaks only (no AI reformatting)
  python -m tools.requirements.reformat_reqs --line-breaks-only --dry-run

  # Fix line breaks without paragraph reflowing
  python -m tools.requirements.reformat_reqs --line-breaks-only --no-reflow
'''
    )

    parser.add_argument(
        '--start-req',
        default='REQ-p00044',
        help='Starting requirement ID (default: REQ-p00044)'
    )
    parser.add_argument(
        '--depth',
        type=int,
        default=None,
        help='Maximum traversal depth (default: unlimited)'
    )
    parser.add_argument(
        '--force-reformat',
        action='store_true',
        help='Reformat even if already in new format'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without applying'
    )
    parser.add_argument(
        '--backup',
        action='store_true',
        help='Create .bak files before editing'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Show detailed progress'
    )
    parser.add_argument(
        '--output-json',
        type=Path,
        help='Write progress report to JSON file'
    )
    parser.add_argument(
        '--skip-hash-update',
        action='store_true',
        help='Skip elspais hash update after edit'
    )
    parser.add_argument(
        '--model',
        default='sonnet',
        choices=['sonnet', 'opus', 'haiku'],
        help='Claude model to use for reformatting (default: sonnet)'
    )
    parser.add_argument(
        '--fix-line-breaks',
        action='store_true',
        help='Normalize line breaks (remove extra blank lines, reflow paragraphs)'
    )
    parser.add_argument(
        '--no-reflow',
        action='store_true',
        help='With --fix-line-breaks: collapse blank lines but do not reflow paragraphs'
    )
    parser.add_argument(
        '--line-breaks-only',
        action='store_true',
        help='Only fix line breaks, skip AI-based reformatting'
    )

    return parser


def process_requirement(
    node: RequirementNode,
    depth: int,
    args: argparse.Namespace,
    results: Dict[str, List]
) -> None:
    """
    Process a single requirement.

    Args:
        node: RequirementNode to process
        depth: Current traversal depth
        args: Parsed command line arguments
        results: Results dict to update
    """
    indent = "  " * depth

    # Check format
    analysis = detect_format(node.body, node.rationale)

    if analysis.is_new_format and not args.force_reformat:
        if args.verbose:
            print(
                f"{indent}[SKIP] {node.req_id}: Already in new format "
                f"({analysis.assertion_count} assertions)",
                file=sys.stderr
            )
        results['already_formatted'].append(node.req_id)
        return

    # Log what we're doing
    action_desc = "Would reformat" if args.dry_run else "Reformatting"
    format_desc = "old format" if not analysis.is_new_format else "forced"
    print(
        f"{indent}[PROCESS] {node.req_id}: {node.title} ({format_desc})",
        file=sys.stderr
    )

    if args.dry_run:
        if args.verbose:
            print(f"{indent}  {action_desc} (dry run)", file=sys.stderr)
            if analysis.has_acceptance_criteria:
                print(f"{indent}  - Has Acceptance Criteria section", file=sys.stderr)
            if not analysis.has_assertions_section:
                print(f"{indent}  - Missing ## Assertions section", file=sys.stderr)
        results['processed'].append({
            'req_id': node.req_id,
            'file': node.file_path,
            'action': 'would_reformat',
            'reason': format_desc
        })
        return

    # Reformat with Claude
    if args.verbose:
        print(f"{indent}  Calling Claude ({args.model})...", file=sys.stderr)

    parsed, success, error_msg = reformat_requirement(
        node,
        model=args.model,
        verbose=args.verbose
    )

    if not success:
        print(f"{indent}  [ERROR] {error_msg}", file=sys.stderr)
        results['errors'].append({
            'req_id': node.req_id,
            'error': error_msg
        })
        return

    # Extract and clean up AI output
    rationale = parsed['rationale']
    assertions = parsed['assertions']

    # Normalize line breaks in AI output (always enabled to prevent introducing issues)
    # This reflows paragraphs and removes unnecessary blank lines
    rationale = normalize_line_breaks(rationale, reflow=True).strip()
    assertions = [normalize_line_breaks(a, reflow=True).strip() for a in assertions]

    is_valid, warnings = validate_reformatted_content(node, rationale, assertions)

    if warnings and args.verbose:
        for w in warnings:
            print(f"{indent}  [WARN] {w}", file=sys.stderr)

    if not is_valid:
        print(f"{indent}  [ERROR] Validation failed", file=sys.stderr)
        results['errors'].append({
            'req_id': node.req_id,
            'error': 'validation_failed',
            'warnings': warnings
        })
        return

    # Assemble new content
    new_content = assemble_new_format(
        req_id=node.req_id,
        title=node.title,
        level=node.level,
        status=node.status,
        implements=node.implements,
        rationale=rationale,
        assertions=assertions
    )

    # Replace in file
    try:
        replace_requirement_in_file(
            node.file_path,
            node.req_id,
            new_content,
            create_backup=args.backup
        )
        print(f"{indent}  [OK] Updated {Path(node.file_path).name}", file=sys.stderr)

        # Update hash
        if not args.skip_hash_update:
            if update_hash(node.req_id, verbose=args.verbose):
                print(f"{indent}  [OK] Hash updated", file=sys.stderr)
            else:
                print(f"{indent}  [WARN] Hash update failed", file=sys.stderr)

        results['processed'].append({
            'req_id': node.req_id,
            'file': node.file_path,
            'action': 'reformatted',
            'assertions': len(assertions),
            'warnings': warnings
        })

    except Exception as e:
        print(f"{indent}  [ERROR] {e}", file=sys.stderr)
        results['errors'].append({
            'req_id': node.req_id,
            'error': str(e)
        })


def process_line_breaks_only(
    node: RequirementNode,
    depth: int,
    args: argparse.Namespace,
    results: Dict[str, List]
) -> None:
    """
    Process a single requirement for line break normalization only.

    This skips AI-based reformatting and only fixes line break issues.

    Args:
        node: RequirementNode to process
        depth: Current traversal depth
        args: Parsed command line arguments
        results: Results dict to update
    """
    indent = "  " * depth

    # Check for line break issues
    full_content = f"{node.body}\n{node.rationale}"
    issues = detect_line_break_issues(full_content)

    if not issues and not args.force_reformat:
        if args.verbose:
            print(
                f"{indent}[SKIP] {node.req_id}: No line break issues detected",
                file=sys.stderr
            )
        results['already_formatted'].append(node.req_id)
        return

    # Log what we're doing
    action_desc = "Would fix" if args.dry_run else "Fixing"
    print(
        f"{indent}[PROCESS] {node.req_id}: {node.title} ({len(issues)} issues)",
        file=sys.stderr
    )

    if args.verbose and issues:
        for issue in issues[:5]:  # Show first 5 issues
            print(f"{indent}  - {issue}", file=sys.stderr)
        if len(issues) > 5:
            print(f"{indent}  ... and {len(issues) - 5} more", file=sys.stderr)

    if args.dry_run:
        results['processed'].append({
            'req_id': node.req_id,
            'file': node.file_path,
            'action': 'would_fix_line_breaks',
            'issues': len(issues)
        })
        return

    # Fix line breaks
    reflow = not args.no_reflow
    fixed_body, fixed_rationale = fix_requirement_line_breaks(
        node.body,
        node.rationale,
        reflow=reflow
    )

    # Read the current file content to reconstruct the full requirement
    try:
        from .file_editor import find_requirement_in_file
        _, _, current_content = find_requirement_in_file(node.file_path, node.req_id)

        # Apply fixes to the full content
        fixed_content = normalize_line_breaks(current_content, reflow=reflow)

        # Replace in file
        replace_requirement_in_file(
            node.file_path,
            node.req_id,
            fixed_content,
            create_backup=args.backup
        )
        print(f"{indent}  [OK] Updated {Path(node.file_path).name}", file=sys.stderr)

        # Update hash
        if not args.skip_hash_update:
            if update_hash(node.req_id, verbose=args.verbose):
                print(f"{indent}  [OK] Hash updated", file=sys.stderr)
            else:
                print(f"{indent}  [WARN] Hash update failed", file=sys.stderr)

        results['processed'].append({
            'req_id': node.req_id,
            'file': node.file_path,
            'action': 'fixed_line_breaks',
            'issues': len(issues)
        })

    except Exception as e:
        print(f"{indent}  [ERROR] {e}", file=sys.stderr)
        results['errors'].append({
            'req_id': node.req_id,
            'error': str(e)
        })


def main() -> int:
    """Main entry point."""
    parser = create_parser()
    args = parser.parse_args()

    # Normalize start REQ ID
    start_req = normalize_req_id(args.start_req)

    # Progress tracking
    results: Dict[str, Any] = {
        'start_req': start_req,
        'depth': args.depth,
        'dry_run': args.dry_run,
        'model': args.model,
        'mode': 'line_breaks_only' if args.line_breaks_only else 'full_reformat',
        'processed': [],
        'skipped': [],
        'errors': [],
        'already_formatted': []
    }

    # Load requirements
    print("Loading requirements via elspais...", file=sys.stderr)
    requirements = get_all_requirements()

    if not requirements:
        print("ERROR: No requirements found", file=sys.stderr)
        return 1

    print(f"Found {len(requirements)} requirements", file=sys.stderr)

    # Build hierarchy
    requirements = build_hierarchy(requirements)

    # Check start REQ exists
    if start_req not in requirements:
        print(f"ERROR: {start_req} not found", file=sys.stderr)
        print(f"Available top-level REQs:", file=sys.stderr)
        for req_id, node in requirements.items():
            if not node.implements:
                print(f"  {req_id}: {node.title}", file=sys.stderr)
        return 1

    # Count children
    start_node = requirements[start_req]
    child_count = len(start_node.children)
    print(
        f"Starting from {start_req} ({child_count} direct children)",
        file=sys.stderr
    )

    if args.depth is not None:
        print(f"Depth limit: {args.depth}", file=sys.stderr)

    # Display mode
    if args.line_breaks_only:
        print("Mode: Line breaks only (no AI reformatting)", file=sys.stderr)
    elif args.fix_line_breaks:
        print("Mode: Full reformat + line break fixing", file=sys.stderr)
    else:
        print("Mode: Full AI-based reformatting", file=sys.stderr)

    print("", file=sys.stderr)

    # Traverse and process - use appropriate callback based on mode
    if args.line_breaks_only:
        def process_callback(node: RequirementNode, depth: int) -> None:
            process_line_breaks_only(node, depth, args, results)
    else:
        def process_callback(node: RequirementNode, depth: int) -> None:
            process_requirement(node, depth, args, results)

    visited = traverse_top_down(
        requirements,
        start_req,
        max_depth=args.depth,
        callback=process_callback
    )

    # Summary
    print("", file=sys.stderr)
    print("--- Summary ---", file=sys.stderr)
    print(f"Visited: {len(visited)}", file=sys.stderr)
    print(f"Processed: {len(results['processed'])}", file=sys.stderr)
    print(f"Already formatted: {len(results['already_formatted'])}", file=sys.stderr)
    print(f"Errors: {len(results['errors'])}", file=sys.stderr)

    # Output JSON if requested
    if args.output_json:
        with open(args.output_json, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"Progress written to {args.output_json}", file=sys.stderr)

    # Exit code
    return 1 if results['errors'] else 0


if __name__ == '__main__':
    sys.exit(main())
