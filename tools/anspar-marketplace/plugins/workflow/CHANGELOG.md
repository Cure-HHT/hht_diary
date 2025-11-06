# Changelog

All notable changes to the workflow plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-31

### Added
- Major version 2.0 release of workflow - next-generation workflow enforcement
- Enhanced architecture with improved state management and advanced features
- Per-worktree state management (.git/WORKFLOW_STATE)
- Git hooks for workflow enforcement:
  - commit-msg: Validates REQ reference in commit messages
  - pre-commit: Validates active ticket exists in worktree state
  - post-commit: Updates worktree state history
- Ticket lifecycle management scripts:
  - claim-ticket.sh: Claim a ticket for this worktree
  - release-ticket.sh: Release the active ticket
  - validate-commit-msg.sh: Check for REQ-xxx references
  - get-active-ticket.sh: Read active ticket from worktree state
  - suggest-req.sh: Suggest REQ IDs based on active ticket
- Distributed state management for multiple concurrent worktrees
- Tracker-agnostic design (Linear integration via linear-integration)

### Features
- **Distributed Worktrees**: Multiple worktrees can work on same/different tickets
- **REQ Traceability**: Enforces requirement references in all commits
- **State Isolation**: Per-worktree .git/WORKFLOW_STATE as source of truth
- **Race Tolerance**: Idempotent operations, accepts benign races
- **Composability**: Pluggable ticket tracker backends

### Architecture
- **State Management**: JSON state file per worktree
- **Linear Integration**: Coordination layer only (not ownership lock)
- **Git Hooks**: Native git hooks (no external dependencies)
- **Agent Support**: Works with both human and AI agents

### Dependencies
- Bash >=4.0
- Git
- jq (for JSON parsing in scripts)
- Optional: linear-integration (for Linear API features)

### Future
- GitHub PR hooks integration
- /start-work and /finish-work Claude Code commands
- Support for additional ticket trackers (Notion, Jira, etc.)
- Worktree state synchronization UI
- Ticket completion confirmation workflow
