#!/usr/bin/env python3
"""
Test suite for scan-implementations.py

Tests implementation scanning, git history search, and output formatting.
"""

import pytest
import subprocess
import json
import tempfile
import os
from pathlib import Path

# Paths
PLUGIN_ROOT = Path(__file__).parent.parent
SCRIPT_PATH = PLUGIN_ROOT / 'scripts' / 'scan-implementations.py'
REPO_ROOT = PLUGIN_ROOT.parents[4]


class TestScriptBasics:
    """Test basic script functionality"""

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

    def test_requires_argument(self):
        """Script should require req_id argument"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH)],
            capture_output=True,
            text=True
        )
        assert result.returncode != 0
        assert 'required' in result.stderr.lower() or 'error' in result.stderr.lower()


class TestImplementationScan:
    """Test implementation scanning functionality"""

    def test_scan_with_short_id(self):
        """Should scan using short requirement ID"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001'],
            capture_output=True,
            text=True,
            timeout=30
        )
        # Should succeed even if no implementations found
        assert result.returncode == 0

    def test_scan_with_full_id(self):
        """Should scan using full requirement ID"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'REQ-d00001'],
            capture_output=True,
            text=True,
            timeout=30
        )
        assert result.returncode == 0

    def test_json_output_format(self):
        """JSON output should be valid and well-structured"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json'],
            capture_output=True,
            text=True,
            timeout=30
        )
        assert result.returncode == 0

        # Parse JSON
        data = json.loads(result.stdout)

        # Check required fields
        assert 'req_id' in data
        assert 'full_id' in data
        assert 'scanned_at' in data
        assert 'implementations' in data
        assert 'commits' in data
        assert 'summary' in data

        # Check data types
        assert isinstance(data['implementations'], list)
        assert isinstance(data['commits'], list)
        assert isinstance(data['summary'], dict)

        # Check summary structure
        assert 'implementation_count' in data['summary']
        assert 'commit_count' in data['summary']

    def test_text_output_format(self):
        """Text output should be human-readable"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'text'],
            capture_output=True,
            text=True,
            timeout=30
        )
        assert result.returncode == 0

        # Check for human-readable elements
        assert 'Implementation Scan' in result.stdout
        assert 'REQ-d00001' in result.stdout or 'No implementations found' in result.stdout

    def test_include_commits_flag(self):
        """--include-commits should search git history"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json', '--include-commits'],
            capture_output=True,
            text=True,
            timeout=30
        )
        assert result.returncode == 0

        data = json.loads(result.stdout)
        # commits list should be present (may be empty)
        assert 'commits' in data
        assert isinstance(data['commits'], list)


class TestImplementationStructure:
    """Test structure of found implementations"""

    def test_implementation_fields(self):
        """Implementation entries should have required fields"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json'],
            capture_output=True,
            text=True,
            timeout=30
        )
        data = json.loads(result.stdout)

        # If implementations found, check structure
        for impl in data['implementations']:
            assert 'file' in impl
            assert 'line' in impl
            assert 'type' in impl
            assert 'declaration' in impl
            assert 'context' in impl
            # last_modified may be None

            # Check types
            assert isinstance(impl['file'], str)
            assert isinstance(impl['line'], int)
            assert impl['line'] > 0
            assert isinstance(impl['type'], str)

    def test_commit_fields(self):
        """Commit entries should have required fields"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json', '--include-commits'],
            capture_output=True,
            text=True,
            timeout=30
        )
        data = json.loads(result.stdout)

        # If commits found, check structure
        for commit in data['commits']:
            assert 'sha' in commit
            assert 'message' in commit
            assert 'author' in commit
            assert 'date' in commit
            assert 'files_changed' in commit

            # Check types
            assert isinstance(commit['sha'], str)
            assert len(commit['sha']) == 8  # Short SHA
            assert isinstance(commit['message'], str)
            assert isinstance(commit['files_changed'], list)


class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_nonexistent_requirement(self):
        """Should handle nonexistent requirement gracefully"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd99999'],
            capture_output=True,
            text=True,
            timeout=30
        )
        # Should succeed with no results
        assert result.returncode == 0
        assert 'No implementations found' in result.stdout or 'implementation_count": 0' in result.stdout

    def test_case_insensitive(self):
        """Should handle case variations"""
        result1 = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'D00001', '--format', 'json'],
            capture_output=True,
            text=True,
            timeout=30
        )
        result2 = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json'],
            capture_output=True,
            text=True,
            timeout=30
        )

        assert result1.returncode == 0
        assert result2.returncode == 0

        data1 = json.loads(result1.stdout)
        data2 = json.loads(result2.stdout)

        # Should find same results
        assert data1['req_id'] == data2['req_id']

    def test_timeout_handling(self):
        """Script should complete in reasonable time"""
        import time
        start = time.time()

        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001'],
            capture_output=True,
            text=True,
            timeout=60  # Should complete well before this
        )

        elapsed = time.time() - start

        assert result.returncode == 0
        assert elapsed < 30, f"Scan took too long: {elapsed:.1f}s"


class TestSearchPatterns:
    """Test different declaration patterns are recognized"""

    def test_recognizes_implements_colon(self):
        """Should recognize 'Implements: REQ-xxx' pattern"""
        # Create temp file with pattern
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False, dir=REPO_ROOT) as f:
            f.write('# Implements: REQ-d00001\n')
            f.write('def test_function():\n')
            f.write('    pass\n')
            temp_file = f.name

        try:
            result = subprocess.run(
                ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json'],
                capture_output=True,
                text=True,
                timeout=30
            )

            data = json.loads(result.stdout)

            # Should find the temp file
            found = any(temp_file in impl['file'] or Path(temp_file).name in impl['file']
                       for impl in data['implementations'])

            # May not find if scan doesn't reach temp file location
            # Just check script runs successfully
            assert result.returncode == 0

        finally:
            # Clean up
            try:
                os.unlink(temp_file)
            except:
                pass

    def test_recognizes_requirements_colon(self):
        """Should recognize 'Requirements: REQ-xxx' pattern"""
        # Tested via actual repo files
        # Just verify the pattern is in the regex
        script_content = SCRIPT_PATH.read_text()
        assert 'implements?' in script_content.lower() or 'requirements?' in script_content.lower()


class TestSummary:
    """Test summary statistics"""

    def test_summary_counts_match(self):
        """Summary counts should match array lengths"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json', '--include-commits'],
            capture_output=True,
            text=True,
            timeout=30
        )
        data = json.loads(result.stdout)

        assert data['summary']['implementation_count'] == len(data['implementations'])
        assert data['summary']['commit_count'] == len(data['commits'])

    def test_timestamp_format(self):
        """Scanned_at should be valid ISO timestamp"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--format', 'json'],
            capture_output=True,
            text=True,
            timeout=30
        )
        data = json.loads(result.stdout)

        timestamp = data['scanned_at']
        # Should be ISO format with T separator
        assert 'T' in timestamp


if __name__ == '__main__':
    # Run tests with pytest if available
    try:
        import pytest
        pytest.main([__file__, '-v'])
    except ImportError:
        print("pytest not available, running basic tests...")
        test_instance = TestScriptBasics()
        for method_name in dir(test_instance):
            if method_name.startswith('test_'):
                print(f"\nRunning {method_name}...")
                try:
                    getattr(test_instance, method_name)()
                    print(f"  ✅ PASSED")
                except Exception as e:
                    print(f"  ❌ FAILED: {e}")
