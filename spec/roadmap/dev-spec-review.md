# Spec Review System - Development Requirements

This file defines development requirements for the collaborative spec review system.

## Related Tickets

- CUR-609: [Feature] Spec Review System for Requirement Documents

---

### REQ-d00086: Spec Review Data Model

**Level**: Dev | **Implements**: - | **Status**: Draft

The spec review system SHALL implement a data model supporting:
1. Review flags to mark REQs for review
2. Comment threads with position-aware anchoring (line, block, word, general)
3. Status change requests with approval workflows
4. Review sessions to group user activity
5. Configuration for approval rules and sync behavior

All data classes SHALL:
- Use Python dataclasses with full type hints
- Support JSON serialization/deserialization for storage
- Include validation methods returning (bool, List[str]) tuples
- Provide factory methods for creating new instances with auto-generated IDs/timestamps

**Rationale**: A well-defined data model enables consistent storage, serialization, and validation across the review system while maintaining FDA audit trail requirements.

**Acceptance Criteria**:
- Data classes for CommentPosition, Comment, Thread, ReviewFlag, Approval, StatusRequest, ReviewSession, ReviewConfig exist
- All classes have to_dict() and from_dict() methods
- All classes have validate() methods
- Unit tests achieve 100% coverage of data model

*End* *Spec Review Data Model* | **Hash**: TBD
---

### REQ-d00087: Position Resolution with Fallback

**Level**: Dev | **Implements**: d00086 | **Status**: Draft

The spec review system SHALL resolve comment positions against current REQ content with the following strategy:

1. If REQ hash matches the hash when comment was created: Return exact position
2. If hash differs, try fallback strategies in order:
   a. Use lineNumber if still within valid range
   b. Search for fallbackContext substring
   c. Find keyword at specified occurrence
   d. Fall back to "general" (whole-REQ)

Position resolution SHALL return confidence levels:
- "exact": Hash matches, position is precise
- "approximate": Hash differs but fallback succeeded
- "unanchored": All fallbacks failed, defaults to general

**Rationale**: Requirements change over time. Position fallback ensures comments remain useful even when the REQ content drifts, while confidence levels help users understand reliability.

**Acceptance Criteria**:
- ResolvedPosition class captures resolved coordinates and confidence
- resolve_position() function implements the fallback algorithm
- Helper functions for line/character offset conversions exist
- Unit tests cover all position types and fallback scenarios

*End* *Position Resolution with Fallback* | **Hash**: TBD
---

### REQ-d00088: Review Storage Operations

**Level**: Dev | **Implements**: d00086 | **Status**: Draft

The spec review system SHALL provide atomic storage operations:

1. **Helper functions**:
   - Atomic JSON writes using temp file + rename pattern
   - Safe JSON reads with proper error handling

2. **Config operations**: Load/save ReviewConfig with defaults

3. **Session operations**: Create, load, list (sorted by date), delete

4. **Review flag operations**: Load/save with REQ ID normalization

5. **Thread operations**:
   - Load/save threads files
   - Add threads and comments
   - Resolve/unresolve threads

6. **Status request operations**:
   - Create status change requests
   - Add approvals with state recalculation
   - Mark requests as applied

7. **Merge operations** for collaborative workflows:
   - Merge threads by combining unique threads and merging comments
   - Merge status files by combining approvals and recalculating state
   - Merge review flags taking newer timestamp but merging scopes

**Rationale**: Atomic operations ensure data integrity. Merge operations enable multi-user collaboration via git branches.

**Acceptance Criteria**:
- All file writes are atomic (temp + rename)
- Missing files return sensible defaults
- Thread/status operations support CRUD with validation
- Merge operations correctly combine data from multiple sources
- Unit tests achieve full coverage

*End* *Review Storage Operations* | **Hash**: TBD
---

### REQ-d00089: Git Branch Management

**Level**: Dev | **Implements**: d00086 | **Status**: Draft

The spec review system SHALL manage git branches for collaborative reviews:

1. **Branch naming**: `reviews/{user}/{session}` convention with sanitization
2. **Branch parsing**: Extract user/session from branch names
3. **Git utilities**: Current branch detection, remote discovery, branch existence checks
4. **Branch operations**: Create, checkout, push, fetch review branches
5. **Listing/discovery**: List local/remote review branches, find all review users
6. **Cleanup**: Delete local/remote branches, cleanup old branches by age
7. **Conflict detection**: Check for uncommitted changes before branch operations

All operations SHALL handle missing remotes and invalid repos gracefully.

**Rationale**: Git-based branch management enables distributed collaboration with audit trails while leveraging existing git infrastructure.

**Acceptance Criteria**:
- Branch names follow `reviews/{user}/{session}` convention
- Create/checkout/push/fetch operations work with local and remote repos
- Branch listing correctly filters review branches
- Error handling gracefully handles edge cases
- Unit tests cover all operations

*End* *Git Branch Management* | **Hash**: TBD
---
