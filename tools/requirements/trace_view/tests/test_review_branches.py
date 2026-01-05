#!/usr/bin/env python3
"""
Tests for review branches module.

Tests for git branch management operations in the review system.

IMPLEMENTS REQUIREMENTS:
    REQ-d00027: Workflow plugin state management
"""

import subprocess
from pathlib import Path
from typing import List, Optional
from unittest.mock import MagicMock, patch

import pytest


# =============================================================================
# Branch Naming Tests (Pure Functions)
# =============================================================================

class TestReviewBranchPrefix:
    """Tests for REVIEW_BRANCH_PREFIX constant. REQ-tv-d00012-A"""

    def test_prefix_is_reviews_slash(self):
        """Prefix should be 'reviews/'."""
        from trace_view.review.branches import REVIEW_BRANCH_PREFIX
        assert REVIEW_BRANCH_PREFIX == 'reviews/'


class TestSanitizeBranchName:
    """Tests for _sanitize_branch_name function. REQ-tv-d00012-B"""

    def test_replaces_spaces_with_hyphens(self):
        """Spaces should become hyphens."""
        from trace_view.review.branches import _sanitize_branch_name
        assert _sanitize_branch_name('hello world') == 'hello-world'

    def test_converts_to_lowercase(self):
        """Output should be lowercase."""
        from trace_view.review.branches import _sanitize_branch_name
        assert _sanitize_branch_name('HelloWorld') == 'helloworld'

    def test_removes_invalid_characters(self):
        """Invalid git branch characters should be removed."""
        from trace_view.review.branches import _sanitize_branch_name
        assert _sanitize_branch_name('hello@world!') == 'helloworld'

    def test_preserves_hyphens_and_underscores(self):
        """Hyphens and underscores are valid."""
        from trace_view.review.branches import _sanitize_branch_name
        assert _sanitize_branch_name('hello-world_test') == 'hello-world_test'

    def test_strips_leading_trailing_hyphens(self):
        """Leading/trailing hyphens should be removed."""
        from trace_view.review.branches import _sanitize_branch_name
        assert _sanitize_branch_name('-hello-') == 'hello'

    def test_handles_empty_string(self):
        """Empty string should return empty."""
        from trace_view.review.branches import _sanitize_branch_name
        assert _sanitize_branch_name('') == ''


class TestGetReviewBranchName:
    """Tests for get_review_branch_name function. REQ-tv-d00012-C"""

    def test_generates_correct_format(self):
        """Should generate reviews/{package}/{user}."""
        from trace_view.review.branches import get_review_branch_name
        result = get_review_branch_name('default', 'alice')
        assert result == 'reviews/default/alice'

    def test_sanitizes_package_id(self):
        """Package ID should be sanitized."""
        from trace_view.review.branches import get_review_branch_name
        result = get_review_branch_name('Q1 Review', 'alice')
        assert result == 'reviews/q1-review/alice'

    def test_sanitizes_username(self):
        """Username should be sanitized."""
        from trace_view.review.branches import get_review_branch_name
        result = get_review_branch_name('default', 'Alice Smith')
        assert result == 'reviews/default/alice-smith'

    def test_handles_complex_names(self):
        """Complex names with special chars."""
        from trace_view.review.branches import get_review_branch_name
        result = get_review_branch_name('Q1@2025!', 'bob.jones')
        assert result == 'reviews/q12025/bobjones'


class TestIsReviewBranch:
    """Tests for is_review_branch function. REQ-tv-d00012-D"""

    def test_valid_review_branch(self):
        """Valid format should return True."""
        from trace_view.review.branches import is_review_branch
        assert is_review_branch('reviews/default/alice') is True

    def test_valid_review_branch_with_hyphens(self):
        """Valid format with hyphens."""
        from trace_view.review.branches import is_review_branch
        assert is_review_branch('reviews/q1-review/bob-jones') is True

    def test_non_review_branch(self):
        """Non-review branch should return False."""
        from trace_view.review.branches import is_review_branch
        assert is_review_branch('main') is False
        assert is_review_branch('feature/foo') is False

    def test_missing_user(self):
        """Missing user component should return False."""
        from trace_view.review.branches import is_review_branch
        assert is_review_branch('reviews/default') is False

    def test_missing_package(self):
        """Missing package should return False."""
        from trace_view.review.branches import is_review_branch
        assert is_review_branch('reviews//alice') is False

    def test_empty_string(self):
        """Empty string should return False."""
        from trace_view.review.branches import is_review_branch
        assert is_review_branch('') is False


class TestParseReviewBranchName:
    """Tests for parse_review_branch_name function. REQ-tv-d00012-E"""

    def test_parses_valid_branch(self):
        """Should return (package, user) tuple."""
        from trace_view.review.branches import parse_review_branch_name
        result = parse_review_branch_name('reviews/default/alice')
        assert result == ('default', 'alice')

    def test_parses_complex_names(self):
        """Should handle complex package/user names."""
        from trace_view.review.branches import parse_review_branch_name
        result = parse_review_branch_name('reviews/q1-review/bob-jones')
        assert result == ('q1-review', 'bob-jones')

    def test_returns_none_for_non_review_branch(self):
        """Non-review branches return None."""
        from trace_view.review.branches import parse_review_branch_name
        assert parse_review_branch_name('main') is None
        assert parse_review_branch_name('feature/foo') is None

    def test_returns_none_for_invalid_format(self):
        """Invalid format returns None."""
        from trace_view.review.branches import parse_review_branch_name
        assert parse_review_branch_name('reviews/default') is None
        assert parse_review_branch_name('reviews//alice') is None


# =============================================================================
# Git Utilities Tests (Mocked)
# =============================================================================

class TestRunGit:
    """Tests for _run_git function. REQ-tv-d00012-F"""

    def test_runs_git_command(self, tmp_path, monkeypatch):
        """Should run git command with correct args."""
        from trace_view.review.branches import _run_git

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=['git', 'status'], returncode=0, stdout='', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = _run_git(tmp_path, ['status'])

        mock_run.assert_called_once()
        call_args = mock_run.call_args
        assert call_args[0][0] == ['git', 'status']
        assert result.returncode == 0

    def test_handles_git_not_found(self, tmp_path, monkeypatch):
        """Should handle git not being available."""
        from trace_view.review.branches import _run_git

        def raise_error(*args, **kwargs):
            raise FileNotFoundError("git not found")

        monkeypatch.setattr(subprocess, 'run', raise_error)

        result = _run_git(tmp_path, ['status'])
        assert result.returncode == 1


class TestGetCurrentBranch:
    """Tests for get_current_branch function. REQ-tv-d00012-G"""

    def test_returns_branch_name(self, tmp_path, monkeypatch):
        """Should return current branch name."""
        from trace_view.review.branches import get_current_branch

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout='main\n', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = get_current_branch(tmp_path)
        assert result == 'main'

    def test_returns_none_on_error(self, tmp_path, monkeypatch):
        """Should return None if not in git repo."""
        from trace_view.review.branches import get_current_branch

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=1, stdout='', stderr='not a git repo'
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = get_current_branch(tmp_path)
        assert result is None


class TestBranchExists:
    """Tests for branch_exists function. REQ-tv-d00012-H"""

    def test_returns_true_if_exists(self, tmp_path, monkeypatch):
        """Should return True if branch exists."""
        from trace_view.review.branches import branch_exists

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout='abc123', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = branch_exists(tmp_path, 'reviews/default/alice')
        assert result is True

    def test_returns_false_if_not_exists(self, tmp_path, monkeypatch):
        """Should return False if branch doesn't exist."""
        from trace_view.review.branches import branch_exists

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=1, stdout='', stderr='not found'
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = branch_exists(tmp_path, 'reviews/default/alice')
        assert result is False


class TestHasUncommittedChanges:
    """Tests for has_uncommitted_changes function. REQ-tv-d00012-I"""

    def test_returns_true_with_changes(self, tmp_path, monkeypatch):
        """Should return True if there are uncommitted changes."""
        from trace_view.review.branches import has_uncommitted_changes

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout=' M file.txt\n', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = has_uncommitted_changes(tmp_path)
        assert result is True

    def test_returns_false_without_changes(self, tmp_path, monkeypatch):
        """Should return False if working tree is clean."""
        from trace_view.review.branches import has_uncommitted_changes

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout='', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = has_uncommitted_changes(tmp_path)
        assert result is False


class TestHasReviewsChanges:
    """Tests for has_reviews_changes function. REQ-tv-d00012-J"""

    def test_returns_true_with_reviews_changes(self, tmp_path, monkeypatch):
        """Should return True if .reviews/ has changes."""
        from trace_view.review.branches import has_reviews_changes

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout=' M .reviews/test.json\n', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = has_reviews_changes(tmp_path)
        assert result is True

    def test_returns_false_without_reviews_changes(self, tmp_path, monkeypatch):
        """Should return False if .reviews/ is clean."""
        from trace_view.review.branches import has_reviews_changes

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout='', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = has_reviews_changes(tmp_path)
        assert result is False


# =============================================================================
# Branch Operations Tests (Mocked)
# =============================================================================

class TestCreateReviewBranch:
    """Tests for create_review_branch function. REQ-tv-d00012-K"""

    def test_creates_branch(self, tmp_path, monkeypatch):
        """Should create and return branch name."""
        from trace_view.review.branches import create_review_branch

        call_count = [0]

        def mock_run(args, **kwargs):
            call_count[0] += 1
            if 'rev-parse' in args:  # branch_exists check
                return subprocess.CompletedProcess(
                    args=args, returncode=1, stdout='', stderr=''
                )
            elif 'branch' in args:  # create branch
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='', stderr=''
                )
            return subprocess.CompletedProcess(
                args=args, returncode=0, stdout='', stderr=''
            )

        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = create_review_branch(tmp_path, 'default', 'alice')
        assert result == 'reviews/default/alice'

    def test_raises_if_branch_exists(self, tmp_path, monkeypatch):
        """Should raise ValueError if branch already exists."""
        from trace_view.review.branches import create_review_branch

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout='abc123', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        with pytest.raises(ValueError, match="already exists"):
            create_review_branch(tmp_path, 'default', 'alice')


class TestCheckoutReviewBranch:
    """Tests for checkout_review_branch function. REQ-tv-d00012-L"""

    def test_checkout_existing_branch(self, tmp_path, monkeypatch):
        """Should checkout existing branch."""
        from trace_view.review.branches import checkout_review_branch

        def mock_run(args, **kwargs):
            if 'rev-parse' in args:  # branch_exists
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='abc123', stderr=''
                )
            elif 'checkout' in args:
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='', stderr=''
                )
            return subprocess.CompletedProcess(
                args=args, returncode=0, stdout='', stderr=''
            )

        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = checkout_review_branch(tmp_path, 'default', 'alice')
        assert result is True

    def test_returns_false_if_branch_not_exists(self, tmp_path, monkeypatch):
        """Should return False if branch doesn't exist."""
        from trace_view.review.branches import checkout_review_branch

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=1, stdout='', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = checkout_review_branch(tmp_path, 'default', 'alice')
        assert result is False


class TestListLocalReviewBranches:
    """Tests for list_local_review_branches function. REQ-tv-d00012-M"""

    def test_lists_all_review_branches(self, tmp_path, monkeypatch):
        """Should list all local review branches."""
        from trace_view.review.branches import list_local_review_branches

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout='  reviews/default/alice\n* reviews/default/bob\n  reviews/q1/carol\n',
            stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = list_local_review_branches(tmp_path)
        assert 'reviews/default/alice' in result
        assert 'reviews/default/bob' in result
        assert 'reviews/q1/carol' in result

    def test_filters_by_user(self, tmp_path, monkeypatch):
        """Should filter by username if provided."""
        from trace_view.review.branches import list_local_review_branches

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout='  reviews/default/alice\n  reviews/q1/alice\n  reviews/default/bob\n',
            stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = list_local_review_branches(tmp_path, user='alice')
        assert 'reviews/default/alice' in result
        assert 'reviews/q1/alice' in result
        assert 'reviews/default/bob' not in result

    def test_returns_empty_on_error(self, tmp_path, monkeypatch):
        """Should return empty list on git error."""
        from trace_view.review.branches import list_local_review_branches

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=1, stdout='', stderr='error'
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = list_local_review_branches(tmp_path)
        assert result == []


class TestListPackageBranches:
    """Tests for list_package_branches function. REQ-tv-d00012-N"""

    def test_lists_branches_for_package(self, tmp_path, monkeypatch):
        """Should list all branches for a specific package."""
        from trace_view.review.branches import list_package_branches

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout='  reviews/default/alice\n  reviews/default/bob\n',
            stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = list_package_branches(tmp_path, 'default')
        assert 'reviews/default/alice' in result
        assert 'reviews/default/bob' in result


class TestListUserBranches:
    """Tests for list_user_branches function. REQ-tv-d00012-O"""

    def test_lists_branches_for_user(self, tmp_path, monkeypatch):
        """Should list all branches for a specific user."""
        from trace_view.review.branches import list_user_branches

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout='  reviews/default/alice\n  reviews/q1/alice\n  reviews/default/bob\n',
            stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = list_user_branches(tmp_path, 'alice')
        assert 'reviews/default/alice' in result
        assert 'reviews/q1/alice' in result
        assert 'reviews/default/bob' not in result


# =============================================================================
# Auto-Sync Operations Tests
# =============================================================================

class TestCommitReviews:
    """Tests for commit_reviews function. REQ-tv-d00012-P"""

    def test_commits_when_changes_exist(self, tmp_path, monkeypatch):
        """Should commit when .reviews/ has changes."""
        from trace_view.review.branches import commit_reviews

        def mock_run(args, **kwargs):
            if '--porcelain' in args:  # has_reviews_changes
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout=' M .reviews/test.json\n', stderr=''
                )
            return subprocess.CompletedProcess(
                args=args, returncode=0, stdout='', stderr=''
            )

        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = commit_reviews(tmp_path, 'Test commit', 'alice')
        assert result is True

    def test_returns_true_when_no_changes(self, tmp_path, monkeypatch):
        """Should return True when no changes to commit."""
        from trace_view.review.branches import commit_reviews

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout='', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = commit_reviews(tmp_path, 'Test commit', 'alice')
        assert result is True


class TestCommitAndPushReviews:
    """Tests for commit_and_push_reviews function. REQ-tv-d00012-Q"""

    def test_returns_success_dict_when_no_changes(self, tmp_path, monkeypatch):
        """Should return success when no changes."""
        from trace_view.review.branches import commit_and_push_reviews

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout='', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = commit_and_push_reviews(tmp_path, 'Test', 'alice')
        assert result['success'] is True
        assert result['committed'] is False
        assert result['pushed'] is False

    def test_commits_and_pushes_on_changes(self, tmp_path, monkeypatch):
        """Should commit and push when changes exist."""
        from trace_view.review.branches import commit_and_push_reviews

        call_sequence = []

        def mock_run(args, **kwargs):
            call_sequence.append(args)
            if '--porcelain' in args:  # has_reviews_changes
                if len([c for c in call_sequence if '--porcelain' in c]) == 1:
                    return subprocess.CompletedProcess(
                        args=args, returncode=0, stdout=' M .reviews/test.json\n', stderr=''
                    )
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='', stderr=''
                )
            elif 'rev-parse' in args and '--abbrev-ref' in args:  # get_current_branch
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='reviews/default/alice\n', stderr=''
                )
            return subprocess.CompletedProcess(
                args=args, returncode=0, stdout='', stderr=''
            )

        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = commit_and_push_reviews(tmp_path, 'Test', 'alice')
        assert result['success'] is True
        assert result['committed'] is True


class TestGetSyncStatus:
    """Tests for get_sync_status function. REQ-tv-d00012-R"""

    def test_returns_status_dict(self, tmp_path, monkeypatch):
        """Should return status dictionary."""
        from trace_view.review.branches import get_sync_status

        def mock_run(args, **kwargs):
            if '--porcelain' in args:
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='', stderr=''
                )
            elif 'rev-parse' in args and '--abbrev-ref' in args:
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='main\n', stderr=''
                )
            elif 'rev-parse' in args and '--verify' in args:
                return subprocess.CompletedProcess(
                    args=args, returncode=1, stdout='', stderr=''
                )
            return subprocess.CompletedProcess(
                args=args, returncode=0, stdout='', stderr=''
            )

        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = get_sync_status(tmp_path)
        assert 'has_local_changes' in result
        assert 'ahead' in result
        assert 'behind' in result
        assert 'branch' in result
        assert result['branch'] == 'main'


# =============================================================================
# Context Manager Tests
# =============================================================================

class TestTemporaryBranchSwitch:
    """Tests for temporary_branch_switch context manager. REQ-tv-d00012-S"""

    def test_yields_true_when_already_on_branch(self, tmp_path, monkeypatch):
        """Should yield True when already on target branch."""
        from trace_view.review.branches import temporary_branch_switch

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout='reviews/default/alice\n', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        with temporary_branch_switch(tmp_path, 'reviews/default/alice') as switched:
            assert switched is True

    def test_switches_back_after_context(self, tmp_path, monkeypatch):
        """Should switch back to original branch after context."""
        from trace_view.review.branches import temporary_branch_switch

        calls = []

        def mock_run(args, **kwargs):
            calls.append(args)
            if 'rev-parse' in args and '--abbrev-ref' in args:
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='main\n', stderr=''
                )
            return subprocess.CompletedProcess(
                args=args, returncode=0, stdout='', stderr=''
            )

        monkeypatch.setattr(subprocess, 'run', mock_run)

        with temporary_branch_switch(tmp_path, 'reviews/default/alice') as switched:
            assert switched is True

        # Check that checkout was called twice (to target, then back)
        checkout_calls = [c for c in calls if 'checkout' in c]
        assert len(checkout_calls) == 2


class TestGetCurrentPackageContext:
    """Tests for get_current_package_context function. REQ-tv-d00012-T"""

    def test_returns_package_and_user_on_review_branch(self, tmp_path, monkeypatch):
        """Should return (package, user) when on review branch."""
        from trace_view.review.branches import get_current_package_context

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout='reviews/q1-review/alice\n', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = get_current_package_context(tmp_path)
        assert result == ('q1-review', 'alice')

    def test_returns_none_on_non_review_branch(self, tmp_path, monkeypatch):
        """Should return None when not on review branch."""
        from trace_view.review.branches import get_current_package_context

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=0, stdout='main\n', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = get_current_package_context(tmp_path)
        assert result is None


# =============================================================================
# Cleanup Operations Tests
# =============================================================================

class TestDeleteLocalReviewBranch:
    """Tests for delete_local_review_branch function. REQ-tv-d00012-U"""

    def test_deletes_existing_branch(self, tmp_path, monkeypatch):
        """Should delete existing branch."""
        from trace_view.review.branches import delete_local_review_branch

        def mock_run(args, **kwargs):
            if 'rev-parse' in args and '--verify' in args:  # branch_exists
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='abc123', stderr=''
                )
            elif 'rev-parse' in args and '--abbrev-ref' in args:  # get_current_branch
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='main\n', stderr=''
                )
            elif 'branch' in args and '-d' in args:  # delete
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='', stderr=''
                )
            return subprocess.CompletedProcess(
                args=args, returncode=0, stdout='', stderr=''
            )

        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = delete_local_review_branch(tmp_path, 'default', 'alice')
        assert result is True

    def test_returns_false_if_branch_not_exists(self, tmp_path, monkeypatch):
        """Should return False if branch doesn't exist."""
        from trace_view.review.branches import delete_local_review_branch

        mock_run = MagicMock(return_value=subprocess.CompletedProcess(
            args=[], returncode=1, stdout='', stderr=''
        ))
        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = delete_local_review_branch(tmp_path, 'default', 'alice')
        assert result is False

    def test_returns_false_if_current_branch(self, tmp_path, monkeypatch):
        """Should return False if trying to delete current branch."""
        from trace_view.review.branches import delete_local_review_branch

        def mock_run(args, **kwargs):
            if 'rev-parse' in args and '--verify' in args:  # branch_exists
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='abc123', stderr=''
                )
            elif 'rev-parse' in args and '--abbrev-ref' in args:  # get_current_branch
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='reviews/default/alice\n', stderr=''
                )
            return subprocess.CompletedProcess(
                args=args, returncode=0, stdout='', stderr=''
            )

        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = delete_local_review_branch(tmp_path, 'default', 'alice')
        assert result is False


class TestListAllReviewUsers:
    """Tests for list_all_review_users function. REQ-tv-d00012-V"""

    def test_returns_unique_users(self, tmp_path, monkeypatch):
        """Should return unique usernames."""
        from trace_view.review.branches import list_all_review_users

        def mock_run(args, **kwargs):
            if '-r' in args:  # remote branches
                return subprocess.CompletedProcess(
                    args=args, returncode=0, stdout='', stderr=''
                )
            return subprocess.CompletedProcess(
                args=args, returncode=0,
                stdout='  reviews/default/alice\n  reviews/q1/alice\n  reviews/default/bob\n',
                stderr=''
            )

        monkeypatch.setattr(subprocess, 'run', mock_run)

        result = list_all_review_users(tmp_path, include_remote=False)
        assert 'alice' in result
        assert 'bob' in result
        assert len(result) == 2  # Unique users only
