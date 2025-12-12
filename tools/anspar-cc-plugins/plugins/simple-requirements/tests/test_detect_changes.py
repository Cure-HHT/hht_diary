#!/usr/bin/env python3
"""
Test suite for detect-changes.py script

Tests requirement change detection by comparing current state with INDEX.md.
"""

import pytest
import subprocess
import json
from pathlib import Path

# Paths
PLUGIN_ROOT = Path(__file__).parent.parent
SCRIPT_PATH = PLUGIN_ROOT / 'scripts' / 'detect-changes.py'


def get_repo_root() -> Path:
    """Get repo root using git (same approach as the scripts use)."""
    import subprocess
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True,
            text=True,
            check=True
        )
        return Path(result.stdout.strip())
    except subprocess.CalledProcessError:
        # Fallback to relative path traversal
        return PLUGIN_ROOT.parents[4]


REPO_ROOT = get_repo_root()
INDEX_PATH = REPO_ROOT / 'spec' / 'INDEX.md'


class TestDetectChanges:
    """Test detect-changes.py script functionality"""

    def test_script_exists(self):
        """Script file should exist and be executable"""
        assert SCRIPT_PATH.exists(), f"Script not found: {SCRIPT_PATH}"
        assert SCRIPT_PATH.stat().st_mode & 0o111, "Script not executable"

    def test_help_output(self):
        """Help flag should show usage information"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--help'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert 'usage:' in result.stdout.lower()
        assert '--format' in result.stdout

    def test_json_output_structure(self):
        """JSON output should have expected structure"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--format', 'json'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

        data = json.loads(result.stdout)

        # Check required fields
        assert 'timestamp' in data
        assert 'changed_requirements' in data
        assert 'new_requirements' in data
        assert 'missing_from_index' in data
        assert 'summary' in data

        # Check summary structure
        summary = data['summary']
        assert 'changed_count' in summary
        assert 'new_count' in summary
        assert 'missing_count' in summary

    def test_summary_output_readable(self):
        """Summary output should be human-readable"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--format', 'summary'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

        # Check for human-readable elements
        assert 'Requirement Change Detection' in result.stdout
        assert '=' in result.stdout  # Header separator

    def test_json_is_valid(self):
        """JSON output must be valid JSON"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--format', 'json'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

        # Should parse without error
        data = json.loads(result.stdout)
        assert isinstance(data, dict)

    def test_change_entry_structure(self):
        """Changed requirement entries should have required fields"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--format', 'json'],
            capture_output=True,
            text=True
        )
        data = json.loads(result.stdout)

        # Check structure even if no changes (use expected structure)
        # If there are changed requirements, validate their structure
        for changed in data['changed_requirements']:
            assert 'req_id' in changed
            assert 'old_hash' in changed
            assert 'new_hash' in changed
            assert 'file' in changed
            assert 'title' in changed

    def test_new_requirement_structure(self):
        """New requirement entries should have required fields"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--format', 'json'],
            capture_output=True,
            text=True
        )
        data = json.loads(result.stdout)

        # If there are new requirements, validate their structure
        for new_req in data['new_requirements']:
            assert 'req_id' in new_req
            assert 'file' in new_req
            assert 'title' in new_req
            assert 'hash' in new_req
            assert 'reason' in new_req
            assert new_req['reason'] == 'hash_tbd'

    def test_counts_match_arrays(self):
        """Summary counts should match array lengths"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--format', 'json'],
            capture_output=True,
            text=True
        )
        data = json.loads(result.stdout)

        summary = data['summary']
        assert summary['changed_count'] == len(data['changed_requirements'])
        assert summary['new_count'] == len(data['new_requirements'])
        assert summary['missing_count'] == len(data['missing_from_index'])

    def test_default_format_is_json(self):
        """Default output format should be JSON"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH)],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

        # Should be valid JSON
        data = json.loads(result.stdout)
        assert isinstance(data, dict)

    def test_index_md_exists(self):
        """INDEX.md should exist for comparison"""
        assert INDEX_PATH.exists(), f"INDEX.md not found: {INDEX_PATH}"

    def test_timestamp_format(self):
        """Timestamp should be in ISO format"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--format', 'json'],
            capture_output=True,
            text=True
        )
        data = json.loads(result.stdout)

        timestamp = data['timestamp']
        # Should contain ISO format indicators
        assert 'T' in timestamp
        assert '+' in timestamp or 'Z' in timestamp


class TestNoChangesScenario:
    """Test behavior when no requirements have changed"""

    def test_no_changes_json(self):
        """When no changes, all counts should be zero (if INDEX.md is up to date)"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--format', 'json'],
            capture_output=True,
            text=True
        )
        data = json.loads(result.stdout)

        # This test assumes INDEX.md is up to date
        # If counts are all zero, validate the structure
        summary = data['summary']
        if summary['changed_count'] == 0 and summary['new_count'] == 0:
            assert len(data['changed_requirements']) == 0
            assert len(data['new_requirements']) == 0

    def test_no_changes_summary(self):
        """Summary should indicate no changes when appropriate"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--format', 'summary'],
            capture_output=True,
            text=True
        )

        # Check for "no changes" message if applicable
        if 'No changes detected' in result.stdout:
            assert '✅' in result.stdout or 'All requirement hashes match' in result.stdout


class TestHashFormat:
    """Test hash format validation"""

    def test_hash_is_8_char_hex(self):
        """All hashes should be 8-character hex strings"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), '--format', 'json'],
            capture_output=True,
            text=True
        )
        data = json.loads(result.stdout)

        # Check changed requirements
        for changed in data['changed_requirements']:
            assert len(changed['old_hash']) == 8 or changed['old_hash'] == 'TBD'
            assert len(changed['new_hash']) == 8
            if changed['old_hash'] != 'TBD':
                assert all(c in '0123456789abcdef' for c in changed['old_hash'])
            assert all(c in '0123456789abcdef' for c in changed['new_hash'])

        # Check new requirements
        for new_req in data['new_requirements']:
            assert len(new_req['hash']) == 8
            assert all(c in '0123456789abcdef' for c in new_req['hash'])


if __name__ == '__main__':
    # Run tests with pytest if available
    try:
        import pytest
        pytest.main([__file__, '-v'])
    except ImportError:
        print("pytest not available, running basic tests...")
        test_instance = TestDetectChanges()
        for method_name in dir(test_instance):
            if method_name.startswith('test_'):
                print(f"\nRunning {method_name}...")
                try:
                    getattr(test_instance, method_name)()
                    print(f"  ✅ PASSED")
                except Exception as e:
                    print(f"  ❌ FAILED: {e}")
