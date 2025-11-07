# Changelog

All notable changes to the Linear Integration plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-11-06

### Added
- **Slash Commands**: New convenient commands for quick access
  - `/ticket` (alias `/issue`): Manage tickets with workflow integration
    - Show current active ticket
    - Create new tickets (launches ticket-creation-agent)
    - Switch to tickets (claims + updates Linear status)
  - `/req` (alias `/requirement`): Query and manage requirements
    - Show recent requirements
    - Display specific requirement details
    - Search requirements by keyword
    - Guide for creating new requirements
    - Run requirement validation

### Implementation
- `commands/ticket.md`, `commands/issue.md` - Ticket command definitions
- `commands/req.md`, `commands/requirement.md` - Requirement command definitions
- `scripts/ticket-command.sh` - Ticket command implementation with workflow integration
- `scripts/req-command.sh` - Requirement command implementation

### Benefits
- Faster access to common operations
- Workflow integration (automatic ticket claiming and status updates)
- Seamless requirement querying
- Reduced context switching

## [1.1.0] - 2025-11-06

### Added
- **Ticket Creation Agent**: Intelligent, context-aware ticket creation assistant
  - Auto-detects context from git status, branch names, and recent commits
  - Infers smart defaults for priority, labels, and descriptions
  - Interactive prompting for missing information
  - Quality validation before ticket creation
  - Automatic requirement linking (REQ-* references)
  - Workflow integration (offers to claim ticket after creation)
  - Duplicate detection with similarity checking

### Changed
- Updated `plugin.json` to register agents directory instead of single agent file
- Enhanced documentation with agent usage examples

### Benefits
- Reduces manual steps in ticket creation workflow
- Ensures consistent ticket quality across team
- Automatically maintains requirement traceability
- Seamless integration with workflow plugin

## [1.0.0] - 2025-10-30

### Added
- Initial release as independent Claude Code plugin
- Linear API integration tools for requirement-ticket traceability
- Environment variable validation with auto-discovery
- Intelligent requirement-ticket caching system (24-hour cache)
- 15 automation scripts for ticket management
- Batch ticket creation from requirements
- Ticket-requirement linking
- Subsystem checklist generation
- Duplicate detection and analysis
- Infrastructure and compliance ticket filtering

### Features
- **fetch-tickets.js**: Fetch all assigned Linear tickets
- **fetch-tickets-by-label.js**: Fetch tickets by label
- **create-requirement-tickets.js**: Batch create tickets from spec/ requirements
- **update-ticket-with-requirement.js**: Link existing tickets to requirements
- **add-subsystem-checklists.js**: Add subsystem checklists to tickets
- **check-duplicates.js**: Find duplicate requirement-ticket mappings
- **list-infrastructure-tickets.js**: List infrastructure-labeled tickets
- **create-tickets.sh**: Batch creation wrapper (PRD → Ops → Dev)
- **run-dry-run.sh**: Preview ticket creation
- **setup-env.sh**: Auto-discover LINEAR_TEAM_ID

### Environment
- AUTO_DISCOVERY: LINEAR_TEAM_ID auto-discovered from Linear API
- CACHE: 24-hour local cache for requirement-ticket mappings
- DOPPLER_READY: Commented for future Doppler integration

### Dependencies
- Node.js >=18.0.0
- Bash >=4.0
