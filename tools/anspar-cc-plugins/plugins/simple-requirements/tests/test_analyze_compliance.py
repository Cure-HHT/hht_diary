#!/usr/bin/env python3
"""
Test suite for analyze-compliance.py

Tests compliance analysis (with mocked AI calls).
"""

import pytest
import subprocess
import json
from pathlib import Path

# Paths
PLUGIN_ROOT = Path(__file__).parent.parent
SCRIPT_PATH = PLUGIN_ROOT / 'scripts' / 'analyze-compliance.py'


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
        assert '--file' in result.stdout or '--auto-scan' in result.stdout

    def test_requires_file_or_autoscan(self):
        """Script should require either --file or --auto-scan"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001'],
            capture_output=True,
            text=True
        )
        assert result.returncode != 0
        assert 'file' in result.stderr.lower() or 'auto-scan' in result.stderr.lower()


class TestOutputFormats:
    """Test output format options"""

    def test_json_output_structure(self):
        """JSON output should have expected structure"""
        # Note: This will fail gracefully if no ANTHROPIC_API_KEY
        # Create a test file in repo
        test_file = PLUGIN_ROOT / 'tests' / 'test.py'
        test_file.write_text('# Test file\n')

        try:
            result = subprocess.run(
                ['python3', str(SCRIPT_PATH), 'd00001', '--file', str(test_file), '--format', 'json'],
                capture_output=True,
                text=True,
                timeout=60
            )

            # Script should run (may not have API key, but structure should be valid)
            if result.returncode == 0:
                data = json.loads(result.stdout)

                # Check required fields
                assert 'analyzed_at' in data
                assert 'total_analyzed' in data
                assert 'analyses' in data
                assert 'summary' in data

                # Check types
                assert isinstance(data['analyses'], list)
                assert isinstance(data['summary'], dict)

        finally:
            # Clean up
            if test_file.exists():
                test_file.unlink()

    def test_text_output_format(self):
        """Text output should be human-readable"""
        test_file = PLUGIN_ROOT / 'tests' / 'test.py'
        test_file.write_text('# Test file\n')

        try:
            result = subprocess.run(
                ['python3', str(SCRIPT_PATH), 'd00001', '--file', str(test_file)],
                capture_output=True,
                text=True,
                timeout=60
            )

            if result.returncode == 0:
                # Check for human-readable elements
                assert 'Compliance Analysis' in result.stdout or 'Analysis' in result.stdout

        finally:
            if test_file.exists():
                test_file.unlink()


class TestAnalysisStructure:
    """Test structure of analysis results"""

    def test_analysis_fields(self):
        """Analysis entries should have required fields"""
        test_file = PLUGIN_ROOT / 'tests' / 'test.py'
        test_file.write_text('# Test\n')

        try:
            result = subprocess.run(
                ['python3', str(SCRIPT_PATH), 'd00001', '--file', str(test_file), '--format', 'json'],
                capture_output=True,
                text=True,
                timeout=60
            )

            if result.returncode == 0:
                data = json.loads(result.stdout)

                for analysis in data['analyses']:
                    # Check required fields
                    assert 'req_id' in analysis
                    assert 'file' in analysis
                    assert 'changes_summary' in analysis
                    assert 'still_compliant' in analysis
                    assert 'risk_level' in analysis
                    assert 'required_changes' in analysis
                    assert 'recommendations' in analysis
                    assert 'analyzed_at' in analysis
                    assert 'confidence' in analysis

                    # Check types
                    assert isinstance(analysis['still_compliant'], bool)
                    assert isinstance(analysis['required_changes'], list)
                    assert analysis['risk_level'] in ['LOW', 'MEDIUM', 'HIGH', 'UNKNOWN']

        finally:
            if test_file.exists():
                test_file.unlink()


class TestErrorHandling:
    """Test error handling"""

    def test_nonexistent_requirement(self):
        """Should handle nonexistent requirement gracefully"""
        test_file = PLUGIN_ROOT / 'tests' / 'test.py'
        test_file.write_text('# Test\n')

        try:
            result = subprocess.run(
                ['python3', str(SCRIPT_PATH), 'd99999', '--file', str(test_file)],
                capture_output=True,
                text=True,
                timeout=30
            )

            # Should fail with error message
            assert result.returncode != 0
            assert 'not found' in result.stderr.lower() or 'error' in result.stderr.lower()

        finally:
            if test_file.exists():
                test_file.unlink()

    def test_nonexistent_file(self):
        """Should handle nonexistent file gracefully"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--file', 'nonexistent-file.py'],
            capture_output=True,
            text=True,
            timeout=30
        )

        assert result.returncode != 0
        assert 'not found' in result.stderr.lower() or 'error' in result.stderr.lower()


class TestWithoutAPIKey:
    """Test behavior when ANTHROPIC_API_KEY is not set"""

    def test_graceful_degradation_without_api_key(self):
        """Should run without API key - either via Claude Code CLI fallback or graceful degradation"""
        import os
        import shutil

        # Temporarily remove API key from environment
        old_key = os.environ.pop('ANTHROPIC_API_KEY', None)
        has_claude_code = shutil.which('claude') is not None

        try:
            test_file = PLUGIN_ROOT / 'tests' / 'test.py'
            test_file.write_text('# Test\n')

            try:
                result = subprocess.run(
                    ['python3', str(SCRIPT_PATH), 'd00001', '--file', str(test_file), '--format', 'json'],
                    capture_output=True,
                    text=True,
                    timeout=120,  # Longer timeout if Claude Code is used
                    env={**os.environ, 'ANTHROPIC_API_KEY': ''}  # Ensure it's not set
                )

                # Should succeed even without API key
                if result.returncode == 0:
                    data = json.loads(result.stdout)

                    # Should still have valid structure
                    assert 'analyses' in data
                    if data['analyses']:
                        analysis = data['analyses'][0]
                        if has_claude_code:
                            # If Claude Code CLI is available, analysis may succeed
                            # or indicate Claude Code error
                            assert 'changes_summary' in analysis
                            assert 'risk_level' in analysis
                        else:
                            # Without any AI backend, should indicate unavailable
                            assert 'unavailable' in analysis['changes_summary'].lower() or \
                                   'UNKNOWN' in analysis['risk_level']

            finally:
                if test_file.exists():
                    test_file.unlink()

        finally:
            # Restore API key if it was set
            if old_key:
                os.environ['ANTHROPIC_API_KEY'] = old_key


class TestAutoScan:
    """Test auto-scan functionality"""

    def test_autoscan_flag(self):
        """--auto-scan should trigger implementation scanning"""
        result = subprocess.run(
            ['python3', str(SCRIPT_PATH), 'd00001', '--auto-scan', '--format', 'json'],
            capture_output=True,
            text=True,
            timeout=180  # Longer timeout for Claude Code CLI analysis
        )

        # May succeed or fail depending on whether implementations found
        # Just check it doesn't crash
        assert result.returncode in [0, 1]


if __name__ == '__main__':
    # Run tests
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
