#!/usr/bin/env python3
"""
Tests for Review Status Modifier

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00015: Status Modifier

This test file follows TDD (Test-Driven Development) methodology.
Each test references the specific assertion from REQ-tv-d00015 that it verifies.
"""

import hashlib
import re
from pathlib import Path
from typing import Optional

import pytest


# =============================================================================
# Test Imports (will fail initially - RED phase)
# =============================================================================

def import_status_module():
    """Helper to import status module - enables better error messages during TDD."""
    from trace_view.review.status import (
        # Constants
        VALID_STATUSES,
        # Dataclass
        ReqLocation,
        # Core functions
        find_req_in_file,
        find_req_in_spec_dir,
        get_req_status,
        change_req_status,
        # Hash functions
        compute_req_hash,
        update_req_hash,
    )
    return {
        'VALID_STATUSES': VALID_STATUSES,
        'ReqLocation': ReqLocation,
        'find_req_in_file': find_req_in_file,
        'find_req_in_spec_dir': find_req_in_spec_dir,
        'get_req_status': get_req_status,
        'change_req_status': change_req_status,
        'compute_req_hash': compute_req_hash,
        'update_req_hash': update_req_hash,
    }


# =============================================================================
# Fixtures
# =============================================================================

@pytest.fixture
def sample_spec_content():
    """Return sample spec file content with a requirement."""
    return """# Requirements Management Tooling

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-25
**Status**: Draft

---

# REQ-tv-d00010: Review Data Models

**Level**: Dev | **Status**: Draft | **Implements**: REQ-tv-p00002

## Rationale

The review system needs data models to store and manage review state.

## Assertions

A. All review data types SHALL be implemented as dataclasses.

B. PositionType, RequestState, and ApprovalDecision SHALL be string enums.

*End* *Review Data Models* | **Hash**: abcd1234

---

# REQ-tv-d00011: Review Storage Operations

**Level**: Dev | **Status**: Active | **Implements**: REQ-tv-p00002

## Rationale

Storage operations enable persistence of review data.

## Assertions

A. The system SHALL use atomic writes for file operations.

*End* *Review Storage Operations* | **Hash**: 12345678
"""


@pytest.fixture
def sample_spec_file(tmp_path, sample_spec_content):
    """Create a temporary spec file with sample content."""
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    spec_file = spec_dir / "dev-trace-view.md"
    spec_file.write_text(sample_spec_content)
    return spec_file


@pytest.fixture
def sample_repo_root(tmp_path, sample_spec_content):
    """Create a temporary repo with spec directory."""
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (spec_dir / "dev-trace-view.md").write_text(sample_spec_content)
    return tmp_path


@pytest.fixture
def multi_file_repo(tmp_path):
    """Create a repo with multiple spec files."""
    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()

    # dev file
    dev_content = """# Dev Spec

# REQ-tv-d00001: Test Requirement

**Level**: Dev | **Status**: Draft | **Implements**: REQ-tv-p00001

Test content.

*End* *Test Requirement* | **Hash**: 00000000
"""
    (spec_dir / "dev-test.md").write_text(dev_content)

    # prd file
    prd_content = """# PRD Spec

# REQ-tv-p00001: Product Requirement

**Level**: PRD | **Status**: Active | **Implements**: -

Test content.

*End* *Product Requirement* | **Hash**: 11111111
"""
    (spec_dir / "prd-test.md").write_text(prd_content)

    # ops file
    ops_content = """# Ops Spec

# REQ-tv-o00001: Operations Requirement

**Level**: Ops | **Status**: Deprecated | **Implements**: REQ-tv-p00001

Test content.

*End* *Operations Requirement* | **Hash**: 22222222
"""
    (spec_dir / "ops-test.md").write_text(ops_content)

    return tmp_path


# =============================================================================
# Assertion A: find_req_in_file() SHALL locate a requirement
# =============================================================================

class TestFindReqInFile:
    """REQ-tv-d00015-A: find_req_in_file(file_path, req_id) SHALL locate a
    requirement in a spec file and return the status line information."""

    def test_find_req_in_file_returns_location(self, sample_spec_file):
        """REQ-tv-d00015-A: Returns ReqLocation when requirement found"""
        m = import_status_module()
        find_req_in_file = m['find_req_in_file']
        ReqLocation = m['ReqLocation']

        result = find_req_in_file(sample_spec_file, "tv-d00010")

        assert result is not None
        assert isinstance(result, ReqLocation)
        assert result.req_id == "tv-d00010"
        assert result.current_status == "Draft"
        assert result.file_path == sample_spec_file

    def test_find_req_in_file_returns_line_number(self, sample_spec_file):
        """REQ-tv-d00015-A: Returns correct 1-based line number of status line"""
        m = import_status_module()
        find_req_in_file = m['find_req_in_file']

        result = find_req_in_file(sample_spec_file, "tv-d00010")

        # Status line is the second line after the header
        assert result is not None
        assert result.line_number > 0  # 1-based line number

        # Verify by reading the file and checking the line
        lines = sample_spec_file.read_text().splitlines()
        status_line = lines[result.line_number - 1]  # Convert to 0-based
        assert "**Status**:" in status_line
        assert "Draft" in status_line

    def test_find_req_in_file_returns_none_when_not_found(self, sample_spec_file):
        """REQ-tv-d00015-A: Returns None when requirement not in file"""
        m = import_status_module()
        find_req_in_file = m['find_req_in_file']

        result = find_req_in_file(sample_spec_file, "tv-d99999")

        assert result is None

    def test_find_req_in_file_handles_nonexistent_file(self, tmp_path):
        """REQ-tv-d00015-A: Returns None for nonexistent file"""
        m = import_status_module()
        find_req_in_file = m['find_req_in_file']

        result = find_req_in_file(tmp_path / "nonexistent.md", "tv-d00010")

        assert result is None

    def test_find_req_in_file_finds_second_requirement(self, sample_spec_file):
        """REQ-tv-d00015-A: Can find any requirement in file, not just first"""
        m = import_status_module()
        find_req_in_file = m['find_req_in_file']

        result = find_req_in_file(sample_spec_file, "tv-d00011")

        assert result is not None
        assert result.req_id == "tv-d00011"
        assert result.current_status == "Active"

    def test_find_req_in_file_accepts_full_req_id(self, sample_spec_file):
        """REQ-tv-d00015-A: Accepts both 'tv-d00010' and 'REQ-tv-d00010' formats"""
        m = import_status_module()
        find_req_in_file = m['find_req_in_file']

        # Without REQ- prefix
        result1 = find_req_in_file(sample_spec_file, "tv-d00010")
        # With REQ- prefix
        result2 = find_req_in_file(sample_spec_file, "REQ-tv-d00010")

        assert result1 is not None
        assert result2 is not None
        assert result1.current_status == result2.current_status


# =============================================================================
# Assertion B: get_req_status() SHALL read and return current status
# =============================================================================

class TestGetReqStatus:
    """REQ-tv-d00015-B: get_req_status(repo_root, req_id) SHALL read and return
    the current status value from the spec file."""

    def test_get_req_status_returns_status(self, sample_repo_root):
        """REQ-tv-d00015-B: Returns current status for valid requirement"""
        m = import_status_module()
        get_req_status = m['get_req_status']

        status = get_req_status(sample_repo_root, "tv-d00010")

        assert status == "Draft"

    def test_get_req_status_returns_different_statuses(self, multi_file_repo):
        """REQ-tv-d00015-B: Returns correct status for different requirements"""
        m = import_status_module()
        get_req_status = m['get_req_status']

        assert get_req_status(multi_file_repo, "tv-d00001") == "Draft"
        assert get_req_status(multi_file_repo, "tv-p00001") == "Active"
        assert get_req_status(multi_file_repo, "tv-o00001") == "Deprecated"

    def test_get_req_status_returns_none_for_unknown(self, sample_repo_root):
        """REQ-tv-d00015-B: Returns None when requirement not found"""
        m = import_status_module()
        get_req_status = m['get_req_status']

        status = get_req_status(sample_repo_root, "tv-d99999")

        assert status is None

    def test_get_req_status_searches_all_spec_files(self, multi_file_repo):
        """REQ-tv-d00015-B: Searches all spec files in spec/ directory"""
        m = import_status_module()
        get_req_status = m['get_req_status']

        # Requirements in different files should all be found
        assert get_req_status(multi_file_repo, "tv-d00001") is not None
        assert get_req_status(multi_file_repo, "tv-p00001") is not None
        assert get_req_status(multi_file_repo, "tv-o00001") is not None


# =============================================================================
# Assertion C: change_req_status() SHALL update status atomically
# =============================================================================

class TestChangeReqStatus:
    """REQ-tv-d00015-C: change_req_status(repo_root, req_id, new_status, user)
    SHALL update the status value in the spec file atomically."""

    def test_change_req_status_updates_file(self, sample_repo_root):
        """REQ-tv-d00015-C: Updates status in the spec file"""
        m = import_status_module()
        change_req_status = m['change_req_status']
        get_req_status = m['get_req_status']

        # Initial status
        assert get_req_status(sample_repo_root, "tv-d00010") == "Draft"

        # Change status
        success, message = change_req_status(
            sample_repo_root, "tv-d00010", "Active", "test_user"
        )

        assert success is True
        assert "tv-d00010" in message

        # Verify status changed
        assert get_req_status(sample_repo_root, "tv-d00010") == "Active"

    def test_change_req_status_returns_success_tuple(self, sample_repo_root):
        """REQ-tv-d00015-C: Returns (True, message) on success"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        success, message = change_req_status(
            sample_repo_root, "tv-d00010", "Active", "test_user"
        )

        assert isinstance(success, bool)
        assert isinstance(message, str)
        assert success is True

    def test_change_req_status_returns_failure_for_unknown(self, sample_repo_root):
        """REQ-tv-d00015-C: Returns (False, error) for unknown requirement"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        success, message = change_req_status(
            sample_repo_root, "tv-d99999", "Active", "test_user"
        )

        assert success is False
        assert "not found" in message.lower()

    def test_change_req_status_no_change_when_same(self, sample_repo_root):
        """REQ-tv-d00015-C: Handles case when status is already target value"""
        m = import_status_module()
        change_req_status = m['change_req_status']
        get_req_status = m['get_req_status']

        # Status is already Draft
        assert get_req_status(sample_repo_root, "tv-d00010") == "Draft"

        success, message = change_req_status(
            sample_repo_root, "tv-d00010", "Draft", "test_user"
        )

        # Should still succeed (or indicate no change)
        assert success is True


# =============================================================================
# Assertion D: Status values SHALL be validated
# =============================================================================

class TestStatusValidation:
    """REQ-tv-d00015-D: Status values SHALL be validated against the allowed set:
    Draft, Active, Deprecated."""

    def test_valid_statuses_defined(self):
        """REQ-tv-d00015-D: VALID_STATUSES constant is defined"""
        m = import_status_module()
        VALID_STATUSES = m['VALID_STATUSES']

        assert "Draft" in VALID_STATUSES
        assert "Active" in VALID_STATUSES
        assert "Deprecated" in VALID_STATUSES
        assert len(VALID_STATUSES) == 3

    def test_change_req_status_rejects_invalid_status(self, sample_repo_root):
        """REQ-tv-d00015-D: Rejects invalid status values"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        success, message = change_req_status(
            sample_repo_root, "tv-d00010", "InvalidStatus", "test_user"
        )

        assert success is False
        assert "invalid" in message.lower() or "status" in message.lower()

    def test_change_req_status_rejects_review_status(self, sample_repo_root):
        """REQ-tv-d00015-D: 'Review' is not a valid status"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        success, message = change_req_status(
            sample_repo_root, "tv-d00010", "Review", "test_user"
        )

        assert success is False

    def test_change_req_status_case_sensitive(self, sample_repo_root):
        """REQ-tv-d00015-D: Status values are case-sensitive"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        # lowercase should be rejected
        success, message = change_req_status(
            sample_repo_root, "tv-d00010", "active", "test_user"
        )

        assert success is False


# =============================================================================
# Assertion E: Content preservation when changing status
# =============================================================================

class TestContentPreservation:
    """REQ-tv-d00015-E: The status modifier SHALL preserve all other content
    and formatting when changing status."""

    def test_preserves_requirement_header(self, sample_repo_root):
        """REQ-tv-d00015-E: Preserves requirement header after status change"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        spec_file = sample_repo_root / "spec" / "dev-trace-view.md"
        original = spec_file.read_text()

        change_req_status(sample_repo_root, "tv-d00010", "Active", "test_user")

        modified = spec_file.read_text()

        # Header should be unchanged
        assert "# REQ-tv-d00010: Review Data Models" in modified

    def test_preserves_assertions(self, sample_repo_root):
        """REQ-tv-d00015-E: Preserves assertions section after status change"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        spec_file = sample_repo_root / "spec" / "dev-trace-view.md"

        change_req_status(sample_repo_root, "tv-d00010", "Active", "test_user")

        modified = spec_file.read_text()

        # Assertions should be unchanged
        assert "A. All review data types SHALL be implemented" in modified
        assert "B. PositionType, RequestState" in modified

    def test_preserves_other_requirements(self, sample_repo_root):
        """REQ-tv-d00015-E: Does not modify other requirements in file"""
        m = import_status_module()
        change_req_status = m['change_req_status']
        get_req_status = m['get_req_status']

        # Change first requirement
        change_req_status(sample_repo_root, "tv-d00010", "Active", "test_user")

        # Second requirement should be unchanged
        assert get_req_status(sample_repo_root, "tv-d00011") == "Active"

    def test_preserves_level_and_implements(self, sample_repo_root):
        """REQ-tv-d00015-E: Preserves Level and Implements on status line"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        spec_file = sample_repo_root / "spec" / "dev-trace-view.md"

        change_req_status(sample_repo_root, "tv-d00010", "Active", "test_user")

        modified = spec_file.read_text()

        # Find the status line for tv-d00010
        lines = modified.splitlines()
        for line in lines:
            if "**Status**: Active" in line and "**Level**: Dev" in line:
                assert "**Implements**: REQ-tv-p00002" in line
                break
        else:
            pytest.fail("Could not find properly formatted status line")

    def test_preserves_file_structure(self, sample_repo_root):
        """REQ-tv-d00015-E: Preserves overall file structure"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        spec_file = sample_repo_root / "spec" / "dev-trace-view.md"
        original = spec_file.read_text()
        original_lines = original.splitlines()

        change_req_status(sample_repo_root, "tv-d00010", "Active", "test_user")

        modified = spec_file.read_text()
        modified_lines = modified.splitlines()

        # Same number of lines (hash line might change)
        # Allow for hash line changes
        assert abs(len(modified_lines) - len(original_lines)) <= 1


# =============================================================================
# Assertion F: Hash update after status changes
# =============================================================================

class TestHashUpdate:
    """REQ-tv-d00015-F: The status modifier SHALL update the requirement's
    content hash footer after status changes."""

    def test_compute_req_hash_returns_8_char_hex(self):
        """REQ-tv-d00015-F: compute_req_hash returns 8-character hex string"""
        m = import_status_module()
        compute_req_hash = m['compute_req_hash']

        content = "Test content for hashing"
        hash_value = compute_req_hash(content)

        assert isinstance(hash_value, str)
        assert len(hash_value) == 8
        assert all(c in '0123456789abcdef' for c in hash_value)

    def test_compute_req_hash_is_deterministic(self):
        """REQ-tv-d00015-F: Same content produces same hash"""
        m = import_status_module()
        compute_req_hash = m['compute_req_hash']

        content = "Test content for hashing"
        hash1 = compute_req_hash(content)
        hash2 = compute_req_hash(content)

        assert hash1 == hash2

    def test_compute_req_hash_different_for_different_content(self):
        """REQ-tv-d00015-F: Different content produces different hash"""
        m = import_status_module()
        compute_req_hash = m['compute_req_hash']

        hash1 = compute_req_hash("Content A")
        hash2 = compute_req_hash("Content B")

        assert hash1 != hash2

    def test_change_req_status_updates_hash(self, sample_repo_root):
        """REQ-tv-d00015-F: Hash is updated after status change"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        spec_file = sample_repo_root / "spec" / "dev-trace-view.md"
        original = spec_file.read_text()

        # Get original hash for tv-d00010
        original_hash_match = re.search(
            r'\*End\* \*Review Data Models\* \| \*\*Hash\*\*: ([a-f0-9]{8})',
            original
        )
        assert original_hash_match is not None
        original_hash = original_hash_match.group(1)

        # Change status
        change_req_status(sample_repo_root, "tv-d00010", "Active", "test_user")

        modified = spec_file.read_text()

        # Get new hash
        new_hash_match = re.search(
            r'\*End\* \*Review Data Models\* \| \*\*Hash\*\*: ([a-f0-9]{8})',
            modified
        )
        assert new_hash_match is not None
        new_hash = new_hash_match.group(1)

        # Hash should be different (status changed)
        assert new_hash != original_hash

    def test_update_req_hash_function_exists(self, sample_repo_root):
        """REQ-tv-d00015-F: update_req_hash function is available"""
        m = import_status_module()
        update_req_hash = m['update_req_hash']

        spec_file = sample_repo_root / "spec" / "dev-trace-view.md"
        result = update_req_hash(spec_file, "tv-d00010")

        assert isinstance(result, bool)


# =============================================================================
# Assertion G: Atomic operations - no corruption on failure
# =============================================================================

class TestAtomicOperations:
    """REQ-tv-d00015-G: Failed status changes SHALL NOT leave the spec file
    in a corrupted or partial state."""

    def test_file_unchanged_on_invalid_status(self, sample_repo_root):
        """REQ-tv-d00015-G: File unchanged when status is invalid"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        spec_file = sample_repo_root / "spec" / "dev-trace-view.md"
        original = spec_file.read_text()

        # Try to change to invalid status
        success, _ = change_req_status(
            sample_repo_root, "tv-d00010", "InvalidStatus", "test_user"
        )

        assert success is False

        # File should be unchanged
        current = spec_file.read_text()
        assert current == original

    def test_file_unchanged_on_req_not_found(self, sample_repo_root):
        """REQ-tv-d00015-G: File unchanged when requirement not found"""
        m = import_status_module()
        change_req_status = m['change_req_status']

        spec_file = sample_repo_root / "spec" / "dev-trace-view.md"
        original = spec_file.read_text()

        # Try to change non-existent requirement
        success, _ = change_req_status(
            sample_repo_root, "tv-d99999", "Active", "test_user"
        )

        assert success is False

        # File should be unchanged
        current = spec_file.read_text()
        assert current == original

    def test_file_remains_valid_after_change(self, sample_repo_root):
        """REQ-tv-d00015-G: File remains parseable after status change"""
        m = import_status_module()
        change_req_status = m['change_req_status']
        find_req_in_file = m['find_req_in_file']

        spec_file = sample_repo_root / "spec" / "dev-trace-view.md"

        # Change status
        change_req_status(sample_repo_root, "tv-d00010", "Active", "test_user")

        # Should still be able to find requirements
        result = find_req_in_file(spec_file, "tv-d00010")
        assert result is not None
        assert result.current_status == "Active"

        # Other requirements should also be findable
        result2 = find_req_in_file(spec_file, "tv-d00011")
        assert result2 is not None


# =============================================================================
# Additional Integration Tests
# =============================================================================

class TestIntegration:
    """Integration tests for status modifier workflow."""

    def test_complete_status_change_workflow(self, sample_repo_root):
        """Test complete status change workflow"""
        m = import_status_module()
        get_req_status = m['get_req_status']
        change_req_status = m['change_req_status']

        # Initial state
        assert get_req_status(sample_repo_root, "tv-d00010") == "Draft"

        # Change to Active
        success, msg = change_req_status(
            sample_repo_root, "tv-d00010", "Active", "alice"
        )
        assert success
        assert get_req_status(sample_repo_root, "tv-d00010") == "Active"

        # Change to Deprecated
        success, msg = change_req_status(
            sample_repo_root, "tv-d00010", "Deprecated", "bob"
        )
        assert success
        assert get_req_status(sample_repo_root, "tv-d00010") == "Deprecated"

        # Change back to Draft
        success, msg = change_req_status(
            sample_repo_root, "tv-d00010", "Draft", "alice"
        )
        assert success
        assert get_req_status(sample_repo_root, "tv-d00010") == "Draft"

    def test_find_req_in_spec_dir_searches_recursively(self, multi_file_repo):
        """Test that find_req_in_spec_dir searches all spec files"""
        m = import_status_module()
        find_req_in_spec_dir = m['find_req_in_spec_dir']

        # Find requirements in different files
        loc1 = find_req_in_spec_dir(multi_file_repo, "tv-d00001")
        loc2 = find_req_in_spec_dir(multi_file_repo, "tv-p00001")
        loc3 = find_req_in_spec_dir(multi_file_repo, "tv-o00001")

        assert loc1 is not None
        assert "dev-test.md" in str(loc1.file_path)

        assert loc2 is not None
        assert "prd-test.md" in str(loc2.file_path)

        assert loc3 is not None
        assert "ops-test.md" in str(loc3.file_path)

    def test_handles_sponsor_spec_files(self, tmp_path):
        """Test searching in sponsor-specific spec directories"""
        m = import_status_module()
        find_req_in_spec_dir = m['find_req_in_spec_dir']
        get_req_status = m['get_req_status']

        # Create sponsor spec directory
        sponsor_spec = tmp_path / "sponsor" / "hht" / "spec"
        sponsor_spec.mkdir(parents=True)

        sponsor_content = """# Sponsor Spec

# REQ-HHT-d00001: Sponsor Requirement

**Level**: Dev | **Status**: Draft | **Implements**: -

Sponsor-specific content.

*End* *Sponsor Requirement* | **Hash**: 33333333
"""
        (sponsor_spec / "dev-sponsor.md").write_text(sponsor_content)

        # Also create empty core spec dir
        (tmp_path / "spec").mkdir()

        # Should find sponsor requirement
        loc = find_req_in_spec_dir(tmp_path, "HHT-d00001")
        assert loc is not None
        assert "sponsor" in str(loc.file_path)

        # get_req_status should also work
        status = get_req_status(tmp_path, "HHT-d00001")
        assert status == "Draft"
