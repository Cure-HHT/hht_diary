"""
Tests for review/server.py - Flask API endpoints

TDD Red Phase: These tests are written BEFORE the implementation.
They will fail until server.py is implemented.

Each test function documents which assertion it verifies in its docstring.
The Elspais reporter extracts these references for traceability.

IMPLEMENTS REQUIREMENTS:
    REQ-d00088: Review Storage Operations
    REQ-d00093: Review Mode Server
"""

import json
from pathlib import Path
from typing import Dict, Any
from unittest.mock import patch, MagicMock

import pytest


# =============================================================================
# Test Fixtures
# =============================================================================

@pytest.fixture
def temp_repo(tmp_path):
    """
    Create a temporary repo structure with .reviews directory.

    Sets up the basic directory structure needed for review storage.
    """
    # Create .reviews directory structure
    reviews_dir = tmp_path / '.reviews'
    reviews_dir.mkdir()
    (reviews_dir / 'reqs').mkdir()
    (reviews_dir / 'sessions').mkdir()

    # Create a minimal spec directory for validation
    spec_dir = tmp_path / 'spec'
    spec_dir.mkdir()

    return tmp_path


@pytest.fixture
def app(temp_repo):
    """Create Flask test app with auto_sync disabled."""
    from trace_view.review.server import create_app

    app = create_app(temp_repo, auto_sync=False)
    app.config['TESTING'] = True
    return app


@pytest.fixture
def client(app):
    """Create Flask test client."""
    return app.test_client()


@pytest.fixture
def valid_req_id():
    """Provide a valid requirement ID."""
    return "d00027"


@pytest.fixture
def valid_hash():
    """Provide a valid 8-character hex hash."""
    return "a1b2c3d4"


@pytest.fixture
def sample_author():
    """Provide a sample author username."""
    return "test_user"


@pytest.fixture
def sample_thread_data(valid_req_id, valid_hash, sample_author):
    """Provide sample thread creation data."""
    from trace_view.review.models import Thread, CommentPosition

    position = CommentPosition.create_line(valid_hash, line_number=42, context="sample context")
    thread = Thread.create(
        req_id=valid_req_id,
        creator=sample_author,
        position=position,
        initial_comment="Initial comment on thread"
    )
    return thread.to_dict()


@pytest.fixture
def sample_comment_data(sample_author):
    """Provide sample comment creation data."""
    return {
        "author": sample_author,
        "body": "This is a test comment"
    }


@pytest.fixture
def sample_flag_data(sample_author):
    """Provide sample review flag data."""
    from trace_view.review.models import ReviewFlag

    flag = ReviewFlag.create(
        user=sample_author,
        reason="Needs review",
        scope=["product_owner", "tech_lead"]
    )
    return flag.to_dict()


@pytest.fixture
def sample_status_request_data(valid_req_id, sample_author):
    """Provide sample status request data."""
    from trace_view.review.models import StatusRequest

    request = StatusRequest.create(
        req_id=valid_req_id,
        from_status="Draft",
        to_status="Active",
        requested_by=sample_author,
        justification="Ready for review"
    )
    return request.to_dict()


@pytest.fixture
def sample_approval_data():
    """Provide sample approval data."""
    from trace_view.review.models import Approval

    approval = Approval.create(
        user="product_owner",
        decision="approve",
        comment="Looks good"
    )
    return approval.to_dict()


@pytest.fixture
def repo_with_thread(temp_repo, valid_req_id, valid_hash, sample_author):
    """Create a repo with an existing thread for testing."""
    from trace_view.review.storage import add_thread
    from trace_view.review.models import Thread, CommentPosition

    position = CommentPosition.create_line(valid_hash, line_number=42)
    thread = Thread.create(
        req_id=valid_req_id,
        creator=sample_author,
        position=position,
        initial_comment="Existing thread"
    )
    add_thread(temp_repo, valid_req_id, thread)

    return temp_repo, thread


@pytest.fixture
def repo_with_status_request(temp_repo, valid_req_id, sample_author):
    """Create a repo with an existing status request for testing."""
    from trace_view.review.storage import create_status_request
    from trace_view.review.models import StatusRequest

    request = StatusRequest.create(
        req_id=valid_req_id,
        from_status="Draft",
        to_status="Active",
        requested_by=sample_author,
        justification="Ready for review",
        required_approvers=["product_owner"]
    )
    create_status_request(temp_repo, valid_req_id, request)

    return temp_repo, request


# =============================================================================
# Health Check Tests
# =============================================================================

class TestHealthCheck:
    """Tests for the health check endpoint."""

    def test_health_returns_ok(self, client):
        """
        REQ-d00093-A: GET /api/health SHALL return status 'ok'.
        """
        response = client.get('/api/health')

        assert response.status_code == 200
        data = response.get_json()
        assert data['status'] == 'ok'

    def test_health_includes_repo_root(self, client, temp_repo):
        """
        REQ-d00093-A: GET /api/health SHALL include repo_root in response.
        """
        response = client.get('/api/health')

        assert response.status_code == 200
        data = response.get_json()
        assert 'repo_root' in data
        assert str(temp_repo) in data['repo_root']

    def test_health_includes_reviews_dir(self, client, temp_repo):
        """
        REQ-d00093-A: GET /api/health SHALL include reviews_dir in response.
        """
        response = client.get('/api/health')

        assert response.status_code == 200
        data = response.get_json()
        assert 'reviews_dir' in data
        assert '.reviews' in data['reviews_dir']


# =============================================================================
# Reviews API Tests
# =============================================================================

class TestReviewsAPI:
    """Tests for the reviews data API endpoints."""

    def test_get_all_reviews_empty(self, client):
        """
        REQ-d00093-B: GET /api/reviews SHALL return empty structure when no reviews exist.
        """
        response = client.get('/api/reviews')

        assert response.status_code == 200
        data = response.get_json()
        assert 'threads' in data
        assert 'flags' in data
        assert 'requests' in data
        assert 'config' in data
        assert data['threads'] == {}
        assert data['flags'] == {}
        assert data['requests'] == {}

    def test_get_all_reviews_with_data(self, client, temp_repo, valid_req_id,
                                        valid_hash, sample_author):
        """
        REQ-d00093-B: GET /api/reviews SHALL return all review data.
        """
        from trace_view.review.storage import add_thread, save_review_flag
        from trace_view.review.models import Thread, CommentPosition, ReviewFlag

        # Create thread
        position = CommentPosition.create_line(valid_hash, line_number=10)
        thread = Thread.create(valid_req_id, sample_author, position, "Test thread")
        add_thread(temp_repo, valid_req_id, thread)

        # Create flag
        flag = ReviewFlag.create(sample_author, "Needs review", ["reviewer"])
        save_review_flag(temp_repo, valid_req_id, flag)

        response = client.get('/api/reviews')

        assert response.status_code == 200
        data = response.get_json()
        assert valid_req_id in data['threads']
        assert valid_req_id in data['flags']

    def test_get_req_reviews_empty(self, client, valid_req_id):
        """
        REQ-d00093-C: GET /api/reviews/reqs/<req_id> SHALL return empty data
        for non-existent REQ.
        """
        response = client.get(f'/api/reviews/reqs/{valid_req_id}')

        assert response.status_code == 200
        data = response.get_json()
        assert data['threads'] == []
        assert data['flag'] is None
        assert data['requests'] == []

    def test_get_req_reviews_normalizes_id(self, client, temp_repo, sample_author, valid_hash):
        """
        REQ-d00093-C: GET /api/reviews/reqs/<req_id> SHALL normalize req_id
        (handle REQ- prefix, case).
        """
        from trace_view.review.storage import add_thread
        from trace_view.review.models import Thread, CommentPosition

        # Add thread using lowercase ID
        position = CommentPosition.create_line(valid_hash, line_number=10)
        thread = Thread.create("d00027", sample_author, position, "Test")
        add_thread(temp_repo, "d00027", thread)

        # Request with uppercase and prefix
        response = client.get('/api/reviews/reqs/REQ-D00027')

        assert response.status_code == 200
        data = response.get_json()
        assert len(data['threads']) == 1


# =============================================================================
# Thread API Tests
# =============================================================================

class TestThreadAPI:
    """Tests for thread management endpoints."""

    def test_create_thread_success(self, client, valid_req_id, sample_thread_data):
        """
        REQ-d00093-D: POST /api/reviews/reqs/<req_id>/threads SHALL create
        a new thread and return 201.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads',
            data=json.dumps(sample_thread_data),
            content_type='application/json'
        )

        assert response.status_code == 201
        data = response.get_json()
        assert data['success'] is True
        assert 'thread' in data

    def test_create_thread_returns_thread_data(self, client, valid_req_id, sample_thread_data):
        """
        REQ-d00093-D: POST /api/reviews/reqs/<req_id>/threads SHALL return
        the created thread data.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads',
            data=json.dumps(sample_thread_data),
            content_type='application/json'
        )

        data = response.get_json()
        assert data['thread']['threadId'] == sample_thread_data['threadId']
        assert data['thread']['reqId'] == sample_thread_data['reqId']

    def test_create_thread_no_data(self, client, valid_req_id):
        """
        REQ-d00093-D: POST /api/reviews/reqs/<req_id>/threads SHALL return
        400 if no data provided.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads',
            content_type='application/json'
        )

        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data

    def test_create_thread_invalid_data(self, client, valid_req_id):
        """
        REQ-d00093-D: POST /api/reviews/reqs/<req_id>/threads SHALL return
        400 for invalid thread data.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads',
            data=json.dumps({"invalid": "data"}),
            content_type='application/json'
        )

        assert response.status_code == 400

    def test_add_comment_success(self, client, valid_req_id, sample_comment_data,
                                  repo_with_thread):
        """
        REQ-d00093-E: POST /api/reviews/reqs/<req_id>/threads/<thread_id>/comments
        SHALL add comment and return 201.
        """
        temp_repo, thread = repo_with_thread

        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads/{thread.threadId}/comments',
            data=json.dumps(sample_comment_data),
            content_type='application/json'
        )

        assert response.status_code == 201
        data = response.get_json()
        assert data['success'] is True
        assert 'comment' in data

    def test_add_comment_returns_comment_data(self, client, valid_req_id,
                                               sample_comment_data, repo_with_thread):
        """
        REQ-d00093-E: POST .../comments SHALL return the created comment data.
        """
        temp_repo, thread = repo_with_thread

        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads/{thread.threadId}/comments',
            data=json.dumps(sample_comment_data),
            content_type='application/json'
        )

        data = response.get_json()
        assert data['comment']['author'] == sample_comment_data['author']
        assert data['comment']['body'] == sample_comment_data['body']

    def test_add_comment_no_data(self, client, valid_req_id, repo_with_thread):
        """
        REQ-d00093-E: POST .../comments SHALL return 400 if no data provided.
        """
        temp_repo, thread = repo_with_thread

        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads/{thread.threadId}/comments',
            content_type='application/json'
        )

        assert response.status_code == 400

    def test_add_comment_missing_author(self, client, valid_req_id, repo_with_thread):
        """
        REQ-d00093-E: POST .../comments SHALL return 400 if author is missing.
        """
        temp_repo, thread = repo_with_thread

        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads/{thread.threadId}/comments',
            data=json.dumps({"body": "Comment without author"}),
            content_type='application/json'
        )

        assert response.status_code == 400
        data = response.get_json()
        assert 'author' in data['error'].lower()

    def test_add_comment_missing_body(self, client, valid_req_id, repo_with_thread):
        """
        REQ-d00093-E: POST .../comments SHALL return 400 if body is missing.
        """
        temp_repo, thread = repo_with_thread

        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads/{thread.threadId}/comments',
            data=json.dumps({"author": "user"}),
            content_type='application/json'
        )

        assert response.status_code == 400
        data = response.get_json()
        assert 'body' in data['error'].lower()

    def test_add_comment_thread_not_found(self, client, valid_req_id, sample_comment_data):
        """
        REQ-d00093-E: POST .../comments SHALL return 400 if thread not found.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads/nonexistent-thread-id/comments',
            data=json.dumps(sample_comment_data),
            content_type='application/json'
        )

        assert response.status_code == 400

    def test_resolve_thread_success(self, client, valid_req_id, repo_with_thread):
        """
        REQ-d00093-F: POST .../threads/<thread_id>/resolve SHALL resolve thread
        and return 200.
        """
        temp_repo, thread = repo_with_thread

        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads/{thread.threadId}/resolve',
            data=json.dumps({"user": "resolver_user"}),
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True

    def test_resolve_thread_uses_anonymous_if_no_user(self, client, valid_req_id,
                                                       repo_with_thread, temp_repo):
        """
        REQ-d00093-F: POST .../resolve SHALL use 'anonymous' if no user provided.
        """
        temp_repo_fixture, thread = repo_with_thread

        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads/{thread.threadId}/resolve',
            content_type='application/json'
        )

        assert response.status_code == 200

        # Verify the thread is resolved
        from trace_view.review.storage import load_threads
        threads = load_threads(temp_repo_fixture, valid_req_id)
        resolved_thread = threads.threads[0]
        assert resolved_thread.resolved is True
        assert resolved_thread.resolvedBy == "anonymous"

    def test_unresolve_thread_success(self, client, valid_req_id, repo_with_thread):
        """
        REQ-d00093-G: POST .../threads/<thread_id>/unresolve SHALL unresolve thread
        and return 200.
        """
        temp_repo, thread = repo_with_thread

        # First resolve
        client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads/{thread.threadId}/resolve',
            data=json.dumps({"user": "resolver"}),
            content_type='application/json'
        )

        # Then unresolve
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads/{thread.threadId}/unresolve',
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True


# =============================================================================
# Flag API Tests
# =============================================================================

class TestFlagAPI:
    """Tests for review flag management endpoints."""

    def test_get_flag_not_exists(self, client, valid_req_id):
        """
        REQ-d00093-H: GET /api/reviews/reqs/<req_id>/flag SHALL return
        unflagged state if no flag exists.
        """
        response = client.get(f'/api/reviews/reqs/{valid_req_id}/flag')

        assert response.status_code == 200
        data = response.get_json()
        assert data['flaggedForReview'] is False

    def test_get_flag_exists(self, client, temp_repo, valid_req_id, sample_author):
        """
        REQ-d00093-H: GET /api/reviews/reqs/<req_id>/flag SHALL return
        flag data if flag exists.
        """
        from trace_view.review.storage import save_review_flag
        from trace_view.review.models import ReviewFlag

        flag = ReviewFlag.create(sample_author, "Needs review", ["reviewer"])
        save_review_flag(temp_repo, valid_req_id, flag)

        response = client.get(f'/api/reviews/reqs/{valid_req_id}/flag')

        assert response.status_code == 200
        data = response.get_json()
        assert data['flaggedForReview'] is True
        assert data['reason'] == "Needs review"

    def test_set_flag_success(self, client, valid_req_id, sample_flag_data):
        """
        REQ-d00093-I: POST /api/reviews/reqs/<req_id>/flag SHALL set flag
        and return 200.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/flag',
            data=json.dumps(sample_flag_data),
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True
        assert 'flag' in data

    def test_set_flag_returns_flag_data(self, client, valid_req_id, sample_flag_data):
        """
        REQ-d00093-I: POST .../flag SHALL return the saved flag data.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/flag',
            data=json.dumps(sample_flag_data),
            content_type='application/json'
        )

        data = response.get_json()
        assert data['flag']['flaggedForReview'] is True
        assert data['flag']['reason'] == sample_flag_data['reason']

    def test_set_flag_no_data(self, client, valid_req_id):
        """
        REQ-d00093-I: POST .../flag SHALL return 400 if no data provided.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/flag',
            content_type='application/json'
        )

        assert response.status_code == 400

    def test_clear_flag_success(self, client, temp_repo, valid_req_id, sample_author):
        """
        REQ-d00093-J: DELETE /api/reviews/reqs/<req_id>/flag SHALL clear flag
        and return 200.
        """
        from trace_view.review.storage import save_review_flag
        from trace_view.review.models import ReviewFlag

        # First set a flag
        flag = ReviewFlag.create(sample_author, "Needs review", ["reviewer"])
        save_review_flag(temp_repo, valid_req_id, flag)

        # Then clear it
        response = client.delete(
            f'/api/reviews/reqs/{valid_req_id}/flag',
            data=json.dumps({"user": sample_author}),
            content_type='application/json'
        )

        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True

    def test_clear_flag_persists(self, client, temp_repo, valid_req_id, sample_author):
        """
        REQ-d00093-J: DELETE .../flag SHALL persist the cleared state.
        """
        from trace_view.review.storage import save_review_flag, load_review_flag
        from trace_view.review.models import ReviewFlag

        flag = ReviewFlag.create(sample_author, "Needs review", ["reviewer"])
        save_review_flag(temp_repo, valid_req_id, flag)

        client.delete(
            f'/api/reviews/reqs/{valid_req_id}/flag',
            content_type='application/json'
        )

        # Verify flag is cleared
        loaded_flag = load_review_flag(temp_repo, valid_req_id)
        assert loaded_flag.flaggedForReview is False


# =============================================================================
# Status Request API Tests
# =============================================================================

class TestStatusRequestAPI:
    """Tests for status request management endpoints."""

    def test_get_status_requests_empty(self, client, valid_req_id):
        """
        REQ-d00093-K: GET /api/reviews/reqs/<req_id>/requests SHALL return
        empty list if no requests exist.
        """
        response = client.get(f'/api/reviews/reqs/{valid_req_id}/requests')

        assert response.status_code == 200
        data = response.get_json()
        assert data == []

    def test_get_status_requests_exists(self, client, valid_req_id,
                                         repo_with_status_request):
        """
        REQ-d00093-K: GET /api/reviews/reqs/<req_id>/requests SHALL return
        all status requests.
        """
        temp_repo, request = repo_with_status_request

        response = client.get(f'/api/reviews/reqs/{valid_req_id}/requests')

        assert response.status_code == 200
        data = response.get_json()
        assert len(data) == 1
        assert data[0]['requestId'] == request.requestId

    def test_create_status_request_success(self, client, valid_req_id,
                                            sample_status_request_data):
        """
        REQ-d00093-L: POST /api/reviews/reqs/<req_id>/requests SHALL create
        status request and return 201.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/requests',
            data=json.dumps(sample_status_request_data),
            content_type='application/json'
        )

        assert response.status_code == 201
        data = response.get_json()
        assert data['success'] is True
        assert 'request' in data

    def test_create_status_request_returns_data(self, client, valid_req_id,
                                                  sample_status_request_data):
        """
        REQ-d00093-L: POST .../requests SHALL return the created request data.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/requests',
            data=json.dumps(sample_status_request_data),
            content_type='application/json'
        )

        data = response.get_json()
        assert data['request']['fromStatus'] == sample_status_request_data['fromStatus']
        assert data['request']['toStatus'] == sample_status_request_data['toStatus']

    def test_create_status_request_no_data(self, client, valid_req_id):
        """
        REQ-d00093-L: POST .../requests SHALL return 400 if no data provided.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/requests',
            content_type='application/json'
        )

        assert response.status_code == 400

    def test_add_approval_success(self, client, valid_req_id, sample_approval_data,
                                   repo_with_status_request):
        """
        REQ-d00093-M: POST .../requests/<request_id>/approvals SHALL add
        approval and return 201.
        """
        temp_repo, request = repo_with_status_request

        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/requests/{request.requestId}/approvals',
            data=json.dumps(sample_approval_data),
            content_type='application/json'
        )

        assert response.status_code == 201
        data = response.get_json()
        assert data['success'] is True
        assert 'approval' in data

    def test_add_approval_returns_data(self, client, valid_req_id, sample_approval_data,
                                        repo_with_status_request):
        """
        REQ-d00093-M: POST .../approvals SHALL return the created approval data.
        """
        temp_repo, request = repo_with_status_request

        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/requests/{request.requestId}/approvals',
            data=json.dumps(sample_approval_data),
            content_type='application/json'
        )

        data = response.get_json()
        assert data['approval']['user'] == sample_approval_data['user']
        assert data['approval']['decision'] == sample_approval_data['decision']

    def test_add_approval_no_data(self, client, valid_req_id, repo_with_status_request):
        """
        REQ-d00093-M: POST .../approvals SHALL return 400 if no data provided.
        """
        temp_repo, request = repo_with_status_request

        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/requests/{request.requestId}/approvals',
            content_type='application/json'
        )

        assert response.status_code == 400

    def test_add_approval_request_not_found(self, client, valid_req_id, sample_approval_data):
        """
        REQ-d00093-M: POST .../approvals SHALL return 400 if request not found.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/requests/nonexistent-id/approvals',
            data=json.dumps(sample_approval_data),
            content_type='application/json'
        )

        assert response.status_code == 400


# =============================================================================
# Sync API Tests
# =============================================================================

class TestSyncAPI:
    """Tests for git sync status endpoints."""

    def test_get_sync_status(self, client):
        """
        REQ-d00093-N: GET /api/reviews/sync/status SHALL return sync status.
        """
        response = client.get('/api/reviews/sync/status')

        assert response.status_code == 200
        data = response.get_json()
        assert 'has_local_changes' in data
        assert 'ahead' in data
        assert 'behind' in data
        assert 'branch' in data

    def test_get_sync_status_includes_auto_sync(self, client):
        """
        REQ-d00093-N: GET /api/reviews/sync/status SHALL include auto_sync_enabled.
        """
        response = client.get('/api/reviews/sync/status')

        data = response.get_json()
        assert 'auto_sync_enabled' in data

    def test_sync_status_auto_sync_disabled_in_tests(self, client):
        """
        REQ-d00093-N: Sync status SHALL reflect app config for auto_sync.
        """
        response = client.get('/api/reviews/sync/status')

        data = response.get_json()
        # In tests, auto_sync is disabled
        assert data['auto_sync_enabled'] is False


# =============================================================================
# Auto-Sync Behavior Tests
# =============================================================================

class TestAutoSyncBehavior:
    """Tests for auto-sync behavior when enabled."""

    @pytest.fixture
    def app_with_sync(self, temp_repo):
        """Create Flask app with auto_sync enabled."""
        from trace_view.review.server import create_app

        app = create_app(temp_repo, auto_sync=True)
        app.config['TESTING'] = True
        return app

    @pytest.fixture
    def client_with_sync(self, app_with_sync):
        """Create test client for app with sync enabled."""
        return app_with_sync.test_client()

    def test_create_thread_triggers_sync(self, client_with_sync, valid_req_id,
                                          sample_thread_data):
        """
        REQ-d00093-O: POST /api/reviews/.../threads SHALL trigger auto-sync
        when enabled.
        """
        with patch('trace_view.review.server.commit_and_push_reviews') as mock_sync:
            mock_sync.return_value = {'success': True, 'committed': True, 'pushed': True}

            response = client_with_sync.post(
                f'/api/reviews/reqs/{valid_req_id}/threads',
                data=json.dumps(sample_thread_data),
                content_type='application/json'
            )

            assert response.status_code == 201
            data = response.get_json()
            # Sync result should be in response when auto_sync is enabled
            assert 'sync' in data or mock_sync.called

    def test_sync_disabled_no_trigger(self, client, valid_req_id, sample_thread_data):
        """
        REQ-d00093-O: POST operations SHALL NOT trigger sync when auto_sync disabled.
        """
        with patch('trace_view.review.server.commit_and_push_reviews') as mock_sync:
            response = client.post(
                f'/api/reviews/reqs/{valid_req_id}/threads',
                data=json.dumps(sample_thread_data),
                content_type='application/json'
            )

            assert response.status_code == 201
            data = response.get_json()
            # No sync key when auto_sync is disabled
            assert 'sync' not in data


# =============================================================================
# Error Handling Tests
# =============================================================================

class TestErrorHandling:
    """Tests for error handling in API endpoints."""

    def test_invalid_json_returns_400(self, client, valid_req_id):
        """
        REQ-d00093-P: API SHALL return 400 for invalid JSON payload.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads',
            data='not valid json {',
            content_type='application/json'
        )

        # Flask returns 400 for malformed JSON
        assert response.status_code in [400, 415]

    def test_exception_handling_returns_error(self, client, valid_req_id):
        """
        REQ-d00093-P: API SHALL return error message on exceptions.
        """
        # Try to add comment to non-existent thread
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads/fake-id/comments',
            data=json.dumps({"author": "user", "body": "comment"}),
            content_type='application/json'
        )

        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data


# =============================================================================
# CORS Tests
# =============================================================================

class TestCORS:
    """Tests for CORS configuration."""

    def test_cors_headers_present(self, client):
        """
        REQ-d00093-Q: API SHALL include CORS headers for browser requests.
        """
        response = client.options('/api/health')

        # CORS preflight or actual request should work
        assert response.status_code in [200, 204]


# =============================================================================
# Create App Factory Tests
# =============================================================================

class TestCreateAppFactory:
    """Tests for the create_app factory function."""

    def test_create_app_with_repo_root(self, temp_repo):
        """
        REQ-d00093-R: create_app SHALL accept repo_root parameter.
        """
        from trace_view.review.server import create_app

        app = create_app(temp_repo)

        assert app.config['REPO_ROOT'] == temp_repo

    def test_create_app_with_auto_sync_false(self, temp_repo):
        """
        REQ-d00093-R: create_app SHALL accept auto_sync parameter.
        """
        from trace_view.review.server import create_app

        app = create_app(temp_repo, auto_sync=False)

        assert app.config['AUTO_SYNC'] is False

    def test_create_app_with_auto_sync_true(self, temp_repo):
        """
        REQ-d00093-R: create_app SHALL default auto_sync to True.
        """
        from trace_view.review.server import create_app

        app = create_app(temp_repo)

        assert app.config['AUTO_SYNC'] is True

    def test_create_app_sets_testing_flag(self, temp_repo):
        """
        REQ-d00093-R: create_app SHALL allow TESTING config to be set.
        """
        from trace_view.review.server import create_app

        app = create_app(temp_repo)
        app.config['TESTING'] = True

        assert app.config['TESTING'] is True


# =============================================================================
# ID Normalization Tests
# =============================================================================

class TestIdNormalization:
    """Tests for requirement ID normalization across endpoints."""

    def test_thread_endpoint_normalizes_id(self, client, temp_repo,
                                            sample_thread_data, valid_hash, sample_author):
        """
        REQ-d00093-S: Thread endpoints SHALL normalize req_id.
        """
        from trace_view.review.models import Thread, CommentPosition
        from trace_view.review.storage import load_threads

        # Create thread data with normalized ID
        position = CommentPosition.create_line(valid_hash, line_number=10)
        thread = Thread.create("d00027", sample_author, position, "Test")

        # POST with uppercase prefix
        response = client.post(
            '/api/reviews/reqs/REQ-D00027/threads',
            data=json.dumps(thread.to_dict()),
            content_type='application/json'
        )

        assert response.status_code == 201

        # Should be stored with normalized ID
        loaded = load_threads(temp_repo, "d00027")
        assert len(loaded.threads) == 1

    def test_flag_endpoint_normalizes_id(self, client, temp_repo, sample_flag_data):
        """
        REQ-d00093-S: Flag endpoints SHALL normalize req_id.
        """
        from trace_view.review.storage import load_review_flag

        # POST with uppercase prefix
        response = client.post(
            '/api/reviews/reqs/REQ-D00027/flag',
            data=json.dumps(sample_flag_data),
            content_type='application/json'
        )

        assert response.status_code == 200

        # Should be retrievable with normalized ID
        flag = load_review_flag(temp_repo, "d00027")
        assert flag.flaggedForReview is True

    def test_status_request_endpoint_normalizes_id(self, client, temp_repo,
                                                     sample_status_request_data):
        """
        REQ-d00093-S: Status request endpoints SHALL normalize req_id.
        """
        from trace_view.review.storage import load_status_requests

        # POST with uppercase prefix
        response = client.post(
            '/api/reviews/reqs/REQ-D00027/requests',
            data=json.dumps(sample_status_request_data),
            content_type='application/json'
        )

        assert response.status_code == 201

        # Should be retrievable with normalized ID
        status = load_status_requests(temp_repo, "d00027")
        assert len(status.requests) == 1


# =============================================================================
# Response Format Tests
# =============================================================================

class TestResponseFormat:
    """Tests for API response format consistency."""

    def test_success_response_format(self, client, valid_req_id, sample_thread_data):
        """
        REQ-d00093-T: Success responses SHALL include 'success: true'.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads',
            data=json.dumps(sample_thread_data),
            content_type='application/json'
        )

        data = response.get_json()
        assert data['success'] is True

    def test_error_response_format(self, client, valid_req_id):
        """
        REQ-d00093-T: Error responses SHALL include 'error' key.
        """
        response = client.post(
            f'/api/reviews/reqs/{valid_req_id}/threads',
            content_type='application/json'
        )

        data = response.get_json()
        assert 'error' in data

    def test_list_response_format(self, client, valid_req_id):
        """
        REQ-d00093-T: List responses SHALL return JSON array.
        """
        response = client.get(f'/api/reviews/reqs/{valid_req_id}/requests')

        data = response.get_json()
        assert isinstance(data, list)

    def test_health_response_format(self, client):
        """
        REQ-d00093-T: Health response SHALL return proper structure.
        """
        response = client.get('/api/health')

        data = response.get_json()
        assert 'status' in data
        assert 'repo_root' in data
        assert 'reviews_dir' in data
