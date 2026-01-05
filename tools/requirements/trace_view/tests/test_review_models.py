"""
Tests for Review Data Models (REQ-tv-d00010).

TDD Red Phase: These tests are written BEFORE the implementation.
They will fail until models.py is implemented.

Each test function documents which assertion it verifies in its docstring.
The Elspais reporter extracts these references for traceability.

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00010: Review data models for spec review system
"""

import re
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Tuple, Any

import pytest


# =============================================================================
# Test Fixtures
# =============================================================================

@pytest.fixture
def valid_hash():
    """Provide a valid 8-character hex hash."""
    return "a1b2c3d4"


@pytest.fixture
def valid_req_id():
    """Provide a valid requirement ID."""
    return "d00027"


@pytest.fixture
def valid_sponsor_req_id():
    """Provide a valid sponsor-specific requirement ID."""
    return "CAL-d00001"


@pytest.fixture
def valid_timestamp():
    """Provide a valid ISO 8601 timestamp."""
    return datetime.now(timezone.utc).isoformat()


@pytest.fixture
def sample_author():
    """Provide a sample author username."""
    return "test_user"


@pytest.fixture
def sample_comment_body():
    """Provide a sample comment body."""
    return "This is a test comment with **markdown** support."


@pytest.fixture
def sample_position(valid_hash):
    """Provide a sample CommentPosition for line type."""
    from trace_view.review.models import CommentPosition
    return CommentPosition.create_line(valid_hash, line_number=42, context="sample context")


@pytest.fixture
def sample_comment(sample_author, sample_comment_body):
    """Provide a sample Comment instance."""
    from trace_view.review.models import Comment
    return Comment.create(author=sample_author, body=sample_comment_body)


@pytest.fixture
def sample_thread(valid_req_id, sample_author, sample_position, sample_comment_body):
    """Provide a sample Thread instance."""
    from trace_view.review.models import Thread
    return Thread.create(
        req_id=valid_req_id,
        creator=sample_author,
        position=sample_position,
        initial_comment=sample_comment_body
    )


# =============================================================================
# Enum Tests
# =============================================================================

class TestPositionTypeEnum:
    """Tests for PositionType enumeration."""

    def test_position_type_has_line_value(self):
        """
        REQ-tv-d00010-A: PositionType enum SHALL include LINE value for
        single-line comment anchoring.
        """
        from trace_view.review.models import PositionType
        assert PositionType.LINE.value == "line"

    def test_position_type_has_block_value(self):
        """
        REQ-tv-d00010-A: PositionType enum SHALL include BLOCK value for
        multi-line comment anchoring.
        """
        from trace_view.review.models import PositionType
        assert PositionType.BLOCK.value == "block"

    def test_position_type_has_word_value(self):
        """
        REQ-tv-d00010-A: PositionType enum SHALL include WORD value for
        keyword-based comment anchoring.
        """
        from trace_view.review.models import PositionType
        assert PositionType.WORD.value == "word"

    def test_position_type_has_general_value(self):
        """
        REQ-tv-d00010-A: PositionType enum SHALL include GENERAL value for
        whole-requirement comments.
        """
        from trace_view.review.models import PositionType
        assert PositionType.GENERAL.value == "general"

    def test_position_type_is_string_enum(self):
        """
        REQ-tv-d00010-A: PositionType SHALL be a string enum for JSON
        serialization compatibility.
        """
        from trace_view.review.models import PositionType
        assert isinstance(PositionType.LINE.value, str)
        assert PositionType.LINE == "line"


class TestRequestStateEnum:
    """Tests for RequestState enumeration."""

    def test_request_state_has_pending_value(self):
        """
        REQ-tv-d00010-B: RequestState enum SHALL include PENDING for
        awaiting approval.
        """
        from trace_view.review.models import RequestState
        assert RequestState.PENDING.value == "pending"

    def test_request_state_has_approved_value(self):
        """
        REQ-tv-d00010-B: RequestState enum SHALL include APPROVED for
        approved requests.
        """
        from trace_view.review.models import RequestState
        assert RequestState.APPROVED.value == "approved"

    def test_request_state_has_rejected_value(self):
        """
        REQ-tv-d00010-B: RequestState enum SHALL include REJECTED for
        rejected requests.
        """
        from trace_view.review.models import RequestState
        assert RequestState.REJECTED.value == "rejected"

    def test_request_state_has_applied_value(self):
        """
        REQ-tv-d00010-B: RequestState enum SHALL include APPLIED for
        applied status changes.
        """
        from trace_view.review.models import RequestState
        assert RequestState.APPLIED.value == "applied"


class TestApprovalDecisionEnum:
    """Tests for ApprovalDecision enumeration."""

    def test_approval_decision_has_approve_value(self):
        """
        REQ-tv-d00010-C: ApprovalDecision enum SHALL include APPROVE value.
        """
        from trace_view.review.models import ApprovalDecision
        assert ApprovalDecision.APPROVE.value == "approve"

    def test_approval_decision_has_reject_value(self):
        """
        REQ-tv-d00010-C: ApprovalDecision enum SHALL include REJECT value.
        """
        from trace_view.review.models import ApprovalDecision
        assert ApprovalDecision.REJECT.value == "reject"


# =============================================================================
# Utility Function Tests
# =============================================================================

class TestValidateReqId:
    """Tests for validate_req_id utility function."""

    def test_validates_core_req_id(self, valid_req_id):
        """
        REQ-tv-d00010-D: validate_req_id SHALL accept core REQ IDs in format
        [pod]NNNNN (e.g., d00027).
        """
        from trace_view.review.models import validate_req_id
        assert validate_req_id(valid_req_id) is True

    def test_validates_sponsor_req_id(self, valid_sponsor_req_id):
        """
        REQ-tv-d00010-D: validate_req_id SHALL accept sponsor-specific REQ IDs
        in format PREFIX-[pod]NNNNN (e.g., CAL-d00001).
        """
        from trace_view.review.models import validate_req_id
        assert validate_req_id(valid_sponsor_req_id) is True

    def test_rejects_req_prefix(self):
        """
        REQ-tv-d00010-D: validate_req_id SHALL reject IDs with REQ- prefix
        since internal format does not use it.
        """
        from trace_view.review.models import validate_req_id
        assert validate_req_id("REQ-d00027") is False

    def test_rejects_invalid_type_letter(self):
        """
        REQ-tv-d00010-D: validate_req_id SHALL reject IDs with invalid type
        letters (only p, o, d are valid).
        """
        from trace_view.review.models import validate_req_id
        assert validate_req_id("x00001") is False
        assert validate_req_id("a00001") is False

    def test_rejects_wrong_digit_count(self):
        """
        REQ-tv-d00010-D: validate_req_id SHALL reject IDs without exactly
        5 digits after the type letter.
        """
        from trace_view.review.models import validate_req_id
        assert validate_req_id("d0001") is False  # 4 digits
        assert validate_req_id("d000001") is False  # 6 digits

    def test_rejects_empty_string(self):
        """
        REQ-tv-d00010-D: validate_req_id SHALL reject empty strings.
        """
        from trace_view.review.models import validate_req_id
        assert validate_req_id("") is False

    def test_rejects_none(self):
        """
        REQ-tv-d00010-D: validate_req_id SHALL reject None values.
        """
        from trace_view.review.models import validate_req_id
        # Should not raise, just return False
        assert validate_req_id(None) is False


class TestValidateHash:
    """Tests for validate_hash utility function."""

    def test_validates_valid_hash(self, valid_hash):
        """
        REQ-tv-d00010-E: validate_hash SHALL accept 8-character hex strings.
        """
        from trace_view.review.models import validate_hash
        assert validate_hash(valid_hash) is True

    def test_validates_uppercase_hash(self):
        """
        REQ-tv-d00010-E: validate_hash SHALL accept uppercase hex characters.
        """
        from trace_view.review.models import validate_hash
        assert validate_hash("A1B2C3D4") is True

    def test_rejects_short_hash(self):
        """
        REQ-tv-d00010-E: validate_hash SHALL reject hashes shorter than 8 chars.
        """
        from trace_view.review.models import validate_hash
        assert validate_hash("a1b2c3") is False

    def test_rejects_long_hash(self):
        """
        REQ-tv-d00010-E: validate_hash SHALL reject hashes longer than 8 chars.
        """
        from trace_view.review.models import validate_hash
        assert validate_hash("a1b2c3d4e5") is False

    def test_rejects_non_hex_characters(self):
        """
        REQ-tv-d00010-E: validate_hash SHALL reject non-hexadecimal characters.
        """
        from trace_view.review.models import validate_hash
        assert validate_hash("a1b2c3g4") is False  # 'g' is invalid

    def test_rejects_empty_string(self):
        """
        REQ-tv-d00010-E: validate_hash SHALL reject empty strings.
        """
        from trace_view.review.models import validate_hash
        assert validate_hash("") is False


class TestGenerateUuid:
    """Tests for generate_uuid utility function."""

    def test_generates_uuid_string(self):
        """
        REQ-tv-d00010-F: generate_uuid SHALL return a valid UUID string.
        """
        from trace_view.review.models import generate_uuid
        result = generate_uuid()
        assert isinstance(result, str)
        # Should be parseable as UUID
        uuid.UUID(result)

    def test_generates_unique_values(self):
        """
        REQ-tv-d00010-F: generate_uuid SHALL return unique values on each call.
        """
        from trace_view.review.models import generate_uuid
        uuids = [generate_uuid() for _ in range(100)]
        assert len(set(uuids)) == 100


class TestNowIso:
    """Tests for now_iso utility function."""

    def test_returns_iso_format(self):
        """
        REQ-tv-d00010-G: now_iso SHALL return current time in ISO 8601 format.
        """
        from trace_view.review.models import now_iso
        result = now_iso()
        # Should be parseable as ISO datetime
        datetime.fromisoformat(result.replace('Z', '+00:00'))

    def test_returns_utc_time(self):
        """
        REQ-tv-d00010-G: now_iso SHALL return UTC time.
        """
        from trace_view.review.models import now_iso
        result = now_iso()
        # Should contain timezone info or be close to UTC now
        parsed = datetime.fromisoformat(result.replace('Z', '+00:00'))
        assert parsed.tzinfo is not None


class TestParseIsoDatetime:
    """Tests for parse_iso_datetime utility function."""

    def test_parses_standard_iso(self, valid_timestamp):
        """
        REQ-tv-d00010-H: parse_iso_datetime SHALL parse standard ISO 8601 strings.
        """
        from trace_view.review.models import parse_iso_datetime
        result = parse_iso_datetime(valid_timestamp)
        assert isinstance(result, datetime)

    def test_parses_z_suffix(self):
        """
        REQ-tv-d00010-H: parse_iso_datetime SHALL handle 'Z' suffix for UTC.
        """
        from trace_view.review.models import parse_iso_datetime
        result = parse_iso_datetime("2024-01-01T12:00:00Z")
        assert isinstance(result, datetime)

    def test_parses_offset_format(self):
        """
        REQ-tv-d00010-H: parse_iso_datetime SHALL handle +HH:MM offset format.
        """
        from trace_view.review.models import parse_iso_datetime
        result = parse_iso_datetime("2024-01-01T12:00:00+00:00")
        assert isinstance(result, datetime)


# =============================================================================
# CommentPosition Tests
# =============================================================================

class TestCommentPositionFactoryMethods:
    """Tests for CommentPosition factory methods."""

    def test_create_line_sets_type(self, valid_hash):
        """
        REQ-tv-d00010-I: create_line factory SHALL set type to 'line'.
        """
        from trace_view.review.models import CommentPosition, PositionType
        pos = CommentPosition.create_line(valid_hash, line_number=10)
        assert pos.type == PositionType.LINE.value

    def test_create_line_sets_line_number(self, valid_hash):
        """
        REQ-tv-d00010-I: create_line factory SHALL set lineNumber field.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_line(valid_hash, line_number=42)
        assert pos.lineNumber == 42

    def test_create_line_sets_hash(self, valid_hash):
        """
        REQ-tv-d00010-I: create_line factory SHALL set hashWhenCreated.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_line(valid_hash, line_number=10)
        assert pos.hashWhenCreated == valid_hash

    def test_create_line_optional_context(self, valid_hash):
        """
        REQ-tv-d00010-I: create_line factory SHALL support optional context.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_line(valid_hash, line_number=10, context="sample")
        assert pos.fallbackContext == "sample"

    def test_create_block_sets_type(self, valid_hash):
        """
        REQ-tv-d00010-J: create_block factory SHALL set type to 'block'.
        """
        from trace_view.review.models import CommentPosition, PositionType
        pos = CommentPosition.create_block(valid_hash, start_line=1, end_line=10)
        assert pos.type == PositionType.BLOCK.value

    def test_create_block_sets_line_range(self, valid_hash):
        """
        REQ-tv-d00010-J: create_block factory SHALL set lineRange as tuple.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_block(valid_hash, start_line=5, end_line=15)
        assert pos.lineRange == (5, 15)

    def test_create_word_sets_type(self, valid_hash):
        """
        REQ-tv-d00010-K: create_word factory SHALL set type to 'word'.
        """
        from trace_view.review.models import CommentPosition, PositionType
        pos = CommentPosition.create_word(valid_hash, keyword="SHALL")
        assert pos.type == PositionType.WORD.value

    def test_create_word_sets_keyword(self, valid_hash):
        """
        REQ-tv-d00010-K: create_word factory SHALL set keyword field.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_word(valid_hash, keyword="MUST")
        assert pos.keyword == "MUST"

    def test_create_word_sets_occurrence(self, valid_hash):
        """
        REQ-tv-d00010-K: create_word factory SHALL set keywordOccurrence.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_word(valid_hash, keyword="SHALL", occurrence=2)
        assert pos.keywordOccurrence == 2

    def test_create_word_default_occurrence(self, valid_hash):
        """
        REQ-tv-d00010-K: create_word factory SHALL default occurrence to 1.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_word(valid_hash, keyword="SHALL")
        assert pos.keywordOccurrence == 1

    def test_create_general_sets_type(self, valid_hash):
        """
        REQ-tv-d00010-L: create_general factory SHALL set type to 'general'.
        """
        from trace_view.review.models import CommentPosition, PositionType
        pos = CommentPosition.create_general(valid_hash)
        assert pos.type == PositionType.GENERAL.value

    def test_create_general_no_position_fields(self, valid_hash):
        """
        REQ-tv-d00010-L: create_general factory SHALL not set position fields.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_general(valid_hash)
        assert pos.lineNumber is None
        assert pos.lineRange is None
        assert pos.keyword is None


class TestCommentPositionValidation:
    """Tests for CommentPosition validation."""

    def test_validate_line_requires_line_number(self, valid_hash):
        """
        REQ-tv-d00010-M: CommentPosition validation SHALL require lineNumber
        for 'line' type.
        """
        from trace_view.review.models import CommentPosition, PositionType
        pos = CommentPosition(
            type=PositionType.LINE.value,
            hashWhenCreated=valid_hash,
            lineNumber=None
        )
        is_valid, errors = pos.validate()
        assert is_valid is False
        assert any("lineNumber" in e for e in errors)

    def test_validate_line_positive_line_number(self, valid_hash):
        """
        REQ-tv-d00010-M: CommentPosition validation SHALL require positive
        lineNumber for 'line' type.
        """
        from trace_view.review.models import CommentPosition, PositionType
        pos = CommentPosition(
            type=PositionType.LINE.value,
            hashWhenCreated=valid_hash,
            lineNumber=0
        )
        is_valid, errors = pos.validate()
        assert is_valid is False
        assert any("positive" in e.lower() or "lineNumber" in e for e in errors)

    def test_validate_block_requires_line_range(self, valid_hash):
        """
        REQ-tv-d00010-N: CommentPosition validation SHALL require lineRange
        for 'block' type.
        """
        from trace_view.review.models import CommentPosition, PositionType
        pos = CommentPosition(
            type=PositionType.BLOCK.value,
            hashWhenCreated=valid_hash,
            lineRange=None
        )
        is_valid, errors = pos.validate()
        assert is_valid is False
        assert any("lineRange" in e for e in errors)

    def test_validate_block_valid_range(self, valid_hash):
        """
        REQ-tv-d00010-N: CommentPosition validation SHALL require end >= start
        in lineRange.
        """
        from trace_view.review.models import CommentPosition, PositionType
        pos = CommentPosition(
            type=PositionType.BLOCK.value,
            hashWhenCreated=valid_hash,
            lineRange=(10, 5)  # Invalid: end < start
        )
        is_valid, errors = pos.validate()
        assert is_valid is False
        assert any("lineRange" in e or "Invalid" in e for e in errors)

    def test_validate_word_requires_keyword(self, valid_hash):
        """
        REQ-tv-d00010-O: CommentPosition validation SHALL require keyword
        for 'word' type.
        """
        from trace_view.review.models import CommentPosition, PositionType
        pos = CommentPosition(
            type=PositionType.WORD.value,
            hashWhenCreated=valid_hash,
            keyword=None
        )
        is_valid, errors = pos.validate()
        assert is_valid is False
        assert any("keyword" in e for e in errors)

    def test_validate_invalid_hash(self):
        """
        REQ-tv-d00010-P: CommentPosition validation SHALL reject invalid hash.
        """
        from trace_view.review.models import CommentPosition, PositionType
        pos = CommentPosition(
            type=PositionType.GENERAL.value,
            hashWhenCreated="invalid"
        )
        is_valid, errors = pos.validate()
        assert is_valid is False
        assert any("hash" in e.lower() for e in errors)

    def test_validate_invalid_type(self, valid_hash):
        """
        REQ-tv-d00010-P: CommentPosition validation SHALL reject invalid type.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition(
            type="invalid_type",
            hashWhenCreated=valid_hash
        )
        is_valid, errors = pos.validate()
        assert is_valid is False
        assert any("type" in e.lower() for e in errors)

    def test_validate_valid_position(self, valid_hash):
        """
        REQ-tv-d00010-P: CommentPosition validation SHALL pass for valid data.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_line(valid_hash, line_number=10)
        is_valid, errors = pos.validate()
        assert is_valid is True
        assert errors == []


class TestCommentPositionSerialization:
    """Tests for CommentPosition to_dict/from_dict serialization."""

    def test_to_dict_includes_type(self, valid_hash):
        """
        REQ-tv-d00010-Q: to_dict SHALL include type field.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_line(valid_hash, line_number=10)
        data = pos.to_dict()
        assert "type" in data
        assert data["type"] == "line"

    def test_to_dict_includes_hash(self, valid_hash):
        """
        REQ-tv-d00010-Q: to_dict SHALL include hashWhenCreated field.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_line(valid_hash, line_number=10)
        data = pos.to_dict()
        assert "hashWhenCreated" in data
        assert data["hashWhenCreated"] == valid_hash

    def test_to_dict_excludes_none_fields(self, valid_hash):
        """
        REQ-tv-d00010-Q: to_dict SHALL exclude None optional fields.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_line(valid_hash, line_number=10)
        data = pos.to_dict()
        assert "keyword" not in data
        assert "lineRange" not in data

    def test_to_dict_converts_tuple_to_list(self, valid_hash):
        """
        REQ-tv-d00010-Q: to_dict SHALL convert lineRange tuple to list for JSON.
        """
        from trace_view.review.models import CommentPosition
        pos = CommentPosition.create_block(valid_hash, start_line=1, end_line=10)
        data = pos.to_dict()
        assert isinstance(data["lineRange"], list)
        assert data["lineRange"] == [1, 10]

    def test_from_dict_creates_instance(self, valid_hash):
        """
        REQ-tv-d00010-R: from_dict SHALL create CommentPosition from dict.
        """
        from trace_view.review.models import CommentPosition
        data = {
            "type": "line",
            "hashWhenCreated": valid_hash,
            "lineNumber": 42
        }
        pos = CommentPosition.from_dict(data)
        assert pos.type == "line"
        assert pos.lineNumber == 42

    def test_from_dict_converts_list_to_tuple(self, valid_hash):
        """
        REQ-tv-d00010-R: from_dict SHALL convert lineRange list to tuple.
        """
        from trace_view.review.models import CommentPosition
        data = {
            "type": "block",
            "hashWhenCreated": valid_hash,
            "lineRange": [5, 15]
        }
        pos = CommentPosition.from_dict(data)
        assert isinstance(pos.lineRange, tuple)
        assert pos.lineRange == (5, 15)

    def test_roundtrip_serialization(self, valid_hash):
        """
        REQ-tv-d00010-R: from_dict(to_dict()) SHALL preserve all data.
        """
        from trace_view.review.models import CommentPosition
        original = CommentPosition.create_word(
            valid_hash, keyword="SHALL", occurrence=2, context="test"
        )
        data = original.to_dict()
        restored = CommentPosition.from_dict(data)
        assert restored.type == original.type
        assert restored.hashWhenCreated == original.hashWhenCreated
        assert restored.keyword == original.keyword
        assert restored.keywordOccurrence == original.keywordOccurrence
        assert restored.fallbackContext == original.fallbackContext


# =============================================================================
# Comment Tests
# =============================================================================

class TestCommentFactory:
    """Tests for Comment.create factory method."""

    def test_create_generates_id(self, sample_author, sample_comment_body):
        """
        REQ-tv-d00010-S: Comment.create SHALL generate a UUID for id.
        """
        from trace_view.review.models import Comment
        comment = Comment.create(author=sample_author, body=sample_comment_body)
        assert comment.id is not None
        uuid.UUID(comment.id)  # Should be valid UUID

    def test_create_generates_timestamp(self, sample_author, sample_comment_body):
        """
        REQ-tv-d00010-S: Comment.create SHALL generate timestamp.
        """
        from trace_view.review.models import Comment
        comment = Comment.create(author=sample_author, body=sample_comment_body)
        assert comment.timestamp is not None
        datetime.fromisoformat(comment.timestamp.replace('Z', '+00:00'))

    def test_create_sets_author(self, sample_author, sample_comment_body):
        """
        REQ-tv-d00010-S: Comment.create SHALL set author field.
        """
        from trace_view.review.models import Comment
        comment = Comment.create(author=sample_author, body=sample_comment_body)
        assert comment.author == sample_author

    def test_create_sets_body(self, sample_author, sample_comment_body):
        """
        REQ-tv-d00010-S: Comment.create SHALL set body field.
        """
        from trace_view.review.models import Comment
        comment = Comment.create(author=sample_author, body=sample_comment_body)
        assert comment.body == sample_comment_body


class TestCommentValidation:
    """Tests for Comment validation."""

    def test_validate_requires_id(self, sample_author, sample_comment_body, valid_timestamp):
        """
        REQ-tv-d00010-T: Comment validation SHALL require id field.
        """
        from trace_view.review.models import Comment
        comment = Comment(
            id="",
            author=sample_author,
            timestamp=valid_timestamp,
            body=sample_comment_body
        )
        is_valid, errors = comment.validate()
        assert is_valid is False
        assert any("id" in e.lower() for e in errors)

    def test_validate_requires_author(self, sample_comment_body, valid_timestamp):
        """
        REQ-tv-d00010-T: Comment validation SHALL require author field.
        """
        from trace_view.review.models import Comment
        comment = Comment(
            id="test-id",
            author="",
            timestamp=valid_timestamp,
            body=sample_comment_body
        )
        is_valid, errors = comment.validate()
        assert is_valid is False
        assert any("author" in e.lower() for e in errors)

    def test_validate_requires_timestamp(self, sample_author, sample_comment_body):
        """
        REQ-tv-d00010-T: Comment validation SHALL require timestamp field.
        """
        from trace_view.review.models import Comment
        comment = Comment(
            id="test-id",
            author=sample_author,
            timestamp="",
            body=sample_comment_body
        )
        is_valid, errors = comment.validate()
        assert is_valid is False
        assert any("timestamp" in e.lower() for e in errors)

    def test_validate_requires_non_empty_body(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-T: Comment validation SHALL require non-empty body.
        """
        from trace_view.review.models import Comment
        comment = Comment(
            id="test-id",
            author=sample_author,
            timestamp=valid_timestamp,
            body="   "  # Whitespace only
        )
        is_valid, errors = comment.validate()
        assert is_valid is False
        assert any("body" in e.lower() for e in errors)

    def test_validate_timestamp_format(self, sample_author, sample_comment_body):
        """
        REQ-tv-d00010-T: Comment validation SHALL validate timestamp format.
        """
        from trace_view.review.models import Comment
        comment = Comment(
            id="test-id",
            author=sample_author,
            timestamp="not-a-timestamp",
            body=sample_comment_body
        )
        is_valid, errors = comment.validate()
        assert is_valid is False
        assert any("timestamp" in e.lower() for e in errors)

    def test_validate_valid_comment(self, sample_comment):
        """
        REQ-tv-d00010-T: Comment validation SHALL pass for valid data.
        """
        is_valid, errors = sample_comment.validate()
        assert is_valid is True
        assert errors == []


class TestCommentSerialization:
    """Tests for Comment to_dict/from_dict serialization."""

    def test_to_dict_all_fields(self, sample_comment):
        """
        REQ-tv-d00010-U: Comment.to_dict SHALL include all fields.
        """
        data = sample_comment.to_dict()
        assert "id" in data
        assert "author" in data
        assert "timestamp" in data
        assert "body" in data

    def test_from_dict_creates_instance(self, sample_author, sample_comment_body, valid_timestamp):
        """
        REQ-tv-d00010-U: Comment.from_dict SHALL create Comment instance.
        """
        from trace_view.review.models import Comment
        data = {
            "id": "test-id",
            "author": sample_author,
            "timestamp": valid_timestamp,
            "body": sample_comment_body
        }
        comment = Comment.from_dict(data)
        assert comment.id == "test-id"
        assert comment.author == sample_author

    def test_roundtrip_serialization(self, sample_comment):
        """
        REQ-tv-d00010-U: from_dict(to_dict()) SHALL preserve all data.
        """
        from trace_view.review.models import Comment
        data = sample_comment.to_dict()
        restored = Comment.from_dict(data)
        assert restored.id == sample_comment.id
        assert restored.author == sample_comment.author
        assert restored.timestamp == sample_comment.timestamp
        assert restored.body == sample_comment.body


# =============================================================================
# Thread Tests
# =============================================================================

class TestThreadFactory:
    """Tests for Thread.create factory method."""

    def test_create_generates_thread_id(self, valid_req_id, sample_author, sample_position):
        """
        REQ-tv-d00010-V: Thread.create SHALL generate a UUID for threadId.
        """
        from trace_view.review.models import Thread
        thread = Thread.create(
            req_id=valid_req_id,
            creator=sample_author,
            position=sample_position
        )
        assert thread.threadId is not None
        uuid.UUID(thread.threadId)

    def test_create_sets_req_id(self, valid_req_id, sample_author, sample_position):
        """
        REQ-tv-d00010-V: Thread.create SHALL set reqId field.
        """
        from trace_view.review.models import Thread
        thread = Thread.create(
            req_id=valid_req_id,
            creator=sample_author,
            position=sample_position
        )
        assert thread.reqId == valid_req_id

    def test_create_sets_creator(self, valid_req_id, sample_author, sample_position):
        """
        REQ-tv-d00010-V: Thread.create SHALL set createdBy field.
        """
        from trace_view.review.models import Thread
        thread = Thread.create(
            req_id=valid_req_id,
            creator=sample_author,
            position=sample_position
        )
        assert thread.createdBy == sample_author

    def test_create_with_initial_comment(
        self, valid_req_id, sample_author, sample_position, sample_comment_body
    ):
        """
        REQ-tv-d00010-V: Thread.create SHALL add initial comment if provided.
        """
        from trace_view.review.models import Thread
        thread = Thread.create(
            req_id=valid_req_id,
            creator=sample_author,
            position=sample_position,
            initial_comment=sample_comment_body
        )
        assert len(thread.comments) == 1
        assert thread.comments[0].body == sample_comment_body

    def test_create_not_resolved_by_default(self, valid_req_id, sample_author, sample_position):
        """
        REQ-tv-d00010-V: Thread.create SHALL set resolved to False by default.
        """
        from trace_view.review.models import Thread
        thread = Thread.create(
            req_id=valid_req_id,
            creator=sample_author,
            position=sample_position
        )
        assert thread.resolved is False


class TestThreadMethods:
    """Tests for Thread methods."""

    def test_add_comment(self, sample_thread, sample_comment_body):
        """
        REQ-tv-d00010-W: Thread.add_comment SHALL create and append comment.
        """
        initial_count = len(sample_thread.comments)
        sample_thread.add_comment("another_user", "Another comment")
        assert len(sample_thread.comments) == initial_count + 1

    def test_add_comment_returns_comment(self, sample_thread):
        """
        REQ-tv-d00010-W: Thread.add_comment SHALL return the new Comment.
        """
        from trace_view.review.models import Comment
        result = sample_thread.add_comment("user", "body")
        assert isinstance(result, Comment)
        assert result.author == "user"

    def test_resolve_sets_resolved(self, sample_thread):
        """
        REQ-tv-d00010-X: Thread.resolve SHALL set resolved to True.
        """
        sample_thread.resolve("resolver_user")
        assert sample_thread.resolved is True

    def test_resolve_sets_resolved_by(self, sample_thread):
        """
        REQ-tv-d00010-X: Thread.resolve SHALL set resolvedBy to user.
        """
        sample_thread.resolve("resolver_user")
        assert sample_thread.resolvedBy == "resolver_user"

    def test_resolve_sets_resolved_at(self, sample_thread):
        """
        REQ-tv-d00010-X: Thread.resolve SHALL set resolvedAt timestamp.
        """
        sample_thread.resolve("resolver_user")
        assert sample_thread.resolvedAt is not None
        datetime.fromisoformat(sample_thread.resolvedAt.replace('Z', '+00:00'))

    def test_unresolve_clears_resolution(self, sample_thread):
        """
        REQ-tv-d00010-Y: Thread.unresolve SHALL clear resolution state.
        """
        sample_thread.resolve("user")
        sample_thread.unresolve()
        assert sample_thread.resolved is False
        assert sample_thread.resolvedBy is None
        assert sample_thread.resolvedAt is None


class TestThreadValidation:
    """Tests for Thread validation."""

    def test_validate_requires_thread_id(
        self, valid_req_id, sample_author, sample_position, valid_timestamp
    ):
        """
        REQ-tv-d00010-Z: Thread validation SHALL require threadId.
        """
        from trace_view.review.models import Thread
        thread = Thread(
            threadId="",
            reqId=valid_req_id,
            createdBy=sample_author,
            createdAt=valid_timestamp,
            position=sample_position
        )
        is_valid, errors = thread.validate()
        assert is_valid is False
        assert any("threadId" in e for e in errors)

    def test_validate_requires_valid_req_id(
        self, sample_author, sample_position, valid_timestamp
    ):
        """
        REQ-tv-d00010-Z: Thread validation SHALL validate reqId format.
        """
        from trace_view.review.models import Thread
        thread = Thread(
            threadId="test-thread-id",
            reqId="INVALID",
            createdBy=sample_author,
            createdAt=valid_timestamp,
            position=sample_position
        )
        is_valid, errors = thread.validate()
        assert is_valid is False
        assert any("requirement" in e.lower() or "reqId" in e for e in errors)

    def test_validate_resolved_requires_resolved_by(
        self, valid_req_id, sample_author, sample_position, valid_timestamp
    ):
        """
        REQ-tv-d00010-Z: Resolved thread validation SHALL require resolvedBy.
        """
        from trace_view.review.models import Thread
        thread = Thread(
            threadId="test-thread-id",
            reqId=valid_req_id,
            createdBy=sample_author,
            createdAt=valid_timestamp,
            position=sample_position,
            resolved=True,
            resolvedBy=None,
            resolvedAt=valid_timestamp
        )
        is_valid, errors = thread.validate()
        assert is_valid is False
        assert any("resolvedBy" in e for e in errors)

    def test_validate_validates_position(
        self, valid_req_id, sample_author, valid_timestamp
    ):
        """
        REQ-tv-d00010-Z: Thread validation SHALL validate position.
        """
        from trace_view.review.models import Thread, CommentPosition
        invalid_position = CommentPosition(
            type="invalid",
            hashWhenCreated="bad"
        )
        thread = Thread(
            threadId="test-thread-id",
            reqId=valid_req_id,
            createdBy=sample_author,
            createdAt=valid_timestamp,
            position=invalid_position
        )
        is_valid, errors = thread.validate()
        assert is_valid is False
        assert any("Position" in e or "position" in e for e in errors)

    def test_validate_validates_comments(self, sample_thread, valid_timestamp):
        """
        REQ-tv-d00010-Z: Thread validation SHALL validate all comments.
        """
        from trace_view.review.models import Comment
        # Add an invalid comment
        invalid_comment = Comment(id="", author="", timestamp=valid_timestamp, body="test")
        sample_thread.comments.append(invalid_comment)
        is_valid, errors = sample_thread.validate()
        assert is_valid is False
        assert any("Comment" in e for e in errors)


class TestThreadSerialization:
    """Tests for Thread to_dict/from_dict serialization."""

    def test_to_dict_includes_all_fields(self, sample_thread):
        """
        REQ-tv-d00010-AA: Thread.to_dict SHALL include all fields.
        """
        data = sample_thread.to_dict()
        assert "threadId" in data
        assert "reqId" in data
        assert "createdBy" in data
        assert "createdAt" in data
        assert "position" in data
        assert "resolved" in data
        assert "comments" in data

    def test_to_dict_serializes_position(self, sample_thread):
        """
        REQ-tv-d00010-AA: Thread.to_dict SHALL serialize position as dict.
        """
        data = sample_thread.to_dict()
        assert isinstance(data["position"], dict)
        assert "type" in data["position"]

    def test_to_dict_serializes_comments(self, sample_thread):
        """
        REQ-tv-d00010-AA: Thread.to_dict SHALL serialize comments as list.
        """
        data = sample_thread.to_dict()
        assert isinstance(data["comments"], list)

    def test_from_dict_creates_instance(
        self, valid_req_id, sample_author, valid_hash, valid_timestamp
    ):
        """
        REQ-tv-d00010-AB: Thread.from_dict SHALL create Thread instance.
        """
        from trace_view.review.models import Thread
        data = {
            "threadId": "test-thread-id",
            "reqId": valid_req_id,
            "createdBy": sample_author,
            "createdAt": valid_timestamp,
            "position": {
                "type": "general",
                "hashWhenCreated": valid_hash
            },
            "resolved": False,
            "comments": []
        }
        thread = Thread.from_dict(data)
        assert thread.threadId == "test-thread-id"
        assert thread.reqId == valid_req_id

    def test_from_dict_deserializes_position(
        self, valid_req_id, sample_author, valid_hash, valid_timestamp
    ):
        """
        REQ-tv-d00010-AB: Thread.from_dict SHALL deserialize position.
        """
        from trace_view.review.models import Thread, CommentPosition
        data = {
            "threadId": "test-thread-id",
            "reqId": valid_req_id,
            "createdBy": sample_author,
            "createdAt": valid_timestamp,
            "position": {
                "type": "line",
                "hashWhenCreated": valid_hash,
                "lineNumber": 10
            },
            "resolved": False,
            "comments": []
        }
        thread = Thread.from_dict(data)
        assert isinstance(thread.position, CommentPosition)
        assert thread.position.lineNumber == 10

    def test_roundtrip_serialization(self, sample_thread):
        """
        REQ-tv-d00010-AB: from_dict(to_dict()) SHALL preserve all data.
        """
        from trace_view.review.models import Thread
        data = sample_thread.to_dict()
        restored = Thread.from_dict(data)
        assert restored.threadId == sample_thread.threadId
        assert restored.reqId == sample_thread.reqId
        assert len(restored.comments) == len(sample_thread.comments)


# =============================================================================
# ReviewFlag Tests
# =============================================================================

class TestReviewFlagFactory:
    """Tests for ReviewFlag factory methods."""

    def test_create_sets_flagged_true(self, sample_author):
        """
        REQ-tv-d00010-AC: ReviewFlag.create SHALL set flaggedForReview True.
        """
        from trace_view.review.models import ReviewFlag
        flag = ReviewFlag.create(
            user=sample_author,
            reason="Needs review",
            scope=["product_owner"]
        )
        assert flag.flaggedForReview is True

    def test_create_sets_user(self, sample_author):
        """
        REQ-tv-d00010-AC: ReviewFlag.create SHALL set flaggedBy to user.
        """
        from trace_view.review.models import ReviewFlag
        flag = ReviewFlag.create(
            user=sample_author,
            reason="Needs review",
            scope=["product_owner"]
        )
        assert flag.flaggedBy == sample_author

    def test_create_generates_timestamp(self, sample_author):
        """
        REQ-tv-d00010-AC: ReviewFlag.create SHALL generate timestamp.
        """
        from trace_view.review.models import ReviewFlag
        flag = ReviewFlag.create(
            user=sample_author,
            reason="Needs review",
            scope=["product_owner"]
        )
        assert flag.flaggedAt is not None
        datetime.fromisoformat(flag.flaggedAt.replace('Z', '+00:00'))

    def test_cleared_returns_unflagged(self):
        """
        REQ-tv-d00010-AD: ReviewFlag.cleared SHALL return unflagged state.
        """
        from trace_view.review.models import ReviewFlag
        flag = ReviewFlag.cleared()
        assert flag.flaggedForReview is False
        assert flag.flaggedBy == ""
        assert flag.flaggedAt == ""
        assert flag.reason == ""
        assert flag.scope == []


class TestReviewFlagMethods:
    """Tests for ReviewFlag methods."""

    def test_clear_resets_all_fields(self, sample_author):
        """
        REQ-tv-d00010-AE: ReviewFlag.clear SHALL reset all fields.
        """
        from trace_view.review.models import ReviewFlag
        flag = ReviewFlag.create(
            user=sample_author,
            reason="Needs review",
            scope=["product_owner"]
        )
        flag.clear()
        assert flag.flaggedForReview is False
        assert flag.flaggedBy == ""
        assert flag.flaggedAt == ""
        assert flag.reason == ""
        assert flag.scope == []


class TestReviewFlagValidation:
    """Tests for ReviewFlag validation."""

    def test_validate_flagged_requires_user(self, valid_timestamp):
        """
        REQ-tv-d00010-AF: Flagged ReviewFlag SHALL require flaggedBy.
        """
        from trace_view.review.models import ReviewFlag
        flag = ReviewFlag(
            flaggedForReview=True,
            flaggedBy="",
            flaggedAt=valid_timestamp,
            reason="test",
            scope=["user"]
        )
        is_valid, errors = flag.validate()
        assert is_valid is False
        assert any("flaggedBy" in e for e in errors)

    def test_validate_flagged_requires_reason(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AF: Flagged ReviewFlag SHALL require reason.
        """
        from trace_view.review.models import ReviewFlag
        flag = ReviewFlag(
            flaggedForReview=True,
            flaggedBy=sample_author,
            flaggedAt=valid_timestamp,
            reason="",
            scope=["user"]
        )
        is_valid, errors = flag.validate()
        assert is_valid is False
        assert any("reason" in e for e in errors)

    def test_validate_flagged_requires_scope(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AF: Flagged ReviewFlag SHALL require non-empty scope.
        """
        from trace_view.review.models import ReviewFlag
        flag = ReviewFlag(
            flaggedForReview=True,
            flaggedBy=sample_author,
            flaggedAt=valid_timestamp,
            reason="test",
            scope=[]
        )
        is_valid, errors = flag.validate()
        assert is_valid is False
        assert any("scope" in e for e in errors)

    def test_validate_unflagged_passes(self):
        """
        REQ-tv-d00010-AF: Unflagged ReviewFlag SHALL pass validation.
        """
        from trace_view.review.models import ReviewFlag
        flag = ReviewFlag.cleared()
        is_valid, errors = flag.validate()
        assert is_valid is True


class TestReviewFlagSerialization:
    """Tests for ReviewFlag to_dict/from_dict serialization."""

    def test_to_dict_all_fields(self, sample_author):
        """
        REQ-tv-d00010-AG: ReviewFlag.to_dict SHALL include all fields.
        """
        from trace_view.review.models import ReviewFlag
        flag = ReviewFlag.create(sample_author, "test", ["user"])
        data = flag.to_dict()
        assert "flaggedForReview" in data
        assert "flaggedBy" in data
        assert "flaggedAt" in data
        assert "reason" in data
        assert "scope" in data

    def test_from_dict_creates_instance(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AG: ReviewFlag.from_dict SHALL create instance.
        """
        from trace_view.review.models import ReviewFlag
        data = {
            "flaggedForReview": True,
            "flaggedBy": sample_author,
            "flaggedAt": valid_timestamp,
            "reason": "test",
            "scope": ["user"]
        }
        flag = ReviewFlag.from_dict(data)
        assert flag.flaggedForReview is True
        assert flag.flaggedBy == sample_author

    def test_roundtrip_serialization(self, sample_author):
        """
        REQ-tv-d00010-AG: from_dict(to_dict()) SHALL preserve all data.
        """
        from trace_view.review.models import ReviewFlag
        original = ReviewFlag.create(sample_author, "test reason", ["a", "b"])
        data = original.to_dict()
        restored = ReviewFlag.from_dict(data)
        assert restored.flaggedForReview == original.flaggedForReview
        assert restored.scope == original.scope


# =============================================================================
# Approval Tests
# =============================================================================

class TestApprovalFactory:
    """Tests for Approval.create factory method."""

    def test_create_sets_user(self, sample_author):
        """
        REQ-tv-d00010-AH: Approval.create SHALL set user field.
        """
        from trace_view.review.models import Approval, ApprovalDecision
        approval = Approval.create(
            user=sample_author,
            decision=ApprovalDecision.APPROVE.value
        )
        assert approval.user == sample_author

    def test_create_sets_decision(self, sample_author):
        """
        REQ-tv-d00010-AH: Approval.create SHALL set decision field.
        """
        from trace_view.review.models import Approval, ApprovalDecision
        approval = Approval.create(
            user=sample_author,
            decision=ApprovalDecision.REJECT.value
        )
        assert approval.decision == ApprovalDecision.REJECT.value

    def test_create_generates_timestamp(self, sample_author):
        """
        REQ-tv-d00010-AH: Approval.create SHALL generate timestamp.
        """
        from trace_view.review.models import Approval, ApprovalDecision
        approval = Approval.create(
            user=sample_author,
            decision=ApprovalDecision.APPROVE.value
        )
        assert approval.at is not None

    def test_create_optional_comment(self, sample_author):
        """
        REQ-tv-d00010-AH: Approval.create SHALL support optional comment.
        """
        from trace_view.review.models import Approval, ApprovalDecision
        approval = Approval.create(
            user=sample_author,
            decision=ApprovalDecision.APPROVE.value,
            comment="LGTM"
        )
        assert approval.comment == "LGTM"


class TestApprovalValidation:
    """Tests for Approval validation."""

    def test_validate_requires_user(self, valid_timestamp):
        """
        REQ-tv-d00010-AI: Approval validation SHALL require user.
        """
        from trace_view.review.models import Approval
        approval = Approval(user="", decision="approve", at=valid_timestamp)
        is_valid, errors = approval.validate()
        assert is_valid is False
        assert any("user" in e.lower() for e in errors)

    def test_validate_requires_valid_decision(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AI: Approval validation SHALL require valid decision.
        """
        from trace_view.review.models import Approval
        approval = Approval(user=sample_author, decision="invalid", at=valid_timestamp)
        is_valid, errors = approval.validate()
        assert is_valid is False
        assert any("decision" in e.lower() for e in errors)

    def test_validate_requires_timestamp(self, sample_author):
        """
        REQ-tv-d00010-AI: Approval validation SHALL require timestamp.
        """
        from trace_view.review.models import Approval
        approval = Approval(user=sample_author, decision="approve", at="")
        is_valid, errors = approval.validate()
        assert is_valid is False
        assert any("at" in e.lower() or "timestamp" in e.lower() for e in errors)

    def test_validate_valid_approval(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AI: Approval validation SHALL pass for valid data.
        """
        from trace_view.review.models import Approval
        approval = Approval(user=sample_author, decision="approve", at=valid_timestamp)
        is_valid, errors = approval.validate()
        assert is_valid is True


class TestApprovalSerialization:
    """Tests for Approval to_dict/from_dict serialization."""

    def test_to_dict_excludes_none_comment(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AJ: Approval.to_dict SHALL exclude None comment.
        """
        from trace_view.review.models import Approval
        approval = Approval(user=sample_author, decision="approve", at=valid_timestamp)
        data = approval.to_dict()
        assert "comment" not in data

    def test_to_dict_includes_comment_when_set(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AJ: Approval.to_dict SHALL include comment when set.
        """
        from trace_view.review.models import Approval
        approval = Approval(
            user=sample_author, decision="approve", at=valid_timestamp, comment="test"
        )
        data = approval.to_dict()
        assert "comment" in data
        assert data["comment"] == "test"

    def test_roundtrip_serialization(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AJ: from_dict(to_dict()) SHALL preserve all data.
        """
        from trace_view.review.models import Approval
        original = Approval(
            user=sample_author, decision="reject", at=valid_timestamp, comment="nope"
        )
        data = original.to_dict()
        restored = Approval.from_dict(data)
        assert restored.user == original.user
        assert restored.decision == original.decision
        assert restored.comment == original.comment


# =============================================================================
# StatusRequest Tests
# =============================================================================

class TestStatusRequestFactory:
    """Tests for StatusRequest.create factory method."""

    def test_create_generates_request_id(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AK: StatusRequest.create SHALL generate requestId.
        """
        from trace_view.review.models import StatusRequest
        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready for review"
        )
        assert request.requestId is not None
        uuid.UUID(request.requestId)

    def test_create_sets_type_status_change(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AK: StatusRequest.create SHALL set type to 'status_change'.
        """
        from trace_view.review.models import StatusRequest
        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready"
        )
        assert request.type == "status_change"

    def test_create_uses_default_approvers(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AK: StatusRequest.create SHALL use default approvers
        based on status transition.
        """
        from trace_view.review.models import StatusRequest
        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready"
        )
        assert "product_owner" in request.requiredApprovers
        assert "tech_lead" in request.requiredApprovers

    def test_create_allows_custom_approvers(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AK: StatusRequest.create SHALL allow custom approvers.
        """
        from trace_view.review.models import StatusRequest
        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready",
            required_approvers=["custom_approver"]
        )
        assert request.requiredApprovers == ["custom_approver"]

    def test_create_initial_state_pending(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AK: StatusRequest.create SHALL set state to PENDING.
        """
        from trace_view.review.models import StatusRequest, RequestState
        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready"
        )
        assert request.state == RequestState.PENDING.value


class TestStatusRequestMethods:
    """Tests for StatusRequest methods."""

    def test_add_approval_appends(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AL: add_approval SHALL append approval to list.
        """
        from trace_view.review.models import StatusRequest
        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready"
        )
        request.add_approval("approver", "approve")
        assert len(request.approvals) == 1

    def test_add_approval_updates_state_on_reject(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AL: add_approval SHALL update state to REJECTED on reject.
        """
        from trace_view.review.models import StatusRequest, RequestState
        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready"
        )
        request.add_approval("approver", "reject")
        assert request.state == RequestState.REJECTED.value

    def test_add_approval_updates_state_on_full_approval(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AL: add_approval SHALL update state to APPROVED when
        all required approvers have approved.
        """
        from trace_view.review.models import StatusRequest, RequestState
        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready",
            required_approvers=["approver1", "approver2"]
        )
        request.add_approval("approver1", "approve")
        assert request.state == RequestState.PENDING.value
        request.add_approval("approver2", "approve")
        assert request.state == RequestState.APPROVED.value

    def test_mark_applied_requires_approved(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AM: mark_applied SHALL raise if not APPROVED.
        """
        from trace_view.review.models import StatusRequest
        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready"
        )
        with pytest.raises(ValueError):
            request.mark_applied()

    def test_mark_applied_sets_applied_state(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AM: mark_applied SHALL set state to APPLIED.
        """
        from trace_view.review.models import StatusRequest, RequestState
        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready",
            required_approvers=["approver"]
        )
        request.add_approval("approver", "approve")
        request.mark_applied()
        assert request.state == RequestState.APPLIED.value


class TestStatusRequestValidation:
    """Tests for StatusRequest validation."""

    def test_validate_requires_valid_req_id(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AN: StatusRequest validation SHALL require valid reqId.
        """
        from trace_view.review.models import StatusRequest, RequestState
        request = StatusRequest(
            requestId="test-id",
            reqId="INVALID",
            type="status_change",
            fromStatus="Draft",
            toStatus="Active",
            requestedBy=sample_author,
            requestedAt=valid_timestamp,
            justification="test",
            approvals=[],
            requiredApprovers=["user"],
            state=RequestState.PENDING.value
        )
        is_valid, errors = request.validate()
        assert is_valid is False
        assert any("requirement" in e.lower() or "reqId" in e for e in errors)

    def test_validate_requires_different_statuses(self, valid_req_id, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AN: StatusRequest validation SHALL require different
        fromStatus and toStatus.
        """
        from trace_view.review.models import StatusRequest, RequestState
        request = StatusRequest(
            requestId="test-id",
            reqId=valid_req_id,
            type="status_change",
            fromStatus="Draft",
            toStatus="Draft",
            requestedBy=sample_author,
            requestedAt=valid_timestamp,
            justification="test",
            approvals=[],
            requiredApprovers=["user"],
            state=RequestState.PENDING.value
        )
        is_valid, errors = request.validate()
        assert is_valid is False
        assert any("different" in e.lower() or "same" in e.lower() for e in errors)

    def test_validate_requires_valid_statuses(self, valid_req_id, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AN: StatusRequest validation SHALL require valid status values.
        """
        from trace_view.review.models import StatusRequest, RequestState
        request = StatusRequest(
            requestId="test-id",
            reqId=valid_req_id,
            type="status_change",
            fromStatus="Invalid",
            toStatus="Active",
            requestedBy=sample_author,
            requestedAt=valid_timestamp,
            justification="test",
            approvals=[],
            requiredApprovers=["user"],
            state=RequestState.PENDING.value
        )
        is_valid, errors = request.validate()
        assert is_valid is False
        assert any("fromStatus" in e or "status" in e.lower() for e in errors)

    def test_validate_requires_justification(self, valid_req_id, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AN: StatusRequest validation SHALL require justification.
        """
        from trace_view.review.models import StatusRequest, RequestState
        request = StatusRequest(
            requestId="test-id",
            reqId=valid_req_id,
            type="status_change",
            fromStatus="Draft",
            toStatus="Active",
            requestedBy=sample_author,
            requestedAt=valid_timestamp,
            justification="",
            approvals=[],
            requiredApprovers=["user"],
            state=RequestState.PENDING.value
        )
        is_valid, errors = request.validate()
        assert is_valid is False
        assert any("justification" in e.lower() for e in errors)


class TestStatusRequestSerialization:
    """Tests for StatusRequest to_dict/from_dict serialization."""

    def test_to_dict_all_fields(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AO: StatusRequest.to_dict SHALL include all fields.
        """
        from trace_view.review.models import StatusRequest
        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready"
        )
        data = request.to_dict()
        assert "requestId" in data
        assert "reqId" in data
        assert "type" in data
        assert "fromStatus" in data
        assert "toStatus" in data
        assert "requestedBy" in data
        assert "requestedAt" in data
        assert "justification" in data
        assert "approvals" in data
        assert "requiredApprovers" in data
        assert "state" in data

    def test_from_dict_deserializes_approvals(
        self, valid_req_id, sample_author, valid_timestamp
    ):
        """
        REQ-tv-d00010-AO: StatusRequest.from_dict SHALL deserialize approvals.
        """
        from trace_view.review.models import StatusRequest, Approval
        data = {
            "requestId": "test-id",
            "reqId": valid_req_id,
            "type": "status_change",
            "fromStatus": "Draft",
            "toStatus": "Active",
            "requestedBy": sample_author,
            "requestedAt": valid_timestamp,
            "justification": "test",
            "approvals": [
                {"user": "approver", "decision": "approve", "at": valid_timestamp}
            ],
            "requiredApprovers": ["approver"],
            "state": "approved"
        }
        request = StatusRequest.from_dict(data)
        assert len(request.approvals) == 1
        assert isinstance(request.approvals[0], Approval)

    def test_roundtrip_serialization(self, valid_req_id, sample_author):
        """
        REQ-tv-d00010-AO: from_dict(to_dict()) SHALL preserve all data.
        """
        from trace_view.review.models import StatusRequest
        original = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready"
        )
        data = original.to_dict()
        restored = StatusRequest.from_dict(data)
        assert restored.requestId == original.requestId
        assert restored.reqId == original.reqId
        assert restored.state == original.state


# =============================================================================
# ReviewSession Tests
# =============================================================================

class TestReviewSessionFactory:
    """Tests for ReviewSession.create factory method."""

    def test_create_generates_session_id(self, sample_author):
        """
        REQ-tv-d00010-AP: ReviewSession.create SHALL generate sessionId.
        """
        from trace_view.review.models import ReviewSession
        session = ReviewSession.create(user=sample_author, name="Sprint 23")
        assert session.sessionId is not None
        uuid.UUID(session.sessionId)

    def test_create_sets_user(self, sample_author):
        """
        REQ-tv-d00010-AP: ReviewSession.create SHALL set user.
        """
        from trace_view.review.models import ReviewSession
        session = ReviewSession.create(user=sample_author, name="Sprint 23")
        assert session.user == sample_author

    def test_create_sets_name(self, sample_author):
        """
        REQ-tv-d00010-AP: ReviewSession.create SHALL set name.
        """
        from trace_view.review.models import ReviewSession
        session = ReviewSession.create(user=sample_author, name="Sprint 23")
        assert session.name == "Sprint 23"

    def test_create_optional_description(self, sample_author):
        """
        REQ-tv-d00010-AP: ReviewSession.create SHALL support optional description.
        """
        from trace_view.review.models import ReviewSession
        session = ReviewSession.create(
            user=sample_author, name="Sprint 23", description="Review all PRD changes"
        )
        assert session.description == "Review all PRD changes"


class TestReviewSessionValidation:
    """Tests for ReviewSession validation."""

    def test_validate_requires_session_id(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AQ: ReviewSession validation SHALL require sessionId.
        """
        from trace_view.review.models import ReviewSession
        session = ReviewSession(
            sessionId="",
            user=sample_author,
            name="Test",
            createdAt=valid_timestamp
        )
        is_valid, errors = session.validate()
        assert is_valid is False
        assert any("sessionId" in e for e in errors)

    def test_validate_requires_user(self, valid_timestamp):
        """
        REQ-tv-d00010-AQ: ReviewSession validation SHALL require user.
        """
        from trace_view.review.models import ReviewSession
        session = ReviewSession(
            sessionId="test-id",
            user="",
            name="Test",
            createdAt=valid_timestamp
        )
        is_valid, errors = session.validate()
        assert is_valid is False
        assert any("user" in e.lower() for e in errors)

    def test_validate_requires_name(self, sample_author, valid_timestamp):
        """
        REQ-tv-d00010-AQ: ReviewSession validation SHALL require name.
        """
        from trace_view.review.models import ReviewSession
        session = ReviewSession(
            sessionId="test-id",
            user=sample_author,
            name="",
            createdAt=valid_timestamp
        )
        is_valid, errors = session.validate()
        assert is_valid is False
        assert any("name" in e.lower() for e in errors)


class TestReviewSessionSerialization:
    """Tests for ReviewSession to_dict/from_dict serialization."""

    def test_to_dict_excludes_none_description(self, sample_author):
        """
        REQ-tv-d00010-AR: ReviewSession.to_dict SHALL exclude None description.
        """
        from trace_view.review.models import ReviewSession
        session = ReviewSession.create(user=sample_author, name="Test")
        data = session.to_dict()
        assert "description" not in data

    def test_roundtrip_serialization(self, sample_author):
        """
        REQ-tv-d00010-AR: from_dict(to_dict()) SHALL preserve all data.
        """
        from trace_view.review.models import ReviewSession
        original = ReviewSession.create(
            user=sample_author, name="Test", description="desc"
        )
        data = original.to_dict()
        restored = ReviewSession.from_dict(data)
        assert restored.sessionId == original.sessionId
        assert restored.description == original.description


# =============================================================================
# ReviewConfig Tests
# =============================================================================

class TestReviewConfigFactory:
    """Tests for ReviewConfig.default factory method."""

    def test_default_has_approval_rules(self):
        """
        REQ-tv-d00010-AS: ReviewConfig.default SHALL include default approval rules.
        """
        from trace_view.review.models import ReviewConfig
        config = ReviewConfig.default()
        assert "Draft->Active" in config.approvalRules
        assert "Active->Deprecated" in config.approvalRules

    def test_default_push_on_comment(self):
        """
        REQ-tv-d00010-AS: ReviewConfig.default SHALL set pushOnComment True.
        """
        from trace_view.review.models import ReviewConfig
        config = ReviewConfig.default()
        assert config.pushOnComment is True

    def test_default_auto_fetch(self):
        """
        REQ-tv-d00010-AS: ReviewConfig.default SHALL set autoFetchOnOpen True.
        """
        from trace_view.review.models import ReviewConfig
        config = ReviewConfig.default()
        assert config.autoFetchOnOpen is True


class TestReviewConfigMethods:
    """Tests for ReviewConfig methods."""

    def test_get_required_approvers_known_transition(self):
        """
        REQ-tv-d00010-AT: get_required_approvers SHALL return approvers for
        known transition.
        """
        from trace_view.review.models import ReviewConfig
        config = ReviewConfig.default()
        approvers = config.get_required_approvers("Draft", "Active")
        assert "product_owner" in approvers
        assert "tech_lead" in approvers

    def test_get_required_approvers_unknown_transition(self):
        """
        REQ-tv-d00010-AT: get_required_approvers SHALL return default for
        unknown transition.
        """
        from trace_view.review.models import ReviewConfig
        config = ReviewConfig.default()
        approvers = config.get_required_approvers("Unknown", "Other")
        assert approvers == ["product_owner"]


class TestReviewConfigValidation:
    """Tests for ReviewConfig validation."""

    def test_validate_invalid_transition_format(self):
        """
        REQ-tv-d00010-AU: ReviewConfig validation SHALL reject invalid
        transition format.
        """
        from trace_view.review.models import ReviewConfig
        config = ReviewConfig(
            approvalRules={"InvalidFormat": ["user"]},
            pushOnComment=True,
            autoFetchOnOpen=True
        )
        is_valid, errors = config.validate()
        assert is_valid is False
        assert any("transition" in e.lower() or "format" in e.lower() for e in errors)

    def test_validate_invalid_status_in_transition(self):
        """
        REQ-tv-d00010-AU: ReviewConfig validation SHALL reject invalid statuses.
        """
        from trace_view.review.models import ReviewConfig
        config = ReviewConfig(
            approvalRules={"Invalid->Active": ["user"]},
            pushOnComment=True,
            autoFetchOnOpen=True
        )
        is_valid, errors = config.validate()
        assert is_valid is False
        assert any("status" in e.lower() for e in errors)

    def test_validate_empty_approvers(self):
        """
        REQ-tv-d00010-AU: ReviewConfig validation SHALL reject empty approvers.
        """
        from trace_view.review.models import ReviewConfig
        config = ReviewConfig(
            approvalRules={"Draft->Active": []},
            pushOnComment=True,
            autoFetchOnOpen=True
        )
        is_valid, errors = config.validate()
        assert is_valid is False
        assert any("approvers" in e.lower() or "empty" in e.lower() for e in errors)

    def test_validate_valid_config(self):
        """
        REQ-tv-d00010-AU: ReviewConfig validation SHALL pass for valid config.
        """
        from trace_view.review.models import ReviewConfig
        config = ReviewConfig.default()
        is_valid, errors = config.validate()
        assert is_valid is True


class TestReviewConfigSerialization:
    """Tests for ReviewConfig to_dict/from_dict serialization."""

    def test_to_dict_all_fields(self):
        """
        REQ-tv-d00010-AV: ReviewConfig.to_dict SHALL include all fields.
        """
        from trace_view.review.models import ReviewConfig
        config = ReviewConfig.default()
        data = config.to_dict()
        assert "approvalRules" in data
        assert "pushOnComment" in data
        assert "autoFetchOnOpen" in data

    def test_from_dict_uses_defaults(self):
        """
        REQ-tv-d00010-AV: ReviewConfig.from_dict SHALL use defaults for
        missing fields.
        """
        from trace_view.review.models import ReviewConfig
        config = ReviewConfig.from_dict({})
        assert config.pushOnComment is True
        assert config.autoFetchOnOpen is True
        assert len(config.approvalRules) > 0

    def test_roundtrip_serialization(self):
        """
        REQ-tv-d00010-AV: from_dict(to_dict()) SHALL preserve all data.
        """
        from trace_view.review.models import ReviewConfig
        original = ReviewConfig(
            approvalRules={"Draft->Active": ["custom"]},
            pushOnComment=False,
            autoFetchOnOpen=False
        )
        data = original.to_dict()
        restored = ReviewConfig.from_dict(data)
        assert restored.pushOnComment == original.pushOnComment
        assert restored.approvalRules == original.approvalRules


# =============================================================================
# Container Classes Tests
# =============================================================================

class TestThreadsFile:
    """Tests for ThreadsFile container class."""

    def test_to_dict_structure(self, valid_req_id):
        """
        REQ-tv-d00010-AW: ThreadsFile.to_dict SHALL include version, reqId, threads.
        """
        from trace_view.review.models import ThreadsFile
        container = ThreadsFile(reqId=valid_req_id, threads=[])
        data = container.to_dict()
        assert "version" in data
        assert "reqId" in data
        assert "threads" in data

    def test_default_version(self, valid_req_id):
        """
        REQ-tv-d00010-AW: ThreadsFile SHALL default to version "1.0".
        """
        from trace_view.review.models import ThreadsFile
        container = ThreadsFile(reqId=valid_req_id, threads=[])
        assert container.version == "1.0"

    def test_from_dict_creates_instance(self, valid_req_id):
        """
        REQ-tv-d00010-AW: ThreadsFile.from_dict SHALL create instance.
        """
        from trace_view.review.models import ThreadsFile
        data = {
            "version": "1.0",
            "reqId": valid_req_id,
            "threads": []
        }
        container = ThreadsFile.from_dict(data)
        assert container.reqId == valid_req_id
        assert container.threads == []

    def test_from_dict_deserializes_threads(
        self, valid_req_id, sample_author, valid_hash, valid_timestamp
    ):
        """
        REQ-tv-d00010-AW: ThreadsFile.from_dict SHALL deserialize threads.
        """
        from trace_view.review.models import ThreadsFile, Thread
        data = {
            "version": "1.0",
            "reqId": valid_req_id,
            "threads": [{
                "threadId": "test-id",
                "reqId": valid_req_id,
                "createdBy": sample_author,
                "createdAt": valid_timestamp,
                "position": {"type": "general", "hashWhenCreated": valid_hash},
                "resolved": False,
                "comments": []
            }]
        }
        container = ThreadsFile.from_dict(data)
        assert len(container.threads) == 1
        assert isinstance(container.threads[0], Thread)


class TestStatusFile:
    """Tests for StatusFile container class."""

    def test_to_dict_structure(self, valid_req_id):
        """
        REQ-tv-d00010-AX: StatusFile.to_dict SHALL include version, reqId, requests.
        """
        from trace_view.review.models import StatusFile
        container = StatusFile(reqId=valid_req_id, requests=[])
        data = container.to_dict()
        assert "version" in data
        assert "reqId" in data
        assert "requests" in data

    def test_default_version(self, valid_req_id):
        """
        REQ-tv-d00010-AX: StatusFile SHALL default to version "1.0".
        """
        from trace_view.review.models import StatusFile
        container = StatusFile(reqId=valid_req_id, requests=[])
        assert container.version == "1.0"

    def test_from_dict_deserializes_requests(
        self, valid_req_id, sample_author, valid_timestamp
    ):
        """
        REQ-tv-d00010-AX: StatusFile.from_dict SHALL deserialize requests.
        """
        from trace_view.review.models import StatusFile, StatusRequest
        data = {
            "version": "1.0",
            "reqId": valid_req_id,
            "requests": [{
                "requestId": "test-id",
                "reqId": valid_req_id,
                "type": "status_change",
                "fromStatus": "Draft",
                "toStatus": "Active",
                "requestedBy": sample_author,
                "requestedAt": valid_timestamp,
                "justification": "test",
                "approvals": [],
                "requiredApprovers": ["user"],
                "state": "pending"
            }]
        }
        container = StatusFile.from_dict(data)
        assert len(container.requests) == 1
        assert isinstance(container.requests[0], StatusRequest)


# =============================================================================
# Constants Tests
# =============================================================================

class TestConstants:
    """Tests for module-level constants."""

    def test_valid_req_statuses(self):
        """
        REQ-tv-d00010-AY: VALID_REQ_STATUSES SHALL contain Draft, Active, Deprecated.
        """
        from trace_view.review.models import VALID_REQ_STATUSES
        assert "Draft" in VALID_REQ_STATUSES
        assert "Active" in VALID_REQ_STATUSES
        assert "Deprecated" in VALID_REQ_STATUSES

    def test_default_approval_rules(self):
        """
        REQ-tv-d00010-AZ: DEFAULT_APPROVAL_RULES SHALL define standard transitions.
        """
        from trace_view.review.models import DEFAULT_APPROVAL_RULES
        assert "Draft->Active" in DEFAULT_APPROVAL_RULES
        assert "Active->Deprecated" in DEFAULT_APPROVAL_RULES
        assert "Draft->Deprecated" in DEFAULT_APPROVAL_RULES
