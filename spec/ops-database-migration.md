# Database Migration Operations Guide

**Version**: 2.0
**Audience**: Operations (Database Administrators, DevOps Engineers)
**Last Updated**: 2025-11-24
**Status**: Draft

> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment architecture
> **See**: dev-database.md for database schema details
> **See**: ops-database-setup.md for initial database setup
> **See**: ops-deployment.md for deployment workflows
> **See**: dev-compliance-practices.md for 21 CFR Part 11 change control requirements

---

## Executive Summary

Operational procedures for schema changes to the Clinical Trial Diary Database in a multi-sponsor architecture. Each sponsor operates an independent Cloud SQL instance in their GCP project, requiring coordinated migration strategies across multiple databases.

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
- Applied only to that sponsor's Cloud SQL instance
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
- Migration log in their Cloud SQL instance (schema_metadata table)
- Change control documentation (21 CFR Part 11)
- Audit trail of all schema changes
- Independent backup/rollback capability via Cloud SQL PITR

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

-- Update schema version
INSERT INTO schema_metadata (version, description, applied_at)
VALUES ('XXX', 'Add device_info column', now());

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

-- Remove version entry
DELETE FROM schema_metadata WHERE version = 'XXX';

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

#### Step 4: Test Locally via Cloud SQL Proxy

```bash
# Start Cloud SQL Proxy for local development
cloud-sql-proxy your-project:us-central1:dev-instance --port=5432 &

# Set connection variables
export PGHOST=127.0.0.1
export PGPORT=5432
export PGUSER=app_user
export PGDATABASE=clinical_diary
export PGPASSWORD=$(gcloud secrets versions access latest --secret=db-password)

# Apply migration
psql -f database/migrations/XXX_description.sql

# Verify results
psql -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'record_audit';"

# Test rollback
psql -f database/migrations/rollback/XXX_rollback.sql

# Verify rollback
psql -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'record_audit';"

# Re-apply migration for continued development
psql -f database/migrations/XXX_description.sql
```

#### Step 5: Create Pull Request

- Include both migration and rollback files
- Reference the ticket number
- Document the change in PR description
- Request review from technical lead and compliance officer

### 2. Staging Phase

#### Step 1: Deploy to Staging

```bash
# Connect to staging Cloud SQL via proxy
cloud-sql-proxy project-id:region:staging-instance --port=5432 &

# Set connection
export PGHOST=127.0.0.1
export PGDATABASE=clinical_diary
export PGUSER=app_user
export PGPASSWORD=$(gcloud secrets versions access latest --secret=staging-db-password --project=staging-project)

# Apply migration
psql -f database/migrations/XXX_description.sql
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

#### Step 2: Verify Cloud SQL Backups

```bash
# List recent backups
gcloud sql backups list --instance=prod-instance --project=prod-project

# Create on-demand backup before migration
gcloud sql backups create --instance=prod-instance --project=prod-project \
  --description="Pre-migration-XXX-$(date +%Y%m%d)"

# Verify backup completed
gcloud sql operations list --instance=prod-instance --project=prod-project --limit=5
```

#### Step 3: Apply Migration

```bash
# Connect to production Cloud SQL
cloud-sql-proxy prod-project:us-central1:prod-instance --port=5432 &

export PGHOST=127.0.0.1
export PGDATABASE=clinical_diary
export PGUSER=app_user
export PGPASSWORD=$(gcloud secrets versions access latest --secret=prod-db-password --project=prod-project)

# Apply migration
psql -f database/migrations/XXX_description.sql

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
- Error rates (Cloud Monitoring)
- Query performance (Cloud SQL Insights)
- Database load (Cloud SQL metrics)
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

# 2. Execute rollback script
psql -f database/migrations/rollback/XXX_rollback.sql

# 3. Verify rollback
psql -c "SELECT version, description FROM schema_metadata ORDER BY applied_at DESC LIMIT 5;"

# 4. If rollback fails, restore from Cloud SQL backup
gcloud sql backups restore BACKUP_ID --restore-instance=prod-instance \
  --project=prod-project --backup-project=prod-project

# 5. Or use point-in-time recovery
gcloud sql instances clone prod-instance recovered-instance \
  --point-in-time="2025-01-24T10:00:00Z" \
  --project=prod-project

# 6. Document incident
echo "Rollback executed at $(date) - Reason: [description]" >> database/migrations/migration_log.txt
```

## Zero-Downtime Migration Patterns

### Pattern 1: Adding a New Column

```sql
-- Step 1: Add column as nullable (no lock)
ALTER TABLE record_audit ADD COLUMN device_info JSONB;

-- Step 2: Backfill data (in batches to avoid long locks)
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

        -- Small delay between batches
        PERFORM pg_sleep(0.1);
    END LOOP;
END $$;

-- Step 3: Add NOT NULL constraint (separate migration after backfill complete)
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

### Pattern 3: Creating Index Concurrently

```sql
-- Use CONCURRENTLY to avoid locking the table
CREATE INDEX CONCURRENTLY idx_record_audit_patient_date
ON record_audit (patient_id, server_timestamp);

-- Note: Cannot be run inside a transaction
-- Run as standalone statement
```

### Pattern 4: Changing Column Type

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

### Option 1: Manual Execution with Cloud SQL Proxy (Current Approach)

```bash
# Pros: Simple, transparent, full control
# Cons: Manual process, potential for human error

cloud-sql-proxy project:region:instance --port=5432 &
psql -f database/migrations/XXX_description.sql
```

### Option 2: Cloud Build Automated Migrations

```yaml
# cloudbuild-migration.yaml
steps:
  # Download Cloud SQL Proxy
  - name: 'gcr.io/cloud-builders/wget'
    args: ['-O', 'cloud-sql-proxy', 'https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.linux.amd64']

  - name: 'gcr.io/cloud-builders/chmod'
    args: ['+x', 'cloud-sql-proxy']

  # Run migration
  - name: 'postgres:15'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        ./cloud-sql-proxy $_INSTANCE_CONNECTION_NAME --port=5432 &
        sleep 5
        PGPASSWORD=$$DB_PASSWORD psql -h 127.0.0.1 -U $_DB_USER -d $_DB_NAME -f database/migrations/$_MIGRATION_FILE
    secretEnv: ['DB_PASSWORD']

availableSecrets:
  secretManager:
    - versionName: projects/$PROJECT_ID/secrets/db-password/versions/latest
      env: 'DB_PASSWORD'

substitutions:
  _INSTANCE_CONNECTION_NAME: 'project:region:instance'
  _DB_USER: 'app_user'
  _DB_NAME: 'clinical_diary'
  _MIGRATION_FILE: 'XXX_description.sql'
```

### Option 3: Migration Tool (Future Consideration)

Consider tools like:
- **Flyway**: Java-based, enterprise-grade
- **Liquibase**: XML/YAML/SQL, extensive features
- **sqitch**: Database-native change management
- **golang-migrate**: Go-based, simple CLI

Evaluation criteria:
- PostgreSQL support
- Rollback capabilities
- Version tracking
- Team familiarity
- CI/CD integration
- Cloud SQL compatibility

## Migration Checklist Template

Copy this checklist for each migration:

```markdown
## Migration XXX: [Description]

### Pre-Migration
- [ ] Migration file created: database/migrations/XXX_description.sql
- [ ] Rollback file created: database/migrations/rollback/XXX_rollback.sql
- [ ] Migration tested locally via Cloud SQL Proxy
- [ ] Rollback tested locally
- [ ] PR created and reviewed
- [ ] Technical review approval
- [ ] Compliance review (if applicable)

### Staging
- [ ] Cloud SQL Proxy connected to staging
- [ ] Migration applied to staging
- [ ] Application tested on staging
- [ ] Performance tested
- [ ] Compliance verified
- [ ] QA approval obtained
- [ ] Rollback tested on staging

### Production
- [ ] Cloud SQL backup verified
- [ ] On-demand backup created
- [ ] Team notified
- [ ] Migration applied
- [ ] Verification completed
- [ ] Cloud Monitoring alerts reviewed
- [ ] Documentation updated

### Post-Migration
- [ ] No issues after 24 hours
- [ ] No issues after 48 hours
- [ ] Migration logged in change control
- [ ] Lessons learned documented (if applicable)
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

# 3. Connect to sponsor's staging Cloud SQL
export PROJECT_ID=orion-staging
export INSTANCE=clinical-diary-staging
export DB_NAME=clinical_diary

cloud-sql-proxy $PROJECT_ID:us-central1:$INSTANCE --port=5432 &

# 4. Set credentials
export PGHOST=127.0.0.1
export PGUSER=app_user
export PGDATABASE=$DB_NAME
export PGPASSWORD=$(gcloud secrets versions access latest --secret=db-password --project=$PROJECT_ID)

# 5. Apply migration to staging
psql -f node_modules/@clinical-diary/database/migrations/005_description.sql

# 6. Run integration tests
doppler run -- dart test integration_test/database_test.dart

# 7. UAT validation (sponsor-specific)
# ... test application functionality ...

# 8. Get UAT sign-off

# 9. Connect to production
export PROJECT_ID=orion-prod
export INSTANCE=clinical-diary-prod

cloud-sql-proxy $PROJECT_ID:us-central1:$INSTANCE --port=5432 &
export PGPASSWORD=$(gcloud secrets versions access latest --secret=db-password --project=$PROJECT_ID)

# 10. Create backup
gcloud sql backups create --instance=$INSTANCE --project=$PROJECT_ID \
  --description="Pre-migration-005"

# 11. Apply migration to production
psql -f node_modules/@clinical-diary/database/migrations/005_description.sql

# 12. Verify production
doppler run -- dart test integration_test/smoke_test.dart

# 13. Monitor for 24-48 hours via Cloud Monitoring
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

# 3. Test in staging via Cloud SQL Proxy
cloud-sql-proxy orion-staging:us-central1:clinical-diary-staging --port=5432 &
psql -f ./database/migrations/003_add_edc_queue.sql

# 4. UAT approval

# 5. Deploy to production
cloud-sql-proxy orion-prod:us-central1:clinical-diary-prod --port=5432 &
psql -f ./database/migrations/003_add_edc_queue.sql
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

## Cloud SQL Specific Operations

### Point-in-Time Recovery (PITR)

If migration causes data issues, recover to point before migration:

```bash
# Find the timestamp before migration was applied
gcloud sql operations list --instance=prod-instance --filter="operationType:BACKUP"

# Clone to a new instance at specific point in time
gcloud sql instances clone prod-instance recovered-instance \
  --point-in-time="2025-01-24T09:55:00Z" \
  --project=prod-project

# Verify recovered data
cloud-sql-proxy prod-project:us-central1:recovered-instance --port=5433 &
psql -h 127.0.0.1 -p 5433 -U postgres -d clinical_diary \
  -c "SELECT version FROM schema_metadata ORDER BY applied_at DESC LIMIT 1;"

# If data looks good, promote recovered instance or export/import data
```

### Monitoring Migration Performance

```bash
# Check active queries during migration
psql -c "SELECT pid, query, state, query_start FROM pg_stat_activity WHERE state != 'idle';"

# Check for locks
psql -c "SELECT * FROM pg_locks WHERE NOT granted;"

# Check table sizes after migration
psql -c "SELECT pg_size_pretty(pg_total_relation_size('record_audit'));"

# View Cloud SQL Insights for query performance
gcloud sql operations list --instance=prod-instance --limit=10
```

---

## References

- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Database Implementation**: dev-database.md
- **Database Setup**: ops-database-setup.md
- **Deployment Workflows**: ops-deployment.md
- **Compliance Requirements**: dev-compliance-practices.md (Change Control section)
- **FDA 21 CFR Part 11**: Electronic Records and Signatures
- **Cloud SQL Documentation**: https://cloud.google.com/sql/docs/postgres
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/current/

## Change Log

| Date | Migration | Description | Author |
| --- | --- | --- | --- |
| 2025-10-14 | 001 | Initial schema | Team |
| 2025-10-14 | Strategy Doc | Migration strategy created | Claude Code |
| 2025-11-24 | 2.0 | Updated for Cloud SQL and GCP | Development Team |

---

**Document Status**: Active migration operations guide
**Review Cycle**: Quarterly or after major incidents
**Owner**: Database Team / DevOps
**Compliance Review**: Required for all schema changes per 21 CFR Part 11
