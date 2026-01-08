#!/usr/bin/env python3
"""
Tests for Review Data Models

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00010: Review Data Models

This test file follows TDD (Test-Driven Development) methodology.
Each test references the specific assertion from REQ-tv-d00010 that it verifies.
"""

import json
import re
import uuid
from datetime import datetime, timezone
from typing import Dict, Any

import pytest


# =============================================================================
# Test Imports (will fail initially - RED phase)
# =============================================================================

def import_models():
    """Helper to import models module - enables better error messages during TDD."""
    from trace_view.review.models import (
        # Enums (Assertion B)
        PositionType,
        RequestState,
        ApprovalDecision,
        # Dataclasses (Assertion A)
        CommentPosition,
        Comment,
        Thread,
        ReviewFlag,
        StatusRequest,
        Approval,
        ReviewSession,
        ReviewConfig,
        ReviewPackage,
        # Container classes (Assertion G)
        ThreadsFile,
        StatusFile,
        PackagesFile,
        # Utility functions
        generate_uuid,
        now_iso,
        validate_req_id,
        validate_hash,
    )
    return {
        'PositionType': PositionType,
        'RequestState': RequestState,
        'ApprovalDecision': ApprovalDecision,
        'CommentPosition': CommentPosition,
        'Comment': Comment,
        'Thread': Thread,
        'ReviewFlag': ReviewFlag,
        'StatusRequest': StatusRequest,
        'Approval': Approval,
        'ReviewSession': ReviewSession,
        'ReviewConfig': ReviewConfig,
        'ReviewPackage': ReviewPackage,
        'ThreadsFile': ThreadsFile,
        'StatusFile': StatusFile,
        'PackagesFile': PackagesFile,
        'generate_uuid': generate_uuid,
        'now_iso': now_iso,
        'validate_req_id': validate_req_id,
        'validate_hash': validate_hash,
    }


# =============================================================================
# Assertion B: String Enums for JSON Compatibility
# =============================================================================

class TestEnumsStringBased:
    """REQ-tv-d00010-B: PositionType, RequestState, and ApprovalDecision SHALL be
    implemented as string enums for JSON compatibility."""

    def test_position_type_is_string_enum(self):
        """REQ-tv-d00010-B: PositionType is a string enum"""
        m = import_models()
        PositionType = m['PositionType']

        # Verify it inherits from str (for JSON serialization)
        assert issubclass(PositionType, str)

        # Verify expected values
        assert PositionType.LINE == "line"
        assert PositionType.BLOCK == "block"
        assert PositionType.WORD == "word"
        assert PositionType.GENERAL == "general"

    def test_request_state_is_string_enum(self):
        """REQ-tv-d00010-B: RequestState is a string enum"""
        m = import_models()
        RequestState = m['RequestState']

        assert issubclass(RequestState, str)
        assert RequestState.PENDING == "pending"
        assert RequestState.APPROVED == "approved"
        assert RequestState.REJECTED == "rejected"
        assert RequestState.APPLIED == "applied"

    def test_approval_decision_is_string_enum(self):
        """REQ-tv-d00010-B: ApprovalDecision is a string enum"""
        m = import_models()
        ApprovalDecision = m['ApprovalDecision']

        assert issubclass(ApprovalDecision, str)
        assert ApprovalDecision.APPROVE == "approve"
        assert ApprovalDecision.REJECT == "reject"

    def test_enums_json_serializable(self):
        """REQ-tv-d00010-B: Enums serialize to JSON strings directly"""
        m = import_models()
        PositionType = m['PositionType']
        RequestState = m['RequestState']

        # Should serialize as plain strings
        data = {
            'position_type': PositionType.LINE,
            'state': RequestState.PENDING
        }
        json_str = json.dumps(data)
        assert '"line"' in json_str
        assert '"pending"' in json_str


# =============================================================================
# Assertion A: Dataclasses
# =============================================================================

class TestDataclassesExist:
    """REQ-tv-d00010-A: All review data types SHALL be implemented as dataclasses."""

    def test_comment_position_is_dataclass(self):
        """REQ-tv-d00010-A: CommentPosition is a dataclass"""
        m = import_models()
        from dataclasses import is_dataclass
        assert is_dataclass(m['CommentPosition'])

    def test_comment_is_dataclass(self):
        """REQ-tv-d00010-A: Comment is a dataclass"""
        m = import_models()
        from dataclasses import is_dataclass
        assert is_dataclass(m['Comment'])

    def test_thread_is_dataclass(self):
        """REQ-tv-d00010-A: Thread is a dataclass"""
        m = import_models()
        from dataclasses import is_dataclass
        assert is_dataclass(m['Thread'])

    def test_review_flag_is_dataclass(self):
        """REQ-tv-d00010-A: ReviewFlag is a dataclass"""
        m = import_models()
        from dataclasses import is_dataclass
        assert is_dataclass(m['ReviewFlag'])

    def test_status_request_is_dataclass(self):
        """REQ-tv-d00010-A: StatusRequest is a dataclass"""
        m = import_models()
        from dataclasses import is_dataclass
        assert is_dataclass(m['StatusRequest'])

    def test_approval_is_dataclass(self):
        """REQ-tv-d00010-A: Approval is a dataclass"""
        m = import_models()
        from dataclasses import is_dataclass
        assert is_dataclass(m['Approval'])

    def test_review_session_is_dataclass(self):
        """REQ-tv-d00010-A: ReviewSession is a dataclass"""
        m = import_models()
        from dataclasses import is_dataclass
        assert is_dataclass(m['ReviewSession'])

    def test_review_config_is_dataclass(self):
        """REQ-tv-d00010-A: ReviewConfig is a dataclass"""
        m = import_models()
        from dataclasses import is_dataclass
        assert is_dataclass(m['ReviewConfig'])

    def test_review_package_is_dataclass(self):
        """REQ-tv-d00010-A: ReviewPackage is a dataclass"""
        m = import_models()
        from dataclasses import is_dataclass
        assert is_dataclass(m['ReviewPackage'])


# =============================================================================
# Assertion C: to_dict() Methods
# =============================================================================

class TestToDictMethods:
    """REQ-tv-d00010-C: Each dataclass SHALL implement a to_dict() method
    returning a JSON-serializable dictionary."""

    def test_comment_position_to_dict(self):
        """REQ-tv-d00010-C: CommentPosition.to_dict() returns JSON-serializable dict"""
        m = import_models()
        CommentPosition = m['CommentPosition']
        PositionType = m['PositionType']

        pos = CommentPosition(
            type=PositionType.LINE.value,
            hashWhenCreated="abc12345",
            lineNumber=42
        )
        d = pos.to_dict()

        assert isinstance(d, dict)
        assert d['type'] == 'line'
        assert d['hashWhenCreated'] == 'abc12345'
        assert d['lineNumber'] == 42

        # Must be JSON serializable
        json_str = json.dumps(d)
        assert '"line"' in json_str

    def test_comment_to_dict(self):
        """REQ-tv-d00010-C: Comment.to_dict() returns JSON-serializable dict"""
        m = import_models()
        Comment = m['Comment']

        comment = Comment(
            id="test-id",
            author="alice",
            timestamp="2024-01-15T10:00:00+00:00",
            body="Test comment"
        )
        d = comment.to_dict()

        assert d['id'] == 'test-id'
        assert d['author'] == 'alice'
        assert d['body'] == 'Test comment'
        json.dumps(d)  # Must not raise

    def test_thread_to_dict(self):
        """REQ-tv-d00010-C: Thread.to_dict() returns JSON-serializable dict"""
        m = import_models()
        Thread = m['Thread']
        CommentPosition = m['CommentPosition']

        pos = CommentPosition(type='general', hashWhenCreated='12345678')
        thread = Thread(
            threadId='thread-1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00',
            position=pos
        )
        d = thread.to_dict()

        assert d['threadId'] == 'thread-1'
        assert d['reqId'] == 'd00001'
        assert 'position' in d
        assert isinstance(d['position'], dict)
        json.dumps(d)

    def test_review_flag_to_dict(self):
        """REQ-tv-d00010-C: ReviewFlag.to_dict() returns JSON-serializable dict"""
        m = import_models()
        ReviewFlag = m['ReviewFlag']

        flag = ReviewFlag(
            flaggedForReview=True,
            flaggedBy='alice',
            flaggedAt='2024-01-15T10:00:00+00:00',
            reason='Needs review',
            scope=['product_owner']
        )
        d = flag.to_dict()

        assert d['flaggedForReview'] is True
        assert d['scope'] == ['product_owner']
        json.dumps(d)

    def test_approval_to_dict(self):
        """REQ-tv-d00010-C: Approval.to_dict() returns JSON-serializable dict"""
        m = import_models()
        Approval = m['Approval']

        approval = Approval(
            user='alice',
            decision='approve',
            at='2024-01-15T10:00:00+00:00'
        )
        d = approval.to_dict()

        assert d['user'] == 'alice'
        assert d['decision'] == 'approve'
        json.dumps(d)

    def test_status_request_to_dict(self):
        """REQ-tv-d00010-C: StatusRequest.to_dict() returns JSON-serializable dict"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        req = StatusRequest(
            requestId='req-1',
            reqId='d00001',
            type='status_change',
            fromStatus='Draft',
            toStatus='Active',
            requestedBy='alice',
            requestedAt='2024-01-15T10:00:00+00:00',
            justification='Ready for production',
            approvals=[],
            requiredApprovers=['product_owner'],
            state='pending'
        )
        d = req.to_dict()

        assert d['fromStatus'] == 'Draft'
        assert d['toStatus'] == 'Active'
        json.dumps(d)

    def test_review_session_to_dict(self):
        """REQ-tv-d00010-C: ReviewSession.to_dict() returns JSON-serializable dict"""
        m = import_models()
        ReviewSession = m['ReviewSession']

        session = ReviewSession(
            sessionId='session-1',
            user='alice',
            name='Sprint 23 Review',
            createdAt='2024-01-15T10:00:00+00:00'
        )
        d = session.to_dict()

        assert d['name'] == 'Sprint 23 Review'
        json.dumps(d)

    def test_review_config_to_dict(self):
        """REQ-tv-d00010-C: ReviewConfig.to_dict() returns JSON-serializable dict"""
        m = import_models()
        ReviewConfig = m['ReviewConfig']

        config = ReviewConfig(
            approvalRules={'Draft->Active': ['product_owner']}
        )
        d = config.to_dict()

        assert 'approvalRules' in d
        json.dumps(d)

    def test_review_package_to_dict(self):
        """REQ-tv-d00010-C: ReviewPackage.to_dict() returns JSON-serializable dict"""
        m = import_models()
        ReviewPackage = m['ReviewPackage']

        pkg = ReviewPackage(
            packageId='pkg-1',
            name='Sprint 23',
            description='Sprint 23 requirements',
            reqIds=['d00001', 'd00002'],
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00'
        )
        d = pkg.to_dict()

        assert d['name'] == 'Sprint 23'
        assert d['reqIds'] == ['d00001', 'd00002']
        json.dumps(d)


# =============================================================================
# Assertion D: from_dict() Methods
# =============================================================================

class TestFromDictMethods:
    """REQ-tv-d00010-D: Each dataclass SHALL implement a from_dict(data)
    class method for deserialization from dictionaries."""

    def test_comment_position_from_dict(self):
        """REQ-tv-d00010-D: CommentPosition.from_dict() deserializes correctly"""
        m = import_models()
        CommentPosition = m['CommentPosition']

        data = {
            'type': 'line',
            'hashWhenCreated': 'abc12345',
            'lineNumber': 42,
            'fallbackContext': 'some context'
        }
        pos = CommentPosition.from_dict(data)

        assert pos.type == 'line'
        assert pos.hashWhenCreated == 'abc12345'
        assert pos.lineNumber == 42
        assert pos.fallbackContext == 'some context'

    def test_comment_from_dict(self):
        """REQ-tv-d00010-D: Comment.from_dict() deserializes correctly"""
        m = import_models()
        Comment = m['Comment']

        data = {
            'id': 'comment-1',
            'author': 'alice',
            'timestamp': '2024-01-15T10:00:00+00:00',
            'body': 'Test body'
        }
        comment = Comment.from_dict(data)

        assert comment.id == 'comment-1'
        assert comment.author == 'alice'
        assert comment.body == 'Test body'

    def test_thread_from_dict(self):
        """REQ-tv-d00010-D: Thread.from_dict() deserializes correctly"""
        m = import_models()
        Thread = m['Thread']

        data = {
            'threadId': 'thread-1',
            'reqId': 'd00001',
            'createdBy': 'alice',
            'createdAt': '2024-01-15T10:00:00+00:00',
            'position': {'type': 'general', 'hashWhenCreated': '12345678'},
            'resolved': False,
            'comments': []
        }
        thread = Thread.from_dict(data)

        assert thread.threadId == 'thread-1'
        assert thread.position.type == 'general'

    def test_status_request_from_dict(self):
        """REQ-tv-d00010-D: StatusRequest.from_dict() deserializes correctly"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        data = {
            'requestId': 'req-1',
            'reqId': 'd00001',
            'type': 'status_change',
            'fromStatus': 'Draft',
            'toStatus': 'Active',
            'requestedBy': 'alice',
            'requestedAt': '2024-01-15T10:00:00+00:00',
            'justification': 'Ready',
            'approvals': [],
            'requiredApprovers': ['product_owner'],
            'state': 'pending'
        }
        req = StatusRequest.from_dict(data)

        assert req.requestId == 'req-1'
        assert req.fromStatus == 'Draft'
        assert req.state == 'pending'

    def test_review_package_from_dict(self):
        """REQ-tv-d00010-D: ReviewPackage.from_dict() deserializes correctly"""
        m = import_models()
        ReviewPackage = m['ReviewPackage']

        data = {
            'packageId': 'pkg-1',
            'name': 'Test Package',
            'description': 'Test description',
            'reqIds': ['d00001'],
            'createdBy': 'alice',
            'createdAt': '2024-01-15T10:00:00+00:00',
            'isDefault': True
        }
        pkg = ReviewPackage.from_dict(data)

        assert pkg.packageId == 'pkg-1'
        assert pkg.isDefault is True

    def test_roundtrip_serialization(self):
        """REQ-tv-d00010-D: to_dict() and from_dict() are inverse operations"""
        m = import_models()
        Thread = m['Thread']
        CommentPosition = m['CommentPosition']
        Comment = m['Comment']

        # Create original with nested structure
        pos = CommentPosition(type='line', hashWhenCreated='12345678', lineNumber=10)
        original = Thread(
            threadId='thread-1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00',
            position=pos,
            resolved=True,
            resolvedBy='bob',
            resolvedAt='2024-01-16T10:00:00+00:00',
            comments=[Comment(
                id='c1',
                author='alice',
                timestamp='2024-01-15T10:00:00+00:00',
                body='First comment'
            )]
        )

        # Roundtrip
        data = original.to_dict()
        restored = Thread.from_dict(data)

        assert restored.threadId == original.threadId
        assert restored.position.lineNumber == original.position.lineNumber
        assert len(restored.comments) == len(original.comments)
        assert restored.resolvedBy == original.resolvedBy


# =============================================================================
# Assertion E: validate() Methods
# =============================================================================

class TestValidateMethods:
    """REQ-tv-d00010-E: Each dataclass SHALL implement a validate() method
    returning a tuple of (is_valid: bool, errors: List[str])."""

    def test_comment_position_validate_valid(self):
        """REQ-tv-d00010-E: CommentPosition.validate() returns (True, []) for valid data"""
        m = import_models()
        CommentPosition = m['CommentPosition']

        pos = CommentPosition(type='line', hashWhenCreated='12345678', lineNumber=1)
        is_valid, errors = pos.validate()

        assert is_valid is True
        assert errors == []

    def test_comment_position_validate_invalid_type(self):
        """REQ-tv-d00010-E: CommentPosition.validate() catches invalid type"""
        m = import_models()
        CommentPosition = m['CommentPosition']

        pos = CommentPosition(type='invalid_type', hashWhenCreated='12345678')
        is_valid, errors = pos.validate()

        assert is_valid is False
        assert any('type' in e.lower() for e in errors)

    def test_comment_position_validate_invalid_hash(self):
        """REQ-tv-d00010-E: CommentPosition.validate() catches invalid hash"""
        m = import_models()
        CommentPosition = m['CommentPosition']

        pos = CommentPosition(type='general', hashWhenCreated='short')
        is_valid, errors = pos.validate()

        assert is_valid is False
        assert any('hash' in e.lower() for e in errors)

    def test_comment_position_validate_line_requires_line_number(self):
        """REQ-tv-d00010-E: CommentPosition.validate() requires lineNumber for LINE type"""
        m = import_models()
        CommentPosition = m['CommentPosition']

        pos = CommentPosition(type='line', hashWhenCreated='12345678')  # Missing lineNumber
        is_valid, errors = pos.validate()

        assert is_valid is False
        assert any('linenumber' in e.lower() for e in errors)

    def test_comment_validate_required_fields(self):
        """REQ-tv-d00010-E: Comment.validate() checks required fields"""
        m = import_models()
        Comment = m['Comment']

        comment = Comment(id='', author='', timestamp='', body='')
        is_valid, errors = comment.validate()

        assert is_valid is False
        assert len(errors) >= 3  # id, author, body at minimum

    def test_thread_validate_cascades_to_children(self):
        """REQ-tv-d00010-E: Thread.validate() validates nested objects"""
        m = import_models()
        Thread = m['Thread']
        CommentPosition = m['CommentPosition']
        Comment = m['Comment']

        # Invalid position (bad hash)
        pos = CommentPosition(type='general', hashWhenCreated='bad')
        thread = Thread(
            threadId='t1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00',
            position=pos,
            comments=[Comment(id='', author='', timestamp='', body='')]  # Invalid comment
        )

        is_valid, errors = thread.validate()

        assert is_valid is False
        # Should have errors from position and comment
        assert any('position' in e.lower() or 'hash' in e.lower() for e in errors)
        assert any('comment' in e.lower() for e in errors)

    def test_status_request_validate(self):
        """REQ-tv-d00010-E: StatusRequest.validate() validates status transitions"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        req = StatusRequest(
            requestId='req-1',
            reqId='d00001',
            type='status_change',
            fromStatus='Invalid',  # Invalid status
            toStatus='Active',
            requestedBy='alice',
            requestedAt='2024-01-15T10:00:00+00:00',
            justification='Test',
            approvals=[],
            requiredApprovers=['product_owner'],
            state='pending'
        )
        is_valid, errors = req.validate()

        assert is_valid is False
        assert any('status' in e.lower() for e in errors)

    def test_review_flag_validate_flagged_requires_fields(self):
        """REQ-tv-d00010-E: ReviewFlag.validate() requires fields when flagged"""
        m = import_models()
        ReviewFlag = m['ReviewFlag']

        flag = ReviewFlag(
            flaggedForReview=True,
            flaggedBy='',  # Missing
            flaggedAt='',  # Missing
            reason='',     # Missing
            scope=[]       # Empty
        )
        is_valid, errors = flag.validate()

        assert is_valid is False
        assert len(errors) >= 3


# =============================================================================
# Assertion F: Factory Methods with Auto-generated IDs and Timestamps
# =============================================================================

class TestFactoryMethods:
    """REQ-tv-d00010-F: Thread, Comment, StatusRequest, and ReviewPackage SHALL
    implement factory methods (create()) that auto-generate IDs and timestamps."""

    def test_comment_create_generates_id(self):
        """REQ-tv-d00010-F: Comment.create() auto-generates UUID"""
        m = import_models()
        Comment = m['Comment']

        comment = Comment.create(author='alice', body='Test comment')

        # ID should be a valid UUID
        assert comment.id is not None
        uuid.UUID(comment.id)  # Raises if invalid

    def test_comment_create_generates_timestamp(self):
        """REQ-tv-d00010-F: Comment.create() auto-generates timestamp"""
        m = import_models()
        Comment = m['Comment']

        before = datetime.now(timezone.utc)
        comment = Comment.create(author='alice', body='Test')
        after = datetime.now(timezone.utc)

        # Should have timestamp
        assert comment.timestamp is not None
        # Should be parseable ISO 8601
        ts = datetime.fromisoformat(comment.timestamp.replace('Z', '+00:00'))
        # Should be recent
        assert before <= ts <= after

    def test_thread_create_generates_id_and_timestamp(self):
        """REQ-tv-d00010-F: Thread.create() auto-generates threadId and createdAt"""
        m = import_models()
        Thread = m['Thread']
        CommentPosition = m['CommentPosition']

        pos = CommentPosition(type='general', hashWhenCreated='12345678')
        thread = Thread.create(req_id='d00001', creator='alice', position=pos)

        assert thread.threadId is not None
        uuid.UUID(thread.threadId)
        assert thread.createdAt is not None
        datetime.fromisoformat(thread.createdAt.replace('Z', '+00:00'))

    def test_thread_create_with_initial_comment(self):
        """REQ-tv-d00010-F: Thread.create() can add initial comment"""
        m = import_models()
        Thread = m['Thread']
        CommentPosition = m['CommentPosition']

        pos = CommentPosition(type='general', hashWhenCreated='12345678')
        thread = Thread.create(
            req_id='d00001',
            creator='alice',
            position=pos,
            initial_comment='First comment!'
        )

        assert len(thread.comments) == 1
        assert thread.comments[0].body == 'First comment!'
        assert thread.comments[0].author == 'alice'

    def test_status_request_create_generates_id_and_timestamp(self):
        """REQ-tv-d00010-F: StatusRequest.create() auto-generates fields"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        req = StatusRequest.create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Ready for production'
        )

        assert req.requestId is not None
        uuid.UUID(req.requestId)
        assert req.requestedAt is not None
        assert req.state == 'pending'  # Initial state

    def test_status_request_create_uses_default_approvers(self):
        """REQ-tv-d00010-F: StatusRequest.create() uses default approval rules"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        req = StatusRequest.create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test'
        )

        # Default rules should include product_owner and tech_lead for Draft->Active
        assert 'product_owner' in req.requiredApprovers or 'tech_lead' in req.requiredApprovers

    def test_review_package_create_generates_id_and_timestamp(self):
        """REQ-tv-d00010-F: ReviewPackage.create() auto-generates fields"""
        m = import_models()
        ReviewPackage = m['ReviewPackage']

        pkg = ReviewPackage.create(
            name='Sprint 23',
            description='Sprint 23 requirements',
            created_by='alice'
        )

        assert pkg.packageId is not None
        uuid.UUID(pkg.packageId)
        assert pkg.createdAt is not None
        assert pkg.name == 'Sprint 23'


# =============================================================================
# Assertion G: Container Classes with Version Tracking
# =============================================================================

class TestContainerClasses:
    """REQ-tv-d00010-G: ThreadsFile, StatusFile, and PackagesFile container classes
    SHALL manage file-level JSON structure with version tracking."""

    def test_threads_file_has_version(self):
        """REQ-tv-d00010-G: ThreadsFile includes version field"""
        m = import_models()
        ThreadsFile = m['ThreadsFile']

        tf = ThreadsFile(reqId='d00001', threads=[])
        d = tf.to_dict()

        assert 'version' in d
        assert d['version'] == '1.0'

    def test_threads_file_roundtrip(self):
        """REQ-tv-d00010-G: ThreadsFile serializes and deserializes correctly"""
        m = import_models()
        ThreadsFile = m['ThreadsFile']
        Thread = m['Thread']
        CommentPosition = m['CommentPosition']

        pos = CommentPosition(type='general', hashWhenCreated='12345678')
        thread = Thread(
            threadId='t1',
            reqId='d00001',
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00',
            position=pos
        )
        original = ThreadsFile(reqId='d00001', threads=[thread])

        data = original.to_dict()
        restored = ThreadsFile.from_dict(data)

        assert restored.version == original.version
        assert restored.reqId == original.reqId
        assert len(restored.threads) == 1

    def test_status_file_has_version(self):
        """REQ-tv-d00010-G: StatusFile includes version field"""
        m = import_models()
        StatusFile = m['StatusFile']

        sf = StatusFile(reqId='d00001', requests=[])
        d = sf.to_dict()

        assert 'version' in d
        assert d['version'] == '1.0'

    def test_packages_file_has_version(self):
        """REQ-tv-d00010-G: PackagesFile includes version field"""
        m = import_models()
        PackagesFile = m['PackagesFile']

        pf = PackagesFile(packages=[])
        d = pf.to_dict()

        assert 'version' in d
        assert d['version'] == '1.0'

    def test_packages_file_manages_active_package(self):
        """REQ-tv-d00010-G: PackagesFile tracks activePackageId"""
        m = import_models()
        PackagesFile = m['PackagesFile']
        ReviewPackage = m['ReviewPackage']

        pkg = ReviewPackage(
            packageId='pkg-1',
            name='Test',
            description='',
            reqIds=[],
            createdBy='alice',
            createdAt='2024-01-15T10:00:00+00:00'
        )
        pf = PackagesFile(packages=[pkg], activePackageId='pkg-1')

        d = pf.to_dict()
        assert d['activePackageId'] == 'pkg-1'

        restored = PackagesFile.from_dict(d)
        assert restored.activePackageId == 'pkg-1'


# =============================================================================
# Assertion H: CommentPosition Anchor Types
# =============================================================================

class TestCommentPositionAnchorTypes:
    """REQ-tv-d00010-H: CommentPosition SHALL support four anchor types:
    LINE, BLOCK, WORD, and GENERAL."""

    def test_create_line_position(self):
        """REQ-tv-d00010-H: CommentPosition supports LINE anchor type"""
        m = import_models()
        CommentPosition = m['CommentPosition']

        pos = CommentPosition.create_line(
            hash_value='12345678',
            line_number=42,
            context='The requirements shall...'
        )

        assert pos.type == 'line'
        assert pos.lineNumber == 42
        assert pos.hashWhenCreated == '12345678'
        assert pos.fallbackContext == 'The requirements shall...'

    def test_create_block_position(self):
        """REQ-tv-d00010-H: CommentPosition supports BLOCK anchor type"""
        m = import_models()
        CommentPosition = m['CommentPosition']

        pos = CommentPosition.create_block(
            hash_value='12345678',
            start_line=10,
            end_line=20
        )

        assert pos.type == 'block'
        assert pos.lineRange == (10, 20)
        assert pos.hashWhenCreated == '12345678'

    def test_create_word_position(self):
        """REQ-tv-d00010-H: CommentPosition supports WORD anchor type"""
        m = import_models()
        CommentPosition = m['CommentPosition']

        pos = CommentPosition.create_word(
            hash_value='12345678',
            keyword='SHALL',
            occurrence=2
        )

        assert pos.type == 'word'
        assert pos.keyword == 'SHALL'
        assert pos.keywordOccurrence == 2

    def test_create_general_position(self):
        """REQ-tv-d00010-H: CommentPosition supports GENERAL anchor type"""
        m = import_models()
        CommentPosition = m['CommentPosition']

        pos = CommentPosition.create_general(hash_value='12345678')

        assert pos.type == 'general'
        assert pos.hashWhenCreated == '12345678'
        assert pos.lineNumber is None
        assert pos.lineRange is None
        assert pos.keyword is None

    def test_block_position_serializes_line_range_as_list(self):
        """REQ-tv-d00010-H: Block position lineRange serializes as JSON array"""
        m = import_models()
        CommentPosition = m['CommentPosition']

        pos = CommentPosition.create_block('12345678', 10, 20)
        d = pos.to_dict()

        # lineRange should be a list for JSON compatibility
        assert d['lineRange'] == [10, 20]

        # Should roundtrip back to tuple
        restored = CommentPosition.from_dict(d)
        assert restored.lineRange == (10, 20)


# =============================================================================
# Assertion I: StatusRequest State Calculation
# =============================================================================

class TestStatusRequestStateCalculation:
    """REQ-tv-d00010-I: StatusRequest SHALL automatically calculate its state
    based on approval votes and configured approval rules."""

    def test_state_starts_pending(self):
        """REQ-tv-d00010-I: New StatusRequest starts in PENDING state"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        req = StatusRequest.create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test'
        )

        assert req.state == 'pending'

    def test_state_becomes_rejected_on_rejection(self):
        """REQ-tv-d00010-I: State becomes REJECTED when any approver rejects"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        req = StatusRequest.create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test',
            required_approvers=['product_owner', 'tech_lead']
        )

        req.add_approval('product_owner', 'reject', 'Not ready')

        assert req.state == 'rejected'

    def test_state_becomes_approved_when_all_approve(self):
        """REQ-tv-d00010-I: State becomes APPROVED when all required approve"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        req = StatusRequest.create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test',
            required_approvers=['product_owner', 'tech_lead']
        )

        req.add_approval('product_owner', 'approve')
        assert req.state == 'pending'  # Still waiting for tech_lead

        req.add_approval('tech_lead', 'approve')
        assert req.state == 'approved'

    def test_state_remains_pending_with_partial_approval(self):
        """REQ-tv-d00010-I: State remains PENDING with partial approvals"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        req = StatusRequest.create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test',
            required_approvers=['product_owner', 'tech_lead']
        )

        req.add_approval('product_owner', 'approve')
        assert req.state == 'pending'

    def test_mark_applied_only_when_approved(self):
        """REQ-tv-d00010-I: Can only mark APPLIED when state is APPROVED"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        req = StatusRequest.create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test',
            required_approvers=['product_owner']
        )

        # Cannot apply when pending
        with pytest.raises(ValueError):
            req.mark_applied()

        # Approve first
        req.add_approval('product_owner', 'approve')
        assert req.state == 'approved'

        # Now can apply
        req.mark_applied()
        assert req.state == 'applied'

    def test_applied_state_is_final(self):
        """REQ-tv-d00010-I: APPLIED state is final (new approvals don't change it)"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        req = StatusRequest.create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='alice',
            justification='Test',
            required_approvers=['product_owner']
        )

        req.add_approval('product_owner', 'approve')
        req.mark_applied()

        # Adding another approval shouldn't change state
        req.add_approval('another_user', 'reject')
        assert req.state == 'applied'


# =============================================================================
# Assertion J: UTC Timestamps in ISO 8601 Format
# =============================================================================

class TestUTCTimestamps:
    """REQ-tv-d00010-J: All dataclasses SHALL use UTC timestamps in ISO 8601 format."""

    def test_now_iso_returns_utc(self):
        """REQ-tv-d00010-J: now_iso() returns UTC timestamp"""
        m = import_models()
        now_iso = m['now_iso']

        ts = now_iso()

        # Should be parseable
        dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))

        # Should be UTC (either +00:00 or Z suffix)
        assert dt.tzinfo is not None
        assert dt.utcoffset().total_seconds() == 0

    def test_comment_create_uses_utc(self):
        """REQ-tv-d00010-J: Comment.create() uses UTC timestamp"""
        m = import_models()
        Comment = m['Comment']

        comment = Comment.create(author='alice', body='Test')
        dt = datetime.fromisoformat(comment.timestamp.replace('Z', '+00:00'))

        assert dt.tzinfo is not None
        assert dt.utcoffset().total_seconds() == 0

    def test_thread_create_uses_utc(self):
        """REQ-tv-d00010-J: Thread.create() uses UTC timestamp"""
        m = import_models()
        Thread = m['Thread']
        CommentPosition = m['CommentPosition']

        pos = CommentPosition.create_general('12345678')
        thread = Thread.create('d00001', 'alice', pos)
        dt = datetime.fromisoformat(thread.createdAt.replace('Z', '+00:00'))

        assert dt.utcoffset().total_seconds() == 0

    def test_iso_format_includes_timezone(self):
        """REQ-tv-d00010-J: ISO 8601 timestamps include timezone info"""
        m = import_models()
        now_iso = m['now_iso']

        ts = now_iso()

        # Should have timezone indicator (either +00:00 or Z)
        assert '+' in ts or 'Z' in ts


# =============================================================================
# Utility Function Tests
# =============================================================================

class TestUtilityFunctions:
    """Tests for utility functions in the models module."""

    def test_generate_uuid_is_valid(self):
        """generate_uuid() returns valid UUID string"""
        m = import_models()
        generate_uuid = m['generate_uuid']

        uid = generate_uuid()
        # Should not raise
        uuid.UUID(uid)

    def test_generate_uuid_is_unique(self):
        """generate_uuid() returns unique values"""
        m = import_models()
        generate_uuid = m['generate_uuid']

        uids = {generate_uuid() for _ in range(100)}
        assert len(uids) == 100

    def test_validate_req_id_valid_formats(self):
        """validate_req_id() accepts valid formats"""
        m = import_models()
        validate_req_id = m['validate_req_id']

        # Core REQs
        assert validate_req_id('d00001') is True
        assert validate_req_id('p00042') is True
        assert validate_req_id('o00003') is True

        # Sponsor-specific
        assert validate_req_id('CAL-d00001') is True
        assert validate_req_id('HHT-p00042') is True

    def test_validate_req_id_invalid_formats(self):
        """validate_req_id() rejects invalid formats"""
        m = import_models()
        validate_req_id = m['validate_req_id']

        # REQ- prefix not allowed
        assert validate_req_id('REQ-d00001') is False

        # Wrong format
        assert validate_req_id('d0001') is False  # Too few digits
        assert validate_req_id('x00001') is False  # Invalid type
        assert validate_req_id('') is False
        assert validate_req_id('invalid') is False

    def test_validate_hash_valid(self):
        """validate_hash() accepts valid 8-char hex strings"""
        m = import_models()
        validate_hash = m['validate_hash']

        assert validate_hash('12345678') is True
        assert validate_hash('abcdef12') is True
        assert validate_hash('ABCDEF12') is True

    def test_validate_hash_invalid(self):
        """validate_hash() rejects invalid hash formats"""
        m = import_models()
        validate_hash = m['validate_hash']

        assert validate_hash('1234567') is False  # Too short
        assert validate_hash('123456789') is False  # Too long
        assert validate_hash('1234567g') is False  # Invalid char
        assert validate_hash('') is False


# =============================================================================
# Additional Integration Tests
# =============================================================================

class TestIntegration:
    """Integration tests for complex scenarios."""

    def test_full_thread_lifecycle(self):
        """Test complete thread lifecycle: create, comment, resolve"""
        m = import_models()
        Thread = m['Thread']
        CommentPosition = m['CommentPosition']

        # Create thread with initial comment
        pos = CommentPosition.create_line('12345678', 10, 'Test context')
        thread = Thread.create('d00001', 'alice', pos, 'Initial feedback')

        assert len(thread.comments) == 1
        assert not thread.resolved

        # Add more comments
        thread.add_comment('bob', 'Good point!')
        thread.add_comment('alice', 'Thanks!')

        assert len(thread.comments) == 3

        # Resolve
        thread.resolve('bob')
        assert thread.resolved
        assert thread.resolvedBy == 'bob'
        assert thread.resolvedAt is not None

        # Unresolve
        thread.unresolve()
        assert not thread.resolved
        assert thread.resolvedBy is None

    def test_full_status_request_workflow(self):
        """Test complete status request workflow"""
        m = import_models()
        StatusRequest = m['StatusRequest']

        # Create request
        req = StatusRequest.create(
            req_id='d00001',
            from_status='Draft',
            to_status='Active',
            requested_by='developer',
            justification='Feature complete and tested',
            required_approvers=['product_owner', 'tech_lead']
        )

        # Validate initial state
        is_valid, errors = req.validate()
        assert is_valid
        assert req.state == 'pending'

        # First approval
        req.add_approval('product_owner', 'approve', 'LGTM')
        assert req.state == 'pending'

        # Second approval
        req.add_approval('tech_lead', 'approve')
        assert req.state == 'approved'

        # Apply the change
        req.mark_applied()
        assert req.state == 'applied'

        # Serialize and deserialize
        data = req.to_dict()
        restored = StatusRequest.from_dict(data)
        assert restored.state == 'applied'
        assert len(restored.approvals) == 2

    def test_review_package_with_multiple_reqs(self):
        """Test ReviewPackage managing multiple requirements"""
        m = import_models()
        ReviewPackage = m['ReviewPackage']
        PackagesFile = m['PackagesFile']

        # Create package with REQs
        pkg = ReviewPackage.create(
            name='Sprint 23 Review',
            description='Requirements for sprint 23',
            created_by='pm_alice'
        )
        pkg.reqIds = ['d00001', 'd00002', 'p00015']

        # Create file with multiple packages
        default_pkg = ReviewPackage(
            packageId='default',
            name='Default',
            description='Default package',
            reqIds=['d00099'],
            createdBy='system',
            createdAt='2024-01-01T00:00:00+00:00',
            isDefault=True
        )

        pf = PackagesFile(packages=[default_pkg, pkg], activePackageId=pkg.packageId)

        # Serialize
        data = pf.to_dict()
        assert len(data['packages']) == 2
        assert data['activePackageId'] == pkg.packageId

        # Deserialize
        restored = PackagesFile.from_dict(data)
        assert len(restored.packages) == 2
        assert restored.get_default().isDefault is True
        assert restored.get_active().name == 'Sprint 23 Review'
