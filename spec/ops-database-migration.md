# Database Migration Operations Guide

**Version**: 1.0
**Audience**: Operations (Database Administrators, DevOps Engineers)
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment architecture
> **See**: dev-database.md for database schema details
> **See**: ops-database-setup.md for initial database setup
> **See**: ops-deployment.md for deployment workflows
> **See**: dev-compliance-practices.md for 21 CFR Part 11 change control requirements

---

## Executive Summary

Operational procedures for schema changes to the Clinical Trial Diary Database in a multi-sponsor architecture. Each sponsor operates an independent Supabase instance, requiring coordinated migration strategies across multiple databases.

**Key Challenges in Multi-Sponsor Environment**:
- **Core schema consistency**: All sponsors must run same core schema version
- **Sponsor-specific extensions**: Each sponsor may have custom tables/functions
- **Coordinated rollouts**: Core updates affect all sponsors
- **Independent timelines**: Each sponsor controls their own deployment schedule
- **Compliance tracking**: Each sponsor maintains separate change control audit trail

**Migration Types**:
1. **Core schema migrations**: Applied to all sponsors (from core repository)
2. **Sponsor extensions**: Applied to single sponsor only (from sponsor repository)
3. **Emergency hotfixes**: Expedited process for critical issues

---

## Overview

This document defines the migration strategy for schema changes to the Clinical Trial Diary Database. All schema changes must follow this process to ensure data integrity, compliance, and system reliability across all sponsor deployments.

## Principles

1. **All schema changes via versioned migrations**: No manual SQL changes in production
2. **Every migration has a rollback script**: Must be able to undo any change
3. **Migrations tested on dev/staging before production**: Multiple environment validation
4. **Zero-downtime migrations for production**: No service interruptions
5. **All migrations documented and reviewed**: Change control compliance
6. **Multi-sponsor coordination**: Core migrations coordinated across all sponsors

---

## Multi-Sponsor Migration Strategy

### Core vs Sponsor-Specific Migrations

**Core Migrations** (in `clinical-diary/packages/database/migrations/`):
- Changes to base schema (record_audit, record_state, RLS policies, etc.)
- Published as versioned package (`@clinical-diary/database@1.2.3`)
- All sponsors must apply in same order
- Coordinated release schedule (quarterly)

**Sponsor Extension Migrations** (in `clinical-diary-{sponsor}/database/migrations/`):
- Sponsor-specific tables or functions
- Applied only to that sponsor's Supabase instance
- Independent deployment schedule
- Must not conflict with core schema

### Migration Coordination Process

#### Core Schema Release

```
Core Repository                 Sponsor A              Sponsor B              Sponsor C
─────────────────────────────────────────────────────────────────────────────────────────
1. Core migration 005
   created & tested

2. Tag v1.3.0 released ────────> Notify Sponsor A ────> Notify Sponsor B ────> Notify Sponsor C

3. Migration available          4. UAT in staging
   in GitHub package               (1-2 weeks)
                                                       5. UAT in staging
                                                          (1-2 weeks)
                                                                              6. UAT in staging
                                                                                 (1-2 weeks)

                                7. Deploy to prod      8. Deploy to prod      9. Deploy to prod
                                   (Week 1)               (Week 2)               (Week 3)
```

**Each sponsor independently**:
1. Reviews core migration release notes
2. Tests migration in staging environment
3. Obtains UAT sign-off
4. Schedules production deployment
5. Applies migration to production
6. Reports completion to core team

### Version Pinning

**Each sponsor repo specifies core version**:

```yaml
# clinical-diary-orion/pubspec.yaml
dependencies:
  clinical_diary_database:
    hosted:
      name: clinical_diary_database
      url: https://pub.pkg.github.com/yourorg
    version: ^1.3.0  # Pin to specific version
```

**Upgrade process**:
1. Update version in pubspec.yaml
2. Test in staging
3. Deploy to production after validation

### Migration Tracking Per Sponsor

**Each sponsor maintains**:
- Migration log in their Supabase instance
- Change control documentation (21 CFR Part 11)
- Audit trail of all schema changes
- Independent backup/rollback capability

---

## Directory Structure

### Core Repository Structure

```
clinical-diary/packages/database/migrations/
├── README.md                    # Core migration execution instructions
├── 001_initial_schema.sql       # Core schema tables
├── 002_add_audit_metadata.sql   # ALCOA+ audit fields
├── 003_add_rls_policies.sql     # Row-level security
├── 004_add_event_sourcing.sql   # Event Sourcing triggers
└── rollback/
    ├── 002_rollback.sql
    ├── 003_rollback.sql
    └── 004_rollback.sql
```

### Sponsor Repository Structure

```
clinical-diary-orion/database/migrations/
├── README.md                    # Sponsor-specific migration instructions
├── 001_edc_integration.sql      # Orion EDC sync tables (proxy mode)
├── 002_custom_reports.sql       # Orion-specific reporting views
└── rollback/
    ├── 001_rollback.sql
    └── 002_rollback.sql
```

**Note**: Sponsor migrations are numbered independently from core migrations.

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

---

## Multi-Sponsor Deployment Procedures

### Applying Core Migration to All Sponsors

**Scenario**: Core migration 005 released in v1.3.0

**For each sponsor** (repeat these steps):

```bash
# 1. Clone/update sponsor repository
cd clinical-diary-orion
git pull origin main

# 2. Update core database dependency
npm install @clinical-diary/database@1.3.0

# 3. Link to sponsor's Supabase staging instance
supabase link --project-ref orion-staging-xyz

# 4. Apply migration to staging
supabase db push --include node_modules/@clinical-diary/database/migrations/005_description.sql

# 5. Run integration tests
flutter test integration_test/database_test.dart --dart-define=ENV=staging

# 6. UAT validation (sponsor-specific)
# ... test application functionality ...

# 7. Get UAT sign-off

# 8. Link to production instance
supabase link --project-ref orion-prod-abc

# 9. Create backup
supabase db dump > backup-$(date +%Y%m%d).sql

# 10. Apply migration to production
supabase db push --include node_modules/@clinical-diary/database/migrations/005_description.sql

# 11. Verify production
flutter test integration_test/smoke_test.dart --dart-define=ENV=production

# 12. Monitor for 24-48 hours
```

**Coordination**:
- Each sponsor deploys on their own schedule
- Core team tracks deployment status across all sponsors
- No strict deadline (sponsors control timing)
- Critical hotfixes may require expedited coordination

### Applying Sponsor-Specific Migration

**Scenario**: Orion adds custom EDC sync table

**Process** (Orion only):

```bash
# 1. Create migration in sponsor repo
cd clinical-diary-orion/database/migrations
touch 003_add_edc_queue.sql
touch rollback/003_rollback.sql

# 2. Develop migration SQL
# ... write migration ...

# 3. Test in staging
supabase link --project-ref orion-staging-xyz
supabase db push --include ./database/migrations/003_add_edc_queue.sql

# 4. UAT approval

# 5. Deploy to production
supabase link --project-ref orion-prod-abc
supabase db push --include ./database/migrations/003_add_edc_queue.sql
```

**No coordination needed** - only affects Orion's instance.

### Emergency Hotfix Procedure

**Scenario**: Critical bug in core schema (data corruption risk)

**Expedited process**:

1. **Core Team**:
   - Create hotfix migration immediately
   - Tag hotfix release (e.g., v1.3.1)
   - Notify all sponsors (email + Slack)
   - Provide severity assessment and timeline recommendation

2. **Each Sponsor** (prioritized):
   - Review hotfix impact
   - Test in staging (compressed timeline: hours not days)
   - Deploy to production ASAP
   - Report completion to core team

3. **Core Team**:
   - Track deployment across all sponsors
   - Provide support for any issues
   - Document incident and lessons learned

---

## References

- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Database Implementation**: dev-database.md
- **Database Setup**: ops-database-setup.md
- **Deployment Workflows**: ops-deployment.md
- **Compliance Requirements**: dev-compliance-practices.md (Change Control section)
- **FDA 21 CFR Part 11**: Electronic Records and Signatures
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/current/

## Change Log

| Date | Migration | Description | Author |
|------|-----------|-------------|--------|
| 2025-10-14 | 001 | Initial schema | Team |
| 2025-10-14 | Strategy Doc | Migration strategy created | Claude Code |

---

**Document Status**: Active migration operations guide
**Review Cycle**: Quarterly or after major incidents
**Owner**: Database Team / DevOps
**Compliance Review**: Required for all schema changes per 21 CFR Part 11
