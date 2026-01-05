"""
Tests for Review Storage Operations (REQ-tv-d00011).

TDD Red Phase: These tests are written BEFORE the implementation.
They will fail until storage.py is implemented.

Each test function documents which assertion it verifies in its docstring.
The Elspais reporter extracts these references for traceability.

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00011: Review storage operations for spec review system
"""

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any

import pytest


# =============================================================================
# Test Fixtures
# =============================================================================

@pytest.fixture
def repo_root(tmp_path):
    """Provide a temporary repository root directory."""
    return tmp_path


@pytest.fixture
def reviews_dir(repo_root):
    """Provide the .reviews directory path (may not exist yet)."""
    return repo_root / '.reviews'


@pytest.fixture
def valid_req_id():
    """Provide a valid requirement ID."""
    return "d00027"


@pytest.fixture
def valid_timestamp():
    """Provide a valid ISO 8601 timestamp."""
    return datetime.now(timezone.utc).isoformat()


@pytest.fixture
def sample_author():
    """Provide a sample author username."""
    return "test_user"


@pytest.fixture
def valid_hash():
    """Provide a valid 8-character hex hash."""
    return "a1b2c3d4"


@pytest.fixture
def sample_config():
    """Provide a sample ReviewConfig instance."""
    from trace_view.review.models import ReviewConfig
    return ReviewConfig.default()


@pytest.fixture
def sample_session(sample_author):
    """Provide a sample ReviewSession instance."""
    from trace_view.review.models import ReviewSession
    return ReviewSession.create(
        user=sample_author,
        name="Test Session",
        description="A test review session"
    )


@pytest.fixture
def sample_review_flag(sample_author):
    """Provide a sample ReviewFlag instance."""
    from trace_view.review.models import ReviewFlag
    return ReviewFlag.create(
        user=sample_author,
        reason="Needs review",
        scope=["product_owner", "tech_lead"]
    )


@pytest.fixture
def sample_position(valid_hash):
    """Provide a sample CommentPosition instance."""
    from trace_view.review.models import CommentPosition
    return CommentPosition.create_line(valid_hash, line_number=42, context="sample context")


@pytest.fixture
def sample_thread(valid_req_id, sample_author, sample_position):
    """Provide a sample Thread instance."""
    from trace_view.review.models import Thread
    return Thread.create(
        req_id=valid_req_id,
        creator=sample_author,
        position=sample_position,
        initial_comment="Initial comment on thread"
    )


@pytest.fixture
def sample_threads_file(valid_req_id, sample_thread):
    """Provide a sample ThreadsFile instance."""
    from trace_view.review.models import ThreadsFile
    return ThreadsFile(reqId=valid_req_id, threads=[sample_thread])


@pytest.fixture
def sample_status_request(valid_req_id, sample_author):
    """Provide a sample StatusRequest instance."""
    from trace_view.review.models import StatusRequest
    return StatusRequest.create(
        req_id=valid_req_id,
        from_status="Draft",
        to_status="Active",
        requested_by=sample_author,
        justification="Ready for review"
    )


@pytest.fixture
def sample_status_file(valid_req_id, sample_status_request):
    """Provide a sample StatusFile instance."""
    from trace_view.review.models import StatusFile
    return StatusFile(reqId=valid_req_id, requests=[sample_status_request])


# =============================================================================
# Helper Function Tests: _atomic_write_json
# =============================================================================

class TestAtomicWriteJson:
    """Tests for _atomic_write_json helper function."""

    def test_creates_parent_directories(self, tmp_path):
        """
        REQ-tv-d00011-A: _atomic_write_json SHALL create parent directories
        if they do not exist.
        """
        from trace_view.review.storage import _atomic_write_json

        deep_path = tmp_path / "a" / "b" / "c" / "test.json"
        data = {"key": "value"}

        _atomic_write_json(deep_path, data)

        assert deep_path.exists()
        assert deep_path.parent.exists()

    def test_writes_valid_json(self, tmp_path):
        """
        REQ-tv-d00011-A: _atomic_write_json SHALL write valid JSON data.
        """
        from trace_view.review.storage import _atomic_write_json

        file_path = tmp_path / "test.json"
        data = {"key": "value", "nested": {"a": 1}}

        _atomic_write_json(file_path, data)

        with open(file_path) as f:
            written_data = json.load(f)
        assert written_data == data

    def test_atomic_write_no_partial_files(self, tmp_path):
        """
        REQ-tv-d00011-A: _atomic_write_json SHALL use temp+rename pattern
        to ensure atomicity (no partial files on failure).
        """
        from trace_view.review.storage import _atomic_write_json

        file_path = tmp_path / "test.json"
        data = {"key": "value"}

        _atomic_write_json(file_path, data)

        # After write, no temp files should remain
        temp_files = list(tmp_path.glob(".tmp_*.json"))
        assert len(temp_files) == 0

    def test_overwrites_existing_file(self, tmp_path):
        """
        REQ-tv-d00011-A: _atomic_write_json SHALL overwrite existing files.
        """
        from trace_view.review.storage import _atomic_write_json

        file_path = tmp_path / "test.json"

        # Write initial data
        _atomic_write_json(file_path, {"initial": True})

        # Overwrite with new data
        _atomic_write_json(file_path, {"updated": True})

        with open(file_path) as f:
            data = json.load(f)
        assert data == {"updated": True}

    def test_preserves_original_on_serialization_error(self, tmp_path):
        """
        REQ-tv-d00011-A: _atomic_write_json SHALL preserve original file
        if serialization fails.
        """
        from trace_view.review.storage import _atomic_write_json

        file_path = tmp_path / "test.json"
        original_data = {"original": True}

        # Write initial data
        _atomic_write_json(file_path, original_data)

        # Try to write non-serializable data
        class NonSerializable:
            pass

        with pytest.raises((TypeError, ValueError)):
            _atomic_write_json(file_path, {"bad": NonSerializable()})

        # Original should be preserved
        with open(file_path) as f:
            data = json.load(f)
        assert data == original_data


# =============================================================================
# Helper Function Tests: _read_json
# =============================================================================

class TestReadJson:
    """Tests for _read_json helper function."""

    def test_reads_valid_json(self, tmp_path):
        """
        REQ-tv-d00011-B: _read_json SHALL read and parse valid JSON files.
        """
        from trace_view.review.storage import _read_json

        file_path = tmp_path / "test.json"
        data = {"key": "value"}
        file_path.write_text(json.dumps(data))

        result = _read_json(file_path)

        assert result == data

    def test_raises_file_not_found(self, tmp_path):
        """
        REQ-tv-d00011-B: _read_json SHALL raise FileNotFoundError for
        missing files.
        """
        from trace_view.review.storage import _read_json

        file_path = tmp_path / "nonexistent.json"

        with pytest.raises(FileNotFoundError):
            _read_json(file_path)

    def test_raises_json_decode_error(self, tmp_path):
        """
        REQ-tv-d00011-B: _read_json SHALL raise JSONDecodeError for
        invalid JSON.
        """
        from trace_view.review.storage import _read_json

        file_path = tmp_path / "invalid.json"
        file_path.write_text("not valid json {")

        with pytest.raises(json.JSONDecodeError):
            _read_json(file_path)


# =============================================================================
# Config Operations Tests
# =============================================================================

class TestLoadConfig:
    """Tests for load_config function."""

    def test_returns_default_if_not_exists(self, repo_root):
        """
        REQ-tv-d00011-C: load_config SHALL return default ReviewConfig
        if config file does not exist.
        """
        from trace_view.review.storage import load_config
        from trace_view.review.models import ReviewConfig

        config = load_config(repo_root)
        default_config = ReviewConfig.default()

        assert config.pushOnComment == default_config.pushOnComment
        assert config.autoFetchOnOpen == default_config.autoFetchOnOpen

    def test_loads_existing_config(self, repo_root, sample_config):
        """
        REQ-tv-d00011-C: load_config SHALL load existing config from file.
        """
        from trace_view.review.storage import load_config, save_config

        # Save a config first
        modified_config = sample_config
        modified_config.pushOnComment = False
        save_config(repo_root, modified_config)

        # Load and verify
        loaded = load_config(repo_root)

        assert loaded.pushOnComment is False


class TestSaveConfig:
    """Tests for save_config function."""

    def test_saves_config_to_correct_path(self, repo_root, sample_config):
        """
        REQ-tv-d00011-D: save_config SHALL write config to
        .reviews/config.json.
        """
        from trace_view.review.storage import save_config

        save_config(repo_root, sample_config)

        config_path = repo_root / '.reviews' / 'config.json'
        assert config_path.exists()

    def test_config_roundtrip(self, repo_root):
        """
        REQ-tv-d00011-D: save_config SHALL preserve all config fields.
        """
        from trace_view.review.storage import load_config, save_config
        from trace_view.review.models import ReviewConfig

        original = ReviewConfig(
            approvalRules={"Draft->Active": ["custom_approver"]},
            pushOnComment=False,
            autoFetchOnOpen=False
        )

        save_config(repo_root, original)
        loaded = load_config(repo_root)

        assert loaded.pushOnComment == original.pushOnComment
        assert loaded.autoFetchOnOpen == original.autoFetchOnOpen
        assert loaded.approvalRules == original.approvalRules


# =============================================================================
# Session Operations Tests
# =============================================================================

class TestCreateSession:
    """Tests for create_session function."""

    def test_creates_session_file(self, repo_root, sample_session):
        """
        REQ-tv-d00011-E: create_session SHALL create session file in
        .reviews/sessions/{sessionId}.json.
        """
        from trace_view.review.storage import create_session

        result = create_session(repo_root, sample_session)

        session_path = repo_root / '.reviews' / 'sessions' / f'{sample_session.sessionId}.json'
        assert session_path.exists()

    def test_returns_created_session(self, repo_root, sample_session):
        """
        REQ-tv-d00011-E: create_session SHALL return the created session.
        """
        from trace_view.review.storage import create_session

        result = create_session(repo_root, sample_session)

        assert result.sessionId == sample_session.sessionId
        assert result.name == sample_session.name


class TestLoadSession:
    """Tests for load_session function."""

    def test_returns_none_if_not_exists(self, repo_root):
        """
        REQ-tv-d00011-F: load_session SHALL return None if session
        does not exist.
        """
        from trace_view.review.storage import load_session

        result = load_session(repo_root, "nonexistent-session-id")

        assert result is None

    def test_loads_existing_session(self, repo_root, sample_session):
        """
        REQ-tv-d00011-F: load_session SHALL load and return existing session.
        """
        from trace_view.review.storage import create_session, load_session

        create_session(repo_root, sample_session)

        loaded = load_session(repo_root, sample_session.sessionId)

        assert loaded is not None
        assert loaded.sessionId == sample_session.sessionId
        assert loaded.name == sample_session.name


class TestListSessions:
    """Tests for list_sessions function."""

    def test_returns_empty_list_if_no_sessions(self, repo_root):
        """
        REQ-tv-d00011-G: list_sessions SHALL return empty list if no
        sessions exist.
        """
        from trace_view.review.storage import list_sessions

        result = list_sessions(repo_root)

        assert result == []

    def test_returns_all_sessions(self, repo_root, sample_author):
        """
        REQ-tv-d00011-G: list_sessions SHALL return all existing sessions.
        """
        from trace_view.review.storage import create_session, list_sessions
        from trace_view.review.models import ReviewSession

        session1 = ReviewSession.create(user=sample_author, name="Session 1")
        session2 = ReviewSession.create(user=sample_author, name="Session 2")

        create_session(repo_root, session1)
        create_session(repo_root, session2)

        result = list_sessions(repo_root)

        assert len(result) == 2

    def test_sorted_by_creation_date_newest_first(self, repo_root, sample_author):
        """
        REQ-tv-d00011-G: list_sessions SHALL return sessions sorted by
        creation date (newest first).
        """
        from trace_view.review.storage import create_session, list_sessions
        from trace_view.review.models import ReviewSession
        import time

        session1 = ReviewSession.create(user=sample_author, name="Older Session")
        time.sleep(0.01)  # Small delay to ensure different timestamps
        session2 = ReviewSession.create(user=sample_author, name="Newer Session")

        create_session(repo_root, session1)
        create_session(repo_root, session2)

        result = list_sessions(repo_root)

        assert result[0].name == "Newer Session"
        assert result[1].name == "Older Session"

    def test_skips_invalid_session_files(self, repo_root, sample_session):
        """
        REQ-tv-d00011-G: list_sessions SHALL skip invalid session files.
        """
        from trace_view.review.storage import create_session, list_sessions

        create_session(repo_root, sample_session)

        # Create an invalid session file
        sessions_dir = repo_root / '.reviews' / 'sessions'
        invalid_file = sessions_dir / 'invalid.json'
        invalid_file.write_text("not valid json {")

        result = list_sessions(repo_root)

        # Should only return the valid session
        assert len(result) == 1
        assert result[0].sessionId == sample_session.sessionId


class TestDeleteSession:
    """Tests for delete_session function."""

    def test_returns_false_if_not_exists(self, repo_root):
        """
        REQ-tv-d00011-H: delete_session SHALL return False if session
        does not exist.
        """
        from trace_view.review.storage import delete_session

        result = delete_session(repo_root, "nonexistent-id")

        assert result is False

    def test_deletes_existing_session(self, repo_root, sample_session):
        """
        REQ-tv-d00011-H: delete_session SHALL delete existing session
        and return True.
        """
        from trace_view.review.storage import create_session, delete_session, load_session

        create_session(repo_root, sample_session)

        result = delete_session(repo_root, sample_session.sessionId)

        assert result is True
        assert load_session(repo_root, sample_session.sessionId) is None


# =============================================================================
# Review Flag Operations Tests
# =============================================================================

class TestLoadReviewFlag:
    """Tests for load_review_flag function."""

    def test_returns_cleared_if_not_exists(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-I: load_review_flag SHALL return cleared ReviewFlag
        if file does not exist.
        """
        from trace_view.review.storage import load_review_flag

        flag = load_review_flag(repo_root, valid_req_id)

        assert flag.flaggedForReview is False

    def test_loads_existing_flag(self, repo_root, valid_req_id, sample_review_flag):
        """
        REQ-tv-d00011-I: load_review_flag SHALL load existing flag.
        """
        from trace_view.review.storage import load_review_flag, save_review_flag

        save_review_flag(repo_root, valid_req_id, sample_review_flag)

        loaded = load_review_flag(repo_root, valid_req_id)

        assert loaded.flaggedForReview is True
        assert loaded.reason == sample_review_flag.reason


class TestSaveReviewFlag:
    """Tests for save_review_flag function."""

    def test_saves_to_correct_path(self, repo_root, valid_req_id, sample_review_flag):
        """
        REQ-tv-d00011-J: save_review_flag SHALL save flag to
        .reviews/reqs/{req_id}/review-flag.json.
        """
        from trace_view.review.storage import save_review_flag

        save_review_flag(repo_root, valid_req_id, sample_review_flag)

        flag_path = repo_root / '.reviews' / 'reqs' / valid_req_id / 'review-flag.json'
        assert flag_path.exists()

    def test_flag_roundtrip(self, repo_root, valid_req_id, sample_review_flag):
        """
        REQ-tv-d00011-J: save_review_flag SHALL preserve all flag fields.
        """
        from trace_view.review.storage import load_review_flag, save_review_flag

        save_review_flag(repo_root, valid_req_id, sample_review_flag)
        loaded = load_review_flag(repo_root, valid_req_id)

        assert loaded.flaggedBy == sample_review_flag.flaggedBy
        assert loaded.reason == sample_review_flag.reason
        assert loaded.scope == sample_review_flag.scope


# =============================================================================
# Thread Operations Tests
# =============================================================================

class TestLoadThreads:
    """Tests for load_threads function."""

    def test_returns_empty_if_not_exists(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-K: load_threads SHALL return empty ThreadsFile
        if file does not exist.
        """
        from trace_view.review.storage import load_threads

        threads_file = load_threads(repo_root, valid_req_id)

        assert threads_file.threads == []
        assert threads_file.reqId == valid_req_id

    def test_loads_existing_threads(self, repo_root, valid_req_id, sample_threads_file):
        """
        REQ-tv-d00011-K: load_threads SHALL load existing threads file.
        """
        from trace_view.review.storage import load_threads, save_threads

        save_threads(repo_root, valid_req_id, sample_threads_file)

        loaded = load_threads(repo_root, valid_req_id)

        assert len(loaded.threads) == 1


class TestSaveThreads:
    """Tests for save_threads function."""

    def test_saves_to_correct_path(self, repo_root, valid_req_id, sample_threads_file):
        """
        REQ-tv-d00011-L: save_threads SHALL save to
        .reviews/reqs/{req_id}/threads.json.
        """
        from trace_view.review.storage import save_threads

        save_threads(repo_root, valid_req_id, sample_threads_file)

        threads_path = repo_root / '.reviews' / 'reqs' / valid_req_id / 'threads.json'
        assert threads_path.exists()


class TestAddThread:
    """Tests for add_thread function."""

    def test_adds_thread_to_existing_file(self, repo_root, valid_req_id, sample_thread):
        """
        REQ-tv-d00011-M: add_thread SHALL append thread to existing
        threads file.
        """
        from trace_view.review.storage import add_thread, load_threads
        from trace_view.review.models import Thread, CommentPosition

        # Add first thread
        add_thread(repo_root, valid_req_id, sample_thread)

        # Add second thread
        position = CommentPosition.create_general("b2c3d4e5")
        second_thread = Thread.create(
            req_id=valid_req_id,
            creator="another_user",
            position=position,
            initial_comment="Second thread"
        )
        add_thread(repo_root, valid_req_id, second_thread)

        loaded = load_threads(repo_root, valid_req_id)

        assert len(loaded.threads) == 2

    def test_returns_added_thread(self, repo_root, valid_req_id, sample_thread):
        """
        REQ-tv-d00011-M: add_thread SHALL return the added thread.
        """
        from trace_view.review.storage import add_thread

        result = add_thread(repo_root, valid_req_id, sample_thread)

        assert result.threadId == sample_thread.threadId


class TestAddCommentToThread:
    """Tests for add_comment_to_thread function."""

    def test_adds_comment_to_existing_thread(self, repo_root, valid_req_id, sample_thread):
        """
        REQ-tv-d00011-N: add_comment_to_thread SHALL add comment to
        existing thread.
        """
        from trace_view.review.storage import add_thread, add_comment_to_thread, load_threads

        add_thread(repo_root, valid_req_id, sample_thread)
        initial_comments = len(sample_thread.comments)

        add_comment_to_thread(
            repo_root, valid_req_id, sample_thread.threadId,
            author="another_user",
            body="Reply comment"
        )

        loaded = load_threads(repo_root, valid_req_id)
        thread = loaded.threads[0]

        assert len(thread.comments) == initial_comments + 1

    def test_raises_if_thread_not_found(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-N: add_comment_to_thread SHALL raise ValueError
        if thread not found.
        """
        from trace_view.review.storage import add_comment_to_thread

        with pytest.raises(ValueError, match="Thread not found"):
            add_comment_to_thread(
                repo_root, valid_req_id, "nonexistent-thread-id",
                author="user",
                body="Comment"
            )

    def test_returns_created_comment(self, repo_root, valid_req_id, sample_thread):
        """
        REQ-tv-d00011-N: add_comment_to_thread SHALL return the created
        Comment.
        """
        from trace_view.review.storage import add_thread, add_comment_to_thread
        from trace_view.review.models import Comment

        add_thread(repo_root, valid_req_id, sample_thread)

        result = add_comment_to_thread(
            repo_root, valid_req_id, sample_thread.threadId,
            author="commenter",
            body="New comment"
        )

        assert isinstance(result, Comment)
        assert result.author == "commenter"
        assert result.body == "New comment"


class TestResolveThread:
    """Tests for resolve_thread function."""

    def test_marks_thread_resolved(self, repo_root, valid_req_id, sample_thread):
        """
        REQ-tv-d00011-O: resolve_thread SHALL mark thread as resolved.
        """
        from trace_view.review.storage import add_thread, resolve_thread, load_threads

        add_thread(repo_root, valid_req_id, sample_thread)

        resolve_thread(repo_root, valid_req_id, sample_thread.threadId, "resolver_user")

        loaded = load_threads(repo_root, valid_req_id)
        thread = loaded.threads[0]

        assert thread.resolved is True
        assert thread.resolvedBy == "resolver_user"

    def test_returns_true_on_success(self, repo_root, valid_req_id, sample_thread):
        """
        REQ-tv-d00011-O: resolve_thread SHALL return True on success.
        """
        from trace_view.review.storage import add_thread, resolve_thread

        add_thread(repo_root, valid_req_id, sample_thread)

        result = resolve_thread(repo_root, valid_req_id, sample_thread.threadId, "user")

        assert result is True

    def test_returns_false_if_not_found(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-O: resolve_thread SHALL return False if thread
        not found.
        """
        from trace_view.review.storage import resolve_thread

        result = resolve_thread(repo_root, valid_req_id, "nonexistent-id", "user")

        assert result is False


class TestUnresolveThread:
    """Tests for unresolve_thread function."""

    def test_marks_thread_unresolved(self, repo_root, valid_req_id, sample_thread):
        """
        REQ-tv-d00011-P: unresolve_thread SHALL mark thread as unresolved.
        """
        from trace_view.review.storage import (
            add_thread, resolve_thread, unresolve_thread, load_threads
        )

        add_thread(repo_root, valid_req_id, sample_thread)
        resolve_thread(repo_root, valid_req_id, sample_thread.threadId, "user")

        unresolve_thread(repo_root, valid_req_id, sample_thread.threadId)

        loaded = load_threads(repo_root, valid_req_id)
        thread = loaded.threads[0]

        assert thread.resolved is False
        assert thread.resolvedBy is None

    def test_returns_false_if_not_found(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-P: unresolve_thread SHALL return False if thread
        not found.
        """
        from trace_view.review.storage import unresolve_thread

        result = unresolve_thread(repo_root, valid_req_id, "nonexistent-id")

        assert result is False


# =============================================================================
# Status Request Operations Tests
# =============================================================================

class TestLoadStatusRequests:
    """Tests for load_status_requests function."""

    def test_returns_empty_if_not_exists(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-Q: load_status_requests SHALL return empty StatusFile
        if file does not exist.
        """
        from trace_view.review.storage import load_status_requests

        status_file = load_status_requests(repo_root, valid_req_id)

        assert status_file.requests == []
        assert status_file.reqId == valid_req_id

    def test_loads_existing_requests(self, repo_root, valid_req_id, sample_status_file):
        """
        REQ-tv-d00011-Q: load_status_requests SHALL load existing status file.
        """
        from trace_view.review.storage import load_status_requests, save_status_requests

        save_status_requests(repo_root, valid_req_id, sample_status_file)

        loaded = load_status_requests(repo_root, valid_req_id)

        assert len(loaded.requests) == 1


class TestSaveStatusRequests:
    """Tests for save_status_requests function."""

    def test_saves_to_correct_path(self, repo_root, valid_req_id, sample_status_file):
        """
        REQ-tv-d00011-R: save_status_requests SHALL save to
        .reviews/reqs/{req_id}/status.json.
        """
        from trace_view.review.storage import save_status_requests

        save_status_requests(repo_root, valid_req_id, sample_status_file)

        status_path = repo_root / '.reviews' / 'reqs' / valid_req_id / 'status.json'
        assert status_path.exists()


class TestCreateStatusRequest:
    """Tests for create_status_request function."""

    def test_appends_request_to_file(self, repo_root, valid_req_id, sample_status_request):
        """
        REQ-tv-d00011-S: create_status_request SHALL append request to
        existing status file.
        """
        from trace_view.review.storage import create_status_request, load_status_requests
        from trace_view.review.models import StatusRequest

        # Create first request
        create_status_request(repo_root, valid_req_id, sample_status_request)

        # Create second request
        second_request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Active",
            to_status="Deprecated",
            requested_by="another_user",
            justification="No longer needed"
        )
        create_status_request(repo_root, valid_req_id, second_request)

        loaded = load_status_requests(repo_root, valid_req_id)

        assert len(loaded.requests) == 2

    def test_returns_created_request(self, repo_root, valid_req_id, sample_status_request):
        """
        REQ-tv-d00011-S: create_status_request SHALL return the created request.
        """
        from trace_view.review.storage import create_status_request

        result = create_status_request(repo_root, valid_req_id, sample_status_request)

        assert result.requestId == sample_status_request.requestId


class TestAddApproval:
    """Tests for add_approval function."""

    def test_adds_approval_to_request(self, repo_root, valid_req_id, sample_status_request):
        """
        REQ-tv-d00011-T: add_approval SHALL add approval to existing request.
        """
        from trace_view.review.storage import (
            create_status_request, add_approval, load_status_requests
        )

        create_status_request(repo_root, valid_req_id, sample_status_request)

        add_approval(
            repo_root, valid_req_id, sample_status_request.requestId,
            user="product_owner",
            decision="approve",
            comment="Looks good"
        )

        loaded = load_status_requests(repo_root, valid_req_id)
        request = loaded.requests[0]

        assert len(request.approvals) == 1
        assert request.approvals[0].user == "product_owner"

    def test_raises_if_request_not_found(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-T: add_approval SHALL raise ValueError if request
        not found.
        """
        from trace_view.review.storage import add_approval

        with pytest.raises(ValueError, match="Status request not found"):
            add_approval(
                repo_root, valid_req_id, "nonexistent-request-id",
                user="user",
                decision="approve"
            )

    def test_returns_created_approval(self, repo_root, valid_req_id, sample_status_request):
        """
        REQ-tv-d00011-T: add_approval SHALL return the created Approval.
        """
        from trace_view.review.storage import create_status_request, add_approval
        from trace_view.review.models import Approval

        create_status_request(repo_root, valid_req_id, sample_status_request)

        result = add_approval(
            repo_root, valid_req_id, sample_status_request.requestId,
            user="approver",
            decision="approve"
        )

        assert isinstance(result, Approval)
        assert result.user == "approver"


class TestMarkRequestApplied:
    """Tests for mark_request_applied function."""

    def test_marks_approved_request_applied(self, repo_root, valid_req_id, sample_author):
        """
        REQ-tv-d00011-U: mark_request_applied SHALL mark approved request
        as applied.
        """
        from trace_view.review.storage import (
            create_status_request, add_approval, mark_request_applied,
            load_status_requests
        )
        from trace_view.review.models import StatusRequest, RequestState

        request = StatusRequest.create(
            req_id=valid_req_id,
            from_status="Draft",
            to_status="Active",
            requested_by=sample_author,
            justification="Ready",
            required_approvers=["approver"]
        )
        create_status_request(repo_root, valid_req_id, request)

        # Approve the request
        add_approval(repo_root, valid_req_id, request.requestId, "approver", "approve")

        # Mark as applied
        mark_request_applied(repo_root, valid_req_id, request.requestId)

        loaded = load_status_requests(repo_root, valid_req_id)

        assert loaded.requests[0].state == RequestState.APPLIED.value

    def test_returns_false_if_not_found(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-U: mark_request_applied SHALL return False if
        request not found.
        """
        from trace_view.review.storage import mark_request_applied

        result = mark_request_applied(repo_root, valid_req_id, "nonexistent-id")

        assert result is False

    def test_raises_if_not_approved(self, repo_root, valid_req_id, sample_status_request):
        """
        REQ-tv-d00011-U: mark_request_applied SHALL raise ValueError if
        request is not in approved state.
        """
        from trace_view.review.storage import create_status_request, mark_request_applied

        create_status_request(repo_root, valid_req_id, sample_status_request)

        with pytest.raises(ValueError, match="approved"):
            mark_request_applied(repo_root, valid_req_id, sample_status_request.requestId)


# =============================================================================
# Merge Operations Tests
# =============================================================================

class TestMergeThreads:
    """Tests for merge_threads function."""

    def test_combines_unique_threads(self, valid_req_id, sample_author, valid_hash):
        """
        REQ-tv-d00011-V: merge_threads SHALL combine unique threads from
        both local and remote.
        """
        from trace_view.review.storage import merge_threads
        from trace_view.review.models import ThreadsFile, Thread, CommentPosition

        pos1 = CommentPosition.create_line(valid_hash, line_number=10)
        pos2 = CommentPosition.create_line(valid_hash, line_number=20)

        thread1 = Thread.create(valid_req_id, sample_author, pos1, "Thread 1")
        thread2 = Thread.create(valid_req_id, sample_author, pos2, "Thread 2")

        local = ThreadsFile(reqId=valid_req_id, threads=[thread1])
        remote = ThreadsFile(reqId=valid_req_id, threads=[thread2])

        merged = merge_threads(local, remote)

        assert len(merged.threads) == 2

    def test_merges_comments_in_matching_threads(self, valid_req_id, sample_author, valid_hash):
        """
        REQ-tv-d00011-V: merge_threads SHALL merge comments from matching
        threads (by threadId).
        """
        from trace_view.review.storage import merge_threads
        from trace_view.review.models import ThreadsFile, Thread, CommentPosition, Comment
        import copy

        pos = CommentPosition.create_line(valid_hash, line_number=10)
        thread = Thread.create(valid_req_id, sample_author, pos, "Initial comment")
        thread_id = thread.threadId

        # Create local copy with additional comment
        local_thread = copy.deepcopy(thread)
        local_thread.add_comment("local_user", "Local comment")

        # Create remote copy with different additional comment
        remote_thread = copy.deepcopy(thread)
        remote_thread.add_comment("remote_user", "Remote comment")

        local = ThreadsFile(reqId=valid_req_id, threads=[local_thread])
        remote = ThreadsFile(reqId=valid_req_id, threads=[remote_thread])

        merged = merge_threads(local, remote)

        # Should have all unique comments
        assert len(merged.threads) == 1
        merged_thread = merged.threads[0]
        assert len(merged_thread.comments) >= 2  # At least initial + one from each

    def test_preserves_resolved_state(self, valid_req_id, sample_author, valid_hash):
        """
        REQ-tv-d00011-V: merge_threads SHALL preserve resolved state
        (if either is resolved, keep resolved).
        """
        from trace_view.review.storage import merge_threads
        from trace_view.review.models import ThreadsFile, Thread, CommentPosition
        import copy

        pos = CommentPosition.create_line(valid_hash, line_number=10)
        thread = Thread.create(valid_req_id, sample_author, pos, "Comment")

        local_thread = copy.deepcopy(thread)
        remote_thread = copy.deepcopy(thread)
        remote_thread.resolve("resolver")

        local = ThreadsFile(reqId=valid_req_id, threads=[local_thread])
        remote = ThreadsFile(reqId=valid_req_id, threads=[remote_thread])

        merged = merge_threads(local, remote)

        assert merged.threads[0].resolved is True


class TestMergeStatusFiles:
    """Tests for merge_status_files function."""

    def test_combines_unique_requests(self, valid_req_id, sample_author):
        """
        REQ-tv-d00011-W: merge_status_files SHALL combine unique requests
        from both local and remote.
        """
        from trace_view.review.storage import merge_status_files
        from trace_view.review.models import StatusFile, StatusRequest

        request1 = StatusRequest.create(
            valid_req_id, "Draft", "Active", sample_author, "Request 1"
        )
        request2 = StatusRequest.create(
            valid_req_id, "Active", "Deprecated", sample_author, "Request 2"
        )

        local = StatusFile(reqId=valid_req_id, requests=[request1])
        remote = StatusFile(reqId=valid_req_id, requests=[request2])

        merged = merge_status_files(local, remote)

        assert len(merged.requests) == 2

    def test_merges_approvals_in_matching_requests(self, valid_req_id, sample_author, valid_timestamp):
        """
        REQ-tv-d00011-W: merge_status_files SHALL merge approvals from
        matching requests (by requestId).
        """
        from trace_view.review.storage import merge_status_files
        from trace_view.review.models import StatusFile, StatusRequest, Approval
        import copy

        request = StatusRequest.create(
            valid_req_id, "Draft", "Active", sample_author, "Request",
            required_approvers=["user1", "user2"]
        )

        local_request = copy.deepcopy(request)
        local_request.add_approval("user1", "approve")

        remote_request = copy.deepcopy(request)
        remote_request.add_approval("user2", "approve")

        local = StatusFile(reqId=valid_req_id, requests=[local_request])
        remote = StatusFile(reqId=valid_req_id, requests=[remote_request])

        merged = merge_status_files(local, remote)

        # Should have approvals from both
        assert len(merged.requests) == 1
        merged_request = merged.requests[0]
        approving_users = {a.user for a in merged_request.approvals}
        assert "user1" in approving_users
        assert "user2" in approving_users


class TestMergeReviewFlags:
    """Tests for merge_review_flags function."""

    def test_returns_cleared_if_neither_flagged(self, sample_author):
        """
        REQ-tv-d00011-X: merge_review_flags SHALL return cleared flag
        if neither is flagged.
        """
        from trace_view.review.storage import merge_review_flags
        from trace_view.review.models import ReviewFlag

        local = ReviewFlag.cleared()
        remote = ReviewFlag.cleared()

        merged = merge_review_flags(local, remote)

        assert merged.flaggedForReview is False

    def test_returns_flagged_if_only_one_flagged(self, sample_author):
        """
        REQ-tv-d00011-X: merge_review_flags SHALL return flagged version
        if only one is flagged.
        """
        from trace_view.review.storage import merge_review_flags
        from trace_view.review.models import ReviewFlag

        local = ReviewFlag.cleared()
        remote = ReviewFlag.create(sample_author, "Needs review", ["user"])

        merged = merge_review_flags(local, remote)

        assert merged.flaggedForReview is True
        assert merged.reason == "Needs review"

    def test_merges_scopes_when_both_flagged(self, sample_author):
        """
        REQ-tv-d00011-X: merge_review_flags SHALL merge scopes when both
        are flagged.
        """
        from trace_view.review.storage import merge_review_flags
        from trace_view.review.models import ReviewFlag
        import time

        local = ReviewFlag.create(sample_author, "Local reason", ["user_a"])
        time.sleep(0.01)
        remote = ReviewFlag.create(sample_author, "Remote reason", ["user_b"])

        merged = merge_review_flags(local, remote)

        assert merged.flaggedForReview is True
        assert "user_a" in merged.scope
        assert "user_b" in merged.scope

    def test_takes_newer_metadata_when_both_flagged(self, sample_author):
        """
        REQ-tv-d00011-X: merge_review_flags SHALL take metadata from newer
        flag when both are flagged.
        """
        from trace_view.review.storage import merge_review_flags
        from trace_view.review.models import ReviewFlag
        import time

        local = ReviewFlag.create(sample_author, "Local reason", ["user_a"])
        time.sleep(0.01)
        remote = ReviewFlag.create("remote_author", "Remote reason", ["user_b"])

        merged = merge_review_flags(local, remote)

        # Remote is newer, so its reason and author should be used
        assert merged.reason == "Remote reason"
        assert merged.flaggedBy == "remote_author"


# =============================================================================
# Path Helper Tests
# =============================================================================

class TestPathHelpers:
    """Tests for file path helper functions."""

    def test_get_config_path(self, repo_root):
        """
        REQ-tv-d00011-Y: get_config_path SHALL return correct path.
        """
        from trace_view.review.models import get_config_path

        path = get_config_path(repo_root)

        assert path == repo_root / '.reviews' / 'config.json'

    def test_get_sessions_dir(self, repo_root):
        """
        REQ-tv-d00011-Y: get_sessions_dir SHALL return correct path.
        """
        from trace_view.review.models import get_sessions_dir

        path = get_sessions_dir(repo_root)

        assert path == repo_root / '.reviews' / 'sessions'

    def test_get_session_path(self, repo_root):
        """
        REQ-tv-d00011-Y: get_session_path SHALL return correct path.
        """
        from trace_view.review.models import get_session_path

        path = get_session_path(repo_root, "test-session-id")

        assert path == repo_root / '.reviews' / 'sessions' / 'test-session-id.json'

    def test_get_threads_path(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-Y: get_threads_path SHALL return correct path.
        """
        from trace_view.review.models import get_threads_path

        path = get_threads_path(repo_root, valid_req_id)

        assert path == repo_root / '.reviews' / 'reqs' / valid_req_id / 'threads.json'

    def test_get_status_path(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-Y: get_status_path SHALL return correct path.
        """
        from trace_view.review.models import get_status_path

        path = get_status_path(repo_root, valid_req_id)

        assert path == repo_root / '.reviews' / 'reqs' / valid_req_id / 'status.json'

    def test_get_review_flag_path(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-Y: get_review_flag_path SHALL return correct path.
        """
        from trace_view.review.models import get_review_flag_path

        path = get_review_flag_path(repo_root, valid_req_id)

        assert path == repo_root / '.reviews' / 'reqs' / valid_req_id / 'review-flag.json'

    def test_normalizes_req_id_in_paths(self, repo_root):
        """
        REQ-tv-d00011-Y: Path functions SHALL normalize req_id (lowercase,
        remove REQ- prefix).
        """
        from trace_view.review.models import get_threads_path

        # With uppercase and prefix
        path = get_threads_path(repo_root, "REQ-D00027")

        # Should be normalized to lowercase without prefix
        assert "d00027" in str(path)
        assert "REQ-" not in str(path)


# =============================================================================
# Error Handling Tests
# =============================================================================

class TestErrorHandling:
    """Tests for error handling in storage operations."""

    def test_handles_concurrent_writes(self, repo_root, valid_req_id, sample_thread):
        """
        REQ-tv-d00011-Z: Storage operations SHALL handle concurrent writes
        safely via atomic operations.
        """
        from trace_view.review.storage import add_thread, load_threads
        from trace_view.review.models import Thread, CommentPosition
        import threading

        # Add initial thread
        add_thread(repo_root, valid_req_id, sample_thread)

        errors = []

        def add_more_threads(thread_num):
            try:
                pos = CommentPosition.create_general("abcd1234")
                thread = Thread.create(
                    valid_req_id, f"user_{thread_num}", pos, f"Thread {thread_num}"
                )
                add_thread(repo_root, valid_req_id, thread)
            except Exception as e:
                errors.append(e)

        # Run multiple threads concurrently
        threads = [threading.Thread(target=add_more_threads, args=(i,)) for i in range(5)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        # Should not have errors (atomic writes prevent corruption)
        assert len(errors) == 0

        # All threads should be saved (though some may overwrite others)
        loaded = load_threads(repo_root, valid_req_id)
        assert len(loaded.threads) >= 1  # At least the initial thread

    def test_handles_corrupted_json_gracefully(self, repo_root, valid_req_id):
        """
        REQ-tv-d00011-Z: Storage operations SHALL handle corrupted JSON
        files gracefully.
        """
        from trace_view.review.storage import load_threads, save_threads
        from trace_view.review.models import ThreadsFile

        # Create a valid threads file first
        threads_file = ThreadsFile(reqId=valid_req_id, threads=[])
        save_threads(repo_root, valid_req_id, threads_file)

        # Corrupt the file
        threads_path = repo_root / '.reviews' / 'reqs' / valid_req_id / 'threads.json'
        threads_path.write_text("corrupted {{{ not json")

        # load_threads should raise JSONDecodeError (not crash)
        with pytest.raises(json.JSONDecodeError):
            load_threads(repo_root, valid_req_id)
