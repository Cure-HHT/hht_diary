# ANSPAR Spec Compliance - Spec Directory Enforcement Plugin

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-31
**Status**: Active

> **See**: README.md for spec/ directory governance rules
> **See**: ../plugins/anspar-spec-compliance/ for implementation
> **Implements**: Main project REQ-o00015 (Documentation Structure Enforcement)

---

## Executive Summary

ANSPAR Spec Compliance enforces spec/ directory compliance through automated validation and AI-powered analysis, ensuring file naming conventions, audience scope rules, and requirement format standards are maintained.

---

### REQ-d00140: File Naming Convention Enforcement

**Level**: Dev | **Implements**: d00100 | **Status**: Active

The plugin SHALL validate spec/ files follow hierarchical naming pattern {audience}-{topic}(-{subtopic}).md with valid audience prefixes (prd-, ops-, dev-), rejecting files violating the naming convention.

Validation SHALL include:
- Pattern matching: `[audience]-[topic](-[subtopic]).md`
- Valid audiences: prd, ops, dev
- Kebab-case enforcement for topic and subtopic
- Clear error messages showing expected format
- Exemptions for: README.md, requirements-format.md
- Integration with pre-commit hook

**Rationale**: Consistent naming enables predictable file discovery. Hierarchical structure communicates content scope. Audience prefixes clarify intended reader.

**Acceptance Criteria**:
- validate-spec-compliance.sh checks all spec/*.md files
- Detects invalid audience prefixes
- Validates pattern: audience-topic or audience-topic-subtopic
- Exempts documented special files
- Error shows filename and expected format
- Pre-commit hook blocks commits with invalid names

---

### REQ-d00141: Audience Scope Rule Enforcement

**Level**: Dev | **Implements**: d00100 | **Status**: Active

The plugin SHALL enforce audience scope rules preventing code examples in PRD files, ensuring product requirements remain technology-agnostic and suitable for business review.

Scope enforcement SHALL include:
- PRD file code detection: no code blocks, no SQL keywords, no function calls
- Code block detection: ````language markers (sql, bash, javascript, etc.)
- Inline code detection: SQL keywords (SELECT, INSERT, CREATE TABLE)
- Function call detection: someFunction(), obj.method()
- Clear violations reported with line numbers
- Ops/dev files exempted from code restrictions

**Rationale**: PRD files reviewed by non-technical stakeholders. Code examples obscure business requirements. Technology-agnostic PRDs enable multiple implementation approaches.

**Acceptance Criteria**:
- Scans prd-*.md files only
- Detects code blocks with language tags
- Detects SQL keywords in prose
- Detects function call patterns
- Reports line numbers for violations
- Ops and dev files allow code freely

---

### REQ-d00142: Requirement Format Validation

**Level**: Dev | **Implements**: d00100 | **Status**: Active

The plugin SHALL validate requirement block format ensuring proper headers, unique IDs, valid metadata fields, and consistent structure across all spec/ files.

Format validation SHALL include:
- Header pattern: `### REQ-{type}{number}: Title`
- Valid types: p (PRD), o (Ops), d (Dev)
- Number format: 5 digits (00001-99999)
- Required fields: Level, Status, optionally Implements
- Valid status values: Active, Draft, Deprecated
- ID uniqueness checking deferred to anspar-requirement-validation

**Rationale**: Consistent format enables automated processing. Unique IDs prevent conflicts. Metadata fields support requirement management.

**Acceptance Criteria**:
- Validates requirement header format
- Checks ID pattern: REQ-{p|o|d}[0-9]{5}
- Verifies required fields present
- Validates status values
- Reports format violations with line numbers
- Does not duplicate anspar-requirement-validation logic

---

### REQ-d00143: AI-Powered Compliance Analysis

**Level**: Dev | **Implements**: d00100 | **Status**: Active

The plugin SHALL provide AI agent for spec compliance analysis offering context-aware recommendations, detecting subtle scope violations, and suggesting improvements beyond automated validation rules.

AI agent SHALL provide:
- Context-aware scope analysis
- Subtle violation detection (technical jargon in PRD files)
- Cross-reference validation suggestions
- Structural improvement recommendations
- Integration with Claude Code via agent.md
- Manual invocation for detailed analysis

**Rationale**: AI analysis detects nuanced issues beyond regex patterns. Context awareness enables intelligent recommendations. Manual invocation provides detailed review option.

**Acceptance Criteria**:
- agent.md defines spec-compliance-enforcer agent
- Agent analyzes audience scope violations
- Detects technical jargon in PRD files
- Suggests cross-reference improvements
- Agent invocable via Claude Code
- Agent output includes: issues, severity, recommendations

---

### REQ-d00144: PostToolUse Hook Integration

**Level**: Dev | **Implements**: d00100 | **Status**: Active

The plugin SHALL integrate with Claude Code PostToolUse hook triggering validation after Write or Edit operations on spec/ files, providing real-time feedback during documentation editing.

Hook integration SHALL include:
- hooks.json configuration for PostToolUse event
- Trigger on Write|Edit operations
- Filter for spec/ directory files only
- Run validate-spec-compliance.sh on affected files
- Display validation results in Claude Code
- Non-blocking execution (warnings, not errors)

**Rationale**: Real-time validation catches issues during editing. PostToolUse hook provides immediate feedback. Non-blocking allows work-in-progress saves.

**Acceptance Criteria**:
- hooks.json defines PostToolUse hook
- Matcher: "Write|Edit"
- Hook filters for spec/*.md files
- Executes validation script
- Results displayed in Claude Code output
- Hook does not block Write/Edit operations
- Clear feedback format

---

### REQ-d00145: Git Pre-Commit Hook Integration

**Level**: Dev | **Implements**: d00100 | **Status**: Active

The plugin SHALL provide pre-commit hook enforcing spec compliance before commits, blocking commits with spec violations and ensuring repository maintains documentation standards.

Pre-commit integration SHALL include:
- pre-commit-spec-compliance executable hook
- Detection of staged spec/*.md files
- Validation execution only on spec file changes
- Commit blocking on validation failures (exit 1)
- Clear error messages with fix instructions
- Integration instructions in README.md

**Rationale**: Pre-commit enforcement prevents invalid specs from entering git history. Early validation reduces rework. Clear errors guide compliance.

**Acceptance Criteria**:
- Hook detects staged spec/*.md files
- Runs validation on staged files only
- Exits 1 to block commit on violations
- Exits 0 to allow commit when valid
- Error messages show: file, line, issue, fix
- README documents installation in .githooks/

---

## References

- **Implementation**: ../plugins/anspar-spec-compliance/
- **Main Project Requirement**: ../../spec/ops-requirements-management.md (REQ-o00015)
- **Marketplace Spec**: dev-marketplace.md

---

**Document Classification**: Internal Use - Development Standards
**Review Frequency**: Quarterly
**Owner**: Spec Compliance Plugin Maintainers
