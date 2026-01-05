"""
Tests for Position Resolution Module (REQ-tv-d00011).

TDD Red Phase: These tests are written BEFORE the implementation.
They will fail until position.py is implemented.

Each test function documents which assertion it verifies in its docstring.
The Elspais reporter extracts these references for traceability.

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00011: Position resolution for spec review system
"""

import pytest
from typing import Tuple, Optional


# =============================================================================
# Test Fixtures
# =============================================================================

@pytest.fixture
def valid_hash():
    """Provide a valid 8-character hex hash."""
    return "a1b2c3d4"


@pytest.fixture
def different_hash():
    """Provide a different valid 8-character hex hash for drift scenarios."""
    return "e5f6a7b8"


@pytest.fixture
def sample_text():
    """Provide sample multi-line text for position testing."""
    return """Line one content here
Line two with some words
Line three has keyword MUST appear
Line four continues
Line five ends the sample"""


@pytest.fixture
def sample_text_with_duplicates():
    """Provide sample text with repeated keywords."""
    return """The system SHALL implement feature A.
The user SHALL be able to access.
The API SHALL return valid JSON.
This is additional content."""


@pytest.fixture
def single_line_text():
    """Provide single line text for edge case testing."""
    return "Single line content only"


@pytest.fixture
def empty_text():
    """Provide empty text for edge case testing."""
    return ""


@pytest.fixture
def line_position(valid_hash):
    """Provide a sample line-type CommentPosition."""
    from trace_view.review.models import CommentPosition
    return CommentPosition.create_line(valid_hash, line_number=3, context="Line three")


@pytest.fixture
def block_position(valid_hash):
    """Provide a sample block-type CommentPosition."""
    from trace_view.review.models import CommentPosition
    return CommentPosition.create_block(valid_hash, start_line=2, end_line=4, context="Line two")


@pytest.fixture
def word_position(valid_hash):
    """Provide a sample word-type CommentPosition."""
    from trace_view.review.models import CommentPosition
    return CommentPosition.create_word(valid_hash, keyword="MUST", occurrence=1, context="MUST appear")


@pytest.fixture
def general_position(valid_hash):
    """Provide a sample general-type CommentPosition."""
    from trace_view.review.models import CommentPosition
    return CommentPosition.create_general(valid_hash)


# =============================================================================
# ConfidenceLevel Enum Tests
# =============================================================================

class TestConfidenceLevelEnum:
    """Tests for ConfidenceLevel enumeration."""

    def test_confidence_level_has_exact_value(self):
        """
        REQ-tv-d00011-A: ConfidenceLevel enum SHALL include EXACT value for
        hash-matched resolution.
        """
        from trace_view.review.position import ConfidenceLevel
        assert ConfidenceLevel.EXACT.value == "exact"

    def test_confidence_level_has_approximate_value(self):
        """
        REQ-tv-d00011-A: ConfidenceLevel enum SHALL include APPROXIMATE value for
        fallback resolution.
        """
        from trace_view.review.position import ConfidenceLevel
        assert ConfidenceLevel.APPROXIMATE.value == "approximate"

    def test_confidence_level_has_unanchored_value(self):
        """
        REQ-tv-d00011-A: ConfidenceLevel enum SHALL include UNANCHORED value for
        failed resolution.
        """
        from trace_view.review.position import ConfidenceLevel
        assert ConfidenceLevel.UNANCHORED.value == "unanchored"

    def test_confidence_level_is_string_enum(self):
        """
        REQ-tv-d00011-A: ConfidenceLevel SHALL be a string enum for JSON
        serialization compatibility.
        """
        from trace_view.review.position import ConfidenceLevel
        assert isinstance(ConfidenceLevel.EXACT.value, str)
        assert ConfidenceLevel.EXACT == "exact"


# =============================================================================
# ResolvedPosition Factory Method Tests
# =============================================================================

class TestResolvedPositionCreateExact:
    """Tests for ResolvedPosition.create_exact factory method."""

    def test_create_exact_sets_confidence(self, valid_hash):
        """
        REQ-tv-d00011-B: create_exact SHALL set confidence to EXACT.
        """
        from trace_view.review.position import ResolvedPosition, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition.create_exact(
            position_type="line",
            line_number=5,
            line_range=(5, 5),
            char_range=(100, 120),
            matched_text="test content",
            original=original
        )
        assert resolved.confidence == ConfidenceLevel.EXACT.value

    def test_create_exact_sets_resolution_path(self, valid_hash):
        """
        REQ-tv-d00011-B: create_exact SHALL set resolutionPath to 'hash_match'.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition.create_exact(
            position_type="line",
            line_number=5,
            line_range=(5, 5),
            char_range=(100, 120),
            matched_text="test",
            original=original
        )
        assert resolved.resolutionPath == "hash_match"

    def test_create_exact_preserves_original(self, valid_hash):
        """
        REQ-tv-d00011-B: create_exact SHALL preserve original CommentPosition.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition.create_exact(
            position_type="line",
            line_number=5,
            line_range=(5, 5),
            char_range=(100, 120),
            matched_text="test",
            original=original
        )
        assert resolved.originalPosition == original


class TestResolvedPositionCreateApproximate:
    """Tests for ResolvedPosition.create_approximate factory method."""

    def test_create_approximate_sets_confidence(self, valid_hash):
        """
        REQ-tv-d00011-C: create_approximate SHALL set confidence to APPROXIMATE.
        """
        from trace_view.review.position import ResolvedPosition, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition.create_approximate(
            position_type="line",
            line_number=5,
            line_range=(5, 5),
            char_range=(100, 120),
            matched_text="test",
            original=original,
            resolution_path="fallback_context"
        )
        assert resolved.confidence == ConfidenceLevel.APPROXIMATE.value

    def test_create_approximate_sets_custom_resolution_path(self, valid_hash):
        """
        REQ-tv-d00011-C: create_approximate SHALL set custom resolutionPath.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition.create_approximate(
            position_type="line",
            line_number=5,
            line_range=(5, 5),
            char_range=(100, 120),
            matched_text="test",
            original=original,
            resolution_path="fallback_keyword"
        )
        assert resolved.resolutionPath == "fallback_keyword"


class TestResolvedPositionCreateUnanchored:
    """Tests for ResolvedPosition.create_unanchored factory method."""

    def test_create_unanchored_sets_confidence(self, valid_hash):
        """
        REQ-tv-d00011-D: create_unanchored SHALL set confidence to UNANCHORED.
        """
        from trace_view.review.position import ResolvedPosition, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition.create_unanchored(original)
        assert resolved.confidence == ConfidenceLevel.UNANCHORED.value

    def test_create_unanchored_sets_type_general(self, valid_hash):
        """
        REQ-tv-d00011-D: create_unanchored SHALL set type to GENERAL.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition, PositionType

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition.create_unanchored(original)
        assert resolved.type == PositionType.GENERAL.value

    def test_create_unanchored_clears_position_fields(self, valid_hash):
        """
        REQ-tv-d00011-D: create_unanchored SHALL set position fields to None.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition.create_unanchored(original)
        assert resolved.lineNumber is None
        assert resolved.lineRange is None
        assert resolved.charRange is None
        assert resolved.matchedText is None

    def test_create_unanchored_sets_resolution_path(self, valid_hash):
        """
        REQ-tv-d00011-D: create_unanchored SHALL set resolutionPath to 'fallback_exhausted'.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition.create_unanchored(original)
        assert resolved.resolutionPath == "fallback_exhausted"


# =============================================================================
# ResolvedPosition Validation Tests
# =============================================================================

class TestResolvedPositionValidation:
    """Tests for ResolvedPosition.validate method."""

    def test_validate_valid_resolved_position(self, valid_hash):
        """
        REQ-tv-d00011-E: validate SHALL pass for valid ResolvedPosition.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition.create_exact(
            position_type="line",
            line_number=5,
            line_range=(5, 5),
            char_range=(0, 20),
            matched_text="test",
            original=original
        )
        is_valid, errors = resolved.validate()
        assert is_valid is True
        assert errors == []

    def test_validate_rejects_invalid_position_type(self, valid_hash):
        """
        REQ-tv-d00011-E: validate SHALL reject invalid position type.
        """
        from trace_view.review.position import ResolvedPosition, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition(
            type="invalid_type",
            confidence=ConfidenceLevel.EXACT.value,
            lineNumber=5,
            lineRange=(5, 5),
            charRange=(0, 20),
            matchedText="test",
            originalPosition=original,
            resolutionPath="hash_match"
        )
        is_valid, errors = resolved.validate()
        assert is_valid is False
        assert any("type" in e.lower() for e in errors)

    def test_validate_rejects_invalid_confidence(self, valid_hash):
        """
        REQ-tv-d00011-E: validate SHALL reject invalid confidence level.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition(
            type="line",
            confidence="invalid_confidence",
            lineNumber=5,
            lineRange=(5, 5),
            charRange=(0, 20),
            matchedText="test",
            originalPosition=original,
            resolutionPath="hash_match"
        )
        is_valid, errors = resolved.validate()
        assert is_valid is False
        assert any("confidence" in e.lower() for e in errors)

    def test_validate_rejects_negative_line_number(self, valid_hash):
        """
        REQ-tv-d00011-E: validate SHALL reject negative lineNumber.
        """
        from trace_view.review.position import ResolvedPosition, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition(
            type="line",
            confidence=ConfidenceLevel.EXACT.value,
            lineNumber=-1,
            lineRange=None,
            charRange=None,
            matchedText=None,
            originalPosition=original,
            resolutionPath="hash_match"
        )
        is_valid, errors = resolved.validate()
        assert is_valid is False
        assert any("lineNumber" in e or "positive" in e.lower() for e in errors)

    def test_validate_rejects_invalid_line_range(self, valid_hash):
        """
        REQ-tv-d00011-E: validate SHALL reject invalid lineRange (end < start).
        """
        from trace_view.review.position import ResolvedPosition, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_block(valid_hash, start_line=1, end_line=5)
        resolved = ResolvedPosition(
            type="block",
            confidence=ConfidenceLevel.EXACT.value,
            lineNumber=1,
            lineRange=(5, 1),  # Invalid: end < start
            charRange=None,
            matchedText=None,
            originalPosition=original,
            resolutionPath="hash_match"
        )
        is_valid, errors = resolved.validate()
        assert is_valid is False
        assert any("lineRange" in e for e in errors)

    def test_validate_rejects_invalid_char_range(self, valid_hash):
        """
        REQ-tv-d00011-E: validate SHALL reject invalid charRange (end < start).
        """
        from trace_view.review.position import ResolvedPosition, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition(
            type="line",
            confidence=ConfidenceLevel.EXACT.value,
            lineNumber=5,
            lineRange=(5, 5),
            charRange=(100, 50),  # Invalid: end < start
            matchedText=None,
            originalPosition=original,
            resolutionPath="hash_match"
        )
        is_valid, errors = resolved.validate()
        assert is_valid is False
        assert any("charRange" in e for e in errors)

    def test_validate_rejects_negative_char_offset(self, valid_hash):
        """
        REQ-tv-d00011-E: validate SHALL reject negative char offset.
        """
        from trace_view.review.position import ResolvedPosition, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition(
            type="line",
            confidence=ConfidenceLevel.EXACT.value,
            lineNumber=5,
            lineRange=(5, 5),
            charRange=(-1, 50),  # Invalid: negative start
            matchedText=None,
            originalPosition=original,
            resolutionPath="hash_match"
        )
        is_valid, errors = resolved.validate()
        assert is_valid is False
        assert any("charRange" in e for e in errors)


# =============================================================================
# ResolvedPosition Serialization Tests
# =============================================================================

class TestResolvedPositionSerialization:
    """Tests for ResolvedPosition to_dict/from_dict serialization."""

    def test_to_dict_includes_required_fields(self, valid_hash):
        """
        REQ-tv-d00011-F: to_dict SHALL include type, confidence, resolutionPath.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_line(valid_hash, line_number=5)
        resolved = ResolvedPosition.create_exact(
            position_type="line",
            line_number=5,
            line_range=(5, 5),
            char_range=(0, 20),
            matched_text="test",
            original=original
        )
        data = resolved.to_dict()
        assert "type" in data
        assert "confidence" in data
        assert "resolutionPath" in data
        assert "originalPosition" in data

    def test_to_dict_excludes_none_fields(self, valid_hash):
        """
        REQ-tv-d00011-F: to_dict SHALL exclude None optional fields.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_general(valid_hash)
        resolved = ResolvedPosition.create_unanchored(original)
        data = resolved.to_dict()
        assert "lineNumber" not in data
        assert "lineRange" not in data
        assert "charRange" not in data
        assert "matchedText" not in data

    def test_to_dict_converts_tuples_to_lists(self, valid_hash):
        """
        REQ-tv-d00011-F: to_dict SHALL convert tuples to lists for JSON.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_block(valid_hash, start_line=1, end_line=5)
        resolved = ResolvedPosition.create_exact(
            position_type="block",
            line_number=1,
            line_range=(1, 5),
            char_range=(0, 100),
            matched_text="test",
            original=original
        )
        data = resolved.to_dict()
        assert isinstance(data["lineRange"], list)
        assert isinstance(data["charRange"], list)

    def test_from_dict_creates_instance(self, valid_hash):
        """
        REQ-tv-d00011-G: from_dict SHALL create ResolvedPosition from dict.
        """
        from trace_view.review.position import ResolvedPosition

        data = {
            "type": "line",
            "confidence": "exact",
            "lineNumber": 5,
            "lineRange": [5, 5],
            "charRange": [0, 20],
            "matchedText": "test",
            "resolutionPath": "hash_match",
            "originalPosition": {
                "type": "line",
                "hashWhenCreated": valid_hash,
                "lineNumber": 5
            }
        }
        resolved = ResolvedPosition.from_dict(data)
        assert resolved.type == "line"
        assert resolved.confidence == "exact"
        assert resolved.lineNumber == 5

    def test_from_dict_converts_lists_to_tuples(self, valid_hash):
        """
        REQ-tv-d00011-G: from_dict SHALL convert lists to tuples.
        """
        from trace_view.review.position import ResolvedPosition

        data = {
            "type": "block",
            "confidence": "exact",
            "lineNumber": 1,
            "lineRange": [1, 5],
            "charRange": [0, 100],
            "resolutionPath": "hash_match",
            "originalPosition": {
                "type": "block",
                "hashWhenCreated": valid_hash,
                "lineRange": [1, 5]
            }
        }
        resolved = ResolvedPosition.from_dict(data)
        assert isinstance(resolved.lineRange, tuple)
        assert isinstance(resolved.charRange, tuple)
        assert resolved.lineRange == (1, 5)

    def test_roundtrip_serialization(self, valid_hash):
        """
        REQ-tv-d00011-G: from_dict(to_dict()) SHALL preserve all data.
        """
        from trace_view.review.position import ResolvedPosition
        from trace_view.review.models import CommentPosition

        original = CommentPosition.create_word(valid_hash, keyword="SHALL", occurrence=2)
        resolved = ResolvedPosition.create_exact(
            position_type="word",
            line_number=3,
            line_range=(3, 3),
            char_range=(50, 55),
            matched_text="SHALL",
            original=original
        )
        data = resolved.to_dict()
        restored = ResolvedPosition.from_dict(data)
        assert restored.type == resolved.type
        assert restored.confidence == resolved.confidence
        assert restored.lineNumber == resolved.lineNumber
        assert restored.lineRange == resolved.lineRange
        assert restored.charRange == resolved.charRange
        assert restored.matchedText == resolved.matchedText
        assert restored.resolutionPath == resolved.resolutionPath


# =============================================================================
# Helper Function Tests: find_line_in_text
# =============================================================================

class TestFindLineInText:
    """Tests for find_line_in_text helper function."""

    def test_finds_first_line(self, sample_text):
        """
        REQ-tv-d00011-H: find_line_in_text SHALL find first line (1-based).
        """
        from trace_view.review.position import find_line_in_text
        result = find_line_in_text(sample_text, 1)
        assert result is not None
        assert result[0] == 0  # Start of text
        assert sample_text[result[0]:result[1]] == "Line one content here"

    def test_finds_middle_line(self, sample_text):
        """
        REQ-tv-d00011-H: find_line_in_text SHALL find middle lines correctly.
        """
        from trace_view.review.position import find_line_in_text
        result = find_line_in_text(sample_text, 3)
        assert result is not None
        assert sample_text[result[0]:result[1]] == "Line three has keyword MUST appear"

    def test_finds_last_line(self, sample_text):
        """
        REQ-tv-d00011-H: find_line_in_text SHALL find last line correctly.
        """
        from trace_view.review.position import find_line_in_text
        result = find_line_in_text(sample_text, 5)
        assert result is not None
        assert sample_text[result[0]:result[1]] == "Line five ends the sample"

    def test_returns_none_for_out_of_range(self, sample_text):
        """
        REQ-tv-d00011-H: find_line_in_text SHALL return None for out of range.
        """
        from trace_view.review.position import find_line_in_text
        result = find_line_in_text(sample_text, 100)
        assert result is None

    def test_returns_none_for_zero_line(self, sample_text):
        """
        REQ-tv-d00011-H: find_line_in_text SHALL return None for line 0.
        """
        from trace_view.review.position import find_line_in_text
        result = find_line_in_text(sample_text, 0)
        assert result is None

    def test_returns_none_for_negative_line(self, sample_text):
        """
        REQ-tv-d00011-H: find_line_in_text SHALL return None for negative line.
        """
        from trace_view.review.position import find_line_in_text
        result = find_line_in_text(sample_text, -1)
        assert result is None

    def test_returns_none_for_empty_text(self):
        """
        REQ-tv-d00011-H: find_line_in_text SHALL return None for empty text.
        """
        from trace_view.review.position import find_line_in_text
        result = find_line_in_text("", 1)
        assert result is None

    def test_handles_single_line_text(self, single_line_text):
        """
        REQ-tv-d00011-H: find_line_in_text SHALL handle single line text.
        """
        from trace_view.review.position import find_line_in_text
        result = find_line_in_text(single_line_text, 1)
        assert result is not None
        assert single_line_text[result[0]:result[1]] == single_line_text


# =============================================================================
# Helper Function Tests: find_context_in_text
# =============================================================================

class TestFindContextInText:
    """Tests for find_context_in_text helper function."""

    def test_finds_substring(self, sample_text):
        """
        REQ-tv-d00011-I: find_context_in_text SHALL find substring.
        """
        from trace_view.review.position import find_context_in_text
        result = find_context_in_text(sample_text, "keyword MUST")
        assert result is not None
        assert sample_text[result[0]:result[1]] == "keyword MUST"

    def test_finds_first_occurrence(self, sample_text_with_duplicates):
        """
        REQ-tv-d00011-I: find_context_in_text SHALL find first occurrence.
        """
        from trace_view.review.position import find_context_in_text
        result = find_context_in_text(sample_text_with_duplicates, "SHALL")
        assert result is not None
        # Should be the first occurrence
        assert result[0] == sample_text_with_duplicates.find("SHALL")

    def test_returns_none_for_missing_context(self, sample_text):
        """
        REQ-tv-d00011-I: find_context_in_text SHALL return None if not found.
        """
        from trace_view.review.position import find_context_in_text
        result = find_context_in_text(sample_text, "NONEXISTENT")
        assert result is None

    def test_returns_none_for_empty_context(self, sample_text):
        """
        REQ-tv-d00011-I: find_context_in_text SHALL return None for empty context.
        """
        from trace_view.review.position import find_context_in_text
        result = find_context_in_text(sample_text, "")
        assert result is None

    def test_returns_none_for_empty_text(self):
        """
        REQ-tv-d00011-I: find_context_in_text SHALL return None for empty text.
        """
        from trace_view.review.position import find_context_in_text
        result = find_context_in_text("", "something")
        assert result is None

    def test_is_case_sensitive(self, sample_text):
        """
        REQ-tv-d00011-I: find_context_in_text SHALL be case sensitive.
        """
        from trace_view.review.position import find_context_in_text
        result_upper = find_context_in_text(sample_text, "MUST")
        result_lower = find_context_in_text(sample_text, "must")
        assert result_upper is not None
        assert result_lower is None  # "must" doesn't exist, only "MUST"


# =============================================================================
# Helper Function Tests: find_keyword_occurrence
# =============================================================================

class TestFindKeywordOccurrence:
    """Tests for find_keyword_occurrence helper function."""

    def test_finds_first_occurrence(self, sample_text_with_duplicates):
        """
        REQ-tv-d00011-J: find_keyword_occurrence SHALL find first occurrence.
        """
        from trace_view.review.position import find_keyword_occurrence
        result = find_keyword_occurrence(sample_text_with_duplicates, "SHALL", 1)
        assert result is not None
        assert sample_text_with_duplicates[result[0]:result[1]] == "SHALL"
        # First occurrence should be early in text
        assert result[0] < 20

    def test_finds_second_occurrence(self, sample_text_with_duplicates):
        """
        REQ-tv-d00011-J: find_keyword_occurrence SHALL find Nth occurrence.
        """
        from trace_view.review.position import find_keyword_occurrence
        result1 = find_keyword_occurrence(sample_text_with_duplicates, "SHALL", 1)
        result2 = find_keyword_occurrence(sample_text_with_duplicates, "SHALL", 2)
        assert result1 is not None
        assert result2 is not None
        assert result2[0] > result1[0]  # Second occurrence is after first

    def test_finds_third_occurrence(self, sample_text_with_duplicates):
        """
        REQ-tv-d00011-J: find_keyword_occurrence SHALL find third occurrence.
        """
        from trace_view.review.position import find_keyword_occurrence
        result3 = find_keyword_occurrence(sample_text_with_duplicates, "SHALL", 3)
        assert result3 is not None
        assert sample_text_with_duplicates[result3[0]:result3[1]] == "SHALL"

    def test_returns_none_for_missing_occurrence(self, sample_text_with_duplicates):
        """
        REQ-tv-d00011-J: find_keyword_occurrence SHALL return None if occurrence not found.
        """
        from trace_view.review.position import find_keyword_occurrence
        # There are only 3 "SHALL"s in the sample
        result = find_keyword_occurrence(sample_text_with_duplicates, "SHALL", 10)
        assert result is None

    def test_returns_none_for_missing_keyword(self, sample_text):
        """
        REQ-tv-d00011-J: find_keyword_occurrence SHALL return None if keyword not found.
        """
        from trace_view.review.position import find_keyword_occurrence
        result = find_keyword_occurrence(sample_text, "NONEXISTENT", 1)
        assert result is None

    def test_returns_none_for_zero_occurrence(self, sample_text):
        """
        REQ-tv-d00011-J: find_keyword_occurrence SHALL return None for occurrence 0.
        """
        from trace_view.review.position import find_keyword_occurrence
        result = find_keyword_occurrence(sample_text, "MUST", 0)
        assert result is None

    def test_returns_none_for_negative_occurrence(self, sample_text):
        """
        REQ-tv-d00011-J: find_keyword_occurrence SHALL return None for negative occurrence.
        """
        from trace_view.review.position import find_keyword_occurrence
        result = find_keyword_occurrence(sample_text, "MUST", -1)
        assert result is None

    def test_returns_none_for_empty_keyword(self, sample_text):
        """
        REQ-tv-d00011-J: find_keyword_occurrence SHALL return None for empty keyword.
        """
        from trace_view.review.position import find_keyword_occurrence
        result = find_keyword_occurrence(sample_text, "", 1)
        assert result is None


# =============================================================================
# Helper Function Tests: get_line_number_from_char_offset
# =============================================================================

class TestGetLineNumberFromCharOffset:
    """Tests for get_line_number_from_char_offset helper function."""

    def test_returns_line_1_for_start(self, sample_text):
        """
        REQ-tv-d00011-K: get_line_number_from_char_offset SHALL return 1 for offset 0.
        """
        from trace_view.review.position import get_line_number_from_char_offset
        result = get_line_number_from_char_offset(sample_text, 0)
        assert result == 1

    def test_returns_correct_line_for_middle(self, sample_text):
        """
        REQ-tv-d00011-K: get_line_number_from_char_offset SHALL return correct line.
        """
        from trace_view.review.position import get_line_number_from_char_offset
        # Find the start of line 3 and check
        lines = sample_text.split('\n')
        offset_line3 = len(lines[0]) + 1 + len(lines[1]) + 1  # After first 2 lines + newlines
        result = get_line_number_from_char_offset(sample_text, offset_line3)
        assert result == 3

    def test_returns_line_1_for_negative_offset(self, sample_text):
        """
        REQ-tv-d00011-K: get_line_number_from_char_offset SHALL return 1 for negative offset.
        """
        from trace_view.review.position import get_line_number_from_char_offset
        result = get_line_number_from_char_offset(sample_text, -5)
        assert result == 1

    def test_returns_line_1_for_empty_text(self):
        """
        REQ-tv-d00011-K: get_line_number_from_char_offset SHALL return 1 for empty text.
        """
        from trace_view.review.position import get_line_number_from_char_offset
        result = get_line_number_from_char_offset("", 0)
        assert result == 1

    def test_handles_offset_at_end(self, sample_text):
        """
        REQ-tv-d00011-K: get_line_number_from_char_offset SHALL handle offset at end.
        """
        from trace_view.review.position import get_line_number_from_char_offset
        result = get_line_number_from_char_offset(sample_text, len(sample_text) - 1)
        assert result == 5  # Last line


# =============================================================================
# Helper Function Tests: get_line_range_from_char_range
# =============================================================================

class TestGetLineRangeFromCharRange:
    """Tests for get_line_range_from_char_range helper function."""

    def test_returns_same_line_for_single_line_range(self, sample_text):
        """
        REQ-tv-d00011-L: get_line_range_from_char_range SHALL return same line for single line.
        """
        from trace_view.review.position import get_line_range_from_char_range
        # Characters within first line
        result = get_line_range_from_char_range(sample_text, 0, 10)
        assert result == (1, 1)

    def test_returns_multi_line_range(self, sample_text):
        """
        REQ-tv-d00011-L: get_line_range_from_char_range SHALL return correct multi-line range.
        """
        from trace_view.review.position import get_line_range_from_char_range
        # From start to end of text
        result = get_line_range_from_char_range(sample_text, 0, len(sample_text))
        assert result[0] == 1
        assert result[1] == 5

    def test_handles_empty_range(self, sample_text):
        """
        REQ-tv-d00011-L: get_line_range_from_char_range SHALL handle empty range.
        """
        from trace_view.review.position import get_line_range_from_char_range
        # Empty range (start == end)
        result = get_line_range_from_char_range(sample_text, 10, 10)
        assert result[0] == result[1]


# =============================================================================
# Helper Function Tests: get_total_lines
# =============================================================================

class TestGetTotalLines:
    """Tests for get_total_lines helper function."""

    def test_counts_multiple_lines(self, sample_text):
        """
        REQ-tv-d00011-M: get_total_lines SHALL count all lines correctly.
        """
        from trace_view.review.position import get_total_lines
        result = get_total_lines(sample_text)
        assert result == 5

    def test_returns_1_for_single_line(self, single_line_text):
        """
        REQ-tv-d00011-M: get_total_lines SHALL return 1 for single line.
        """
        from trace_view.review.position import get_total_lines
        result = get_total_lines(single_line_text)
        assert result == 1

    def test_returns_0_for_empty_text(self, empty_text):
        """
        REQ-tv-d00011-M: get_total_lines SHALL return 0 for empty text.
        """
        from trace_view.review.position import get_total_lines
        result = get_total_lines(empty_text)
        assert result == 0


# =============================================================================
# Core Resolution Tests: resolve_position (hash matches)
# =============================================================================

class TestResolvePositionExact:
    """Tests for resolve_position with matching hash (exact resolution)."""

    def test_exact_resolution_for_line_type(self, sample_text, line_position, valid_hash):
        """
        REQ-tv-d00011-N: resolve_position SHALL return EXACT confidence when hash matches.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        result = resolve_position(line_position, sample_text, valid_hash)
        assert result.confidence == ConfidenceLevel.EXACT.value
        assert result.resolutionPath == "hash_match"

    def test_exact_resolution_sets_line_number(self, sample_text, line_position, valid_hash):
        """
        REQ-tv-d00011-N: resolve_position SHALL set lineNumber for LINE type.
        """
        from trace_view.review.position import resolve_position
        result = resolve_position(line_position, sample_text, valid_hash)
        assert result.lineNumber == 3
        assert result.lineRange == (3, 3)

    def test_exact_resolution_sets_char_range(self, sample_text, line_position, valid_hash):
        """
        REQ-tv-d00011-N: resolve_position SHALL set charRange for LINE type.
        """
        from trace_view.review.position import resolve_position
        result = resolve_position(line_position, sample_text, valid_hash)
        assert result.charRange is not None
        # Char range should match line 3
        assert sample_text[result.charRange[0]:result.charRange[1]] == "Line three has keyword MUST appear"

    def test_exact_resolution_for_block_type(self, sample_text, block_position, valid_hash):
        """
        REQ-tv-d00011-O: resolve_position SHALL handle BLOCK type correctly.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        result = resolve_position(block_position, sample_text, valid_hash)
        assert result.confidence == ConfidenceLevel.EXACT.value
        assert result.lineRange == (2, 4)
        assert result.lineNumber == 2  # First line of block

    def test_exact_resolution_for_word_type(self, sample_text, word_position, valid_hash):
        """
        REQ-tv-d00011-P: resolve_position SHALL handle WORD type correctly.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        result = resolve_position(word_position, sample_text, valid_hash)
        assert result.confidence == ConfidenceLevel.EXACT.value
        assert result.matchedText == "MUST"
        assert result.charRange is not None

    def test_exact_resolution_for_general_type(self, sample_text, general_position, valid_hash):
        """
        REQ-tv-d00011-Q: resolve_position SHALL handle GENERAL type correctly.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        result = resolve_position(general_position, sample_text, valid_hash)
        assert result.confidence == ConfidenceLevel.EXACT.value
        assert result.lineNumber is None
        assert result.lineRange == (1, 5)  # Whole document
        assert result.charRange == (0, len(sample_text))

    def test_exact_resolution_case_insensitive_hash(self, sample_text, line_position, valid_hash):
        """
        REQ-tv-d00011-N: resolve_position SHALL compare hashes case-insensitively.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        upper_hash = valid_hash.upper()
        result = resolve_position(line_position, sample_text, upper_hash)
        assert result.confidence == ConfidenceLevel.EXACT.value


# =============================================================================
# Core Resolution Tests: resolve_position (hash differs - fallback)
# =============================================================================

class TestResolvePositionWithFallback:
    """Tests for resolve_position with different hash (approximate resolution)."""

    def test_fallback_to_line_number(self, sample_text, line_position, different_hash):
        """
        REQ-tv-d00011-R: resolve_position SHALL try lineNumber fallback first.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        result = resolve_position(line_position, sample_text, different_hash)
        assert result.confidence == ConfidenceLevel.APPROXIMATE.value
        assert result.resolutionPath == "fallback_line_number"
        assert result.lineNumber == 3  # Original line still valid

    def test_fallback_to_context(self, valid_hash, different_hash, sample_text):
        """
        REQ-tv-d00011-S: resolve_position SHALL try fallbackContext if lineNumber fails.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        # Position with out-of-range line but valid context
        position = CommentPosition.create_line(
            valid_hash,
            line_number=100,  # Out of range
            context="keyword MUST"
        )
        result = resolve_position(position, sample_text, different_hash)
        assert result.confidence == ConfidenceLevel.APPROXIMATE.value
        assert result.resolutionPath == "fallback_context"

    def test_fallback_to_keyword(self, valid_hash, different_hash, sample_text):
        """
        REQ-tv-d00011-T: resolve_position SHALL try keyword fallback if context fails.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        # Word position with valid keyword but different hash
        position = CommentPosition.create_word(
            valid_hash,
            keyword="MUST",
            occurrence=1,
            context="NONEXISTENT CONTEXT"
        )
        result = resolve_position(position, sample_text, different_hash)
        assert result.confidence == ConfidenceLevel.APPROXIMATE.value
        assert result.resolutionPath == "fallback_keyword"

    def test_fallback_to_unanchored(self, valid_hash, different_hash, sample_text):
        """
        REQ-tv-d00011-U: resolve_position SHALL return UNANCHORED if all fallbacks fail.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        from trace_view.review.models import CommentPosition, PositionType

        # Position with no valid fallback
        position = CommentPosition(
            type=PositionType.LINE.value,
            hashWhenCreated=valid_hash,
            lineNumber=100,  # Out of range
            fallbackContext="NONEXISTENT CONTEXT",
            keyword="NONEXISTENT_KEYWORD"
        )
        result = resolve_position(position, sample_text, different_hash)
        assert result.confidence == ConfidenceLevel.UNANCHORED.value
        assert result.resolutionPath == "fallback_exhausted"
        assert result.type == PositionType.GENERAL.value


# =============================================================================
# Edge Case Tests
# =============================================================================

class TestResolvePositionEdgeCases:
    """Tests for resolve_position edge cases."""

    def test_empty_text_returns_unanchored(self, line_position, valid_hash):
        """
        REQ-tv-d00011-V: resolve_position SHALL return UNANCHORED for empty text.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        result = resolve_position(line_position, "", valid_hash)
        assert result.confidence == ConfidenceLevel.UNANCHORED.value

    def test_line_out_of_range_uses_fallback(self, valid_hash, different_hash, sample_text):
        """
        REQ-tv-d00011-W: resolve_position SHALL use fallback when line out of range.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        position = CommentPosition.create_line(
            valid_hash,
            line_number=100,
            context="Line one"
        )
        result = resolve_position(position, sample_text, different_hash)
        # Should fall back to context
        assert result.confidence == ConfidenceLevel.APPROXIMATE.value

    def test_missing_keyword_uses_next_fallback(self, valid_hash, different_hash, sample_text):
        """
        REQ-tv-d00011-X: resolve_position SHALL try next fallback when keyword missing.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        position = CommentPosition.create_word(
            valid_hash,
            keyword="NONEXISTENT",
            occurrence=1
        )
        result = resolve_position(position, sample_text, different_hash)
        # Should become unanchored since no fallbacks work
        assert result.confidence == ConfidenceLevel.UNANCHORED.value

    def test_block_position_fallback_uses_first_line(self, valid_hash, different_hash, sample_text):
        """
        REQ-tv-d00011-Y: resolve_position SHALL use block's first line for lineNumber fallback.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        position = CommentPosition.create_block(
            valid_hash,
            start_line=2,
            end_line=4
        )
        result = resolve_position(position, sample_text, different_hash)
        assert result.confidence == ConfidenceLevel.APPROXIMATE.value
        assert result.resolutionPath == "fallback_line_number"
        assert result.lineNumber == 2  # First line of block

    def test_word_at_specific_occurrence(self, valid_hash, sample_text_with_duplicates):
        """
        REQ-tv-d00011-Z: resolve_position SHALL find specific keyword occurrence.
        """
        from trace_view.review.position import resolve_position
        from trace_view.review.models import CommentPosition

        position = CommentPosition.create_word(
            valid_hash,
            keyword="SHALL",
            occurrence=2
        )
        result = resolve_position(position, sample_text_with_duplicates, valid_hash)
        assert result.matchedText == "SHALL"
        # Second occurrence should be after first
        first_pos = sample_text_with_duplicates.find("SHALL")
        assert result.charRange[0] > first_pos


# =============================================================================
# Internal Resolution Function Tests
# =============================================================================

class TestResolveExact:
    """Tests for _resolve_exact internal function."""

    def test_resolve_exact_general_covers_whole_text(self, sample_text, valid_hash):
        """
        REQ-tv-d00011-AA: _resolve_exact for GENERAL SHALL cover whole text.
        """
        from trace_view.review.position import _resolve_exact
        from trace_view.review.models import CommentPosition

        position = CommentPosition.create_general(valid_hash)
        result = _resolve_exact(position, sample_text)
        assert result.charRange == (0, len(sample_text))
        assert result.lineRange[0] == 1
        assert result.lineRange[1] == 5

    def test_resolve_exact_line_extracts_matched_text(self, sample_text, valid_hash):
        """
        REQ-tv-d00011-AB: _resolve_exact for LINE SHALL extract matched text.
        """
        from trace_view.review.position import _resolve_exact
        from trace_view.review.models import CommentPosition

        position = CommentPosition.create_line(valid_hash, line_number=1)
        result = _resolve_exact(position, sample_text)
        assert result.matchedText == "Line one content here"

    def test_resolve_exact_block_extracts_range(self, sample_text, valid_hash):
        """
        REQ-tv-d00011-AC: _resolve_exact for BLOCK SHALL extract line range text.
        """
        from trace_view.review.position import _resolve_exact
        from trace_view.review.models import CommentPosition

        position = CommentPosition.create_block(valid_hash, start_line=1, end_line=2)
        result = _resolve_exact(position, sample_text)
        assert result.lineRange == (1, 2)
        # matchedText should contain both lines
        assert "Line one" in result.matchedText
        assert "Line two" in result.matchedText

    def test_resolve_exact_word_sets_all_fields(self, sample_text, valid_hash):
        """
        REQ-tv-d00011-AD: _resolve_exact for WORD SHALL set line and char info.
        """
        from trace_view.review.position import _resolve_exact
        from trace_view.review.models import CommentPosition

        position = CommentPosition.create_word(valid_hash, keyword="MUST", occurrence=1)
        result = _resolve_exact(position, sample_text)
        assert result.matchedText == "MUST"
        assert result.lineNumber == 3  # "MUST" is on line 3
        assert result.charRange is not None


class TestResolveWithFallback:
    """Tests for _resolve_with_fallback internal function."""

    def test_fallback_line_in_range_succeeds(self, sample_text, valid_hash):
        """
        REQ-tv-d00011-AE: _resolve_with_fallback SHALL succeed with valid lineNumber.
        """
        from trace_view.review.position import _resolve_with_fallback
        from trace_view.review.models import CommentPosition

        position = CommentPosition.create_line(valid_hash, line_number=3)
        result = _resolve_with_fallback(position, sample_text)
        assert result.resolutionPath == "fallback_line_number"
        assert result.lineNumber == 3

    def test_fallback_context_succeeds(self, sample_text, valid_hash):
        """
        REQ-tv-d00011-AF: _resolve_with_fallback SHALL succeed with valid context.
        """
        from trace_view.review.position import _resolve_with_fallback
        from trace_view.review.models import CommentPosition

        position = CommentPosition(
            type="line",
            hashWhenCreated=valid_hash,
            lineNumber=100,  # Out of range
            fallbackContext="keyword MUST"
        )
        result = _resolve_with_fallback(position, sample_text)
        assert result.resolutionPath == "fallback_context"

    def test_fallback_keyword_succeeds(self, sample_text, valid_hash):
        """
        REQ-tv-d00011-AG: _resolve_with_fallback SHALL succeed with valid keyword.
        """
        from trace_view.review.position import _resolve_with_fallback
        from trace_view.review.models import CommentPosition

        position = CommentPosition(
            type="word",
            hashWhenCreated=valid_hash,
            lineNumber=100,  # Out of range
            fallbackContext="NONEXISTENT",
            keyword="MUST",
            keywordOccurrence=1
        )
        result = _resolve_with_fallback(position, sample_text)
        assert result.resolutionPath == "fallback_keyword"

    def test_fallback_exhausted_returns_unanchored(self, sample_text, valid_hash):
        """
        REQ-tv-d00011-AH: _resolve_with_fallback SHALL return unanchored when exhausted.
        """
        from trace_view.review.position import _resolve_with_fallback, ConfidenceLevel
        from trace_view.review.models import CommentPosition, PositionType

        position = CommentPosition(
            type=PositionType.LINE.value,
            hashWhenCreated=valid_hash,
            lineNumber=100,
            fallbackContext="NONEXISTENT",
            keyword="NONEXISTENT"
        )
        result = _resolve_with_fallback(position, sample_text)
        assert result.confidence == ConfidenceLevel.UNANCHORED.value
        assert result.resolutionPath == "fallback_exhausted"


# =============================================================================
# Integration Tests
# =============================================================================

class TestPositionResolutionIntegration:
    """Integration tests for the complete position resolution workflow."""

    def test_full_workflow_exact_line(self, sample_text, valid_hash):
        """
        REQ-tv-d00011-AI: Full workflow SHALL resolve line position exactly.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        # Create position, resolve, validate
        position = CommentPosition.create_line(valid_hash, line_number=3, context="Line three")
        result = resolve_position(position, sample_text, valid_hash)

        # Validate result
        is_valid, errors = result.validate()
        assert is_valid is True
        assert result.confidence == ConfidenceLevel.EXACT.value
        assert result.originalPosition == position

    def test_full_workflow_drift_recovery(self, sample_text, valid_hash, different_hash):
        """
        REQ-tv-d00011-AJ: Full workflow SHALL recover from content drift.
        """
        from trace_view.review.position import resolve_position, ConfidenceLevel
        from trace_view.review.models import CommentPosition

        # Position created with old hash, resolved with new hash
        position = CommentPosition.create_line(
            valid_hash,
            line_number=3,
            context="Line three"
        )
        result = resolve_position(position, sample_text, different_hash)

        # Should still find the content
        assert result.confidence == ConfidenceLevel.APPROXIMATE.value
        # Validate result
        is_valid, errors = result.validate()
        assert is_valid is True

    def test_serialization_roundtrip_after_resolution(self, sample_text, valid_hash):
        """
        REQ-tv-d00011-AK: Resolved position SHALL survive serialization roundtrip.
        """
        from trace_view.review.position import resolve_position, ResolvedPosition
        from trace_view.review.models import CommentPosition

        position = CommentPosition.create_word(valid_hash, keyword="MUST", occurrence=1)
        result = resolve_position(position, sample_text, valid_hash)

        # Serialize and deserialize
        data = result.to_dict()
        restored = ResolvedPosition.from_dict(data)

        # All fields should match
        assert restored.type == result.type
        assert restored.confidence == result.confidence
        assert restored.lineNumber == result.lineNumber
        assert restored.charRange == result.charRange
        assert restored.matchedText == result.matchedText
