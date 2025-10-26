# Requirements Traceability Format Specification

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2025-01-25

---

## Overview

This document defines the format for traceable requirements across PRD, Operations, and Development specifications.

## Requirement ID Format

### Pattern

```
{level}{5-digit-number}
```

**Levels**:
- `p` = Product Requirements Document (PRD) level
- `o` = Operations level
- `d` = Development level

**Examples**: `p00001`, `o00042`, `d00156`

### ID Assignment Rules

1. **Sequential within level**: IDs increment sequentially within each level
2. **Never reuse**: Deleted requirements keep their ID (marked as deprecated)
3. **Zero-padded**: Always use 5 digits (p00001, not p1)
4. **No gaps required**: IDs can be consecutive

---

## Requirement Block Format

### Structure

```markdown
### REQ-{id}: {informal-title}

**Level**: {PRD|Ops|Dev} | **Implements**: {parent-ids} | **Status**: {Active|Deprecated|Draft}

{requirement-body}

**Rationale**: {why-this-requirement-exists}

**Acceptance Criteria**:
- {criterion-1}
- {criterion-2}
```

### Field Definitions

#### Informal Title
- Brief description for human navigation
- NOT part of the requirement (body is authoritative)
- Can be changed without affecting requirement

#### Level
- `PRD`: Product/business requirement
- `Ops`: Operational requirement (deployment, monitoring, procedures)
- `Dev`: Development requirement (implementation details)

#### Implements
- Parent requirement IDs this implements
- Use `-` if no parent (top-level PRD requirements)
- Multiple parents separated by commas: `p00001, p00003`

#### Status
- `Active`: Current, must be implemented
- `Draft`: Under review, not yet approved
- `Deprecated`: Replaced or no longer needed (keep for history)

#### Requirement Body
- **Authoritative statement** of the requirement
- Uses SHALL/MUST for mandatory, SHOULD for recommended
- Clear, testable, unambiguous
- Can span multiple paragraphs

#### Rationale
- Why this requirement exists
- Business/technical justification
- Optional but recommended

#### Acceptance Criteria
- How to verify the requirement is met
- Testable conditions
- Used by QA and validation

**Note**: Child requirements are automatically discovered by tools scanning for "Implements" references. No manual "Traced by" field is needed.

---

## Requirements Development Methodology

### Top-Down Requirement Creation

**CRITICAL**: Always start at the PRD level when adding new requirements. Never drive PRD requirements from code implementation.

#### Proper Flow (Top-Down)

1. **Identify Business Need**: What does the product/system need to do?
2. **Add PRD Requirement**: Define WHAT at the product level (no implementation details)
3. **Add Ops Requirement**: Define HOW TO DEPLOY/OPERATE (if needed)
4. **Add Dev Requirement**: Define HOW TO BUILD/IMPLEMENT (if needed)

#### Example: Multi-Site Support

```
✅ CORRECT:
1. PRD: "System SHALL support multiple clinical trial sites per sponsor" (p00018)
2. Ops: "Database SHALL be configured with site records and assignments" (o00011)
3. Dev: "Schema SHALL implement sites table with RLS policies" (d00011)
4. Code: schema.sql implements the sites table, references d00011

❌ WRONG:
1. Code: schema.sql has a sites table
2. Dev: "Schema has sites table" (d00011) ← Describes existing code
3. Ops: "Configure the sites table" (o00011) ← Added after code exists
4. PRD: "Support sites" (p00018) ← Business requirement added last!
```

### Why Top-Down Matters

1. **Requirements drive implementation**, not vice versa
2. **PRD stays technology-agnostic** (WHAT, not HOW)
3. **Prevents post-hoc rationalization** of code decisions
4. **Maintains clear business justification** for all features
5. **Enables proper requirement traceability** for auditors

### When Adding Requirements to Existing Code

When retroactively adding requirements to existing code (like our database schema):

1. **Start with PRD**: What business need does this code address?
2. **Write requirement as if code doesn't exist**: What SHOULD the system do?
3. **Cascade down through Ops/Dev**: How should it be deployed/built?
4. **Link code to requirements**: Code implements the requirements

The requirement text should be **prescriptive** (SHALL/MUST), not **descriptive** (currently has/does).

### Code Comments Referencing Requirements

When adding requirement references to code files:

```sql
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00018: Multi-Site Support Per Sponsor
--   REQ-o00011: Multi-Site Data Configuration Per Sponsor
--   REQ-d00011: Multi-Site Schema Implementation
--
-- This schema implements multi-site support per the requirements above.
-- Sites table contains sponsor's clinical trial sites (REQ-p00018).
-- RLS policies enforce site-level access control (REQ-d00011).
```

Code comments explain HOW the code implements requirements, but they don't define WHAT the requirements are.

---

## Examples

### Top-Level PRD Requirement

```markdown
### REQ-p00001: Multi-Sponsor Data Isolation

**Level**: PRD | **Implements**: - | **Status**: Active

The system SHALL ensure complete data isolation between pharmaceutical sponsors
such that no user, administrator, or automated process can access data belonging
to a different sponsor.

Each sponsor SHALL operate in a completely separate environment with:
- Dedicated database instances
- Separate authentication systems
- Independent encryption keys
- Isolated user accounts

**Rationale**: Eliminates any possibility of accidental data mixing or unauthorized
cross-sponsor access. Critical for regulatory compliance and sponsor trust.

**Acceptance Criteria**:
- Database queries cannot return records from other sponsors
- Authentication tokens are scoped to a single sponsor
- Encryption keys are never shared between sponsors
- Administrative access is limited to single sponsor
```

### Ops Requirement Implementing PRD

```markdown
### REQ-o00001: Separate Supabase Projects Per Sponsor

**Level**: Ops | **Implements**: p00001 | **Status**: Active

Each sponsor SHALL be provisioned with a dedicated Supabase project containing:
- Isolated PostgreSQL database
- Separate API endpoints (unique URL)
- Independent authentication configuration
- Isolated storage buckets

**Rationale**: Implements multi-sponsor isolation at the infrastructure level
using Supabase's project isolation guarantees.

**Acceptance Criteria**:
- Each sponsor has unique Supabase project URL
- Database connections do not span projects
- API keys are project-specific
- No shared configuration files
```

### Dev Requirement Implementing Ops

```markdown
### REQ-d00012: Environment-Specific Configuration Files

**Level**: Dev | **Implements**: o00001, o00002 | **Status**: Active

The application SHALL load sponsor-specific configuration from environment files
that specify Supabase connection parameters.

Configuration files SHALL follow the naming pattern:
`environments/{sponsor_code}/supabase_config.dart`

Each file MUST contain:
- `supabaseUrl`: Unique project URL
- `supabaseAnonKey`: Project-specific anonymous key
- `sponsorId`: Unique sponsor identifier

**Rationale**: Enables build-time composition while maintaining runtime isolation.

**Acceptance Criteria**:
- Configuration files exist for each sponsor in version control
- Build process validates all required fields present
- No hardcoded credentials in source code
- URL patterns match expected Supabase format
```

---

## Usage in Code and Commits

### Code Comments

```dart
// REQ-d00012: Load sponsor-specific Supabase configuration
final config = await loadSponsorConfig(sponsorCode);
```

### Commit Messages

```
[p00001] Add multi-sponsor database isolation

Implements REQ-p00001 by creating separate Supabase projects for
each sponsor with isolated databases and authentication.

Related: o00001, o00002
```

### GitHub Issues

```markdown
## Issue: Implement Database Isolation

**Requirements**: p00001, o00001, o00002, d00045

Implement complete database isolation per the requirements above...
```

### Pull Requests

```markdown
## Summary
Implements multi-sponsor isolation requirements

**Requirements Addressed**:
- REQ-p00001: Multi-Sponsor Data Isolation
- REQ-o00001: Separate Supabase Projects Per Sponsor
- REQ-d00012: Environment-Specific Configuration Files

## Changes
...
```

---

## Tooling

### Validation Scripts

Located in `tools/requirements/`:

**validate_requirements.py**: Check requirement format and IDs
- Verify unique IDs
- Check format compliance
- Validate "Implements" links exist
- Find orphaned requirements

**generate_traceability.py**: Generate traceability matrix
- HTML output showing full requirement tree
- CSV export for spreadsheet tools
- Markdown summary for documentation

**check_coverage.py**: Find unimplemented requirements
- PRD requirements without Ops/Dev children
- Ops requirements without Dev children

### Running Validation

```bash
# Validate all requirements
python tools/requirements/validate_requirements.py

# Generate traceability matrix
python tools/requirements/generate_traceability.py --format html

# Check implementation coverage
python tools/requirements/check_coverage.py
```

---

## Migration Strategy

### Phase 1: Add Requirements to New Work
- New features include requirement IDs from start
- Build validation tooling

### Phase 2: Retroactive Documentation
- Add requirement IDs to existing critical features
- Focus on compliance-critical areas first

### Phase 3: Enforcement
- CI/CD checks for requirement references in PRs
- Automated coverage reports

---

## FAQ

### Do all headings become requirements?

No. Only headings prefixed with `REQ-{id}:` are formal requirements.
Regular headings remain unchanged.

### Can I change a requirement's title?

Yes. The title is informal navigation only. The requirement body is authoritative.

### What if I need to change a requirement?

Update the body text, increment a version note if desired. The ID stays the same
so all references remain valid.

### How do I deprecate a requirement?

Change status to `Deprecated` and add explanation. Never delete or reuse the ID.

### Do I need requirements for everything?

No. Use requirements for:
- Compliance-critical functionality
- Cross-cutting concerns (security, isolation, audit)
- Complex features requiring traceability
- Anything that might need validation evidence

Simple implementation details don't need formal requirements.

---

## References

- FDA 21 CFR Part 11 (Electronic Records)
- ISO 13485 (Medical Devices Quality Management)
- ISO 62304 (Medical Device Software Lifecycle)
