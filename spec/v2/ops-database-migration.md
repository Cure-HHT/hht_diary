# Database Migration Strategy
# TODO: This file contains redundant information. Remove/move examples to other files, replace with references if necessary.
# TODO: This is a strategy/high-level document. It should read more like a PRD than an implementation spec.
# TODO: Any unique and useful information in this document related to implementation or operations should be moved to another document so that this file can be used as a reference in a hierarchical documentation structure.


## Overview

This document defines the migration strategy for schema changes to the Clinical Trial Diary Database. All schema changes must follow this process to ensure data integrity, compliance, and system reliability.

## Principles

1. **All schema changes via versioned migrations**: No manual SQL changes in production
2. **Every migration has a rollback script**: Must be able to undo any change
3. **Migrations tested on dev/staging before production**: Multiple environment validation
4. **Zero-downtime migrations for production**: No service interruptions
5. **All migrations documented and reviewed**: Change control compliance

## Directory Structure

```
database/migrations/
├── README.md                    # Migration execution instructions
├── 001_initial_schema.sql       # Initial database schema
├── 002_add_audit_metadata.sql   # Example: TICKET-001 implementation
├── 003_add_tamper_detection.sql # Example: TICKET-002 implementation
└── rollback/
    ├── 002_rollback.sql         # Rollback for migration 002
    └── 003_rollback.sql         # Rollback for migration 003
```

## Migration File Naming Convention

Format: `NNN_description.sql`

- `NNN`: Three-digit sequential number (001, 002, 003...)
- `description`: Brief description using underscores (e.g., `add_audit_metadata`)
- Extension: `.sql`

Examples:
- `001_initial_schema.sql`
- `002_add_audit_metadata.sql`
- `003_add_tamper_detection.sql`

## Migration Process

### 1. Development Phase

#### Step 1: Create Migration Files

```bash
# Create migration file
touch database/migrations/XXX_description.sql

# Create corresponding rollback
touch database/migrations/rollback/XXX_rollback.sql
```

#### Step 2: Write Migration SQL

```sql
-- database/migrations/XXX_description.sql
-- =====================================================
-- Migration: XXX - Description
-- Ticket: TICKET-XXX
-- Author: [Your Name]
-- Date: YYYY-MM-DD
-- =====================================================

-- Purpose:
-- Brief description of what this migration does

-- Dependencies:
-- List any prerequisite migrations or conditions

BEGIN;

-- Your migration SQL here
ALTER TABLE record_audit ADD COLUMN IF NOT EXISTS device_info JSONB;

-- Add comments for documentation
COMMENT ON COLUMN record_audit.device_info IS 'Device and platform information for audit trail';

-- Verify migration success
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name = 'device_info'
    ) THEN
        RAISE EXCEPTION 'Migration failed: device_info column not created';
    END IF;
END $$;

COMMIT;
```

#### Step 3: Write Rollback SQL

```sql
-- database/migrations/rollback/XXX_rollback.sql
-- =====================================================
-- Rollback: XXX - Description
-- =====================================================

BEGIN;

-- Reverse the migration changes
ALTER TABLE record_audit DROP COLUMN IF EXISTS device_info;

-- Verify rollback success
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'record_audit'
        AND column_name = 'device_info'
    ) THEN
        RAISE EXCEPTION 'Rollback failed: device_info column still exists';
    END IF;
END $$;

COMMIT;
```

#### Step 4: Test Locally

```bash
# Apply migration
psql -U postgres -d dbtest_local -f database/migrations/XXX_description.sql

# Verify results
psql -U postgres -d dbtest_local -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'record_audit';"

# Test rollback
psql -U postgres -d dbtest_local -f database/migrations/rollback/XXX_rollback.sql

# Verify rollback
psql -U postgres -d dbtest_local -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'record_audit';"

# Re-apply migration for continued development
psql -U postgres -d dbtest_local -f database/migrations/XXX_description.sql
```

#### Step 5: Create Pull Request

- Include both migration and rollback files
- Reference the ticket number
- Document the change in PR description
- Request review from technical lead and compliance officer

### 2. Staging Phase

#### Step 1: Deploy to Staging

```bash
# Apply migration to staging database
psql -h staging.db.example.com -U staging_user -d dbtest_staging -f database/migrations/XXX_description.sql
```

#### Step 2: Validation

- [ ] Run full test suite
- [ ] Verify application functionality
- [ ] Check audit trail integrity
- [ ] Performance test if schema affects queries
- [ ] Verify RLS policies still work
- [ ] Check compliance report generation

#### Step 3: QA Approval

- QA team validates changes
- Compliance officer reviews if needed
- Sign-off documented in ticket

### 3. Production Phase

#### Step 1: Pre-Deployment Checklist

- [ ] Migration tested on staging
- [ ] Rollback tested on staging
- [ ] QA approval obtained
- [ ] Backup plan documented
- [ ] Maintenance window scheduled (if required)
- [ ] Team notified
- [ ] Rollback team on standby

#### Step 2: Backup Production Database

```bash
# Create backup before migration
pg_dump -h production.db.example.com -U prod_user -d dbtest_prod > backup_YYYYMMDD_HHMM.sql

# Verify backup integrity
pg_restore --list backup_YYYYMMDD_HHMM.sql
```

#### Step 3: Apply Migration

```bash
# Apply migration
psql -h production.db.example.com -U prod_user -d dbtest_prod -f database/migrations/XXX_description.sql

# Log the migration
echo "Migration XXX applied at $(date)" >> database/migrations/migration_log.txt
```

#### Step 4: Verification

- [ ] Migration completed successfully
- [ ] Application health checks pass
- [ ] Audit trail integrity maintained
- [ ] No error rate increase
- [ ] Performance metrics normal
- [ ] User functionality verified

#### Step 5: Post-Deployment Monitoring

Monitor for 24-48 hours:
- Error rates
- Query performance
- Database load
- Audit trail integrity
- User-reported issues

### 4. Rollback (If Needed)

#### Rollback Criteria

Execute rollback immediately if:
- Migration fails with errors
- Data corruption detected
- Application error rate increases significantly
- Performance degrades beyond acceptable levels
- Audit trail integrity compromised
- Critical functionality broken

#### Rollback Procedure

```bash
# 1. Notify team
echo "ROLLBACK INITIATED: Migration XXX" | mail -s "Production Rollback" team@example.com

# 2. Execute rollback
psql -h production.db.example.com -U prod_user -d dbtest_prod -f database/migrations/rollback/XXX_rollback.sql

# 3. Verify rollback
psql -h production.db.example.com -U prod_user -d dbtest_prod -c "SELECT version();"

# 4. Restore from backup if rollback fails
psql -h production.db.example.com -U prod_user -d dbtest_prod < backup_YYYYMMDD_HHMM.sql

# 5. Document incident
echo "Rollback executed at $(date) - Reason: [description]" >> database/migrations/migration_log.txt
```

## Zero-Downtime Migration Patterns

### Pattern 1: Adding a New Column

```sql
-- Step 1: Add column as nullable
ALTER TABLE record_audit ADD COLUMN device_info JSONB;

-- Step 2: Backfill data (in batches)
DO $$
DECLARE
    batch_size INT := 1000;
    offset_val INT := 0;
BEGIN
    LOOP
        UPDATE record_audit
        SET device_info = '{}'::jsonb
        WHERE audit_id IN (
            SELECT audit_id FROM record_audit
            WHERE device_info IS NULL
            ORDER BY audit_id
            LIMIT batch_size
        );

        IF NOT FOUND THEN
            EXIT;
        END IF;

        offset_val := offset_val + batch_size;
        RAISE NOTICE 'Backfilled % rows', offset_val;
    END LOOP;
END $$;

-- Step 3: Add NOT NULL constraint (separate migration)
ALTER TABLE record_audit ALTER COLUMN device_info SET NOT NULL;
```

### Pattern 2: Renaming a Column

```sql
-- Step 1: Add new column
ALTER TABLE record_audit ADD COLUMN new_name JSONB;

-- Step 2: Backfill data
UPDATE record_audit SET new_name = old_name;

-- Step 3: Update application to use new_name (deploy code)

-- Step 4: Drop old column (separate migration after code deployed)
ALTER TABLE record_audit DROP COLUMN old_name;
```

### Pattern 3: Changing Column Type

```sql
-- Step 1: Add new column with new type
ALTER TABLE record_audit ADD COLUMN signature_hash_v2 BYTEA;

-- Step 2: Backfill with conversion
UPDATE record_audit SET signature_hash_v2 = decode(signature_hash, 'hex');

-- Step 3: Update application to use new column (deploy code)

-- Step 4: Drop old column (separate migration)
ALTER TABLE record_audit DROP COLUMN signature_hash;
ALTER TABLE record_audit RENAME COLUMN signature_hash_v2 TO signature_hash;
```

## Compliance Requirements

Per FDA 21 CFR Part 11 Change Control requirements, every migration must have:

### Change Request Documentation

- [ ] **Change request ID**: TICKET-XXX
- [ ] **Change description**: What is being changed and why
- [ ] **Impact assessment**: What systems/data are affected
- [ ] **Risk assessment**: Potential risks and mitigation strategies
- [ ] **Compliance impact**: Does this affect audit trail, validation, or compliance?

### Review and Approval

- [ ] **Technical review**: Database architect or senior engineer
- [ ] **Compliance review**: Compliance officer (if compliance-related)
- [ ] **QA review**: QA team sign-off after staging validation
- [ ] **Change approval**: Technical lead approval

### Testing and Validation

- [ ] **Unit tests**: Migration logic tested
- [ ] **Integration tests**: Application still works with new schema
- [ ] **Regression tests**: Existing functionality unaffected
- [ ] **Performance tests**: No significant performance degradation
- [ ] **Compliance tests**: Audit trail integrity maintained

### Documentation

- [ ] **Migration file**: Documented with comments
- [ ] **Rollback file**: Documented with comments
- [ ] **Change log**: Entry added to CHANGELOG.md
- [ ] **Architecture docs**: Updated if architectural change
- [ ] **Compliance docs**: Updated if compliance-related

### Post-Deployment

- [ ] **Migration executed**: Timestamp and executor logged
- [ ] **Verification completed**: All checks passed
- [ ] **Documentation updated**: Production schema documented
- [ ] **Lessons learned**: Any issues documented for future reference

## Migration Tools

### Option 1: Manual Execution (Current Approach)

```bash
# Pros: Simple, transparent, full control
# Cons: Manual process, potential for human error

psql -f database/migrations/XXX_description.sql
```

### Option 2: Migration Tool (Future Consideration)

Consider tools like:
- **Flyway**: Java-based, enterprise-grade
- **Liquibase**: XML/YAML/SQL, extensive features
- **sqitch**: Database-native change management
- **migrate**: Go-based, simple

Evaluation criteria:
- PostgreSQL support
- Rollback capabilities
- Version tracking
- Team familiarity
- CI/CD integration

## Migration Checklist Template

Copy this checklist for each migration:

```markdown
## Migration XXX: [Description]

### Pre-Migration
- [ ] Migration file created: database/migrations/XXX_description.sql
- [ ] Rollback file created: database/migrations/rollback/XXX_rollback.sql
- [ ] Migration tested locally
- [ ] Rollback tested locally
- [ ] PR created and reviewed
- [ ] Technical review approval
- [ ] Compliance review (if applicable)

### Staging
- [ ] Migration applied to staging
- [ ] Application tested on staging
- [ ] Performance tested
- [ ] Compliance verified
- [ ] QA approval obtained
- [ ] Rollback tested on staging

### Production
- [ ] Backup created
- [ ] Team notified
- [ ] Migration applied
- [ ] Verification completed
- [ ] Monitoring active
- [ ] Documentation updated

### Post-Migration
- [ ] No issues after 24 hours
- [ ] No issues after 48 hours
- [ ] Migration logged in change control
- [ ] Lessons learned documented (if applicable)
```

## Common Migration Scenarios

### Scenario 1: TICKET-001 - Add Audit Metadata Fields

See: `database/migrations/002_add_audit_metadata.sql`

**Change**: Add three new columns to `record_audit` table
**Impact**: Low - additive change only
**Downtime**: None required
**Rollback**: Simple column drop

### Scenario 2: TICKET-002 - Add Tamper Detection

See: `database/migrations/003_add_tamper_detection.sql`

**Change**: Add triggers and functions for hash computation
**Impact**: Medium - adds triggers to insert operations
**Downtime**: None required
**Rollback**: Drop triggers and functions

### Scenario 3: Schema Refactoring

**Change**: Split table or normalize data
**Impact**: High - requires data migration
**Downtime**: May require maintenance window
**Rollback**: Complex - may need backup restore

## Troubleshooting

### Migration Fails Midway

```sql
-- If migration fails, transaction will auto-rollback
-- Check error message
-- Fix issue in migration file
-- Re-run migration
```

### Deadlock During Migration

```sql
-- Long-running migrations may cause deadlocks
-- Solution: Run during low-traffic period
-- Or break into smaller batches
```

### Rollback Fails

```bash
# If rollback fails, restore from backup
pg_restore -d dbtest_prod backup_YYYYMMDD_HHMM.sql

# Investigate why rollback failed
# Fix rollback script
# Document in post-mortem
```

## References

- FDA 21 CFR Part 11 - Electronic Records and Signatures
- `spec/compliance-practices.md` - Change Control section (lines 289-318)
- `spec/core-practices.md` - Continuous Compliance section
- PostgreSQL Documentation: https://www.postgresql.org/docs/current/

## Change Log

| Date | Migration | Description | Author |
|------|-----------|-------------|--------|
| 2025-10-14 | 001 | Initial schema | Team |
| 2025-10-14 | Strategy Doc | Migration strategy created | Claude Code |

## Approval

**Document Version**: 1.0
**Created**: 2025-10-14
**Status**: Draft
**Next Review**: 2026-01-14 (Quarterly)

---

**Document Owner**: Database Architect
**Compliance Review**: Required for changes
**Change Control ID**: TICKET-009
