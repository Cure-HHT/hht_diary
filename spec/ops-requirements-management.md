# Requirements Management Operations

**Version**: 1.0
**Audience**: Operations
**Last Updated**: 2025-10-25
**Status**: Draft

> **See**: prd-requirements-management.md for business/regulatory requirements
> **See**: dev-requirements-management.md for tooling implementation
> **See**: spec/requirements-format.md for detailed format specification

---

## Executive Summary

This document defines operational procedures for maintaining formal requirements, enforcing documentation standards, and managing architecture decisions. These procedures ensure regulatory compliance, quality assurance, and institutional knowledge preservation.

---

# REQ-o00013: Requirements Format Validation

**Level**: Ops | **Status**: Draft | **Implements**: p00020

## Rationale

Standardized requirement formats enable automated validation and traceability matrix generation, which are essential for FDA 21 CFR Part 11 compliance and regulatory audits. A consistent structure ensures requirements remain machine-readable for tooling while being human-readable for auditors. Automatic validation integrated into the development workflow prevents malformed or invalid requirements from entering the codebase. Auto-generation of traceability matrices ensures they remain synchronized with requirements and never become outdated or inconsistent, supporting end-to-end requirement traceability from product requirements through operational and development specifications.

## Assertions

A. Requirements SHALL follow the standardized format defined in spec/requirements-format.md.
B. The system SHALL perform automatic format validation before commits via pre-commit hooks.
C. The system SHALL auto-generate traceability matrices whenever spec/ files change.
D. The system SHALL ensure all requirements have unique IDs following pattern [pod]NNNNN.
E. The system SHALL ensure all requirements include the required fields: Level, Implements, and Status.
F. The system SHALL validate that all 'Implements' references point to existing requirements.
G. The system SHALL validate that the Level prefix matches the stated level (p=PRD, o=Ops, d=Dev).
H. The system SHALL validate that requirements use prescriptive language (SHALL/MUST for mandatory obligations).
I. The system SHALL regenerate traceability matrices automatically on spec/ changes.
J. The system SHALL generate matrices in both markdown and HTML formats.
K. The pre-commit hook SHALL reject commits with format errors, duplicate IDs, or broken links.
L. The system SHALL automatically stage generated matrices for commit.
M. The system SHALL provide clear error messages with file and line numbers when validation fails.
N. The system SHALL provide manual validation via the command: python3 tools/requirements/validate_requirements.py.
O. Generated matrices SHALL be viewable in markdown format for documentation purposes.
P. Generated matrices SHALL be viewable in HTML format for interactive browsing.

*End* *Requirements Format Validation* | **Hash**: 73eb4415
---

# REQ-o00014: Top-Down Requirement Cascade

**Level**: Ops | **Status**: Draft | **Implements**: p00020

## Rationale

Top-down requirement cascade ensures that business needs drive implementation decisions rather than technical considerations dictating product direction. This methodology maintains clear separation between product vision (PRD), operational procedures (OPS), and technical implementation (DEV), preventing post-hoc rationalization of existing code. By forcing explicit business justification at the PRD level before any technical work begins, this approach ensures proper requirement traceability for regulatory audits and keeps stakeholder concerns properly separated. Even when documenting existing functionality, requirements are written prescriptively to describe what should exist rather than descriptively documenting what does exist, maintaining consistency in requirement specification and enabling validation against actual implementation.

## Assertions

A. Requirements SHALL be created following top-down cascade from PRD to OPS to DEV levels.
B. The system SHALL NOT derive product requirements from existing code.
C. New features SHALL start with a PRD requirement defining the business need.
D. OPS requirements SHALL be added after PRD requirements to define deployment and operational procedures.
E. DEV requirements SHALL be added after OPS requirements to define implementation approach.
F. Requirements SHALL use prescriptive language (SHALL/MUST), not descriptive language.
G. Code implementation SHALL follow requirements.
H. Post-hoc requirements for existing code SHALL be written top-down.
I. Post-hoc requirements SHALL be written prescriptively as if code does not exist yet.
J. PRD requirements SHALL NOT contain code examples.
K. PRD requirements SHALL NOT contain technical implementation details.
L. OPS requirements SHALL reference PRD parents in the 'Implements' field.
M. DEV requirements SHALL reference OPS or PRD parents in the 'Implements' field.
N. Validation tooling SHALL warn about unusual requirement hierarchies.
O. Validation tooling SHALL warn when PRD requirements implement other PRD requirements.
P. New features SHALL follow the sequence: ticket → PRD requirement → OPS requirement → DEV requirement → code.
Q. Code header comments SHALL reference requirements.

*End* *Top-Down Requirement Cascade* | **Hash**: 68a8deeb
---

# REQ-o00015: Documentation Structure Enforcement

**Level**: Ops | **Status**: Draft | **Implements**: p00020

## Rationale

Clear separation between requirements (spec/) and decisions (docs/) ensures regulatory documents (requirements) are distinct from explanatory documents (ADRs). Hierarchical naming enables quick navigation and understanding of content scope. Audience scope rules ensure PRD requirements remain technology-agnostic and suitable for business/regulatory review. Structured organization supports long-term maintenance across team changes and facilitates compliance auditing by maintaining a clear distinction between what is required versus how it was decided.

## Assertions

A. The system SHALL organize documentation with spec/ containing formal requirements and docs/ containing decisions, ADRs, and explanatory documentation.
B. Requirements documents SHALL be located only in the spec/ directory.
C. Requirements documents SHALL NOT be located in the docs/ directory.
D. Architecture Decision Records SHALL be located only in the docs/ directory.
E. Decision rationale SHALL be located only in the docs/ directory.
F. Architecture Decision Records SHALL NOT be located in the spec/ directory.
G. All files in spec/ SHALL follow the naming pattern {audience}-{topic}(-{subtopic}).md.
H. Product requirements files SHALL use the prd- prefix.
I. Operations requirements files SHALL use the ops- prefix.
J. Development requirements files SHALL use the dev- prefix.
K. Files with the prd- prefix SHALL NOT contain code examples.
L. Files with the prd- prefix SHALL NOT contain CLI commands.
M. Files with the ops- prefix SHALL contain deployment procedures, monitoring procedures, or configuration details.
N. Files with the dev- prefix SHALL contain code examples or implementation details.
O. The spec/README.md file SHALL document topic scopes to prevent content duplication.
P. Documentation files SHALL use cross-references to related content instead of duplicating content.
Q. Each topic in spec/ SHALL have a narrow, focused scope as defined in spec/README.md.

*End* *Documentation Structure Enforcement* | **Hash**: bafe78ff
---

# REQ-o00016: Architecture Decision Process

**Level**: Ops | **Status**: Draft | **Implements**: p00021

## Rationale

Clinical trial systems have 25+ year operational lifetimes, and architectural decisions made today will be maintained by different teams over decades. The formal ADR process ensures that decisions are reviewable and reversible, that future maintainers understand system design rationale, that regulatory audits have technical context available, and that the same mistakes are not repeated due to forgotten alternatives. ADRs provide institutional memory for significant technical choices involving long-term impact or trade-offs, while avoiding documentation overhead for routine or easily reversible implementation decisions.

## Assertions

A. The system SHALL trigger Architecture Decision Record (ADR) creation for significant architectural and design decisions.
B. ADRs SHALL be created for decisions involving architectural patterns.
C. ADRs SHALL be created for decisions involving technology choices.
D. ADRs SHALL be created for decisions involving security models.
E. ADRs SHALL be created for decisions involving compliance approaches.
F. ADRs SHALL document the context of the decision.
G. ADRs SHALL document the decision itself.
H. ADRs SHALL document the consequences of the decision.
I. ADRs SHALL document alternatives that were considered.
J. ADRs SHALL follow a lifecycle from Proposed to Accepted to Deprecated or Superseded.
K. ADRs SHALL include a clearly marked status of Proposed, Accepted, Deprecated, or Superseded.
L. ADRs SHALL reference the originating ticket number in the Context section.
M. ADRs SHALL reference implementing requirements when applicable.
N. ADRs SHALL be indexed in docs/adr/README.md.
O. The docs/adr/README.md index SHALL be maintained to include all ADRs.
P. Superseded ADRs SHALL reference the replacement ADR number.
Q. ADRs SHALL be committed with implementing code when applicable.
R. ADRs SHALL NOT be created for routine implementation choices.
S. ADRs SHALL NOT be created for trivial decisions.
T. ADRs SHALL NOT be created for easily reversible choices.

*End* *Architecture Decision Process* | **Hash**: d2bf6cb2
---

# REQ-o00017: Version Control Workflow

**Level**: Ops | **Status**: Draft | **Implements**: p00020

## Rationale

Feature branches isolate changes and enable parallel development without affecting the main codebase. Requirement references in commits provide bidirectional traceability from code to requirements, which is essential for FDA 21 CFR Part 11 compliance audits and regulatory submissions. Pre-commit hooks enforce validation rules before changes enter the repository, preventing invalid requirements from entering the codebase and reducing rework. Ticket references enable tracking work history and understanding change context for collaborative development. ADR references connect implementation decisions to architectural rationale. Consistent commit message formatting enables automated tooling for audit reporting, traceability matrix generation, and compliance documentation.

## Assertions

A. Developers SHALL create feature branches before making file changes.
B. Feature branches SHALL use the naming pattern: feature/descriptive-name.
C. Commit messages SHALL include ticket references in the format: [TICKET-XXX] Brief description, when a ticket is applicable.
D. Commit messages SHALL include implemented requirements in the format: Implements: REQ-p00xxx, REQ-o00yyy, REQ-d00zzz.
E. Commit messages SHALL reference relevant ADRs in the format: ADR: ADR-NNN-title when implementing architectural decisions.
F. The system SHALL run pre-commit hooks automatically before accepting commits.
G. Pre-commit hooks SHALL validate requirements before accepting commits.
H. Pre-commit hooks SHALL block invalid commits by returning exit code 1.
I. Pre-commit hooks SHALL automatically regenerate traceability matrices when spec/ directory files change.
J. Developers SHALL configure git hooks by running: git config core.hooksPath .githooks once per developer environment.
K. The repository SHALL document hook configuration in .githooks/README.md.
L. Feature branches SHALL be used for all non-trivial changes.

*End* *Version Control Workflow* | **Hash**: c5c6c55e
---

## Workflow Examples

### Adding New Feature with Requirements

```bash
# 1. Create feature branch
git checkout -b feature/multi-language-support

# 2. Create PRD requirement in spec/prd-diary-app.md
# Example: REQ-p00049: Multi-Language Support

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
