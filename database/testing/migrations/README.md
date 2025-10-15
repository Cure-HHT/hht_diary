# Database Migrations

This directory contains versioned database migrations for the Clinical Trial Diary Database.

## Quick Start

### Apply a Migration

```bash
# Connect to your database and apply a migration
psql -U your_user -d dbtest -f database/migrations/XXX_description.sql
```

### Rollback a Migration

```bash
# Connect to your database and rollback a migration
psql -U your_user -d dbtest -f database/migrations/rollback/XXX_rollback.sql
```

## Directory Structure

```
database/migrations/
├── README.md                    # This file
├── 001_initial_schema.sql       # Initial database schema
├── 002_add_audit_metadata.sql   # Add ALCOA+ metadata fields
├── 003_add_tamper_detection.sql # Add cryptographic tamper detection
└── rollback/
    ├── 002_rollback.sql         # Rollback for migration 002
    └── 003_rollback.sql         # Rollback for migration 003
```

## Migration Numbering

Migrations are numbered sequentially with three digits:
- `001` - Initial schema
- `002` - First migration after initial
- `003` - Second migration after initial
- etc.

## Creating a New Migration

### 1. Determine the Next Number

```bash
# Find the highest migration number
ls database/migrations/ | grep -E '^[0-9]{3}_' | sort | tail -1
```

### 2. Create Migration Files

```bash
# Example: Creating migration 004
touch database/migrations/004_your_description.sql
touch database/migrations/rollback/004_rollback.sql
```

### 3. Write Migration SQL

Use this template for `database/migrations/004_your_description.sql`:

```sql
-- =====================================================
-- Migration: 004 - Your Description
-- Ticket: TICKET-XXX
-- Author: Your Name
-- Date: 2025-10-14
-- =====================================================

-- Purpose:
-- Brief description of what this migration does and why

-- Dependencies:
-- List any prerequisite migrations (e.g., "Requires migration 003")

BEGIN;

-- Your migration SQL here
-- Example:
-- ALTER TABLE your_table ADD COLUMN new_column TEXT;
-- COMMENT ON COLUMN your_table.new_column IS 'Description';

-- Verification step (optional but recommended)
DO $$
BEGIN
    -- Check that your changes were applied
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'your_table'
        AND column_name = 'new_column'
    ) THEN
        RAISE EXCEPTION 'Migration failed: new_column not created';
    END IF;

    RAISE NOTICE 'Migration 004 completed successfully';
END $$;

COMMIT;
```

### 4. Write Rollback SQL

Use this template for `database/migrations/rollback/004_rollback.sql`:

```sql
-- =====================================================
-- Rollback: 004 - Your Description
-- =====================================================

-- This rollback script reverses migration 004

BEGIN;

-- Reverse your migration changes here
-- Example:
-- ALTER TABLE your_table DROP COLUMN IF EXISTS new_column;

-- Verification step (optional but recommended)
DO $$
BEGIN
    -- Check that rollback was successful
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'your_table'
        AND column_name = 'new_column'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: new_column still exists';
    END IF;

    RAISE NOTICE 'Rollback 004 completed successfully';
END $$;

COMMIT;
```

### 5. Test Your Migration

```bash
# Apply the migration
psql -U postgres -d dbtest_local -f database/migrations/004_your_description.sql

# Verify it worked
psql -U postgres -d dbtest_local -c "\\d your_table"

# Test the rollback
psql -U postgres -d dbtest_local -f database/migrations/rollback/004_rollback.sql

# Verify rollback worked
psql -U postgres -d dbtest_local -c "\\d your_table"

# Re-apply for continued development
psql -U postgres -d dbtest_local -f database/migrations/004_your_description.sql
```

## Migration Best Practices

### 1. Always Use Transactions

Wrap your migrations in `BEGIN;` and `COMMIT;` so they rollback automatically if any statement fails.

```sql
BEGIN;
-- Your changes here
COMMIT;
```

### 2. Make Migrations Idempotent

Use `IF NOT EXISTS` and `IF EXISTS` to make migrations safe to run multiple times:

```sql
-- Good: Idempotent
ALTER TABLE my_table ADD COLUMN IF NOT EXISTS new_col TEXT;

-- Bad: Will fail on second run
ALTER TABLE my_table ADD COLUMN new_col TEXT;
```

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
END $$;
```

### 4. Document Why, Not Just What

Include comments explaining the business reason for the change:

```sql
-- Add device_info field to satisfy FDA 21 CFR Part 11.10(e)
-- Compliance requirement: Must capture device information for audit trail
ALTER TABLE record_audit ADD COLUMN device_info JSONB;
```

### 5. One Logical Change Per Migration

Don't mix unrelated changes in one migration file. Create separate migrations for:
- Schema changes (tables, columns)
- Index changes
- Function/trigger changes
- Data migrations

### 6. Test Rollbacks

Always test that your rollback script works before merging:

```bash
# Apply migration
psql -f database/migrations/XXX_description.sql

# Test rollback
psql -f database/migrations/rollback/XXX_rollback.sql

# Verify database is in original state
```

## Migration Workflow

### Development

1. Create migration and rollback files
2. Test locally
3. Commit both files
4. Create PR with migration description
5. Get technical review

### Staging

1. Apply migration to staging database
2. Run full test suite
3. Verify application works
4. Get QA approval

### Production

1. Create database backup
2. Apply migration during low-traffic period
3. Verify migration success
4. Monitor for 24-48 hours
5. Document in change log

## Common Migration Patterns

### Adding a Column

```sql
-- Add nullable column
ALTER TABLE my_table ADD COLUMN IF NOT EXISTS new_col TEXT;

-- Add comment
COMMENT ON COLUMN my_table.new_col IS 'Description of column';

-- Rollback
ALTER TABLE my_table DROP COLUMN IF EXISTS new_col;
```

### Adding an Index

```sql
-- Create index
CREATE INDEX IF NOT EXISTS idx_my_table_new_col ON my_table(new_col);

-- Add comment
COMMENT ON INDEX idx_my_table_new_col IS 'Index for new_col queries';

-- Rollback
DROP INDEX IF EXISTS idx_my_table_new_col;
```

### Adding a Function

```sql
-- Create function
CREATE OR REPLACE FUNCTION my_function()
RETURNS void AS $$
BEGIN
    -- Function logic
END;
$$ LANGUAGE plpgsql;

-- Rollback
DROP FUNCTION IF EXISTS my_function();
```

### Adding a Trigger

```sql
-- Create trigger function
CREATE OR REPLACE FUNCTION trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    -- Trigger logic
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER my_trigger
    BEFORE INSERT ON my_table
    FOR EACH ROW
    EXECUTE FUNCTION trigger_function();

-- Rollback
DROP TRIGGER IF EXISTS my_trigger ON my_table;
DROP FUNCTION IF EXISTS trigger_function();
```

## Zero-Downtime Migrations

For production systems that can't have downtime, follow these patterns:

### Adding a NOT NULL Column

```sql
-- Step 1: Add as nullable
ALTER TABLE my_table ADD COLUMN new_col TEXT;

-- Step 2: Backfill data
UPDATE my_table SET new_col = 'default_value' WHERE new_col IS NULL;

-- Step 3: Add NOT NULL constraint (separate migration)
ALTER TABLE my_table ALTER COLUMN new_col SET NOT NULL;
```

### Renaming a Column

```sql
-- Step 1: Add new column
ALTER TABLE my_table ADD COLUMN new_name TEXT;

-- Step 2: Backfill
UPDATE my_table SET new_name = old_name;

-- Step 3: Deploy app to use new_name

-- Step 4: Drop old column (separate migration after app deployed)
ALTER TABLE my_table DROP COLUMN old_name;
```

## Troubleshooting

### Migration Fails

```bash
# Check the error message
# Fix the migration file
# Since we use transactions, the database should be unchanged
# Re-run the corrected migration
```

### Migration Applied But Need to Undo

```bash
# Run the rollback script
psql -f database/migrations/rollback/XXX_rollback.sql
```

### Migration Partially Applied (No Transaction)

```bash
# Manually inspect the database
psql -c "\\d table_name"

# Manually fix the state
# Document the manual fix in the ticket
# Update the migration to use transactions
```

## Migration History

| Migration | Description | Date | Ticket |
|-----------|-------------|------|--------|
| 001 | Initial schema | 2025-10-14 | Initial |
| 002 | Add audit metadata fields | 2025-10-14 | TICKET-001 |
| 003 | Add tamper detection | 2025-10-14 | TICKET-002 |

## References

- [Migration Strategy Documentation](../../spec/MIGRATION_STRATEGY.md)
- [Compliance Practices](../../spec/compliance-practices.md)
- [Core Practices](../../spec/core-practices.md)

## Getting Help

- Review the [Migration Strategy](../../spec/MIGRATION_STRATEGY.md) for detailed guidance
- Ask in the #database channel
- Contact the database architect

---

**Last Updated**: 2025-10-14
**Maintained By**: Database Team
