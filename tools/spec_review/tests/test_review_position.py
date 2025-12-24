#!/usr/bin/env python3
"""
Tests for review_position.py - Position Tracking Module

TDD tests written before implementation.
"""

import pytest
from typing import Tuple, Optional

from tools.spec_review.review_data import CommentPosition, PositionType
from tools.spec_review.review_position import (
    # Enum
    ConfidenceLevel,
    # Data class
    ResolvedPosition,
    # Helper functions
    find_line_in_text,
    find_context_in_text,
    find_keyword_occurrence,
    get_line_number_from_char_offset,
    get_line_range_from_char_range,
    get_total_lines,
    # Core function
    resolve_position,
)


# =============================================================================
# Tests for ConfidenceLevel Enum
# =============================================================================

class TestConfidenceLevel:
    """Test ConfidenceLevel enum"""

    def test_confidence_values(self):
        assert ConfidenceLevel.EXACT.value == "exact"
        assert ConfidenceLevel.APPROXIMATE.value == "approximate"
        assert ConfidenceLevel.UNANCHORED.value == "unanchored"


# =============================================================================
# Tests for find_line_in_text
# =============================================================================

class TestFindLineInText:
    """Test find_line_in_text helper function"""

    def test_first_line(self):
        assert find_line_in_text("abc\ndef", 1) == (0, 3)

    def test_second_line(self):
        assert find_line_in_text("abc\ndef", 2) == (4, 7)

    def test_third_line(self):
        assert find_line_in_text("abc\ndef\nghi", 3) == (8, 11)

    def test_single_line_no_newline(self):
        assert find_line_in_text("abc", 1) == (0, 3)

    def test_empty_text(self):
        assert find_line_in_text("", 1) is None

    def test_line_out_of_range(self):
        assert find_line_in_text("abc", 2) is None

    def test_zero_line_number(self):
        assert find_line_in_text("abc", 0) is None

    def test_negative_line_number(self):
        assert find_line_in_text("abc", -1) is None

    def test_empty_line_in_middle(self):
        # "abc\n\ndef" - line 2 is empty
        result = find_line_in_text("abc\n\ndef", 2)
        assert result == (4, 4)  # Empty line has same start and end

    def test_trailing_newline(self):
        # "abc\n" - has trailing newline
        assert find_line_in_text("abc\n", 1) == (0, 3)
        assert find_line_in_text("abc\n", 2) == (4, 4)  # Empty last line

    def test_long_lines(self):
        text = "a" * 100 + "\n" + "b" * 50
        assert find_line_in_text(text, 1) == (0, 100)
        assert find_line_in_text(text, 2) == (101, 151)


# =============================================================================
# Tests for find_context_in_text
# =============================================================================

class TestFindContextInText:
    """Test find_context_in_text helper function"""

    def test_found_at_start(self):
        assert find_context_in_text("hello world", "hello") == (0, 5)

    def test_found_in_middle(self):
        assert find_context_in_text("hello world", "o wo") == (4, 8)

    def test_found_at_end(self):
        assert find_context_in_text("hello world", "world") == (6, 11)

    def test_not_found(self):
        assert find_context_in_text("hello world", "xyz") is None

    def test_empty_context(self):
        assert find_context_in_text("hello", "") is None

    def test_empty_text(self):
        assert find_context_in_text("", "hello") is None

    def test_both_empty(self):
        assert find_context_in_text("", "") is None

    def test_first_of_multiple(self):
        # Should return first occurrence
        assert find_context_in_text("abc abc abc", "abc") == (0, 3)

    def test_case_sensitive(self):
        assert find_context_in_text("Hello World", "hello") is None
        assert find_context_in_text("Hello World", "Hello") == (0, 5)

    def test_context_spans_lines(self):
        assert find_context_in_text("hello\nworld", "o\nw") == (4, 7)

    def test_entire_text(self):
        assert find_context_in_text("abc", "abc") == (0, 3)


# =============================================================================
# Tests for find_keyword_occurrence
# =============================================================================

class TestFindKeywordOccurrence:
    """Test find_keyword_occurrence helper function"""

    def test_first_occurrence(self):
        assert find_keyword_occurrence("cat dog cat", "cat", 1) == (0, 3)

    def test_second_occurrence(self):
        assert find_keyword_occurrence("cat dog cat", "cat", 2) == (8, 11)

    def test_third_occurrence(self):
        assert find_keyword_occurrence("cat cat cat", "cat", 3) == (8, 11)

    def test_occurrence_not_found(self):
        # Only 2 occurrences, asking for 3rd
        assert find_keyword_occurrence("cat dog cat", "cat", 3) is None

    def test_keyword_not_found(self):
        assert find_keyword_occurrence("cat dog", "bird", 1) is None

    def test_zero_occurrence(self):
        assert find_keyword_occurrence("cat", "cat", 0) is None

    def test_negative_occurrence(self):
        assert find_keyword_occurrence("cat", "cat", -1) is None

    def test_empty_keyword(self):
        assert find_keyword_occurrence("cat dog", "", 1) is None

    def test_empty_text(self):
        assert find_keyword_occurrence("", "cat", 1) is None

    def test_overlapping_not_counted(self):
        # "aaa" - searching for "aa", there's only 1 non-overlapping
        # But find() starts after index+1, so we get both
        assert find_keyword_occurrence("aaa", "aa", 1) == (0, 2)
        assert find_keyword_occurrence("aaa", "aa", 2) == (1, 3)

    def test_keyword_with_spaces(self):
        assert find_keyword_occurrence("the system SHALL do", "SHALL", 1) == (11, 16)

    def test_case_sensitive(self):
        assert find_keyword_occurrence("Cat cat CAT", "cat", 1) == (4, 7)
        assert find_keyword_occurrence("Cat cat CAT", "Cat", 1) == (0, 3)


# =============================================================================
# Tests for get_line_number_from_char_offset
# =============================================================================

class TestGetLineNumberFromCharOffset:
    """Test get_line_number_from_char_offset helper function"""

    def test_first_char(self):
        assert get_line_number_from_char_offset("abc\ndef", 0) == 1

    def test_last_char_first_line(self):
        assert get_line_number_from_char_offset("abc\ndef", 2) == 1

    def test_newline_char(self):
        # Newline belongs to the line it terminates
        assert get_line_number_from_char_offset("abc\ndef", 3) == 1

    def test_first_char_second_line(self):
        assert get_line_number_from_char_offset("abc\ndef", 4) == 2

    def test_empty_text(self):
        assert get_line_number_from_char_offset("", 0) == 1

    def test_negative_offset(self):
        assert get_line_number_from_char_offset("abc", -1) == 1

    def test_zero_offset(self):
        assert get_line_number_from_char_offset("abc", 0) == 1

    def test_beyond_text(self):
        # Should clamp to last valid position
        result = get_line_number_from_char_offset("abc", 100)
        assert result == 1

    def test_multiline_third_line(self):
        text = "line1\nline2\nline3"
        assert get_line_number_from_char_offset(text, 12) == 3


# =============================================================================
# Tests for get_line_range_from_char_range
# =============================================================================

class TestGetLineRangeFromCharRange:
    """Test get_line_range_from_char_range helper function"""

    def test_single_line(self):
        assert get_line_range_from_char_range("abc\ndef", 0, 3) == (1, 1)

    def test_spans_two_lines(self):
        assert get_line_range_from_char_range("abc\ndef", 0, 7) == (1, 2)

    def test_second_line_only(self):
        assert get_line_range_from_char_range("abc\ndef", 4, 7) == (2, 2)

    def test_spans_three_lines(self):
        text = "line1\nline2\nline3"
        assert get_line_range_from_char_range(text, 0, 17) == (1, 3)

    def test_empty_range(self):
        # Start and end are same
        assert get_line_range_from_char_range("abc\ndef", 4, 4) == (2, 2)


# =============================================================================
# Tests for get_total_lines
# =============================================================================

class TestGetTotalLines:
    """Test get_total_lines helper function"""

    def test_empty_text(self):
        assert get_total_lines("") == 0

    def test_single_line(self):
        assert get_total_lines("abc") == 1

    def test_two_lines(self):
        assert get_total_lines("abc\ndef") == 2

    def test_three_lines(self):
        assert get_total_lines("a\nb\nc") == 3

    def test_trailing_newline(self):
        # Trailing newline creates an empty last line
        assert get_total_lines("abc\n") == 2

    def test_only_newlines(self):
        assert get_total_lines("\n\n") == 3


# =============================================================================
# Tests for ResolvedPosition
# =============================================================================

class TestResolvedPosition:
    """Test ResolvedPosition dataclass"""

    def test_create_exact(self):
        pos = CommentPosition.create_line("abc12345", 5)
        resolved = ResolvedPosition.create_exact(
            position_type="line",
            line_number=5,
            line_range=(5, 5),
            char_range=(20, 30),
            matched_text="some text",
            original=pos
        )
        assert resolved.confidence == "exact"
        assert resolved.lineNumber == 5
        assert resolved.resolutionPath == "hash_match"

    def test_create_approximate(self):
        pos = CommentPosition.create_line("abc12345", 5)
        resolved = ResolvedPosition.create_approximate(
            position_type="line",
            line_number=3,
            line_range=(3, 3),
            char_range=(10, 20),
            matched_text="fallback text",
            original=pos,
            resolution_path="fallback_context"
        )
        assert resolved.confidence == "approximate"
        assert resolved.resolutionPath == "fallback_context"

    def test_create_unanchored(self):
        pos = CommentPosition.create_word("abc12345", "SHALL", 1)
        resolved = ResolvedPosition.create_unanchored(pos)
        assert resolved.confidence == "unanchored"
        assert resolved.type == "general"
        assert resolved.lineNumber is None
        assert resolved.resolutionPath == "fallback_exhausted"

    def test_validate_success(self):
        pos = CommentPosition.create_line("abc12345", 5)
        resolved = ResolvedPosition.create_exact(
            position_type="line",
            line_number=5,
            line_range=(5, 5),
            char_range=(0, 10),
            matched_text="text",
            original=pos
        )
        valid, errors = resolved.validate()
        assert valid is True
        assert errors == []

    def test_validate_invalid_type(self):
        pos = CommentPosition.create_line("abc12345", 5)
        resolved = ResolvedPosition(
            type="invalid",
            confidence="exact",
            lineNumber=5,
            lineRange=(5, 5),
            charRange=(0, 10),
            matchedText="text",
            originalPosition=pos,
            resolutionPath="test"
        )
        valid, errors = resolved.validate()
        assert valid is False
        assert any("type" in e.lower() for e in errors)

    def test_validate_invalid_line_range(self):
        pos = CommentPosition.create_line("abc12345", 5)
        resolved = ResolvedPosition(
            type="line",
            confidence="exact",
            lineNumber=5,
            lineRange=(5, 3),  # Invalid: end < start
            charRange=(0, 10),
            matchedText="text",
            originalPosition=pos,
            resolutionPath="test"
        )
        valid, errors = resolved.validate()
        assert valid is False
        assert any("lineRange" in e for e in errors)

    def test_to_dict(self):
        pos = CommentPosition.create_line("abc12345", 5)
        resolved = ResolvedPosition.create_exact(
            position_type="line",
            line_number=5,
            line_range=(5, 5),
            char_range=(10, 20),
            matched_text="text",
            original=pos
        )
        d = resolved.to_dict()
        assert d["type"] == "line"
        assert d["confidence"] == "exact"
        assert d["lineNumber"] == 5
        assert d["lineRange"] == [5, 5]  # Tuple becomes list
        assert d["charRange"] == [10, 20]
        assert "originalPosition" in d

    def test_to_dict_omits_none(self):
        pos = CommentPosition.create_general("abc12345")
        resolved = ResolvedPosition.create_unanchored(pos)
        d = resolved.to_dict()
        assert "lineNumber" not in d
        assert "lineRange" not in d
        assert "charRange" not in d
        assert "matchedText" not in d

    def test_from_dict(self):
        pos = CommentPosition.create_line("abc12345", 5)
        original = ResolvedPosition.create_exact(
            position_type="line",
            line_number=5,
            line_range=(5, 5),
            char_range=(10, 20),
            matched_text="text",
            original=pos
        )
        d = original.to_dict()
        restored = ResolvedPosition.from_dict(d)
        assert restored.type == original.type
        assert restored.confidence == original.confidence
        assert restored.lineNumber == original.lineNumber
        assert restored.lineRange == original.lineRange
        assert restored.charRange == original.charRange


# =============================================================================
# Tests for resolve_position - Core Function
# =============================================================================

class TestResolvePosition:
    """Test resolve_position core function"""

    # --- Exact resolution (hash matches) ---

    def test_exact_hash_match_general(self):
        """When hash matches, general position resolves to whole REQ"""
        pos = CommentPosition.create_general("abc12345")
        result = resolve_position(pos, "line1\nline2\nline3", "abc12345")
        assert result.confidence == "exact"
        assert result.type == "general"
        assert result.lineRange == (1, 3)

    def test_exact_hash_match_line(self):
        """When hash matches, line position resolves exactly"""
        pos = CommentPosition.create_line("abc12345", 2)
        result = resolve_position(pos, "line1\nline2\nline3", "abc12345")
        assert result.confidence == "exact"
        assert result.type == "line"
        assert result.lineNumber == 2
        assert result.matchedText == "line2"

    def test_exact_hash_match_block(self):
        """When hash matches, block position resolves exactly"""
        pos = CommentPosition.create_block("abc12345", 1, 2)
        result = resolve_position(pos, "line1\nline2\nline3", "abc12345")
        assert result.confidence == "exact"
        assert result.type == "block"
        assert result.lineRange == (1, 2)
        assert "line1" in result.matchedText
        assert "line2" in result.matchedText

    def test_exact_hash_match_word(self):
        """When hash matches, word position resolves exactly"""
        pos = CommentPosition.create_word("abc12345", "SHALL", 1)
        text = "The system SHALL do this and SHALL do that"
        result = resolve_position(pos, text, "abc12345")
        assert result.confidence == "exact"
        assert result.type == "word"
        assert result.matchedText == "SHALL"
        # First occurrence of SHALL
        assert result.charRange == (11, 16)

    def test_exact_hash_match_word_second_occurrence(self):
        """Word position with second occurrence"""
        pos = CommentPosition.create_word("abc12345", "SHALL", 2)
        text = "The system SHALL do this and SHALL do that"
        result = resolve_position(pos, text, "abc12345")
        assert result.confidence == "exact"
        # Second occurrence of SHALL
        assert result.charRange == (29, 34)

    def test_exact_hash_case_insensitive(self):
        """Hash comparison should be case insensitive"""
        pos = CommentPosition.create_general("ABC12345")
        result = resolve_position(pos, "text", "abc12345")
        assert result.confidence == "exact"

    # --- Fallback resolution (hash differs) ---

    def test_fallback_to_line_number(self):
        """When hash differs but line is valid, use line fallback"""
        pos = CommentPosition.create_line("abc12345", 2)
        result = resolve_position(pos, "new1\nnew2\nnew3", "def67890")
        assert result.confidence == "approximate"
        assert result.lineNumber == 2
        assert result.resolutionPath == "fallback_line_number"

    def test_fallback_line_out_of_range_to_context(self):
        """When line out of range, try context fallback"""
        pos = CommentPosition.create_line("abc12345", 10, context="specific text")
        result = resolve_position(pos, "has specific text here", "def67890")
        assert result.confidence == "approximate"
        assert result.resolutionPath == "fallback_context"
        assert result.matchedText == "specific text"

    def test_fallback_context_not_found_to_keyword(self):
        """When context not found, try keyword fallback"""
        pos = CommentPosition(
            type="line",
            hashWhenCreated="abc12345",
            lineNumber=100,  # Out of range
            fallbackContext="not found text",
            keyword="SHALL",
            keywordOccurrence=1
        )
        result = resolve_position(pos, "The system SHALL work", "def67890")
        assert result.confidence == "approximate"
        assert result.resolutionPath == "fallback_keyword"
        assert result.matchedText == "SHALL"

    def test_fallback_all_fail_unanchored(self):
        """When all fallbacks fail, return unanchored"""
        pos = CommentPosition.create_line("abc12345", 100)  # Line way out of range
        result = resolve_position(pos, "short", "def67890")
        assert result.confidence == "unanchored"
        assert result.type == "general"
        assert result.resolutionPath == "fallback_exhausted"

    def test_fallback_for_block_position(self):
        """Block position falls back when hash differs"""
        pos = CommentPosition.create_block("abc12345", 1, 2)
        # New text has only 2 lines
        result = resolve_position(pos, "new1\nnew2", "def67890")
        # Should try line fallback (uses first line of block)
        assert result.confidence == "approximate"

    def test_fallback_for_word_position(self):
        """Word position with fallback when hash differs"""
        pos = CommentPosition.create_word("abc12345", "SHALL", 1)
        result = resolve_position(pos, "This SHALL work", "def67890")
        assert result.confidence == "approximate"
        assert result.resolutionPath == "fallback_keyword"

    # --- Edge cases ---

    def test_empty_text_returns_unanchored(self):
        """Empty requirement body returns unanchored"""
        pos = CommentPosition.create_line("abc12345", 1)
        result = resolve_position(pos, "", "def67890")
        assert result.confidence == "unanchored"

    def test_word_not_found_in_text(self):
        """Word position when word doesn't exist"""
        pos = CommentPosition.create_word("abc12345", "NONEXISTENT", 1)
        result = resolve_position(pos, "text without the word", "abc12345")
        # Even with hash match, if word isn't found, should handle gracefully
        assert result.charRange is None or result.confidence != "exact"

    def test_preserves_original_position(self):
        """Resolved position contains original for reference"""
        pos = CommentPosition.create_line("abc12345", 5, context="context")
        result = resolve_position(pos, "line1\nline2", "def67890")
        assert result.originalPosition is pos
        assert result.originalPosition.lineNumber == 5
        assert result.originalPosition.fallbackContext == "context"


# =============================================================================
# Integration Tests
# =============================================================================

class TestIntegration:
    """Integration tests for position resolution"""

    def test_full_resolution_workflow(self):
        """Test complete resolution with serialization"""
        # Create position
        pos = CommentPosition.create_line("abc12345", 2, context="requirement body")

        # Original text
        original_text = "# Title\nThe requirement body here\n# Next section"

        # Resolve with matching hash
        result1 = resolve_position(pos, original_text, "abc12345")
        assert result1.confidence == "exact"
        assert result1.lineNumber == 2

        # Modified text (hash changed)
        modified_text = "# New Title\nThe requirement body here with changes\n# Footer"

        # Resolve with different hash - should use fallback
        result2 = resolve_position(pos, modified_text, "xyz98765")
        # Line 2 still exists, should fallback to it
        assert result2.confidence == "approximate"

        # Serialize and restore
        d = result2.to_dict()
        restored = ResolvedPosition.from_dict(d)
        assert restored.confidence == result2.confidence
        assert restored.lineNumber == result2.lineNumber

    def test_multiline_requirement(self):
        """Test resolution in a realistic REQ body"""
        req_body = """The system SHALL provide user authentication.

**Rationale**: Security is paramount.

The implementation MUST use industry standard protocols.

*End* *Authentication* | **Hash**: abc12345"""

        pos = CommentPosition.create_word("abc12345", "SHALL", 1)
        result = resolve_position(pos, req_body, "abc12345")

        assert result.confidence == "exact"
        assert result.matchedText == "SHALL"
        assert result.lineNumber == 1  # SHALL is on first line
