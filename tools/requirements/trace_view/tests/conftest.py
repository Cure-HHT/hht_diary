"""
pytest configuration and fixtures for trace_view tests.

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00005: Elspais Test Output Format

This module provides:
- ElspaisReporter: pytest plugin that generates trace_results.json
- Common fixtures for testing the HTML generator refactoring
"""

import sys
from pathlib import Path as _Path

# Add trace_view package to Python path for imports
# tests/ -> trace_view/ -> requirements/
_tests_dir = _Path(__file__).resolve().parent
_requirements_dir = _tests_dir.parent.parent
if str(_requirements_dir) not in sys.path:
    sys.path.insert(0, str(_requirements_dir))
# Also add tests/ to allow importing conftest from test files
if str(_tests_dir) not in sys.path:
    sys.path.insert(0, str(_tests_dir))

import json
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import pytest


class ElspaisReporter:
    """
    Pytest plugin that generates trace_results.json for elspais integration.

    REQ-tv-d00005-A: Test runs SHALL produce a JSON output file at
                     `tests/results/trace_results.json`.
    REQ-tv-d00005-J: A pytest plugin SHALL be implemented in `conftest.py`
                     to generate the output automatically.
    """

    # Pattern to extract requirement IDs from docstrings
    # REQ-tv-d00005-K: The reporter SHALL extract requirement IDs from test
    #                  docstrings using the pattern `REQ-tv-[pdo]\d{5}(?:-[A-Z])?`
    REQ_PATTERN = re.compile(r'(REQ-tv-[pdo]\d{5})(?:-([A-Z]))?')

    def __init__(self):
        self.results = []
        self.start_time = None
        self.test_run_id = str(uuid.uuid4())[:8]
        self._item_docstrings = {}  # Cache docstrings from collection

    def pytest_sessionstart(self, session):
        """Record session start time."""
        self.start_time = datetime.now(timezone.utc)

    def pytest_collection_modifyitems(self, items):
        """Cache docstrings during collection phase."""
        for item in items:
            try:
                if hasattr(item, 'function') and item.function.__doc__:
                    self._item_docstrings[item.nodeid] = item.function.__doc__
            except (AttributeError, TypeError):
                pass

    def pytest_runtest_logreport(self, report):
        """
        Capture test results and extract requirement IDs.

        REQ-tv-d00005-C: Each test result entry SHALL include: requirement_id,
                         assertion_id, full_id, test_name, test_file, test_line,
                         status, duration_ms, error_message, and timestamp.
        """
        if report.when != 'call':
            return

        # Get test function docstring from cache
        docstring = self._item_docstrings.get(report.nodeid)
        if not docstring:
            return

        # Extract requirement ID from docstring
        # REQ-tv-d00005-I: Test functions SHALL include the requirement ID
        #                  in their docstring for extraction by the reporter.
        match = self.REQ_PATTERN.search(docstring)
        if not match:
            return

        base_req_id = match.group(1)
        assertion_id = match.group(2)  # May be None
        full_id = f"{base_req_id}-{assertion_id}" if assertion_id else base_req_id

        # Build result entry per REQ-tv-d00005-C
        # REQ-tv-d00005-D: The `requirement_id` field SHALL contain the base
        #                  requirement ID without assertion suffix
        # REQ-tv-d00005-E: The `assertion_id` field SHALL contain only the
        #                  assertion letter or null
        # REQ-tv-d00005-F: The `full_id` field SHALL contain the complete
        #                  reference including assertion suffix if applicable
        # REQ-tv-d00005-G: The `status` field SHALL be one of: passed, failed,
        #                  or skipped

        error_message = None
        if report.failed and report.longrepr:
            error_message = str(report.longrepr)[:500]  # Truncate long errors

        self.results.append({
            "requirement_id": base_req_id,
            "assertion_id": assertion_id,
            "full_id": full_id,
            "test_name": report.nodeid.split("::")[-1],
            "test_file": Path(report.fspath).name if report.fspath else None,
            "test_line": report.location[1] if report.location else None,
            "status": report.outcome,  # 'passed', 'failed', or 'skipped'
            "duration_ms": int(report.duration * 1000),
            "error_message": error_message,
            "timestamp": datetime.now(timezone.utc).isoformat()
        })

    def pytest_sessionfinish(self, session, exitstatus):
        """
        Write trace_results.json at end of test session.

        REQ-tv-d00005-L: The output file SHALL be generated at the end of the
                         pytest session via `pytest_sessionfinish` hook.
        """
        # Calculate summary
        # REQ-tv-d00005-H: The output SHALL include a `summary` object with:
        #                  total, passed, failed, skipped, and coverage_percentage
        total = len(self.results)
        passed = sum(1 for r in self.results if r["status"] == "passed")
        failed = sum(1 for r in self.results if r["status"] == "failed")
        skipped = sum(1 for r in self.results if r["status"] == "skipped")
        coverage = (passed / total * 100) if total > 0 else 0.0

        # Build output structure
        # REQ-tv-d00005-B: The JSON output SHALL conform to format version "1.0"
        # REQ-tv-d00005-M: The `generated_at` field SHALL contain an ISO 8601
        #                  formatted timestamp
        output = {
            "format_version": "1.0",
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "test_run_id": self.test_run_id,
            "results": self.results,
            "summary": {
                "total": total,
                "passed": passed,
                "failed": failed,
                "skipped": skipped,
                "coverage_percentage": round(coverage, 1)
            }
        }

        # Write to file
        # REQ-tv-d00005-A: output at `tests/results/trace_results.json`
        output_path = Path(__file__).parent / "results" / "trace_results.json"
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(output, indent=2))


def pytest_configure(config):
    """Register the Elspais reporter plugin."""
    reporter = ElspaisReporter()
    config.pluginmanager.register(reporter, "elspais_reporter")


# =============================================================================
# Common Fixtures
# =============================================================================

@pytest.fixture
def templates_dir(tmp_path):
    """Create a temporary templates directory structure."""
    templates = tmp_path / "templates"
    templates.mkdir()
    (templates / "partials").mkdir()
    (templates / "components").mkdir()
    return templates


@pytest.fixture
def sample_requirements():
    """Provide sample requirement data for testing."""
    from trace_view.models import Requirement
    return {
        "p00001": Requirement(
            id="p00001",
            title="Test Requirement",
            level="PRD",
            status="Active",
            body="Test body content",
            rationale="Test rationale",
            implements=set(),
            file_path=Path("prd-test.md"),
            line_number=1
        )
    }


@pytest.fixture
def sample_repo_root(tmp_path):
    """Provide a temporary repo root for testing."""
    # Create minimal spec directory structure
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (spec_dir / "prd-test.md").write_text("# REQ-p00001: Test\n\nTest content")
    return tmp_path


@pytest.fixture
def htmlerator_class():
    """Import and return HTMLGenerator class (for testing new implementation).

    This fixture skips if the HTMLGenerator hasn't been refactored to use Jinja2.
    The refactored version will have an 'env' attribute (Jinja2 Environment).
    """
    try:
        from trace_view.html.generator import HTMLGenerator
        # Check if this is the refactored version with Jinja2
        # The refactored version will have template-related attributes
        generator = HTMLGenerator.__new__(HTMLGenerator)
        if not hasattr(HTMLGenerator, '_load_css') or not hasattr(HTMLGenerator, '_load_js'):
            pytest.skip("HTMLGenerator not yet refactored (missing _load_css/_load_js methods)")
        return HTMLGenerator
    except ImportError:
        pytest.skip("HTMLGenerator not yet available")


@pytest.fixture
def htmlerator(htmlerator_class, sample_requirements, sample_repo_root):
    """Provide a fully configured HTMLGenerator instance for testing.

    This fixture combines the generator class with sample data and repo root
    to avoid the 'repo_root is None' errors in tests.
    """
    return htmlerator_class(
        requirements=sample_requirements,
        repo_root=sample_repo_root
    )
