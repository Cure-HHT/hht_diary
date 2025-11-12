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
# REQ-{id}: {informal-title}

**Level**: {PRD|Ops|Dev} | **Implements**: {parent-ids} | **Status**: {Active|Deprecated|Draft} | **Hash**: {sha256-prefix}

{requirement-body}

**Rationale**: {why-this-requirement-exists}

**Acceptance Criteria**:
- {criterion-1}
- {criterion-2}

*end* *optionallly repeat informal-title* **hash:00000000**
```

**Note on Header Levels**: Requirements can use any markdown header level (`#`, `##`, `###`, etc.). The traceability tooling matches the `REQ-{id}:` pattern regardless of header level. In practice, most spec files use `#` (H1) headers for individual requirements, while the "Document Structure Standards" section below shows an alternative organization using `###` (H3) headers within a hierarchical document structure. Choose the approach that best fits your document's organization.

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

#### Hash
- SHA-256 hash of requirement body (first 8 characters)
- Calculated from: requirement body text, rationale, and acceptance criteria
- Excludes: title, metadata line, file path
- Format: 8 lowercase hexadecimal characters (e.g., `abc12345`)
- Purpose: Detect requirement changes for implementation tracking
- Required: Yes
- Updated automatically using `python3 tools/requirements/update-REQ-hashes.py`

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

---

### Requirement Refinement vs. Cascade

Requirements can follow two valid patterns: **cascade** (cross-level) and **refinement** (same-level).

#### Pattern 1: Cascade (PRD → Ops → Dev)

**Purpose**: Decompose business requirement into operational and implementation details

**Example**:
```
REQ-p00006: System SHALL support offline data entry (PRD)
  ├─ REQ-o00002: Deploy local-first database (Ops)
  │    └─ REQ-d00002: Implement IndexedDB sync layer (Dev)
  └─ REQ-o00003: Configure offline sync policies (Ops)
       └─ REQ-d00003: Implement conflict resolution (Dev)
```

**Characteristics**:
- Moves DOWN abstraction levels (business → operations → implementation)
- Each level adds more concrete detail
- Standard pattern for most requirements

#### Pattern 2: Refinement (PRD → PRD or Ops → Ops)

**Purpose**: Refine broad requirement into peer-level specifics

**Example**:
```
REQ-p00005: System SHALL protect PHI (broad security requirement)
  ├─ REQ-p00038: System SHALL enforce row-level security (refinement)
  │    ├─ REQ-o00009: Deploy RLS policies (cascade)
  │    └─ REQ-d00008: Implement RLS (cascade)
  └─ REQ-p00039: System SHALL maintain audit trail (refinement)
       ├─ REQ-o00010: Configure audit logging (cascade)
       └─ REQ-d00009: Implement audit triggers (cascade)
```

**Characteristics**:
- Stays at SAME abstraction level (PRD → PRD)
- Parent requirement is too broad to implement directly
- Each child refines a specific aspect
- Each refined requirement then cascades to Ops/Dev

#### When to Use Each Pattern

**Use Cascade When**:
- Requirement is concrete enough to implement
- Moving from business need to technical solution
- Standard progression: PRD → Ops → Dev

**Use Refinement When**:
- Requirement is too broad ("protect data", "ensure security")
- Multiple distinct aspects need to be specified
- Need to break down before implementation planning

#### Validation Warnings

The validation tool warns about same-level relationships ("PRD implements PRD") to catch accidental errors. These warnings are **informational** - verify the relationship is intentional refinement, not a mistake.

**Valid refinement triggers warning** → Expected, acceptable
**Accidental same-level reference** → Needs fixing

When in doubt, ask: "Is this breaking a broad requirement into specifics (refinement) or implementing a business need technically (cascade)?"

#### Real-World Examples from This Project

**FDA Compliance Refinement**:
```
REQ-p00010: FDA 21 CFR Part 11 Compliance (broad)
  ├─ REQ-p00011: ALCOA+ Principles (specific aspect)
  ├─ REQ-p00012: Data Retention (specific aspect)
  └─ REQ-p00013: Change History (specific aspect)
```

**Security Architecture Refinement**:
```
REQ-p00001: Multi-Sponsor Data Separation (broad)
  ├─ REQ-p00003: Separate Database Per Sponsor (specific mechanism)
  ├─ REQ-p00007: Automatic Configuration (specific behavior)
  └─ REQ-p00008: Single Mobile App (specific deployment)
```

Both patterns are valid and necessary for a complete requirements hierarchy.

---

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
# REQ-p00031: Multi-Sponsor Data Isolation

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

*End* *Multi-Sponsor Data Isolation* | **Hash**: a1b2c3d4
```

### Ops Requirement Implementing PRD

```markdown
# REQ-o00056: Separate Supabase Projects Per Sponsor

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

*End* *Separate Supabase Projects Per Sponsor* | **Hash**: TBD
```

### Dev Requirement Implementing Ops

```markdown
# REQ-d00012: Environment-Specific Configuration Files

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

*End* *Environment-Specific Configuration Files* | **Hash**: 22cd37a6
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
CLAUDE_TODO: insert file links here (relative to git root)

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

### When does a section need a REQ-ID?

Sections need formal REQ-IDs when they define **mandatory system capabilities** using prescriptive language (SHALL/MUST). Sections that explain, describe benefits, or provide context do NOT need REQ-IDs.

**Need REQ-ID** (Prescriptive):
- "The system SHALL ensure..."
- "Users MUST NOT be able to..."
- "Access control SHALL enforce..."
- Defines specific behavior that must be implemented
- Contains acceptance criteria or testable conditions

**No REQ-ID needed** (Descriptive/Explanatory):
- "How It Works" sections explaining features to stakeholders
- "Benefits" lists for users/sponsors
- "What This Means" explanations
- Summaries that reference existing REQs
- Implementation notes that belong in dev-level docs

---

## Document Structure Standards

### Heading Hierarchy in PRD Files

PRD files SHALL follow this standardized heading structure:

```markdown
# Document Title

## {Major Topic Section}
High-level section divider (no REQs expected at this level)

### REQ-pXXXXX: {Requirement Title}
Formal product requirement with complete metadata

**Level**: PRD | **Implements**: {parent-ids} | **Status**: Active
[requirement body with SHALL/MUST language]
**Rationale**: [why it exists]
**Acceptance Criteria**: [testable conditions]

---

### {Explanatory Heading}
Contextual explanation for stakeholders (no REQ-ID needed)
- Describes how features work
- Lists benefits
- Provides examples

#### {Sub-detail Heading}
Implementation notes or additional context
- Lower-level details
- "How it works" mechanics
- User-facing explanations

---

### REQ-pXXXXY: {Next Requirement}
[next formal requirement...]
```

### Heading Level Guidelines

| Level | Purpose | REQ-ID Required? | Example |
|-------|---------|------------------|---------|
| `#` | Document title | Never | `# Security Architecture` |
| `##` | Major topic section | Never | `## User Authentication` |
| `###` | Formal requirement OR explanatory section | Only if prescriptive | `### REQ-p00002: MFA for Staff`<br>or<br>`### How Users Log In` |
| `####` | Sub-details, implementation notes | Never | `#### Password Requirements` |

### Section Ordering Convention

Within each major topic (`##`), organize as:

1. **Formal requirements first** (### REQ-pXXXXX)
2. **Explanatory sections second** (### heading without REQ)
3. **Implementation details last** (#### subheadings)

**Example**:

```markdown
## Access Control

### REQ-p00033: Role-Based Access Control
[formal requirement with SHALL/MUST]

### REQ-p00034: Least Privilege Access
[formal requirement with SHALL/MUST]

### How Access Control Works
[explanatory section describing the implementation]

#### Example Scenarios
[implementation examples]
```

### Separating Requirements from Explanations

Use horizontal rules (`---`) to clearly separate formal requirements from explanatory content:

```markdown
### REQ-p00032: Complete Multi-Sponsor Data Separation
[requirement body]
**Rationale**: [...]
**Acceptance Criteria**: [...]

---

### How Multi-Sponsor Isolation Works
[explanatory content for stakeholders]
```

### Policy/Implementation Reference Pattern

When implementation sections reference formal requirements (as in prd-security-RLS.md):

```markdown
### REQ-pXXXXX: Example Requirement
[formal requirement]

---

### Policy Implementation Details

#### Policy 1: Example Implementation (Implements REQ-pXXXXX)
[technical implementation details, SQL policies, etc.]
```

This pattern:
- Defines the WHAT (formal requirement)
- Separates the HOW (implementation details)
- Links implementation back to requirement
- Keeps PRD readable for non-technical stakeholders

---

## References

- FDA 21 CFR Part 11 (Electronic Records)
- ISO 13485 (Medical Devices Quality Management)
- ISO 62304 (Medical Device Software Lifecycle)
