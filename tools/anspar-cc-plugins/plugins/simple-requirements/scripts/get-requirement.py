#!/usr/bin/env python3
"""
Get Requirement Script

Fetches a requirement by ID and displays its full content with metadata.

Usage:
    python3 get-requirement.py REQ-d00027
    python3 get-requirement.py d00027
    python3 get-requirement.py d00027 --format json
    python3 get-requirement.py d00027 --format markdown

Formats:
    - markdown: Human-readable formatted output (default)
    - json: Machine-readable JSON output
"""

import sys
import json
import argparse
from pathlib import Path
from typing import Dict, Any

# Import shared utilities
from common import get_repo_root, get_requirements_via_cli, normalize_req_id, format_req_id

repo_root = get_repo_root()


def format_requirement_markdown(req_id: str, req: Dict[str, Any]) -> str:
    """
    Format requirement as markdown for human reading.

    Args:
        req_id: Normalized requirement ID (e.g., 'd00027')
        req: Requirement data dict from elspais CLI

    Returns:
        Formatted markdown string
    """
    implements_str = ', '.join(req.get('implements', [])) if req.get('implements') else '-'

    output = []
    output.append(f"### REQ-{req_id}: {req['title']}")
    output.append("")
    output.append(f"**Level**: {req['level']} | **Implements**: {implements_str} | **Status**: {req['status']} | **Hash**: {req['hash']}")
    output.append("")
    output.append(req['body'])
    output.append("")
    output.append(f"**Source**: {req['file']}:{req['line']}")

    return '\n'.join(output)


def format_requirement_json(req_id: str, req: Dict[str, Any]) -> str:
    """
    Format requirement as JSON for machine reading.

    Args:
        req_id: Normalized requirement ID (e.g., 'd00027')
        req: Requirement data dict from elspais CLI

    Returns:
        JSON string
    """
    data = {
        'id': req_id,
        'full_id': f'REQ-{req_id}',
        'title': req['title'],
        'level': req['level'],
        'implements': req.get('implements', []),
        'status': req['status'],
        'hash': req['hash'],
        'body': req['body'],
        'source': {
            'file': req['file'],
            'line': req['line']
        }
    }

    return json.dumps(data, indent=2)


def get_requirement(req_id: str, format_type: str = 'markdown') -> str:
    """
    Fetch and format a requirement by ID.

    Args:
        req_id: Requirement ID (with or without REQ- prefix)
        format_type: Output format ('markdown' or 'json')

    Returns:
        Formatted requirement string

    Raises:
        ValueError: If requirement not found
    """
    # Normalize ID
    normalized_id = normalize_req_id(req_id)
    full_id = format_req_id(normalized_id)

    # Get all requirements via elspais CLI
    all_reqs = get_requirements_via_cli()

    if not all_reqs:
        raise FileNotFoundError("Failed to get requirements from elspais CLI")

    # Find the requirement (elspais uses full IDs like 'REQ-d00027')
    if full_id not in all_reqs:
        available_ids = ', '.join(sorted(all_reqs.keys())[:10])
        raise ValueError(
            f"Requirement '{normalized_id}' not found.\n"
            f"Available requirements (first 10): {available_ids}..."
        )

    req = all_reqs[full_id]

    # Format based on type
    if format_type == 'json':
        return format_requirement_json(normalized_id, req)
    else:
        return format_requirement_markdown(normalized_id, req)


def main():
    """Main entry point for CLI usage."""
    parser = argparse.ArgumentParser(
        description='Fetch and display a requirement by ID',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    %(prog)s REQ-d00027
    %(prog)s d00027
    %(prog)s d00027 --format json
    %(prog)s p00042 --format markdown
        """
    )

    parser.add_argument(
        'req_id',
        help='Requirement ID (e.g., REQ-d00027 or d00027)'
    )

    parser.add_argument(
        '--format',
        choices=['markdown', 'json'],
        default='markdown',
        help='Output format (default: markdown)'
    )

    args = parser.parse_args()

    try:
        output = get_requirement(args.req_id, args.format)
        print(output)
        return 0
    except FileNotFoundError as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return 1
    except ValueError as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"❌ Unexpected error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
