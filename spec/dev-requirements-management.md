# Requirements Management Tooling

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-25
**Status**: Draft

> **See**: prd-requirements-management.md for business/regulatory requirements
> **See**: ops-requirements-management.md for operational procedures
> **See**: tools/requirements/README.md for tool usage documentation

---

## Executive Summary

This document defines the implementation requirements for requirements management tooling, including validation scripts, traceability matrix generation, pre-commit hooks, and code-to-requirement linking mechanisms. These tools automate enforcement of requirements quality and traceability.

---

## Technology Stack

- **Language**: Python 3.8+ (standard library only, no external dependencies)
- **Version Control**: Git with custom hooks in `.githooks/`
- **Output Formats**: Markdown, HTML, CSV (for traceability matrices)
- **Integration**: Pre-commit hooks, manual CLI tools

---

# REQ-d00014: Requirement Validation Tooling

**Level**: Dev | **Implements**: o00013 | **Status**: Draft

The system SHALL implement automated requirement validation via the `elspais` CLI tool (primary) and `tools/requirements/validate_requirements.py` (fallback/programmatic access), checking format compliance, ID uniqueness, valid parent links, and level consistency, with integration into git hooks to prevent invalid requirements from entering the codebase.

Implementation SHALL include:
- Primary CLI tool: `elspais validate` configured via `.elspais.toml`
- Fallback Python scripts in `tools/requirements/` for programmatic/plugin use
- Validation of ID format: `REQ-[pod]NNNNN` pattern
- Uniqueness check: no duplicate IDs across all spec/ files
- Parent validation: all "Implements" references point to existing requirements
- Level consistency: ID prefix matches stated level (p=PRD, o=Ops, d=Dev)
- Status validation: only allowed values (Active, Draft, Deprecated)
- Error reporting with file path and line number
- Exit code 0 on success, 1 on validation errors
- Warning reporting for unusual patterns (e.g., PRD implements PRD)

**Rationale**: The elspais CLI provides standardized requirement validation across projects with consistent configuration via `.elspais.toml`. Local Python scripts remain available for programmatic access by plugins and internal tooling. Automated validation catches errors before code review, reducing rework and ensuring consistency. Integration with git hooks prevents invalid requirements from entering git history, maintaining requirement quality over time.

**Acceptance Criteria**:
- elspais CLI installed and available in PATH
- `.elspais.toml` configuration file present in repository root
- `elspais validate` scans all .md files in spec/ directory recursively
- Validates requirement format matches spec/requirements-format.md specification
- Detects and reports duplicate IDs with file locations
- Validates all "Implements" references exist and are reachable
- Checks ID prefix matches level field (p→PRD, o→Ops, d→Dev)
- Warns about unusual hierarchies (PRD implementing PRD, etc.)
- Outputs summary statistics: total requirements, by level, by status
- Returns exit code 0 only when all requirements valid
- Error messages include file path, line number, and specific issue
- Runnable manually: `elspais validate`
- Local scripts available as fallback: `python3 tools/requirements/validate_requirements.py`

*End* *Requirement Validation Tooling* | **Hash**: 0d6697dc
---

# REQ-d00015: Traceability Matrix Auto-Generation

**Level**: Dev | **Implements**: o00013 | **Status**: Draft

The system SHALL implement automated traceability matrix generation via the `elspais trace` CLI command (primary) and `tools/requirements/generate_traceability.py` (fallback/programmatic access), producing markdown and HTML formats showing requirement hierarchies, with output to the `build-reports/` directory.

Implementation SHALL include:
- Primary CLI tool: `elspais trace` configured via `.elspais.toml`
- Fallback Python scripts in `tools/requirements/` for programmatic/plugin use
- Hierarchical tree structure showing parent-child relationships
- Output formats: markdown (.md), HTML (.html), CSV (.csv)
- HTML format with interactive collapsible tree using JavaScript
- Color-coding by level: PRD (blue), OPS (orange), DEV (green)
- Status badges showing Active/Draft/Deprecated
- Summary statistics: total requirements, counts by level and status
- Orphaned requirement detection (no children implementing them)
- Output directory: `build-reports/combined/traceability/` (configurable in .elspais.toml)

**Rationale**: The elspais CLI provides standardized traceability matrix generation with output to `build-reports/` for CI/CD integration. Local Python scripts remain available for programmatic access by plugins and internal tooling. Traceability matrices provide visual representation of requirement relationships essential for regulatory audits and impact analysis. Auto-generation ensures matrices never become outdated or inconsistent with requirements.

**Acceptance Criteria**:
- elspais CLI installed and available in PATH
- `elspais trace` generates traceability matrices
- Supports multiple output formats: markdown, html, csv
- Markdown output shows hierarchical tree with indentation
- HTML output includes collapsible tree with expand/collapse functionality
- HTML uses color coding: PRD blue, OPS orange, DEV green
- HTML includes "Expand All" and "Collapse All" buttons
- CSV output suitable for import into spreadsheets
- Script detects orphaned requirements (no implementing children)
- Generated files include timestamp and requirement count
- Output directory: `build-reports/combined/traceability/` (per .elspais.toml)
- Runnable manually: `elspais trace`
- Local scripts available as fallback: `python3 tools/requirements/generate_traceability.py --format both`

*End* *Traceability Matrix Auto-Generation* | **Hash**: 4ff6c66e
---

# REQ-d00016: Code-to-Requirement Linking

**Level**: Dev | **Implements**: o00014 | **Status**: Draft

Implementation files SHALL include standardized header comments linking code to requirements using format `IMPLEMENTS REQUIREMENTS: REQ-xxx, REQ-yyy`, enabling traceability from implementation back to requirements for audit and impact analysis.

Implementation SHALL include:
- Header comment format defined in spec/requirements-format.md
- Language-specific comment syntax (SQL: --, Dart/TS/JS: //, Python: #)
- Multi-line format for readability when multiple requirements
- Requirement IDs listed in ascending order
- Header comments placed before first functional code (after imports/declarations)
- Documentation of format in requirements-format.md with examples
- Examples for SQL, Dart, TypeScript, Python

**Rationale**: Code-to-requirement links enable reverse traceability from implementation to requirements, essential for impact analysis when requirements change. Header comments are visible during code review and development. Standardized format enables potential future tooling to verify all code is linked to requirements. Explicit requirement references make compliance audits easier by showing which code implements which regulatory requirements.

**Acceptance Criteria**:
- Header comment format documented in spec/requirements-format.md
- Examples provided for each language: SQL, Dart, TypeScript, Python
- Format: `IMPLEMENTS REQUIREMENTS: REQ-p00xxx, REQ-o00yyy, REQ-d00zzz`
- Multi-line format shown for files implementing many requirements
- Comments use language-appropriate syntax (-- for SQL, // for Dart/TS, # for Python)
- Placed after file-level comments/imports, before functional code
- Requirement IDs in ascending order (p00001, p00002, o00001, d00001)
- Format is machine-readable for future tooling
- Examples include database/*.sql, mobile app code, test files
- CLAUDE.md documents requirement for header comments

*End* *Code-to-Requirement Linking* | **Hash**: c857235a
---

# REQ-d00017: ADR Template and Lifecycle Tooling

**Level**: Dev | **Implements**: o00016 | **Status**: Draft

The system SHALL provide ADR template, lifecycle documentation, and index maintenance in `docs/adr/README.md`, enabling consistent ADR creation and tracking of architectural decisions throughout their lifecycle from Proposed to Accepted to Deprecated/Superseded.

Implementation SHALL include:
- ADR template in docs/adr/README.md with sections: Status, Context, Decision, Consequences, Alternatives
- ADR lifecycle documentation: Proposed → Accepted → Deprecated/Superseded
- ADR index table in docs/adr/README.md: number, title, status, date
- Instructions for creating ADRs linked to tickets
- Guidance on when ADRs are needed vs. not needed
- Examples of ADR-to-requirement linking
- Naming convention: ADR-{number}-{descriptive-title}.md
- Sequential numbering starting from 001

**Rationale**: Standardized ADR template ensures consistent decision documentation. Lifecycle documentation guides teams through proposal, acceptance, and deprecation processes. Centralized index in README.md provides single source of truth for all decisions. Examples and guidance reduce friction in ADR creation. Explicit criteria for when ADRs are needed prevents both over-documentation and under-documentation.

**Acceptance Criteria**:
- docs/adr/README.md contains ADR template with required sections
- Template includes: Status, Context, Decision, Consequences, Alternatives
- Lifecycle stages documented: Proposed, Accepted, Deprecated, Superseded
- ADR index table maintained showing: number, title, status, date, link
- Guidance provided: when to create ADR, when not to create ADR
- Examples show ADR linking to requirements and tickets
- File naming convention documented: ADR-NNN-descriptive-title.md
- Workflow documented: ticket → ADR draft → review → accepted → implement
- Instructions for updating index when adding new ADRs
- Examples of supersession: how to link old ADR to replacement

*End* *ADR Template and Lifecycle Tooling* | **Hash**: 36997d8f
---

# REQ-d00018: Git Hook Implementation

**Level**: Dev | **Implements**: o00017 | **Status**: Draft

The system SHALL implement pre-push hook in `.githooks/pre-push` that enforces requirement validation using `elspais validate` and `elspais index validate`, blocking pushes with validation errors, with configuration instructions in `.githooks/README.md`.

Implementation SHALL include:
- Bash script in .githooks/pre-push executable by git
- Execution of `elspais validate` for requirement format validation
- Execution of `elspais index validate` for INDEX.md consistency
- Exit code 1 (block push) on validation failure
- Clear error messages directing developer to fix issues
- Configuration command: `git config core.hooksPath .githooks`
- Documentation in .githooks/README.md with troubleshooting
- Bypass mechanism documented: `git push --no-verify` (discouraged)
- Requirement: elspais CLI must be installed for hooks to function

**Rationale**: Pre-push hooks enforce quality gates before code enters remote repository, preventing invalid requirements from being shared with the team. Using the elspais CLI provides standardized validation consistent with CI/CD. Clear error messages help developers fix issues before pushing. Hook configuration per repository enables consistent enforcement across team.

**Acceptance Criteria**:
- .githooks/pre-push executable bash script (chmod +x)
- Hook runs `elspais validate` for requirement validation
- Hook runs `elspais index validate` for INDEX.md validation
- Returns exit code 1 to block push if validation fails
- Outputs clear error messages with file/line references
- Documents configuration in .githooks/README.md
- Includes troubleshooting section for common issues
- Documents bypass method: --no-verify (with warnings)
- Configuration required once per developer: git config core.hooksPath .githooks
- Hook works correctly on Linux, macOS, Windows Git Bash
- elspais CLI must be installed (hook fails gracefully with clear message if missing)
- CLAUDE.md documents hook setup requirement
- Local Python scripts remain available for plugin/programmatic use

*End* *Git Hook Implementation* | **Hash**: b2aee05d
---

# REQ-d00053: Development Environment and Tooling Setup

**Level**: Dev | **Implements**: o00017 | **Status**: Draft

Development environment SHALL provide standardized, repeatable tooling configuration including IDE integrations, code analysis tools, and workflow automation to ensure consistent developer experience and productivity.

Development environment setup SHALL include:
- IDE/editor configuration and extensions (e.g., Claude Code with MCP servers)
- Code quality and analysis tools (e.g., linters, formatters)
- Project management integrations (e.g., Linear integration with IDE)
- Documentation and reference tools
- Setup scripts or documentation for reproducible environment
- Tool configuration tracked in version control where appropriate

**Rationale**: Standardized development environment ensures all developers have consistent tooling, reducing "works on my machine" issues. IDE integrations and automation tools improve developer productivity. Reproducible setup enables quick onboarding of new developers. Tracking tool configurations in version control ensures team-wide consistency. Project management integrations (Linear, Claude Code tools) streamline workflow and maintain traceability.

**Acceptance Criteria**:
- Development environment setup documented (e.g., in CLAUDE.md or setup scripts)
- IDE extensions and configurations specified
- Integration tools (Linear, code analysis) installed and configured
- Setup process can be completed by new developer following documentation
- Tool configurations maintain compatibility across team
- Setup documentation kept up-to-date with tool changes
- Integration tools facilitate requirement traceability workflow

*End* *Development Environment and Tooling Setup* | **Hash**: 404b139b
---

## Tool Usage Examples

### Manual Requirement Validation (elspais CLI - Primary)

```bash
# Validate all requirements using elspais CLI
elspais validate

# Validate INDEX.md consistency
elspais index validate

# Example output on success:
# Validating requirements in spec/...
# Found 42 requirements
# All requirements valid
# Summary: PRD=20, Ops=12, Dev=10

# Example output on error:
# ERROR: Duplicate requirement ID
#   REQ-p00036 found in:
#     - spec/prd-requirements.md:45
#     - spec/prd-diary-app.md:123
```

### Manual Requirement Validation (Local Scripts - Fallback/Plugins)

```bash
# Local Python scripts remain available for programmatic/plugin use
python3 tools/requirements/validate_requirements.py

# These scripts are used by:
# - Claude Code plugins (pending elspais --json support)
# - Internal tooling requiring programmatic access
```

### Manual Traceability Matrix Generation

```bash
# Generate traceability matrix using elspais CLI (primary)
elspais trace

# Output goes to build-reports/combined/traceability/ (per .elspais.toml)

# Fallback: Local Python scripts for programmatic use
python3 tools/requirements/generate_traceability.py --format both
python3 tools/requirements/generate_traceability.py --format csv
```

### Git Hook Setup

```bash
# One-time setup per developer
git config core.hooksPath .githooks

# Verify configuration
git config --get core.hooksPath
# Should output: .githooks

# Ensure elspais is installed (required for hooks)
which elspais || echo "Install elspais: pip install elspais"

# Test hook manually
.githooks/pre-push

# Hook runs automatically on git push
git push origin feature-branch
# Pre-push hook will:
# 1. Run elspais validate
# 2. Run elspais index validate
# 3. Allow push if valid, block if invalid
```

### Code Header Comment Examples

**SQL Example** (`database/schema.sql`):
```sql
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-d00007: Database Schema Implementation

CREATE TABLE record_audit (
  event_uuid UUID PRIMARY KEY,
  ...
);
```

**Dart Example** (`lib/services/sync_service.dart`):
```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation
//   REQ-d00013: Application Instance UUID Generation

class SyncService {
  ...
}
```

**TypeScript Example** (`src/api/requirements.ts`):
```typescript
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00014: Requirement Validation Tooling
//   REQ-d00015: Traceability Matrix Auto-Generation

export class RequirementValidator {
  ...
}
```

---

## Testing Requirements

### Unit Tests

- validate_requirements.py SHALL have unit tests covering:
  - Valid requirement parsing
  - Format error detection
  - Duplicate ID detection
  - Invalid parent reference detection
  - Level mismatch detection

- generate_traceability.py SHALL have unit tests covering:
  - Requirement hierarchy construction
  - Markdown output format
  - HTML output format
  - CSV output format
  - Orphaned requirement detection

### Integration Tests

- Pre-commit hook SHALL have integration tests covering:
  - spec/ file change detection
  - Matrix regeneration triggering
  - Validation execution
  - Commit blocking on errors
  - Matrix auto-staging

---

## References

- **Product Requirements**: prd-requirements-management.md
- **Operations Procedures**: ops-requirements-management.md
- **Format Specification**: requirements-format.md
- **Tool Documentation**: tools/requirements/README.md
- **ADR Process**: docs/adr/README.md
- **Hook Configuration**: .githooks/README.md
- **Development Practices**: dev-core-practices.md

---

**Document Classification**: Internal Use - Development Standards
**Review Frequency**: Quarterly or when tooling changes
**Owner**: Development Lead / DevOps Team
