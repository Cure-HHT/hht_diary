#!/usr/bin/env python3
"""
Position Resolution Module for trace_view

Resolves comment positions within requirement text, handling content drift
when REQ hashes don't match. Uses fallback strategies to locate anchors
with varying confidence levels.

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00012: Position Resolution
"""

from dataclasses import dataclass
from enum import Enum
from typing import Any, Dict, List, Optional, Tuple

from .models import CommentPosition, PositionType


# =============================================================================
# Enums
# REQ-tv-d00012-B: Confidence levels as string enums
# =============================================================================

class ResolutionConfidence(str, Enum):
    """
    Confidence level for resolved position.

    REQ-tv-d00012-B: EXACT (hash matches), APPROXIMATE (fallback matched),
    or UNANCHORED (no match found).
    """
    EXACT = "exact"
    APPROXIMATE = "approximate"
    UNANCHORED = "unanchored"


# =============================================================================
# Data Classes
# =============================================================================

@dataclass
class ResolvedPosition:
    """
    Result of resolving a CommentPosition against current REQ content.

    REQ-tv-d00012-A: Resolves CommentPosition anchors to current document coordinates.
    REQ-tv-d00012-I: Includes resolutionPath describing the fallback strategy used.

    Contains all information needed to display a comment at its resolved
    location, including confidence level and original position for reference.
    """
    type: str  # Resolved position type (PositionType value)
    confidence: str  # ResolutionConfidence value
    lineNumber: Optional[int]  # Resolved line (1-based), None for general
    lineRange: Optional[Tuple[int, int]]  # Resolved line range (start, end), 1-based
    charRange: Optional[Tuple[int, int]]  # Character offsets in body (start, end), 0-based
    matchedText: Optional[str]  # The text that was matched (for debugging)
    originalPosition: CommentPosition  # Original position for reference
    resolutionPath: str  # How position was resolved (for debugging)

    @classmethod
    def create_exact(
        cls,
        position_type: str,
        line_number: Optional[int],
        line_range: Optional[Tuple[int, int]],
        char_range: Optional[Tuple[int, int]],
        matched_text: Optional[str],
        original: CommentPosition
    ) -> 'ResolvedPosition':
        """
        Factory for exact resolution (hash matched).

        REQ-tv-d00012-C: Hash match yields EXACT confidence.
        """
        return cls(
            type=position_type,
            confidence=ResolutionConfidence.EXACT.value,
            lineNumber=line_number,
            lineRange=line_range,
            charRange=char_range,
            matchedText=matched_text,
            originalPosition=original,
            resolutionPath="hash_match"
        )

    @classmethod
    def create_approximate(
        cls,
        position_type: str,
        line_number: Optional[int],
        line_range: Optional[Tuple[int, int]],
        char_range: Optional[Tuple[int, int]],
        matched_text: Optional[str],
        original: CommentPosition,
        resolution_path: str
    ) -> 'ResolvedPosition':
        """
        Factory for approximate resolution (fallback succeeded).

        REQ-tv-d00012-D: Fallback resolution yields APPROXIMATE confidence.
        """
        return cls(
            type=position_type,
            confidence=ResolutionConfidence.APPROXIMATE.value,
            lineNumber=line_number,
            lineRange=line_range,
            charRange=char_range,
            matchedText=matched_text,
            originalPosition=original,
            resolutionPath=resolution_path
        )

    @classmethod
    def create_unanchored(cls, original: CommentPosition) -> 'ResolvedPosition':
        """
        Factory for unanchored resolution (all fallbacks failed).

        REQ-tv-d00012-J: When no fallback succeeds, resolve as UNANCHORED
        with original position preserved.
        """
        return cls(
            type=PositionType.GENERAL.value,
            confidence=ResolutionConfidence.UNANCHORED.value,
            lineNumber=None,
            lineRange=None,
            charRange=None,
            matchedText=None,
            originalPosition=original,
            resolutionPath="fallback_exhausted"
        )

    def validate(self) -> Tuple[bool, List[str]]:
        """Validate resolved position fields"""
        errors = []

        if self.type not in [pt.value for pt in PositionType]:
            errors.append(f"Invalid position type: {self.type}")

        if self.confidence not in [cl.value for cl in ResolutionConfidence]:
            errors.append(f"Invalid confidence level: {self.confidence}")

        # Line numbers must be positive if present
        if self.lineNumber is not None and self.lineNumber < 1:
            errors.append("lineNumber must be positive")

        # Line range validation
        if self.lineRange is not None:
            if len(self.lineRange) != 2:
                errors.append("lineRange must be tuple of (start, end)")
            elif self.lineRange[0] < 1 or self.lineRange[1] < self.lineRange[0]:
                errors.append("Invalid lineRange: start must be >= 1 and end >= start")

        # Char range validation
        if self.charRange is not None:
            if len(self.charRange) != 2:
                errors.append("charRange must be tuple of (start, end)")
            elif self.charRange[0] < 0 or self.charRange[1] < self.charRange[0]:
                errors.append("Invalid charRange: start must be >= 0 and end >= start")

        return len(errors) == 0, errors

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        result: Dict[str, Any] = {
            'type': self.type,
            'confidence': self.confidence,
            'resolutionPath': self.resolutionPath,
            'originalPosition': self.originalPosition.to_dict()
        }
        if self.lineNumber is not None:
            result['lineNumber'] = self.lineNumber
        if self.lineRange is not None:
            result['lineRange'] = list(self.lineRange)
        if self.charRange is not None:
            result['charRange'] = list(self.charRange)
        if self.matchedText is not None:
            result['matchedText'] = self.matchedText
        return result

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ResolvedPosition':
        """Create from dictionary (JSON deserialization)"""
        line_range = data.get('lineRange')
        if line_range is not None:
            line_range = tuple(line_range)
        char_range = data.get('charRange')
        if char_range is not None:
            char_range = tuple(char_range)
        return cls(
            type=data['type'],
            confidence=data['confidence'],
            lineNumber=data.get('lineNumber'),
            lineRange=line_range,
            charRange=char_range,
            matchedText=data.get('matchedText'),
            originalPosition=CommentPosition.from_dict(data['originalPosition']),
            resolutionPath=data.get('resolutionPath', 'unknown')
        )


# =============================================================================
# Helper Functions
# =============================================================================

def find_line_in_text(text: str, line_number: int) -> Optional[Tuple[int, int]]:
    """
    Find character range for a specific line in text.

    Args:
        text: The text to search in
        line_number: 1-based line number to find

    Returns:
        Tuple of (start_offset, end_offset) for the line, or None if line doesn't exist.
        end_offset points to the character after the line content (before newline or EOF).
    """
    if not text or line_number < 1:
        return None

    lines = text.split('\n')

    if line_number > len(lines):
        return None

    # Calculate start offset by summing lengths of previous lines + newlines
    start_offset = 0
    for i in range(line_number - 1):
        start_offset += len(lines[i]) + 1  # +1 for newline

    # End offset is start + length of this line
    end_offset = start_offset + len(lines[line_number - 1])

    return (start_offset, end_offset)


def find_context_in_text(text: str, context: str) -> Optional[Tuple[int, int]]:
    """
    Find character range where context appears in text.

    Args:
        text: The text to search in
        context: The substring to find

    Returns:
        Tuple of (start_offset, end_offset) for first occurrence, or None if not found.
    """
    if not text or not context:
        return None

    index = text.find(context)
    if index == -1:
        return None

    return (index, index + len(context))


def find_keyword_occurrence(
    text: str,
    keyword: str,
    occurrence: int
) -> Optional[Tuple[int, int]]:
    """
    Find character range of the Nth occurrence of a keyword.

    REQ-tv-d00012-G: For WORD positions, find the Nth occurrence based on keywordOccurrence.

    Args:
        text: The text to search in
        keyword: The word/phrase to find
        occurrence: 1-based occurrence index (1 = first, 2 = second, etc.)

    Returns:
        Tuple of (start_offset, end_offset) for the Nth occurrence, or None if not found.
    """
    if not text or not keyword or occurrence < 1:
        return None

    current_occurrence = 0
    start_index = 0

    while start_index < len(text):
        index = text.find(keyword, start_index)
        if index == -1:
            break

        current_occurrence += 1
        if current_occurrence == occurrence:
            return (index, index + len(keyword))

        # Move past this occurrence to find next
        start_index = index + 1

    return None


def get_line_number_from_char_offset(text: str, char_offset: int) -> int:
    """
    Convert character offset to 1-based line number.

    Args:
        text: The text to analyze
        char_offset: 0-based character offset

    Returns:
        1-based line number containing the offset.
    """
    if not text or char_offset <= 0:
        return 1

    # Clamp offset to text length
    char_offset = min(char_offset, len(text) - 1)

    # Count newlines before offset
    newline_count = text[:char_offset + 1].count('\n')

    # Special case: if offset is exactly on a newline, it belongs to previous line
    if char_offset < len(text) and text[char_offset] == '\n':
        return newline_count  # Don't add 1 since we're ON the newline

    return newline_count + 1


def get_line_range_from_char_range(
    text: str,
    start: int,
    end: int
) -> Tuple[int, int]:
    """
    Convert character range to line range.

    Args:
        text: The text to analyze
        start: Start character offset (0-based, inclusive)
        end: End character offset (0-based, exclusive)

    Returns:
        Tuple of (start_line, end_line) as 1-based line numbers.
    """
    start_line = get_line_number_from_char_offset(text, start)
    # Handle empty range (start == end) - both on same line
    if start >= end:
        return (start_line, start_line)
    # end is exclusive, so use end-1 for the line calculation
    end_line = get_line_number_from_char_offset(text, end - 1)

    return (start_line, end_line)


def get_total_lines(text: str) -> int:
    """
    Get total number of lines in text.

    Args:
        text: The text to analyze

    Returns:
        Total line count (minimum 1 for non-empty text, 0 for empty)
    """
    if not text:
        return 0
    return text.count('\n') + 1


# =============================================================================
# Core Resolution Functions
# =============================================================================

def resolve_position(
    position: CommentPosition,
    content: str,
    current_hash: str
) -> ResolvedPosition:
    """
    Resolve a comment position against current requirement content.

    REQ-tv-d00012-A: Resolves CommentPosition anchors to current document coordinates.

    This is the main entry point for position resolution. It determines
    the current location of a comment anchor, accounting for potential
    content drift since the comment was created.

    Args:
        position: The original CommentPosition from the comment/thread
        content: Current requirement body text
        current_hash: Current 8-character hash of the requirement

    Returns:
        ResolvedPosition with confidence level and resolved coordinates

    Resolution Strategy:
        1. If hash matches: Return exact position based on original type
        2. If hash differs, try fallbacks in order:
           a. lineNumber (if within valid range)
           b. fallbackContext (substring search)
           c. keyword at keywordOccurrence
           d. Fall back to general (unanchored)
    """
    # Handle empty text edge case
    if not content:
        return ResolvedPosition.create_unanchored(position)

    # REQ-tv-d00012-H: GENERAL positions always resolve with EXACT confidence
    if position.type == PositionType.GENERAL.value:
        return _resolve_general(position, content)

    # REQ-tv-d00012-C: Check if hash matches (exact resolution) - case insensitive
    hash_matches = position.hashWhenCreated.lower() == current_hash.lower()

    if hash_matches:
        return _resolve_exact(position, content)
    else:
        # REQ-tv-d00012-D: Hash differs, attempt fallback resolution
        return _resolve_with_fallback(position, content)


def _resolve_general(
    position: CommentPosition,
    content: str
) -> ResolvedPosition:
    """
    Resolve GENERAL position type.

    REQ-tv-d00012-H: GENERAL positions always resolve with EXACT confidence
    since they apply to the entire requirement.
    """
    total_lines = get_total_lines(content)
    return ResolvedPosition.create_exact(
        position_type=PositionType.GENERAL.value,
        line_number=None,
        line_range=(1, total_lines) if total_lines > 0 else None,
        char_range=(0, len(content)) if content else None,
        matched_text=None,
        original=position
    )


def _resolve_exact(
    position: CommentPosition,
    content: str
) -> ResolvedPosition:
    """
    Resolve position when hash matches (exact confidence).

    REQ-tv-d00012-C: When the document hash matches, the position resolves
    with EXACT confidence using stored coordinates.

    Trusts the original position data since content hasn't changed.
    """
    pos_type = position.type

    if pos_type == PositionType.GENERAL.value:
        return _resolve_general(position, content)

    elif pos_type == PositionType.LINE.value:
        line_num = position.lineNumber
        char_range = find_line_in_text(content, line_num)
        matched_text = None

        if char_range:
            matched_text = content[char_range[0]:char_range[1]]

        return ResolvedPosition.create_exact(
            position_type=pos_type,
            line_number=line_num,
            line_range=(line_num, line_num) if line_num else None,
            char_range=char_range,
            matched_text=matched_text,
            original=position
        )

    elif pos_type == PositionType.BLOCK.value:
        line_range = position.lineRange
        if line_range:
            start_range = find_line_in_text(content, line_range[0])
            end_range = find_line_in_text(content, line_range[1])

            char_range = None
            matched_text = None
            if start_range and end_range:
                char_range = (start_range[0], end_range[1])
                matched_text = content[char_range[0]:char_range[1]]

            return ResolvedPosition.create_exact(
                position_type=pos_type,
                line_number=line_range[0],  # First line of block
                line_range=line_range,
                char_range=char_range,
                matched_text=matched_text,
                original=position
            )
        else:
            return ResolvedPosition.create_unanchored(position)

    elif pos_type == PositionType.WORD.value:
        keyword = position.keyword
        occurrence = position.keywordOccurrence or 1

        if keyword:
            char_range = find_keyword_occurrence(content, keyword, occurrence)

            line_number = None
            line_range_result = None
            matched_text = keyword if char_range else None

            if char_range:
                line_number = get_line_number_from_char_offset(content, char_range[0])
                line_range_result = get_line_range_from_char_range(
                    content, char_range[0], char_range[1]
                )

            return ResolvedPosition.create_exact(
                position_type=pos_type,
                line_number=line_number,
                line_range=line_range_result,
                char_range=char_range,
                matched_text=matched_text,
                original=position
            )
        else:
            return ResolvedPosition.create_unanchored(position)

    # Unknown type - fall back to unanchored
    return ResolvedPosition.create_unanchored(position)


def _resolve_with_fallback(
    position: CommentPosition,
    content: str
) -> ResolvedPosition:
    """
    Resolve position when hash differs (approximate confidence).

    REQ-tv-d00012-D: When document hash differs, attempt fallback resolution.
    REQ-tv-d00012-E: For LINE positions, search for context string.
    REQ-tv-d00012-F: For BLOCK positions, search for context and expand.
    REQ-tv-d00012-G: For WORD positions, search for keyword at Nth occurrence.

    Tries fallback strategies in order:
    1. lineNumber (if within valid range)
    2. fallbackContext (substring search)
    3. keyword at keywordOccurrence
    4. Unanchored (general)
    """
    total_lines = get_total_lines(content)

    # Strategy 1: Try lineNumber if available and in range
    # For block positions, also try the first line of lineRange
    line_to_try = position.lineNumber
    if line_to_try is None and position.lineRange is not None:
        line_to_try = position.lineRange[0]

    if line_to_try is not None:
        if 1 <= line_to_try <= total_lines:
            char_range = find_line_in_text(content, line_to_try)
            if char_range:
                matched_text = content[char_range[0]:char_range[1]]
                return ResolvedPosition.create_approximate(
                    position_type=PositionType.LINE.value,
                    line_number=line_to_try,
                    line_range=(line_to_try, line_to_try),
                    char_range=char_range,
                    matched_text=matched_text,
                    original=position,
                    resolution_path="fallback_line_number"
                )

    # Strategy 2: Try fallbackContext
    # REQ-tv-d00012-E: For LINE positions, search for context string
    if position.fallbackContext:
        char_range = find_context_in_text(content, position.fallbackContext)
        if char_range:
            line_number = get_line_number_from_char_offset(content, char_range[0])
            line_range = get_line_range_from_char_range(
                content, char_range[0], char_range[1]
            )
            return ResolvedPosition.create_approximate(
                position_type=PositionType.LINE.value,  # Resolved to line
                line_number=line_number,
                line_range=line_range,
                char_range=char_range,
                matched_text=position.fallbackContext,
                original=position,
                resolution_path="fallback_context"
            )

    # Strategy 3: Try keyword occurrence
    # REQ-tv-d00012-G: For WORD positions, search for keyword
    if position.keyword:
        occurrence = position.keywordOccurrence or 1
        char_range = find_keyword_occurrence(content, position.keyword, occurrence)
        if char_range:
            line_number = get_line_number_from_char_offset(content, char_range[0])
            line_range = get_line_range_from_char_range(
                content, char_range[0], char_range[1]
            )
            return ResolvedPosition.create_approximate(
                position_type=PositionType.WORD.value,
                line_number=line_number,
                line_range=line_range,
                char_range=char_range,
                matched_text=position.keyword,
                original=position,
                resolution_path="fallback_keyword"
            )

    # Strategy 4: Fall back to general (unanchored)
    # REQ-tv-d00012-J: When no fallback succeeds, resolve as UNANCHORED
    return ResolvedPosition.create_unanchored(position)
