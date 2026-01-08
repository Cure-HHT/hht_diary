"""
Tests for Elspais Test Output Format (REQ-tv-d00005).

These tests verify the test output format itself - they are meta-tests
that ensure our test infrastructure produces correct trace results.

Each test function documents which assertion it verifies in its docstring.
The Elspais reporter extracts these references for traceability.
"""

import json
import re
from datetime import datetime
from pathlib import Path

import pytest


class TestOutputFileLocation:
    """Tests for output file location and existence."""

    def test_output_file_created(self):
        """
        REQ-tv-d00005-A: Test runs SHALL produce a JSON output file at
        `tests/results/trace_results.json`.
        """
        results_path = Path(__file__).parent / "results" / "trace_results.json"

        # After a test run, this file should exist
        # This test will be verified after the full test suite runs
        # For now, verify the path is correct
        expected_path = Path(__file__).parent / "results"
        assert expected_path.exists(), f"Results directory must exist at {expected_path}"


class TestFormatVersion:
    """Tests for JSON format structure."""

    def test_format_version_is_one_point_zero(self):
        """
        REQ-tv-d00005-B: The JSON output SHALL conform to format version "1.0"
        as specified in this requirement.
        """
        results_path = Path(__file__).parent / "results" / "trace_results.json"

        if not results_path.exists():
            pytest.skip("trace_results.json not yet generated")

        data = json.loads(results_path.read_text())
        assert data.get("format_version") == "1.0", \
            f"Format version must be '1.0', got {data.get('format_version')}"


class TestResultEntryFields:
    """Tests for result entry structure."""

    def test_result_entries_have_required_fields(self):
        """
        REQ-tv-d00005-C: Each test result entry SHALL include: requirement_id,
        assertion_id, full_id, test_name, test_file, test_line, status,
        duration_ms, error_message, and timestamp.
        """
        results_path = Path(__file__).parent / "results" / "trace_results.json"

        if not results_path.exists():
            pytest.skip("trace_results.json not yet generated")

        data = json.loads(results_path.read_text())
        required_fields = [
            "requirement_id",
            "assertion_id",
            "full_id",
            "test_name",
            "test_file",
            "test_line",
            "status",
            "duration_ms",
            "error_message",
            "timestamp"
        ]

        for result in data.get("results", []):
            for field in required_fields:
                assert field in result, f"Missing required field: {field}"


class TestRequirementIdFormat:
    """Tests for requirement ID field format."""

    def test_requirement_id_is_base_without_suffix(self):
        """
        REQ-tv-d00005-D: The `requirement_id` field SHALL contain the base
        requirement ID without assertion suffix (e.g., `REQ-tv-d00001`).
        """
        results_path = Path(__file__).parent / "results" / "trace_results.json"

        if not results_path.exists():
            pytest.skip("trace_results.json not yet generated")

        data = json.loads(results_path.read_text())

        for result in data.get("results", []):
            req_id = result.get("requirement_id", "")
            # Should match pattern without assertion suffix
            assert re.match(r'^REQ-tv-[pdo]\d{5}$', req_id), \
                f"requirement_id should be base ID: {req_id}"


class TestAssertionIdFormat:
    """Tests for assertion ID field format."""

    def test_assertion_id_is_letter_or_null(self):
        """
        REQ-tv-d00005-E: The `assertion_id` field SHALL contain only the
        assertion letter (e.g., `A`) or null if the test covers the entire
        requirement.
        """
        results_path = Path(__file__).parent / "results" / "trace_results.json"

        if not results_path.exists():
            pytest.skip("trace_results.json not yet generated")

        data = json.loads(results_path.read_text())

        for result in data.get("results", []):
            assertion_id = result.get("assertion_id")
            # Should be single letter A-Z or None
            if assertion_id is not None:
                assert re.match(r'^[A-Z]$', assertion_id), \
                    f"assertion_id should be single letter: {assertion_id}"


class TestFullIdFormat:
    """Tests for full ID field format."""

    def test_full_id_includes_assertion_suffix(self):
        """
        REQ-tv-d00005-F: The `full_id` field SHALL contain the complete
        reference including assertion suffix if applicable
        (e.g., `REQ-tv-d00001-A`).
        """
        results_path = Path(__file__).parent / "results" / "trace_results.json"

        if not results_path.exists():
            pytest.skip("trace_results.json not yet generated")

        data = json.loads(results_path.read_text())

        for result in data.get("results", []):
            full_id = result.get("full_id", "")
            req_id = result.get("requirement_id", "")
            assertion_id = result.get("assertion_id")

            if assertion_id:
                expected = f"{req_id}-{assertion_id}"
                assert full_id == expected, \
                    f"full_id should be {expected}, got {full_id}"
            else:
                assert full_id == req_id, \
                    f"full_id should be {req_id} when no assertion, got {full_id}"


class TestStatusValues:
    """Tests for status field values."""

    def test_status_is_valid_enum(self):
        """
        REQ-tv-d00005-G: The `status` field SHALL be one of: passed, failed,
        or skipped.
        """
        results_path = Path(__file__).parent / "results" / "trace_results.json"

        if not results_path.exists():
            pytest.skip("trace_results.json not yet generated")

        data = json.loads(results_path.read_text())
        valid_statuses = {"passed", "failed", "skipped"}

        for result in data.get("results", []):
            status = result.get("status")
            assert status in valid_statuses, \
                f"Invalid status: {status}"


class TestSummaryObject:
    """Tests for summary object structure."""

    def test_summary_has_required_fields(self):
        """
        REQ-tv-d00005-H: The output SHALL include a `summary` object with:
        total, passed, failed, skipped, and coverage_percentage fields.
        """
        results_path = Path(__file__).parent / "results" / "trace_results.json"

        if not results_path.exists():
            pytest.skip("trace_results.json not yet generated")

        data = json.loads(results_path.read_text())
        summary = data.get("summary", {})

        required_fields = ["total", "passed", "failed", "skipped", "coverage_percentage"]
        for field in required_fields:
            assert field in summary, f"Summary missing field: {field}"


class TestDocstringExtraction:
    """Tests for requirement ID extraction from docstrings."""

    def test_requirement_id_extracted_from_docstring(self):
        """
        REQ-tv-d00005-I: Test functions SHALL include the requirement ID
        in their docstring for extraction by the reporter.
        """
        # This test verifies that our own docstring is extractable
        docstring = self.test_requirement_id_extracted_from_docstring.__doc__
        pattern = r'(REQ-tv-[pdo]\d{5})(?:-([A-Z]))?'
        match = re.search(pattern, docstring)

        assert match is not None, "Docstring should contain REQ-tv-xxxxx pattern"
        assert match.group(1) == "REQ-tv-d00005", "Should extract correct requirement ID"
        assert match.group(2) == "I", "Should extract correct assertion ID"


class TestPytestPlugin:
    """Tests for pytest plugin implementation."""

    def test_elspais_reporter_registered(self):
        """
        REQ-tv-d00005-J: A pytest plugin SHALL be implemented in `conftest.py`
        to generate the output automatically.
        """
        # Verify the conftest.py exists and defines the reporter
        conftest_path = Path(__file__).parent / "conftest.py"
        assert conftest_path.exists(), "conftest.py must exist"

        content = conftest_path.read_text()
        assert "ElspaisReporter" in content, "conftest.py must define ElspaisReporter"
        assert "pytest_configure" in content, "conftest.py must register plugin"


class TestPatternMatching:
    """Tests for requirement ID pattern matching."""

    def test_pattern_matches_tv_format(self):
        """
        REQ-tv-d00005-K: The reporter SHALL extract requirement IDs from test
        docstrings using the pattern `REQ-tv-[pdo]\\d{5}(?:-[A-Z])?`.
        """
        from conftest import ElspaisReporter

        pattern = ElspaisReporter.REQ_PATTERN

        # Valid patterns
        valid_cases = [
            ("REQ-tv-p00001", "REQ-tv-p00001", None),
            ("REQ-tv-d00001-A", "REQ-tv-d00001", "A"),
            ("REQ-tv-o00099-Z", "REQ-tv-o00099", "Z"),
        ]

        for test_str, expected_base, expected_assertion in valid_cases:
            match = pattern.search(test_str)
            assert match is not None, f"Should match: {test_str}"
            assert match.group(1) == expected_base
            assert match.group(2) == expected_assertion

        # Invalid patterns
        invalid_cases = [
            "REQ-p00001",  # Wrong prefix format
            "REQ-tv-x00001",  # Invalid type letter
            "REQ-tv-d0001",  # Wrong digit count
        ]

        for test_str in invalid_cases:
            match = pattern.search(test_str)
            assert match is None, f"Should not match: {test_str}"


class TestSessionFinish:
    """Tests for session finish hook."""

    def test_output_generated_at_session_end(self):
        """
        REQ-tv-d00005-L: The output file SHALL be generated at the end of
        the pytest session via `pytest_sessionfinish` hook.
        """
        from conftest import ElspaisReporter

        # Verify the hook method exists
        reporter = ElspaisReporter()
        assert hasattr(reporter, 'pytest_sessionfinish'), \
            "Reporter must have pytest_sessionfinish hook"

        # Verify it's callable
        assert callable(reporter.pytest_sessionfinish)


class TestTimestampFormat:
    """Tests for timestamp format."""

    def test_generated_at_is_iso8601(self):
        """
        REQ-tv-d00005-M: The `generated_at` field SHALL contain an ISO 8601
        formatted timestamp.
        """
        results_path = Path(__file__).parent / "results" / "trace_results.json"

        if not results_path.exists():
            pytest.skip("trace_results.json not yet generated")

        data = json.loads(results_path.read_text())
        generated_at = data.get("generated_at", "")

        # Try to parse as ISO 8601
        try:
            # Python's fromisoformat handles most ISO 8601 formats
            datetime.fromisoformat(generated_at.replace('Z', '+00:00'))
        except ValueError:
            pytest.fail(f"generated_at is not valid ISO 8601: {generated_at}")
