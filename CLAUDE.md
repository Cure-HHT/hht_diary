# Project Structure

- read the README.md file
- the spec/ directory contains the specifications for the project and its sub-parts
- the docs/ directory contains descriptions generated during implementation
- the archive/ directory contains obsolete files. DO NOT use unless explicitly asked.
- the evaluation directory contains mock evaluation of the system by a mock Sponsor.
- Always read the spec/README.md file before modifying any files in the spec/ directory.

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

- **Pre-commit hook**: Validates requirement format and links
- **CI/CD check**: GitHub Actions validates on pull requests
- **Manual validation**: Run `python3 tools/requirements/validate_requirements.py`

**Violations will cause build failures. Add requirements BEFORE committing code.**
