"""
Format detection for requirements.

Detects whether a requirement is in old format (needs reformatting)
or new format (already reformatted).
"""

import re
from dataclasses import dataclass


@dataclass
class FormatAnalysis:
    """Result of format detection analysis."""
    is_new_format: bool
    has_assertions_section: bool
    has_labeled_assertions: bool
    has_acceptance_criteria: bool
    uses_shall_language: bool
    assertion_count: int
    confidence: float  # 0.0 to 1.0


def detect_format(body: str, rationale: str = "") -> FormatAnalysis:
    """
    Detect whether a requirement is in old or new format.

    New format indicators:
    - Has '## Assertions' section with labeled assertions (A., B., C.)
    - Does NOT have '**Acceptance Criteria**:' section
    - Uses prescriptive SHALL language in assertions

    Old format indicators:
    - Has '**Acceptance Criteria**:' or 'Acceptance Criteria:' section
    - Uses descriptive language (does, has, provides) without labeled assertions
    - May have bullet points without letter labels

    Args:
        body: The requirement body text
        rationale: Optional rationale text

    Returns:
        FormatAnalysis with detection results
    """
    full_text = f"{body}\n{rationale}".strip()

    # Check for ## Assertions section
    has_assertions_section = bool(
        re.search(r'^##\s+Assertions\s*$', full_text, re.MULTILINE)
    )

    # Check for labeled assertions (A., B., C., etc. followed by SHALL somewhere in the line)
    labeled_assertions = re.findall(
        r'^[A-Z]\.\s+.*\bSHALL\b',
        full_text,
        re.MULTILINE | re.IGNORECASE
    )
    has_labeled_assertions = len(labeled_assertions) >= 1
    assertion_count = len(labeled_assertions)

    # Check for Acceptance Criteria section
    has_acceptance_criteria = bool(re.search(
        r'\*?\*?Acceptance\s+Criteria\*?\*?\s*:',
        full_text,
        re.IGNORECASE
    ))

    # Check for SHALL language usage anywhere
    shall_count = len(re.findall(r'\bSHALL\b', full_text, re.IGNORECASE))
    uses_shall_language = shall_count >= 1

    # Determine if new format
    # New format: has Assertions section with labeled assertions, no Acceptance Criteria
    is_new_format = (
        has_assertions_section and
        has_labeled_assertions and
        not has_acceptance_criteria
    )

    # Calculate confidence score
    confidence = 0.0
    if has_assertions_section:
        confidence += 0.35
    if has_labeled_assertions:
        confidence += 0.35
    if not has_acceptance_criteria:
        confidence += 0.20
    if uses_shall_language:
        confidence += 0.10

    # Invert confidence if old format
    if not is_new_format:
        confidence = 1.0 - confidence

    return FormatAnalysis(
        is_new_format=is_new_format,
        has_assertions_section=has_assertions_section,
        has_labeled_assertions=has_labeled_assertions,
        has_acceptance_criteria=has_acceptance_criteria,
        uses_shall_language=uses_shall_language,
        assertion_count=assertion_count,
        confidence=confidence
    )


def needs_reformatting(body: str, rationale: str = "") -> bool:
    """
    Simple check if a requirement needs reformatting.

    Args:
        body: The requirement body text
        rationale: Optional rationale text

    Returns:
        True if the requirement needs reformatting (is in old format)
    """
    analysis = detect_format(body, rationale)
    return not analysis.is_new_format
