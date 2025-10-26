# Requirements Management Tooling

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-25
**Status**: Active

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

### REQ-d00014: Requirement Validation Tooling

**Level**: Dev | **Implements**: o00013 | **Status**: Active

The system SHALL implement automated requirement validation via `tools/requirements/validate_requirements.py`, checking format compliance, ID uniqueness, valid parent links, and level consistency, with integration into pre-commit hooks to prevent invalid requirements from entering the codebase.

Implementation SHALL include:
- Python script scanning `spec/` directory for requirement blocks
- Validation of ID format: `REQ-[pod]NNNNN` pattern
- Uniqueness check: no duplicate IDs across all spec/ files
- Parent validation: all "Implements" references point to existing requirements
- Level consistency: ID prefix matches stated level (p=PRD, o=Ops, d=Dev)
- Status validation: only allowed values (Active, Draft, Deprecated)
- Error reporting with file path and line number
- Exit code 0 on success, 1 on validation errors
- Warning reporting for unusual patterns (e.g., PRD implements PRD)

**Rationale**: Automated validation catches errors before code review, reducing rework and ensuring consistency. Machine validation is faster and more reliable than human review for format compliance. Integration with pre-commit hooks prevents invalid requirements from entering git history, maintaining requirement quality over time. Clear error messages enable developers to fix issues quickly.

**Acceptance Criteria**:
- validate_requirements.py implemented in Python 3.8+ with no external dependencies
- Script scans all .md files in spec/ directory recursively
- Validates requirement format matches spec/requirements-format.md specification
- Detects and reports duplicate IDs with file locations
- Validates all "Implements" references exist and are reachable
- Checks ID prefix matches level field (p→PRD, o→Ops, d→Dev)
- Warns about unusual hierarchies (PRD implementing PRD, etc.)
- Outputs summary statistics: total requirements, by level, by status
- Returns exit code 0 only when all requirements valid
- Error messages include file path, line number, and specific issue
- Runnable manually: `python3 tools/requirements/validate_requirements.py`

---

### REQ-d00015: Traceability Matrix Auto-Generation

**Level**: Dev | **Implements**: o00013 | **Status**: Active

The system SHALL implement automated traceability matrix generation via `tools/requirements/generate_traceability.py`, producing markdown and HTML formats showing requirement hierarchies, with pre-commit hook integration to auto-regenerate matrices whenever spec/ files change.

Implementation SHALL include:
- Python script parsing requirements from spec/ directory
- Hierarchical tree structure showing parent-child relationships
- Output formats: markdown (.md), HTML (.html), CSV (.csv)
- HTML format with interactive collapsible tree using JavaScript
- Color-coding by level: PRD (blue), OPS (orange), DEV (green)
- Status badges showing Active/Draft/Deprecated
- Summary statistics: total requirements, counts by level and status
- Orphaned requirement detection (no children implementing them)
- Pre-commit hook auto-regeneration when spec/*.md files change
- Auto-staging of generated matrices for commit

**Rationale**: Traceability matrices provide visual representation of requirement relationships essential for regulatory audits and impact analysis. Auto-generation ensures matrices never become outdated or inconsistent with requirements. HTML format with interactive features enables easy browsing of complex requirement hierarchies. Pre-commit hook integration eliminates manual regeneration step, preventing outdated matrices from being committed.

**Acceptance Criteria**:
- generate_traceability.py implemented in Python 3.8+
- Supports --format argument: markdown, html, csv, both (md+html)
- Markdown output shows hierarchical tree with indentation
- HTML output includes collapsible tree with expand/collapse functionality
- HTML uses color coding: PRD blue, OPS orange, DEV green
- HTML includes "Expand All" and "Collapse All" buttons
- CSV output suitable for import into spreadsheets
- Script detects orphaned requirements (no implementing children)
- Pre-commit hook detects spec/*.md file changes
- Hook runs both markdown and HTML generation automatically
- Hook stages generated traceability_matrix.md and traceability_matrix.html
- Generated files include timestamp and requirement count
- Output filename: traceability_matrix.{md,html,csv}
- Runnable manually: `python3 tools/requirements/generate_traceability.py --format both`

---

### REQ-d00016: Code-to-Requirement Linking

**Level**: Dev | **Implements**: o00014 | **Status**: Active

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

---

### REQ-d00017: ADR Template and Lifecycle Tooling

**Level**: Dev | **Implements**: o00016 | **Status**: Active

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

---

### REQ-d00018: Git Hook Implementation

**Level**: Dev | **Implements**: o00017 | **Status**: Active

The system SHALL implement pre-commit hook in `.githooks/pre-commit` that enforces requirement validation, auto-regenerates traceability matrices when spec/ files change, and blocks commits with validation errors, with configuration instructions in `.githooks/README.md`.

Implementation SHALL include:
- Bash script in .githooks/pre-commit executable by git
- Detection of spec/*.md files in staged changes
- Auto-regeneration of traceability matrices when spec/ files changed
- Execution of validate_requirements.py before commit
- Exit code 1 (block commit) on validation failure
- Clear error messages directing developer to fix issues
- Auto-staging of regenerated traceability matrices
- Configuration command: `git config core.hooksPath .githooks`
- Documentation in .githooks/README.md with troubleshooting
- Bypass mechanism documented: `git commit --no-verify` (discouraged)

**Rationale**: Pre-commit hooks enforce quality gates before code enters git history, preventing invalid requirements from being committed and requiring rework later. Auto-regeneration of traceability matrices ensures they're always current with requirements. Automatic staging of matrices simplifies developer workflow. Hook configuration per repository enables consistent enforcement across team. Clear error messages help developers fix issues quickly.

**Acceptance Criteria**:
- .githooks/pre-commit executable bash script (chmod +x)
- Hook detects spec/*.md in staged changes using `git diff --cached`
- When spec/ files changed, runs generate_traceability.py --format both
- Stages traceability_matrix.md and traceability_matrix.html automatically
- Runs validate_requirements.py before accepting commit
- Returns exit code 1 to block commit if validation fails
- Outputs clear error messages with file/line references
- Documents configuration in .githooks/README.md
- Includes troubleshooting section for common issues
- Documents bypass method: --no-verify (with warnings)
- Configuration required once per developer: git config core.hooksPath .githooks
- Hook works correctly on Linux, macOS, Windows Git Bash
- CLAUDE.md documents hook setup requirement

---

## Tool Usage Examples

### Manual Requirement Validation

```bash
# Validate all requirements in spec/ directory
python3 tools/requirements/validate_requirements.py

# Example output on success:
# 🔍 Scanning /path/to/spec for requirements...
# 📋 Found 42 requirements
# ✅ ALL REQUIREMENTS VALID
# 📊 SUMMARY:
#   Total requirements: 42
#   By level: PRD=20, Ops=12, Dev=10
#   By status: Active=42, Draft=0, Deprecated=0

# Example output on error:
# ❌ ERROR: Duplicate requirement ID
#   REQ-p00020 found in:
#     - spec/prd-requirements.md:45
#     - spec/prd-app.md:123
```

### Manual Traceability Matrix Generation

```bash
# Generate markdown format (for documentation)
python3 tools/requirements/generate_traceability.py --format markdown

# Generate HTML format (for interactive browsing)
python3 tools/requirements/generate_traceability.py --format html

# Generate both markdown and HTML (recommended)
python3 tools/requirements/generate_traceability.py --format both

# Generate CSV (for spreadsheet import)
python3 tools/requirements/generate_traceability.py --format csv

# Output to custom location
python3 tools/requirements/generate_traceability.py --format html --output docs/trace.html
```

### Pre-commit Hook Setup

```bash
# One-time setup per developer
git config core.hooksPath .githooks

# Verify configuration
git config --get core.hooksPath
# Should output: .githooks

# Test hook manually
.githooks/pre-commit

# Hook runs automatically on git commit
git commit -m "Add new requirement"
# Pre-commit hook will:
# 1. Detect spec/*.md files changed
# 2. Regenerate traceability matrices
# 3. Validate all requirements
# 4. Stage updated matrices
# 5. Allow commit if valid, block if invalid
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
