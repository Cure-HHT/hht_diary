# ANSPAR Requirement Validation - Requirement Format Validation Plugin

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-31
**Status**: Active

> **See**: README.md for spec/ directory governance rules
> **See**: ../plugins/anspar-requirement-validation/ for implementation
> **Implements**: Main project REQ-d00014 (Requirement Validation Tooling)

---

## Executive Summary

ANSPAR Requirement Validation validates requirement format, uniqueness, and links before commits, ensuring requirement quality through automated checks integrated with git hooks and CI/CD pipelines.

---

### REQ-d00150: Requirement Format Validation

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL validate requirement ID format matching pattern REQ-{type}{number} where type is p/o/d and number is 5 digits, ensuring consistent requirement identification across all spec/ files.

Format validation SHALL include:
- ID pattern: `REQ-[pod][0-9]{5}`
- Valid types: p (PRD), o (Ops), d (Dev)
- Number range: 00001-99999
- Header format: `### REQ-{id}: Title`
- Error reporting with file path and line number
- Integration with shared validation script

**Rationale**: Consistent format enables automated tooling. Pattern validation catches typos early. Clear error messages guide correction.

**Acceptance Criteria**:
- Validates all spec/*.md files
- Detects REQ-{type}{number} pattern
- Reports invalid formats with file:line
- Validates type is p, o, or d
- Validates number is 5 digits
- Uses shared tools/requirements/validate_requirements.py

---

### REQ-d00151: Requirement Uniqueness Checking

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL detect duplicate requirement IDs across all spec/ files, preventing ID conflicts and ensuring each requirement has unique identifier.

Uniqueness checking SHALL include:
- Scan all spec/*.md files for REQ IDs
- Build requirement ID registry
- Detect duplicate IDs across files
- Report all files containing duplicate
- Exit with error code 1 on duplicates
- Clear error showing conflicting file locations

**Rationale**: Unique IDs essential for requirement traceability. Duplicate detection prevents confusion. File locations enable quick resolution.

**Acceptance Criteria**:
- Scans all spec/*.md recursively
- Builds map of REQ ID → file locations
- Detects when ID appears in multiple files
- Reports: REQ ID, file1:line, file2:line
- Exits 1 on duplicates (blocks commit)
- Exits 0 when all IDs unique

---

### REQ-d00152: Parent Link Validation

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL validate all "Implements" references point to existing parent requirements with helpful error messages suggesting corrections, ensuring requirement hierarchy integrity and preventing broken references.

Link validation SHALL include:
- Parse "Implements" field from requirements
- Verify referenced REQ IDs exist in spec/ files
- Detect circular references (A implements B, B implements A)
- Warn about unusual hierarchies (PRD implements PRD)
- Report missing parent requirements
- Missing parent warnings include: "Did you mean REQ-o00017?" suggestions
- Typo detection: If REQ-o00017 exists, suggest instead of REQ-o00018 missing
- Build complete requirement dependency graph

**Rationale**: Valid links maintain requirement traceability. Broken references prevent impact analysis. Circular detection prevents infinite loops. Helpful error messages with suggestions reduce spec fixing time for small teams.

**Acceptance Criteria**:
- Parses "Implements" field from requirement metadata
- Verifies each referenced REQ ID exists
- Detects circular implement chains
- Warns when PRD implements PRD (unusual)
- Reports missing parent with: child REQ, missing parent REQ
- Missing parent errors include "Did you mean...?" suggestions for similar IDs
- Typo detection compares missing ID to existing IDs (edit distance < 3)
- Builds dependency graph for analysis

---

### REQ-d00153: Level Consistency Validation

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL validate requirement ID prefix matches stated Level field (p→PRD, o→Ops, d→Dev), ensuring consistency between ID and metadata.

Consistency validation SHALL include:
- Extract Level field value
- Extract type from REQ-{type}{number} ID
- Validate mapping: p→PRD, o→Ops, d→Dev
- Report mismatches with file:line
- Case-insensitive Level matching
- Clear error explaining expected consistency

**Rationale**: Consistency prevents confusion. Automated validation catches human error. Clear errors guide correction.

**Acceptance Criteria**:
- Extracts "Level" field from requirement
- Extracts type prefix from REQ ID
- Validates p↔PRD, o↔Ops, d↔Dev mapping
- Reports mismatches: "REQ-p00042 has Level: Ops"
- Case-insensitive (PRD, prd, Prd all valid)
- Error shows expected level for given ID prefix

---

### REQ-d00154: Thin Wrapper Architecture

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL implement thin wrapper pattern referencing shared validation script at tools/requirements/validate_requirements.py, enabling both git hooks and CI/CD to use identical validation logic.

Wrapper architecture SHALL include:
- Git hook: hooks/pre-commit-requirement-validation
- Shared script: tools/requirements/validate_requirements.py
- Hook executes shared script with appropriate arguments
- CI/CD executes shared script directly
- Single source of truth for validation logic
- Hook provides git-specific context only

**Rationale**: Single source prevents logic divergence. Shared script enables CI/CD reuse. Thin wrapper minimizes plugin maintenance.

**Acceptance Criteria**:
- Hook script under 50 lines (thin wrapper)
- Hook calls: python3 tools/requirements/validate_requirements.py
- Shared script path relative to repo root
- Hook passes staged files to script (if applicable)
- CI/CD can call shared script directly
- Updates to validation logic require changing only shared script

---

### REQ-d00155: Git Hook Integration

**Level**: Dev | **Implements**: d00100 | **Status**: Required | **Maintenance**: Set-and-Forget

The plugin SHALL integrate with git pre-commit hook blocking commits containing invalid requirements, with Claude Code PostToolUse hook providing real-time validation feedback.

Hook integration SHALL include:
- Pre-commit hook in hooks/ directory
- PostToolUse hook configuration in hooks.json
- Pre-commit blocks on validation failure (exit 1)
- PostToolUse triggers on Write|Edit of spec/ files
- Clear error messages with file:line references
- Installation instructions in README.md

**Rationale**: Pre-commit enforcement prevents invalid requirements in git history. PostToolUse provides real-time feedback during editing.

**Acceptance Criteria**:
- pre-commit-requirement-validation executable
- Hook detects spec/*.md in staged changes
- Executes validation script
- Exits 1 to block commit on errors
- PostToolUse hook in hooks.json
- PostToolUse non-blocking (warnings only)
- README documents hook installation

---

### REQ-d00156: Requirement Coverage Reporting

**Level**: Dev | **Implements**: d00100 | **Status**: Recommended | **Maintenance**: Set-and-Forget

The plugin SHOULD generate coverage report showing requirement distribution, implementation status, and hierarchy completeness, providing small teams with visibility into spec completeness.

Coverage report SHALL show:
- Total requirements by level (PRD/Ops/Dev)
- Requirements with implementations vs specification-only
- Requirements without children (leaf requirements)
- Requirements without parents (top-level requirements)
- Report format: Simple text summary, optionally JSON for tooling

**Rationale**: Small team benefits from visibility into requirement coverage. Quick report helps identify gaps. Simple text format enables human review. Optional JSON enables tooling integration.

**Acceptance Criteria**:
- Report generated via --coverage flag
- Shows counts: total, implemented, orphaned
- Warns if > 30% requirements have no implementations
- Text format: human-readable summary
- JSON format: machine-parseable (optional)
- Coverage includes: PRD, Ops, Dev level breakdowns

---

## References

- **Implementation**: ../plugins/anspar-requirement-validation/
- **Shared Script**: ../../tools/requirements/validate_requirements.py
- **Main Project Requirement**: ../../spec/dev-requirements-management.md (REQ-d00014)
- **Marketplace Spec**: dev-marketplace.md

---

**Document Classification**: Internal Use - Development Standards
**Review Frequency**: Quarterly
**Owner**: Requirement Validation Plugin Maintainers
