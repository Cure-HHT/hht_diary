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

# Import shared utilities
from common import get_repo_root, setup_python_path, normalize_req_id

# Add tools/requirements to Python path for imports
setup_python_path()
repo_root = get_repo_root()

from validate_requirements import RequirementValidator, Requirement


def format_requirement_markdown(req: Requirement) -> str:
    """
    Format requirement as markdown for human reading.

    Args:
        req: Requirement object

    Returns:
        Formatted markdown string
    """
    implements_str = ', '.join(req.implements) if req.implements else '-'

    output = []
    output.append(f"### REQ-{req.id}: {req.title}")
    output.append("")
    output.append(f"**Level**: {req.level} | **Implements**: {implements_str} | **Status**: {req.status} | **Hash**: {req.hash}")
    output.append("")
    output.append(req.body)
    output.append("")
    output.append(f"**Source**: {req.file_path.name}:{req.line_number}")

    return '\n'.join(output)


def format_requirement_json(req: Requirement) -> str:
    """
    Format requirement as JSON for machine reading.

    Args:
        req: Requirement object

    Returns:
        JSON string
    """
    data = {
        'id': req.id,
        'full_id': f'REQ-{req.id}',
        'title': req.title,
        'level': req.level,
        'implements': req.implements,
        'status': req.status,
        'hash': req.hash,
        'body': req.body,
        'source': {
            'file': str(req.file_path.name),
            'line': req.line_number
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

    # Parse all requirements
    spec_dir = repo_root / 'spec'
    if not spec_dir.exists():
        raise FileNotFoundError(f"Spec directory not found: {spec_dir}")

    validator = RequirementValidator(spec_dir)
    validator._parse_requirements()

    # Find the requirement
    if normalized_id not in validator.requirements:
        available_ids = ', '.join(sorted(validator.requirements.keys())[:10])
        raise ValueError(
            f"Requirement '{normalized_id}' not found.\n"
            f"Available requirements (first 10): {available_ids}..."
        )

    req = validator.requirements[normalized_id]

    # Format based on type
    if format_type == 'json':
        return format_requirement_json(req)
    else:
        return format_requirement_markdown(req)


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
