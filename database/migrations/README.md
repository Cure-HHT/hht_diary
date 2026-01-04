# Database Migration Files

## Overview

This directory contains database migration scripts for production deployment. Migrations are **deployment artifacts** that modify the database schema over time in a controlled, versioned manner.

**IMPORTANT: Pre-Deployment (v0.x.x)**

Until v1.0.0 deployment, this directory should remain empty. All schema changes should be made directly to the source schema files (`database/schema.sql`, `database/roles.sql`, etc.). Migrations are only needed after the first production deployment to evolve the schema without data loss.

**Key Principles**:
- Migrations are numbered sequentially and applied in order
- Each migration is immutable once deployed
- Every migration should have a corresponding rollback script
- Migrations use simplified operational headers (not requirement traceability)

---

## Migration vs Implementation Files

Understanding the difference between implementation files and migration files is crucial:

### Implementation Files

**Location**: `database/schema.sql`, `database/triggers.sql`, `database/rls_policies.sql`

**Purpose**: Source code defining the database structure
**Header format**: Formal requirement traceability
**Required fields**: IMPLEMENTS REQUIREMENTS with REQ-pXXXXX, REQ-oXXXXX, REQ-dXXXXX
**Audience**: Developers, auditors, compliance teams
**Lifecycle**: Long-lived, stable, modified over time
**Validation**: Pre-commit hook checks requirement links

**Example header**:
```sql
-- IMPLEMENTS REQUIREMENTS:
--   REQ-p00004: Immutable Audit Trail via Event Sourcing
--   REQ-d00007: Database Schema Implementation
```

### Migration Files

**Location**: `database/migrations/NNN_description.sql`

**Purpose**: Deployment artifacts that apply changes to database
**Header format**: Simplified operational metadata
**Required fields**: Number, Description, Dependencies, Reference
**Audience**: DevOps, DBAs, deployment automation
**Lifecycle**: Created once, never modified after deployment
**Validation**: CI/CD checks migration sequence

**Example header**:
```sql
-- =====================================================
-- Migration: Add JSONB Validation Functions
-- Number: 008
-- Description: Implements comprehensive validation for diary event data
-- Dependencies: Requires base schema (001)
-- Reference: spec/JSONB_SCHEMA.md
-- =====================================================
```

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

**Why The Difference?**

| Aspect | Implementation Files | Migration Files |
| --- | --- | --- |
| **Audience** | Developers, auditors, compliance | DevOps, DBAs, deployment automation |
| **Traceability** | Requirements (REQ-xxx) | Other migrations (dependencies) |
| **Lifecycle** | Long-lived, stable | Created once, never modified |
| **Purpose** | Define WHAT to build | Define HOW to deploy |
| **Validation** | Pre-commit hook checks requirement links | CI/CD checks migration sequence |

---

## Creating Migrations

### Step-by-Step Process

#### 1. Identify the Change
- What database modification is needed?
- Does it require changes to tables, functions, triggers, or policies?

#### 2. Update Implementation File First
- Modify the source file (`schema.sql`, `triggers.sql`, etc.)
- Ensure it includes proper requirement headers

#### 3. Determine Next Migration Number

```bash
# Find the highest migration number
ls database/migrations/ | grep -E '^[0-9]{3}_' | sort | tail -1
# Example output: 009_configure_rls.sql
# Next number would be: 010
```

#### 4. Create Migration Files

```bash
cd database/migrations
# Create migration file
touch 010_your_description.sql

# Create rollback file
touch rollback/010_rollback.sql
```

#### 5. Write Migration Header

Use the standard migration header template:

```sql
-- =====================================================
-- Migration: <Brief Description>
-- Number: <NNN>
-- Description: <Detailed explanation of what this migration does>
-- Dependencies: <What must exist before running this>
-- Reference: <Link to related spec or implementation file>
-- =====================================================
```

**Header Fields Explained**:
- **Migration**: Brief, descriptive title (e.g., "Add Session Tracking")
- **Number**: Three-digit zero-padded number matching filename (e.g., 010)
- **Description**: Detailed explanation including why this change is needed
- **Dependencies**: List of prerequisite migrations (e.g., "Requires base schema (001)")
- **Reference**: Links to spec/ files, implementation files, or ADRs

#### 6. Write Migration SQL

Add your SQL statements within a transaction:

```sql
BEGIN;

-- Your database changes here
ALTER TABLE my_table ADD COLUMN new_column TEXT;
COMMENT ON COLUMN my_table.new_column IS 'Description of column';

-- Verification step (recommended)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'my_table'
        AND column_name = 'new_column'
    ) THEN
        RAISE EXCEPTION 'Migration failed: new_column not created';
    END IF;

    RAISE NOTICE 'Migration 010 completed successfully';
END $$;

COMMIT;
```

#### 7. Create Rollback Script

Write the corresponding rollback in `rollback/010_rollback.sql`:

```sql
-- =====================================================
-- Rollback: <Brief Description>
-- Number: <NNN>
-- Description: Removes changes from migration <NNN>
-- =====================================================

BEGIN;

-- Reverse your migration changes
ALTER TABLE my_table DROP COLUMN IF EXISTS new_column;

-- Verification step (recommended)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'my_table'
        AND column_name = 'new_column'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: new_column still exists';
    END IF;

    RAISE NOTICE 'Rollback 010 completed successfully';
END $$;

COMMIT;
```

#### 8. Test Locally

```bash
# Apply the migration
psql -U postgres -d dbtest_local -f database/migrations/010_your_description.sql

# Verify it worked
psql -U postgres -d dbtest_local -c "\\d my_table"

# Test the rollback
psql -U postgres -d dbtest_local -f database/migrations/rollback/010_rollback.sql

# Verify rollback worked
psql -U postgres -d dbtest_local -c "\\d my_table"

# Re-apply for continued development
psql -U postgres -d dbtest_local -f database/migrations/010_your_description.sql
```

#### 9. Update Documentation
- Add entry to Migration History table in this README
- Update deployment guides if needed

---

## Migration Templates

### Template 1: Adding a Column

**Migration (NNN_add_column.sql)**:
```sql
-- =====================================================
-- Migration: Add User Type Column
-- Number: 010
-- Description: Adds user_type column to support role-based access
-- Dependencies: Requires base schema (001)
-- Reference: database/schema.sql, spec/prd-security.md
-- =====================================================

BEGIN;

-- Add nullable column
ALTER TABLE users ADD COLUMN IF NOT EXISTS user_type TEXT;

-- Add comment
COMMENT ON COLUMN users.user_type IS 'User role type for access control';

-- Verification
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'user_type'
    ) THEN
        RAISE EXCEPTION 'Migration failed: user_type not created';
    END IF;

    RAISE NOTICE 'Migration 010 completed successfully';
END $$;

COMMIT;
```

**Rollback (rollback/NNN_rollback.sql)**:
```sql
-- =====================================================
-- Rollback: Add User Type Column
-- Number: 010
-- Description: Removes user_type column added in migration 010
-- =====================================================

BEGIN;

-- Drop column
ALTER TABLE users DROP COLUMN IF EXISTS user_type;

-- Verification
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'user_type'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: user_type still exists';
    END IF;

    RAISE NOTICE 'Rollback 010 completed successfully';
END $$;

COMMIT;
```

### Template 2: Adding a Function

**Migration**:
```sql
-- =====================================================
-- Migration: Add Data Anonymization Functions
-- Number: 011
-- Description: Implements GDPR-compliant data anonymization
-- Dependencies: Requires base schema (001)
-- Reference: spec/prd-privacy.md, spec/dev-data-privacy.md
-- =====================================================

BEGIN;

-- Create function
CREATE OR REPLACE FUNCTION anonymize_patient_data(patient_id UUID)
RETURNS VOID AS $$
BEGIN
    -- Anonymization logic here
    UPDATE record_state
    SET event_data = jsonb_set(event_data, '{patient_name}', '"[REDACTED]"')
    WHERE event_data->>'patient_id' = patient_id::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comment
COMMENT ON FUNCTION anonymize_patient_data(UUID) IS 'GDPR Right to Erasure implementation';

-- Verification
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'anonymize_patient_data'
    ) THEN
        RAISE EXCEPTION 'Migration failed: function not created';
    END IF;

    RAISE NOTICE 'Migration 011 completed successfully';
END $$;

COMMIT;
```

**Rollback**:
```sql
-- =====================================================
-- Rollback: Add Data Anonymization Functions
-- Number: 011
-- Description: Removes anonymization function from migration 011
-- =====================================================

BEGIN;

DROP FUNCTION IF EXISTS anonymize_patient_data(UUID);

-- Verification
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'anonymize_patient_data'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: function still exists';
    END IF;

    RAISE NOTICE 'Rollback 011 completed successfully';
END $$;

COMMIT;
```

### Template 3: Adding an Index

**Migration**:
```sql
-- =====================================================
-- Migration: Add Performance Index on Timestamps
-- Number: 012
-- Description: Improves query performance for audit log time-range queries
-- Dependencies: Requires base schema (001)
-- Reference: database/schema.sql, spec/ops-performance.md
-- =====================================================

BEGIN;

-- Create index
CREATE INDEX IF NOT EXISTS idx_record_audit_created_at
ON record_audit(created_at DESC);

-- Add comment
COMMENT ON INDEX idx_record_audit_created_at IS 'Performance index for time-range audit queries';

-- Verification
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_record_audit_created_at'
    ) THEN
        RAISE EXCEPTION 'Migration failed: index not created';
    END IF;

    RAISE NOTICE 'Migration 012 completed successfully';
END $$;

COMMIT;
```

**Rollback**:
```sql
-- =====================================================
-- Rollback: Add Performance Index on Timestamps
-- Number: 012
-- Description: Removes index from migration 012
-- =====================================================

BEGIN;

DROP INDEX IF EXISTS idx_record_audit_created_at;

-- Verification
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_record_audit_created_at'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: index still exists';
    END IF;

    RAISE NOTICE 'Rollback 012 completed successfully';
END $$;

COMMIT;
```

### Template 4: Updating RLS Policies

**Migration**:
```sql
-- =====================================================
-- Migration: Update RLS for Multi-Site Support
-- Number: 013
-- Description: Adds site-based access control to RLS policies
-- Dependencies: Requires RLS configuration (009), sites table (001)
-- Reference: database/rls_policies.sql, spec/prd-security-RLS.md
-- =====================================================

BEGIN;

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

-- Verification
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'record_state_select'
        AND tablename = 'record_state'
    ) THEN
        RAISE EXCEPTION 'Migration failed: policy not created';
    END IF;

    RAISE NOTICE 'Migration 013 completed successfully';
END $$;

COMMIT;
```

**Rollback**:
```sql
-- =====================================================
-- Rollback: Update RLS for Multi-Site Support
-- Number: 013
-- Description: Restores original RLS policy from before migration 013
-- =====================================================

BEGIN;

-- Drop new policy
DROP POLICY IF EXISTS record_state_select ON record_state;

-- Restore old policy (user-only access)
CREATE POLICY record_state_select ON record_state
    FOR SELECT
    TO authenticated
    USING (patient_id = auth.uid());

-- Verification
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE policyname = 'record_state_select'
        AND tablename = 'record_state'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: policy not restored';
    END IF;

    RAISE NOTICE 'Rollback 013 completed successfully';
END $$;

COMMIT;
```

---

## Migration Best Practices

### 1. Always Use Transactions

Wrap migrations in `BEGIN;` and `COMMIT;` so they rollback automatically if any statement fails.

```sql
BEGIN;
-- Your changes here
COMMIT;
```

**Why**: Ensures atomicity - either all changes apply or none do. Prevents partial migrations that leave the database in an inconsistent state.

### 2. Make Migrations Idempotent

Use `IF NOT EXISTS` and `IF EXISTS` to make migrations safe to run multiple times:

```sql
-- Good: Idempotent
ALTER TABLE my_table ADD COLUMN IF NOT EXISTS new_col TEXT;
CREATE INDEX IF NOT EXISTS idx_name ON my_table(new_col);

-- Bad: Will fail on second run
ALTER TABLE my_table ADD COLUMN new_col TEXT;
CREATE INDEX idx_name ON my_table(new_col);
```

**Why**: Allows safe retry of failed migrations and prevents errors during development/testing.

### 3. Include Verification Steps

Add checks to ensure your migration succeeded:

```sql
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'my_table' AND column_name = 'new_col'
    ) THEN
        RAISE EXCEPTION 'Migration verification failed';
    END IF;

    RAISE NOTICE 'Migration completed successfully';
END $$;
```

**Why**: Catches silent failures and provides immediate feedback on migration success.

### 4. Document Why, Not Just What

Include comments explaining the business reason for the change:

```sql
-- Add device_info field to satisfy FDA 21 CFR Part 11.10(e)
-- Compliance requirement: Must capture device information for audit trail
ALTER TABLE record_audit ADD COLUMN device_info JSONB;
```

**Why**: Future maintainers need context to understand the purpose and avoid inadvertently removing critical functionality.

### 5. One Logical Change Per Migration

Don't mix unrelated changes in one migration file. Create separate migrations for:
- Schema changes (tables, columns)
- Index changes
- Function/trigger changes
- Data migrations
- RLS policy updates

**Why**: Makes rollbacks cleaner, simplifies debugging, and allows independent deployment of changes.

### 6. Test Rollbacks Before Merging

Always test that your rollback script works:

```bash
# Apply migration
psql -f database/migrations/XXX_description.sql

# Test rollback
psql -f database/migrations/rollback/XXX_rollback.sql

# Verify database is in original state
psql -c "\\d table_name"
```

**Why**: Rollbacks are critical for production incidents. Untested rollbacks are useless in emergencies.

### 7. Use Comments Extensively

Add PostgreSQL comments to all new database objects:

```sql
COMMENT ON TABLE new_table IS 'Description of purpose';
COMMENT ON COLUMN new_table.col IS 'Field description';
COMMENT ON FUNCTION func() IS 'Function purpose';
COMMENT ON INDEX idx IS 'Index optimization target';
```

**Why**: Makes the database self-documenting and helps DBAs understand the schema without reading code.

### 8. Consider Performance Impact

For large tables, consider:
- Creating indexes `CONCURRENTLY` to avoid blocking
- Adding NOT NULL constraints in multiple steps
- Using `SET NOT NULL` only after data is backfilled

```sql
-- Create index without blocking writes
CREATE INDEX CONCURRENTLY idx_name ON large_table(column);
```

**Why**: Prevents production downtime during migrations on large datasets.

---

## Migration Naming Convention

### Pattern

`{NNN}_{descriptive_name}.sql`

### Rules

1. **Three-digit zero-padded number** (001, 002, ..., 010, 099, 100)
2. **Lowercase with underscores** (no spaces, hyphens, or camelCase)
3. **Descriptive action verb** (add, configure, update, remove, enable, create)
4. **Never reuse numbers** (even if migration deleted)

### Good Examples

- `001_initial_schema.sql` - Base schema creation
- `008_add_jsonb_validation.sql` - Add validation functions
- `009_configure_rls.sql` - Enable Row-Level Security
- `010_add_session_tracking.sql` - Add session columns
- `011_create_anonymization_functions.sql` - Add GDPR functions

### Bad Examples

- `1_schema.sql` - Not zero-padded
- `010-add-column.sql` - Uses hyphens instead of underscores
- `010_AddColumn.sql` - Uses camelCase instead of lowercase
- `010_changes.sql` - Not descriptive enough

---

## Migration Dependencies

### Declaring Dependencies

Always declare dependencies in the header when a migration requires:
- Specific tables to exist
- Functions or triggers from previous migrations
- Extension installations
- Schema modifications from earlier migrations

```sql
-- Dependencies: Requires base schema (001)
-- Dependencies: Requires validation functions (008) and RLS setup (009)
```

### Dependency Chain Example

```
001_initial_schema.sql
  └─ Creates: tables, base functions
      ├─ 008_add_jsonb_validation.sql
      │    └─ Depends on: Tables from 001
      │    └─ Adds: Validation functions
      │         └─ 010_add_validation_trigger.sql
      │              └─ Depends on: Functions from 008
      └─ 009_configure_rls.sql
           └─ Depends on: Tables from 001
           └─ Adds: RLS policies
```

### Circular Dependencies

**Avoid circular dependencies.** If you encounter a situation where two changes seem mutually dependent:

1. Break into smaller migrations
2. Add temporary nullable columns
3. Use multi-step migrations

---

## Reference Field Guidelines

The "Reference:" field links migrations back to authoritative documentation.

### Link to Spec Files (Requirements)

```sql
-- Reference: spec/JSONB_SCHEMA.md
-- Reference: spec/dev-security-RLS.md
-- Reference: spec/prd-privacy.md
```

### Link to Implementation Files

```sql
-- Reference: database/rls_policies.sql
-- Reference: database/schema.sql
-- Reference: database/triggers.sql
```

### Link to ADRs (Architectural Decisions)

```sql
-- Reference: docs/adr/ADR-001-event-sourcing-pattern.md
-- Reference: docs/adr/ADR-015-rls-implementation.md
```

### Multiple References

```sql
-- Reference: database/schema.sql, spec/dev-compliance-practices.md, docs/adr/ADR-020-audit-metadata.md
```

---

## Common Migration Patterns

### Adding NOT NULL Column to Populated Table

**Bad** (causes errors on existing rows):
```sql
ALTER TABLE my_table ADD COLUMN new_col TEXT NOT NULL;
```

**Good** (multi-step approach):

**Migration 010**: Add nullable column and backfill
```sql
BEGIN;
-- Step 1: Add as nullable
ALTER TABLE my_table ADD COLUMN new_col TEXT;

-- Step 2: Backfill data
UPDATE my_table SET new_col = 'default_value' WHERE new_col IS NULL;

COMMIT;
```

**Migration 011**: Add NOT NULL constraint
```sql
BEGIN;
-- Step 3: Add NOT NULL constraint
ALTER TABLE my_table ALTER COLUMN new_col SET NOT NULL;
COMMIT;
```

### Renaming a Column

**Bad** (breaks running applications):
```sql
ALTER TABLE my_table RENAME COLUMN old_name TO new_name;
```

**Good** (zero-downtime approach):

**Migration 012**: Add new column and sync
```sql
BEGIN;
-- Step 1: Add new column
ALTER TABLE my_table ADD COLUMN new_name TEXT;

-- Step 2: Backfill from old column
UPDATE my_table SET new_name = old_name;

-- Step 3: Create trigger to keep them in sync
CREATE TRIGGER sync_column_names
    BEFORE INSERT OR UPDATE ON my_table
    FOR EACH ROW
    EXECUTE FUNCTION sync_old_and_new_columns();
COMMIT;
```

**Migration 013** (after app deployed): Remove old column
```sql
BEGIN;
-- Step 4: Drop trigger
DROP TRIGGER IF EXISTS sync_column_names ON my_table;

-- Step 5: Drop old column
ALTER TABLE my_table DROP COLUMN old_name;
COMMIT;
```

### Changing Column Type

**Bad** (may fail with data):
```sql
ALTER TABLE my_table ALTER COLUMN my_col TYPE integer USING my_col::integer;
```

**Good** (safe approach):

**Migration 014**: Add new typed column
```sql
BEGIN;
-- Add new column with desired type
ALTER TABLE my_table ADD COLUMN my_col_new INTEGER;

-- Safely convert data (with error handling)
UPDATE my_table
SET my_col_new = CASE
    WHEN my_col ~ '^\d+$' THEN my_col::integer
    ELSE NULL
END;
COMMIT;
```

**Migration 015**: Switch to new column
```sql
BEGIN;
-- Drop old column
ALTER TABLE my_table DROP COLUMN my_col;

-- Rename new column
ALTER TABLE my_table RENAME COLUMN my_col_new TO my_col;
COMMIT;
```

### Adding Foreign Key to Existing Table

**Bad** (may fail if data doesn't match):
```sql
ALTER TABLE child_table
ADD CONSTRAINT fk_parent
FOREIGN KEY (parent_id) REFERENCES parent_table(id);
```

**Good** (validated approach):

**Migration 016**: Add constraint with validation
```sql
BEGIN;
-- First, validate data will satisfy constraint
DO $$
DECLARE
    invalid_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO invalid_count
    FROM child_table c
    LEFT JOIN parent_table p ON c.parent_id = p.id
    WHERE c.parent_id IS NOT NULL AND p.id IS NULL;

    IF invalid_count > 0 THEN
        RAISE EXCEPTION 'Cannot add foreign key: % rows reference non-existent parents', invalid_count;
    END IF;
END $$;

-- Add constraint
ALTER TABLE child_table
ADD CONSTRAINT fk_parent
FOREIGN KEY (parent_id) REFERENCES parent_table(id);

COMMIT;
```

---

## Testing Migrations

### Local Testing Workflow

```bash
# 1. Create test database
createdb dbtest_migrations

# 2. Apply all existing migrations
for f in database/migrations/0*.sql; do
    echo "Applying $f"
    psql dbtest_migrations -f "$f"
done

# 3. Test your new migration
psql dbtest_migrations -f database/migrations/010_new_migration.sql

# 4. Verify results
psql dbtest_migrations -c "\\d table_name"

# 5. Test rollback
psql dbtest_migrations -f database/migrations/rollback/010_rollback.sql

# 6. Verify rollback
psql dbtest_migrations -c "\\d table_name"

# 7. Clean up
dropdb dbtest_migrations
```

### Testing with Supabase

```bash
# Start local Supabase
supabase start

# Apply migration
supabase db push database/migrations/010_new_migration.sql

# Check result in Supabase dashboard
supabase dashboard

# Reset to test again
supabase db reset

# Apply all migrations
supabase db push
```

### Automated Testing

Create a test script `test_migration.sh`:

```bash
#!/bin/bash
set -e

DB="dbtest_$$"
MIGRATION=$1

echo "Creating test database: $DB"
createdb "$DB"

echo "Applying all migrations before $MIGRATION"
# Apply migrations up to the one being tested
for f in database/migrations/*.sql; do
    [[ "$f" < "database/migrations/$MIGRATION" ]] || break
    psql "$DB" -f "$f" -q
done

echo "Testing migration: $MIGRATION"
psql "$DB" -f "database/migrations/$MIGRATION"

echo "Testing rollback"
psql "$DB" -f "database/migrations/rollback/${MIGRATION%.*}_rollback.sql"

echo "Cleaning up"
dropdb "$DB"

echo "✓ Migration test passed"
```

Usage:
```bash
chmod +x test_migration.sh
./test_migration.sh 010_new_migration.sql
```

---

## Deployment

### Development Environment

```bash
# Apply migration locally
psql -U postgres -d dbtest_local -f database/migrations/010_migration.sql

# Verify
psql -U postgres -d dbtest_local -c "\\d table_name"
```

### Staging Environment

```bash
# Apply to staging Supabase project
supabase db push database/migrations/010_migration.sql --project-ref <staging-ref>

# Run test suite
npm run test:integration

# Verify application works
npm run test:e2e
```

### Production Deployment

**See [docs/ops-database-deployment.md](/home/mclew/dev24/diary-worktrees/clean-docs/docs/ops-database-deployment.md) for complete operational procedures.**

**Quick reference**:

1. **Pre-deployment**:
   - Create database backup
   - Announce maintenance window
   - Review migration and rollback scripts
   - Test in staging

2. **Apply migration**:
   ```bash
   # Via Supabase CLI
   supabase db push database/migrations/010_migration.sql --project-ref <prod-ref>

   # Or via Supabase SQL Editor (for manual control)
   # Copy and paste migration SQL
   ```

3. **Post-deployment**:
   - Verify migration success
   - Monitor application logs
   - Check database performance
   - Update change log

4. **Rollback if needed**:
   ```bash
   supabase db push database/migrations/rollback/010_rollback.sql --project-ref <prod-ref>
   ```

---

## Troubleshooting

### Migration Fails During Application

**Symptom**: Migration stops with an error

**Cause**: SQL syntax error, constraint violation, or missing dependency

**Solution**:
1. Since we use transactions, database should be unchanged
2. Check error message for specific issue
3. Fix migration file
4. Re-run corrected migration

```bash
# Check error
psql -f database/migrations/010_migration.sql
# ERROR:  column "new_col" already exists

# Fix the migration (add IF NOT EXISTS)
# Re-run
psql -f database/migrations/010_migration.sql
# Success
```

### Migration Applied But Need to Undo

**Symptom**: Migration succeeded but caused issues

**Solution**: Run the rollback script

```bash
# Rollback the migration
psql -f database/migrations/rollback/010_rollback.sql

# Verify rollback
psql -c "\\d table_name"

# Fix the migration
# Re-apply when ready
psql -f database/migrations/010_migration.sql
```

### Migration Partially Applied (No Transaction)

**Symptom**: Migration failed but some changes were applied

**Cause**: Migration didn't use `BEGIN;`/`COMMIT;` wrapper

**Solution**:
1. Manually inspect database state
   ```bash
   psql -c "\\d table_name"
   psql -c "\\df function_name"
   psql -c "\\di index_name"
   ```
2. Manually reverse applied changes
3. Document manual fix in ticket
4. Update migration to use transactions
5. Re-test

### Rollback Script Doesn't Exist

**Symptom**: Need to rollback but no rollback script

**Solution**:
1. Create rollback script retroactively
2. Test it thoroughly
3. Apply rollback
4. Document in post-mortem

### Migration Number Conflict

**Symptom**: Two developers created migrations with same number

**Solution**:
1. Renumber one migration to next available number
2. Update "Number:" field in header
3. Update filename
4. Ensure Dependencies: field is still correct
5. Update rollback script filename
6. Never merge conflicting numbers to main branch

### Migration Applied to Wrong Environment

**Symptom**: Production migration applied to staging or vice versa

**Solution**:
1. If applied to lower environment: Not critical, proceed with higher environment
2. If applied to production prematurely:
   - Assess impact immediately
   - Run rollback if safe
   - If rollback unsafe, apply dependent migrations to complete the change
   - Document incident

### RLS Blocks All Access After Migration

**Symptom**: Users cannot see any data after RLS migration

**Solution**:
1. Verify JWT token contains correct user ID
   ```sql
   SELECT current_setting('request.jwt.claims', true) AS jwt_claims;
   ```
2. Check `auth.uid()` returns expected value
3. Verify users assigned to sites in `user_site_assignments`
4. Test policy logic directly:
   ```sql
   -- Check what the policy condition evaluates to
   SELECT
       patient_id,
       patient_id = auth.uid() AS can_access
   FROM record_state
   LIMIT 5;
   ```

### Validation Function Too Strict

**Symptom**: Valid data rejected after migration

**Solution**:
1. Test validation function directly:
   ```sql
   SELECT validate_diary_data('<your_json>'::jsonb);
   ```
2. Check error message for specific validation failure
3. Verify data matches spec exactly
4. If spec is wrong, update spec first, then migration
5. Create new migration to fix validation logic

---

## Validation

### What IS Validated

- **Implementation files** (`schema.sql`, `triggers.sql`, etc.) - Checked for requirement links by pre-commit hooks
- **Spec files** (`spec/prd-*.md`, `spec/dev-*.md`, etc.) - Validated for correct format

### What is NOT Validated

- **Migration files** - Not checked by requirement validation tool because they are deployment artifacts, not implementation source
- **Rollback scripts** - Tested manually before production use

### CI/CD Checks

Migrations are validated by the deployment process:
- Sequential numbering
- Dependency satisfaction
- SQL syntax validation
- Rollback script existence

---

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
3. Update filename to match
4. Ensure Dependencies: field is still correct
5. Update corresponding rollback script
6. Never merge conflicting numbers to main branch

### Can I have gaps in migration numbers?

**Yes.** If a migration is abandoned or rolled back permanently, it's fine to have gaps:
- `008_add_validation.sql`
- `009_configure_rls.sql`
- `011_add_index.sql` (010 was abandoned)

### Should I commit migration and rollback together?

**Yes, always.** Every migration commit should include:
- The migration file
- The corresponding rollback file
- Updates to this README if needed

### How do I test migrations before production?

1. Test locally on development database
2. Apply to staging environment
3. Run full test suite
4. Get QA approval
5. Schedule production deployment during low-traffic period

### What if a migration takes too long?

For migrations that might take minutes on large tables:
1. Add progress output:
   ```sql
   RAISE NOTICE 'Processing batch %/%', current_batch, total_batches;
   ```
2. Consider breaking into smaller migrations
3. Use `CREATE INDEX CONCURRENTLY` for indexes
4. Schedule during maintenance window

### Can I run multiple migrations at once?

**No.** Apply migrations sequentially in order:
```bash
# Bad
psql -f 010_migration.sql & psql -f 011_migration.sql &

# Good
psql -f 010_migration.sql && psql -f 011_migration.sql
```

### How do I know which migrations have been applied?

Supabase and some other systems track this automatically. For manual PostgreSQL:

Create a migrations tracking table:
```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
    migration_number INTEGER PRIMARY KEY,
    migration_name TEXT NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Update migrations to record themselves:
```sql
-- At end of migration
INSERT INTO schema_migrations (migration_number, migration_name)
VALUES (010, '010_add_session_tracking.sql');
```

---

## Migration History

| Migration | Description | Date | Ticket | Status |
| --- | --- | --- | --- | --- |
| 001 | Initial schema | 2025-10-14 | Initial | Applied |
| 002 | Add audit metadata fields | 2025-10-14 | TICKET-001 | Applied |
| 003 | Add tamper detection | 2025-10-14 | TICKET-002 | Applied |

*(Update this table when new migrations are created)*

---

## Directory Structure

```
database/migrations/
├── README.md                    # This file
├── 001_initial_schema.sql       # Initial database schema
├── 002_add_audit_metadata.sql   # Add ALCOA+ metadata fields
├── 003_add_tamper_detection.sql # Add cryptographic tamper detection
├── 008_add_jsonb_validation.sql # JSONB validation functions
├── 009_configure_rls.sql        # Row-Level Security policies
└── rollback/
    ├── 001_rollback.sql         # Rollback for migration 001
    ├── 002_rollback.sql         # Rollback for migration 002
    ├── 003_rollback.sql         # Rollback for migration 003
    ├── 008_rollback.sql         # Rollback for migration 008
    └── 009_rollback.sql         # Rollback for migration 009
```

---

## References

- **[docs/ops-database-deployment.md](/home/mclew/dev24/diary-worktrees/clean-docs/docs/ops-database-deployment.md)** - Complete operational deployment procedures, testing, and monitoring
- **[spec/requirements-format.md](/home/mclew/dev24/diary-worktrees/clean-docs/spec/requirements-format.md)** - Requirement traceability format for implementation files
- **[database/schema.sql](/home/mclew/dev24/diary-worktrees/clean-docs/database/schema.sql)** - Implementation file with requirement headers
- **[spec/MIGRATION_STRATEGY.md](/home/mclew/dev24/diary-worktrees/clean-docs/spec/MIGRATION_STRATEGY.md)** - High-level migration strategy (if exists)

---

## Getting Help

- Review this README for migration standards and templates
- Check [docs/ops-database-deployment.md](/home/mclew/dev24/diary-worktrees/clean-docs/docs/ops-database-deployment.md) for deployment procedures
- Consult spec/ files for requirement details
- Ask in the #database channel
- Contact the database architect

---

**Last Updated**: 2025-11-11
**Maintained By**: Database Team
