#!/usr/bin/env python3
"""
Review Data Models for trace_view

Data classes for the review system including:
- ReviewFlag: Mark REQs for review
- CommentPosition: Position-aware comment anchoring
- Comment: Individual comments
- Thread: Comment threads with position
- StatusRequest: Status change requests with approvals
- Approval: Individual approvals
- ReviewSession: Review session metadata
- ReviewConfig: System configuration
- ReviewPackage: Named collections of REQs under review

IMPLEMENTS REQUIREMENTS:
    REQ-tv-d00010: Review Data Models
"""

import re
import uuid
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Dict, List, Optional, Tuple


# =============================================================================
# Enums and Constants
# REQ-tv-d00010-B: String enums for JSON compatibility
# =============================================================================

class PositionType(str, Enum):
    """Type of comment position anchor"""
    LINE = "line"
    BLOCK = "block"
    WORD = "word"
    GENERAL = "general"


class RequestState(str, Enum):
    """State of a status change request"""
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    APPLIED = "applied"


class ApprovalDecision(str, Enum):
    """Approval decision type"""
    APPROVE = "approve"
    REJECT = "reject"


# Valid REQ status values
VALID_REQ_STATUSES = {"Draft", "Active", "Deprecated"}

# Default approval rules for status transitions
DEFAULT_APPROVAL_RULES: Dict[str, List[str]] = {
    "Draft->Active": ["product_owner", "tech_lead"],
    "Active->Deprecated": ["product_owner"],
    "Draft->Deprecated": ["product_owner"]
}


# =============================================================================
# Utility Functions
# =============================================================================

def generate_uuid() -> str:
    """Generate a new UUID string"""
    return str(uuid.uuid4())


def now_iso() -> str:
    """
    Get current UTC timestamp in ISO 8601 format.

    REQ-tv-d00010-J: All timestamps SHALL be UTC in ISO 8601 format.
    """
    return datetime.now(timezone.utc).isoformat()


def parse_iso_datetime(iso_str: str) -> datetime:
    """Parse ISO 8601 datetime string to datetime object"""
    # Handle both with and without timezone, and Z suffix
    if iso_str.endswith('Z'):
        iso_str = iso_str[:-1] + '+00:00'
    return datetime.fromisoformat(iso_str)


def validate_req_id(req_id: str) -> bool:
    """
    Validate requirement ID format.

    Valid formats:
    - d00001, p00042, o00003 (core REQs)
    - CAL-d00001 (sponsor-specific REQs)

    Does NOT accept REQ- prefix.
    """
    if not req_id:
        return False
    # Negative lookahead to reject REQ- prefix; only sponsor prefixes allowed
    pattern = r'^(?!REQ-)(?:[A-Z]{2,4}-)?[pod]\d{5}$'
    return bool(re.match(pattern, req_id))


def validate_hash(hash_value: str) -> bool:
    """Validate 8-character hex hash format"""
    if not hash_value:
        return False
    return bool(re.match(r'^[a-fA-F0-9]{8}$', hash_value))


# =============================================================================
# Data Classes
# REQ-tv-d00010-A: All types implemented as dataclasses
# REQ-tv-d00010-C: Each dataclass implements to_dict()
# REQ-tv-d00010-D: Each dataclass implements from_dict()
# REQ-tv-d00010-E: Each dataclass implements validate()
# =============================================================================

@dataclass
class CommentPosition:
    """
    Position anchor for a comment within a requirement.

    REQ-tv-d00010-H: Supports four anchor types: LINE, BLOCK, WORD, GENERAL.

    Supports multiple anchor types:
    - "line": Specific line number
    - "block": Range of lines (e.g., entire section)
    - "word": Specific keyword occurrence
    - "general": No specific position (applies to whole REQ)

    The hashWhenCreated allows detection of content drift.
    """
    type: str  # PositionType value as string for JSON compatibility
    hashWhenCreated: str  # 8-char REQ hash when comment was created
    lineNumber: Optional[int] = None
    lineRange: Optional[Tuple[int, int]] = None
    keyword: Optional[str] = None
    keywordOccurrence: Optional[int] = None  # 1-based occurrence index
    fallbackContext: Optional[str] = None  # Snippet for finding position on hash mismatch

    def __post_init__(self):
        """Validate position type matches provided fields"""
        if isinstance(self.type, PositionType):
            self.type = self.type.value

    @classmethod
    def create_line(cls, hash_value: str, line_number: int,
                    context: Optional[str] = None) -> 'CommentPosition':
        """Factory for line-anchored position"""
        return cls(
            type=PositionType.LINE.value,
            hashWhenCreated=hash_value,
            lineNumber=line_number,
            fallbackContext=context
        )

    @classmethod
    def create_block(cls, hash_value: str, start_line: int, end_line: int,
                     context: Optional[str] = None) -> 'CommentPosition':
        """Factory for block-anchored position"""
        return cls(
            type=PositionType.BLOCK.value,
            hashWhenCreated=hash_value,
            lineRange=(start_line, end_line),
            fallbackContext=context
        )

    @classmethod
    def create_word(cls, hash_value: str, keyword: str, occurrence: int = 1,
                    context: Optional[str] = None) -> 'CommentPosition':
        """Factory for word-anchored position"""
        return cls(
            type=PositionType.WORD.value,
            hashWhenCreated=hash_value,
            keyword=keyword,
            keywordOccurrence=occurrence,
            fallbackContext=context
        )

    @classmethod
    def create_general(cls, hash_value: str) -> 'CommentPosition':
        """Factory for general (whole REQ) position"""
        return cls(
            type=PositionType.GENERAL.value,
            hashWhenCreated=hash_value
        )

    def validate(self) -> Tuple[bool, List[str]]:
        """
        Validate position fields based on type.

        REQ-tv-d00010-E: Returns (is_valid, list_of_error_messages)
        """
        errors = []

        if self.type not in [pt.value for pt in PositionType]:
            errors.append(f"Invalid position type: {self.type}")
            return False, errors

        if not validate_hash(self.hashWhenCreated):
            errors.append(f"Invalid hash format: {self.hashWhenCreated}")

        if self.type == PositionType.LINE.value:
            if self.lineNumber is None:
                errors.append("lineNumber required for 'line' type")
            elif self.lineNumber < 1:
                errors.append("lineNumber must be positive")

        elif self.type == PositionType.BLOCK.value:
            if self.lineRange is None:
                errors.append("lineRange required for 'block' type")
            elif len(self.lineRange) != 2:
                errors.append("lineRange must be tuple of (start, end)")
            elif self.lineRange[0] < 1 or self.lineRange[1] < self.lineRange[0]:
                errors.append("Invalid lineRange: start must be >= 1 and end >= start")

        elif self.type == PositionType.WORD.value:
            if not self.keyword:
                errors.append("keyword required for 'word' type")
            if self.keywordOccurrence is not None and self.keywordOccurrence < 1:
                errors.append("keywordOccurrence must be positive")

        return len(errors) == 0, errors

    def to_dict(self) -> Dict[str, Any]:
        """
        Convert to JSON-serializable dictionary.

        REQ-tv-d00010-C: Returns JSON-serializable dict.
        """
        result: Dict[str, Any] = {
            'type': self.type,
            'hashWhenCreated': self.hashWhenCreated
        }
        if self.lineNumber is not None:
            result['lineNumber'] = self.lineNumber
        if self.lineRange is not None:
            result['lineRange'] = list(self.lineRange)  # Tuple to list for JSON
        if self.keyword is not None:
            result['keyword'] = self.keyword
        if self.keywordOccurrence is not None:
            result['keywordOccurrence'] = self.keywordOccurrence
        if self.fallbackContext is not None:
            result['fallbackContext'] = self.fallbackContext
        return result

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'CommentPosition':
        """
        Create from dictionary (JSON deserialization).

        REQ-tv-d00010-D: Deserializes from dictionaries.
        """
        line_range = data.get('lineRange')
        if line_range is not None:
            line_range = tuple(line_range)  # List to tuple
        return cls(
            type=data['type'],
            hashWhenCreated=data['hashWhenCreated'],
            lineNumber=data.get('lineNumber'),
            lineRange=line_range,
            keyword=data.get('keyword'),
            keywordOccurrence=data.get('keywordOccurrence'),
            fallbackContext=data.get('fallbackContext')
        )


@dataclass
class Comment:
    """
    Single comment in a thread.

    Comments are immutable once created - edits create new comments
    with references to the original.
    """
    id: str  # UUID
    author: str  # Username
    timestamp: str  # ISO 8601 datetime
    body: str  # Markdown content

    @classmethod
    def create(cls, author: str, body: str) -> 'Comment':
        """
        Factory for creating new comment with auto-generated fields.

        REQ-tv-d00010-F: Auto-generates IDs and timestamps.
        REQ-tv-d00010-J: Uses UTC timestamps.
        """
        return cls(
            id=generate_uuid(),
            author=author,
            timestamp=now_iso(),
            body=body
        )

    def validate(self) -> Tuple[bool, List[str]]:
        """Validate comment fields"""
        errors = []

        if not self.id:
            errors.append("Comment id is required")
        if not self.author:
            errors.append("Comment author is required")
        if not self.timestamp:
            errors.append("Comment timestamp is required")
        if not self.body or not self.body.strip():
            errors.append("Comment body cannot be empty")

        # Validate timestamp format
        if self.timestamp:
            try:
                parse_iso_datetime(self.timestamp)
            except ValueError:
                errors.append(f"Invalid timestamp format: {self.timestamp}")

        return len(errors) == 0, errors

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Comment':
        """Create from dictionary"""
        return cls(
            id=data['id'],
            author=data['author'],
            timestamp=data['timestamp'],
            body=data['body']
        )


@dataclass
class Thread:
    """
    Comment thread with position anchor.

    A thread is a collection of comments about a specific location
    in a requirement. Threads can be resolved.
    """
    threadId: str  # UUID
    reqId: str  # Requirement ID (e.g., "d00027")
    createdBy: str  # Username who started thread
    createdAt: str  # ISO 8601 datetime
    position: CommentPosition
    resolved: bool = False
    resolvedBy: Optional[str] = None
    resolvedAt: Optional[str] = None
    comments: List[Comment] = field(default_factory=list)

    @classmethod
    def create(cls, req_id: str, creator: str, position: CommentPosition,
               initial_comment: Optional[str] = None) -> 'Thread':
        """
        Factory for creating new thread.

        REQ-tv-d00010-F: Auto-generates IDs and timestamps.

        Args:
            req_id: Requirement ID this thread is about
            creator: Username of thread creator
            position: Position anchor for the thread
            initial_comment: Optional first comment body
        """
        thread = cls(
            threadId=generate_uuid(),
            reqId=req_id,
            createdBy=creator,
            createdAt=now_iso(),
            position=position
        )
        if initial_comment:
            thread.add_comment(creator, initial_comment)
        return thread

    def add_comment(self, author: str, body: str) -> Comment:
        """Add a new comment to the thread"""
        comment = Comment.create(author, body)
        self.comments.append(comment)
        return comment

    def resolve(self, user: str) -> None:
        """Mark thread as resolved"""
        self.resolved = True
        self.resolvedBy = user
        self.resolvedAt = now_iso()

    def unresolve(self) -> None:
        """Mark thread as unresolved"""
        self.resolved = False
        self.resolvedBy = None
        self.resolvedAt = None

    def validate(self) -> Tuple[bool, List[str]]:
        """Validate thread and all comments"""
        errors = []

        if not self.threadId:
            errors.append("Thread threadId is required")
        if not validate_req_id(self.reqId):
            errors.append(f"Invalid requirement ID: {self.reqId}")
        if not self.createdBy:
            errors.append("Thread createdBy is required")

        # Validate position
        pos_valid, pos_errors = self.position.validate()
        errors.extend([f"Position: {e}" for e in pos_errors])

        # Validate resolution state
        if self.resolved:
            if not self.resolvedBy:
                errors.append("Resolved thread must have resolvedBy")
            if not self.resolvedAt:
                errors.append("Resolved thread must have resolvedAt")

        # Validate comments
        for i, comment in enumerate(self.comments):
            comment_valid, comment_errors = comment.validate()
            errors.extend([f"Comment[{i}]: {e}" for e in comment_errors])

        return len(errors) == 0, errors

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        return {
            'threadId': self.threadId,
            'reqId': self.reqId,
            'createdBy': self.createdBy,
            'createdAt': self.createdAt,
            'position': self.position.to_dict(),
            'resolved': self.resolved,
            'resolvedBy': self.resolvedBy,
            'resolvedAt': self.resolvedAt,
            'comments': [c.to_dict() for c in self.comments]
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Thread':
        """Create from dictionary"""
        return cls(
            threadId=data['threadId'],
            reqId=data['reqId'],
            createdBy=data['createdBy'],
            createdAt=data['createdAt'],
            position=CommentPosition.from_dict(data['position']),
            resolved=data.get('resolved', False),
            resolvedBy=data.get('resolvedBy'),
            resolvedAt=data.get('resolvedAt'),
            comments=[Comment.from_dict(c) for c in data.get('comments', [])]
        )


@dataclass
class ReviewFlag:
    """
    Marks a requirement for review.

    When a requirement is flagged, it signals that reviewers in the
    specified scope should examine it.
    """
    flaggedForReview: bool
    flaggedBy: str  # Username
    flaggedAt: str  # ISO 8601 datetime
    reason: str
    scope: List[str]  # List of roles/users who should review

    @classmethod
    def create(cls, user: str, reason: str, scope: List[str]) -> 'ReviewFlag':
        """Factory for creating new review flag"""
        return cls(
            flaggedForReview=True,
            flaggedBy=user,
            flaggedAt=now_iso(),
            reason=reason,
            scope=scope
        )

    @classmethod
    def cleared(cls) -> 'ReviewFlag':
        """Factory for an unflagged state"""
        return cls(
            flaggedForReview=False,
            flaggedBy='',
            flaggedAt='',
            reason='',
            scope=[]
        )

    def clear(self) -> None:
        """Clear the review flag"""
        self.flaggedForReview = False
        self.flaggedBy = ''
        self.flaggedAt = ''
        self.reason = ''
        self.scope = []

    def validate(self) -> Tuple[bool, List[str]]:
        """Validate flag state"""
        errors = []

        if self.flaggedForReview:
            if not self.flaggedBy:
                errors.append("Flagged review must have flaggedBy")
            if not self.flaggedAt:
                errors.append("Flagged review must have flaggedAt")
            if not self.reason:
                errors.append("Flagged review must have reason")
            if not self.scope:
                errors.append("Flagged review must have non-empty scope")

        return len(errors) == 0, errors

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ReviewFlag':
        """Create from dictionary"""
        return cls(
            flaggedForReview=data['flaggedForReview'],
            flaggedBy=data.get('flaggedBy', ''),
            flaggedAt=data.get('flaggedAt', ''),
            reason=data.get('reason', ''),
            scope=data.get('scope', [])
        )


@dataclass
class Approval:
    """
    Single approval on a status change request.
    """
    user: str  # Username
    decision: str  # ApprovalDecision value
    at: str  # ISO 8601 datetime
    comment: Optional[str] = None

    @classmethod
    def create(cls, user: str, decision: str,
               comment: Optional[str] = None) -> 'Approval':
        """Factory for creating new approval"""
        return cls(
            user=user,
            decision=decision,
            at=now_iso(),
            comment=comment
        )

    def validate(self) -> Tuple[bool, List[str]]:
        """Validate approval"""
        errors = []

        if not self.user:
            errors.append("Approval user is required")
        if self.decision not in [d.value for d in ApprovalDecision]:
            errors.append(f"Invalid decision: {self.decision}")
        if not self.at:
            errors.append("Approval timestamp (at) is required")

        return len(errors) == 0, errors

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        result: Dict[str, Any] = {
            'user': self.user,
            'decision': self.decision,
            'at': self.at
        }
        if self.comment is not None:
            result['comment'] = self.comment
        return result

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Approval':
        """Create from dictionary"""
        return cls(
            user=data['user'],
            decision=data['decision'],
            at=data['at'],
            comment=data.get('comment')
        )


@dataclass
class StatusRequest:
    """
    Request to change a requirement's status.

    REQ-tv-d00010-I: Automatically calculates state based on approval votes.

    Status changes require approvals from designated approvers.
    Valid transitions:
    - Draft -> Active (requires product_owner, tech_lead)
    - Active -> Deprecated (requires product_owner)
    - Draft -> Deprecated (requires product_owner)
    """
    requestId: str  # UUID
    reqId: str  # Requirement ID
    type: str  # Always "status_change"
    fromStatus: str
    toStatus: str
    requestedBy: str  # Username
    requestedAt: str  # ISO 8601 datetime
    justification: str
    approvals: List[Approval]
    requiredApprovers: List[str]  # Roles/users required to approve
    state: str  # RequestState value

    @classmethod
    def create(cls, req_id: str, from_status: str, to_status: str,
               requested_by: str, justification: str,
               required_approvers: Optional[List[str]] = None) -> 'StatusRequest':
        """
        Factory for creating new status change request.

        REQ-tv-d00010-F: Auto-generates IDs and timestamps.

        Args:
            req_id: Requirement ID
            from_status: Current status
            to_status: Requested new status
            requested_by: Username making request
            justification: Reason for change
            required_approvers: Override default approvers
        """
        # Determine required approvers from defaults if not provided
        if required_approvers is None:
            transition_key = f"{from_status}->{to_status}"
            required_approvers = DEFAULT_APPROVAL_RULES.get(
                transition_key, ["product_owner"]
            )

        return cls(
            requestId=generate_uuid(),
            reqId=req_id,
            type="status_change",
            fromStatus=from_status,
            toStatus=to_status,
            requestedBy=requested_by,
            requestedAt=now_iso(),
            justification=justification,
            approvals=[],
            requiredApprovers=required_approvers,
            state=RequestState.PENDING.value
        )

    def add_approval(self, user: str, decision: str,
                     comment: Optional[str] = None) -> Approval:
        """Add an approval to the request"""
        approval = Approval.create(user, decision, comment)
        self.approvals.append(approval)
        self._update_state()
        return approval

    def _update_state(self) -> None:
        """
        Update state based on approvals.

        REQ-tv-d00010-I: State automatically calculated from approval votes.
        """
        if self.state == RequestState.APPLIED.value:
            return  # Already applied, don't change

        # Check for any rejections
        for approval in self.approvals:
            if approval.decision == ApprovalDecision.REJECT.value:
                self.state = RequestState.REJECTED.value
                return

        # Check if all required approvers have approved
        approved_users = {
            a.user for a in self.approvals
            if a.decision == ApprovalDecision.APPROVE.value
        }

        # Check if required approvers are satisfied
        all_approved = all(
            approver in approved_users
            for approver in self.requiredApprovers
        )

        if all_approved:
            self.state = RequestState.APPROVED.value
        else:
            self.state = RequestState.PENDING.value

    def mark_applied(self) -> None:
        """Mark the request as applied"""
        if self.state != RequestState.APPROVED.value:
            raise ValueError("Can only apply approved requests")
        self.state = RequestState.APPLIED.value

    def validate(self) -> Tuple[bool, List[str]]:
        """Validate status request"""
        errors = []

        if not self.requestId:
            errors.append("requestId is required")
        if not validate_req_id(self.reqId):
            errors.append(f"Invalid requirement ID: {self.reqId}")
        if self.type != "status_change":
            errors.append(f"Invalid type: {self.type}")
        if self.fromStatus not in VALID_REQ_STATUSES:
            errors.append(f"Invalid fromStatus: {self.fromStatus}")
        if self.toStatus not in VALID_REQ_STATUSES:
            errors.append(f"Invalid toStatus: {self.toStatus}")
        if self.fromStatus == self.toStatus:
            errors.append("fromStatus and toStatus must be different")
        if not self.requestedBy:
            errors.append("requestedBy is required")
        if not self.justification:
            errors.append("justification is required")
        if self.state not in [s.value for s in RequestState]:
            errors.append(f"Invalid state: {self.state}")

        # Validate approvals
        for i, approval in enumerate(self.approvals):
            approval_valid, approval_errors = approval.validate()
            errors.extend([f"Approval[{i}]: {e}" for e in approval_errors])

        return len(errors) == 0, errors

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        return {
            'requestId': self.requestId,
            'reqId': self.reqId,
            'type': self.type,
            'fromStatus': self.fromStatus,
            'toStatus': self.toStatus,
            'requestedBy': self.requestedBy,
            'requestedAt': self.requestedAt,
            'justification': self.justification,
            'approvals': [a.to_dict() for a in self.approvals],
            'requiredApprovers': self.requiredApprovers,
            'state': self.state
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'StatusRequest':
        """Create from dictionary"""
        return cls(
            requestId=data['requestId'],
            reqId=data['reqId'],
            type=data['type'],
            fromStatus=data['fromStatus'],
            toStatus=data['toStatus'],
            requestedBy=data['requestedBy'],
            requestedAt=data['requestedAt'],
            justification=data['justification'],
            approvals=[Approval.from_dict(a) for a in data.get('approvals', [])],
            requiredApprovers=data.get('requiredApprovers', []),
            state=data['state']
        )


@dataclass
class ReviewSession:
    """
    Groups review activity for a user.

    Sessions help organize reviews and track progress over time.
    """
    sessionId: str  # UUID
    user: str  # Username
    name: str  # Session name (e.g., "Sprint 23 Review")
    createdAt: str  # ISO 8601 datetime
    description: Optional[str] = None

    @classmethod
    def create(cls, user: str, name: str,
               description: Optional[str] = None) -> 'ReviewSession':
        """Factory for creating new session"""
        return cls(
            sessionId=generate_uuid(),
            user=user,
            name=name,
            createdAt=now_iso(),
            description=description
        )

    def validate(self) -> Tuple[bool, List[str]]:
        """Validate session"""
        errors = []

        if not self.sessionId:
            errors.append("sessionId is required")
        if not self.user:
            errors.append("user is required")
        if not self.name:
            errors.append("name is required")
        if not self.createdAt:
            errors.append("createdAt is required")

        return len(errors) == 0, errors

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        result: Dict[str, Any] = {
            'sessionId': self.sessionId,
            'user': self.user,
            'name': self.name,
            'createdAt': self.createdAt
        }
        if self.description is not None:
            result['description'] = self.description
        return result

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ReviewSession':
        """Create from dictionary"""
        return cls(
            sessionId=data['sessionId'],
            user=data['user'],
            name=data['name'],
            createdAt=data['createdAt'],
            description=data.get('description')
        )


@dataclass
class ReviewConfig:
    """
    System configuration for the review system.
    """
    approvalRules: Dict[str, List[str]]  # Status transition -> required approvers
    pushOnComment: bool = True  # Auto git push when adding comments
    autoFetchOnOpen: bool = True  # Auto git fetch when opening reviews

    @classmethod
    def default(cls) -> 'ReviewConfig':
        """Factory for default configuration"""
        return cls(
            approvalRules=DEFAULT_APPROVAL_RULES.copy(),
            pushOnComment=True,
            autoFetchOnOpen=True
        )

    def get_required_approvers(self, from_status: str, to_status: str) -> List[str]:
        """Get required approvers for a status transition"""
        key = f"{from_status}->{to_status}"
        return self.approvalRules.get(key, ["product_owner"])

    def validate(self) -> Tuple[bool, List[str]]:
        """Validate configuration"""
        errors = []

        # Validate approval rules
        for transition, approvers in self.approvalRules.items():
            parts = transition.split('->')
            if len(parts) != 2:
                errors.append(f"Invalid transition format: {transition}")
                continue
            from_status, to_status = parts
            if from_status not in VALID_REQ_STATUSES:
                errors.append(f"Invalid from status in {transition}: {from_status}")
            if to_status not in VALID_REQ_STATUSES:
                errors.append(f"Invalid to status in {transition}: {to_status}")
            if not approvers:
                errors.append(f"Empty approvers for {transition}")

        return len(errors) == 0, errors

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        return {
            'approvalRules': self.approvalRules,
            'pushOnComment': self.pushOnComment,
            'autoFetchOnOpen': self.autoFetchOnOpen
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ReviewConfig':
        """Create from dictionary"""
        return cls(
            approvalRules=data.get('approvalRules', DEFAULT_APPROVAL_RULES.copy()),
            pushOnComment=data.get('pushOnComment', True),
            autoFetchOnOpen=data.get('autoFetchOnOpen', True)
        )


@dataclass
class ReviewPackage:
    """
    Named collection of REQs under review.

    Packages group related requirements for coordinated review.
    """
    packageId: str  # UUID
    name: str
    description: str
    reqIds: List[str]
    createdBy: str  # Username
    createdAt: str  # ISO 8601 datetime
    isDefault: bool = False

    @classmethod
    def create(cls, name: str, description: str, created_by: str) -> 'ReviewPackage':
        """
        Factory for creating new package.

        REQ-tv-d00010-F: Auto-generates IDs and timestamps.
        """
        return cls(
            packageId=generate_uuid(),
            name=name,
            description=description,
            reqIds=[],
            createdBy=created_by,
            createdAt=now_iso(),
            isDefault=False
        )

    @classmethod
    def create_default(cls) -> 'ReviewPackage':
        """Create the default package"""
        return cls(
            packageId="default",
            name="Default",
            description="REQs manually set to Review status",
            reqIds=[],
            createdBy="system",
            createdAt=now_iso(),
            isDefault=True
        )

    def validate(self) -> Tuple[bool, List[str]]:
        """Validate package"""
        errors = []

        if not self.packageId:
            errors.append("packageId is required")
        if not self.name:
            errors.append("name is required")
        if not self.createdBy:
            errors.append("createdBy is required")
        if not self.createdAt:
            errors.append("createdAt is required")

        return len(errors) == 0, errors

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        return {
            'packageId': self.packageId,
            'name': self.name,
            'description': self.description,
            'reqIds': self.reqIds.copy(),
            'createdBy': self.createdBy,
            'createdAt': self.createdAt,
            'isDefault': self.isDefault
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ReviewPackage':
        """Create from dictionary"""
        return cls(
            packageId=data.get('packageId', ''),
            name=data.get('name', ''),
            description=data.get('description', ''),
            reqIds=data.get('reqIds', []).copy(),
            createdBy=data.get('createdBy', ''),
            createdAt=data.get('createdAt', ''),
            isDefault=data.get('isDefault', False)
        )


# =============================================================================
# Container Classes for JSON File Contents
# REQ-tv-d00010-G: Container classes with version tracking
# =============================================================================

@dataclass
class ThreadsFile:
    """Container for threads.json file contents"""
    reqId: str
    threads: List[Thread]
    version: str = "1.0"

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        return {
            'version': self.version,
            'reqId': self.reqId,
            'threads': [t.to_dict() for t in self.threads]
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ThreadsFile':
        """Create from dictionary"""
        return cls(
            version=data.get('version', '1.0'),
            reqId=data['reqId'],
            threads=[Thread.from_dict(t) for t in data.get('threads', [])]
        )


@dataclass
class StatusFile:
    """Container for status.json file contents"""
    reqId: str
    requests: List[StatusRequest]
    version: str = "1.0"

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        return {
            'version': self.version,
            'reqId': self.reqId,
            'requests': [r.to_dict() for r in self.requests]
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'StatusFile':
        """Create from dictionary"""
        return cls(
            version=data.get('version', '1.0'),
            reqId=data['reqId'],
            requests=[StatusRequest.from_dict(r) for r in data.get('requests', [])]
        )


@dataclass
class PackagesFile:
    """Container for packages.json file contents"""
    packages: List[ReviewPackage]
    activePackageId: Optional[str] = None
    version: str = "1.0"

    def to_dict(self) -> Dict[str, Any]:
        """Convert to JSON-serializable dictionary"""
        return {
            'version': self.version,
            'packages': [p.to_dict() for p in self.packages],
            'activePackageId': self.activePackageId
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'PackagesFile':
        """Create from dictionary"""
        packages = [ReviewPackage.from_dict(p) for p in data.get('packages', [])]
        return cls(
            version=data.get('version', '1.0'),
            packages=packages,
            activePackageId=data.get('activePackageId')
        )

    def get_default(self) -> Optional[ReviewPackage]:
        """Get the default package"""
        for pkg in self.packages:
            if pkg.isDefault:
                return pkg
        return None

    def get_active(self) -> Optional[ReviewPackage]:
        """Get the currently active package"""
        if not self.activePackageId:
            return None
        for pkg in self.packages:
            if pkg.packageId == self.activePackageId:
                return pkg
        return None

    def get_by_id(self, package_id: str) -> Optional[ReviewPackage]:
        """Get a package by ID"""
        for pkg in self.packages:
            if pkg.packageId == package_id:
                return pkg
        return None
