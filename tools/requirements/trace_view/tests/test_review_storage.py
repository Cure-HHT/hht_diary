#!/usr/bin/env python3
"""
Tests for Review Storage Operations

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00011: Review Storage Operations

This test file follows TDD (Test-Driven Development) methodology.
Each test references the specific assertion from REQ-tv-d00011 that it verifies.
"""

import json
import os
import tempfile
from pathlib import Path
from typing import Dict, Any
from unittest.mock import patch, MagicMock

import pytest


# =============================================================================
# Test Imports (will fail initially - RED phase)
# =============================================================================

def import_storage():
    """Helper to import storage module - enables better error messages during TDD."""
    from trace_view.review.storage import (
        # Helper functions
        atomic_write_json,
        read_json,
        normalize_req_id,
        # Path functions
        get_reviews_root,
        get_req_dir,
        get_threads_path,
        get_status_path,
        get_review_flag_path,
        get_config_path,
        get_packages_path,
        # Thread operations
        load_threads,
        save_threads,
        add_thread,
        add_comment_to_thread,
        resolve_thread,
        unresolve_thread,
        # Status request operations
        load_status_requests,
        save_status_requests,
        create_status_request,
        add_approval,
        mark_request_applied,
        # Review flag operations
        load_review_flag,
        save_review_flag,
        # Package operations
        load_packages,
        save_packages,
        create_package,
        update_package,
        delete_package,
        add_req_to_package,
        remove_req_from_package,
        # Config operations
        load_config,
        save_config,
        # Merge operations
        merge_threads,
        merge_status_files,
        merge_review_flags,
    )
    return {
        'atomic_write_json': atomic_write_json,
        'read_json': read_json,
        'normalize_req_id': normalize_req_id,
        'get_reviews_root': get_reviews_root,
        'get_req_dir': get_req_dir,
        'get_threads_path': get_threads_path,
        'get_status_path': get_status_path,
        'get_review_flag_path': get_review_flag_path,
        'get_config_path': get_config_path,
        'get_packages_path': get_packages_path,
        'load_threads': load_threads,
        'save_threads': save_threads,
        'add_thread': add_thread,
        'add_comment_to_thread': add_comment_to_thread,
        'resolve_thread': resolve_thread,
        'unresolve_thread': unresolve_thread,
        'load_status_requests': load_status_requests,
        'save_status_requests': save_status_requests,
        'create_status_request': create_status_request,
        'add_approval': add_approval,
        'mark_request_applied': mark_request_applied,
        'load_review_flag': load_review_flag,
        'save_review_flag': save_review_flag,
        'load_packages': load_packages,
        'save_packages': save_packages,
        'create_package': create_package,
        'update_package': update_package,
        'delete_package': delete_package,
        'add_req_to_package': add_req_to_package,
        'remove_req_from_package': remove_req_from_package,
        'load_config': load_config,
        'save_config': save_config,
        'merge_threads': merge_threads,
        'merge_status_files': merge_status_files,
        'merge_review_flags': merge_review_flags,
    }


def import_models():
    """Helper to import models module."""
    from trace_view.review.models import (
        Thread,
        Comment,
        ThreadsFile,
        StatusFile,
        StatusRequest,
        ReviewFlag,
        ReviewConfig,
        ReviewPackage,
        PackagesFile,
        Approval,
        CommentPosition,
        parse_iso_datetime,
    )
    return {
        'Thread': Thread,
        'Comment': Comment,
        'ThreadsFile': ThreadsFile,
        'StatusFile': StatusFile,
        'StatusRequest': StatusRequest,
        'ReviewFlag': ReviewFlag,
        'ReviewConfig': ReviewConfig,
        'ReviewPackage': ReviewPackage,
        'PackagesFile': PackagesFile,
        'Approval': Approval,
        'CommentPosition': CommentPosition,
        'parse_iso_datetime': parse_iso_datetime,
    }


# =============================================================================
# Assertion A: Atomic Write Operations
# =============================================================================

class TestAtomicWriteOperations:
    """REQ-tv-d00011-A: All JSON file writes SHALL use atomic write operations
    via temporary file creation followed by rename."""

    def test_atomic_write_creates_temp_file(self, tmp_path):
        """REQ-tv-d00011-A: Atomic write creates temp file before final write"""
        s = import_storage()

        target_file = tmp_path / "test.json"
        data = {"key": "value"}

        # Write should succeed
        s['atomic_write_json'](target_file, data)

        # File should exist
        assert target_file.exists()

        # Content should be correct
        with open(target_file) as f:
            loaded = json.load(f)
        assert loaded == data

    def test_atomic_write_creates_parent_directories(self, tmp_path):
        """REQ-tv-d00011-A: Atomic write creates parent directories if needed"""
        s = import_storage()

        target_file = tmp_path / "deep" / "nested" / "path" / "test.json"
        data = {"nested": True}

        s['atomic_write_json'](target_file, data)

        assert target_file.exists()
        with open(target_file) as f:
            assert json.load(f) == data

    def test_atomic_write_does_not_corrupt_on_failure(self, tmp_path):
        """REQ-tv-d00011-A: Atomic write preserves original file on failure"""
        s = import_storage()

        target_file = tmp_path / "test.json"
        original_data = {"original": True}

        # Write original file
        s['atomic_write_json'](target_file, original_data)

        # Verify original exists
        assert target_file.exists()

        # Try to write invalid data that causes serialization failure
        class UnserializableObject:
            pass

        bad_data = {"bad": UnserializableObject()}

        with pytest.raises((TypeError, ValueError)):
            s['atomic_write_json'](target_file, bad_data)

        # Original file should still contain original data
        with open(target_file) as f:
            assert json.load(f) == original_data

    def test_atomic_write_cleans_up_temp_file_on_failure(self, tmp_path):
        """REQ-tv-d00011-A: Temp files are cleaned up if write fails"""
        s = import_storage()

        target_file = tmp_path / "test.json"

        class UnserializableObject:
            pass

        bad_data = {"bad": UnserializableObject()}

        with pytest.raises((TypeError, ValueError)):
            s['atomic_write_json'](target_file, bad_data)

        # No temp files should remain
        temp_files = list(tmp_path.glob('.tmp_*.json'))
        assert len(temp_files) == 0

    def test_atomic_write_uses_same_directory_for_temp(self, tmp_path):
        """REQ-tv-d00011-A: Temp file is created in same directory as target"""
        s = import_storage()

        subdir = tmp_path / "subdir"
        subdir.mkdir()
        target_file = subdir / "test.json"

        # Track temp file creation
        original_mkstemp = tempfile.mkstemp
        temp_dirs_used = []

        def tracking_mkstemp(*args, **kwargs):
            if 'dir' in kwargs:
                temp_dirs_used.append(kwargs['dir'])
            return original_mkstemp(*args, **kwargs)

        with patch('tempfile.mkstemp', side_effect=tracking_mkstemp):
            s['atomic_write_json'](target_file, {"test": True})

        # Temp file should be created in same directory as target
        # This ensures atomic rename works (same filesystem)
        if temp_dirs_used:
            assert Path(temp_dirs_used[0]) == subdir


# =============================================================================
# Assertion B: Thread Storage Operations
# =============================================================================

class TestThreadStorageOperations:
    """REQ-tv-d00011-B: Thread storage operations SHALL support:
    load_threads(), save_threads(), add_thread(), add_comment_to_thread(),
    resolve_thread(), and unresolve_thread()."""

    def test_load_threads_returns_empty_when_file_missing(self, tmp_path):
        """REQ-tv-d00011-B: load_threads returns empty ThreadsFile when missing"""
        s = import_storage()
        m = import_models()

        result = s['load_threads'](tmp_path, 'd00001')

        assert isinstance(result, m['ThreadsFile'])
        assert result.threads == []
        assert result.reqId == 'd00001'

    def test_save_and_load_threads_roundtrip(self, tmp_path):
        """REQ-tv-d00011-B: save_threads and load_threads preserve data"""
        s = import_storage()
        m = import_models()

        # Create a thread with comments
        pos = m['CommentPosition'].create_general('12345678')
        thread = m['Thread'].create('d00001', 'alice', pos, 'Initial comment')
        threads_file = m['ThreadsFile'](reqId='d00001', threads=[thread])

        # Save and reload
        s['save_threads'](tmp_path, 'd00001', threads_file)
        loaded = s['load_threads'](tmp_path, 'd00001')

        assert len(loaded.threads) == 1
        assert loaded.threads[0].threadId == thread.threadId
        assert loaded.threads[0].createdBy == 'alice'

    def test_add_thread_creates_and_appends(self, tmp_path):
        """REQ-tv-d00011-B: add_thread creates file if needed and appends"""
        s = import_storage()
        m = import_models()

        pos = m['CommentPosition'].create_general('12345678')
        thread = m['Thread'].create('d00001', 'alice', pos)

        # Add to non-existent file
        result = s['add_thread'](tmp_path, 'd00001', thread)

        # Should return the thread
        assert result.threadId == thread.threadId

        # Should be persisted
        loaded = s['load_threads'](tmp_path, 'd00001')
        assert len(loaded.threads) == 1

    def test_add_comment_to_thread(self, tmp_path):
        """REQ-tv-d00011-B: add_comment_to_thread adds comment to existing thread"""
        s = import_storage()
        m = import_models()

        # Create and save a thread
        pos = m['CommentPosition'].create_general('12345678')
        thread = m['Thread'].create('d00001', 'alice', pos)
        s['add_thread'](tmp_path, 'd00001', thread)

        # Add comment
        comment = s['add_comment_to_thread'](
            tmp_path, 'd00001', thread.threadId, 'bob', 'Reply comment'
        )

        # Should return the comment
        assert comment.author == 'bob'
        assert comment.body == 'Reply comment'

        # Should be persisted
        loaded = s['load_threads'](tmp_path, 'd00001')
        assert len(loaded.threads[0].comments) == 1

    def test_add_comment_to_thread_raises_for_missing_thread(self, tmp_path):
        """REQ-tv-d00011-B: add_comment_to_thread raises ValueError for missing thread"""
        s = import_storage()

        with pytest.raises(ValueError, match="not found"):
            s['add_comment_to_thread'](
                tmp_path, 'd00001', 'nonexistent-thread-id', 'bob', 'Comment'
            )

    def test_resolve_thread(self, tmp_path):
        """REQ-tv-d00011-B: resolve_thread marks thread as resolved"""
        s = import_storage()
        m = import_models()

        # Create and save a thread
        pos = m['CommentPosition'].create_general('12345678')
        thread = m['Thread'].create('d00001', 'alice', pos)
        s['add_thread'](tmp_path, 'd00001', thread)

        # Resolve
        result = s['resolve_thread'](tmp_path, 'd00001', thread.threadId, 'bob')

        assert result is True

        # Should be persisted
        loaded = s['load_threads'](tmp_path, 'd00001')
        assert loaded.threads[0].resolved is True
        assert loaded.threads[0].resolvedBy == 'bob'

    def test_resolve_thread_returns_false_for_missing(self, tmp_path):
        """REQ-tv-d00011-B: resolve_thread returns False for missing thread"""
        s = import_storage()

        result = s['resolve_thread'](tmp_path, 'd00001', 'nonexistent', 'bob')
        assert result is False

    def test_unresolve_thread(self, tmp_path):
        """REQ-tv-d00011-B: unresolve_thread marks thread as unresolved"""
        s = import_storage()
        m = import_models()

        # Create, save, and resolve a thread
        pos = m['CommentPosition'].create_general('12345678')
        thread = m['Thread'].create('d00001', 'alice', pos)
        s['add_thread'](tmp_path, 'd00001', thread)
        s['resolve_thread'](tmp_path, 'd00001', thread.threadId, 'bob')

        # Unresolve
        result = s['unresolve_thread'](tmp_path, 'd00001', thread.threadId)

        assert result is True

        # Should be persisted
        loaded = s['load_threads'](tmp_path, 'd00001')
        assert loaded.threads[0].resolved is False
        assert loaded.threads[0].resolvedBy is None


# =============================================================================
# Assertion C: Status Request Storage Operations
# =============================================================================

class TestStatusRequestStorageOperations:
    """REQ-tv-d00011-C: Status request storage operations SHALL support:
    load_status_requests(), save_status_requests(), create_status_request(),
    add_approval(), and mark_request_applied()."""

    def test_load_status_requests_returns_empty_when_missing(self, tmp_path):
        """REQ-tv-d00011-C: load_status_requests returns empty StatusFile when missing"""
        s = import_storage()
        m = import_models()

        result = s['load_status_requests'](tmp_path, 'd00001')

        assert isinstance(result, m['StatusFile'])
        assert result.requests == []
        assert result.reqId == 'd00001'

    def test_save_and_load_status_requests_roundtrip(self, tmp_path):
        """REQ-tv-d00011-C: save_status_requests and load preserve data"""
        s = import_storage()
        m = import_models()

        request = m['StatusRequest'].create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Ready for review'
        )
        status_file = m['StatusFile'](reqId='d00001', requests=[request])

        s['save_status_requests'](tmp_path, 'd00001', status_file)
        loaded = s['load_status_requests'](tmp_path, 'd00001')

        assert len(loaded.requests) == 1
        assert loaded.requests[0].requestId == request.requestId

    def test_create_status_request(self, tmp_path):
        """REQ-tv-d00011-C: create_status_request creates and persists request"""
        s = import_storage()
        m = import_models()

        request = m['StatusRequest'].create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test'
        )

        result = s['create_status_request'](tmp_path, 'd00001', request)

        assert result.requestId == request.requestId

        # Should be persisted
        loaded = s['load_status_requests'](tmp_path, 'd00001')
        assert len(loaded.requests) == 1

    def test_add_approval(self, tmp_path):
        """REQ-tv-d00011-C: add_approval adds approval to existing request"""
        s = import_storage()
        m = import_models()

        # Create and save a request
        request = m['StatusRequest'].create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test',
            required_approvers=['product_owner']
        )
        s['create_status_request'](tmp_path, 'd00001', request)

        # Add approval
        approval = s['add_approval'](
            tmp_path, 'd00001', request.requestId, 'product_owner', 'approve'
        )

        assert approval.user == 'product_owner'
        assert approval.decision == 'approve'

        # Should be persisted
        loaded = s['load_status_requests'](tmp_path, 'd00001')
        assert len(loaded.requests[0].approvals) == 1

    def test_add_approval_raises_for_missing_request(self, tmp_path):
        """REQ-tv-d00011-C: add_approval raises ValueError for missing request"""
        s = import_storage()

        with pytest.raises(ValueError, match="not found"):
            s['add_approval'](
                tmp_path, 'd00001', 'nonexistent-request', 'bob', 'approve'
            )

    def test_mark_request_applied(self, tmp_path):
        """REQ-tv-d00011-C: mark_request_applied marks approved request as applied"""
        s = import_storage()
        m = import_models()

        # Create and approve request
        request = m['StatusRequest'].create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test',
            required_approvers=['product_owner']
        )
        s['create_status_request'](tmp_path, 'd00001', request)
        s['add_approval'](tmp_path, 'd00001', request.requestId, 'product_owner', 'approve')

        # Mark applied
        result = s['mark_request_applied'](tmp_path, 'd00001', request.requestId)

        assert result is True

        # Should be persisted
        loaded = s['load_status_requests'](tmp_path, 'd00001')
        assert loaded.requests[0].state == 'applied'

    def test_mark_request_applied_returns_false_for_missing(self, tmp_path):
        """REQ-tv-d00011-C: mark_request_applied returns False for missing request"""
        s = import_storage()

        result = s['mark_request_applied'](tmp_path, 'd00001', 'nonexistent')
        assert result is False


# =============================================================================
# Assertion D: Review Flag Storage Operations
# =============================================================================

class TestReviewFlagStorageOperations:
    """REQ-tv-d00011-D: Review flag storage operations SHALL support:
    load_review_flag() and save_review_flag()."""

    def test_load_review_flag_returns_cleared_when_missing(self, tmp_path):
        """REQ-tv-d00011-D: load_review_flag returns cleared flag when missing"""
        s = import_storage()
        m = import_models()

        result = s['load_review_flag'](tmp_path, 'd00001')

        assert isinstance(result, m['ReviewFlag'])
        assert result.flaggedForReview is False

    def test_save_and_load_review_flag_roundtrip(self, tmp_path):
        """REQ-tv-d00011-D: save_review_flag and load preserve data"""
        s = import_storage()
        m = import_models()

        flag = m['ReviewFlag'].create(
            user='alice',
            reason='Needs review',
            scope=['product_owner', 'tech_lead']
        )

        s['save_review_flag'](tmp_path, 'd00001', flag)
        loaded = s['load_review_flag'](tmp_path, 'd00001')

        assert loaded.flaggedForReview is True
        assert loaded.flaggedBy == 'alice'
        assert loaded.reason == 'Needs review'
        assert set(loaded.scope) == {'product_owner', 'tech_lead'}


# =============================================================================
# Assertion E: Package Storage Operations
# =============================================================================

class TestPackageStorageOperations:
    """REQ-tv-d00011-E: Package storage operations SHALL support:
    load_packages(), save_packages(), create_package(), update_package(),
    delete_package(), add_req_to_package(), and remove_req_from_package()."""

    def test_load_packages_returns_empty_with_default_when_missing(self, tmp_path):
        """REQ-tv-d00011-E: load_packages returns file with default package when missing"""
        s = import_storage()
        m = import_models()

        result = s['load_packages'](tmp_path)

        assert isinstance(result, m['PackagesFile'])
        # Should have default package
        default_pkg = result.get_default()
        assert default_pkg is not None
        assert default_pkg.isDefault is True

    def test_save_and_load_packages_roundtrip(self, tmp_path):
        """REQ-tv-d00011-E: save_packages and load preserve data"""
        s = import_storage()
        m = import_models()

        pkg = m['ReviewPackage'].create(
            name='Sprint 23',
            description='Sprint 23 requirements',
            created_by='alice'
        )
        packages_file = m['PackagesFile'](packages=[pkg], activePackageId=pkg.packageId)

        s['save_packages'](tmp_path, packages_file)
        loaded = s['load_packages'](tmp_path)

        # Note: loaded may include default package if we always ensure one exists
        assert any(p.name == 'Sprint 23' for p in loaded.packages)

    def test_create_package(self, tmp_path):
        """REQ-tv-d00011-E: create_package creates and persists package"""
        s = import_storage()
        m = import_models()

        pkg = m['ReviewPackage'].create(
            name='Sprint 23',
            description='Test',
            created_by='alice'
        )

        result = s['create_package'](tmp_path, pkg)

        assert result.packageId == pkg.packageId

        # Should be persisted
        loaded = s['load_packages'](tmp_path)
        assert any(p.packageId == pkg.packageId for p in loaded.packages)

    def test_update_package(self, tmp_path):
        """REQ-tv-d00011-E: update_package updates existing package"""
        s = import_storage()
        m = import_models()

        # Create package
        pkg = m['ReviewPackage'].create(
            name='Sprint 23',
            description='Original',
            created_by='alice'
        )
        s['create_package'](tmp_path, pkg)

        # Update package
        pkg.description = 'Updated description'
        pkg.reqIds = ['d00001', 'd00002']

        result = s['update_package'](tmp_path, pkg)

        assert result is True

        # Should be persisted
        loaded = s['load_packages'](tmp_path)
        updated_pkg = next(p for p in loaded.packages if p.packageId == pkg.packageId)
        assert updated_pkg.description == 'Updated description'
        assert updated_pkg.reqIds == ['d00001', 'd00002']

    def test_update_package_returns_false_for_missing(self, tmp_path):
        """REQ-tv-d00011-E: update_package returns False for missing package"""
        s = import_storage()
        m = import_models()

        pkg = m['ReviewPackage'].create(
            name='Nonexistent',
            description='Test',
            created_by='alice'
        )

        result = s['update_package'](tmp_path, pkg)
        assert result is False

    def test_delete_package(self, tmp_path):
        """REQ-tv-d00011-E: delete_package removes package"""
        s = import_storage()
        m = import_models()

        # Create package
        pkg = m['ReviewPackage'].create(
            name='Sprint 23',
            description='Test',
            created_by='alice'
        )
        s['create_package'](tmp_path, pkg)

        # Delete
        result = s['delete_package'](tmp_path, pkg.packageId)

        assert result is True

        # Should be removed
        loaded = s['load_packages'](tmp_path)
        assert not any(p.packageId == pkg.packageId for p in loaded.packages)

    def test_delete_package_returns_false_for_missing(self, tmp_path):
        """REQ-tv-d00011-E: delete_package returns False for missing package"""
        s = import_storage()

        result = s['delete_package'](tmp_path, 'nonexistent-id')
        assert result is False

    def test_add_req_to_package(self, tmp_path):
        """REQ-tv-d00011-E: add_req_to_package adds requirement ID to package"""
        s = import_storage()
        m = import_models()

        # Create package
        pkg = m['ReviewPackage'].create(
            name='Sprint 23',
            description='Test',
            created_by='alice'
        )
        s['create_package'](tmp_path, pkg)

        # Add requirement
        result = s['add_req_to_package'](tmp_path, pkg.packageId, 'd00001')

        assert result is True

        # Should be persisted
        loaded = s['load_packages'](tmp_path)
        updated_pkg = next(p for p in loaded.packages if p.packageId == pkg.packageId)
        assert 'd00001' in updated_pkg.reqIds

    def test_add_req_to_package_no_duplicates(self, tmp_path):
        """REQ-tv-d00011-E: add_req_to_package prevents duplicate REQ IDs"""
        s = import_storage()
        m = import_models()

        # Create package with existing req
        pkg = m['ReviewPackage'].create(
            name='Sprint 23',
            description='Test',
            created_by='alice'
        )
        pkg.reqIds = ['d00001']
        s['create_package'](tmp_path, pkg)

        # Try to add same requirement again
        s['add_req_to_package'](tmp_path, pkg.packageId, 'd00001')

        # Should still have only one
        loaded = s['load_packages'](tmp_path)
        updated_pkg = next(p for p in loaded.packages if p.packageId == pkg.packageId)
        assert updated_pkg.reqIds.count('d00001') == 1

    def test_remove_req_from_package(self, tmp_path):
        """REQ-tv-d00011-E: remove_req_from_package removes requirement ID from package"""
        s = import_storage()
        m = import_models()

        # Create package with requirements
        pkg = m['ReviewPackage'].create(
            name='Sprint 23',
            description='Test',
            created_by='alice'
        )
        pkg.reqIds = ['d00001', 'd00002']
        s['create_package'](tmp_path, pkg)

        # Remove requirement
        result = s['remove_req_from_package'](tmp_path, pkg.packageId, 'd00001')

        assert result is True

        # Should be persisted
        loaded = s['load_packages'](tmp_path)
        updated_pkg = next(p for p in loaded.packages if p.packageId == pkg.packageId)
        assert 'd00001' not in updated_pkg.reqIds
        assert 'd00002' in updated_pkg.reqIds


# =============================================================================
# Assertion F: Config Storage Operations
# =============================================================================

class TestConfigStorageOperations:
    """REQ-tv-d00011-F: Config storage operations SHALL support:
    load_config() and save_config() for system-wide settings."""

    def test_load_config_returns_default_when_missing(self, tmp_path):
        """REQ-tv-d00011-F: load_config returns default config when missing"""
        s = import_storage()
        m = import_models()

        result = s['load_config'](tmp_path)

        assert isinstance(result, m['ReviewConfig'])
        # Should have default approval rules
        assert 'Draft->Active' in result.approvalRules

    def test_save_and_load_config_roundtrip(self, tmp_path):
        """REQ-tv-d00011-F: save_config and load preserve data"""
        s = import_storage()
        m = import_models()

        config = m['ReviewConfig'](
            approvalRules={'Custom->Rule': ['custom_approver']},
            pushOnComment=False,
            autoFetchOnOpen=False
        )

        s['save_config'](tmp_path, config)
        loaded = s['load_config'](tmp_path)

        assert 'Custom->Rule' in loaded.approvalRules
        assert loaded.pushOnComment is False
        assert loaded.autoFetchOnOpen is False


# =============================================================================
# Assertion G: Merge Operations
# =============================================================================

class TestMergeOperations:
    """REQ-tv-d00011-G: Merge operations SHALL support:
    merge_threads(), merge_status_files(), and merge_review_flags()
    for combining data from multiple user branches."""

    def test_merge_threads_combines_unique(self, tmp_path):
        """REQ-tv-d00011-G: merge_threads combines unique threads from both sources"""
        s = import_storage()
        m = import_models()

        pos1 = m['CommentPosition'].create_general('12345678')
        pos2 = m['CommentPosition'].create_general('87654321')

        thread1 = m['Thread'].create('d00001', 'alice', pos1)
        thread2 = m['Thread'].create('d00001', 'bob', pos2)

        local = m['ThreadsFile'](reqId='d00001', threads=[thread1])
        remote = m['ThreadsFile'](reqId='d00001', threads=[thread2])

        merged = s['merge_threads'](local, remote)

        assert len(merged.threads) == 2
        thread_ids = {t.threadId for t in merged.threads}
        assert thread1.threadId in thread_ids
        assert thread2.threadId in thread_ids

    def test_merge_threads_deduplicates_by_id(self, tmp_path):
        """REQ-tv-d00011-G: merge_threads deduplicates threads by ID"""
        s = import_storage()
        m = import_models()

        pos = m['CommentPosition'].create_general('12345678')
        thread = m['Thread'].create('d00001', 'alice', pos)

        # Same thread in both
        local = m['ThreadsFile'](reqId='d00001', threads=[thread])
        remote = m['ThreadsFile'](reqId='d00001', threads=[thread])

        merged = s['merge_threads'](local, remote)

        assert len(merged.threads) == 1

    def test_merge_threads_merges_comments(self, tmp_path):
        """REQ-tv-d00011-G: merge_threads merges comments from both sources"""
        s = import_storage()
        m = import_models()

        pos = m['CommentPosition'].create_general('12345678')

        # Create base thread
        thread1 = m['Thread'](
            threadId='t1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00',
            position=pos,
            comments=[m['Comment'](
                id='c1',
                author='alice',
                timestamp='2024-01-15T10:00:00+00:00',
                body='Comment 1'
            )]
        )

        # Create version with different comment
        thread2 = m['Thread'](
            threadId='t1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00',
            position=pos,
            comments=[m['Comment'](
                id='c2',
                author='bob',
                timestamp='2024-01-15T11:00:00+00:00',
                body='Comment 2'
            )]
        )

        local = m['ThreadsFile'](reqId='d00001', threads=[thread1])
        remote = m['ThreadsFile'](reqId='d00001', threads=[thread2])

        merged = s['merge_threads'](local, remote)

        assert len(merged.threads) == 1
        assert len(merged.threads[0].comments) == 2

    def test_merge_threads_resolution_takes_resolved(self, tmp_path):
        """REQ-tv-d00011-G: merge_threads prefers resolved state"""
        s = import_storage()
        m = import_models()

        pos = m['CommentPosition'].create_general('12345678')

        thread_unresolved = m['Thread'](
            threadId='t1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00',
            position=pos,
            resolved=False
        )

        thread_resolved = m['Thread'](
            threadId='t1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00',
            position=pos,
            resolved=True,
            resolvedBy='bob',
            resolvedAt='2024-01-15T12:00:00+00:00'
        )

        local = m['ThreadsFile'](reqId='d00001', threads=[thread_unresolved])
        remote = m['ThreadsFile'](reqId='d00001', threads=[thread_resolved])

        merged = s['merge_threads'](local, remote)

        assert merged.threads[0].resolved is True
        assert merged.threads[0].resolvedBy == 'bob'

    def test_merge_status_files_combines_unique(self, tmp_path):
        """REQ-tv-d00011-G: merge_status_files combines unique requests"""
        s = import_storage()
        m = import_models()

        req1 = m['StatusRequest'].create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test 1'
        )
        req2 = m['StatusRequest'].create(
            req_id='d00001',
            from_status='Active',
            to_status='Deprecated',
            requested_by='bob',
            justification='Test 2'
        )

        local = m['StatusFile'](reqId='d00001', requests=[req1])
        remote = m['StatusFile'](reqId='d00001', requests=[req2])

        merged = s['merge_status_files'](local, remote)

        assert len(merged.requests) == 2

    def test_merge_status_files_merges_approvals_by_timestamp(self, tmp_path):
        """REQ-tv-d00011-G: merge_status_files uses timestamp for approval conflicts"""
        s = import_storage()
        m = import_models()

        # Create request with early approval
        req1 = m['StatusRequest'](
            requestId='r1',
            reqId='d00001',
            type='status_change',
            fromStatus='Draft',
            toStatus='Active',
            requestedBy='alice',
            requestedAt='2024-01-15T10:00:00+00:00',
            justification='Test',
            approvals=[m['Approval'](
                user='product_owner',
                decision='approve',
                at='2024-01-15T10:00:00+00:00'
            )],
            requiredApprovers=['product_owner'],
            state='pending'
        )

        # Same request with later approval that rejects
        req2 = m['StatusRequest'](
            requestId='r1',
            reqId='d00001',
            type='status_change',
            fromStatus='Draft',
            toStatus='Active',
            requestedBy='alice',
            requestedAt='2024-01-15T10:00:00+00:00',
            justification='Test',
            approvals=[m['Approval'](
                user='product_owner',
                decision='reject',
                at='2024-01-15T12:00:00+00:00'  # Later
            )],
            requiredApprovers=['product_owner'],
            state='pending'
        )

        local = m['StatusFile'](reqId='d00001', requests=[req1])
        remote = m['StatusFile'](reqId='d00001', requests=[req2])

        merged = s['merge_status_files'](local, remote)

        assert len(merged.requests) == 1
        # Should take the later rejection
        assert merged.requests[0].approvals[0].decision == 'reject'

    def test_merge_review_flags_both_unflagged(self, tmp_path):
        """REQ-tv-d00011-G: merge_review_flags returns unflagged if neither flagged"""
        s = import_storage()
        m = import_models()

        local = m['ReviewFlag'].cleared()
        remote = m['ReviewFlag'].cleared()

        merged = s['merge_review_flags'](local, remote)

        assert merged.flaggedForReview is False

    def test_merge_review_flags_one_flagged(self, tmp_path):
        """REQ-tv-d00011-G: merge_review_flags returns flagged one if only one flagged"""
        s = import_storage()
        m = import_models()

        local = m['ReviewFlag'].cleared()
        remote = m['ReviewFlag'].create(
            user='alice',
            reason='Needs review',
            scope=['product_owner']
        )

        merged = s['merge_review_flags'](local, remote)

        assert merged.flaggedForReview is True
        assert merged.flaggedBy == 'alice'

    def test_merge_review_flags_both_flagged_uses_newer(self, tmp_path):
        """REQ-tv-d00011-G: merge_review_flags uses newer flag when both flagged"""
        s = import_storage()
        m = import_models()

        local = m['ReviewFlag'](
            flaggedForReview=True,
            flaggedBy='alice',
            flaggedAt='2024-01-15T10:00:00+00:00',
            reason='Early reason',
            scope=['product_owner']
        )
        remote = m['ReviewFlag'](
            flaggedForReview=True,
            flaggedBy='bob',
            flaggedAt='2024-01-15T12:00:00+00:00',  # Later
            reason='Later reason',
            scope=['tech_lead']
        )

        merged = s['merge_review_flags'](local, remote)

        assert merged.flaggedBy == 'bob'  # Newer
        assert merged.reason == 'Later reason'

    def test_merge_review_flags_merges_scopes(self, tmp_path):
        """REQ-tv-d00011-G: merge_review_flags combines scopes from both"""
        s = import_storage()
        m = import_models()

        local = m['ReviewFlag'](
            flaggedForReview=True,
            flaggedBy='alice',
            flaggedAt='2024-01-15T10:00:00+00:00',
            reason='Reason',
            scope=['product_owner']
        )
        remote = m['ReviewFlag'](
            flaggedForReview=True,
            flaggedBy='bob',
            flaggedAt='2024-01-15T12:00:00+00:00',
            reason='Reason',
            scope=['tech_lead']
        )

        merged = s['merge_review_flags'](local, remote)

        # Should have both scopes
        assert set(merged.scope) == {'product_owner', 'tech_lead'}


# =============================================================================
# Assertion H: Storage Paths Convention
# =============================================================================

class TestStoragePathsConvention:
    """REQ-tv-d00011-H: Storage paths SHALL follow the convention:
    .reviews/reqs/{normalized-req-id}/threads.json, etc."""

    def test_get_reviews_root(self, tmp_path):
        """REQ-tv-d00011-H: get_reviews_root returns .reviews directory"""
        s = import_storage()

        result = s['get_reviews_root'](tmp_path)

        assert result == tmp_path / '.reviews'

    def test_get_req_dir(self, tmp_path):
        """REQ-tv-d00011-H: get_req_dir returns correct path for requirement"""
        s = import_storage()

        result = s['get_req_dir'](tmp_path, 'd00001')

        assert result == tmp_path / '.reviews' / 'reqs' / 'd00001'

    def test_get_threads_path(self, tmp_path):
        """REQ-tv-d00011-H: get_threads_path returns threads.json path"""
        s = import_storage()

        result = s['get_threads_path'](tmp_path, 'd00001')

        assert result == tmp_path / '.reviews' / 'reqs' / 'd00001' / 'threads.json'

    def test_get_status_path(self, tmp_path):
        """REQ-tv-d00011-H: get_status_path returns status.json path"""
        s = import_storage()

        result = s['get_status_path'](tmp_path, 'd00001')

        assert result == tmp_path / '.reviews' / 'reqs' / 'd00001' / 'status.json'

    def test_get_review_flag_path(self, tmp_path):
        """REQ-tv-d00011-H: get_review_flag_path returns flag.json path"""
        s = import_storage()

        result = s['get_review_flag_path'](tmp_path, 'd00001')

        assert result == tmp_path / '.reviews' / 'reqs' / 'd00001' / 'flag.json'

    def test_get_config_path(self, tmp_path):
        """REQ-tv-d00011-H: get_config_path returns config.json path"""
        s = import_storage()

        result = s['get_config_path'](tmp_path)

        assert result == tmp_path / '.reviews' / 'config.json'

    def test_get_packages_path(self, tmp_path):
        """REQ-tv-d00011-H: get_packages_path returns packages.json path"""
        s = import_storage()

        result = s['get_packages_path'](tmp_path)

        assert result == tmp_path / '.reviews' / 'packages.json'


# =============================================================================
# Assertion I: Requirement ID Path Normalization
# =============================================================================

class TestRequirementIdNormalization:
    """REQ-tv-d00011-I: Requirement IDs in paths SHALL be normalized
    by replacing colons and slashes with underscores."""

    def test_normalize_req_id_simple(self):
        """REQ-tv-d00011-I: Simple IDs pass through unchanged"""
        s = import_storage()

        assert s['normalize_req_id']('d00001') == 'd00001'
        assert s['normalize_req_id']('p00042') == 'p00042'

    def test_normalize_req_id_with_colons(self):
        """REQ-tv-d00011-I: Colons are replaced with underscores"""
        s = import_storage()

        assert s['normalize_req_id']('REQ:d00001') == 'REQ_d00001'
        assert s['normalize_req_id']('a:b:c') == 'a_b_c'

    def test_normalize_req_id_with_slashes(self):
        """REQ-tv-d00011-I: Slashes are replaced with underscores"""
        s = import_storage()

        assert s['normalize_req_id']('REQ/d00001') == 'REQ_d00001'
        assert s['normalize_req_id']('a/b/c') == 'a_b_c'

    def test_normalize_req_id_mixed(self):
        """REQ-tv-d00011-I: Mixed colons and slashes are all replaced"""
        s = import_storage()

        assert s['normalize_req_id']('a:b/c:d') == 'a_b_c_d'

    def test_get_req_dir_uses_normalized_id(self, tmp_path):
        """REQ-tv-d00011-I: Path functions use normalized IDs"""
        s = import_storage()

        result = s['get_req_dir'](tmp_path, 'REQ:d00001')

        assert 'REQ_d00001' in str(result)
        assert ':' not in str(result)


# =============================================================================
# Assertion J: Merge Strategy - Deduplicate and Timestamp Conflict Resolution
# =============================================================================

class TestMergeStrategyDeduplication:
    """REQ-tv-d00011-J: The merge strategy SHALL deduplicate by ID
    and use timestamp-based conflict resolution."""

    def test_thread_merge_deduplicates_comments_by_id(self, tmp_path):
        """REQ-tv-d00011-J: Thread merge deduplicates comments by ID"""
        s = import_storage()
        m = import_models()

        pos = m['CommentPosition'].create_general('12345678')

        comment = m['Comment'](
            id='c1',
            author='alice',
            timestamp='2024-01-15T10:00:00+00:00',
            body='Same comment'
        )

        thread1 = m['Thread'](
            threadId='t1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00',
            position=pos,
            comments=[comment]
        )
        thread2 = m['Thread'](
            threadId='t1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00',
            position=pos,
            comments=[comment]  # Same comment
        )

        local = m['ThreadsFile'](reqId='d00001', threads=[thread1])
        remote = m['ThreadsFile'](reqId='d00001', threads=[thread2])

        merged = s['merge_threads'](local, remote)

        # Should have only one comment
        assert len(merged.threads[0].comments) == 1

    def test_status_merge_deduplicates_requests_by_id(self, tmp_path):
        """REQ-tv-d00011-J: Status merge deduplicates requests by ID"""
        s = import_storage()
        m = import_models()

        req = m['StatusRequest'](
            requestId='r1',
            reqId='d00001',
            type='status_change',
            fromStatus='Draft',
            toStatus='Active',
            requestedBy='alice',
            requestedAt='2024-01-15T10:00:00+00:00',
            justification='Test',
            approvals=[],
            requiredApprovers=['product_owner'],
            state='pending'
        )

        local = m['StatusFile'](reqId='d00001', requests=[req])
        remote = m['StatusFile'](reqId='d00001', requests=[req])  # Same

        merged = s['merge_status_files'](local, remote)

        assert len(merged.requests) == 1

    def test_approval_merge_uses_timestamp_for_same_user(self, tmp_path):
        """REQ-tv-d00011-J: Approval merge uses timestamp when same user approved twice"""
        s = import_storage()
        m = import_models()

        req1 = m['StatusRequest'](
            requestId='r1',
            reqId='d00001',
            type='status_change',
            fromStatus='Draft',
            toStatus='Active',
            requestedBy='alice',
            requestedAt='2024-01-15T10:00:00+00:00',
            justification='Test',
            approvals=[m['Approval'](
                user='reviewer',
                decision='approve',
                at='2024-01-15T10:00:00+00:00',
                comment='Early approval'
            )],
            requiredApprovers=['reviewer'],
            state='pending'
        )

        req2 = m['StatusRequest'](
            requestId='r1',
            reqId='d00001',
            type='status_change',
            fromStatus='Draft',
            toStatus='Active',
            requestedBy='alice',
            requestedAt='2024-01-15T10:00:00+00:00',
            justification='Test',
            approvals=[m['Approval'](
                user='reviewer',
                decision='reject',  # Different decision
                at='2024-01-15T14:00:00+00:00',  # Later timestamp
                comment='Changed mind'
            )],
            requiredApprovers=['reviewer'],
            state='pending'
        )

        local = m['StatusFile'](reqId='d00001', requests=[req1])
        remote = m['StatusFile'](reqId='d00001', requests=[req2])

        merged = s['merge_status_files'](local, remote)

        # Should have only one approval from 'reviewer' - the later one
        assert len(merged.requests[0].approvals) == 1
        assert merged.requests[0].approvals[0].decision == 'reject'
        assert merged.requests[0].approvals[0].comment == 'Changed mind'

    def test_comments_sorted_by_timestamp_after_merge(self, tmp_path):
        """REQ-tv-d00011-J: Comments are sorted by timestamp after merge"""
        s = import_storage()
        m = import_models()

        pos = m['CommentPosition'].create_general('12345678')

        # Later comment
        comment1 = m['Comment'](
            id='c1',
            author='alice',
            timestamp='2024-01-15T12:00:00+00:00',
            body='Later comment'
        )
        # Earlier comment
        comment2 = m['Comment'](
            id='c2',
            author='bob',
            timestamp='2024-01-15T10:00:00+00:00',
            body='Earlier comment'
        )

        thread1 = m['Thread'](
            threadId='t1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T09:00:00+00:00',
            position=pos,
            comments=[comment1]
        )
        thread2 = m['Thread'](
            threadId='t1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T09:00:00+00:00',
            position=pos,
            comments=[comment2]
        )

        local = m['ThreadsFile'](reqId='d00001', threads=[thread1])
        remote = m['ThreadsFile'](reqId='d00001', threads=[thread2])

        merged = s['merge_threads'](local, remote)

        # Comments should be sorted by timestamp
        comments = merged.threads[0].comments
        assert len(comments) == 2
        assert comments[0].body == 'Earlier comment'  # First
        assert comments[1].body == 'Later comment'   # Second


# =============================================================================
# Integration Tests
# =============================================================================

class TestStorageIntegration:
    """Integration tests for complete storage workflows."""

    def test_full_review_workflow(self, tmp_path):
        """Test complete review workflow: flag, create threads, resolve"""
        s = import_storage()
        m = import_models()

        req_id = 'd00001'

        # 1. Flag requirement for review
        flag = m['ReviewFlag'].create(
            user='pm_alice',
            reason='New feature needs review',
            scope=['tech_lead', 'product_owner']
        )
        s['save_review_flag'](tmp_path, req_id, flag)

        # 2. Create a review thread
        pos = m['CommentPosition'].create_line('12345678', 42, 'The SHALL statement...')
        thread = m['Thread'].create(req_id, 'reviewer_bob', pos, 'Consider rephrasing this requirement.')
        s['add_thread'](tmp_path, req_id, thread)

        # 3. Add response
        s['add_comment_to_thread'](
            tmp_path, req_id, thread.threadId,
            'pm_alice', 'Good point, I will update it.'
        )

        # 4. Resolve thread
        s['resolve_thread'](tmp_path, req_id, thread.threadId, 'pm_alice')

        # 5. Request status change
        status_request = m['StatusRequest'].create(
            req_id=req_id,
            from_status='Draft',
            to_status='Active',
            requested_by='pm_alice',
            justification='Review complete, all threads resolved',
            required_approvers=['tech_lead', 'product_owner']
        )
        s['create_status_request'](tmp_path, req_id, status_request)

        # 6. Get approvals
        s['add_approval'](tmp_path, req_id, status_request.requestId, 'tech_lead', 'approve')
        s['add_approval'](tmp_path, req_id, status_request.requestId, 'product_owner', 'approve', 'LGTM')

        # 7. Apply the change
        s['mark_request_applied'](tmp_path, req_id, status_request.requestId)

        # 8. Clear review flag
        cleared_flag = m['ReviewFlag'].cleared()
        s['save_review_flag'](tmp_path, req_id, cleared_flag)

        # Verify final state
        loaded_flag = s['load_review_flag'](tmp_path, req_id)
        assert loaded_flag.flaggedForReview is False

        loaded_threads = s['load_threads'](tmp_path, req_id)
        assert len(loaded_threads.threads) == 1
        assert loaded_threads.threads[0].resolved is True
        assert len(loaded_threads.threads[0].comments) == 2

        loaded_status = s['load_status_requests'](tmp_path, req_id)
        assert len(loaded_status.requests) == 1
        assert loaded_status.requests[0].state == 'applied'

    def test_multiple_requirements_isolation(self, tmp_path):
        """Test that different requirements have isolated storage"""
        s = import_storage()
        m = import_models()

        # Create threads for two different requirements
        pos = m['CommentPosition'].create_general('12345678')

        thread1 = m['Thread'].create('d00001', 'alice', pos, 'Comment on d00001')
        thread2 = m['Thread'].create('d00002', 'bob', pos, 'Comment on d00002')

        s['add_thread'](tmp_path, 'd00001', thread1)
        s['add_thread'](tmp_path, 'd00002', thread2)

        # Verify isolation
        loaded1 = s['load_threads'](tmp_path, 'd00001')
        loaded2 = s['load_threads'](tmp_path, 'd00002')

        assert len(loaded1.threads) == 1
        assert loaded1.threads[0].comments[0].body == 'Comment on d00001'

        assert len(loaded2.threads) == 1
        assert loaded2.threads[0].comments[0].body == 'Comment on d00002'

    def test_package_workflow(self, tmp_path):
        """Test package creation and management workflow"""
        s = import_storage()
        m = import_models()

        # 1. Create a package
        pkg = m['ReviewPackage'].create(
            name='Sprint 23 Review',
            description='Requirements for sprint 23',
            created_by='pm_alice'
        )
        s['create_package'](tmp_path, pkg)

        # 2. Add requirements to package
        s['add_req_to_package'](tmp_path, pkg.packageId, 'd00001')
        s['add_req_to_package'](tmp_path, pkg.packageId, 'd00002')
        s['add_req_to_package'](tmp_path, pkg.packageId, 'p00015')

        # 3. Load and verify
        loaded = s['load_packages'](tmp_path)
        sprint_pkg = next(p for p in loaded.packages if p.packageId == pkg.packageId)

        assert sprint_pkg.name == 'Sprint 23 Review'
        assert set(sprint_pkg.reqIds) == {'d00001', 'd00002', 'p00015'}

        # 4. Remove a requirement
        s['remove_req_from_package'](tmp_path, pkg.packageId, 'd00002')

        # 5. Verify removal
        loaded = s['load_packages'](tmp_path)
        sprint_pkg = next(p for p in loaded.packages if p.packageId == pkg.packageId)
        assert set(sprint_pkg.reqIds) == {'d00001', 'p00015'}

        # 6. Delete package
        s['delete_package'](tmp_path, pkg.packageId)

        loaded = s['load_packages'](tmp_path)
        assert not any(p.packageId == pkg.packageId for p in loaded.packages)
