#!/usr/bin/env python3
"""
Tests for review_merge.py - Consolidated Package View Module

TDD tests written before implementation.
"""

import pytest
import subprocess
import tempfile
from pathlib import Path
from typing import Dict

# Import from review_merge (will fail until implemented)
from tools.spec_review.review_merge import (
    fetch_all_package_branches,
    merge_package_review_data,
    get_package_contributors,
)

# Also need these for setup
from tools.spec_review.review_branches import (
    create_review_branch,
    checkout_review_branch,
    get_review_branch_name,
)
from tools.spec_review.review_storage import (
    save_threads,
    save_review_flag,
)
from tools.spec_review.review_data import (
    Thread,
    Comment,
    Position,
    ReviewFlag,
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


def _create_sample_thread(author: str, thread_id: str, req_id: str) -> Thread:
    """Helper to create a sample thread"""
    return Thread(
        threadId=thread_id,
        createdBy=author,
        createdAt="2025-01-15T10:00:00Z",
        position=Position(type="general"),
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
# Tests for get_package_contributors
# =============================================================================

class TestGetPackageContributors:
    """Test getting contributors for a package"""

    def test_no_contributors(self, temp_git_repo):
        """Empty list when no branches exist for package"""
        contributors = get_package_contributors(temp_git_repo, 'nonexistent')
        assert contributors == []

    def test_single_contributor(self, temp_git_repo):
        """List single contributor"""
        create_review_branch(temp_git_repo, 'default', 'alice')

        contributors = get_package_contributors(temp_git_repo, 'default')
        assert contributors == ['alice']

    def test_multiple_contributors(self, temp_git_repo):
        """List all contributors for a package"""
        create_review_branch(temp_git_repo, 'q1-review', 'alice')
        create_review_branch(temp_git_repo, 'q1-review', 'bob')
        create_review_branch(temp_git_repo, 'q1-review', 'charlie')

        contributors = get_package_contributors(temp_git_repo, 'q1-review')
        assert set(contributors) == {'alice', 'bob', 'charlie'}

    def test_contributors_sorted(self, temp_git_repo):
        """Contributors returned in sorted order"""
        create_review_branch(temp_git_repo, 'default', 'charlie')
        create_review_branch(temp_git_repo, 'default', 'alice')
        create_review_branch(temp_git_repo, 'default', 'bob')

        contributors = get_package_contributors(temp_git_repo, 'default')
        assert contributors == ['alice', 'bob', 'charlie']


# =============================================================================
# Tests for merge_package_review_data
# =============================================================================

class TestMergePackageReviewData:
    """Test merging review data from multiple package branches"""

    def test_empty_package_returns_empty(self, temp_git_repo):
        """Empty result when no branches"""
        data = merge_package_review_data(temp_git_repo, 'nonexistent')
        assert data == {'threads': {}, 'flags': {}, 'contributors': []}

    def test_single_user_data(self, temp_git_repo):
        """Merge data from single user"""
        # Create branch and add review data
        create_review_branch(temp_git_repo, 'default', 'alice')
        checkout_review_branch(temp_git_repo, 'default', 'alice')

        # Add some review data
        thread = _create_sample_thread('alice', 't1', 'p00001')
        save_threads(temp_git_repo, 'p00001', [thread])

        flag = ReviewFlag(
            flaggedForReview=True,
            flaggedBy='alice',
            flaggedAt="2025-01-15T10:00:00Z",
            reason="Test flag"
        )
        save_review_flag(temp_git_repo, 'p00001', flag)

        # Merge - should get alice's data
        data = merge_package_review_data(temp_git_repo, 'default')
        assert 'alice' in data['contributors']
        assert 'p00001' in data['threads']
        assert 'p00001' in data['flags']

    def test_merge_multiple_users(self, temp_git_repo):
        """Merge data from multiple users"""
        # Create Alice's branch with data
        create_review_branch(temp_git_repo, 'q1', 'alice')
        checkout_review_branch(temp_git_repo, 'q1', 'alice')
        thread_a = _create_sample_thread('alice', 't1', 'p00001')
        save_threads(temp_git_repo, 'p00001', [thread_a])

        # Commit Alice's changes
        subprocess.run(['git', 'add', '.reviews/'], cwd=temp_git_repo, capture_output=True)
        subprocess.run(['git', 'commit', '-m', 'Alice reviews'], cwd=temp_git_repo, capture_output=True)

        # Go back to main and create Bob's branch
        subprocess.run(['git', 'checkout', 'master'], cwd=temp_git_repo, capture_output=True)
        subprocess.run(['git', 'checkout', 'main'], cwd=temp_git_repo, capture_output=True)

        create_review_branch(temp_git_repo, 'q1', 'bob')
        checkout_review_branch(temp_git_repo, 'q1', 'bob')
        thread_b = _create_sample_thread('bob', 't2', 'p00002')
        save_threads(temp_git_repo, 'p00002', [thread_b])

        # Merge should include data from both
        data = merge_package_review_data(temp_git_repo, 'q1')
        assert 'alice' in data['contributors']
        assert 'bob' in data['contributors']

    def test_merge_threads_same_req(self, temp_git_repo):
        """Merge threads for the same REQ from different users"""
        # Create Alice's thread on p00001
        create_review_branch(temp_git_repo, 'pkg', 'alice')
        checkout_review_branch(temp_git_repo, 'pkg', 'alice')
        thread_a = _create_sample_thread('alice', 't-alice', 'p00001')
        save_threads(temp_git_repo, 'p00001', [thread_a])
        subprocess.run(['git', 'add', '.reviews/'], cwd=temp_git_repo, capture_output=True)
        subprocess.run(['git', 'commit', '-m', 'Alice thread'], cwd=temp_git_repo, capture_output=True)

        # Go back to main
        subprocess.run(['git', 'checkout', 'master'], cwd=temp_git_repo, capture_output=True)
        subprocess.run(['git', 'checkout', 'main'], cwd=temp_git_repo, capture_output=True)

        # Create Bob's thread on same p00001
        create_review_branch(temp_git_repo, 'pkg', 'bob')
        checkout_review_branch(temp_git_repo, 'pkg', 'bob')
        thread_b = _create_sample_thread('bob', 't-bob', 'p00001')
        save_threads(temp_git_repo, 'p00001', [thread_b])

        # Merge should combine threads
        data = merge_package_review_data(temp_git_repo, 'pkg')
        assert 'p00001' in data['threads']
        # Should have both threads
        p00001_threads = data['threads']['p00001']
        thread_ids = [t['threadId'] for t in p00001_threads]
        assert 't-alice' in thread_ids
        assert 't-bob' in thread_ids


# =============================================================================
# Tests for fetch_all_package_branches
# =============================================================================

class TestFetchAllPackageBranches:
    """Test fetching all remote branches for a package"""

    def test_fetch_no_remote(self, temp_git_repo):
        """Returns empty when no remote configured"""
        result = fetch_all_package_branches(temp_git_repo, 'default')
        assert result == []

    def test_fetch_with_remote(self, temp_git_repo_with_remote):
        """Fetch branches from remote"""
        # Create and push a branch
        create_review_branch(temp_git_repo_with_remote, 'default', 'alice')
        checkout_review_branch(temp_git_repo_with_remote, 'default', 'alice')
        (temp_git_repo_with_remote / 'test.txt').write_text('test')
        subprocess.run(['git', 'add', '.'], cwd=temp_git_repo_with_remote, capture_output=True)
        subprocess.run(['git', 'commit', '-m', 'test'], cwd=temp_git_repo_with_remote, capture_output=True)
        subprocess.run(['git', 'push', '-u', 'origin', 'reviews/default/alice'],
                      cwd=temp_git_repo_with_remote, capture_output=True)

        # Fetch should find the branch
        branches = fetch_all_package_branches(temp_git_repo_with_remote, 'default')
        # Should include the pushed branch
        assert any('alice' in b for b in branches)
