"""
Test helpers for trace-view test suite

Provides common fixtures and utilities for testing requirement parsing,
output generation, and HTML validation.
"""

import hashlib
from html.parser import HTMLParser


def calculate_test_hash(body: str) -> str:
    """Calculate requirement hash for test purposes (same algorithm as elspais)."""
    normalized = body.strip()
    hash_obj = hashlib.sha256(normalized.encode('utf-8'))
    return hash_obj.hexdigest()[:8]


# Alias for backward compatibility
calculate_requirement_hash = calculate_test_hash


def make_requirement(req_id: str, title: str, level: str, implements: str,
                     status: str, body: str) -> str:
    """Helper to create a requirement in the standard format with end marker.

    Args:
        req_id: Requirement ID (e.g., 'p00001', 'd00001')
        title: Requirement title
        level: Level (PRD, Ops, Dev)
        implements: Parent requirement ID or '-' for none
        status: Status (Active, Draft, Deprecated)
        body: Requirement body text

    Returns:
        Formatted requirement markdown string
    """
    # Body should NOT include leading/trailing newlines for hash calculation
    # but when written to file, it will have surrounding newlines
    parsed_body = f"\n{body}"  # Leading newline as parser extracts it
    req_hash = calculate_test_hash(parsed_body)
    return f"""# REQ-{req_id}: {title}

**Level**: {level} | **Implements**: {implements} | **Status**: {status}

{body}

*End* *{title}* | **Hash**: {req_hash}
"""


def make_requirement_with_rationale(req_id: str, title: str, level: str, implements: str,
                                     status: str, body: str, rationale: str) -> str:
    """Helper to create a requirement with separate body and rationale sections.

    Args:
        req_id: Requirement ID (e.g., 'p00001', 'd00001')
        title: Requirement title
        level: Level (PRD, Ops, Dev)
        implements: Parent requirement ID or '-' for none
        status: Status (Active, Draft, Deprecated)
        body: Requirement body text
        rationale: Rationale text

    Returns:
        Formatted requirement markdown string with rationale
    """
    full_body = f"{body}\n\n**Rationale**: {rationale}" if rationale else body
    parsed_body = f"\n{full_body}"
    req_hash = calculate_test_hash(parsed_body)
    return f"""# REQ-{req_id}: {title}

**Level**: {level} | **Implements**: {implements} | **Status**: {status}

{full_body}

*End* *{title}* | **Hash**: {req_hash}
"""


class HTMLValidator(HTMLParser):
    """Simple HTML validator to check for well-formed HTML.

    Usage:
        validator = HTMLValidator()
        validator.feed(html_content)
        if not validator.is_valid():
            print(f"HTML errors: {validator.errors}")
            print(f"Unclosed tags: {validator.tag_stack}")
    """

    # Self-closing tags that don't need closing tags
    VOID_ELEMENTS = {'br', 'hr', 'img', 'input', 'meta', 'link', 'area',
                     'base', 'col', 'embed', 'param', 'source', 'track', 'wbr'}

    def __init__(self):
        super().__init__()
        self.errors = []
        self.tag_stack = []

    def handle_starttag(self, tag, attrs):
        if tag not in self.VOID_ELEMENTS:
            self.tag_stack.append(tag)

    def handle_endtag(self, tag):
        if tag in self.VOID_ELEMENTS:
            return
        if not self.tag_stack:
            self.errors.append(f"Unexpected closing tag: {tag}")
        elif self.tag_stack[-1] != tag:
            self.errors.append(f"Mismatched tags: expected {self.tag_stack[-1]}, got {tag}")
        else:
            self.tag_stack.pop()

    def is_valid(self):
        """Check if the HTML is well-formed."""
        return len(self.errors) == 0 and len(self.tag_stack) == 0

    def reset(self):
        """Reset validator state for reuse."""
        super().reset()
        self.errors = []
        self.tag_stack = []
