#!/usr/bin/env python3
"""
Detect Requirement Changes

Compares current requirement hashes with recorded hashes in INDEX.md
to detect which requirements have been modified.

Usage:
    python3 detect-changes.py
    python3 detect-changes.py --format json
    python3 detect-changes.py --format summary

Output Formats:
    - json: Machine-readable JSON (default)
    - summary: Human-readable summary

Requires:
    pip install elspais
"""

import sys
import json
import argparse
import re
import subprocess
from pathlib import Path
from datetime import datetime, timezone

# Import shared utilities
from common import get_repo_root, get_requirements_via_cli, normalize_req_id

repo_root = get_repo_root()

def parse_index_md(index_path: Path) -> dict:
    """
    Parse INDEX.md to extract recorded requirement hashes.

    Args:
        index_path: Path to spec/INDEX.md

    Returns:
        Dict mapping req_id to {file, title, hash}
    """
    if not index_path.exists():
        raise FileNotFoundError(f"INDEX.md not found at: {index_path}")

    content = index_path.read_text()
    index_reqs = {}

    # Parse markdown table rows
    # Format: | REQ-{id} | file.md | Title | hash |
    pattern = re.compile(r'\|\s*REQ-([pod]\d{5})\s*\|\s*([^\|]+?)\s*\|\s*([^\|]+?)\s*\|\s*([a-f0-9]{8}|TBD)\s*\|')

    for match in pattern.finditer(content):
        req_id = match.group(1).strip()
        file = match.group(2).strip()
        title = match.group(3).strip()
        hash_value = match.group(4).strip()

        index_reqs[req_id] = {
            'file': file,
            'title': title,
            'hash': hash_value
        }

    return index_reqs


def detect_changes(format_type: str = 'json') -> str:
    """
    Detect changed requirements by comparing current and INDEX.md hashes.

    Args:
        format_type: Output format ('json' or 'summary')

    Returns:
        Formatted output string
    """
    spec_dir = repo_root / 'spec'

    # Parse current requirements via elspais CLI
    current_reqs = get_requirements_via_cli()

    # Parse INDEX.md
    index_path = spec_dir / 'INDEX.md'
    index_reqs = parse_index_md(index_path)

    # Compare hashes
    changed = []
    new_reqs = []
    missing_from_index = []

    for full_req_id, req in current_reqs.items():
        # Extract short ID (e.g., 'd00027' from 'REQ-d00027')
        req_id = normalize_req_id(full_req_id)

        if req_id not in index_reqs:
            # New requirement not in INDEX.md
            missing_from_index.append({
                'req_id': req_id,
                'file': req['file'],
                'title': req['title'],
                'hash': req['hash'],
                'reason': 'not_in_index'
            })
        elif index_reqs[req_id]['hash'] == 'TBD':
            # Hash marked as TBD in INDEX
            new_reqs.append({
                'req_id': req_id,
                'file': req['file'],
                'title': req['title'],
                'hash': req['hash'],
                'reason': 'hash_tbd'
            })
        elif req['hash'] != index_reqs[req_id]['hash']:
            # Hash mismatch - requirement changed
            changed.append({
                'req_id': req_id,
                'old_hash': index_reqs[req_id]['hash'],
                'new_hash': req['hash'],
                'file': req['file'],
                'title': req['title']
            })

    # Format output
    timestamp = datetime.now(timezone.utc).isoformat()

    if format_type == 'json':
        result = {
            'timestamp': timestamp,
            'changed_requirements': changed,
            'new_requirements': new_reqs,
            'missing_from_index': missing_from_index,
            'summary': {
                'changed_count': len(changed),
                'new_count': len(new_reqs),
                'missing_count': len(missing_from_index)
            }
        }
        return json.dumps(result, indent=2)

    else:  # summary format
        lines = []
        lines.append("🔍 Requirement Change Detection")
        lines.append("=" * 60)
        lines.append("")

        if not changed and not new_reqs and not missing_from_index:
            lines.append("✅ No changes detected")
            lines.append("   All requirement hashes match INDEX.md")
            return '\n'.join(lines)

        if changed:
            lines.append(f"⚠️  {len(changed)} Changed Requirement(s):")
            lines.append("")
            for item in changed:
                lines.append(f"  • REQ-{item['req_id']}: {item['title']}")
                lines.append(f"    File: {item['file']}")
                lines.append(f"    Old Hash: {item['old_hash']} → New Hash: {item['new_hash']}")
                lines.append("")

        if new_reqs:
            lines.append(f"📝 {len(new_reqs)} New Requirement(s) (Hash = TBD):")
            lines.append("")
            for item in new_reqs:
                lines.append(f"  • REQ-{item['req_id']}: {item['title']}")
                lines.append(f"    File: {item['file']}, Hash: {item['hash']}")
                lines.append("")

        if missing_from_index:
            lines.append(f"❓ {len(missing_from_index)} Requirement(s) Missing from INDEX.md:")
            lines.append("")
            for item in missing_from_index:
                lines.append(f"  • REQ-{item['req_id']}: {item['title']}")
                lines.append(f"    File: {item['file']}, Hash: {item['hash']}")
                lines.append("")

        lines.append("=" * 60)
        lines.append("")
        lines.append("Next Steps:")
        lines.append("1. Review changed requirements above")
        lines.append("2. Verify implementations still satisfy requirements")
        lines.append("3. Update INDEX.md hashes when verified:")
        lines.append("   elspais hash update")
        lines.append("")

        return '\n'.join(lines)


def main():
    """Main entry point for CLI usage."""
    parser = argparse.ArgumentParser(
        description='Detect changed requirements by comparing hashes',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    %(prog)s
    %(prog)s --format json
    %(prog)s --format summary
        """
    )

    parser.add_argument(
        '--format',
        choices=['json', 'summary'],
        default='json',
        help='Output format (default: json)'
    )

    args = parser.parse_args()

    try:
        output = detect_changes(args.format)
        print(output)
        return 0
    except FileNotFoundError as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"❌ Unexpected error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
