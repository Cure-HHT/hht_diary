#!/usr/bin/env python3
"""
Tests for review_storage.py - Storage Operations Module

TDD tests written before implementation.
"""

import json
import pytest
import tempfile
from pathlib import Path
from typing import Dict, Any

from tools.spec_review.review_data import (
    ReviewConfig,
    ReviewSession,
    ReviewFlag,
    Thread,
    Comment,
    ThreadsFile,
    StatusFile,
    StatusRequest,
    Approval,
    CommentPosition,
)
from tools.spec_review.review_storage import (
    # Helper functions
    _atomic_write_json,
    _read_json,
    # Config operations
    load_config,
    save_config,
    # Session operations
    create_session,
    load_session,
    list_sessions,
    delete_session,
    # Review flag operations
    load_review_flag,
    save_review_flag,
    # Thread operations
    load_threads,
    save_threads,
    add_thread,
    add_comment_to_thread,
    resolve_thread,
    unresolve_thread,
    # Status request operations
    load_status_requests,
    save_status_requests,
    create_status_request,
    add_approval,
    mark_request_applied,
    # Merge operations
    merge_threads,
    merge_status_files,
    merge_review_flags,
)


@pytest.fixture
def temp_repo():
    """Create a temporary directory as mock repo root"""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def sample_position():
    """Create a sample CommentPosition"""
    return CommentPosition.create_general("abc12345")


@pytest.fixture
def sample_thread(sample_position):
    """Create a sample Thread"""
    return Thread.create("d00001", "alice", sample_position, "Initial comment")


@pytest.fixture
def sample_session():
    """Create a sample ReviewSession"""
    return ReviewSession.create("alice", "Test Session", "A test review session")


@pytest.fixture
def sample_flag():
    """Create a sample ReviewFlag"""
    return ReviewFlag.create("alice", "Needs review", ["team"])


@pytest.fixture
def sample_status_request():
    """Create a sample StatusRequest"""
    return StatusRequest.create(
        "d00001", "Draft", "Active", "alice", "Ready for activation",
        required_approvers=["bob"]
    )


# =============================================================================
# Tests for Helper Functions
# =============================================================================

class TestAtomicWriteJson:
    """Test atomic write helper"""

    def test_creates_parent_directories(self, temp_repo):
        path = temp_repo / "deep" / "nested" / "file.json"
        data = {"key": "value"}
        _atomic_write_json(path, data)
        assert path.exists()
        assert json.loads(path.read_text()) == data

    def test_writes_valid_json(self, temp_repo):
        path = temp_repo / "test.json"
        data = {"number": 42, "list": [1, 2, 3], "nested": {"a": "b"}}
        _atomic_write_json(path, data)
        loaded = json.loads(path.read_text())
        assert loaded == data

    def test_overwrites_existing_file(self, temp_repo):
        path = temp_repo / "test.json"
        _atomic_write_json(path, {"old": "data"})
        _atomic_write_json(path, {"new": "data"})
        loaded = json.loads(path.read_text())
        assert loaded == {"new": "data"}

    def test_pretty_prints_json(self, temp_repo):
        path = temp_repo / "test.json"
        data = {"key": "value"}
        _atomic_write_json(path, data)
        content = path.read_text()
        assert "  " in content  # Has indentation


class TestReadJson:
    """Test JSON read helper"""

    def test_reads_valid_json(self, temp_repo):
        path = temp_repo / "test.json"
        path.write_text('{"key": "value"}')
        result = _read_json(path)
        assert result == {"key": "value"}

    def test_raises_on_missing_file(self, temp_repo):
        path = temp_repo / "nonexistent.json"
        with pytest.raises(FileNotFoundError):
            _read_json(path)

    def test_raises_on_invalid_json(self, temp_repo):
        path = temp_repo / "invalid.json"
        path.write_text("not valid json")
        with pytest.raises(json.JSONDecodeError):
            _read_json(path)


# =============================================================================
# Tests for Config Operations
# =============================================================================

class TestConfigOperations:
    """Test config load/save operations"""

    def test_load_missing_returns_default(self, temp_repo):
        config = load_config(temp_repo)
        assert config.pushOnComment is True
        assert config.autoFetchOnOpen is True
        assert "Draft->Active" in config.approvalRules

    def test_save_and_load_roundtrip(self, temp_repo):
        config = ReviewConfig(
            approvalRules={"Draft->Active": ["manager"]},
            pushOnComment=False,
            autoFetchOnOpen=True
        )
        save_config(temp_repo, config)
        loaded = load_config(temp_repo)
        assert loaded.pushOnComment is False
        assert loaded.approvalRules["Draft->Active"] == ["manager"]

    def test_save_creates_directory(self, temp_repo):
        config = ReviewConfig.default()
        save_config(temp_repo, config)
        config_path = temp_repo / ".reviews" / "config.json"
        assert config_path.exists()


# =============================================================================
# Tests for Session Operations
# =============================================================================

class TestSessionOperations:
    """Test session CRUD operations"""

    def test_create_and_load_session(self, temp_repo, sample_session):
        create_session(temp_repo, sample_session)
        loaded = load_session(temp_repo, sample_session.sessionId)
        assert loaded is not None
        assert loaded.sessionId == sample_session.sessionId
        assert loaded.name == sample_session.name

    def test_load_missing_session_returns_none(self, temp_repo):
        result = load_session(temp_repo, "nonexistent-id")
        assert result is None

    def test_list_sessions_empty(self, temp_repo):
        sessions = list_sessions(temp_repo)
        assert sessions == []

    def test_list_sessions_sorted_by_date(self, temp_repo):
        # Create sessions with different times
        session1 = ReviewSession.create("alice", "First")
        session2 = ReviewSession.create("bob", "Second")
        session3 = ReviewSession.create("charlie", "Third")

        create_session(temp_repo, session1)
        create_session(temp_repo, session2)
        create_session(temp_repo, session3)

        sessions = list_sessions(temp_repo)
        assert len(sessions) == 3
        # Newest first
        assert sessions[0].name == "Third"

    def test_delete_existing_session(self, temp_repo, sample_session):
        create_session(temp_repo, sample_session)
        result = delete_session(temp_repo, sample_session.sessionId)
        assert result is True
        assert load_session(temp_repo, sample_session.sessionId) is None

    def test_delete_nonexistent_session(self, temp_repo):
        result = delete_session(temp_repo, "nonexistent-id")
        assert result is False


# =============================================================================
# Tests for Review Flag Operations
# =============================================================================

class TestReviewFlagOperations:
    """Test review flag load/save operations"""

    def test_load_missing_returns_cleared(self, temp_repo):
        flag = load_review_flag(temp_repo, "d00001")
        assert flag.flaggedForReview is False

    def test_save_and_load_flagged(self, temp_repo, sample_flag):
        save_review_flag(temp_repo, "d00001", sample_flag)
        loaded = load_review_flag(temp_repo, "d00001")
        assert loaded.flaggedForReview is True
        assert loaded.flaggedBy == "alice"
        assert loaded.reason == "Needs review"

    def test_normalizes_req_id(self, temp_repo, sample_flag):
        # Save with uppercase, load with lowercase prefix
        save_review_flag(temp_repo, "REQ-D00001", sample_flag)
        loaded = load_review_flag(temp_repo, "d00001")
        assert loaded.flaggedForReview is True


# =============================================================================
# Tests for Thread Operations
# =============================================================================

class TestThreadOperations:
    """Test thread CRUD operations"""

    def test_load_missing_returns_empty(self, temp_repo):
        threads_file = load_threads(temp_repo, "d00001")
        assert threads_file.reqId == "d00001"
        assert threads_file.threads == []

    def test_save_and_load_threads(self, temp_repo, sample_thread):
        threads_file = ThreadsFile(reqId="d00001", threads=[sample_thread])
        save_threads(temp_repo, "d00001", threads_file)
        loaded = load_threads(temp_repo, "d00001")
        assert len(loaded.threads) == 1
        assert loaded.threads[0].threadId == sample_thread.threadId

    def test_add_thread(self, temp_repo, sample_thread):
        result = add_thread(temp_repo, "d00001", sample_thread)
        assert result.threadId == sample_thread.threadId
        loaded = load_threads(temp_repo, "d00001")
        assert len(loaded.threads) == 1

    def test_add_comment_to_thread(self, temp_repo, sample_thread):
        add_thread(temp_repo, "d00001", sample_thread)
        comment = add_comment_to_thread(
            temp_repo, "d00001", sample_thread.threadId,
            "bob", "Reply comment"
        )
        assert comment.author == "bob"
        assert comment.body == "Reply comment"

        loaded = load_threads(temp_repo, "d00001")
        assert len(loaded.threads[0].comments) == 2

    def test_add_comment_to_missing_thread_raises(self, temp_repo):
        with pytest.raises(ValueError, match="Thread not found"):
            add_comment_to_thread(
                temp_repo, "d00001", "nonexistent-thread",
                "bob", "Comment"
            )

    def test_resolve_thread(self, temp_repo, sample_thread):
        add_thread(temp_repo, "d00001", sample_thread)
        result = resolve_thread(
            temp_repo, "d00001", sample_thread.threadId, "charlie"
        )
        assert result is True

        loaded = load_threads(temp_repo, "d00001")
        assert loaded.threads[0].resolved is True
        assert loaded.threads[0].resolvedBy == "charlie"

    def test_resolve_missing_thread(self, temp_repo):
        result = resolve_thread(temp_repo, "d00001", "nonexistent", "alice")
        assert result is False

    def test_unresolve_thread(self, temp_repo, sample_thread):
        add_thread(temp_repo, "d00001", sample_thread)
        resolve_thread(temp_repo, "d00001", sample_thread.threadId, "alice")
        result = unresolve_thread(temp_repo, "d00001", sample_thread.threadId)
        assert result is True

        loaded = load_threads(temp_repo, "d00001")
        assert loaded.threads[0].resolved is False

    def test_unresolve_missing_thread(self, temp_repo):
        result = unresolve_thread(temp_repo, "d00001", "nonexistent")
        assert result is False


# =============================================================================
# Tests for Status Request Operations
# =============================================================================

class TestStatusRequestOperations:
    """Test status request CRUD operations"""

    def test_load_missing_returns_empty(self, temp_repo):
        status_file = load_status_requests(temp_repo, "d00001")
        assert status_file.reqId == "d00001"
        assert status_file.requests == []

    def test_create_status_request(self, temp_repo, sample_status_request):
        result = create_status_request(temp_repo, "d00001", sample_status_request)
        assert result.requestId == sample_status_request.requestId

        loaded = load_status_requests(temp_repo, "d00001")
        assert len(loaded.requests) == 1

    def test_add_approval(self, temp_repo, sample_status_request):
        create_status_request(temp_repo, "d00001", sample_status_request)
        approval = add_approval(
            temp_repo, "d00001", sample_status_request.requestId,
            "bob", "approve", "Looks good"
        )
        assert approval.user == "bob"
        assert approval.decision == "approve"

        loaded = load_status_requests(temp_repo, "d00001")
        assert len(loaded.requests[0].approvals) == 1

    def test_add_approval_missing_request_raises(self, temp_repo):
        with pytest.raises(ValueError, match="Status request not found"):
            add_approval(
                temp_repo, "d00001", "nonexistent",
                "bob", "approve"
            )

    def test_mark_request_applied(self, temp_repo, sample_status_request):
        create_status_request(temp_repo, "d00001", sample_status_request)
        add_approval(
            temp_repo, "d00001", sample_status_request.requestId,
            "bob", "approve"
        )
        result = mark_request_applied(
            temp_repo, "d00001", sample_status_request.requestId
        )
        assert result is True

        loaded = load_status_requests(temp_repo, "d00001")
        assert loaded.requests[0].state == "applied"

    def test_mark_unapproved_request_raises(self, temp_repo, sample_status_request):
        create_status_request(temp_repo, "d00001", sample_status_request)
        with pytest.raises(ValueError):
            mark_request_applied(
                temp_repo, "d00001", sample_status_request.requestId
            )

    def test_mark_missing_request_returns_false(self, temp_repo):
        result = mark_request_applied(temp_repo, "d00001", "nonexistent")
        assert result is False


# =============================================================================
# Tests for Merge Operations
# =============================================================================

class TestMergeThreads:
    """Test thread merging logic"""

    def test_merge_unique_threads(self, sample_position):
        thread1 = Thread.create("d00001", "alice", sample_position, "First")
        thread2 = Thread.create("d00001", "bob", sample_position, "Second")

        local = ThreadsFile(reqId="d00001", threads=[thread1])
        remote = ThreadsFile(reqId="d00001", threads=[thread2])

        merged = merge_threads(local, remote)
        assert len(merged.threads) == 2

    def test_merge_same_thread_different_comments(self, sample_position):
        thread = Thread.create("d00001", "alice", sample_position, "Original")
        thread_id = thread.threadId

        # Create local version with additional comment
        local_thread = Thread(
            threadId=thread_id,
            reqId="d00001",
            createdBy="alice",
            createdAt=thread.createdAt,
            position=sample_position,
            comments=[
                thread.comments[0],
                Comment.create("alice", "Local comment")
            ]
        )

        # Create remote version with different additional comment
        remote_thread = Thread(
            threadId=thread_id,
            reqId="d00001",
            createdBy="alice",
            createdAt=thread.createdAt,
            position=sample_position,
            comments=[
                thread.comments[0],
                Comment.create("bob", "Remote comment")
            ]
        )

        local = ThreadsFile(reqId="d00001", threads=[local_thread])
        remote = ThreadsFile(reqId="d00001", threads=[remote_thread])

        merged = merge_threads(local, remote)
        assert len(merged.threads) == 1
        # Should have 3 comments: original + local + remote
        assert len(merged.threads[0].comments) == 3

    def test_merge_resolve_state_conflict(self, sample_position):
        thread = Thread.create("d00001", "alice", sample_position, "Thread")
        thread_id = thread.threadId

        # Local is not resolved
        local_thread = Thread(
            threadId=thread_id,
            reqId="d00001",
            createdBy="alice",
            createdAt=thread.createdAt,
            position=sample_position,
            resolved=False,
            comments=thread.comments
        )

        # Remote is resolved
        remote_thread = Thread(
            threadId=thread_id,
            reqId="d00001",
            createdBy="alice",
            createdAt=thread.createdAt,
            position=sample_position,
            resolved=True,
            resolvedBy="bob",
            resolvedAt="2025-01-15T12:00:00Z",
            comments=thread.comments
        )

        local = ThreadsFile(reqId="d00001", threads=[local_thread])
        remote = ThreadsFile(reqId="d00001", threads=[remote_thread])

        merged = merge_threads(local, remote)
        # Remote resolved, local not - should be resolved
        assert merged.threads[0].resolved is True
        assert merged.threads[0].resolvedBy == "bob"


class TestMergeStatusFiles:
    """Test status file merging logic"""

    def test_merge_unique_requests(self):
        request1 = StatusRequest.create(
            "d00001", "Draft", "Active", "alice", "First request",
            required_approvers=["bob"]
        )
        request2 = StatusRequest.create(
            "d00001", "Active", "Deprecated", "charlie", "Second request",
            required_approvers=["bob"]
        )

        local = StatusFile(reqId="d00001", requests=[request1])
        remote = StatusFile(reqId="d00001", requests=[request2])

        merged = merge_status_files(local, remote)
        assert len(merged.requests) == 2

    def test_merge_same_request_different_approvals(self):
        request = StatusRequest.create(
            "d00001", "Draft", "Active", "alice", "Request",
            required_approvers=["bob", "charlie"]
        )
        request_id = request.requestId

        # Local has bob's approval
        local_request = StatusRequest(
            requestId=request_id,
            reqId="d00001",
            type="status_change",
            fromStatus="Draft",
            toStatus="Active",
            requestedBy="alice",
            requestedAt=request.requestedAt,
            justification="Request",
            approvals=[Approval.create("bob", "approve")],
            requiredApprovers=["bob", "charlie"],
            state="pending"
        )

        # Remote has charlie's approval
        remote_request = StatusRequest(
            requestId=request_id,
            reqId="d00001",
            type="status_change",
            fromStatus="Draft",
            toStatus="Active",
            requestedBy="alice",
            requestedAt=request.requestedAt,
            justification="Request",
            approvals=[Approval.create("charlie", "approve")],
            requiredApprovers=["bob", "charlie"],
            state="pending"
        )

        local = StatusFile(reqId="d00001", requests=[local_request])
        remote = StatusFile(reqId="d00001", requests=[remote_request])

        merged = merge_status_files(local, remote)
        assert len(merged.requests) == 1
        # Should have both approvals and be approved
        assert len(merged.requests[0].approvals) == 2
        assert merged.requests[0].state == "approved"


class TestMergeReviewFlags:
    """Test review flag merging logic"""

    def test_merge_neither_flagged(self):
        local = ReviewFlag.cleared()
        remote = ReviewFlag.cleared()
        merged = merge_review_flags(local, remote)
        assert merged.flaggedForReview is False

    def test_merge_only_local_flagged(self):
        local = ReviewFlag.create("alice", "Local reason", ["team"])
        remote = ReviewFlag.cleared()
        merged = merge_review_flags(local, remote)
        assert merged.flaggedForReview is True
        assert merged.flaggedBy == "alice"

    def test_merge_only_remote_flagged(self):
        local = ReviewFlag.cleared()
        remote = ReviewFlag.create("bob", "Remote reason", ["team"])
        merged = merge_review_flags(local, remote)
        assert merged.flaggedForReview is True
        assert merged.flaggedBy == "bob"

    def test_merge_both_flagged_takes_newer(self):
        local = ReviewFlag(
            flaggedForReview=True,
            flaggedBy="alice",
            flaggedAt="2025-01-15T10:00:00Z",
            reason="Local reason",
            scope=["team-a"]
        )
        remote = ReviewFlag(
            flaggedForReview=True,
            flaggedBy="bob",
            flaggedAt="2025-01-15T12:00:00Z",  # Newer
            reason="Remote reason",
            scope=["team-b"]
        )
        merged = merge_review_flags(local, remote)
        assert merged.flaggedBy == "bob"  # Newer wins
        assert merged.reason == "Remote reason"
        # Scopes should be merged
        assert "team-a" in merged.scope
        assert "team-b" in merged.scope


# =============================================================================
# Integration Tests
# =============================================================================

class TestIntegration:
    """Integration tests for storage operations"""

    def test_full_review_workflow(self, temp_repo, sample_position):
        # 1. Create a session
        session = ReviewSession.create("alice", "Q1 Review")
        create_session(temp_repo, session)

        # 2. Flag a requirement
        flag = ReviewFlag.create("alice", "Needs clarification", ["product"])
        save_review_flag(temp_repo, "d00001", flag)

        # 3. Create a thread with comments
        thread = Thread.create("d00001", "alice", sample_position, "First question")
        add_thread(temp_repo, "d00001", thread)
        add_comment_to_thread(
            temp_repo, "d00001", thread.threadId,
            "bob", "Here's the answer"
        )

        # 4. Resolve the thread
        resolve_thread(temp_repo, "d00001", thread.threadId, "alice")

        # 5. Create status request
        request = StatusRequest.create(
            "d00001", "Draft", "Active", "alice", "Ready",
            required_approvers=["bob"]
        )
        create_status_request(temp_repo, "d00001", request)

        # 6. Approve and apply
        add_approval(temp_repo, "d00001", request.requestId, "bob", "approve")
        mark_request_applied(temp_repo, "d00001", request.requestId)

        # Verify final state
        loaded_threads = load_threads(temp_repo, "d00001")
        assert len(loaded_threads.threads) == 1
        assert loaded_threads.threads[0].resolved is True
        assert len(loaded_threads.threads[0].comments) == 2

        loaded_status = load_status_requests(temp_repo, "d00001")
        assert len(loaded_status.requests) == 1
        assert loaded_status.requests[0].state == "applied"

        loaded_flag = load_review_flag(temp_repo, "d00001")
        assert loaded_flag.flaggedForReview is True

        loaded_sessions = list_sessions(temp_repo)
        assert len(loaded_sessions) == 1
