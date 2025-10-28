# Database Migration Files

## Overview

This directory contains database migration scripts for Supabase deployment. Migrations are **deployment artifacts** that modify the database schema over time.

## Migration Header Format

### Standard Migration Header Template

```sql
-- =====================================================
-- Migration: <Brief Description>
-- Number: <NNN>
-- Description: <Detailed explanation of what this migration does>
-- Dependencies: <What must exist before running this>
-- Reference: <Link to related spec or implementation file>
-- =====================================================
```

### Example

```sql
-- =====================================================
-- Migration: Add JSONB Validation Functions
-- Number: 008
-- Description: Implements comprehensive validation for diary event data
-- Dependencies: Requires base schema (001)
-- Reference: spec/JSONB_SCHEMA.md
-- =====================================================
```

## Why Migrations Use Different Format

### Implementation Files vs Migration Files

**Implementation files** (schema.sql, triggers.sql, rls_policies.sql):
- **Purpose**: Source code defining the database structure
- **Header format**: Formal requirement traceability
- **Required fields**: IMPLEMENTS REQUIREMENTS with REQ-pXXXXX, REQ-oXXXXX, REQ-dXXXXX
- **Example**:
  ```sql
  -- IMPLEMENTS REQUIREMENTS:
  --   REQ-p00004: Immutable Audit Trail via Event Sourcing
  --   REQ-d00007: Database Schema Implementation
  ```

**Migration files** (008_add_jsonb_validation.sql):
- **Purpose**: Deployment artifacts that apply changes to database
- **Header format**: Simplified operational metadata
- **Required fields**: Number, Description, Dependencies, Reference
- **Example**: See template above

### Why The Difference?

| Aspect | Implementation Files | Migration Files |
|--------|---------------------|-----------------|
| **Audience** | Developers, auditors, compliance | DevOps, DBAs, deployment automation |
| **Traceability** | Requirements (REQ-xxx) | Other migrations (dependencies) |
| **Lifecycle** | Long-lived, stable | Created once, never modified |
| **Purpose** | Define WHAT to build | Define HOW to deploy |
| **Validation** | Pre-commit hook checks requirement links | CI/CD checks migration sequence |

### Relationship Between Implementation and Migration

```
Implementation File (database/schema.sql)
├─ Contains: Full table definitions
├─ Header: IMPLEMENTS REQUIREMENTS (REQ-p00xxx, REQ-d00xxx)
└─ Deployed via: Migration script references it

Migration File (migrations/001_initial_schema.sql)
├─ Contains: SQL to create/modify database
├─ Header: Migration metadata (Number, Dependencies, Reference)
├─ Reference: Points back to implementation file
└─ Applied by: Supabase migration system
```

## Migration Workflow

### Creating a New Migration

1. **Identify the change**: What database modification is needed?
2. **Update implementation file**: Modify the source (schema.sql, triggers.sql, etc.)
3. **Create migration script**:
   ```bash
   cd database/migrations
   # Use next available number
   touch 010_add_new_feature.sql
   ```
4. **Add migration header**: Use template above
5. **Add SQL statements**: Write the actual database changes
6. **Reference implementation**: Link to the source file in "Reference:" field
7. **Create rollback script**: Add corresponding rollback in `rollback/` directory
8. **Test locally**: Apply migration to test database
9. **Document**: Update DEPLOYMENT_GUIDE.md if needed

### Naming Convention

**Pattern**: `{NNN}_{descriptive_name}.sql`

**Examples**:
- `001_initial_schema.sql` - Base schema creation
- `008_add_jsonb_validation.sql` - Add validation functions
- `009_configure_rls.sql` - Enable Row-Level Security

**Rules**:
- Three-digit zero-padded number (001, 002, ..., 010)
- Lowercase with underscores
- Descriptive action verb (add, configure, update, remove)
- Never reuse numbers (even if migration deleted)

## Migration Dependencies

### Declaring Dependencies

```sql
-- Dependencies: Requires base schema (001)
```

**Always declare dependencies when migration requires:**
- Specific tables to exist
- Functions or triggers from previous migrations
- Extension installations
- Schema modifications

### Dependency Chain Example

```
001_initial_schema.sql
  └─ Creates: tables, base functions
      ├─ 008_add_jsonb_validation.sql
      │    └─ Depends on: Tables from 001
      │    └─ Adds: Validation functions
      └─ 009_configure_rls.sql
           └─ Depends on: Tables from 001
           └─ Adds: RLS policies
```

## Reference Field

The "Reference:" field links migrations back to authoritative documentation:

**Link to spec/ files** (requirements):
```sql
-- Reference: spec/JSONB_SCHEMA.md
-- Reference: spec/dev-security-RLS.md
```

**Link to implementation files**:
```sql
-- Reference: database/rls_policies.sql
-- Reference: database/schema.sql
```

**Link to ADRs** (architectural decisions):
```sql
-- Reference: docs/adr/ADR-001-event-sourcing-pattern.md
```

## Rollback Scripts

Every migration SHOULD have a corresponding rollback script in `rollback/`:

**Migration**: `migrations/010_add_new_table.sql`
**Rollback**: `rollback/010_rollback.sql`

Rollback scripts reverse the migration changes:
```sql
-- =====================================================
-- Rollback: Add New Table
-- Number: 010
-- Description: Removes new_table added in migration 010
-- =====================================================

DROP TABLE IF EXISTS new_table CASCADE;
```

## Validation

Migrations are NOT validated by the requirement validation tool (`tools/requirements/validate_requirements.py`) because they are deployment artifacts, not implementation source.

**What IS validated:**
- Implementation files (schema.sql, triggers.sql, etc.) - Checked for requirement links
- Spec files (spec/prd-*.md, spec/dev-*.md, etc.) - Validated for correct format

**What is NOT validated:**
- Migration files - Checked by deployment process only
- Rollback scripts - Tested manually before production use

## Deployment Process

See `DEPLOYMENT_GUIDE.md` for complete deployment procedures.

**Quick reference:**
```bash
# Apply migration locally
supabase db push

# Apply migration to production (via CI/CD)
# See spec/ops-deployment.md
```

## Examples

### Example 1: Schema Modification

```sql
-- =====================================================
-- Migration: Add Session Tracking to Audit Log
-- Number: 010
-- Description: Adds session_id and ip_address columns to record_audit
-- Dependencies: Requires base schema (001)
-- Reference: database/schema.sql, spec/dev-compliance-practices.md
-- =====================================================

ALTER TABLE record_audit ADD COLUMN session_id TEXT;
ALTER TABLE record_audit ADD COLUMN ip_address INET;

COMMENT ON COLUMN record_audit.session_id IS 'User session identifier for audit correlation';
COMMENT ON COLUMN record_audit.ip_address IS 'Source IP address for security tracking';
```

### Example 2: Function Addition

```sql
-- =====================================================
-- Migration: Add Data Anonymization Functions
-- Number: 011
-- Description: Implements GDPR-compliant data anonymization
-- Dependencies: Requires base schema (001)
-- Reference: spec/prd-privacy.md, spec/dev-data-privacy.md
-- =====================================================

CREATE OR REPLACE FUNCTION anonymize_patient_data(patient_id UUID)
RETURNS VOID AS $$
BEGIN
    -- Anonymization logic here
    UPDATE record_state
    SET event_data = jsonb_set(event_data, '{patient_name}', '"[REDACTED]"')
    WHERE event_data->>'patient_id' = patient_id::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION anonymize_patient_data(UUID) IS 'GDPR Right to Erasure implementation';
```

### Example 3: RLS Policy Update

```sql
-- =====================================================
-- Migration: Update RLS for Multi-Site Support
-- Number: 012
-- Description: Adds site-based access control to RLS policies
-- Dependencies: Requires RLS configuration (009), sites table (001)
-- Reference: database/rls_policies.sql, spec/prd-security-RLS.md
-- =====================================================

-- Drop old policy
DROP POLICY IF EXISTS record_state_select ON record_state;

-- Create new site-aware policy
CREATE POLICY record_state_select ON record_state
    FOR SELECT
    TO authenticated
    USING (
        site_id IN (
            SELECT site_id
            FROM user_site_assignments
            WHERE user_id = auth.uid() AND active = true
        )
    );
```

## FAQ

### Do I need requirement IDs in migration headers?

**No.** Migration files are deployment artifacts and use simplified headers. Requirement traceability happens in the implementation files (schema.sql, triggers.sql, etc.).

### What if I need to change a migration after it's deployed?

**Never modify deployed migrations.** Create a new migration that makes the changes:
- Deployed migration: `010_add_column.sql` (adds `user_type TEXT`)
- New migration: `011_modify_user_type.sql` (changes to `user_type user_role_enum`)

### Should migrations reference Linear tickets?

**Optional but recommended.** Add ticket reference in Description field:
```sql
-- Description: Implements session tracking (Linear: CUR-127)
```

This helps correlate migrations with project management without requiring formal REQ-xxx traceability.

### How do I handle migration conflicts in git?

Migrations are numbered sequentially. If two developers create migrations with the same number:
1. Renumber one migration to next available number
2. Update "Number:" field in header
3. Ensure Dependencies: field is still correct
4. Never merge conflicting numbers to main branch

---

**See Also**:
- `DEPLOYMENT_GUIDE.md` - Full deployment procedures
- `spec/requirements-format.md` - Requirement traceability format
- `database/schema.sql` - Implementation file with requirement headers
- `spec/ops-deployment.md` - Operations procedures
