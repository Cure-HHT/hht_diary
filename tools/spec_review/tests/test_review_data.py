#!/usr/bin/env python3
"""
Tests for review_data.py - Data Layer Foundation

TDD tests written before implementation.
"""

import json
import pytest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch
import uuid

# Import module under test (will fail until implemented)
from tools.spec_review.review_data import (
    # Enums and Constants
    PositionType,
    RequestState,
    ApprovalDecision,
    VALID_REQ_STATUSES,
    DEFAULT_APPROVAL_RULES,
    # Utility functions
    generate_uuid,
    now_iso,
    parse_iso_datetime,
    validate_req_id,
    validate_hash,
    # Data classes
    CommentPosition,
    Comment,
    Thread,
    ReviewFlag,
    Approval,
    StatusRequest,
    ReviewSession,
    ReviewConfig,
    # Container classes
    ThreadsFile,
    StatusFile,
    # Path helpers
    get_reviews_dir,
    get_config_path,
    get_sessions_dir,
    get_session_path,
    get_reqs_dir,
    get_req_dir,
    get_threads_path,
    get_status_path,
    get_review_flag_path,
    normalize_req_id,
)


# =============================================================================
# Tests for Enums and Constants
# =============================================================================

class TestEnums:
    """Test enum definitions"""

    def test_position_type_values(self):
        assert PositionType.LINE.value == "line"
        assert PositionType.BLOCK.value == "block"
        assert PositionType.WORD.value == "word"
        assert PositionType.GENERAL.value == "general"

    def test_request_state_values(self):
        assert RequestState.PENDING.value == "pending"
        assert RequestState.APPROVED.value == "approved"
        assert RequestState.REJECTED.value == "rejected"
        assert RequestState.APPLIED.value == "applied"

    def test_approval_decision_values(self):
        assert ApprovalDecision.APPROVE.value == "approve"
        assert ApprovalDecision.REJECT.value == "reject"

    def test_valid_req_statuses(self):
        assert VALID_REQ_STATUSES == {"Draft", "Active", "Deprecated"}

    def test_default_approval_rules(self):
        assert "Draft->Active" in DEFAULT_APPROVAL_RULES
        assert "Active->Deprecated" in DEFAULT_APPROVAL_RULES
        assert isinstance(DEFAULT_APPROVAL_RULES["Draft->Active"], list)


# =============================================================================
# Tests for Utility Functions
# =============================================================================

class TestUtilityFunctions:
    """Test utility functions"""

    def test_generate_uuid_format(self):
        result = generate_uuid()
        # Should be valid UUID string
        parsed = uuid.UUID(result)
        assert str(parsed) == result

    def test_generate_uuid_unique(self):
        results = [generate_uuid() for _ in range(100)]
        assert len(set(results)) == 100

    def test_now_iso_format(self):
        result = now_iso()
        # Should be parseable
        dt = parse_iso_datetime(result)
        assert isinstance(dt, datetime)
        # Should have timezone
        assert dt.tzinfo is not None

    def test_parse_iso_datetime_with_z(self):
        result = parse_iso_datetime("2025-01-15T10:30:00Z")
        assert result.year == 2025
        assert result.month == 1
        assert result.day == 15
        assert result.hour == 10
        assert result.minute == 30

    def test_parse_iso_datetime_with_offset(self):
        result = parse_iso_datetime("2025-01-15T10:30:00+00:00")
        assert result.year == 2025

    def test_validate_req_id_core_valid(self):
        assert validate_req_id("d00001") is True
        assert validate_req_id("p00042") is True
        assert validate_req_id("o00003") is True

    def test_validate_req_id_sponsor_valid(self):
        assert validate_req_id("CAL-d00001") is True
        assert validate_req_id("SUN-p00042") is True
        assert validate_req_id("ABCD-o00003") is True

    def test_validate_req_id_invalid(self):
        assert validate_req_id("x00001") is False  # Invalid prefix
        assert validate_req_id("d0001") is False   # Wrong number of digits
        assert validate_req_id("d000001") is False # Too many digits
        assert validate_req_id("REQ-d00001") is False  # Has REQ- prefix
        assert validate_req_id("") is False

    def test_validate_hash_valid(self):
        assert validate_hash("abc12345") is True
        assert validate_hash("DEADBEEF") is True
        assert validate_hash("00000000") is True

    def test_validate_hash_invalid(self):
        assert validate_hash("abc1234") is False   # Too short
        assert validate_hash("abc123456") is False # Too long
        assert validate_hash("ghijklmn") is False  # Invalid hex chars
        assert validate_hash("") is False


# =============================================================================
# Tests for CommentPosition
# =============================================================================

class TestCommentPosition:
    """Test CommentPosition class"""

    def test_create_line_position(self):
        pos = CommentPosition.create_line("abc12345", 15, "some context")
        assert pos.type == "line"
        assert pos.hashWhenCreated == "abc12345"
        assert pos.lineNumber == 15
        assert pos.fallbackContext == "some context"
        assert pos.lineRange is None
        assert pos.keyword is None

    def test_create_block_position(self):
        pos = CommentPosition.create_block("abc12345", 10, 20, "block context")
        assert pos.type == "block"
        assert pos.lineRange == (10, 20)
        assert pos.lineNumber is None

    def test_create_word_position(self):
        pos = CommentPosition.create_word("abc12345", "SHALL", 2, "word context")
        assert pos.type == "word"
        assert pos.keyword == "SHALL"
        assert pos.keywordOccurrence == 2

    def test_create_general_position(self):
        pos = CommentPosition.create_general("abc12345")
        assert pos.type == "general"
        assert pos.lineNumber is None
        assert pos.lineRange is None
        assert pos.keyword is None

    def test_validate_line_success(self):
        pos = CommentPosition.create_line("abc12345", 15)
        valid, errors = pos.validate()
        assert valid is True
        assert errors == []

    def test_validate_line_missing_line_number(self):
        pos = CommentPosition(type="line", hashWhenCreated="abc12345")
        valid, errors = pos.validate()
        assert valid is False
        assert any("lineNumber" in e for e in errors)

    def test_validate_block_missing_range(self):
        pos = CommentPosition(type="block", hashWhenCreated="abc12345")
        valid, errors = pos.validate()
        assert valid is False
        assert any("lineRange" in e for e in errors)

    def test_validate_word_missing_keyword(self):
        pos = CommentPosition(type="word", hashWhenCreated="abc12345")
        valid, errors = pos.validate()
        assert valid is False
        assert any("keyword" in e for e in errors)

    def test_validate_invalid_hash(self):
        pos = CommentPosition(type="general", hashWhenCreated="invalid")
        valid, errors = pos.validate()
        assert valid is False
        assert any("hash" in e.lower() for e in errors)

    def test_to_dict_line(self):
        pos = CommentPosition.create_line("abc12345", 15, "context")
        d = pos.to_dict()
        assert d["type"] == "line"
        assert d["hashWhenCreated"] == "abc12345"
        assert d["lineNumber"] == 15
        assert d["fallbackContext"] == "context"
        assert "lineRange" not in d  # Optional fields omitted when None

    def test_to_dict_block_converts_tuple_to_list(self):
        pos = CommentPosition.create_block("abc12345", 10, 20)
        d = pos.to_dict()
        assert d["lineRange"] == [10, 20]  # List, not tuple

    def test_from_dict_line(self):
        data = {
            "type": "line",
            "hashWhenCreated": "abc12345",
            "lineNumber": 15,
            "fallbackContext": "context"
        }
        pos = CommentPosition.from_dict(data)
        assert pos.type == "line"
        assert pos.lineNumber == 15

    def test_from_dict_block_converts_list_to_tuple(self):
        data = {
            "type": "block",
            "hashWhenCreated": "abc12345",
            "lineRange": [10, 20]
        }
        pos = CommentPosition.from_dict(data)
        assert pos.lineRange == (10, 20)  # Tuple, not list

    def test_roundtrip_serialization(self):
        original = CommentPosition.create_word("abc12345", "SHALL", 2, "context text")
        data = original.to_dict()
        restored = CommentPosition.from_dict(data)
        assert restored.type == original.type
        assert restored.keyword == original.keyword
        assert restored.keywordOccurrence == original.keywordOccurrence


# =============================================================================
# Tests for Comment
# =============================================================================

class TestComment:
    """Test Comment class"""

    def test_create_auto_generates_id_and_timestamp(self):
        comment = Comment.create("alice", "This is a comment")
        assert comment.id is not None
        assert len(comment.id) == 36  # UUID format
        assert comment.timestamp is not None
        assert comment.author == "alice"
        assert comment.body == "This is a comment"

    def test_validate_success(self):
        comment = Comment.create("alice", "Valid comment")
        valid, errors = comment.validate()
        assert valid is True
        assert errors == []

    def test_validate_empty_body(self):
        comment = Comment(id="123", author="alice", timestamp=now_iso(), body="")
        valid, errors = comment.validate()
        assert valid is False
        assert any("body" in e.lower() for e in errors)

    def test_validate_whitespace_only_body(self):
        comment = Comment(id="123", author="alice", timestamp=now_iso(), body="   ")
        valid, errors = comment.validate()
        assert valid is False

    def test_validate_missing_author(self):
        comment = Comment(id="123", author="", timestamp=now_iso(), body="text")
        valid, errors = comment.validate()
        assert valid is False
        assert any("author" in e.lower() for e in errors)

    def test_to_dict(self):
        comment = Comment.create("alice", "Test comment")
        d = comment.to_dict()
        assert "id" in d
        assert d["author"] == "alice"
        assert d["body"] == "Test comment"
        assert "timestamp" in d

    def test_from_dict(self):
        data = {
            "id": "test-id",
            "author": "bob",
            "timestamp": "2025-01-15T10:00:00Z",
            "body": "Restored comment"
        }
        comment = Comment.from_dict(data)
        assert comment.id == "test-id"
        assert comment.author == "bob"
        assert comment.body == "Restored comment"

    def test_roundtrip_serialization(self):
        original = Comment.create("charlie", "Original message")
        data = original.to_dict()
        restored = Comment.from_dict(data)
        assert restored.id == original.id
        assert restored.author == original.author
        assert restored.body == original.body


# =============================================================================
# Tests for Thread
# =============================================================================

class TestThread:
    """Test Thread class"""

    def test_create_without_initial_comment(self):
        pos = CommentPosition.create_general("abc12345")
        thread = Thread.create("d00001", "alice", pos)
        assert thread.threadId is not None
        assert thread.reqId == "d00001"
        assert thread.createdBy == "alice"
        assert thread.resolved is False
        assert len(thread.comments) == 0

    def test_create_with_initial_comment(self):
        pos = CommentPosition.create_line("abc12345", 10)
        thread = Thread.create("d00001", "alice", pos, "First comment")
        assert len(thread.comments) == 1
        assert thread.comments[0].body == "First comment"
        assert thread.comments[0].author == "alice"

    def test_add_comment(self):
        pos = CommentPosition.create_general("abc12345")
        thread = Thread.create("d00001", "alice", pos)
        comment = thread.add_comment("bob", "Reply comment")
        assert len(thread.comments) == 1
        assert comment.author == "bob"
        assert comment.body == "Reply comment"

    def test_resolve(self):
        pos = CommentPosition.create_general("abc12345")
        thread = Thread.create("d00001", "alice", pos)
        thread.resolve("bob")
        assert thread.resolved is True
        assert thread.resolvedBy == "bob"
        assert thread.resolvedAt is not None

    def test_unresolve(self):
        pos = CommentPosition.create_general("abc12345")
        thread = Thread.create("d00001", "alice", pos)
        thread.resolve("bob")
        thread.unresolve()
        assert thread.resolved is False
        assert thread.resolvedBy is None
        assert thread.resolvedAt is None

    def test_validate_success(self):
        pos = CommentPosition.create_general("abc12345")
        thread = Thread.create("d00001", "alice", pos, "Comment")
        valid, errors = thread.validate()
        assert valid is True
        assert errors == []

    def test_validate_invalid_req_id(self):
        pos = CommentPosition.create_general("abc12345")
        thread = Thread(
            threadId="123",
            reqId="invalid",
            createdBy="alice",
            createdAt=now_iso(),
            position=pos
        )
        valid, errors = thread.validate()
        assert valid is False
        assert any("requirement" in e.lower() or "req" in e.lower() for e in errors)

    def test_validate_resolved_without_resolver(self):
        pos = CommentPosition.create_general("abc12345")
        thread = Thread(
            threadId="123",
            reqId="d00001",
            createdBy="alice",
            createdAt=now_iso(),
            position=pos,
            resolved=True,
            resolvedBy=None
        )
        valid, errors = thread.validate()
        assert valid is False
        assert any("resolvedBy" in e for e in errors)

    def test_to_dict(self):
        pos = CommentPosition.create_line("abc12345", 15)
        thread = Thread.create("d00001", "alice", pos, "Comment text")
        d = thread.to_dict()
        assert d["reqId"] == "d00001"
        assert d["createdBy"] == "alice"
        assert d["position"]["type"] == "line"
        assert len(d["comments"]) == 1

    def test_from_dict(self):
        data = {
            "threadId": "thread-123",
            "reqId": "p00001",
            "createdBy": "bob",
            "createdAt": "2025-01-15T10:00:00Z",
            "position": {
                "type": "general",
                "hashWhenCreated": "abc12345"
            },
            "resolved": False,
            "comments": [
                {
                    "id": "comment-1",
                    "author": "bob",
                    "timestamp": "2025-01-15T10:00:00Z",
                    "body": "Test comment"
                }
            ]
        }
        thread = Thread.from_dict(data)
        assert thread.threadId == "thread-123"
        assert thread.reqId == "p00001"
        assert len(thread.comments) == 1

    def test_roundtrip_serialization(self):
        pos = CommentPosition.create_word("abc12345", "SHALL", 1)
        original = Thread.create("o00005", "charlie", pos, "Initial")
        original.add_comment("dave", "Reply")
        original.resolve("eve")
        data = original.to_dict()
        restored = Thread.from_dict(data)
        assert restored.threadId == original.threadId
        assert len(restored.comments) == 2
        assert restored.resolved is True


# =============================================================================
# Tests for ReviewFlag
# =============================================================================

class TestReviewFlag:
    """Test ReviewFlag class"""

    def test_create(self):
        flag = ReviewFlag.create("alice", "Needs review", ["prd-team", "tech-lead"])
        assert flag.flaggedForReview is True
        assert flag.flaggedBy == "alice"
        assert flag.reason == "Needs review"
        assert flag.scope == ["prd-team", "tech-lead"]
        assert flag.flaggedAt is not None

    def test_cleared_factory(self):
        flag = ReviewFlag.cleared()
        assert flag.flaggedForReview is False
        assert flag.flaggedBy == ""
        assert flag.scope == []

    def test_clear(self):
        flag = ReviewFlag.create("alice", "Reason", ["team"])
        flag.clear()
        assert flag.flaggedForReview is False
        assert flag.reason == ""

    def test_validate_flagged_success(self):
        flag = ReviewFlag.create("alice", "Reason", ["team"])
        valid, errors = flag.validate()
        assert valid is True

    def test_validate_flagged_missing_reason(self):
        flag = ReviewFlag(
            flaggedForReview=True,
            flaggedBy="alice",
            flaggedAt=now_iso(),
            reason="",
            scope=["team"]
        )
        valid, errors = flag.validate()
        assert valid is False
        assert any("reason" in e.lower() for e in errors)

    def test_validate_flagged_empty_scope(self):
        flag = ReviewFlag(
            flaggedForReview=True,
            flaggedBy="alice",
            flaggedAt=now_iso(),
            reason="Reason",
            scope=[]
        )
        valid, errors = flag.validate()
        assert valid is False
        assert any("scope" in e.lower() for e in errors)

    def test_validate_cleared_always_valid(self):
        flag = ReviewFlag.cleared()
        valid, errors = flag.validate()
        assert valid is True

    def test_to_dict(self):
        flag = ReviewFlag.create("alice", "Reason", ["team"])
        d = flag.to_dict()
        assert d["flaggedForReview"] is True
        assert d["flaggedBy"] == "alice"

    def test_from_dict(self):
        data = {
            "flaggedForReview": True,
            "flaggedBy": "bob",
            "flaggedAt": "2025-01-15T10:00:00Z",
            "reason": "Review needed",
            "scope": ["all"]
        }
        flag = ReviewFlag.from_dict(data)
        assert flag.flaggedBy == "bob"
        assert flag.scope == ["all"]


# =============================================================================
# Tests for Approval
# =============================================================================

class TestApproval:
    """Test Approval class"""

    def test_create_approve(self):
        approval = Approval.create("alice", "approve", "Looks good")
        assert approval.user == "alice"
        assert approval.decision == "approve"
        assert approval.comment == "Looks good"
        assert approval.at is not None

    def test_create_reject(self):
        approval = Approval.create("bob", "reject", "Needs work")
        assert approval.decision == "reject"

    def test_create_without_comment(self):
        approval = Approval.create("charlie", "approve")
        assert approval.comment is None

    def test_validate_success(self):
        approval = Approval.create("alice", "approve")
        valid, errors = approval.validate()
        assert valid is True

    def test_validate_invalid_decision(self):
        approval = Approval(user="alice", decision="maybe", at=now_iso())
        valid, errors = approval.validate()
        assert valid is False
        assert any("decision" in e.lower() for e in errors)

    def test_to_dict_with_comment(self):
        approval = Approval.create("alice", "approve", "Great")
        d = approval.to_dict()
        assert d["comment"] == "Great"

    def test_to_dict_without_comment(self):
        approval = Approval.create("alice", "approve")
        d = approval.to_dict()
        assert "comment" not in d  # Omitted when None


# =============================================================================
# Tests for StatusRequest
# =============================================================================

class TestStatusRequest:
    """Test StatusRequest class"""

    def test_create_uses_default_approvers(self):
        request = StatusRequest.create(
            "d00001", "Draft", "Active", "alice", "Ready for activation"
        )
        assert request.requestId is not None
        assert request.fromStatus == "Draft"
        assert request.toStatus == "Active"
        assert request.state == "pending"
        assert request.requiredApprovers == ["product_owner", "tech_lead"]

    def test_create_with_custom_approvers(self):
        request = StatusRequest.create(
            "d00001", "Draft", "Active", "alice", "Ready",
            required_approvers=["manager"]
        )
        assert request.requiredApprovers == ["manager"]

    def test_add_approval(self):
        request = StatusRequest.create("d00001", "Draft", "Active", "alice", "Ready")
        approval = request.add_approval("product_owner", "approve", "LGTM")
        assert len(request.approvals) == 1
        assert approval.user == "product_owner"

    def test_state_updates_to_approved_when_all_approve(self):
        request = StatusRequest.create(
            "d00001", "Draft", "Active", "alice", "Ready",
            required_approvers=["bob", "charlie"]
        )
        request.add_approval("bob", "approve")
        assert request.state == "pending"  # Still pending
        request.add_approval("charlie", "approve")
        assert request.state == "approved"  # All approved

    def test_state_updates_to_rejected_on_any_rejection(self):
        request = StatusRequest.create(
            "d00001", "Draft", "Active", "alice", "Ready",
            required_approvers=["bob", "charlie"]
        )
        request.add_approval("bob", "approve")
        request.add_approval("charlie", "reject")
        assert request.state == "rejected"

    def test_mark_applied(self):
        request = StatusRequest.create(
            "d00001", "Draft", "Active", "alice", "Ready",
            required_approvers=["bob"]
        )
        request.add_approval("bob", "approve")
        request.mark_applied()
        assert request.state == "applied"

    def test_mark_applied_fails_if_not_approved(self):
        request = StatusRequest.create(
            "d00001", "Draft", "Active", "alice", "Ready"
        )
        with pytest.raises(ValueError):
            request.mark_applied()

    def test_validate_success(self):
        request = StatusRequest.create("d00001", "Draft", "Active", "alice", "Ready")
        valid, errors = request.validate()
        assert valid is True

    def test_validate_invalid_from_status(self):
        request = StatusRequest(
            requestId="123",
            reqId="d00001",
            type="status_change",
            fromStatus="Invalid",
            toStatus="Active",
            requestedBy="alice",
            requestedAt=now_iso(),
            justification="Reason",
            approvals=[],
            requiredApprovers=["bob"],
            state="pending"
        )
        valid, errors = request.validate()
        assert valid is False
        assert any("fromStatus" in e for e in errors)

    def test_validate_same_status(self):
        request = StatusRequest(
            requestId="123",
            reqId="d00001",
            type="status_change",
            fromStatus="Active",
            toStatus="Active",
            requestedBy="alice",
            requestedAt=now_iso(),
            justification="Reason",
            approvals=[],
            requiredApprovers=["bob"],
            state="pending"
        )
        valid, errors = request.validate()
        assert valid is False
        assert any("different" in e.lower() for e in errors)

    def test_to_dict(self):
        request = StatusRequest.create("d00001", "Draft", "Active", "alice", "Ready")
        request.add_approval("bob", "approve", "OK")
        d = request.to_dict()
        assert d["fromStatus"] == "Draft"
        assert d["toStatus"] == "Active"
        assert len(d["approvals"]) == 1

    def test_from_dict(self):
        data = {
            "requestId": "req-123",
            "reqId": "p00001",
            "type": "status_change",
            "fromStatus": "Draft",
            "toStatus": "Active",
            "requestedBy": "alice",
            "requestedAt": "2025-01-15T10:00:00Z",
            "justification": "Ready",
            "approvals": [],
            "requiredApprovers": ["bob"],
            "state": "pending"
        }
        request = StatusRequest.from_dict(data)
        assert request.requestId == "req-123"
        assert request.state == "pending"


# =============================================================================
# Tests for ReviewSession
# =============================================================================

class TestReviewSession:
    """Test ReviewSession class"""

    def test_create(self):
        session = ReviewSession.create("alice", "Sprint 23 Review", "Q1 review session")
        assert session.sessionId is not None
        assert session.user == "alice"
        assert session.name == "Sprint 23 Review"
        assert session.description == "Q1 review session"

    def test_create_without_description(self):
        session = ReviewSession.create("bob", "Quick Review")
        assert session.description is None

    def test_validate_success(self):
        session = ReviewSession.create("alice", "Test Session")
        valid, errors = session.validate()
        assert valid is True

    def test_validate_missing_name(self):
        session = ReviewSession(
            sessionId="123",
            user="alice",
            name="",
            createdAt=now_iso()
        )
        valid, errors = session.validate()
        assert valid is False
        assert any("name" in e.lower() for e in errors)

    def test_to_dict_with_description(self):
        session = ReviewSession.create("alice", "Test", "Description")
        d = session.to_dict()
        assert d["description"] == "Description"

    def test_to_dict_without_description(self):
        session = ReviewSession.create("alice", "Test")
        d = session.to_dict()
        assert "description" not in d  # Omitted when None


# =============================================================================
# Tests for ReviewConfig
# =============================================================================

class TestReviewConfig:
    """Test ReviewConfig class"""

    def test_default_config(self):
        config = ReviewConfig.default()
        assert config.pushOnComment is True
        assert config.autoFetchOnOpen is True
        assert "Draft->Active" in config.approvalRules

    def test_get_required_approvers(self):
        config = ReviewConfig.default()
        approvers = config.get_required_approvers("Draft", "Active")
        assert "product_owner" in approvers
        assert "tech_lead" in approvers

    def test_get_required_approvers_unknown_transition(self):
        config = ReviewConfig.default()
        approvers = config.get_required_approvers("Unknown", "Other")
        assert approvers == ["product_owner"]  # Default fallback

    def test_validate_success(self):
        config = ReviewConfig.default()
        valid, errors = config.validate()
        assert valid is True

    def test_validate_invalid_transition_format(self):
        config = ReviewConfig(
            approvalRules={"Draft-Active": ["bob"]},  # Missing > in arrow
            pushOnComment=True,
            autoFetchOnOpen=True
        )
        valid, errors = config.validate()
        assert valid is False

    def test_validate_invalid_status_in_transition(self):
        config = ReviewConfig(
            approvalRules={"Invalid->Active": ["bob"]},
            pushOnComment=True,
            autoFetchOnOpen=True
        )
        valid, errors = config.validate()
        assert valid is False

    def test_to_dict(self):
        config = ReviewConfig.default()
        d = config.to_dict()
        assert "approvalRules" in d
        assert d["pushOnComment"] is True

    def test_from_dict(self):
        data = {
            "approvalRules": {"Draft->Active": ["manager"]},
            "pushOnComment": False,
            "autoFetchOnOpen": True
        }
        config = ReviewConfig.from_dict(data)
        assert config.pushOnComment is False
        assert config.approvalRules["Draft->Active"] == ["manager"]


# =============================================================================
# Tests for Container Classes
# =============================================================================

class TestThreadsFile:
    """Test ThreadsFile container class"""

    def test_to_dict(self):
        pos = CommentPosition.create_general("abc12345")
        thread = Thread.create("d00001", "alice", pos, "Comment")
        threads_file = ThreadsFile(reqId="d00001", threads=[thread])
        d = threads_file.to_dict()
        assert d["version"] == "1.0"
        assert d["reqId"] == "d00001"
        assert len(d["threads"]) == 1

    def test_from_dict(self):
        data = {
            "version": "1.0",
            "reqId": "p00001",
            "threads": []
        }
        threads_file = ThreadsFile.from_dict(data)
        assert threads_file.reqId == "p00001"
        assert threads_file.threads == []


class TestStatusFile:
    """Test StatusFile container class"""

    def test_to_dict(self):
        request = StatusRequest.create("d00001", "Draft", "Active", "alice", "Ready")
        status_file = StatusFile(reqId="d00001", requests=[request])
        d = status_file.to_dict()
        assert d["version"] == "1.0"
        assert len(d["requests"]) == 1

    def test_from_dict(self):
        data = {
            "version": "1.0",
            "reqId": "p00001",
            "requests": []
        }
        status_file = StatusFile.from_dict(data)
        assert status_file.reqId == "p00001"


# =============================================================================
# Tests for Path Helper Functions
# =============================================================================

class TestPathHelpers:
    """Test path helper functions"""

    def test_get_reviews_dir(self):
        repo = Path("/home/user/repo")
        assert get_reviews_dir(repo) == Path("/home/user/repo/.reviews")

    def test_get_config_path(self):
        repo = Path("/home/user/repo")
        assert get_config_path(repo) == Path("/home/user/repo/.reviews/config.json")

    def test_get_sessions_dir(self):
        repo = Path("/home/user/repo")
        assert get_sessions_dir(repo) == Path("/home/user/repo/.reviews/sessions")

    def test_get_session_path(self):
        repo = Path("/home/user/repo")
        result = get_session_path(repo, "abc123")
        assert result == Path("/home/user/repo/.reviews/sessions/abc123.json")

    def test_get_reqs_dir(self):
        repo = Path("/home/user/repo")
        assert get_reqs_dir(repo) == Path("/home/user/repo/.reviews/reqs")

    def test_get_req_dir(self):
        repo = Path("/home/user/repo")
        result = get_req_dir(repo, "D00001")  # Uppercase
        assert result == Path("/home/user/repo/.reviews/reqs/d00001")  # Lowercase

    def test_get_threads_path(self):
        repo = Path("/home/user/repo")
        result = get_threads_path(repo, "d00001")
        assert result == Path("/home/user/repo/.reviews/reqs/d00001/threads.json")

    def test_get_status_path(self):
        repo = Path("/home/user/repo")
        result = get_status_path(repo, "d00001")
        assert result == Path("/home/user/repo/.reviews/reqs/d00001/status.json")

    def test_get_review_flag_path(self):
        repo = Path("/home/user/repo")
        result = get_review_flag_path(repo, "d00001")
        assert result == Path("/home/user/repo/.reviews/reqs/d00001/review-flag.json")

    def test_normalize_req_id_removes_prefix(self):
        assert normalize_req_id("REQ-d00001") == "d00001"
        assert normalize_req_id("req-P00042") == "p00042"

    def test_normalize_req_id_lowercases(self):
        assert normalize_req_id("D00001") == "d00001"
        assert normalize_req_id("CAL-P00001") == "cal-p00001"

    def test_normalize_req_id_already_normalized(self):
        assert normalize_req_id("d00001") == "d00001"


# =============================================================================
# Integration Tests
# =============================================================================

class TestIntegration:
    """Integration tests for full workflows"""

    def test_full_review_workflow(self):
        """Test complete review workflow: flag, comment, resolve"""
        # 1. Create flag
        flag = ReviewFlag.create("alice", "Needs clarification", ["prd-team"])
        assert flag.flaggedForReview is True

        # 2. Create thread with comments
        pos = CommentPosition.create_line("abc12345", 15, "The system SHALL")
        thread = Thread.create("d00001", "alice", pos, "What does 'system' mean here?")
        thread.add_comment("bob", "It refers to the backend service")
        thread.add_comment("alice", "Thanks for clarifying!")

        # 3. Resolve thread
        thread.resolve("alice")

        # 4. Serialize and restore
        thread_data = thread.to_dict()
        json_str = json.dumps(thread_data, indent=2)
        restored_data = json.loads(json_str)
        restored_thread = Thread.from_dict(restored_data)

        assert restored_thread.resolved is True
        assert len(restored_thread.comments) == 3

    def test_full_status_change_workflow(self):
        """Test status change request with approvals"""
        # 1. Create request
        request = StatusRequest.create(
            "d00001", "Draft", "Active", "alice", "Requirement is complete",
            required_approvers=["bob", "charlie"]
        )
        assert request.state == "pending"

        # 2. First approval
        request.add_approval("bob", "approve", "Verified implementation")
        assert request.state == "pending"  # Still need charlie

        # 3. Second approval
        request.add_approval("charlie", "approve")
        assert request.state == "approved"

        # 4. Mark as applied
        request.mark_applied()
        assert request.state == "applied"

        # 5. Serialize and verify
        data = request.to_dict()
        assert len(data["approvals"]) == 2

    def test_threads_file_with_multiple_threads(self):
        """Test ThreadsFile with multiple threads"""
        pos1 = CommentPosition.create_line("abc12345", 10)
        pos2 = CommentPosition.create_word("abc12345", "SHALL", 1)

        thread1 = Thread.create("d00001", "alice", pos1, "Comment on line 10")
        thread2 = Thread.create("d00001", "bob", pos2, "Comment on SHALL")

        threads_file = ThreadsFile(reqId="d00001", threads=[thread1, thread2])

        # Serialize
        data = threads_file.to_dict()
        json_str = json.dumps(data)

        # Restore
        restored_data = json.loads(json_str)
        restored = ThreadsFile.from_dict(restored_data)

        assert len(restored.threads) == 2
        assert restored.threads[0].createdBy == "alice"
        assert restored.threads[1].position.keyword == "SHALL"
