#!/usr/bin/env python3
"""
Tests for Position Resolution System

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00012: Position Resolution

This test file follows TDD (Test-Driven Development) methodology.
Each test references the specific assertion from REQ-tv-d00012 that it verifies.
"""

import json
from dataclasses import is_dataclass

import pytest


# =============================================================================
# Test Imports (will fail initially - RED phase)
# =============================================================================

def import_position_module():
    """Helper to import position module - enables better error messages during TDD."""
    from trace_view.review.position import (
        # Enums
        ResolutionConfidence,
        # Data classes
        ResolvedPosition,
        # Functions
        resolve_position,
        # Helper functions
        find_line_in_text,
        find_context_in_text,
        find_keyword_occurrence,
        get_line_number_from_char_offset,
        get_line_range_from_char_range,
        get_total_lines,
    )
    return {
        'ResolutionConfidence': ResolutionConfidence,
        'ResolvedPosition': ResolvedPosition,
        'resolve_position': resolve_position,
        'find_line_in_text': find_line_in_text,
        'find_context_in_text': find_context_in_text,
        'find_keyword_occurrence': find_keyword_occurrence,
        'get_line_number_from_char_offset': get_line_number_from_char_offset,
        'get_line_range_from_char_range': get_line_range_from_char_range,
        'get_total_lines': get_total_lines,
    }


def import_models():
    """Helper to import models module."""
    from trace_view.review.models import CommentPosition, PositionType
    return {
        'CommentPosition': CommentPosition,
        'PositionType': PositionType,
    }


# =============================================================================
# Assertion A: Position Resolution System Resolves Anchors
# =============================================================================

class TestPositionResolutionBasics:
    """REQ-tv-d00012-A: The position resolution system SHALL resolve
    CommentPosition anchors to current document coordinates."""

    def test_resolve_position_function_exists(self):
        """REQ-tv-d00012-A: resolve_position function exists"""
        p = import_position_module()
        assert callable(p['resolve_position'])

    def test_resolve_position_returns_resolved_position(self):
        """REQ-tv-d00012-A: resolve_position returns ResolvedPosition"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_general('12345678')
        content = "Line 1\nLine 2\nLine 3"

        result = p['resolve_position'](position, content, '12345678')

        assert isinstance(result, p['ResolvedPosition'])

    def test_resolve_position_handles_line_type(self):
        """REQ-tv-d00012-A: resolve_position handles LINE position type"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 2, 'Line 2')
        content = "Line 1\nLine 2\nLine 3"

        result = p['resolve_position'](position, content, '12345678')

        assert result.lineNumber == 2

    def test_resolve_position_handles_block_type(self):
        """REQ-tv-d00012-A: resolve_position handles BLOCK position type"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_block('12345678', 1, 3)
        content = "Line 1\nLine 2\nLine 3"

        result = p['resolve_position'](position, content, '12345678')

        assert result.lineRange == (1, 3)

    def test_resolve_position_handles_word_type(self):
        """REQ-tv-d00012-A: resolve_position handles WORD position type"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_word('12345678', 'SHALL', 1)
        content = "The system SHALL do this.\nIt SHALL also do that."

        result = p['resolve_position'](position, content, '12345678')

        assert result.matchedText == 'SHALL'


# =============================================================================
# Assertion B: Confidence Levels
# =============================================================================

class TestResolutionConfidenceLevels:
    """REQ-tv-d00012-B: ResolvedPosition SHALL indicate confidence level:
    EXACT (hash matches), APPROXIMATE (fallback matched), or UNANCHORED (no match found)."""

    def test_resolution_confidence_is_string_enum(self):
        """REQ-tv-d00012-B: ResolutionConfidence is a string enum"""
        p = import_position_module()
        ResolutionConfidence = p['ResolutionConfidence']

        assert issubclass(ResolutionConfidence, str)

    def test_resolution_confidence_has_exact(self):
        """REQ-tv-d00012-B: ResolutionConfidence has EXACT value"""
        p = import_position_module()
        ResolutionConfidence = p['ResolutionConfidence']

        assert ResolutionConfidence.EXACT == "exact"

    def test_resolution_confidence_has_approximate(self):
        """REQ-tv-d00012-B: ResolutionConfidence has APPROXIMATE value"""
        p = import_position_module()
        ResolutionConfidence = p['ResolutionConfidence']

        assert ResolutionConfidence.APPROXIMATE == "approximate"

    def test_resolution_confidence_has_unanchored(self):
        """REQ-tv-d00012-B: ResolutionConfidence has UNANCHORED value"""
        p = import_position_module()
        ResolutionConfidence = p['ResolutionConfidence']

        assert ResolutionConfidence.UNANCHORED == "unanchored"

    def test_resolved_position_has_confidence_field(self):
        """REQ-tv-d00012-B: ResolvedPosition has confidence field"""
        p = import_position_module()

        assert is_dataclass(p['ResolvedPosition'])


# =============================================================================
# Assertion C: Exact Resolution When Hash Matches
# =============================================================================

class TestExactResolutionHashMatch:
    """REQ-tv-d00012-C: When the document hash matches the position's
    hashWhenCreated, the position SHALL resolve with EXACT confidence
    using stored coordinates."""

    def test_exact_resolution_when_hash_matches(self):
        """REQ-tv-d00012-C: Hash match yields EXACT confidence"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 2)
        content = "Line 1\nLine 2\nLine 3"
        current_hash = '12345678'  # Matches

        result = p['resolve_position'](position, content, current_hash)

        assert result.confidence == 'exact'

    def test_exact_resolution_uses_stored_line_number(self):
        """REQ-tv-d00012-C: Exact resolution uses original lineNumber"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 5)
        content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"

        result = p['resolve_position'](position, content, '12345678')

        assert result.lineNumber == 5
        assert result.confidence == 'exact'

    def test_exact_resolution_uses_stored_line_range(self):
        """REQ-tv-d00012-C: Exact resolution uses original lineRange"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_block('12345678', 2, 4)
        content = "L1\nL2\nL3\nL4\nL5"

        result = p['resolve_position'](position, content, '12345678')

        assert result.lineRange == (2, 4)
        assert result.confidence == 'exact'

    def test_exact_resolution_case_insensitive_hash(self):
        """REQ-tv-d00012-C: Hash comparison is case insensitive"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('abcdef12', 1)
        content = "Line 1"

        result = p['resolve_position'](position, content, 'ABCDEF12')

        assert result.confidence == 'exact'

    def test_exact_resolution_path_is_hash_match(self):
        """REQ-tv-d00012-C: Exact resolution has resolutionPath 'hash_match'"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 1)
        content = "Line 1"

        result = p['resolve_position'](position, content, '12345678')

        assert result.resolutionPath == 'hash_match'


# =============================================================================
# Assertion D: Fallback Resolution When Hash Differs
# =============================================================================

class TestFallbackResolutionHashDiffers:
    """REQ-tv-d00012-D: When the document hash differs, the system SHALL
    attempt fallback resolution using the fallbackContext field."""

    def test_hash_mismatch_triggers_fallback(self):
        """REQ-tv-d00012-D: Hash mismatch triggers fallback resolution"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 2, 'specific context'
        )
        content = "Line 1\nspecific context\nLine 3"
        different_hash = 'aaaabbbb'

        result = p['resolve_position'](position, content, different_hash)

        # Should attempt fallback, not exact
        assert result.confidence != 'exact' or result.resolutionPath != 'hash_match'

    def test_fallback_uses_fallback_context(self):
        """REQ-tv-d00012-D: Fallback uses fallbackContext to find position"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 10, 'unique text marker'
        )
        # Content changed, original line 10 is now at line 3
        content = "Line 1\nLine 2\nunique text marker\nLine 4"

        result = p['resolve_position'](position, content, 'different')

        # Should find the context at new location
        assert result.lineNumber == 3 or result.matchedText == 'unique text marker'

    def test_fallback_resolution_is_approximate(self):
        """REQ-tv-d00012-D: Successful fallback yields APPROXIMATE confidence"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 10, 'findable context'
        )
        content = "Line 1\nfindable context\nLine 3"

        result = p['resolve_position'](position, content, 'different')

        assert result.confidence == 'approximate'


# =============================================================================
# Assertion E: LINE Position Fallback Resolution
# =============================================================================

class TestLinePositionFallback:
    """REQ-tv-d00012-E: For LINE positions, fallback resolution SHALL search
    for the context string and return the matching line number."""

    def test_line_fallback_finds_context_line(self):
        """REQ-tv-d00012-E: LINE fallback finds line containing context"""
        p = import_position_module()
        m = import_models()

        # Original line 10 is out of range, so fallback will use context
        position = m['CommentPosition'].create_line(
            '12345678', 10, 'target line content'
        )
        content = "First line\nSecond line\ntarget line content\nFourth line"

        result = p['resolve_position'](position, content, 'different')

        assert result.lineNumber == 3  # Line containing the context
        assert result.resolutionPath == 'fallback_context'

    def test_line_fallback_returns_correct_resolution_path(self):
        """REQ-tv-d00012-E: LINE fallback has appropriate resolutionPath"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 1, 'searchable text'
        )
        content = "Line 1\nsearchable text\nLine 3"

        result = p['resolve_position'](position, content, 'different')

        assert 'fallback' in result.resolutionPath.lower()

    def test_line_fallback_first_tries_original_line_number(self):
        """REQ-tv-d00012-E: LINE fallback tries original lineNumber first if valid"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 2, None  # No fallback context
        )
        content = "Line 1\nLine 2\nLine 3"

        result = p['resolve_position'](position, content, 'different')

        # Should still resolve to line 2 if it's in valid range
        assert result.lineNumber == 2
        assert result.confidence == 'approximate'


# =============================================================================
# Assertion F: BLOCK Position Fallback Resolution
# =============================================================================

class TestBlockPositionFallback:
    """REQ-tv-d00012-F: For BLOCK positions, fallback resolution SHALL search
    for the context and expand to include the original block size."""

    def test_block_fallback_finds_context_and_expands(self):
        """REQ-tv-d00012-F: BLOCK fallback finds context and expands to block size"""
        p = import_position_module()
        m = import_models()

        # Original block was lines 1-3 (3 lines)
        position = m['CommentPosition'].create_block(
            '12345678', 1, 3, 'start of block'
        )
        content = "Line 1\nLine 2\nstart of block\nLine 4\nLine 5"

        result = p['resolve_position'](position, content, 'different')

        # Should find context and attempt to match
        assert result.lineNumber is not None or result.lineRange is not None

    def test_block_fallback_preserves_approximate_confidence(self):
        """REQ-tv-d00012-F: BLOCK fallback yields APPROXIMATE confidence"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_block(
            '12345678', 1, 2, 'block marker'
        )
        content = "Line 1\nblock marker\nLine 3"

        result = p['resolve_position'](position, content, 'different')

        assert result.confidence == 'approximate'


# =============================================================================
# Assertion G: WORD Position Fallback Resolution
# =============================================================================

class TestWordPositionFallback:
    """REQ-tv-d00012-G: For WORD positions, fallback resolution SHALL search
    for the keyword and return the Nth occurrence based on keywordOccurrence."""

    def test_word_fallback_finds_keyword(self):
        """REQ-tv-d00012-G: WORD fallback finds keyword in document"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_word(
            '12345678', 'SHALL', 1
        )
        content = "The system SHALL do this."

        result = p['resolve_position'](position, content, 'different')

        assert result.matchedText == 'SHALL'

    def test_word_fallback_finds_nth_occurrence(self):
        """REQ-tv-d00012-G: WORD fallback finds correct occurrence"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_word(
            '12345678', 'SHALL', 2  # Second occurrence
        )
        content = "First SHALL here.\nSecond SHALL here.\nThird SHALL here."

        result = p['resolve_position'](position, content, 'different')

        # Should find the second occurrence
        assert result.matchedText == 'SHALL'
        # Line number should be 2 (second line)
        assert result.lineNumber == 2

    def test_word_fallback_with_nonexistent_occurrence(self):
        """REQ-tv-d00012-G: WORD fallback handles missing occurrence gracefully"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_word(
            '12345678', 'SHALL', 5  # Fifth occurrence (doesn't exist)
        )
        content = "First SHALL here.\nSecond SHALL here."

        result = p['resolve_position'](position, content, 'different')

        # Should be unanchored since 5th occurrence doesn't exist
        assert result.confidence == 'unanchored'


# =============================================================================
# Assertion H: GENERAL Position Resolution
# =============================================================================

class TestGeneralPositionResolution:
    """REQ-tv-d00012-H: GENERAL positions SHALL always resolve with EXACT
    confidence since they apply to the entire requirement."""

    def test_general_position_always_exact(self):
        """REQ-tv-d00012-H: GENERAL position always resolves with EXACT"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_general('12345678')
        content = "Any content here"

        # Even with different hash, GENERAL should be exact
        result = p['resolve_position'](position, content, 'different')

        assert result.confidence == 'exact'

    def test_general_position_covers_whole_document(self):
        """REQ-tv-d00012-H: GENERAL position covers entire document"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_general('12345678')
        content = "Line 1\nLine 2\nLine 3"

        result = p['resolve_position'](position, content, '12345678')

        # Should cover all lines
        assert result.lineRange == (1, 3)

    def test_general_position_char_range_covers_all(self):
        """REQ-tv-d00012-H: GENERAL position charRange covers entire content"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_general('12345678')
        content = "Complete document content"

        result = p['resolve_position'](position, content, '12345678')

        assert result.charRange == (0, len(content))


# =============================================================================
# Assertion I: Resolution Path Description
# =============================================================================

class TestResolutionPathDescription:
    """REQ-tv-d00012-I: ResolvedPosition SHALL include a resolutionPath field
    describing which fallback strategy was used."""

    def test_resolution_path_for_hash_match(self):
        """REQ-tv-d00012-I: Hash match has resolutionPath 'hash_match'"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 1)
        content = "Line 1"

        result = p['resolve_position'](position, content, '12345678')

        assert result.resolutionPath == 'hash_match'

    def test_resolution_path_for_fallback_line_number(self):
        """REQ-tv-d00012-I: Line number fallback has descriptive path"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 2)
        content = "Line 1\nLine 2\nLine 3"

        result = p['resolve_position'](position, content, 'different')

        assert 'fallback' in result.resolutionPath.lower()

    def test_resolution_path_for_fallback_context(self):
        """REQ-tv-d00012-I: Context fallback has descriptive path"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 10, 'findable text'
        )
        content = "Line 1\nfindable text\nLine 3"

        result = p['resolve_position'](position, content, 'different')

        assert 'fallback' in result.resolutionPath.lower()
        assert 'context' in result.resolutionPath.lower()

    def test_resolution_path_for_fallback_keyword(self):
        """REQ-tv-d00012-I: Keyword fallback has descriptive path"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_word(
            '12345678', 'keyword', 1
        )
        content = "The keyword is here"

        result = p['resolve_position'](position, content, 'different')

        assert 'fallback' in result.resolutionPath.lower()
        assert 'keyword' in result.resolutionPath.lower()

    def test_resolution_path_for_unanchored(self):
        """REQ-tv-d00012-I: Unanchored has descriptive path"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 100, 'nonexistent context'
        )
        content = "Short content"

        result = p['resolve_position'](position, content, 'different')

        assert 'fallback' in result.resolutionPath.lower() or 'exhausted' in result.resolutionPath.lower()


# =============================================================================
# Assertion J: Unanchored Resolution
# =============================================================================

class TestUnanchoredResolution:
    """REQ-tv-d00012-J: When no fallback succeeds, the position SHALL resolve
    as UNANCHORED with the original position preserved for manual re-anchoring."""

    def test_unanchored_when_all_fallbacks_fail(self):
        """REQ-tv-d00012-J: UNANCHORED when no fallback succeeds"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 100,  # Line doesn't exist
            'nonexistent context that will not be found'
        )
        content = "Short\ncontent"

        result = p['resolve_position'](position, content, 'different')

        assert result.confidence == 'unanchored'

    def test_unanchored_preserves_original_position(self):
        """REQ-tv-d00012-J: UNANCHORED preserves originalPosition"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 50, 'unfindable'
        )
        content = "Minimal content"

        result = p['resolve_position'](position, content, 'different')

        assert result.originalPosition == position
        assert result.originalPosition.lineNumber == 50

    def test_unanchored_has_null_coordinates(self):
        """REQ-tv-d00012-J: UNANCHORED has null line coordinates"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 999, 'will not find this'
        )
        content = "Small content"

        result = p['resolve_position'](position, content, 'different')

        if result.confidence == 'unanchored':
            assert result.lineNumber is None

    def test_unanchored_with_empty_content(self):
        """REQ-tv-d00012-J: Empty content yields UNANCHORED"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 1)
        content = ""

        result = p['resolve_position'](position, content, '12345678')

        assert result.confidence == 'unanchored'


# =============================================================================
# ResolvedPosition Data Class Tests
# =============================================================================

class TestResolvedPositionDataClass:
    """Tests for ResolvedPosition data class structure and methods."""

    def test_resolved_position_is_dataclass(self):
        """ResolvedPosition is a dataclass"""
        p = import_position_module()
        assert is_dataclass(p['ResolvedPosition'])

    def test_resolved_position_has_required_fields(self):
        """ResolvedPosition has all required fields"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_general('12345678')
        content = "Test content"

        result = p['resolve_position'](position, content, '12345678')

        # Check all required fields exist
        assert hasattr(result, 'type')
        assert hasattr(result, 'confidence')
        assert hasattr(result, 'lineNumber')
        assert hasattr(result, 'lineRange')
        assert hasattr(result, 'charRange')
        assert hasattr(result, 'matchedText')
        assert hasattr(result, 'originalPosition')
        assert hasattr(result, 'resolutionPath')

    def test_resolved_position_to_dict(self):
        """ResolvedPosition.to_dict() returns JSON-serializable dict"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 1)
        content = "Line 1"

        result = p['resolve_position'](position, content, '12345678')
        d = result.to_dict()

        assert isinstance(d, dict)
        assert 'type' in d
        assert 'confidence' in d
        assert 'resolutionPath' in d

        # Should be JSON serializable
        json_str = json.dumps(d)
        assert '"exact"' in json_str or '"approximate"' in json_str or '"unanchored"' in json_str

    def test_resolved_position_from_dict(self):
        """ResolvedPosition.from_dict() deserializes correctly"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 5)
        content = "L1\nL2\nL3\nL4\nL5"

        original = p['resolve_position'](position, content, '12345678')
        data = original.to_dict()
        restored = p['ResolvedPosition'].from_dict(data)

        assert restored.type == original.type
        assert restored.confidence == original.confidence
        assert restored.lineNumber == original.lineNumber
        assert restored.resolutionPath == original.resolutionPath

    def test_resolved_position_validate(self):
        """ResolvedPosition.validate() checks field validity"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 1)
        content = "Line 1"

        result = p['resolve_position'](position, content, '12345678')
        is_valid, errors = result.validate()

        assert is_valid is True
        assert errors == []

    def test_resolved_position_create_exact_factory(self):
        """ResolvedPosition.create_exact() factory method works"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 1)

        result = p['ResolvedPosition'].create_exact(
            position_type='line',
            line_number=1,
            line_range=(1, 1),
            char_range=(0, 6),
            matched_text='Line 1',
            original=position
        )

        assert result.confidence == 'exact'
        assert result.resolutionPath == 'hash_match'

    def test_resolved_position_create_approximate_factory(self):
        """ResolvedPosition.create_approximate() factory method works"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 1)

        result = p['ResolvedPosition'].create_approximate(
            position_type='line',
            line_number=2,
            line_range=(2, 2),
            char_range=(7, 13),
            matched_text='Line 2',
            original=position,
            resolution_path='fallback_context'
        )

        assert result.confidence == 'approximate'
        assert result.resolutionPath == 'fallback_context'

    def test_resolved_position_create_unanchored_factory(self):
        """ResolvedPosition.create_unanchored() factory method works"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 100)

        result = p['ResolvedPosition'].create_unanchored(position)

        assert result.confidence == 'unanchored'
        assert result.originalPosition == position


# =============================================================================
# Helper Function Tests
# =============================================================================

class TestHelperFunctions:
    """Tests for helper functions used in position resolution."""

    def test_find_line_in_text(self):
        """find_line_in_text returns character range for line"""
        p = import_position_module()

        text = "Line 1\nLine 2\nLine 3"

        # Line 1: chars 0-6
        result = p['find_line_in_text'](text, 1)
        assert result == (0, 6)

        # Line 2: chars 7-13
        result = p['find_line_in_text'](text, 2)
        assert result == (7, 13)

        # Line 3: chars 14-20
        result = p['find_line_in_text'](text, 3)
        assert result == (14, 20)

    def test_find_line_in_text_invalid_line(self):
        """find_line_in_text returns None for invalid line"""
        p = import_position_module()

        text = "Line 1\nLine 2"

        result = p['find_line_in_text'](text, 5)
        assert result is None

        result = p['find_line_in_text'](text, 0)
        assert result is None

        result = p['find_line_in_text'](text, -1)
        assert result is None

    def test_find_context_in_text(self):
        """find_context_in_text finds substring position"""
        p = import_position_module()

        text = "The quick brown fox"

        result = p['find_context_in_text'](text, 'quick')
        assert result == (4, 9)

        result = p['find_context_in_text'](text, 'missing')
        assert result is None

    def test_find_keyword_occurrence(self):
        """find_keyword_occurrence finds Nth occurrence"""
        p = import_position_module()

        text = "SHALL do this. SHALL do that. SHALL do more."

        # First occurrence
        result = p['find_keyword_occurrence'](text, 'SHALL', 1)
        assert result == (0, 5)

        # Second occurrence
        result = p['find_keyword_occurrence'](text, 'SHALL', 2)
        assert result == (15, 20)

        # Third occurrence
        result = p['find_keyword_occurrence'](text, 'SHALL', 3)
        assert result == (30, 35)

        # Fourth (doesn't exist)
        result = p['find_keyword_occurrence'](text, 'SHALL', 4)
        assert result is None

    def test_get_line_number_from_char_offset(self):
        """get_line_number_from_char_offset converts offset to line"""
        p = import_position_module()

        text = "Line 1\nLine 2\nLine 3"

        # Characters in line 1
        assert p['get_line_number_from_char_offset'](text, 0) == 1
        assert p['get_line_number_from_char_offset'](text, 5) == 1

        # Characters in line 2
        assert p['get_line_number_from_char_offset'](text, 7) == 2
        assert p['get_line_number_from_char_offset'](text, 12) == 2

        # Characters in line 3
        assert p['get_line_number_from_char_offset'](text, 14) == 3

    def test_get_line_range_from_char_range(self):
        """get_line_range_from_char_range converts char range to lines"""
        p = import_position_module()

        text = "Line 1\nLine 2\nLine 3"

        # Range within single line
        result = p['get_line_range_from_char_range'](text, 0, 6)
        assert result == (1, 1)

        # Range spanning lines 1-2
        result = p['get_line_range_from_char_range'](text, 0, 13)
        assert result == (1, 2)

        # Range spanning all lines
        result = p['get_line_range_from_char_range'](text, 0, 20)
        assert result == (1, 3)

    def test_get_total_lines(self):
        """get_total_lines counts lines in text"""
        p = import_position_module()

        assert p['get_total_lines']("Single line") == 1
        assert p['get_total_lines']("Line 1\nLine 2") == 2
        assert p['get_total_lines']("L1\nL2\nL3\nL4") == 4
        assert p['get_total_lines']("") == 0


# =============================================================================
# Edge Cases and Integration Tests
# =============================================================================

class TestEdgeCases:
    """Edge case tests for position resolution."""

    def test_empty_fallback_context(self):
        """Empty fallbackContext doesn't break resolution"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 1, ''  # Empty context
        )
        content = "Line 1\nLine 2"

        # Should not raise
        result = p['resolve_position'](position, content, 'different')
        assert result is not None

    def test_special_characters_in_context(self):
        """Special regex characters in context are handled"""
        p = import_position_module()
        m = import_models()

        # Line 10 is out of range, so fallback will use context
        position = m['CommentPosition'].create_line(
            '12345678', 10, 'text with (parens) and [brackets]'
        )
        content = "Line 1\ntext with (parens) and [brackets]\nLine 3"

        result = p['resolve_position'](position, content, 'different')

        assert result.matchedText == 'text with (parens) and [brackets]'
        assert result.resolutionPath == 'fallback_context'

    def test_multiline_content(self):
        """Multiline content is handled correctly"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_block('12345678', 2, 4)
        content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"

        result = p['resolve_position'](position, content, '12345678')

        assert result.lineRange == (2, 4)

    def test_unicode_content(self):
        """Unicode content is handled correctly"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line(
            '12345678', 1, 'unicode text'
        )
        content = "unicode text\ncontient des accents: cafe"

        result = p['resolve_position'](position, content, '12345678')

        assert result.lineNumber == 1

    def test_very_long_content(self):
        """Very long content is handled"""
        p = import_position_module()
        m = import_models()

        # Generate 1000 lines
        lines = [f"Line {i}" for i in range(1000)]
        content = "\n".join(lines)

        position = m['CommentPosition'].create_line('12345678', 500)

        result = p['resolve_position'](position, content, '12345678')

        assert result.lineNumber == 500

    def test_whitespace_only_lines(self):
        """Lines with only whitespace are handled"""
        p = import_position_module()
        m = import_models()

        position = m['CommentPosition'].create_line('12345678', 2)
        content = "Line 1\n   \nLine 3"

        result = p['resolve_position'](position, content, '12345678')

        assert result.lineNumber == 2
        assert result.matchedText == '   '


class TestIntegrationScenarios:
    """Integration tests for realistic scenarios."""

    def test_requirement_text_scenario(self):
        """Test with realistic requirement text"""
        p = import_position_module()
        m = import_models()

        content = """## REQ-d00001: User Authentication

The system SHALL authenticate users via OAuth 2.0.

### Assertions

A. Users SHALL provide valid credentials.
B. Invalid credentials SHALL result in error message.
C. Session tokens SHALL expire after 24 hours.
"""

        # Comment on assertion B (line 8)
        position = m['CommentPosition'].create_line(
            '12345678', 8, 'Invalid credentials SHALL'
        )

        result = p['resolve_position'](position, content, '12345678')

        assert result.confidence == 'exact'
        assert result.lineNumber == 8

    def test_requirement_after_edit(self):
        """Test position resolution after requirement is edited"""
        p = import_position_module()
        m = import_models()

        # Original content when comment was created
        # The comment was on "B. Invalid credentials" which was line 4
        # Now content changed significantly, line 4 might be empty or different
        position = m['CommentPosition'].create_line(
            'original1', 100, 'B. Invalid credentials'  # Line 100 out of range
        )

        # Content after editing - new line added at top
        new_content = """## Added Header

## REQ-d00001: User Authentication

A. Users SHALL provide credentials.
B. Invalid credentials SHALL fail.
C. Sessions expire after 24 hours.
"""

        result = p['resolve_position'](position, new_content, 'newHash1')

        # Should find the line by context even though it moved
        assert result.confidence == 'approximate'
        assert result.resolutionPath == 'fallback_context'
        assert 'Invalid credentials' in (result.matchedText or '')

    def test_batch_resolution(self):
        """Test resolving multiple positions for same document"""
        p = import_position_module()
        m = import_models()

        content = """Line 1
Line 2
Line 3
Line 4
Line 5"""

        positions = [
            m['CommentPosition'].create_line('12345678', 1),
            m['CommentPosition'].create_line('12345678', 3),
            m['CommentPosition'].create_general('12345678'),
        ]

        results = [
            p['resolve_position'](pos, content, '12345678')
            for pos in positions
        ]

        assert results[0].lineNumber == 1
        assert results[1].lineNumber == 3
        assert results[2].lineRange == (1, 5)
