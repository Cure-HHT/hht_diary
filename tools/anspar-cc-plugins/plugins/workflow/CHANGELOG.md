# Changelog

All notable changes to the workflow plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.4.0] - 2025-11-07

### Added
- **`/start_phase` command**: Activate project phase protections (production, etc.)
  - Interactive command with prominent warnings and confirmation
  - Automates production phase activation:
    - Sets `WORKFLOW_PROTECTION_ENABLED=true` repository variable
    - Renames `CODEOWNERS-PRE-PRODUCTION` → `CODEOWNERS` via PR
  - Uses GitHub API for repository variable management
  - Creates properly formatted PR with security checklist
  - Comprehensive error handling and manual fallback instructions
- **`start-phase.sh` script**: Automation script for phase activation
  - GitHub API integration for repository variables
  - Branch creation and automated PR workflow
  - Detailed status output and next steps
- **Production phase documentation**: Complete activation/deactivation procedures

### Benefits
- One-command activation of production protections
- Prevents mistakes with prominent warnings
- Reduces manual steps in critical workflow transitions
- Provides safety confirmation before making changes
- Future-ready for additional project phases

## [2.3.0] - 2025-11-06

### Added
- **Dev Container Detection**: SessionStart hook now detects if working outside dev container
  - Checks for container environment variables
  - Checks for container marker files (/.dockerenv, /run/.containerenv)
  - Verifies if .devcontainer directory exists in repository
  - Provides informational warning with setup instructions
- **Environment consistency guidance**: Helps maintain team environment parity
- **Non-blocking warning**: Informational only, doesn't prevent work outside container

### Changed
- **SessionStart hook enhanced**: Now includes both workflow status and environment checks
- **Comprehensive session context**: Users get full picture of workflow and environment state

### Benefits
- Reduces "works on my machine" issues
- Guides new developers to standardized environment
- Maintains consistent tool versions across team
- Optional - respects user choice to work outside container

## [2.2.0] - 2025-11-06

### Added
- **Enhanced ticket creation integration**: UserPromptSubmit hook now suggests using ticket-creation-agent
- **Additional detection patterns**:
  - Bug fix detection: "fix bug", "fix issue", "fix problem"
  - Documentation work: "update docs", "write README", "add documentation"
- **Actionable guidance**: Messages now include specific commands and agent invocations
- **Seamless workflow**: Direct integration with intelligent ticket-creation-agent

### Changed
- **Improved messaging**: Warnings now point to ticket-creation-agent instead of manual scripts
- **Clearer options**: When no ticket exists, provide 3 clear options (create, claim, explore)
- **Better user experience**: Reduced friction in ticket creation workflow

### Benefits
- Easier ticket creation (just say "create a ticket for...")
- Smart context-aware suggestions from ticket-creation-agent
- Reduced manual steps in workflow
- Maintains workflow discipline without being intrusive

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
- Tracker-agnostic design (Linear integration via linear-api)

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
- Optional: linear-api (for Linear API features)

### Future
- GitHub PR hooks integration
- /start-work and /finish-work Claude Code commands
- Support for additional ticket trackers (Notion, Jira, etc.)
- Worktree state synchronization UI
- Ticket completion confirmation workflow
