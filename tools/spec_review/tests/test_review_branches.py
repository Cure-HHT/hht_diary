#!/usr/bin/env python3
"""
Tests for review_branches.py - Git Branch Management Module

TDD tests written before implementation.

Branch naming convention: reviews/{package}/{user}
- package: Review package ID (e.g., 'default', 'q1-2025-review')
- user: Username (e.g., 'alice', 'bob')
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
    # Package-aware discovery (Module 19)
    list_package_branches,
    list_user_branches,
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
# Tests for Branch Naming (Module 19: reviews/{package}/{user})
# =============================================================================

class TestBranchNaming:
    """Test branch name generation and parsing for reviews/{package}/{user}"""

    def test_get_review_branch_name(self):
        """Branch format: reviews/{package_id}/{user}"""
        name = get_review_branch_name('q1-review', 'alice')
        assert name == 'reviews/q1-review/alice'

    def test_get_review_branch_name_default_package(self):
        """Default package branch"""
        name = get_review_branch_name('default', 'bob')
        assert name == 'reviews/default/bob'

    def test_get_review_branch_name_sanitizes_spaces(self):
        """Package names with spaces are sanitized"""
        name = get_review_branch_name('Q1 Review Session', 'alice')
        assert ' ' not in name
        assert name.endswith('/alice')
        assert name.startswith('reviews/')

    def test_get_review_branch_name_sanitizes_special_chars(self):
        """Special characters are removed from package name"""
        name = get_review_branch_name('review@#$%', 'alice')
        # Should only contain valid git branch chars
        assert all(c.isalnum() or c in '-_/' for c in name)

    def test_get_review_branch_name_sanitizes_username(self):
        """Username is also sanitized"""
        name = get_review_branch_name('default', 'alice@company.com')
        assert '@' not in name
        assert name.startswith('reviews/default/')

    def test_parse_review_branch_name(self):
        """Parse returns (package_id, user) tuple"""
        result = parse_review_branch_name('reviews/q1-review/alice')
        assert result == ('q1-review', 'alice')

    def test_parse_review_branch_name_default(self):
        """Parse default package branch"""
        result = parse_review_branch_name('reviews/default/bob')
        assert result == ('default', 'bob')

    def test_parse_review_branch_name_invalid(self):
        result = parse_review_branch_name('main')
        assert result is None

    def test_parse_review_branch_name_wrong_prefix(self):
        result = parse_review_branch_name('feature/alice/something')
        assert result is None

    def test_is_review_branch_valid(self):
        """Valid review branches: reviews/{package}/{user}"""
        assert is_review_branch('reviews/default/alice')
        assert is_review_branch('reviews/q1-review/bob')
        assert is_review_branch('reviews/sprint-23/charlie')

    def test_is_review_branch_invalid(self):
        assert not is_review_branch('main')
        assert not is_review_branch('feature/new-thing')
        assert not is_review_branch('reviews')  # Incomplete
        assert not is_review_branch('reviews/default')  # Missing user


# =============================================================================
# Tests for Package-Aware Discovery (Module 19)
# =============================================================================

class TestPackageAwareDiscovery:
    """Test package-based branch discovery functions"""

    def test_list_package_branches_empty(self, temp_git_repo):
        """No branches for a package that doesn't exist"""
        branches = list_package_branches(temp_git_repo, 'nonexistent')
        assert branches == []

    def test_list_package_branches(self, temp_git_repo):
        """List all branches for a specific package"""
        # Create branches for different packages
        create_review_branch(temp_git_repo, 'q1-review', 'alice')
        create_review_branch(temp_git_repo, 'q1-review', 'bob')
        create_review_branch(temp_git_repo, 'q2-review', 'alice')

        # List branches for q1-review package
        branches = list_package_branches(temp_git_repo, 'q1-review')
        assert len(branches) == 2
        assert 'reviews/q1-review/alice' in branches
        assert 'reviews/q1-review/bob' in branches
        assert 'reviews/q2-review/alice' not in branches

    def test_list_user_branches_empty(self, temp_git_repo):
        """No branches for a user that doesn't exist"""
        branches = list_user_branches(temp_git_repo, 'nonexistent')
        assert branches == []

    def test_list_user_branches(self, temp_git_repo):
        """List all branches for a specific user across packages"""
        # Create branches for different users/packages
        create_review_branch(temp_git_repo, 'q1-review', 'alice')
        create_review_branch(temp_git_repo, 'q2-review', 'alice')
        create_review_branch(temp_git_repo, 'default', 'alice')
        create_review_branch(temp_git_repo, 'q1-review', 'bob')

        # List branches for alice
        branches = list_user_branches(temp_git_repo, 'alice')
        assert len(branches) == 3
        assert 'reviews/q1-review/alice' in branches
        assert 'reviews/q2-review/alice' in branches
        assert 'reviews/default/alice' in branches
        assert 'reviews/q1-review/bob' not in branches

    def test_list_package_branches_extracts_users(self, temp_git_repo):
        """Verify we can extract all users for a package"""
        create_review_branch(temp_git_repo, 'default', 'alice')
        create_review_branch(temp_git_repo, 'default', 'bob')
        create_review_branch(temp_git_repo, 'default', 'charlie')

        branches = list_package_branches(temp_git_repo, 'default')
        users = [parse_review_branch_name(b)[1] for b in branches]
        assert set(users) == {'alice', 'bob', 'charlie'}


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
        """Create branch with new convention: reviews/{package}/{user}"""
        branch_name = create_review_branch(
            temp_git_repo, 'q1-review', 'alice'
        )
        assert branch_name == 'reviews/q1-review/alice'
        assert branch_exists(temp_git_repo, branch_name)

    def test_create_review_branch_default_package(self, temp_git_repo):
        """Create branch for default package"""
        branch_name = create_review_branch(temp_git_repo, 'default', 'bob')
        assert branch_name == 'reviews/default/bob'
        assert branch_exists(temp_git_repo, branch_name)

    def test_create_review_branch_already_exists_raises(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'q1-review', 'alice')
        with pytest.raises(ValueError, match="already exists"):
            create_review_branch(temp_git_repo, 'q1-review', 'alice')

    def test_checkout_review_branch(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'q1', 'alice')
        result = checkout_review_branch(temp_git_repo, 'q1', 'alice')
        assert result is True
        assert get_current_branch(temp_git_repo) == 'reviews/q1/alice'

    def test_checkout_review_branch_nonexistent(self, temp_git_repo):
        result = checkout_review_branch(temp_git_repo, 'nonexistent', 'alice')
        assert result is False

    def test_push_review_branch(self, temp_git_repo_with_remote):
        # Create and checkout review branch
        create_review_branch(temp_git_repo_with_remote, 'q1', 'alice')
        checkout_review_branch(temp_git_repo_with_remote, 'q1', 'alice')

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
        result = push_review_branch(temp_git_repo_with_remote, 'q1', 'alice')
        assert result is True

    def test_push_review_branch_no_remote(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'q1', 'alice')
        result = push_review_branch(temp_git_repo, 'q1', 'alice')
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
        """List branches with new naming: reviews/{package}/{user}"""
        create_review_branch(temp_git_repo, 'q1', 'alice')
        create_review_branch(temp_git_repo, 'sprint-23', 'bob')
        create_review_branch(temp_git_repo, 'q2', 'alice')

        branches = list_local_review_branches(temp_git_repo)
        assert len(branches) == 3
        assert 'reviews/q1/alice' in branches
        assert 'reviews/sprint-23/bob' in branches

    def test_list_local_review_branches_filters_non_review(self, temp_git_repo):
        # Create a non-review branch
        subprocess.run(
            ['git', 'branch', 'feature/something'],
            cwd=temp_git_repo,
            capture_output=True,
            check=True
        )
        create_review_branch(temp_git_repo, 'q1', 'alice')

        branches = list_local_review_branches(temp_git_repo)
        assert len(branches) == 1
        assert 'feature/something' not in branches

    def test_list_local_review_branches_for_user(self, temp_git_repo):
        """Filter by user still works with new convention"""
        create_review_branch(temp_git_repo, 'q1', 'alice')
        create_review_branch(temp_git_repo, 'sprint-23', 'bob')
        create_review_branch(temp_git_repo, 'q2', 'alice')

        branches = list_local_review_branches(temp_git_repo, user='alice')
        assert len(branches) == 2
        assert 'reviews/q1/alice' in branches
        assert 'reviews/q2/alice' in branches

    def test_list_remote_review_branches(self, temp_git_repo_with_remote):
        # Create and push a review branch
        create_review_branch(temp_git_repo_with_remote, 'q1', 'alice')
        checkout_review_branch(temp_git_repo_with_remote, 'q1', 'alice')
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
        push_review_branch(temp_git_repo_with_remote, 'q1', 'alice')
        fetch_review_branches(temp_git_repo_with_remote)

        branches = list_remote_review_branches(temp_git_repo_with_remote)
        assert 'origin/reviews/q1/alice' in branches or 'reviews/q1/alice' in [b.replace('origin/', '') for b in branches]

    def test_list_all_review_users(self, temp_git_repo):
        """List users extracts from second component now"""
        create_review_branch(temp_git_repo, 'q1', 'alice')
        create_review_branch(temp_git_repo, 'sprint-23', 'bob')
        create_review_branch(temp_git_repo, 'q2', 'alice')
        create_review_branch(temp_git_repo, 'review', 'charlie')

        users = list_all_review_users(temp_git_repo)
        assert set(users) == {'alice', 'bob', 'charlie'}


# =============================================================================
# Tests for Cleanup
# =============================================================================

class TestCleanup:
    """Test branch cleanup operations"""

    def test_delete_local_review_branch(self, temp_git_repo):
        """Delete with new convention: reviews/{package}/{user}"""
        create_review_branch(temp_git_repo, 'q1', 'alice')
        assert branch_exists(temp_git_repo, 'reviews/q1/alice')

        result = delete_local_review_branch(temp_git_repo, 'q1', 'alice')
        assert result is True
        assert not branch_exists(temp_git_repo, 'reviews/q1/alice')

    def test_delete_local_review_branch_nonexistent(self, temp_git_repo):
        result = delete_local_review_branch(temp_git_repo, 'nonexistent', 'alice')
        assert result is False

    def test_delete_local_review_branch_current_fails(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'q1', 'alice')
        checkout_review_branch(temp_git_repo, 'q1', 'alice')

        # Should fail because we're on the branch
        result = delete_local_review_branch(temp_git_repo, 'q1', 'alice')
        assert result is False

    def test_delete_remote_review_branch(self, temp_git_repo_with_remote):
        # Create and push
        create_review_branch(temp_git_repo_with_remote, 'q1', 'alice')
        checkout_review_branch(temp_git_repo_with_remote, 'q1', 'alice')
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
        push_review_branch(temp_git_repo_with_remote, 'q1', 'alice')

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
        result = delete_remote_review_branch(temp_git_repo_with_remote, 'q1', 'alice')
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
        """Conflict check with new convention: reviews/{package}/{user}"""
        create_review_branch(temp_git_repo, 'q1', 'alice')

        conflicts = check_review_branch_conflicts(temp_git_repo, 'q1', 'alice')
        assert conflicts == []

    def test_check_review_branch_conflicts_uncommitted(self, temp_git_repo):
        create_review_branch(temp_git_repo, 'q1', 'alice')
        (temp_git_repo / 'README.md').write_text('Modified!')

        conflicts = check_review_branch_conflicts(temp_git_repo, 'q1', 'alice')
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


# =============================================================================
# Tests for Package-Aware Branch Management (Module 20)
# =============================================================================

# Import the new functions for Module 20
from tools.spec_review.review_branches import (
    ensure_package_branch,
    switch_to_package_branch,
    get_current_package_context,
)


class TestPackageAwareBranchManagement:
    """Test package-aware branch management functions (Module 20)"""

    def test_ensure_package_branch_creates_new(self, temp_git_repo):
        """Create branch if it doesn't exist"""
        branch = ensure_package_branch(temp_git_repo, 'q1-review', 'alice')
        assert branch == 'reviews/q1-review/alice'
        assert branch_exists(temp_git_repo, branch)
        # Should also checkout the branch
        assert get_current_branch(temp_git_repo) == branch

    def test_ensure_package_branch_checks_out_existing(self, temp_git_repo):
        """Checkout existing branch"""
        # Create the branch first
        create_review_branch(temp_git_repo, 'q1-review', 'alice')
        # Now ensure - should just checkout
        branch = ensure_package_branch(temp_git_repo, 'q1-review', 'alice')
        assert branch == 'reviews/q1-review/alice'
        assert get_current_branch(temp_git_repo) == branch

    def test_switch_to_package_branch_creates_and_switches(self, temp_git_repo):
        """Switch creates branch if needed and changes to it"""
        result = switch_to_package_branch(temp_git_repo, 'default', 'bob')
        assert result is True
        assert get_current_branch(temp_git_repo) == 'reviews/default/bob'

    def test_switch_to_package_branch_existing(self, temp_git_repo):
        """Switch to existing branch"""
        create_review_branch(temp_git_repo, 'default', 'bob')
        result = switch_to_package_branch(temp_git_repo, 'default', 'bob')
        assert result is True
        assert get_current_branch(temp_git_repo) == 'reviews/default/bob'

    def test_switch_to_package_branch_stashes_uncommitted(self, temp_git_repo):
        """Stash uncommitted changes before switching"""
        # Create initial branch and make some changes
        create_review_branch(temp_git_repo, 'pkg1', 'alice')
        checkout_review_branch(temp_git_repo, 'pkg1', 'alice')
        # Modify an existing tracked file (README.md was created in fixture)
        original_content = (temp_git_repo / 'README.md').read_text()
        (temp_git_repo / 'README.md').write_text('Modified content for stash test')

        # Switch should stash changes
        result = switch_to_package_branch(temp_git_repo, 'pkg2', 'alice')
        assert result is True
        assert get_current_branch(temp_git_repo) == 'reviews/pkg2/alice'
        # The modified file should revert to original (since stashed)
        assert (temp_git_repo / 'README.md').read_text() == original_content

    def test_get_current_package_context_on_review_branch(self, temp_git_repo):
        """Get context when on a review branch"""
        create_review_branch(temp_git_repo, 'q1-review', 'alice')
        checkout_review_branch(temp_git_repo, 'q1-review', 'alice')

        context = get_current_package_context(temp_git_repo)
        assert context is not None
        assert context == ('q1-review', 'alice')

    def test_get_current_package_context_not_on_review_branch(self, temp_git_repo):
        """Returns None when not on a review branch"""
        context = get_current_package_context(temp_git_repo)
        assert context is None

    def test_get_current_package_context_on_main(self, temp_git_repo):
        """Returns None when on main branch"""
        # Should be on main/master by default
        context = get_current_package_context(temp_git_repo)
        assert context is None

    def test_switch_between_packages_same_user(self, temp_git_repo):
        """Switch between packages for same user"""
        # Create and work on first package
        switch_to_package_branch(temp_git_repo, 'pkg1', 'alice')
        assert get_current_package_context(temp_git_repo) == ('pkg1', 'alice')

        # Switch to second package
        switch_to_package_branch(temp_git_repo, 'pkg2', 'alice')
        assert get_current_package_context(temp_git_repo) == ('pkg2', 'alice')

    def test_ensure_package_branch_sanitizes_names(self, temp_git_repo):
        """Package and user names are sanitized"""
        branch = ensure_package_branch(temp_git_repo, 'Q1 Review', 'Alice@company.com')
        # Should sanitize to lowercase, remove special chars
        assert 'Q1' not in branch  # Should be lowercase
        assert '@' not in branch
        assert branch_exists(temp_git_repo, branch)
