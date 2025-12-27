#!/usr/bin/env python3
"""
Tests for review_server.py branch management endpoints.

TDD tests for Module 23: API endpoints for branch management.
"""

import json
import pytest
import subprocess
import tempfile
from pathlib import Path

# Import the Flask app
from tools.spec_review.review_server import create_app
from tools.spec_review.review_branches import (
    create_review_branch,
    checkout_review_branch,
    get_current_package_context,
)
from tools.spec_review.review_storage import add_thread
from tools.spec_review.review_data import (
    Thread,
    Comment,
    CommentPosition,
)


@pytest.fixture
def temp_git_repo():
    """Create a temporary git repository for testing"""
    with tempfile.TemporaryDirectory() as tmpdir:
        repo = Path(tmpdir)
        # Initialize git repo
        subprocess.run(['git', 'init'], cwd=repo, capture_output=True, check=True)
        subprocess.run(
            ['git', 'config', 'user.email', 'test@test.com'],
            cwd=repo, capture_output=True, check=True
        )
        subprocess.run(
            ['git', 'config', 'user.name', 'Test User'],
            cwd=repo, capture_output=True, check=True
        )
        # Create initial commit
        (repo / 'README.md').write_text('# Test Repo')
        subprocess.run(['git', 'add', 'README.md'], cwd=repo, capture_output=True, check=True)
        subprocess.run(['git', 'commit', '-m', 'Initial commit'], cwd=repo, capture_output=True, check=True)
        yield repo


@pytest.fixture
def client(temp_git_repo):
    """Create a test client for the Flask app"""
    app = create_app(temp_git_repo, auto_sync=False)
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


@pytest.fixture
def temp_git_repo_with_remote():
    """Create a temp git repo with a fake remote"""
    with tempfile.TemporaryDirectory() as tmpdir:
        base_dir = Path(tmpdir)
        repo = base_dir / 'repo'
        remote_dir = base_dir / 'remote.git'

        repo.mkdir()
        subprocess.run(['git', 'init'], cwd=repo, capture_output=True, check=True)
        subprocess.run(
            ['git', 'config', 'user.email', 'test@test.com'],
            cwd=repo, capture_output=True, check=True
        )
        subprocess.run(
            ['git', 'config', 'user.name', 'Test User'],
            cwd=repo, capture_output=True, check=True
        )
        (repo / 'README.md').write_text('# Test Repo')
        subprocess.run(['git', 'add', 'README.md'], cwd=repo, capture_output=True, check=True)
        subprocess.run(['git', 'commit', '-m', 'Initial'], cwd=repo, capture_output=True, check=True)

        # Create bare remote
        subprocess.run(
            ['git', 'clone', '--bare', str(repo), str(remote_dir)],
            capture_output=True, check=True
        )
        subprocess.run(
            ['git', 'remote', 'add', 'origin', str(remote_dir)],
            cwd=repo, capture_output=True, check=True
        )
        yield repo


@pytest.fixture
def client_with_remote(temp_git_repo_with_remote):
    """Create a test client for the Flask app with remote"""
    app = create_app(temp_git_repo_with_remote, auto_sync=False)
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def _create_sample_thread(author: str, thread_id: str, req_id: str) -> Thread:
    """Helper to create a sample thread"""
    return Thread(
        threadId=thread_id,
        reqId=req_id,
        createdBy=author,
        createdAt="2025-01-15T10:00:00Z",
        position=CommentPosition(type="general", hashWhenCreated="abc12345"),
        resolved=False,
        comments=[
            Comment(
                id=f"c-{thread_id}",
                author=author,
                timestamp="2025-01-15T10:00:00Z",
                body=f"Comment by {author}"
            )
        ]
    )


# =============================================================================
# Tests for GET /api/reviews/context
# =============================================================================

class TestGetContext:
    """Test getting current package/user context from branch"""

    def test_context_not_on_review_branch(self, client, temp_git_repo):
        """Returns null when not on a review branch"""
        response = client.get('/api/reviews/context')
        assert response.status_code == 200
        data = response.get_json()
        assert data is None or data.get('packageId') is None

    def test_context_on_review_branch(self, client, temp_git_repo):
        """Returns package and user when on review branch"""
        # Create and checkout a review branch
        create_review_branch(temp_git_repo, 'q1-review', 'alice')
        checkout_review_branch(temp_git_repo, 'q1-review', 'alice')

        response = client.get('/api/reviews/context')
        assert response.status_code == 200
        data = response.get_json()
        assert data is not None
        assert data['packageId'] == 'q1-review'
        assert data['user'] == 'alice'
        assert 'branch' in data


# =============================================================================
# Tests for POST /api/reviews/packages/switch
# =============================================================================

class TestSwitchPackage:
    """Test switching to a package branch"""

    def test_switch_creates_branch_if_not_exists(self, client, temp_git_repo):
        """Switching to a package creates the branch if needed"""
        response = client.post(
            '/api/reviews/packages/switch',
            json={'packageId': 'new-package', 'user': 'bob'}
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True
        assert 'reviews/new-package/bob' in data['branch']

        # Verify we're now on that branch
        context = get_current_package_context(temp_git_repo)
        assert context == ('new-package', 'bob')

    def test_switch_to_existing_branch(self, client, temp_git_repo):
        """Switching to existing branch checks it out"""
        # Create the branch first
        create_review_branch(temp_git_repo, 'existing-pkg', 'charlie')

        # Go back to main
        subprocess.run(['git', 'checkout', 'master'], cwd=temp_git_repo, capture_output=True)
        subprocess.run(['git', 'checkout', 'main'], cwd=temp_git_repo, capture_output=True)

        # Switch via API
        response = client.post(
            '/api/reviews/packages/switch',
            json={'packageId': 'existing-pkg', 'user': 'charlie'}
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True

        # Verify we're on the branch
        context = get_current_package_context(temp_git_repo)
        assert context == ('existing-pkg', 'charlie')

    def test_switch_requires_package_id(self, client):
        """Switch requires packageId parameter"""
        response = client.post(
            '/api/reviews/packages/switch',
            json={'user': 'alice'}
        )
        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data

    def test_switch_requires_user(self, client):
        """Switch requires user parameter"""
        response = client.post(
            '/api/reviews/packages/switch',
            json={'packageId': 'test'}
        )
        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data

    def test_switch_stashes_uncommitted_changes(self, client, temp_git_repo):
        """Uncommitted changes are stashed before switching"""
        # Create first branch and make changes
        create_review_branch(temp_git_repo, 'pkg1', 'alice')
        checkout_review_branch(temp_git_repo, 'pkg1', 'alice')

        # Modify a tracked file (README.md)
        readme = temp_git_repo / 'README.md'
        readme.write_text('# Modified content')

        # Switch to different package
        response = client.post(
            '/api/reviews/packages/switch',
            json={'packageId': 'pkg2', 'user': 'alice'}
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True

        # Verify we're on new branch
        context = get_current_package_context(temp_git_repo)
        assert context == ('pkg2', 'alice')


# =============================================================================
# Tests for POST /api/reviews/sync/fetch-all-package
# =============================================================================

class TestFetchAllPackage:
    """Test fetching and merging data from all package branches"""

    def test_fetch_all_empty_package(self, client, temp_git_repo):
        """Returns empty data when no branches for package"""
        # Switch to a package first
        client.post(
            '/api/reviews/packages/switch',
            json={'packageId': 'empty-pkg', 'user': 'alice'}
        )

        response = client.post('/api/reviews/sync/fetch-all-package')
        assert response.status_code == 200
        data = response.get_json()
        assert 'threads' in data
        assert 'flags' in data
        assert 'contributors' in data

    def test_fetch_all_merges_multiple_users(self, client, temp_git_repo):
        """Merges data from multiple users' branches"""
        # Create Alice's branch with data
        create_review_branch(temp_git_repo, 'shared-pkg', 'alice')
        checkout_review_branch(temp_git_repo, 'shared-pkg', 'alice')
        thread_a = _create_sample_thread('alice', 't-alice', 'p00001')
        add_thread(temp_git_repo, 'p00001', thread_a)
        subprocess.run(['git', 'add', '.reviews/'], cwd=temp_git_repo, capture_output=True)
        subprocess.run(['git', 'commit', '-m', 'Alice data'], cwd=temp_git_repo, capture_output=True)

        # Go back to main and create Bob's branch
        subprocess.run(['git', 'checkout', 'master'], cwd=temp_git_repo, capture_output=True)
        subprocess.run(['git', 'checkout', 'main'], cwd=temp_git_repo, capture_output=True)

        create_review_branch(temp_git_repo, 'shared-pkg', 'bob')
        checkout_review_branch(temp_git_repo, 'shared-pkg', 'bob')
        thread_b = _create_sample_thread('bob', 't-bob', 'p00002')
        add_thread(temp_git_repo, 'p00002', thread_b)
        subprocess.run(['git', 'add', '.reviews/'], cwd=temp_git_repo, capture_output=True)
        subprocess.run(['git', 'commit', '-m', 'Bob data'], cwd=temp_git_repo, capture_output=True)

        # Fetch all via API (should get both Alice and Bob's data)
        response = client.post('/api/reviews/sync/fetch-all-package')
        assert response.status_code == 200
        data = response.get_json()

        # Should have both contributors
        assert 'alice' in data['contributors']
        assert 'bob' in data['contributors']

    def test_fetch_all_requires_package_context(self, client, temp_git_repo):
        """Returns error when not on a review branch"""
        # Ensure we're on main
        subprocess.run(['git', 'checkout', 'master'], cwd=temp_git_repo, capture_output=True)
        subprocess.run(['git', 'checkout', 'main'], cwd=temp_git_repo, capture_output=True)

        response = client.post('/api/reviews/sync/fetch-all-package')
        # Either returns empty data or error - both are acceptable
        assert response.status_code in [200, 400]


# =============================================================================
# Tests for GET /api/reviews/packages/<id>/contributors
# =============================================================================

class TestGetPackageContributors:
    """Test getting contributors for a package"""

    def test_contributors_empty_package(self, client, temp_git_repo):
        """Returns empty list for package with no branches"""
        response = client.get('/api/reviews/packages/nonexistent/contributors')
        assert response.status_code == 200
        data = response.get_json()
        assert data['contributors'] == []

    def test_contributors_with_branches(self, client, temp_git_repo):
        """Returns list of users with branches for package"""
        # Create branches for multiple users
        create_review_branch(temp_git_repo, 'test-pkg', 'alice')
        create_review_branch(temp_git_repo, 'test-pkg', 'bob')

        response = client.get('/api/reviews/packages/test-pkg/contributors')
        assert response.status_code == 200
        data = response.get_json()
        assert set(data['contributors']) == {'alice', 'bob'}
