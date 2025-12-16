#!/usr/bin/env python3
"""
Apply PRD requirements hierarchy changes.

This script reads the proposed changes from analyze_hierarchy.py
and applies them to the spec files.

IMPLEMENTS REQUIREMENTS:
    REQ-p00020: System Validation and Traceability
"""

import re
import json
import sys
from pathlib import Path
from typing import Dict, List, Optional


def apply_changes(spec_dir: Path, proposals: List[Dict], dry_run: bool = False) -> Dict:
    """Apply hierarchy changes to spec files.

    Returns: Summary of changes made.
    """
    summary = {
        "files_modified": [],
        "requirements_updated": [],
        "errors": []
    }

    # Group changes by file
    by_file = {}
    for p in proposals:
        file_path = spec_dir / p["file"]
        if file_path not in by_file:
            by_file[file_path] = []
        by_file[file_path].append(p)

    for file_path, changes in by_file.items():
        if not file_path.exists():
            summary["errors"].append(f"File not found: {file_path}")
            continue

        content = file_path.read_text()
        modified = False

        for p in changes:
            req_id = p["req_id"]
            proposed = p["proposed_implements"]

            # Build the new implements value
            if proposed is None:
                new_impl = "-"
            else:
                new_impl = ", ".join(proposed)

            # Find the requirement header and its implements line
            # Pattern to match: # REQ-{req_id}: ...
            req_pattern = rf'(^# REQ-{req_id}:[^\n]*\n)'
            req_match = re.search(req_pattern, content, re.MULTILINE)

            if not req_match:
                summary["errors"].append(f"Could not find REQ-{req_id} in {file_path}")
                continue

            # Find the **Implements**: line after the header
            start_pos = req_match.end()

            # Look for **Implements** within the next 200 characters
            search_region = content[start_pos:start_pos + 500]
            impl_pattern = r'(\*\*Implements\*\*:\s*)([^\n|]+)'
            impl_match = re.search(impl_pattern, search_region)

            if not impl_match:
                summary["errors"].append(f"Could not find **Implements** for REQ-{req_id}")
                continue

            # Calculate absolute position
            abs_start = start_pos + impl_match.start()
            abs_end = start_pos + impl_match.end()

            old_line = impl_match.group(0)
            new_line = impl_match.group(1) + new_impl

            if old_line != new_line:
                # Apply the change
                content = content[:abs_start] + new_line + content[abs_end:]
                modified = True
                summary["requirements_updated"].append({
                    "req_id": req_id,
                    "old": old_line,
                    "new": new_line
                })

                if not dry_run:
                    print(f"  REQ-{req_id}: {impl_match.group(2).strip()} -> {new_impl}")

        if modified:
            summary["files_modified"].append(str(file_path))
            if not dry_run:
                file_path.write_text(content)

    return summary


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Apply PRD hierarchy changes")
    parser.add_argument("--dry-run", action="store_true", help="Show changes without applying")
    parser.add_argument("--input", type=str, help="JSON file with proposals (or stdin)")
    args = parser.parse_args()

    spec_dir = Path(__file__).parent.parent.parent / "spec"

    # Get proposals either from file or by running analysis
    if args.input:
        with open(args.input) as f:
            proposals = json.load(f)
    else:
        # Import and run analysis
        from analyze_hierarchy import parse_requirements, analyze_hierarchy
        requirements = parse_requirements(spec_dir)
        proposals = analyze_hierarchy(requirements)

    print(f"Found {len(proposals)} proposed changes")

    if args.dry_run:
        print("\n=== DRY RUN - No changes will be made ===\n")

    print("\nApplying changes...")
    summary = apply_changes(spec_dir, proposals, dry_run=args.dry_run)

    print(f"\n=== Summary ===")
    print(f"Files modified: {len(summary['files_modified'])}")
    print(f"Requirements updated: {len(summary['requirements_updated'])}")

    if summary["errors"]:
        print(f"\nErrors ({len(summary['errors'])}):")
        for err in summary["errors"]:
            print(f"  - {err}")

    if summary["files_modified"]:
        print(f"\nModified files:")
        for f in summary["files_modified"]:
            print(f"  - {f}")


if __name__ == "__main__":
    main()
