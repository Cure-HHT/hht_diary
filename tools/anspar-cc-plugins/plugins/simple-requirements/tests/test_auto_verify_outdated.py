#!/usr/bin/env python3
"""
Test suite for auto-verify-outdated.py script

Tests automatic verification of outdated requirements from commit messages.
"""

import pytest
import subprocess
import json
import tempfile
import os
from pathlib import Path
from unittest.mock import patch, MagicMock

# Paths
PLUGIN_ROOT = Path(__file__).parent.parent
SCRIPT_PATH = PLUGIN_ROOT / 'scripts' / 'auto-verify-outdated.py'

# Import the module for unit testing
import sys
sys.path.insert(0, str(PLUGIN_ROOT / 'scripts'))
import importlib.util
spec = importlib.util.spec_from_file_location("auto_verify_outdated", SCRIPT_PATH)
auto_verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auto_verify)


def get_repo_root() -> Path:
    """Get repo root using git."""
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True,
            text=True,
            check=True
        )
        return Path(result.stdout.strip())
    except subprocess.CalledProcessError:
        return PLUGIN_ROOT.parents[4]


REPO_ROOT = get_repo_root()


class TestExtractReqIds:
    """Test REQ ID extraction from commit messages"""

    def test_single_req(self):
        """Should extract a single REQ reference"""
        msg = "[CUR-123] Add feature\n\nImplements: REQ-d00027"
        result = auto_verify.extract_req_ids(msg)
        assert result == ['d00027']

    def test_multiple_reqs(self):
        """Should extract multiple REQ references"""
        msg = "[CUR-123] Add feature\n\nImplements: REQ-d00027, REQ-p00042"
        result = auto_verify.extract_req_ids(msg)
        assert sorted(result) == ['d00027', 'p00042']

    def test_case_insensitive(self):
        """Should handle uppercase REQ references"""
        msg = "Implements: REQ-D00027"
        result = auto_verify.extract_req_ids(msg)
        assert result == ['d00027']

    def test_no_reqs(self):
        """Should return empty list when no REQs present"""
        msg = "[CUR-123] Simple commit message"
        result = auto_verify.extract_req_ids(msg)
        assert result == []

    def test_invalid_req_format(self):
        """Should not match invalid REQ formats"""
        # x is not a valid type (only p, o, d)
        # 4 digits is too few
        msg = "REQ-x00027 REQ-d0027 REQ-12345"
        result = auto_verify.extract_req_ids(msg)
        assert result == []

    def test_all_req_types(self):
        """Should match all REQ types (p, o, d)"""
        msg = "REQ-p00001 REQ-o00002 REQ-d00003"
        result = auto_verify.extract_req_ids(msg)
        assert sorted(result) == ['d00003', 'o00002', 'p00001']


class TestFindOutdatedReqs:
    """Test matching REQs against outdated tracking"""

    def test_finds_matching_req(self):
        """Should find REQ that's in outdated list"""
        req_ids = ['d00027']
        tracking_data = {
            'outdated_requirements': [
                {'req_id': 'd00027', 'title': 'Test requirement'}
            ]
        }
        result = auto_verify.find_outdated_reqs(req_ids, tracking_data)
        assert len(result) == 1
        assert result[0]['req_id'] == 'd00027'

    def test_no_match(self):
        """Should return empty when no REQs match"""
        req_ids = ['d00027']
        tracking_data = {
            'outdated_requirements': [
                {'req_id': 'd00099', 'title': 'Different requirement'}
            ]
        }
        result = auto_verify.find_outdated_reqs(req_ids, tracking_data)
        assert result == []

    def test_partial_match(self):
        """Should only return matching REQs"""
        req_ids = ['d00027', 'd00028']
        tracking_data = {
            'outdated_requirements': [
                {'req_id': 'd00027', 'title': 'Test 1'},
                {'req_id': 'd00099', 'title': 'Test 2'}
            ]
        }
        result = auto_verify.find_outdated_reqs(req_ids, tracking_data)
        assert len(result) == 1
        assert result[0]['req_id'] == 'd00027'

    def test_empty_tracking(self):
        """Should handle empty tracking data"""
        req_ids = ['d00027']
        result = auto_verify.find_outdated_reqs(req_ids, {})
        assert result == []

    def test_none_tracking(self):
        """Should handle None tracking data"""
        req_ids = ['d00027']
        result = auto_verify.find_outdated_reqs(req_ids, None)
        assert result == []


class TestGetAutoVerifySetting:
    """Test auto-verify setting detection"""

    def test_env_var_1(self):
        """Should detect AUTO_VERIFY_REQ=1"""
        with patch.dict(os.environ, {'AUTO_VERIFY_REQ': '1'}):
            assert auto_verify.get_auto_verify_setting() is True

    def test_env_var_true(self):
        """Should detect AUTO_VERIFY_REQ=true"""
        with patch.dict(os.environ, {'AUTO_VERIFY_REQ': 'true'}):
            assert auto_verify.get_auto_verify_setting() is True

    def test_env_var_yes(self):
        """Should detect AUTO_VERIFY_REQ=yes"""
        with patch.dict(os.environ, {'AUTO_VERIFY_REQ': 'yes'}):
            assert auto_verify.get_auto_verify_setting() is True

    def test_env_var_false(self):
        """Should return False for AUTO_VERIFY_REQ=0"""
        with patch.dict(os.environ, {'AUTO_VERIFY_REQ': '0'}, clear=True):
            # Mock git config to return nothing
            with patch('subprocess.run') as mock_run:
                mock_run.return_value = MagicMock(returncode=1, stdout='')
                assert auto_verify.get_auto_verify_setting() is False

    def test_no_env_var(self):
        """Should return False when env var not set"""
        env = os.environ.copy()
        env.pop('AUTO_VERIFY_REQ', None)
        with patch.dict(os.environ, env, clear=True):
            with patch('subprocess.run') as mock_run:
                mock_run.return_value = MagicMock(returncode=1, stdout='')
                assert auto_verify.get_auto_verify_setting() is False


class TestScriptIntegration:
    """Integration tests for the script"""

    def test_script_exists(self):
        """Script file should exist"""
        assert SCRIPT_PATH.exists(), f"Script not found: {SCRIPT_PATH}"

    def test_help_output(self):
        """Help should show usage information"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--help'],
            capture_output=True,
            text=True
        )
        # argparse exits with 0 for --help
        assert result.returncode == 0
        assert 'usage:' in result.stdout.lower() or 'COMMIT-MSG-FILE' in result.stdout

    def test_missing_file_arg(self):
        """Should error when commit message file not provided"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH)],
            capture_output=True,
            text=True
        )
        # argparse exits with 2 for missing required arguments
        assert result.returncode == 2
        assert 'required' in result.stderr.lower() or 'COMMIT-MSG-FILE' in result.stderr

    def test_nonexistent_file(self):
        """Should error when commit message file doesn't exist"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '/nonexistent/file.txt'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 2

    def test_commit_msg_no_reqs(self):
        """Should exit 0 when no REQs in commit message"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write("[CUR-123] Simple commit without REQ\n")
            f.flush()
            try:
                result = subprocess.run(
                    ['python3', str(SCRIPT_PATH), f.name],
                    capture_output=True,
                    text=True,
                    cwd=REPO_ROOT
                )
                assert result.returncode == 0
            finally:
                os.unlink(f.name)

    def test_commit_msg_with_req_no_tracking(self):
        """Should exit 0 when REQ is present but no tracking file"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write("[CUR-123] Add feature\n\nImplements: REQ-d99999\n")
            f.flush()
            try:
                result = subprocess.run(
                    ['python3', str(SCRIPT_PATH), f.name],
                    capture_output=True,
                    text=True,
                    cwd=REPO_ROOT
                )
                # Should succeed - REQ not in outdated list
                assert result.returncode == 0
            finally:
                os.unlink(f.name)


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
