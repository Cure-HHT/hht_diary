#!/usr/bin/env python3
"""
Tests for status_modifier.py - Modify REQ status in spec files

TDD tests written before implementation.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration (status change workflow)
"""

import pytest
import tempfile
from pathlib import Path

from tools.spec_review.status_modifier import (
    change_req_status,
    get_req_status,
    find_req_in_file,
    get_spec_file_for_req,
)


class TestFindReqInFile:
    """Test finding a REQ in a spec file"""

    def test_find_req_returns_position_for_valid_req(self, tmp_path):
        """Should return the position of the status field for a valid REQ"""
        spec_content = """# REQ-d00001: Test Requirement

**Level**: Dev | **Implements**: - | **Status**: Draft

This is the body.

*End* *Test Requirement* | **Hash**: abc12345
"""
        spec_file = tmp_path / "dev-test.md"
        spec_file.write_text(spec_content)

        result = find_req_in_file(spec_file, "d00001")
        assert result is not None
        assert result["req_id"] == "d00001"
        assert result["current_status"] == "Draft"
        assert result["status_line_start"] > 0
        assert result["status_line_end"] > result["status_line_start"]

    def test_find_req_returns_none_for_missing_req(self, tmp_path):
        """Should return None if REQ is not in file"""
        spec_content = """# REQ-d00001: Test Requirement

**Level**: Dev | **Implements**: - | **Status**: Draft

This is the body.

*End* *Test Requirement* | **Hash**: abc12345
"""
        spec_file = tmp_path / "dev-test.md"
        spec_file.write_text(spec_content)

        result = find_req_in_file(spec_file, "d00002")
        assert result is None

    def test_find_req_handles_review_status(self, tmp_path):
        """Should find REQs with Review status"""
        spec_content = """# REQ-d00001: Test Requirement

**Level**: Dev | **Implements**: - | **Status**: Review

This is the body.

*End* *Test Requirement* | **Hash**: abc12345
"""
        spec_file = tmp_path / "dev-test.md"
        spec_file.write_text(spec_content)

        result = find_req_in_file(spec_file, "d00001")
        assert result is not None
        assert result["current_status"] == "Review"


class TestGetReqStatus:
    """Test getting the current status of a REQ"""

    def test_get_status_for_existing_req(self, tmp_path):
        """Should return the status for an existing REQ"""
        spec_dir = tmp_path / "spec"
        spec_dir.mkdir()
        spec_content = """# REQ-d00001: Test Requirement

**Level**: Dev | **Implements**: - | **Status**: Draft

This is the body.

*End* *Test Requirement* | **Hash**: abc12345
"""
        spec_file = spec_dir / "dev-test.md"
        spec_file.write_text(spec_content)

        status = get_req_status(tmp_path, "d00001")
        assert status == "Draft"

    def test_get_status_returns_none_for_missing_req(self, tmp_path):
        """Should return None if REQ not found"""
        spec_dir = tmp_path / "spec"
        spec_dir.mkdir()
        spec_file = spec_dir / "dev-test.md"
        spec_file.write_text("# Empty file\n")

        status = get_req_status(tmp_path, "d99999")
        assert status is None


class TestGetSpecFileForReq:
    """Test finding which spec file contains a REQ"""

    def test_finds_file_containing_req(self, tmp_path):
        """Should return the path to the file containing the REQ"""
        spec_dir = tmp_path / "spec"
        spec_dir.mkdir()

        # Create two spec files
        file1 = spec_dir / "dev-foo.md"
        file1.write_text("# REQ-d00001: Foo\n\n**Level**: Dev | **Implements**: - | **Status**: Draft\n\nBody\n\n*End* *Foo* | **Hash**: abc12345\n")

        file2 = spec_dir / "dev-bar.md"
        file2.write_text("# REQ-d00002: Bar\n\n**Level**: Dev | **Implements**: - | **Status**: Active\n\nBody\n\n*End* *Bar* | **Hash**: def67890\n")

        result = get_spec_file_for_req(tmp_path, "d00002")
        assert result == file2

    def test_returns_none_for_missing_req(self, tmp_path):
        """Should return None if REQ not found in any file"""
        spec_dir = tmp_path / "spec"
        spec_dir.mkdir()

        file1 = spec_dir / "dev-foo.md"
        file1.write_text("# REQ-d00001: Foo\n\n**Level**: Dev | **Implements**: - | **Status**: Draft\n\nBody\n\n*End* *Foo* | **Hash**: abc12345\n")

        result = get_spec_file_for_req(tmp_path, "d99999")
        assert result is None


class TestChangeReqStatus:
    """Test changing a REQ's status in a spec file"""

    def test_change_draft_to_review(self, tmp_path):
        """Should change Draft status to Review"""
        spec_dir = tmp_path / "spec"
        spec_dir.mkdir()
        spec_content = """# REQ-d00001: Test Requirement

**Level**: Dev | **Implements**: - | **Status**: Draft

This is the body.

*End* *Test Requirement* | **Hash**: abc12345
"""
        spec_file = spec_dir / "dev-test.md"
        spec_file.write_text(spec_content)

        result = change_req_status(tmp_path, "d00001", "Review", "test_user")
        assert result["success"] is True
        assert result["old_status"] == "Draft"
        assert result["new_status"] == "Review"
        assert result["file"] == str(spec_file)

        # Verify the file was updated
        updated_content = spec_file.read_text()
        assert "**Status**: Review" in updated_content
        assert "**Status**: Draft" not in updated_content

    def test_change_review_to_active(self, tmp_path):
        """Should change Review status to Active"""
        spec_dir = tmp_path / "spec"
        spec_dir.mkdir()
        spec_content = """# REQ-d00001: Test Requirement

**Level**: Dev | **Implements**: - | **Status**: Review

This is the body.

*End* *Test Requirement* | **Hash**: abc12345
"""
        spec_file = spec_dir / "dev-test.md"
        spec_file.write_text(spec_content)

        result = change_req_status(tmp_path, "d00001", "Active", "test_user")
        assert result["success"] is True
        assert result["old_status"] == "Review"
        assert result["new_status"] == "Active"

        # Verify the file was updated
        updated_content = spec_file.read_text()
        assert "**Status**: Active" in updated_content

    def test_change_returns_error_for_missing_req(self, tmp_path):
        """Should return error for missing REQ"""
        spec_dir = tmp_path / "spec"
        spec_dir.mkdir()
        spec_file = spec_dir / "dev-test.md"
        spec_file.write_text("# Empty file\n")

        result = change_req_status(tmp_path, "d99999", "Review", "test_user")
        assert result["success"] is False
        assert "not found" in result["error"].lower()

    def test_change_returns_error_for_invalid_status(self, tmp_path):
        """Should return error for invalid new status"""
        spec_dir = tmp_path / "spec"
        spec_dir.mkdir()
        spec_content = """# REQ-d00001: Test Requirement

**Level**: Dev | **Implements**: - | **Status**: Draft

This is the body.

*End* *Test Requirement* | **Hash**: abc12345
"""
        spec_file = spec_dir / "dev-test.md"
        spec_file.write_text(spec_content)

        result = change_req_status(tmp_path, "d00001", "InvalidStatus", "test_user")
        assert result["success"] is False
        assert "invalid" in result["error"].lower()

    def test_change_no_op_for_same_status(self, tmp_path):
        """Should return success but no change if status is already the target"""
        spec_dir = tmp_path / "spec"
        spec_dir.mkdir()
        spec_content = """# REQ-d00001: Test Requirement

**Level**: Dev | **Implements**: - | **Status**: Review

This is the body.

*End* *Test Requirement* | **Hash**: abc12345
"""
        spec_file = spec_dir / "dev-test.md"
        spec_file.write_text(spec_content)

        result = change_req_status(tmp_path, "d00001", "Review", "test_user")
        assert result["success"] is True
        assert result["old_status"] == "Review"
        assert result["new_status"] == "Review"
        assert result.get("no_change") is True

    def test_change_preserves_other_content(self, tmp_path):
        """Should not modify other parts of the file"""
        spec_dir = tmp_path / "spec"
        spec_dir.mkdir()
        spec_content = """# Intro

Some intro text.

# REQ-d00001: Test Requirement

**Level**: Dev | **Implements**: - | **Status**: Draft

This is the body with **markdown** and `code`.

**Rationale**: Because reasons.

*End* *Test Requirement* | **Hash**: abc12345

---

# REQ-d00002: Another Requirement

**Level**: Dev | **Implements**: d00001 | **Status**: Active

Another body.

*End* *Another Requirement* | **Hash**: def67890
"""
        spec_file = spec_dir / "dev-test.md"
        spec_file.write_text(spec_content)

        result = change_req_status(tmp_path, "d00001", "Review", "test_user")
        assert result["success"] is True

        # Verify only d00001 was changed
        updated_content = spec_file.read_text()
        assert "# REQ-d00001:" in updated_content
        assert "# REQ-d00002:" in updated_content
        assert "**Status**: Review" in updated_content  # d00001 changed
        assert "**Status**: Active" in updated_content  # d00002 unchanged
        assert "Some intro text." in updated_content
        assert "**markdown** and `code`" in updated_content


class TestStatusModifierWithSponsorReqs:
    """Test status modifier with sponsor-specific REQ IDs"""

    def test_change_sponsor_req_status(self, tmp_path):
        """Should handle sponsor-prefixed REQ IDs"""
        spec_dir = tmp_path / "spec"
        spec_dir.mkdir()
        sponsor_dir = tmp_path / "sponsor" / "CAL" / "spec"
        sponsor_dir.mkdir(parents=True)

        spec_content = """# REQ-CAL-d00001: Sponsor Requirement

**Level**: Dev | **Implements**: - | **Status**: Draft

Sponsor-specific body.

*End* *Sponsor Requirement* | **Hash**: abc12345
"""
        spec_file = sponsor_dir / "dev-sponsor.md"
        spec_file.write_text(spec_content)

        result = change_req_status(tmp_path, "CAL-d00001", "Review", "test_user")
        assert result["success"] is True
        assert result["old_status"] == "Draft"
        assert result["new_status"] == "Review"

        # Verify the file was updated
        updated_content = spec_file.read_text()
        assert "**Status**: Review" in updated_content


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
