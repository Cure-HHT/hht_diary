#!/usr/bin/env python3
"""
Shared requirement hash calculation logic.

Both validate_requirements.py and update-REQ-hashes.py use this to ensure
consistent hash calculation.
"""

import hashlib


def calculate_requirement_hash(body: str) -> str:
    """
    Calculate SHA-256 hash of requirement body (first 8 chars).

    The body should be cleaned (trailing blank lines removed) before calling this.
    """
    return hashlib.sha256(body.encode('utf-8')).hexdigest()[:8]


def clean_requirement_body(body_text: str) -> str:
    """
    Clean requirement body text for hash calculation.

    Removes trailing blank lines to ensure consistent hashing between
    the validator and update script.

    Args:
        body_text: Raw body text between status line and end marker

    Returns:
        Cleaned body text with trailing blank lines removed
    """
    body_lines = body_text.split('\n')

    # Remove trailing blank lines
    while body_lines and not body_lines[-1].strip():
        body_lines.pop()

    return '\n'.join(body_lines)
