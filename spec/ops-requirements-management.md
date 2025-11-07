# Requirements Management Operations

**Version**: 1.0
**Audience**: Operations
**Last Updated**: 2025-10-25
**Status**: Active

> **See**: prd-requirements-management.md for business/regulatory requirements
> **See**: dev-requirements-management.md for tooling implementation
> **See**: spec/requirements-format.md for detailed format specification

---

## Executive Summary

This document defines operational procedures for maintaining formal requirements, enforcing documentation standards, and managing architecture decisions. These procedures ensure regulatory compliance, quality assurance, and institutional knowledge preservation.

---

# REQ-o00013: Requirements Format Validation

**Level**: Ops | **Implements**: p00036 | **Status**: Active

Requirements SHALL follow the standardized format defined in spec/requirements-format.md, with automatic validation occurring before commits via pre-commit hooks, and traceability matrices auto-generated whenever spec/ files change.

Format validation SHALL ensure:
- All requirements have unique IDs following pattern `[pod]NNNNN`
- All requirements include required fields: Level, Implements, Status
- All "Implements" references point to existing requirements
- Level prefix matches stated level (p=PRD, o=Ops, d=Dev)
- Requirements use prescriptive language (SHALL/MUST for mandatory)
- Traceability matrices regenerated automatically on spec/ changes
- Matrices include both markdown and HTML formats

**Rationale**: Standardized format enables automated validation and traceability matrix generation. Consistent structure ensures requirements are machine-readable for tooling and human-readable for auditors. Automatic validation prevents invalid requirements from entering the codebase. Auto-generation of traceability matrices ensures they never become outdated or inconsistent with requirements.

**Acceptance Criteria**:
- Pre-commit hook validates all requirements before accepting commit
- Hook rejects commits with format errors, duplicate IDs, or broken links
- Hook auto-regenerates traceability_matrix.md and traceability_matrix.html
- Generated matrices automatically staged for commit
- Validation provides clear error messages with file and line numbers
- Manual validation available: `python3 tools/requirements/validate_requirements.py`
- Matrices viewable in markdown (documentation) and HTML (interactive browsing)

*End* *Requirements Format Validation* | **Hash**: 2743e711
---

# REQ-o00014: Top-Down Requirement Cascade

**Level**: Ops | **Implements**: p00036 | **Status**: Active

Requirements SHALL be created following top-down cascade from PRD to OPS to DEV levels, never deriving product requirements from existing code, ensuring business needs drive implementation rather than vice versa.

Top-down cascade SHALL ensure:
- New features start with PRD requirement defining business need
- OPS requirements added defining deployment/operational procedures
- DEV requirements added defining implementation approach
- Requirements use prescriptive language (SHALL/MUST), not descriptive
- Code implementation follows requirements, not vice versa
- Post-hoc requirements for existing code still written top-down
- Requirements written as if code doesn't exist yet

**Rationale**: Top-down cascade ensures requirements drive implementation, maintains PRD independence from technical details, prevents post-hoc rationalization of code decisions, keeps business justification clear for all features, and enables proper requirement traceability for regulatory audits. Starting at PRD level forces explicit business justification before technical work begins.

**Acceptance Criteria**:
- PRD requirements contain no code examples or technical implementation details
- OPS requirements reference PRD parents in "Implements" field
- DEV requirements reference OPS/PRD parents in "Implements" field
- Requirements for existing code written prescriptively (what should exist)
- Validation tooling warns about unusual hierarchies (e.g., PRD implements PRD)
- New features begin with ticket → PRD requirement → OPS → DEV → code flow
- Code header comments reference requirements, not vice versa

*End* *Top-Down Requirement Cascade* | **Hash**: d36fc1fb
---

# REQ-o00015: Documentation Structure Enforcement

**Level**: Ops | **Implements**: p00036 | **Status**: Active

Documentation SHALL be organized with spec/ containing formal requirements (WHAT/WHY/HOW to build/deploy) and docs/ containing decisions, ADRs, and explanatory documentation, with files using hierarchical naming `{audience}-{topic}(-{subtopic}).md`.

Documentation structure SHALL ensure:
- spec/ contains requirements documents (prd-, ops-, dev- prefixes)
- docs/ contains Architecture Decision Records and implementation guides
- Files follow naming pattern: `{audience}-{topic}(-{subtopic}).md`
- Audience prefixes: prd- (product), ops- (operations), dev- (development)
- Audience scope enforced: prd- no code, ops- commands/configs, dev- code examples
- Cross-references used instead of duplicate content
- Each topic has narrow, focused scope per spec/README.md

**Rationale**: Clear separation between requirements (spec/) and decisions (docs/) ensures regulatory documents (requirements) are distinct from explanatory documents (ADRs). Hierarchical naming enables quick navigation and understanding of content scope. Audience scope rules ensure PRD requirements remain technology-agnostic and suitable for business/regulatory review. Structured organization supports long-term maintenance across team changes.

**Acceptance Criteria**:
- Requirements only in spec/ directory, never in docs/
- ADRs and decision rationale only in docs/, never in spec/
- All spec/ files follow `{audience}-{topic}(-{subtopic}).md` pattern
- prd- files contain no code examples or CLI commands
- ops- files contain deployment/monitoring procedures and configurations
- dev- files contain code examples and implementation details
- spec/README.md documents topic scopes to prevent content duplication
- Files cross-reference each other instead of duplicating content

*End* *Documentation Structure Enforcement* | **Hash**: 426b1961
---

# REQ-o00016: Architecture Decision Process

**Level**: Ops | **Implements**: p00037 | **Status**: Active

Significant architectural and design decisions SHALL trigger Architecture Decision Record (ADR) creation, with ADRs following defined lifecycle from Proposed through Accepted to Deprecated/Superseded, and linking to implementing requirements and originating tickets.

ADR process SHALL ensure:
- ADRs created for decisions with long-term impact or trade-offs
- ADRs document context, decision, consequences, and alternatives
- ADRs follow lifecycle: Proposed → Accepted → Deprecated/Superseded
- ADRs link to tickets that triggered the decision
- ADRs link to requirements that implement the decision
- ADRs indexed in docs/adr/README.md
- ADRs committed with implementing code when applicable

**Rationale**: Clinical trial systems have 25+ year operational lifetimes. Architectural decisions made today will be maintained by different teams over decades. Formal ADR process ensures decisions are reviewable and reversible, future maintainers understand system design rationale, regulatory audits have technical context available, and the same mistakes aren't repeated due to forgotten alternatives.

**Acceptance Criteria**:
- ADRs created for: architectural patterns, technology choices, security models, compliance approaches
- ADR template followed: Status, Context, Decision, Consequences, Alternatives
- ADRs reference originating ticket number in Context section
- ADRs reference implementing requirements when applicable
- ADR status clearly marked: Proposed, Accepted, Deprecated, Superseded
- docs/adr/README.md index maintained with all ADRs
- Superseded ADRs reference replacement ADR number
- ADRs not created for: routine implementation choices, trivial decisions, easily reversible choices

*End* *Architecture Decision Process* | **Hash**: 5efd9802
---

# REQ-o00017: Version Control Workflow

**Level**: Ops | **Implements**: p00036, p00037 | **Status**: Active

Development SHALL use feature branches created before changes, with commits referencing tickets, requirements, and ADRs, and pre-commit hooks enforcing validation before accepting commits.

Version control workflow SHALL ensure:
- Feature branches created before file changes: `git checkout -b feature/descriptive-name`
- Commits reference ticket numbers: `[TICKET-XXX] Brief description`
- Commits reference implemented requirements: `Implements: REQ-p00xxx, REQ-o00yyy, REQ-d00zzz`
- Commits reference relevant ADRs: `ADR: ADR-NNN-title`
- Pre-commit hooks run validation automatically
- Pre-commit hooks block invalid commits (exit code 1)
- Hook setup required once per developer: `git config core.hooksPath .githooks`

**Rationale**: Feature branches isolate changes and enable parallel development. Requirement references in commits provide traceability from code to requirements for audits. Pre-commit hooks prevent invalid requirements from entering the codebase, reducing rework and ensuring quality. Ticket references enable tracking work history and understanding change context. Consistent commit format enables automated tooling and audit reporting.

**Acceptance Criteria**:
- Feature branches used for all non-trivial changes
- Commit messages include ticket reference when applicable
- Commit messages list implemented requirements in format: `Implements: REQ-xxx, REQ-yyy`
- Commit messages reference ADRs when implementing architectural decisions
- .githooks/pre-commit validates requirements before accepting commit
- Pre-commit hook auto-regenerates traceability matrices when spec/ changes
- Hook configuration documented in .githooks/README.md
- Developers run `git config core.hooksPath .githooks` during onboarding

*End* *Version Control Workflow* | **Hash**: c8076d8e
---

## Workflow Examples

### Adding New Feature with Requirements

```bash
# 1. Create feature branch
git checkout -b feature/multi-language-support

# 2. Create PRD requirement in spec/prd-app.md
# Example: REQ-p00022: Multi-Language Support

# 3. Create OPS requirement in spec/ops-deployment.md
# Example: REQ-o00018: Language Configuration Management

# 4. Create DEV requirement in spec/dev-app.md
# Example: REQ-d00019: i18n Implementation

# 5. Validate requirements
python3 tools/requirements/validate_requirements.py

# 6. Implement code with requirement references in headers
# // IMPLEMENTS REQUIREMENTS: REQ-p00022, REQ-d00019

# 7. Commit (pre-commit hook validates automatically)
git commit -m "[TICKET-123] Add multi-language support

Implements support for English, Spanish, French languages.

Implements: REQ-p00022, REQ-o00018, REQ-d00019

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Pre-commit hook will:
# - Regenerate traceability matrices
# - Validate all requirements
# - Auto-stage updated matrices
# - Allow commit if validation passes
```

### Creating ADR with Requirements

```bash
# 1. Ticket #124 requires choosing database for audit trail
# 2. Draft ADR-006 with "Proposed" status
# 3. Team reviews and approves
# 4. Update ADR-006 status to "Accepted"
# 5. Create requirements implementing the decision
# 6. Implement code
# 7. Commit ADR and code together

git commit -m "[TICKET-124] Implement PostgreSQL audit trail per ADR-006

Chosen PostgreSQL over MongoDB for audit trail storage.

Implements: REQ-p00023, REQ-o00019, REQ-d00020
ADR: ADR-006-postgresql-audit-trail

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## References

- **Product Requirements**: prd-requirements-management.md
- **Development Implementation**: dev-requirements-management.md
- **Format Specification**: requirements-format.md
- **ADR Process**: docs/adr/README.md
- **Pre-commit Hook**: .githooks/README.md

---

**Document Classification**: Internal Use - Operations Procedures
**Review Frequency**: Quarterly or when process changes
**Owner**: Development Lead / Quality Assurance
