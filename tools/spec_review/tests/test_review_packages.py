#!/usr/bin/env python3
"""
Tests for review_packages.py - Review Package Data Model and Storage

TDD tests written before implementation.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration (package management)
"""

import json
import pytest
import tempfile
from pathlib import Path
from datetime import datetime

from tools.spec_review.review_packages import (
    ReviewPackage,
    PackagesFile,
    load_packages,
    save_packages,
    create_package,
    get_package,
    update_package,
    delete_package,
    add_req_to_package,
    remove_req_from_package,
    get_active_package,
    set_active_package,
    get_default_package,
    on_status_changed_to_review,
    get_package_for_req,
)


class TestReviewPackageDataClass:
    """Test the ReviewPackage data class"""

    def test_create_package(self):
        """Should create a package with all fields"""
        pkg = ReviewPackage(
            packageId="test-id",
            name="Test Package",
            description="A test package",
            reqIds=["d00001", "d00002"],
            createdBy="test_user",
            createdAt="2025-01-15T10:00:00Z",
            isDefault=False
        )
        assert pkg.packageId == "test-id"
        assert pkg.name == "Test Package"
        assert pkg.reqIds == ["d00001", "d00002"]
        assert pkg.isDefault is False

    def test_to_dict(self):
        """Should serialize to dictionary"""
        pkg = ReviewPackage(
            packageId="test-id",
            name="Test Package",
            description="A test package",
            reqIds=["d00001"],
            createdBy="test_user",
            createdAt="2025-01-15T10:00:00Z",
            isDefault=False
        )
        d = pkg.to_dict()
        assert d["packageId"] == "test-id"
        assert d["name"] == "Test Package"
        assert d["reqIds"] == ["d00001"]

    def test_from_dict(self):
        """Should deserialize from dictionary"""
        d = {
            "packageId": "test-id",
            "name": "Test Package",
            "description": "A test package",
            "reqIds": ["d00001"],
            "createdBy": "test_user",
            "createdAt": "2025-01-15T10:00:00Z",
            "isDefault": False
        }
        pkg = ReviewPackage.from_dict(d)
        assert pkg.packageId == "test-id"
        assert pkg.name == "Test Package"


class TestPackagesFile:
    """Test the PackagesFile container"""

    def test_empty_packages_file(self):
        """Should create empty packages file"""
        pf = PackagesFile(packages=[], activePackageId=None)
        assert len(pf.packages) == 0
        assert pf.activePackageId is None

    def test_get_default_package(self):
        """Should return the default package"""
        default = ReviewPackage(
            packageId="default",
            name="Default",
            description="Default package",
            reqIds=[],
            createdBy="system",
            createdAt="2025-01-01T00:00:00Z",
            isDefault=True
        )
        pf = PackagesFile(packages=[default], activePackageId=None)
        assert pf.get_default() == default

    def test_get_active_package(self):
        """Should return the active package"""
        pkg1 = ReviewPackage(
            packageId="pkg1",
            name="Package 1",
            description="",
            reqIds=[],
            createdBy="user",
            createdAt="2025-01-15T10:00:00Z",
            isDefault=False
        )
        pf = PackagesFile(packages=[pkg1], activePackageId="pkg1")
        assert pf.get_active() == pkg1


class TestLoadSavePackages:
    """Test loading and saving packages"""

    def test_load_creates_default_if_not_exists(self, tmp_path):
        """Should create default package if file doesn't exist"""
        pf = load_packages(tmp_path)
        assert len(pf.packages) == 1
        assert pf.packages[0].isDefault is True
        assert pf.packages[0].name == "Default"

    def test_save_and_load_packages(self, tmp_path):
        """Should round-trip packages through save/load"""
        pkg = ReviewPackage(
            packageId="test-pkg",
            name="Test Package",
            description="Testing",
            reqIds=["d00001", "d00002"],
            createdBy="test_user",
            createdAt="2025-01-15T10:00:00Z",
            isDefault=False
        )
        pf = PackagesFile(packages=[pkg], activePackageId="test-pkg")
        save_packages(tmp_path, pf)

        loaded = load_packages(tmp_path)
        assert len(loaded.packages) == 1
        assert loaded.packages[0].name == "Test Package"
        assert loaded.activePackageId == "test-pkg"


class TestCreatePackage:
    """Test package creation"""

    def test_create_package_adds_to_file(self, tmp_path):
        """Should add new package to packages file"""
        pkg = create_package(
            tmp_path,
            name="New Package",
            description="My new package",
            user="test_user"
        )
        assert pkg.name == "New Package"
        assert pkg.packageId is not None
        assert len(pkg.packageId) > 0

        # Verify it was persisted
        loaded = load_packages(tmp_path)
        assert len(loaded.packages) == 2  # default + new
        names = [p.name for p in loaded.packages]
        assert "New Package" in names


class TestGetPackage:
    """Test getting packages by ID"""

    def test_get_existing_package(self, tmp_path):
        """Should return package by ID"""
        # Create a package first
        pkg = create_package(tmp_path, "Test", "Desc", "user")

        fetched = get_package(tmp_path, pkg.packageId)
        assert fetched is not None
        assert fetched.name == "Test"

    def test_get_nonexistent_package(self, tmp_path):
        """Should return None for nonexistent ID"""
        load_packages(tmp_path)  # Ensure file exists
        fetched = get_package(tmp_path, "nonexistent-id")
        assert fetched is None


class TestUpdatePackage:
    """Test updating packages"""

    def test_update_package_name(self, tmp_path):
        """Should update package name"""
        pkg = create_package(tmp_path, "Original", "Desc", "user")

        success = update_package(tmp_path, pkg.packageId, name="Updated Name")
        assert success is True

        fetched = get_package(tmp_path, pkg.packageId)
        assert fetched.name == "Updated Name"

    def test_update_nonexistent_package(self, tmp_path):
        """Should return False for nonexistent package"""
        load_packages(tmp_path)  # Ensure file exists
        success = update_package(tmp_path, "nonexistent", name="New Name")
        assert success is False


class TestDeletePackage:
    """Test deleting packages"""

    def test_delete_package(self, tmp_path):
        """Should delete a package"""
        pkg = create_package(tmp_path, "ToDelete", "Desc", "user")

        success = delete_package(tmp_path, pkg.packageId)
        assert success is True

        fetched = get_package(tmp_path, pkg.packageId)
        assert fetched is None

    def test_cannot_delete_default_package(self, tmp_path):
        """Should not allow deleting the default package"""
        pf = load_packages(tmp_path)
        default_pkg = pf.get_default()

        success = delete_package(tmp_path, default_pkg.packageId)
        assert success is False

        # Default should still exist
        loaded = load_packages(tmp_path)
        assert loaded.get_default() is not None


class TestAddRemoveReqFromPackage:
    """Test adding and removing REQs from packages"""

    def test_add_req_to_package(self, tmp_path):
        """Should add a REQ to a package"""
        pkg = create_package(tmp_path, "Test", "Desc", "user")

        success = add_req_to_package(tmp_path, pkg.packageId, "d00001")
        assert success is True

        fetched = get_package(tmp_path, pkg.packageId)
        assert "d00001" in fetched.reqIds

    def test_add_req_is_idempotent(self, tmp_path):
        """Should not duplicate REQ if already in package"""
        pkg = create_package(tmp_path, "Test", "Desc", "user")

        add_req_to_package(tmp_path, pkg.packageId, "d00001")
        add_req_to_package(tmp_path, pkg.packageId, "d00001")

        fetched = get_package(tmp_path, pkg.packageId)
        assert fetched.reqIds.count("d00001") == 1

    def test_remove_req_from_package(self, tmp_path):
        """Should remove a REQ from a package"""
        pkg = create_package(tmp_path, "Test", "Desc", "user")
        add_req_to_package(tmp_path, pkg.packageId, "d00001")
        add_req_to_package(tmp_path, pkg.packageId, "d00002")

        success = remove_req_from_package(tmp_path, pkg.packageId, "d00001")
        assert success is True

        fetched = get_package(tmp_path, pkg.packageId)
        assert "d00001" not in fetched.reqIds
        assert "d00002" in fetched.reqIds


class TestActivePackage:
    """Test active package management"""

    def test_set_and_get_active_package(self, tmp_path):
        """Should set and get the active package"""
        pkg = create_package(tmp_path, "Test", "Desc", "user")

        success = set_active_package(tmp_path, pkg.packageId)
        assert success is True

        active = get_active_package(tmp_path)
        assert active is not None
        assert active.packageId == pkg.packageId

    def test_clear_active_package(self, tmp_path):
        """Should allow clearing active package (set to None)"""
        pkg = create_package(tmp_path, "Test", "Desc", "user")
        set_active_package(tmp_path, pkg.packageId)

        success = set_active_package(tmp_path, None)
        assert success is True

        active = get_active_package(tmp_path)
        assert active is None


class TestGetDefaultPackage:
    """Test getting the default package"""

    def test_get_default_package(self, tmp_path):
        """Should return the default package"""
        load_packages(tmp_path)  # Creates default

        default = get_default_package(tmp_path)
        assert default is not None
        assert default.isDefault is True


class TestGetPackageForReq:
    """Test finding which package contains a REQ"""

    def test_find_package_containing_req(self, tmp_path):
        """Should return the package containing a REQ"""
        pkg = create_package(tmp_path, "Test", "Desc", "user")
        add_req_to_package(tmp_path, pkg.packageId, "d00001")

        found = get_package_for_req(tmp_path, "d00001")
        assert found is not None
        assert found.packageId == pkg.packageId

    def test_return_none_for_req_not_in_any_package(self, tmp_path):
        """Should return None if REQ not in any package"""
        load_packages(tmp_path)

        found = get_package_for_req(tmp_path, "d99999")
        assert found is None


class TestOnStatusChangedToReview:
    """Test auto-add to package when status changes to Review"""

    def test_adds_to_default_package_when_no_active(self, tmp_path):
        """Should add REQ to default package when no active package"""
        load_packages(tmp_path)

        pkg = on_status_changed_to_review(tmp_path, "d00001", source='gui')

        assert pkg is not None
        assert pkg.isDefault is True
        assert "d00001" in pkg.reqIds

    def test_adds_to_active_package_when_set(self, tmp_path):
        """Should add REQ to active package when one is set"""
        active_pkg = create_package(tmp_path, "Active", "Active package", "user")
        set_active_package(tmp_path, active_pkg.packageId)

        pkg = on_status_changed_to_review(tmp_path, "d00002", source='gui')

        assert pkg is not None
        assert pkg.packageId == active_pkg.packageId
        assert "d00002" in pkg.reqIds

    def test_file_source_always_uses_default(self, tmp_path):
        """Should always use default package for file-based changes"""
        active_pkg = create_package(tmp_path, "Active", "Active package", "user")
        set_active_package(tmp_path, active_pkg.packageId)

        pkg = on_status_changed_to_review(tmp_path, "d00003", source='file')

        assert pkg is not None
        assert pkg.isDefault is True
        assert "d00003" in pkg.reqIds

    def test_returns_none_if_already_in_package(self, tmp_path):
        """Should return None if REQ is already in a package"""
        other_pkg = create_package(tmp_path, "Other", "Other package", "user")
        add_req_to_package(tmp_path, other_pkg.packageId, "d00004")

        result = on_status_changed_to_review(tmp_path, "d00004", source='gui')

        assert result is None

    def test_does_not_duplicate_req_in_package(self, tmp_path):
        """Should not add duplicate REQ IDs"""
        load_packages(tmp_path)

        on_status_changed_to_review(tmp_path, "d00005", source='gui')
        on_status_changed_to_review(tmp_path, "d00005", source='gui')

        default = get_default_package(tmp_path)
        count = default.reqIds.count("d00005")
        assert count == 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
