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

**Level**: Dev | **Status**: Draft | **Implements**: o00013

## Rationale

The elspais CLI provides standardized requirement validation across projects with consistent configuration via .elspais.toml. Local Python scripts remain available for programmatic access by plugins and internal tooling. Automated validation catches errors before code review, reducing rework and ensuring consistency. Integration with git hooks prevents invalid requirements from entering git history, maintaining requirement quality over time. This requirement supports REQ-o00013 by providing the technical implementation of requirement validation tooling.

## Assertions

A. The system SHALL implement automated requirement validation via the elspais CLI tool as the primary validation mechanism.
B. The system SHALL provide tools/requirements/validate_requirements.py as a fallback validation tool for programmatic and plugin access.
C. The elspais CLI SHALL be configured via .elspais.toml in the repository root.
D. The system SHALL validate requirement ID format matches the REQ-[pod]NNNNN pattern.
E. The system SHALL check for duplicate requirement IDs across all spec/ files.
F. The system SHALL validate that all 'Implements' references point to existing requirements.
G. The system SHALL verify level consistency between ID prefix and stated level (p=PRD, o=Ops, d=Dev).
H. The system SHALL validate that status values are limited to allowed values (Active, Draft, Deprecated).
I. The system SHALL report errors with file path and line number.
J. The system SHALL exit with code 0 on successful validation and code 1 on validation errors.
K. The system SHALL report warnings for unusual patterns such as PRD implementing PRD.
L. The elspais CLI SHALL be installed and available in PATH.
M. The elspais validate command SHALL scan all .md files in the spec/ directory recursively.
N. The system SHALL validate requirement format matches the spec/requirements-format.md specification.
O. The system SHALL output summary statistics including total requirements, counts by level, and counts by status.
P. Error messages SHALL include file path, line number, and specific issue description.
Q. The elspais validate command SHALL be executable manually via the command line.
R. The fallback Python script SHALL be executable via python3 tools/requirements/validate_requirements.py.
S. The system SHALL integrate requirement validation into git hooks to prevent invalid requirements from entering the codebase.

*End* *Requirement Validation Tooling* | **Hash**: 5ef43845
---

# REQ-d00015: Traceability Matrix Auto-Generation

**Level**: Dev | **Status**: Draft | **Implements**: o00013

## Rationale

The elspais CLI provides standardized traceability matrix generation with output to build-reports/ for CI/CD integration. Local Python scripts remain available for programmatic access by plugins and internal tooling. Traceability matrices provide visual representation of requirement relationships essential for regulatory audits and impact analysis under FDA 21 CFR Part 11. Auto-generation ensures matrices never become outdated or inconsistent with requirements, supporting ALCOA+ principles of complete and consistent documentation.

## Assertions

A. The system SHALL implement automated traceability matrix generation via the elspais trace CLI command as the primary tool.
B. The system SHALL provide tools/requirements/generate_traceability.py as a fallback for programmatic access.
C. The system SHALL configure the elspais trace command via .elspais.toml.
D. The system SHALL produce traceability matrices in markdown format.
E. The system SHALL produce traceability matrices in HTML format.
F. The system SHALL produce traceability matrices in CSV format.
G. The system SHALL output generated files to the build-reports/combined/traceability/ directory as configurable in .elspais.toml.
H. The system SHALL display requirement hierarchies using a hierarchical tree structure showing parent-child relationships.
I. Markdown output SHALL show hierarchical tree structure with indentation.
J. HTML output SHALL include interactive collapsible tree using JavaScript.
K. HTML output SHALL include Expand All and Collapse All buttons.
L. HTML output SHALL use color-coding by requirement level: PRD as blue, OPS as orange, and DEV as green.
M. The system SHALL display status badges showing Active, Draft, or Deprecated states.
N. The system SHALL include summary statistics showing total requirements count.
O. The system SHALL include summary statistics showing counts by level.
P. The system SHALL include summary statistics showing counts by status.
Q. The system SHALL detect orphaned requirements that have no children implementing them.
R. CSV output SHALL be suitable for import into spreadsheets.
S. Generated files SHALL include a timestamp.
T. Generated files SHALL include requirement count.
U. The elspais CLI tool SHALL be installed and available in PATH.
V. The system SHALL support manual execution via the elspais trace command.
W. The system SHALL support fallback execution via python3 tools/requirements/generate_traceability.py --format both.

*End* *Traceability Matrix Auto-Generation* | **Hash**: 761084dc
---

# REQ-d00016: Code-to-Requirement Linking

**Level**: Dev | **Status**: Draft | **Implements**: o00014

## Rationale

Code-to-requirement links enable reverse traceability from implementation to requirements, essential for impact analysis when requirements change. Header comments are visible during code review and development. Standardized format enables potential future tooling to verify all code is linked to requirements. Explicit requirement references make compliance audits easier by showing which code implements which regulatory requirements.

## Assertions

A. Implementation files SHALL include standardized header comments linking code to requirements.
B. Header comments SHALL use the format 'IMPLEMENTS REQUIREMENTS: REQ-xxx, REQ-yyy'.
C. The system SHALL use language-specific comment syntax for header comments (SQL: --, Dart/TS/JS: //, Python: #).
D. Header comments SHALL use multi-line format for readability when multiple requirements are referenced.
E. Requirement IDs in header comments SHALL be listed in ascending order.
F. Header comments SHALL be placed before the first functional code (after imports/declarations).
G. The header comment format SHALL be documented in spec/requirements-format.md.
H. The documentation in spec/requirements-format.md SHALL include examples for SQL, Dart, TypeScript, and Python.
I. The documentation SHALL provide examples showing the format 'IMPLEMENTS REQUIREMENTS: REQ-p00xxx, REQ-o00yyy, REQ-d00zzz'.
J. The documentation SHALL include multi-line format examples for files implementing many requirements.
K. The documentation SHALL show examples with language-appropriate syntax (-- for SQL, // for Dart/TS, # for Python).
L. Examples SHALL demonstrate header comment placement after file-level comments/imports and before functional code.
M. Examples SHALL demonstrate requirement IDs in ascending order (p00001, p00002, o00001, d00001).
N. The header comment format SHALL be machine-readable for future tooling.
O. The documentation SHALL include examples from database/*.sql files.
P. The documentation SHALL include examples from mobile app code.
Q. The documentation SHALL include examples from test files.
R. CLAUDE.md SHALL document the requirement for header comments in implementation files.

*End* *Code-to-Requirement Linking* | **Hash**: 8bf2c189
---

# REQ-d00017: ADR Template and Lifecycle Tooling

**Level**: Dev | **Status**: Draft | **Implements**: o00016

## Rationale

This requirement establishes the foundational structure for Architecture Decision Records (ADRs) to ensure consistent documentation of architectural choices throughout the project lifecycle. ADRs provide a historical record of why specific technical decisions were made, which is critical for FDA-regulated systems where design rationale must be traceable and auditable. The standardized template, lifecycle stages, and centralized index reduce documentation friction while preventing both over-documentation and under-documentation. By linking ADRs to requirements and tickets, the system maintains bidirectional traceability between architectural decisions and functional requirements, supporting regulatory compliance and long-term maintainability.

## Assertions

A. The system SHALL provide an ADR template in docs/adr/README.md.
B. The ADR template SHALL include the following sections: Status, Context, Decision, Consequences, and Alternatives.
C. The system SHALL document ADR lifecycle stages: Proposed, Accepted, Deprecated, and Superseded.
D. The system SHALL maintain an ADR index table in docs/adr/README.md.
E. The ADR index table SHALL display the following fields for each ADR: number, title, status, date, and link.
F. The system SHALL provide instructions for creating ADRs linked to tickets.
G. The system SHALL provide guidance on when ADRs are needed.
H. The system SHALL provide guidance on when ADRs are not needed.
I. The system SHALL provide examples of ADR-to-requirement linking.
J. The system SHALL document the ADR file naming convention as ADR-{number}-{descriptive-title}.md.
K. The system SHALL use sequential numbering for ADRs starting from 001.
L. The system SHALL document the ADR workflow: ticket → ADR draft → review → accepted → implement.
M. The system SHALL provide instructions for updating the index when adding new ADRs.
N. The system SHALL provide examples of ADR supersession showing how to link old ADRs to replacement ADRs.

*End* *ADR Template and Lifecycle Tooling* | **Hash**: fc6fd26f
---

# REQ-d00018: Git Hook Implementation

**Level**: Dev | **Status**: Draft | **Implements**: o00017

## Rationale

Pre-push hooks enforce quality gates before code enters the remote repository, preventing invalid requirements from being shared with the team. Using the elspais CLI provides standardized validation consistent with CI/CD pipelines. Clear error messages help developers fix issues locally before pushing. Hook configuration per repository enables consistent enforcement across the team while maintaining cross-platform compatibility.

## Assertions

A. The system SHALL implement a pre-push hook in .githooks/pre-push that enforces requirement validation.
B. The pre-push hook SHALL be implemented as a Bash script executable by git.
C. The pre-push hook SHALL execute 'elspais validate' for requirement format validation.
D. The pre-push hook SHALL execute 'elspais index validate' for INDEX.md consistency validation.
E. The pre-push hook SHALL return exit code 1 to block the push when validation fails.
F. The pre-push hook SHALL output clear error messages with file and line references when validation fails.
G. The pre-push hook SHALL fail gracefully with a clear message if the elspais CLI is not installed.
H. The .githooks/pre-push file SHALL be executable (chmod +x permissions).
I. The system SHALL provide configuration instructions in .githooks/README.md.
J. The .githooks/README.md file SHALL document the configuration command: 'git config core.hooksPath .githooks'.
K. The .githooks/README.md file SHALL include a troubleshooting section for common issues.
L. The .githooks/README.md file SHALL document the bypass mechanism using 'git push --no-verify' with warnings discouraging its use.
M. The pre-push hook SHALL work correctly on Linux, macOS, and Windows Git Bash environments.
N. The CLAUDE.md file SHALL document the hook setup requirement.
O. Local Python scripts SHALL remain available for plugin and programmatic use.

*End* *Git Hook Implementation* | **Hash**: 70fae011
---

# REQ-d00053: Development Environment and Tooling Setup

**Level**: Dev | **Status**: Draft | **Implements**: o00017

## Rationale

Standardized development environments ensure all developers have consistent tooling, reducing "works on my machine" issues and environment drift. IDE integrations and automation tools improve developer productivity by providing seamless access to code analysis, project management, and documentation resources. Reproducible setup processes enable quick onboarding of new developers and ensure team-wide consistency. Tracking tool configurations in version control maintains environmental parity across the team. Project management integrations (Linear, Claude Code tools) streamline workflow and maintain the requirement traceability necessary for FDA 21 CFR Part 11 compliance.

## Assertions

A. The development environment SHALL provide standardized, repeatable tooling configuration.
B. The development environment SHALL include IDE/editor configuration and extensions.
C. The development environment SHALL include code quality and analysis tools.
D. The development environment SHALL include project management integrations.
E. The development environment SHALL include documentation and reference tools.
F. The development environment SHALL include setup scripts or documentation for reproducible environment configuration.
G. Tool configurations SHALL be tracked in version control where appropriate.
H. Development environment setup SHALL be documented in accessible locations such as CLAUDE.md or setup scripts.
I. IDE extensions and configurations SHALL be specified in the documentation.
J. Integration tools for project management and code analysis SHALL be installed and configured.
K. The setup process SHALL be completable by a new developer following the provided documentation.
L. Tool configurations SHALL maintain compatibility across the development team.
M. Setup documentation SHALL be kept up-to-date with tool changes.
N. Integration tools SHALL facilitate the requirement traceability workflow.

*End* *Development Environment and Tooling Setup* | **Hash**: a00606aa
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
