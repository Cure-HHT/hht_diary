"""
Line break normalization for requirement content.

Provides functions to:
- Remove unnecessary blank lines after section headers
- Reflow paragraphs (join lines broken mid-sentence)
- Preserve intentional structure (list items, code blocks)

IMPLEMENTS REQUIREMENTS:
    REQ-d00018: Git Hook Implementation (requirement formatting)
"""

import re
from typing import List, Tuple


def normalize_line_breaks(content: str, reflow: bool = True) -> str:
    """
    Normalize line breaks in requirement content.

    Args:
        content: Raw requirement markdown content
        reflow: If True, also reflow paragraphs (join broken lines)

    Returns:
        Content with normalized line breaks
    """
    lines = content.split('\n')
    result_lines: List[str] = []

    i = 0
    while i < len(lines):
        line = lines[i]

        # Check if this is a section header (## Something)
        if re.match(r'^##\s+\w', line):
            result_lines.append(line)
            # Skip blank lines immediately after section header
            i += 1
            while i < len(lines) and lines[i].strip() == '':
                i += 1
            # Add single blank line after header for readability
            result_lines.append('')
            continue

        # Check if this starts a paragraph that might need reflowing
        if reflow and line.strip() and not _is_structural_line(line):
            # Collect paragraph lines
            para_lines = [line.rstrip()]
            i += 1
            while i < len(lines):
                next_line = lines[i]
                # Stop at blank lines, structural elements, or next section
                if (next_line.strip() == '' or
                    _is_structural_line(next_line) or
                    re.match(r'^##\s+', next_line)):
                    break
                para_lines.append(next_line.rstrip())
                i += 1

            # Join and reflow the paragraph
            reflowed = _reflow_paragraph(para_lines)
            result_lines.append(reflowed)
            continue

        # Keep structural lines and blank lines as-is
        result_lines.append(line.rstrip())
        i += 1

    # Clean up multiple consecutive blank lines
    return _collapse_blank_lines('\n'.join(result_lines))


def _is_structural_line(line: str) -> bool:
    """
    Check if a line is structural (should not be reflowed).

    Structural lines include:
    - List items (A., B., 1., -, *)
    - Headers (# or ##)
    - Metadata lines (**Level**: etc)
    - End markers (*End* ...)
    - Code fence markers (```)
    """
    stripped = line.strip()

    if not stripped:
        return False

    # Headers
    if stripped.startswith('#'):
        return True

    # Lettered assertions (A. B. C. etc)
    if re.match(r'^[A-Z]\.\s', stripped):
        return True

    # Numbered lists (1. 2. 3. etc)
    if re.match(r'^\d+\.\s', stripped):
        return True

    # Bullet points
    if stripped.startswith(('- ', '* ', '+ ')):
        return True

    # Metadata line
    if stripped.startswith('**Level**:') or stripped.startswith('**Status**:'):
        return True

    # Combined metadata line
    if re.match(r'\*\*Level\*\*:', stripped):
        return True

    # End marker
    if stripped.startswith('*End*'):
        return True

    # Code fence
    if stripped.startswith('```'):
        return True

    return False


def _reflow_paragraph(lines: List[str]) -> str:
    """
    Reflow a list of paragraph lines into a single line.

    Args:
        lines: Lines that form a paragraph

    Returns:
        Single reflowed line
    """
    if not lines:
        return ''

    if len(lines) == 1:
        return lines[0]

    # Join lines with space, collapsing multiple spaces
    joined = ' '.join(line.strip() for line in lines if line.strip())
    # Collapse multiple spaces
    return re.sub(r'\s+', ' ', joined)


def _collapse_blank_lines(content: str) -> str:
    """
    Collapse multiple consecutive blank lines into single blank lines.

    Args:
        content: Content that may have multiple blank lines

    Returns:
        Content with at most one blank line between paragraphs
    """
    # Replace 3+ newlines with 2 newlines (one blank line)
    return re.sub(r'\n{3,}', '\n\n', content)


def fix_requirement_line_breaks(
    body: str,
    rationale: str,
    reflow: bool = True
) -> Tuple[str, str]:
    """
    Fix line breaks in requirement body and rationale.

    Args:
        body: Requirement body text
        rationale: Requirement rationale text
        reflow: Whether to reflow paragraphs

    Returns:
        Tuple of (fixed_body, fixed_rationale)
    """
    fixed_body = normalize_line_breaks(body, reflow=reflow) if body else ''
    fixed_rationale = normalize_line_breaks(rationale, reflow=reflow) if rationale else ''

    return fixed_body, fixed_rationale


def detect_line_break_issues(content: str) -> List[str]:
    """
    Detect potential line break issues in content.

    Returns list of issues found for reporting.
    """
    issues = []
    lines = content.split('\n')

    for i, line in enumerate(lines):
        # Check for blank line after section header
        if re.match(r'^##\s+\w', line):
            # Look ahead for multiple blank lines
            blank_count = 0
            j = i + 1
            while j < len(lines) and lines[j].strip() == '':
                blank_count += 1
                j += 1
            if blank_count > 1:
                issues.append(
                    f"Line {i+1}: Multiple blank lines ({blank_count}) after section header"
                )

        # Check for mid-sentence line break (line ends without punctuation)
        stripped = line.rstrip()
        if (stripped and
            not _is_structural_line(line) and
            i + 1 < len(lines) and
            lines[i + 1].strip() and
            not _is_structural_line(lines[i + 1])):
            # Line ends with a word (not punctuation), followed by non-empty line
            if stripped and stripped[-1].isalnum():
                issues.append(
                    f"Line {i+1}: Possible mid-sentence line break"
                )

    return issues
