#!/usr/bin/env python3
"""
Tests for review_cli.py - CLI Interface Module

TDD tests written before implementation.
"""

import json
import os
import pytest
import subprocess
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

from tools.spec_review.review_cli import (
    # Main CLI
    main,
    create_parser,
    # Command handlers
    cmd_init_session,
    cmd_list_sessions,
    cmd_delete_session,
    cmd_flag,
    cmd_unflag,
    cmd_comment,
    cmd_reply,
    cmd_resolve,
    cmd_unresolve,
    cmd_request_status,
    cmd_approve,
    cmd_reject,
    cmd_list_threads,
    cmd_list_requests,
    cmd_create_branch,
    cmd_checkout_branch,
    cmd_push,
    cmd_fetch,
    cmd_list_branches,
)


@pytest.fixture
def temp_repo():
    """Create a temporary directory with git repo as mock repo root"""
    with tempfile.TemporaryDirectory() as tmpdir:
        repo = Path(tmpdir)
        # Initialize git repo
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
        yield repo


# =============================================================================
# Tests for Parser
# =============================================================================

class TestParser:
    """Test argument parser configuration"""

    def test_parser_has_subcommands(self):
        parser = create_parser()
        # Should not raise when parsed with subcommand
        args = parser.parse_args(['init-session', '--user', 'alice', '--name', 'Q1'])
        assert args.command == 'init-session'

    def test_init_session_args(self):
        parser = create_parser()
        args = parser.parse_args([
            'init-session',
            '--user', 'alice',
            '--name', 'Q1 Review',
            '--description', 'First quarter review'
        ])
        assert args.user == 'alice'
        assert args.name == 'Q1 Review'
        assert args.description == 'First quarter review'

    def test_flag_args(self):
        parser = create_parser()
        args = parser.parse_args([
            'flag', 'd00001',
            '--user', 'alice',
            '--reason', 'Needs review',
            '--scope', 'team'
        ])
        assert args.req_id == 'd00001'
        assert args.user == 'alice'
        assert args.reason == 'Needs review'

    def test_comment_args(self):
        parser = create_parser()
        args = parser.parse_args([
            'comment', 'd00001',
            '--user', 'alice',
            '--body', 'This needs clarification',
            '--line', '5',
            '--hash', 'abc12345'
        ])
        assert args.req_id == 'd00001'
        assert args.user == 'alice'
        assert args.body == 'This needs clarification'
        assert args.line == 5
        assert args.hash == 'abc12345'

    def test_reply_args(self):
        parser = create_parser()
        args = parser.parse_args([
            'reply', 'thread-uuid-123',
            '--user', 'bob',
            '--body', 'I agree',
            '--req', 'd00001'
        ])
        assert args.thread_id == 'thread-uuid-123'
        assert args.user == 'bob'
        assert args.body == 'I agree'

    def test_request_status_args(self):
        parser = create_parser()
        args = parser.parse_args([
            'request-status', 'd00001',
            '--user', 'alice',
            '--from', 'Draft',
            '--to', 'Active',
            '--justification', 'Ready for activation'
        ])
        assert args.req_id == 'd00001'
        assert args.from_status == 'Draft'  # 'from' is reserved, so we use from_status
        assert args.to == 'Active'

    def test_approve_args(self):
        parser = create_parser()
        args = parser.parse_args([
            'approve', 'request-uuid-123',
            '--user', 'bob',
            '--req', 'd00001',
            '--comment', 'LGTM'
        ])
        assert args.request_id == 'request-uuid-123'
        assert args.user == 'bob'

    def test_format_option(self):
        parser = create_parser()
        args = parser.parse_args([
            'list-threads', 'd00001',
            '--format', 'json'
        ])
        assert args.format == 'json'

    def test_repo_option(self):
        parser = create_parser()
        args = parser.parse_args([
            '--repo', '/path/to/repo',
            'list-sessions'
        ])
        assert args.repo == '/path/to/repo'


# =============================================================================
# Tests for Session Commands
# =============================================================================

class TestSessionCommands:
    """Test session management commands"""

    def test_init_session_creates_session(self, temp_repo, capsys):
        result = cmd_init_session(
            temp_repo, 'alice', 'Q1 Review', 'First quarter review'
        )
        assert result == 0
        captured = capsys.readouterr()
        assert 'Created session' in captured.out or 'session' in captured.out.lower()

    def test_list_sessions_empty(self, temp_repo, capsys):
        result = cmd_list_sessions(temp_repo, format='summary')
        assert result == 0
        captured = capsys.readouterr()
        assert 'No sessions' in captured.out or 'no session' in captured.out.lower()

    def test_list_sessions_shows_created(self, temp_repo, capsys):
        cmd_init_session(temp_repo, 'alice', 'Q1 Review', None)
        capsys.readouterr()  # Clear output

        result = cmd_list_sessions(temp_repo, format='summary')
        assert result == 0
        captured = capsys.readouterr()
        assert 'Q1 Review' in captured.out

    def test_list_sessions_json_format(self, temp_repo, capsys):
        cmd_init_session(temp_repo, 'alice', 'Q1 Review', None)
        capsys.readouterr()

        result = cmd_list_sessions(temp_repo, format='json')
        assert result == 0
        captured = capsys.readouterr()
        data = json.loads(captured.out)
        assert isinstance(data, list)
        assert len(data) == 1

    def test_delete_session(self, temp_repo, capsys):
        cmd_init_session(temp_repo, 'alice', 'Q1 Review', None)
        captured = capsys.readouterr()
        # Extract session ID from output
        # Assuming output contains "session_id: xxx" or similar
        # We need to list sessions to get the ID
        cmd_list_sessions(temp_repo, format='json')
        captured = capsys.readouterr()
        sessions = json.loads(captured.out)
        session_id = sessions[0]['sessionId']

        result = cmd_delete_session(temp_repo, session_id)
        assert result == 0


# =============================================================================
# Tests for Flag Commands
# =============================================================================

class TestFlagCommands:
    """Test review flag commands"""

    def test_flag_requirement(self, temp_repo, capsys):
        result = cmd_flag(
            temp_repo, 'd00001', 'alice', 'Needs review', ['team']
        )
        assert result == 0
        captured = capsys.readouterr()
        assert 'flagged' in captured.out.lower()

    def test_unflag_requirement(self, temp_repo, capsys):
        cmd_flag(temp_repo, 'd00001', 'alice', 'Needs review', ['team'])
        capsys.readouterr()

        result = cmd_unflag(temp_repo, 'd00001')
        assert result == 0
        captured = capsys.readouterr()
        assert 'cleared' in captured.out.lower() or 'unflagged' in captured.out.lower()


# =============================================================================
# Tests for Comment Commands
# =============================================================================

class TestCommentCommands:
    """Test comment/thread commands"""

    def test_comment_creates_thread(self, temp_repo, capsys):
        result = cmd_comment(
            temp_repo, 'd00001', 'alice', 'This needs clarification',
            hash_value='abc12345', line=5
        )
        assert result == 0
        captured = capsys.readouterr()
        assert 'thread' in captured.out.lower() or 'created' in captured.out.lower()

    def test_reply_to_thread(self, temp_repo, capsys):
        # First create a thread
        cmd_comment(
            temp_repo, 'd00001', 'alice', 'First comment',
            hash_value='abc12345', line=5
        )
        capsys.readouterr()

        # Get thread ID from listing
        cmd_list_threads(temp_repo, 'd00001', format='json')
        captured = capsys.readouterr()
        threads = json.loads(captured.out)
        thread_id = threads[0]['threadId']

        # Reply
        result = cmd_reply(temp_repo, 'd00001', thread_id, 'bob', 'I agree')
        assert result == 0

    def test_resolve_thread(self, temp_repo, capsys):
        # Create thread
        cmd_comment(
            temp_repo, 'd00001', 'alice', 'Question',
            hash_value='abc12345', line=5
        )
        capsys.readouterr()

        # Get thread ID
        cmd_list_threads(temp_repo, 'd00001', format='json')
        captured = capsys.readouterr()
        threads = json.loads(captured.out)
        thread_id = threads[0]['threadId']

        # Resolve
        result = cmd_resolve(temp_repo, 'd00001', thread_id, 'charlie')
        assert result == 0

    def test_unresolve_thread(self, temp_repo, capsys):
        # Create and resolve thread
        cmd_comment(
            temp_repo, 'd00001', 'alice', 'Question',
            hash_value='abc12345', line=5
        )
        capsys.readouterr()

        cmd_list_threads(temp_repo, 'd00001', format='json')
        captured = capsys.readouterr()
        threads = json.loads(captured.out)
        thread_id = threads[0]['threadId']

        cmd_resolve(temp_repo, 'd00001', thread_id, 'charlie')
        capsys.readouterr()

        # Unresolve
        result = cmd_unresolve(temp_repo, 'd00001', thread_id)
        assert result == 0

    def test_list_threads_empty(self, temp_repo, capsys):
        result = cmd_list_threads(temp_repo, 'd00001', format='summary')
        assert result == 0
        captured = capsys.readouterr()
        assert 'No threads' in captured.out or 'no thread' in captured.out.lower()

    def test_list_threads_json(self, temp_repo, capsys):
        cmd_comment(
            temp_repo, 'd00001', 'alice', 'Comment',
            hash_value='abc12345', line=5
        )
        capsys.readouterr()

        result = cmd_list_threads(temp_repo, 'd00001', format='json')
        assert result == 0
        captured = capsys.readouterr()
        data = json.loads(captured.out)
        assert isinstance(data, list)


# =============================================================================
# Tests for Status Request Commands
# =============================================================================

class TestStatusRequestCommands:
    """Test status request commands"""

    def test_request_status(self, temp_repo, capsys):
        result = cmd_request_status(
            temp_repo, 'd00001', 'alice', 'Draft', 'Active',
            'Ready for activation', required_approvers=['bob']
        )
        assert result == 0
        captured = capsys.readouterr()
        assert 'request' in captured.out.lower()

    def test_approve_request(self, temp_repo, capsys):
        # Create request
        cmd_request_status(
            temp_repo, 'd00001', 'alice', 'Draft', 'Active',
            'Ready', required_approvers=['bob']
        )
        capsys.readouterr()

        # Get request ID
        cmd_list_requests(temp_repo, 'd00001', format='json')
        captured = capsys.readouterr()
        requests = json.loads(captured.out)
        request_id = requests[0]['requestId']

        # Approve
        result = cmd_approve(temp_repo, 'd00001', request_id, 'bob', 'LGTM')
        assert result == 0

    def test_reject_request(self, temp_repo, capsys):
        # Create request
        cmd_request_status(
            temp_repo, 'd00001', 'alice', 'Draft', 'Active',
            'Ready', required_approvers=['bob']
        )
        capsys.readouterr()

        # Get request ID
        cmd_list_requests(temp_repo, 'd00001', format='json')
        captured = capsys.readouterr()
        requests = json.loads(captured.out)
        request_id = requests[0]['requestId']

        # Reject
        result = cmd_reject(temp_repo, 'd00001', request_id, 'bob', 'Not ready yet')
        assert result == 0

    def test_list_requests_empty(self, temp_repo, capsys):
        result = cmd_list_requests(temp_repo, 'd00001', format='summary')
        assert result == 0
        captured = capsys.readouterr()
        assert 'No requests' in captured.out or 'no request' in captured.out.lower()


# =============================================================================
# Tests for Branch Commands
# =============================================================================

class TestBranchCommands:
    """Test branch management commands"""

    def test_create_branch(self, temp_repo, capsys):
        result = cmd_create_branch(temp_repo, 'alice', 'q1-review')
        assert result == 0
        captured = capsys.readouterr()
        assert 'created' in captured.out.lower()

    def test_create_branch_already_exists(self, temp_repo, capsys):
        cmd_create_branch(temp_repo, 'alice', 'q1-review')
        capsys.readouterr()

        result = cmd_create_branch(temp_repo, 'alice', 'q1-review')
        assert result == 1
        captured = capsys.readouterr()
        assert 'already exists' in captured.out.lower() or 'error' in captured.out.lower()

    def test_checkout_branch(self, temp_repo, capsys):
        cmd_create_branch(temp_repo, 'alice', 'q1-review')
        capsys.readouterr()

        result = cmd_checkout_branch(temp_repo, 'alice', 'q1-review')
        assert result == 0

    def test_checkout_nonexistent_branch(self, temp_repo, capsys):
        result = cmd_checkout_branch(temp_repo, 'alice', 'nonexistent')
        assert result == 1

    def test_list_branches_empty(self, temp_repo, capsys):
        result = cmd_list_branches(temp_repo, format='summary')
        assert result == 0
        captured = capsys.readouterr()
        assert 'No review branches' in captured.out or 'no review' in captured.out.lower()

    def test_list_branches(self, temp_repo, capsys):
        cmd_create_branch(temp_repo, 'alice', 'q1')
        cmd_create_branch(temp_repo, 'bob', 'sprint')
        capsys.readouterr()

        result = cmd_list_branches(temp_repo, format='summary')
        assert result == 0
        captured = capsys.readouterr()
        assert 'alice' in captured.out
        assert 'bob' in captured.out

    def test_push_no_remote(self, temp_repo, capsys):
        cmd_create_branch(temp_repo, 'alice', 'q1')
        capsys.readouterr()

        result = cmd_push(temp_repo, 'alice', 'q1')
        assert result == 1  # No remote configured

    def test_fetch_no_remote(self, temp_repo, capsys):
        result = cmd_fetch(temp_repo)
        assert result == 1  # No remote configured


# =============================================================================
# Tests for Main Entry Point
# =============================================================================

class TestMain:
    """Test main entry point"""

    def test_main_no_args_shows_help(self, capsys):
        # When no command provided, main shows help and returns 0
        result = main([])
        assert result == 0
        captured = capsys.readouterr()
        assert 'usage' in captured.out.lower()

    def test_main_init_session(self, temp_repo, capsys):
        result = main([
            '--repo', str(temp_repo),
            'init-session',
            '--user', 'alice',
            '--name', 'Test'
        ])
        assert result == 0

    def test_main_flag(self, temp_repo, capsys):
        result = main([
            '--repo', str(temp_repo),
            'flag', 'd00001',
            '--user', 'alice',
            '--reason', 'Review needed'
        ])
        assert result == 0

    def test_main_comment(self, temp_repo, capsys):
        result = main([
            '--repo', str(temp_repo),
            'comment', 'd00001',
            '--user', 'alice',
            '--body', 'Question',
            '--hash', 'abc12345'
        ])
        assert result == 0
