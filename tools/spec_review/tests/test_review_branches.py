#!/usr/bin/env python3
"""
Tests for review_branches.py - Git Branch Management Module

TDD tests written before implementation.
"""

import os
import pytest
import subprocess
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

from tools.spec_review.review_branches import (
    # Branch naming
    get_review_branch_name,
    parse_review_branch_name,
    is_review_branch,
    # Git utilities
    get_current_branch,
    get_remote_name,
    branch_exists,
    remote_branch_exists,
    # Branch operations
    create_review_branch,
    checkout_review_branch,
    push_review_branch,
    fetch_review_branches,
    # Listing and discovery
    list_local_review_branches,
    list_remote_review_branches,
    list_all_review_users,
    # Cleanup
    delete_local_review_branch,
    delete_remote_review_branch,
    cleanup_old_branches,
    # Conflict detection
    has_uncommitted_changes,
    check_review_branch_conflicts,
)


@pytest.fixture
def temp_git_repo():
    """Create a temporary git repository for testing"""
    with tempfile.TemporaryDirectory() as tmpdir:
        repo = Path(tmpdir)
        # Initialize git repo
        subprocess.run(
            ['git', 'init'],
            cwd=repo,
            capture_output=True,
            check=True
        )
        # Configure user for commits
        subprocess.run(
            ['git', 'config', 'user.email', 'test@test.com'],
            cwd=repo,
            capture_output=True,
            check=True
        )
        subprocess.run(
            ['git', 'config', 'user.name', 'Test User'],
            cwd=repo,
            capture_output=True,
            check=True
        )
        # Create initial commit
        (repo / 'README.md').write_text('# Test Repo')
        subprocess.run(
            ['git', 'add', 'README.md'],
            cwd=repo,
            capture_output=True,
            check=True
        )
        subprocess.run(
            ['git', 'commit', '-m', 'Initial commit'],
            cwd=repo,
            capture_output=True,
            check=True
        )
        yield repo


@pytest.fixture
def temp_git_repo_with_remote():
    """Create a temp git repo with a fake remote"""
    with tempfile.TemporaryDirectory() as tmpdir:
        base_dir = Path(tmpdir)
        repo = base_dir / 'repo'
        remote_dir = base_dir / 'remote.git'

        # Initialize git repo
        repo.mkdir()
        subprocess.run(
            ['git', 'init'],
            cwd=repo,
            capture_output=True,
            check=True
        )
        subprocess.run(
            ['git', 'config', 'user.email', 'test@test.com'],
            cwd=repo,
            capture_output=True,
            check=True
        )
        subprocess.run(
            ['git', 'config', 'user.name', 'Test User'],
            cwd=repo,
            capture_output=True,
            check=True
        )
        # Create initial commit
        (repo / 'README.md').write_text('# Test Repo')
        subprocess.run(
            ['git', 'add', 'README.md'],
            cwd=repo,
            capture_output=True,
            check=True
        )
        subprocess.run(
            ['git', 'commit', '-m', 'Initial commit'],
            cwd=repo,
            capture_output=True,
            check=True
        )

        # Create bare remote
        subprocess.run(
            ['git', 'clone', '--bare', str(repo), str(remote_dir)],
            capture_output=True,
            check=True
        )
        # Add remote to main repo
        subprocess.run(
            ['git', 'remote', 'add', 'origin', str(remote_dir)],
            cwd=repo,
            capture_output=True,
            check=True
        )
        yield repo


# =============================================================================
# Tests for Branch Naming
# =============================================================================

class TestBranchNaming:
    """Test branch name generation and parsing"""

    def test_get_review_branch_name(self):
        name = get_review_branch_name('alice', 'q1-review')
        assert name == 'reviews/alice/q1-review'

    def test_get_review_branch_name_sanitizes_spaces(self):
        name = get_review_branch_name('alice', 'Q1 Review Session')
        assert ' ' not in name
        assert name.startswith('reviews/alice/')

    def test_get_review_branch_name_sanitizes_special_chars(self):
        name = get_review_branch_name('alice', 'review@#$%')
        # Should only contain valid git branch chars
        assert all(c.isalnum() or c in '-_/' for c in name)

    def test_parse_review_branch_name(self):
        result = parse_review_branch_name('reviews/alice/q1-review')
        assert result == ('alice', 'q1-review')

    def test_parse_review_branch_name_invalid(self):
        result = parse_review_branch_name('main')
        assert result is None

    def test_parse_review_branch_name_wrong_prefix(self):
        result = parse_review_branch_name('feature/alice/something')
        assert result is None

    def test_is_review_branch_valid(self):
        assert is_review_branch('reviews/alice/q1')
        assert is_review_branch('reviews/bob/sprint-23')

    def test_is_review_branch_invalid(self):
        assert not is_review_branch('main')
        assert not is_review_branch('feature/new-thing')
        assert not is_review_branch('reviews')  # Incomplete
        assert not is_review_branch('reviews/alice')  # Missing session


# =============================================================================
# Tests for Git Utilities
# =============================================================================

class TestGitUtilities:
    """Test git utility functions"""

    def test_get_current_branch(self, temp_git_repo):
        # Default branch after init
        branch = get_current_branch(temp_git_repo)
        assert branch in ['main', 'master']  # Depends on git config

    def test_get_current_branch_after_checkout(self, temp_git_repo):
        subprocess.run(
            ['git', 'checkout', '-b', 'test-branch'],
            cwd=temp_git_repo,
            capture_output=True,
            check=True
        )
        branch = get_current_branch(temp_git_repo)
        assert branch == 'test-branch'

    def test_get_remote_name_default(self, temp_git_repo_with_remote):
        remote = get_remote_name(temp_git_repo_with_remote)
        assert remote == 'origin'

    def test_get_remote_name_no_remote(self, temp_git_repo):
        remote = get_remote_name(temp_git_repo)
        assert remote is None

    def test_branch_exists_true(self, temp_git_repo):
        # Create a branch
        subprocess.run(
            ['git', 'branch', 'test-exists'],
            cwd=temp_git_repo,
            capture_output=True,
            check=True
        )
        assert branch_exists(temp_git_repo, 'test-exists')

    def test_branch_exists_false(self, temp_git_repo):
        assert not branch_exists(temp_git_repo, 'nonexistent-branch')

    def test_remote_branch_exists_false_no_remote(self, temp_git_repo):
        assert not remote_branch_exists(temp_git_repo, 'some-branch')


# =============================================================================
# Tests for Branch Operations
# =============================================================================

class TestBranchOperations:
    """Test branch creation, checkout, push operations"""

    def test_create_review_branch(self, temp_git_repo):
        branch_name = create_review_branch(
            temp_git_repo, 'alice', 'q1-review'
        )
        assert branch_name == 'reviews/alice/q1-review'
        assert branch_exists(temp_git_repo, branch_name)

    def test_create_review_branch_already_exists_raises(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'alice', 'q1-review')
        with pytest.raises(ValueError, match="already exists"):
            create_review_branch(temp_git_repo, 'alice', 'q1-review')

    def test_checkout_review_branch(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'alice', 'q1')
        result = checkout_review_branch(temp_git_repo, 'alice', 'q1')
        assert result is True
        assert get_current_branch(temp_git_repo) == 'reviews/alice/q1'

    def test_checkout_review_branch_nonexistent(self, temp_git_repo):
        result = checkout_review_branch(temp_git_repo, 'alice', 'nonexistent')
        assert result is False

    def test_push_review_branch(self, temp_git_repo_with_remote):
        # Create and checkout review branch
        create_review_branch(temp_git_repo_with_remote, 'alice', 'q1')
        checkout_review_branch(temp_git_repo_with_remote, 'alice', 'q1')

        # Make a commit
        (temp_git_repo_with_remote / 'test.txt').write_text('test')
        subprocess.run(
            ['git', 'add', 'test.txt'],
            cwd=temp_git_repo_with_remote,
            capture_output=True,
            check=True
        )
        subprocess.run(
            ['git', 'commit', '-m', 'Test commit'],
            cwd=temp_git_repo_with_remote,
            capture_output=True,
            check=True
        )

        # Push
        result = push_review_branch(temp_git_repo_with_remote, 'alice', 'q1')
        assert result is True

    def test_push_review_branch_no_remote(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'alice', 'q1')
        result = push_review_branch(temp_git_repo, 'alice', 'q1')
        assert result is False

    def test_fetch_review_branches(self, temp_git_repo_with_remote):
        # Just verify it doesn't error on valid repo
        result = fetch_review_branches(temp_git_repo_with_remote)
        assert result is True

    def test_fetch_review_branches_no_remote(self, temp_git_repo):
        result = fetch_review_branches(temp_git_repo)
        assert result is False


# =============================================================================
# Tests for Listing and Discovery
# =============================================================================

class TestListingAndDiscovery:
    """Test branch listing operations"""

    def test_list_local_review_branches_empty(self, temp_git_repo):
        branches = list_local_review_branches(temp_git_repo)
        assert branches == []

    def test_list_local_review_branches(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'alice', 'q1')
        create_review_branch(temp_git_repo, 'bob', 'sprint-23')
        create_review_branch(temp_git_repo, 'alice', 'q2')

        branches = list_local_review_branches(temp_git_repo)
        assert len(branches) == 3
        assert 'reviews/alice/q1' in branches
        assert 'reviews/bob/sprint-23' in branches

    def test_list_local_review_branches_filters_non_review(self, temp_git_repo):
        # Create a non-review branch
        subprocess.run(
            ['git', 'branch', 'feature/something'],
            cwd=temp_git_repo,
            capture_output=True,
            check=True
        )
        create_review_branch(temp_git_repo, 'alice', 'q1')

        branches = list_local_review_branches(temp_git_repo)
        assert len(branches) == 1
        assert 'feature/something' not in branches

    def test_list_local_review_branches_for_user(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'alice', 'q1')
        create_review_branch(temp_git_repo, 'bob', 'sprint-23')
        create_review_branch(temp_git_repo, 'alice', 'q2')

        branches = list_local_review_branches(temp_git_repo, user='alice')
        assert len(branches) == 2
        assert 'reviews/alice/q1' in branches
        assert 'reviews/alice/q2' in branches

    def test_list_remote_review_branches(self, temp_git_repo_with_remote):
        # Create and push a review branch
        create_review_branch(temp_git_repo_with_remote, 'alice', 'q1')
        checkout_review_branch(temp_git_repo_with_remote, 'alice', 'q1')
        (temp_git_repo_with_remote / 'test.txt').write_text('test')
        subprocess.run(
            ['git', 'add', 'test.txt'],
            cwd=temp_git_repo_with_remote,
            capture_output=True,
            check=True
        )
        subprocess.run(
            ['git', 'commit', '-m', 'Test'],
            cwd=temp_git_repo_with_remote,
            capture_output=True,
            check=True
        )
        push_review_branch(temp_git_repo_with_remote, 'alice', 'q1')
        fetch_review_branches(temp_git_repo_with_remote)

        branches = list_remote_review_branches(temp_git_repo_with_remote)
        assert 'origin/reviews/alice/q1' in branches or 'reviews/alice/q1' in [b.replace('origin/', '') for b in branches]

    def test_list_all_review_users(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'alice', 'q1')
        create_review_branch(temp_git_repo, 'bob', 'sprint-23')
        create_review_branch(temp_git_repo, 'alice', 'q2')
        create_review_branch(temp_git_repo, 'charlie', 'review')

        users = list_all_review_users(temp_git_repo)
        assert set(users) == {'alice', 'bob', 'charlie'}


# =============================================================================
# Tests for Cleanup
# =============================================================================

class TestCleanup:
    """Test branch cleanup operations"""

    def test_delete_local_review_branch(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'alice', 'q1')
        assert branch_exists(temp_git_repo, 'reviews/alice/q1')

        result = delete_local_review_branch(temp_git_repo, 'alice', 'q1')
        assert result is True
        assert not branch_exists(temp_git_repo, 'reviews/alice/q1')

    def test_delete_local_review_branch_nonexistent(self, temp_git_repo):
        result = delete_local_review_branch(temp_git_repo, 'alice', 'nonexistent')
        assert result is False

    def test_delete_local_review_branch_current_fails(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'alice', 'q1')
        checkout_review_branch(temp_git_repo, 'alice', 'q1')

        # Should fail because we're on the branch
        result = delete_local_review_branch(temp_git_repo, 'alice', 'q1')
        assert result is False

    def test_delete_remote_review_branch(self, temp_git_repo_with_remote):
        # Create and push
        create_review_branch(temp_git_repo_with_remote, 'alice', 'q1')
        checkout_review_branch(temp_git_repo_with_remote, 'alice', 'q1')
        (temp_git_repo_with_remote / 'test.txt').write_text('test')
        subprocess.run(
            ['git', 'add', 'test.txt'],
            cwd=temp_git_repo_with_remote,
            capture_output=True,
            check=True
        )
        subprocess.run(
            ['git', 'commit', '-m', 'Test'],
            cwd=temp_git_repo_with_remote,
            capture_output=True,
            check=True
        )
        push_review_branch(temp_git_repo_with_remote, 'alice', 'q1')

        # Checkout main first
        subprocess.run(
            ['git', 'checkout', 'main'],
            cwd=temp_git_repo_with_remote,
            capture_output=True
        )
        subprocess.run(
            ['git', 'checkout', 'master'],
            cwd=temp_git_repo_with_remote,
            capture_output=True
        )

        # Delete remote
        result = delete_remote_review_branch(temp_git_repo_with_remote, 'alice', 'q1')
        assert result is True


# =============================================================================
# Tests for Conflict Detection
# =============================================================================

class TestConflictDetection:
    """Test conflict detection utilities"""

    def test_has_uncommitted_changes_clean(self, temp_git_repo):
        assert has_uncommitted_changes(temp_git_repo) is False

    def test_has_uncommitted_changes_modified(self, temp_git_repo):
        (temp_git_repo / 'README.md').write_text('Modified!')
        assert has_uncommitted_changes(temp_git_repo) is True

    def test_has_uncommitted_changes_staged(self, temp_git_repo):
        (temp_git_repo / 'new.txt').write_text('New file')
        subprocess.run(
            ['git', 'add', 'new.txt'],
            cwd=temp_git_repo,
            capture_output=True,
            check=True
        )
        assert has_uncommitted_changes(temp_git_repo) is True

    def test_check_review_branch_conflicts_clean(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'alice', 'q1')

        conflicts = check_review_branch_conflicts(temp_git_repo, 'alice', 'q1')
        assert conflicts == []

    def test_check_review_branch_conflicts_uncommitted(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'alice', 'q1')
        (temp_git_repo / 'README.md').write_text('Modified!')

        conflicts = check_review_branch_conflicts(temp_git_repo, 'alice', 'q1')
        assert 'uncommitted changes' in conflicts[0].lower()


# =============================================================================
# Tests for Error Handling
# =============================================================================

class TestErrorHandling:
    """Test error handling in edge cases"""

    def test_operations_on_invalid_repo(self):
        """Test that operations fail gracefully on invalid repo"""
        fake_path = Path('/nonexistent/path')

        # These should not raise, but return appropriate error values
        assert get_current_branch(fake_path) is None
        assert not branch_exists(fake_path, 'test')
        assert list_local_review_branches(fake_path) == []
