"""
REQ Reformatting Tool

Traverses the requirement hierarchy and reformats REQs from old format
(with Acceptance Criteria) to new format (with labeled Assertions).

Also provides line break normalization to remove unnecessary blank lines
and reflow paragraphs that were broken mid-sentence.

IMPLEMENTS REQUIREMENTS:
    REQ-d00018: Git Hook Implementation (requirement formatting)
"""

__version__ = "0.2.0"

from .line_breaks import (
    normalize_line_breaks,
    fix_requirement_line_breaks,
    detect_line_break_issues
)
