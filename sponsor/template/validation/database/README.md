# Database Validation (Optional)

**Component**: Sponsor-Specific Database Instance
**Version**: 1.0
**Audience**: QA/Validation Team, Database Administrator
**Status**: Template (Optional Component)

---

## Overview

This directory contains validation documentation for the sponsor-specific database instance.

**Note**: This is an **optional component**. Database validation is typically only needed when a sponsor deploys a web portal. Portal-less deployments (mobile-only) may not require separate database validation.

### Scope

Database validation focuses on:
- Database schema deployment and integrity
- Row-level security (RLS) policy enforcement
- Event sourcing pattern implementation
- Audit trail immutability and tamper detection
- Backup and recovery procedures
- Data retention compliance

### Key Characteristics

**Sponsor-Specific Instance**:
- Each sponsor has separate Supabase project
- Dedicated PostgreSQL database instance
- Isolated from other sponsors
- Sponsor-specific users and access control

**Shared Schema**:
- Schema deployed from common `database/schema.sql`
- All sponsors use identical schema structure
- No sponsor-specific schema extensions
- Schema versioning tracked

**Optional Component**:
- Required when portal deployed
- May not be needed for mobile-only deployments
- Focus on operational aspects (schema validation is common)

---

## Validation Approach

### Risk-Based Validation

Database validation uses a risk-based approach focusing on:

**High Risk**:
- Audit trail integrity (immutability, tamper detection)
- Data isolation (RLS policy enforcement)
- Backup and recovery (data loss prevention)

**Medium Risk**:
- Schema correctness (structure, constraints)
- Performance (query optimization, indexing)

**Low Risk**:
- Database naming conventions
- Non-critical configuration

### Validation Levels

**Installation Qualification (IQ)**:
- Verify database instance provisioned correctly
- Verify schema deployed from approved source
- Verify database version and configuration
- Verify backup systems configured

**Operational Qualification (OQ)**:
- Verify RLS policies enforce access control
- Verify event sourcing triggers function correctly
- Verify audit trail immutability
- Verify tamper detection works
- Verify backup execution successful

**Performance Qualification (PQ)**:
- Verify query performance meets targets
- Verify concurrent user support
- Verify backup/recovery meets RTO/RPO

---

## Directory Structure

```
database/
├── README.md                          # This file
├── validation-plan.md                 # Overall validation strategy
├── test-protocols/
│   ├── IQ-001-schema-deployment.md    # Schema deployment verification
│   ├── IQ-002-backup-setup.md         # Backup configuration verification
│   ├── OQ-001-rls-enforcement.md      # RLS policy validation
│   ├── OQ-002-event-sourcing.md       # Event sourcing pattern validation
│   ├── OQ-003-audit-integrity.md      # Audit trail immutability
│   ├── OQ-004-tamper-detection.md     # Tampering detection validation
│   ├── OQ-005-backup-execution.md     # Backup process validation
│   ├── OQ-006-recovery-procedure.md   # Recovery process validation
│   └── PQ-001-performance.md          # Query performance validation
├── test-results/
│   └── {version}/                     # Results for each validation cycle
│       ├── IQ-001-results.md
│       ├── OQ-001-results.md
│       └── ...
└── validation-report.md               # Summary report
```

---

## Requirements Coverage

This validation covers the following requirements:

### Product Requirements (PRD)

 | Requirement | Title | Validation Protocol |
 | --- | --- | --- |
 | REQ-p00003 | Separate Database Per Sponsor | IQ-001 |
 | REQ-p00004 | Immutable Audit Trail via Event Sourcing | OQ-002, OQ-003 |
 | REQ-p00013 | Complete Data Change History | OQ-002 |
 | REQ-p00015 | Database-Level Access Enforcement | OQ-001 |
 | REQ-p00035 | Patient Data Isolation | OQ-001 |
 | REQ-p00036 | Investigator Site-Scoped Access | OQ-001 |
 | REQ-p00040 | Event Sourcing State Protection | OQ-001 |

### Development Requirements (DEV)

 | Requirement | Title | Validation Protocol |
 | --- | --- | --- |
 | REQ-d00007 | Database Schema Implementation and Deployment | IQ-001 |
 | REQ-d00011 | Multi-Site Schema Implementation | IQ-001 |
 | REQ-d00019 | Patient Data Isolation RLS Implementation | OQ-001 |
 | REQ-d00020 | Investigator Site-Scoped RLS Implementation | OQ-001 |
 | REQ-d00026 | Event Sourcing State Protection RLS Implementation | OQ-001 |

### Operations Requirements (OPS)

| Requirement | Title | Validation Protocol |
| --- | --- | --- |
| REQ-o00003 | GCP Project Provisioning Per Sponsor | IQ-001 |
| REQ-o00004 | Database Schema Deployment | IQ-001 |
| REQ-o00020 | Patient Data Isolation Policy Deployment | OQ-001 |
| REQ-o00027 | Event Sourcing State Protection Policy Deployment | OQ-001 |

---

## Test Protocol Overview

### IQ-001: Schema Deployment

**Purpose**: Verify database schema deployed correctly per REQ-d00007

**Key Tests**:
- Supabase project provisioned
- PostgreSQL version correct (15+)
- Schema deployed from `database/schema.sql`
- All tables created correctly
- All triggers created and enabled
- All RLS policies created
- All functions/procedures created
- Event sourcing schema present (record_audit, record_state)
- Schema version documented

**Acceptance**: Schema matches approved source, all objects created

---

### IQ-002: Backup Setup

**Purpose**: Verify backup systems configured correctly

**Key Tests**:
- Supabase automatic backups enabled
- Backup retention configured (7 years)
- Backup encryption enabled
- Backup schedule documented
- Backup storage verified (S3)
- Point-in-time recovery (PITR) enabled

**Acceptance**: Backup system configured per retention policy

---

### OQ-001: RLS Policy Enforcement

**Purpose**: Verify RLS policies enforce access control per REQ-p00015, REQ-d00019-20

**Key Tests**:
- Patient isolation: User A cannot query User B's patients
- Site-scoped access: Investigator sees assigned sites only
- Analyst read-only: Analysts cannot INSERT/UPDATE/DELETE
- Administrator access: Admins can access all data with audit trail
- Event sourcing protection: Direct writes to record_state blocked
- Cross-sponsor isolation: No data leakage between sponsors

**Test Method**:
- Create test users with different roles
- Execute queries as each user
- Verify returned data matches role permissions
- Attempt unauthorized operations (expect rejection)

**Acceptance**: All RLS policies enforce correct access, no unauthorized access

---

### OQ-002: Event Sourcing Pattern

**Purpose**: Verify event sourcing implementation per REQ-p00004, REQ-d00007

**Key Tests**:
- Events inserted to `record_audit` table
- Triggers update `record_state` table automatically
- State derived correctly from event history
- Event immutability enforced (no UPDATE/DELETE on record_audit)
- Sequence numbers incremented correctly
- Concurrent event handling correct (optimistic locking)

**Test Method**:
- Insert test events
- Verify state table updated
- Attempt to modify/delete events (expect rejection)
- Verify event sequence correct

**Acceptance**: Event sourcing pattern works correctly, events immutable

---

### OQ-003: Audit Trail Immutability

**Purpose**: Verify audit trail cannot be modified per REQ-p00004

**Key Tests**:
- UPDATE on record_audit rejected
- DELETE on record_audit rejected
- Direct INSERT to record_state rejected
- Trigger-based state updates allowed
- Audit trail complete (all changes captured)
- Original values preserved

**Test Method**:
- Attempt to UPDATE/DELETE audit records
- Verify operations rejected
- Verify only INSERT allowed
- Confirm state updates via triggers only

**Acceptance**: Audit trail immutable, enforced at database level

---

### OQ-004: Tamper Detection

**Purpose**: Verify tamper detection per REQ-o00048

**Key Tests**:
- Cryptographic hashes generated for audit records
- Hash verification function works
- Tampering detected when hash modified
- Sequence number gaps detected
- Alert generated on tampering detection
- Tamper detection runs automatically (every 5 minutes)

**Test Method**:
- Generate test audit records
- Verify hashes calculated correctly
- Modify hash manually (simulate tampering)
- Verify tampering detected
- Verify alert generated

**Acceptance**: Tampering detected within 5 minutes, alerts functional

---

### OQ-005: Backup Execution

**Purpose**: Verify backups execute successfully

**Key Tests**:
- Daily backups execute on schedule
- Backup completion logged
- Backup integrity verified
- Backup size reasonable
- PITR snapshots available
- Failed backup alerts fire

**Acceptance**: 100% of scheduled backups succeed

---

### OQ-006: Recovery Procedure

**Purpose**: Verify recovery procedure works

**Key Tests**:
- Test database restored from backup
- Restored data verified complete
- Restored data verified accurate
- Audit trail integrity preserved in restore
- Recovery procedure follows documented steps
- Recovery time measured

**Test Method**:
- Create test database snapshot
- Restore to new instance
- Compare restored data to original
- Verify audit trail intact
- Document recovery time

**Acceptance**: Test restore successful, data integrity verified, RTO met

---

### PQ-001: Performance

**Purpose**: Verify query performance acceptable

**Key Tests**:
- API query response time <500ms (p95)
- Dashboard queries <2 seconds
- Report generation <30 seconds
- Concurrent user support (50+ queries/second)
- Index usage verified (EXPLAIN ANALYZE)
- Connection pool not exhausted

**Test Method**:
- Execute common queries
- Measure response times
- Analyze query plans
- Load test with concurrent users

**Acceptance**: All performance targets met

---

## Validation Execution

### Pre-Validation Setup

Before executing validation:

1. **Verify database deployed**:
   - Supabase project URL
   - PostgreSQL version
   - Schema version

2. **Prepare test environment**:
   - Test users (various roles)
   - Test data (patients, events, sites)
   - Test database credentials

3. **Document environment**:
   - Supabase project ID
   - Database connection string
   - Schema version hash

4. **Coordinate access**:
   - QA team has database access
   - DBA available for support

### Execution Process

For each test protocol:

1. **Review protocol**: Ensure test steps current
2. **Execute tests**: Follow protocol step-by-step
3. **Document results**: Record actual results
4. **Capture evidence**: SQL queries, query results, logs
5. **Note deviations**: Document unexpected behavior
6. **Pass/fail decision**: Compare to acceptance criteria

### Post-Validation

After all protocols executed:

1. **Review results**: Ensure all tests passed
2. **Address failures**: Investigate and resolve
3. **Re-test if needed**: Re-execute failed tests
4. **Generate validation report**: Summarize results
5. **Archive artifacts**: Store with deployment artifacts

---

## Validation Report

The validation report (`validation-report.md`) includes:

**Executive Summary**:
- Database version validated
- Validation date range
- Overall validation conclusion

**Validation Scope**:
- Components validated
- Requirements covered
- Test protocols executed

**Test Results Summary**:
- Protocol results (pass/fail)
- Deviations and resolutions
- Evidence references (SQL queries, screenshots)

**Traceability Matrix**:
- Requirements-to-test-protocol mapping
- Test coverage analysis

**Conclusion**:
- Validation statement
- Approvals (DBA, QA lead)
- Effective date

---

## Sponsor-Specific Customization

### Customization Points

When customizing this template for a sponsor:

1. **Data Volume**:
   - Adjust performance targets for expected data volume
   - Customize backup retention (default 7 years)
   - Define archive strategy for completed studies

2. **Compliance Requirements**:
   - Add sponsor-specific audit trail requirements
   - Include additional tamper detection checks
   - Customize retention policies

3. **Integration**:
   - Validate EDC sync (if proxy mode)
   - Validate external integrations
   - Add protocol for data import/export

4. **Performance**:
   - Adjust based on expected user count
   - Customize concurrent query targets
   - Define sponsor-specific SLAs

### Example: High-Volume Sponsor

For sponsor with 1000+ patients:

**Update**:
- Performance targets (1000+ queries/second)
- Backup frequency (hourly vs daily)
- Archive strategy (yearly rollups)

**Add**:
- OQ-007-partitioning-validation.md (table partitioning)
- PQ-002-scalability.md (million-record testing)

---

## Revalidation Triggers

Revalidation required when:

1. **Schema changes**:
   - Database migrations deployed
   - New tables/columns added
   - RLS policies updated

2. **Infrastructure changes**:
   - PostgreSQL version upgrade
   - Supabase configuration changes
   - Backup system changes

3. **Annual validation**:
   - Per 21 CFR Part 11 requirements
   - Execute critical protocols
   - Verify ongoing compliance

4. **Audit findings**:
   - Data integrity issues discovered
   - Performance degradation
   - Compliance violations

---

## Database-Less Deployments

If your sponsor uses mobile-only deployment (no portal, no central database):

1. **Delete this directory**: Remove `database/` entirely
2. **Update main README**: Note database not deployed
3. **Focus validation on**: Mobile app local storage and sync

Mobile-only deployments store data locally on devices and may sync peer-to-peer or to minimal backend. Full database validation not required in this scenario.

---

## References

### Requirements

- `spec/prd-database.md` - Database product requirements
- `spec/dev-database.md` - Database implementation requirements
- `spec/ops-database-setup.md` - Database deployment requirements
- `spec/prd-security-RLS.md` - RLS policy requirements

### Architecture

- `spec/prd-architecture-multi-sponsor.md` - Multi-sponsor architecture
- `spec/dev-architecture-multi-sponsor.md` - Implementation details

### Schema

- `database/schema.sql` - Database schema source
- `database/migrations/` - Schema migrations

### Related Validation

- `../mobile-app/README.md` - Mobile app validation
- `../portal/README.md` - Portal validation
- `../operations/README.md` - Operations validation (includes backup)

---

## Change History

 | Date | Version | Author | Changes |
 | --- | --- | --- | --- |
 | 2025-01-13 | 1.0 | Development Team | Initial database validation framework |
