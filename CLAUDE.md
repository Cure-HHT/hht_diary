# Project Structure and SOPs

## Directory Organization

- **README.md**: Project overview and documentation structure
- **spec/**: Formal requirements (WHAT, WHY, HOW to build/deploy)
  - Use hierarchical naming: `{audience}-{topic}(-{subtopic}).md`
  - Audiences: `prd-` (product), `ops-` (operations), `dev-` (development)
  - **ALWAYS read spec/README.md before modifying spec/ files**
- **docs/**: Implementation documentation (HOW decisions were made)
  - `adr/`: Architecture Decision Records (ADRs)
  - Implementation guides, runbooks, design notes
  - **See docs/README.md and docs/adr/README.md for ADR process**
- **database/**: SQL schema, triggers, functions, migrations, tests
- **archive/**: Obsolete files - DO NOT use unless explicitly asked
- **evaluation/**: Mock sponsor evaluation materials

## Key SOPs

### 1. Documentation Placement (spec/ vs docs/)

**Use spec/** for:
- ✅ Formal requirements defining system capabilities
- ✅ Deployment/operation procedures (ops- files)
- ✅ Implementation specifications (dev- files)
- ✅ Compliance and regulatory requirements

**Use docs/** for:
- ✅ Architecture Decision Records (ADRs)
- ✅ Explaining WHY technical choices were made
- ✅ Implementation tutorials and guides
- ✅ Investigation reports

**See**: `docs/README.md` for complete guidelines

### 2. Architecture Decision Records (ADRs)

**When to create an ADR**:
- Significant architectural decisions with trade-offs
- Technology choices affecting multiple components
- Security model decisions
- Compliance approaches

**Workflow**:
1. Ticket created (e.g., #123 "Add feature X")
2. Draft ADR with "Proposed" status, reference ticket
3. Team review and discussion
4. Update to "Accepted" and implement
5. Commit ADR with code, reference ticket in commit message

**See**: `docs/adr/README.md` for complete ADR process and template

### 3. File Naming Conventions

**spec/ files**: `{audience}-{topic}(-{subtopic}).md`
- Examples: `prd-app.md`, `ops-deployment.md`, `dev-security-RBAC.md`

**ADR files**: `ADR-{number}-{descriptive-title}.md`
- Examples: `ADR-001-event-sourcing-pattern.md`

**Audience Scope**:
- `prd-`: No code examples, only WHAT/WHY
- `ops-`: CLI commands, configs, deployment procedures
- `dev-`: Code examples, API docs, implementation patterns

---

# ⚠️ REQUIREMENT TRACEABILITY (MANDATORY) ⚠️

**This project uses formal requirement traceability. ALL code and specs MUST be linked to requirements.**

## CRITICAL: When Creating/Modifying Code Files

**BEFORE** editing ANY implementation file (.sql, .dart, .ts, .py, .js, etc.):

1. ✅ **Identify requirements**: Which requirements does this code implement?
2. ✅ **Add header comments**: Include requirement references at top of file
3. ✅ **Use correct format**: `IMPLEMENTS REQUIREMENTS: REQ-p00xxx, REQ-o00yyy, REQ-d00zzz`

**Example (SQL)**:
```sql
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-p00010: FDA 21 CFR Part 11 Compliance
--   REQ-d00007: Database Schema Implementation
```

**Example (Dart/TypeScript)**:
```dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-p00006: Offline-First Data Entry
//   REQ-d00004: Local-First Data Entry Implementation
```

## CRITICAL: When Creating/Modifying Requirements

**ALL new requirements MUST follow TOP-DOWN cascade** (never bottom-up from code):

1. **START at PRD level**: What business need exists? (REQ-p00xxx)
2. **Add Ops requirement**: How to deploy/operate? (REQ-o00xxx)
3. **Add Dev requirement**: How to build/implement? (REQ-d00xxx)
4. **THEN modify code**: Link code to requirements

**NEVER**:
- ❌ Write code first, then add requirements
- ❌ Skip PRD and start at Ops/Dev
- ❌ Add requirements that describe existing code (use prescriptive SHALL/MUST)

**See**: `spec/requirements-format.md` for complete methodology

## Where to Find Requirements

- **All requirements**: Scan `spec/` directory for `### REQ-{id}:` blocks
- **Validation tool**: `python3 tools/requirements/validate_requirements.py`
- **Traceability matrix**: See `traceability_matrix.md`
- **Format specification**: See `spec/requirements-format.md`

## Enforcement

- **Pre-commit hook**: Validates requirement format and links (`.githooks/pre-commit`)
  - **Setup required**: `git config core.hooksPath .githooks` (one-time per developer)
  - **See**: `.githooks/README.md` for installation and troubleshooting
- **CI/CD check**: GitHub Actions validates on pull requests (see `TODO_CI_CD_SETUP.md`)
- **Manual validation**: Run `python3 tools/requirements/validate_requirements.py`

**Violations will cause build failures. Add requirements BEFORE committing code.**

---

## Workflow for New Features

### Standard Development Workflow

1. **Ticket created**: Issue/ticket defines the need
2. **Assess if ADR needed**: Significant architectural decision with trade-offs?
   - ✅ Yes → Draft ADR in `docs/adr/` with "Proposed" status
   - ❌ No → Proceed to requirements
3. **Create requirements** (top-down cascade):
   - Start with PRD: `REQ-p00xxx` in appropriate `spec/prd-*.md`
   - Add Ops: `REQ-o00xxx` in `spec/ops-*.md` (implements PRD)
   - Add Dev: `REQ-d00xxx` in `spec/dev-*.md` (implements Ops)
4. **Validate requirements**: Run `python3 tools/requirements/validate_requirements.py`
5. **Create feature branch**: `git checkout -b feature/descriptive-name`
6. **Implement code**: Add requirement references in file headers
7. **Update ADR** (if applicable): Set status to "Accepted"
8. **Commit**: Include ticket and requirement references in commit message
9. **Merge to main**: Pre-commit hook validates automatically

### Commit Message Format

```
[TICKET-XXX] Brief description

Detailed explanation of changes.

Implements: REQ-p00xxx, REQ-o00yyy, REQ-d00zzz
ADR: ADR-NNN-title (if applicable)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## Quick Reference

### Finding Documentation

| Need | Location |
|------|----------|
| What the system does | `spec/prd-*.md` |
| How to deploy/operate | `spec/ops-*.md` |
| How to implement | `spec/dev-*.md` |
| Why we made decisions | `docs/adr/` |
| Requirement format | `spec/requirements-format.md` |
| Traceability matrix | `traceability_matrix.md` |
| spec/ vs docs/ rules | `docs/README.md` |

### Key Commands

```bash
# Validate requirements
python3 tools/requirements/validate_requirements.py

# Generate traceability matrix
python3 tools/requirements/generate_traceability.py --format markdown

# Enable git hooks (one-time setup)
git config core.hooksPath .githooks

# Create feature branch
git checkout -b feature/descriptive-name
```
