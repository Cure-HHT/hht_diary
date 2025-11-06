#!/usr/bin/env python3
"""
Test suite for get-requirement.py script

Tests requirement fetching, formatting, and error handling.
"""

import pytest
import subprocess
import json
from pathlib import Path

# Paths
PLUGIN_ROOT = Path(__file__).parent.parent
SCRIPT_PATH = PLUGIN_ROOT / 'scripts' / 'get-requirement.py'


class TestGetRequirement:
    """Test get-requirement.py script functionality"""

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
        assert 'req_id' in result.stdout.lower()
        assert '--format' in result.stdout

    def test_fetch_requirement_short_id(self):
        """Should fetch requirement by short ID (d00001)"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Script failed: {result.stderr}"

        # Parse JSON output
        data = json.loads(result.stdout)
        assert data['id'] == 'd00001'
        assert data['full_id'] == 'REQ-d00001'
        assert 'title' in data
        assert 'body' in data
        assert 'hash' in data
        assert 'level' in data

    def test_fetch_requirement_full_id(self):
        """Should fetch requirement by full ID (REQ-d00001)"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'REQ-d00001', '--format', 'json'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        data = json.loads(result.stdout)
        assert data['id'] == 'd00001'

    def test_markdown_format(self):
        """Should output markdown format by default"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Check for markdown elements
        assert '###' in result.stdout  # Header
        assert 'REQ-d00001' in result.stdout
        assert '**Level**:' in result.stdout
        assert '**Hash**:' in result.stdout

    def test_json_format(self):
        """Should output valid JSON when --format json"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

        # Should be valid JSON
        data = json.loads(result.stdout)
        assert isinstance(data, dict)
        assert 'id' in data
        assert 'title' in data

    def test_nonexistent_requirement(self):
        """Should handle nonexistent requirement gracefully"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd99999'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 1, "Should exit with error code"
        assert 'not found' in result.stderr.lower()

    def test_case_insensitive(self):
        """Should handle case-insensitive requirement IDs"""
        # Test with uppercase
        result1 = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'D00001', '--format', 'json'],
            capture_output=True,
            text=True
        )
        # Test with lowercase
        result2 = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json'],
            capture_output=True,
            text=True
        )

        assert result1.returncode == 0
        assert result2.returncode == 0

        data1 = json.loads(result1.stdout)
        data2 = json.loads(result2.stdout)

        assert data1['id'] == data2['id']

    def test_requirement_metadata_completeness(self):
        """Fetched requirement should have all expected metadata"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

        data = json.loads(result.stdout)

        # Check all expected fields
        required_fields = ['id', 'full_id', 'title', 'level', 'implements',
                          'status', 'hash', 'body', 'source']
        for field in required_fields:
            assert field in data, f"Missing field: {field}"

        # Check source has file and line
        assert 'file' in data['source']
        assert 'line' in data['source']

    def test_hash_format(self):
        """Hash should be 8-character hex string"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

        data = json.loads(result.stdout)
        hash_value = data['hash']

        assert len(hash_value) == 8, "Hash should be 8 characters"
        assert all(c in '0123456789abcdef' for c in hash_value), "Hash should be hex"


class TestNormalization:
    """Test requirement ID normalization"""

    def test_req_prefix_removed(self):
        """REQ- prefix should be normalized"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'REQ-d00001', '--format', 'json'],
            capture_output=True,
            text=True
        )
        data = json.loads(result.stdout)
        assert data['id'] == 'd00001'  # No REQ- prefix in ID field

    def test_full_id_includes_prefix(self):
        """full_id field should include REQ- prefix"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json'],
            capture_output=True,
            text=True
        )
        data = json.loads(result.stdout)
        assert data['full_id'] == 'REQ-d00001'


if __name__ == '__main__':
    # Run tests with pytest if available, otherwise basic execution
    try:
        import pytest
        pytest.main([__file__, '-v'])
    except ImportError:
        print("pytest not available, running basic tests...")
        test_instance = TestGetRequirement()
        for method_name in dir(test_instance):
            if method_name.startswith('test_'):
                print(f"\nRunning {method_name}...")
                try:
                    getattr(test_instance, method_name)()
                    print(f"  ✅ PASSED")
                except Exception as e:
                    print(f"  ❌ FAILED: {e}")
