# ANSPAR Workflow - Git Workflow Enforcement Plugin

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-31
**Status**: Active

> **See**: README.md for spec/ directory governance rules
> **See**: ../plugins/anspar-workflow/ for implementation
> **Implements**: Main project REQ-o00017 (Version Control Workflow)

---

## Executive Summary

ANSPAR Workflow enforces requirement traceability and ticket lifecycle management through git hooks and per-worktree state tracking, ensuring all commits reference formal requirements and are linked to active tickets.

---

### REQ-d00120: Per-Worktree State Management

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL maintain independent workflow state per git worktree using .git/WORKFLOW_STATE file, enabling multiple worktrees to work on same or different tickets concurrently without state conflicts.

Implementation SHALL include:
- JSON state file at .git/WORKFLOW_STATE (per-worktree location)
- Active ticket tracking: ticketId, requirements, metadata
- Append-only history array with all workflow events
- State schema: activeTicket object, history array, metadata
- Git-dir detection for correct state file placement
- State validation on read and write operations

**Rationale**: Per-worktree state enables distributed development. Independent state prevents conflicts. Append-only history provides complete audit trail.

**Acceptance Criteria**:
- State file location: $(git rev-parse --git-dir)/WORKFLOW_STATE
- Multiple worktrees maintain independent state
- State survives git operations (commit, checkout, merge)
- History records: claims, releases, commits with timestamps
- Schema documented in docs/workflow-state-schema.md

---

### REQ-d00121: Requirement Reference Validation

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL validate all commit messages contain at least one requirement reference in format REQ-{type}{number} where type is p/o/d and number is 5 digits, blocking commits lacking requirement references.

Validation SHALL ensure:
- Regex pattern: `REQ-[pdo][0-9]{5}`
- Multiple requirements supported: "REQ-p00042, REQ-d00027"
- Validation via commit-msg git hook
- Clear error messages with format examples
- Bypass available via git commit --no-verify
- Requirement suggestion helper (suggest-req.sh)

**Rationale**: Requirement references enable traceability from code to requirements. Automated enforcement prevents missing references. Examples in error messages aid compliance.

**Acceptance Criteria**:
- commit-msg hook validates message format
- Hook blocks commit if no REQ reference found (exit 1)
- Error message shows expected format with examples
- Multiple REQ references in single commit allowed
- suggest-req.sh provides context-aware suggestions

---

### REQ-d00122: Active Ticket Enforcement

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL require active ticket to be claimed before allowing commits, enforcing ticket-driven development workflow and preventing uncommitted work from orphaned tickets, with emergency bypass mechanism for critical situations.

Enforcement SHALL include:
- Pre-commit hook checks for activeTicket in state
- Block commit if activeTicket is null
- Emergency bypass: ANSPAR_WORKFLOW_SKIP=true git commit (logged to history)
- Emergency commits flagged for post-hoc ticket association
- Clear error with claim-ticket.sh usage instructions
- Ticket claiming via scripts/claim-ticket.sh
- Ticket release via scripts/release-ticket.sh
- Support for ticket switching and resuming

**Rationale**: Ticket enforcement ensures all work linked to tickets. Prevents orphaned commits. Emergency bypass accommodates critical situations while maintaining audit trail. Post-hoc flagging ensures emergencies are reviewed.

**Acceptance Criteria**:
- Pre-commit hook validates activeTicket exists
- Hook blocks commit if no ticket claimed (exit 1)
- ANSPAR_WORKFLOW_SKIP=true bypasses check and logs to history
- Emergency bypasses marked with flag for review
- Error shows how to claim ticket
- claim-ticket.sh updates state with ticket ID and metadata
- release-ticket.sh sets activeTicket = null

---

### REQ-d00123: Workflow State Transitions

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL support essential ticket operations (claim, release, status) with optional convenience operations for workflow flexibility.

Essential operations:
- Claim: claim-ticket.sh <TICKET-ID> - start working on ticket
- Release: release-ticket.sh [REASON] - stop working, mark complete
- Status: get-active-ticket.sh - show current state

Optional operations (nice-to-have for small teams):
- Switch: switch-ticket.sh <NEW-ID> <REASON> - convenience for claim after release
- Resume: resume-ticket.sh - interactive selection from history
- History: list-history.sh - audit trail viewer

**Rationale**: Essential operations (claim/release/status) provide core workflow. Optional operations add convenience without complexity. Small teams can start with essentials, add optional features as needed.

**Acceptance Criteria**:
- Claim, release, and status scripts are functional (required)
- Optional scripts may be implemented for convenience
- Switch atomically releases current and claims new (if implemented)
- Resume shows list of recently released tickets (if implemented)
- History shows chronological workflow events (if implemented)
- Scripts use jq for safe JSON manipulation

---

### REQ-d00124: Distributed Worktree Support

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL support git worktrees with independent state management, enabling multiple worktrees to work on same ticket (valid for multi-PR workflows) or different tickets concurrently.

Worktree support SHALL ensure:
- Each worktree has independent .git/WORKFLOW_STATE
- Multiple worktrees can claim same ticket (valid scenario)
- State file location determined via git rev-parse --git-dir
- No cross-worktree state dependencies
- Worktree deletion cleans up state automatically
- Documentation includes worktree usage examples

**Rationale**: Worktree support enables parallel development. Independent state prevents conflicts. Same-ticket multi-worktree valid for implementation + tests in separate PRs.

**Acceptance Criteria**:
- State file created in worktree's .git directory
- Multiple worktrees with same ticket work correctly
- No shared state between worktrees
- Worktree removal removes state file
- README documents worktree workflows

---

### REQ-d00125: Git Hook Integration

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL provide git hooks for pre-commit, commit-msg, post-commit, and session-start events, integrating workflow enforcement into git operations and Claude Code sessions.

Hook integration SHALL include:
- pre-commit: validates active ticket exists
- commit-msg: validates REQ references in message
- post-commit: records commit in workflow history
- session-start: displays workflow status at Claude Code startup
- hooks.json: SessionStart event configuration
- Installation instructions in README

**Rationale**: Git hooks provide enforcement points. Session-start hook informs developer of workflow state. Post-commit recording maintains audit trail.

**Acceptance Criteria**:
- All hooks executable (chmod +x)
- Hooks use ${CLAUDE_PLUGIN_ROOT} for path resolution
- pre-commit and commit-msg exit 1 to block commits
- post-commit always exits 0 (never blocks)
- session-start outputs JSON for Claude Code
- README documents hook installation

---

### REQ-d00126: State File Recovery

**Level**: Dev | **Implements**: d00120 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL detect and recover from corrupted state files without blocking development, ensuring workflow resilience in face of file corruption or JSON parsing errors.

Recovery SHALL include:
- Corruption detection on state file read
- Backup restoration if .git/WORKFLOW_STATE.bak exists
- State regeneration with user input if no backup
- Graceful degradation: Allow commits with warning if state unrecoverable
- Corruption causes logged for debugging

**Rationale**: Small team can't afford blocked development due to corrupted state. Auto-recovery keeps workflow moving. Backup files provide safety net. Graceful degradation ensures work continues even with issues.

**Acceptance Criteria**:
- Invalid JSON triggers recovery workflow
- Automatic backup created before each state write
- Recovery never blocks commits (worst case: warning + allow)
- Corruption events logged to .git/WORKFLOW_ERRORS.log
- User prompted to manually fix or regenerate state if auto-recovery fails
- Backup files retain last 2 versions (.bak, .bak2)

---

## References

- **Implementation**: ../plugins/anspar-workflow/
- **Main Project Requirement**: ../../spec/ops-requirements-management.md (REQ-o00017)
- **Marketplace Spec**: dev-marketplace.md

---

**Document Classification**: Internal Use - Development Standards
**Review Frequency**: Quarterly
**Owner**: Workflow Plugin Maintainers
