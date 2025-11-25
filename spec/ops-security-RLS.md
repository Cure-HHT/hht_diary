# Row-Level Security Operations

**Version**: 1.0
**Audience**: Operations
**Last Updated**: 2025-10-26
**Status**: Active

> **See**: prd-security-RLS.md for product requirements
> **See**: dev-security-RLS.md for implementation details
> **See**: ops-database-setup.md for database provisioning

---

## Executive Summary

This document defines operational procedures for deploying, configuring, and monitoring PostgreSQL Row-Level Security (RLS) policies that enforce access control requirements. Each sponsor's Cloud SQL instance requires RLS policies to be enabled and properly configured to ensure data isolation and regulatory compliance.

---

## RLS Policy Deployment Requirements

# REQ-o00020: Patient Data Isolation Policy Deployment

**Level**: Ops | **Implements**: p00035 | **Status**: Active

PostgreSQL Row-Level Security policies SHALL be deployed to enforce patient data isolation, ensuring patients can only access their own clinical diary entries through database-level access controls.

Policy deployment SHALL include:
- RLS enabled on all patient data tables (`record_state`, `record_audit`)
- SELECT policy filtering by `patient_id = current_user_id()`
- INSERT policy validating `patient_id` matches authenticated user
- Policy enforcement cannot be bypassed by service role
- Policies deployed via migration scripts with rollback capability
- Policy testing executed before production deployment

**Rationale**: Implements patient data isolation (p00035) through PostgreSQL RLS. Deployment procedures ensure policies are consistently applied across all sponsor instances and cannot be circumvented.

**Acceptance Criteria**:
- RLS enabled on patient data tables in all sponsor databases
- Patients can query only their own records (verified by test suite)
- Cross-patient access attempts return empty results
- Policies survive database restores and migrations
- Policy deployment logged in change management system

*End* *Patient Data Isolation Policy Deployment* | **Hash**: 055dc1e6
---

# REQ-o00021: Investigator Site-Scoped Access Policy Deployment

**Level**: Ops | **Implements**: p00036 | **Status**: Active

PostgreSQL Row-Level Security policies SHALL be deployed to restrict investigator access to clinical data at their assigned sites only, with site assignments managed in database tables.

Policy deployment SHALL include:
- RLS policies on clinical data tables filtering by site assignment
- `investigator_site_assignments` table created and indexed
- Subquery validation against assignment table in RLS policy
- Site de-assignment immediately revokes data access
- Single active site context enforced through application session management
- Migration scripts creating assignment tables and policies

**Rationale**: Implements site-scoped access (p00036) at the database level. Multi-site clinical trials require investigators to access only their assigned sites to maintain data integrity and regulatory compliance.

**Acceptance Criteria**:
- RLS policies enforce site-level filtering on clinical data tables
- `investigator_site_assignments` table exists with proper indexes
- Site assignment changes reflected immediately in access control
- Investigators cannot access unassigned sites' data (verified by tests)
- Assignment table and policies deployed atomically via migration

*End* *Investigator Site-Scoped Access Policy Deployment* | **Hash**: 38196c93
---

# REQ-o00022: Investigator Annotation Access Policy Deployment

**Level**: Ops | **Implements**: p00037 | **Status**: Active

PostgreSQL Row-Level Security policies SHALL be deployed to allow investigators to create annotations while preventing modification of patient-entered clinical data.

Policy deployment SHALL include:
- `investigator_annotations` table created with RLS policies
- INSERT policy on annotations table allowing site-scoped creation
- No UPDATE/DELETE policies on `record_audit` table for investigators
- No modification policies on `record_state` table for investigators
- Annotation schema includes investigator identity and timestamp columns
- Foreign key constraints linking annotations to clinical records

**Rationale**: Implements annotation restrictions (p00037) ensuring investigators can add clinical notes without altering patient-reported data. Database-level enforcement prevents accidental or intentional data modification.

**Acceptance Criteria**:
- Investigators can create annotations at assigned sites
- Investigators cannot modify `record_state` or `record_audit` tables
- Annotation attempts on unassigned sites fail
- All annotations include investigator ID and timestamp
- Policies prevent modification of patient diary entries

*End* *Investigator Annotation Access Policy Deployment* | **Hash**: d428ead1
---

# REQ-o00023: Analyst Read-Only Access Policy Deployment

**Level**: Ops | **Implements**: p00022 | **Status**: Active

PostgreSQL Row-Level Security policies SHALL be deployed to provide analysts read-only access to de-identified clinical data at their assigned sites.

Policy deployment SHALL include:
- SELECT policies on clinical data tables for analyst role
- Site-scoping via `analyst_site_assignments` table
- No INSERT, UPDATE, or DELETE policies for analyst role
- Query audit logging enabled for analyst access
- Assignment table with site-to-analyst mappings
- Policies enforce de-identified data access only

**Rationale**: Implements analyst read-only access (p00022) with site-scoping. Missing write policies inherently enforce read-only access at database level, preventing data modification.

**Acceptance Criteria**:
- Analysts can SELECT from clinical data tables at assigned sites
- Analysts cannot INSERT, UPDATE, or DELETE any records
- Site assignments restrict data visibility
- All analyst queries logged in audit trail
- No patient identity accessible to analyst role

*End* *Analyst Read-Only Access Policy Deployment* | **Hash**: 346c5484
---

# REQ-o00024: Sponsor Global Access Policy Deployment

**Level**: Ops | **Implements**: p00023 | **Status**: Active

PostgreSQL Row-Level Security policies SHALL be deployed to provide sponsors read access to all clinical data across all sites within their isolated database instance.

Policy deployment SHALL include:
- SELECT policies on clinical data tables for sponsor role (no site filter)
- No modification policies on clinical data tables for sponsor role
- Full access policies on user management and configuration tables
- Sponsor isolation enforced through separate GCP projects (Cloud SQL)
- Policies allow de-identified data access only
- Write access limited to administrative tables

**Rationale**: Implements sponsor global access (p00023) within their isolated instance. Separate database per sponsor ensures no cross-sponsor access; RLS ensures sponsors cannot modify clinical data.

**Acceptance Criteria**:
- Sponsors can view data from all sites in their instance
- Sponsors cannot modify clinical data tables
- Sponsors can manage users and configuration
- No access to other sponsors' data (separate databases)
- Read-only clinical access enforced by missing write policies

*End* *Sponsor Global Access Policy Deployment* | **Hash**: 1a54172d
---

# REQ-o00025: Auditor Compliance Access Policy Deployment

**Level**: Ops | **Implements**: p00038 | **Status**: Active

PostgreSQL Row-Level Security policies SHALL be deployed to provide auditors read-only access to all data including audit logs, with data export actions logged and justified.

Policy deployment SHALL include:
- SELECT policies on all tables for auditor role (no restrictions)
- No INSERT, UPDATE, or DELETE policies for auditor role
- Export logging function capturing justification and case ID
- Quarterly access review procedures documented
- Policies covering clinical data, audit logs, and system tables
- Export activity tracked in separate audit table

**Rationale**: Implements auditor compliance access (p00038) required for FDA 21 CFR Part 11. Auditors need global read access for compliance monitoring but must not modify any records.

**Acceptance Criteria**:
- Auditors can SELECT from all tables across all sites
- Auditors cannot modify any records
- Data export functions require justification parameter
- Export actions logged with auditor identity and case ID
- Access review procedures documented and scheduled

*End* *Auditor Compliance Access Policy Deployment* | **Hash**: 7778ee1d
---

# REQ-o00026: Administrator Access Policy Deployment

**Level**: Ops | **Implements**: p00039 | **Status**: Active

PostgreSQL Row-Level Security policies SHALL be deployed for administrator access with comprehensive logging and break-glass access controls for protected health information.

Policy deployment SHALL include:
- Full access policies for administrator role on all tables
- Break-glass access logging function for PHI access
- Ticket ID and TTL validation for break-glass sessions
- Separate policies for routine admin vs. break-glass access
- Quarterly access review procedures
- Justification logging for all administrative actions

**Rationale**: Implements administrator access (p00039) with accountability. Break-glass mechanism provides emergency PHI access while maintaining audit trail and time-limited authorization.

**Acceptance Criteria**:
- Administrators can modify configuration and user tables
- PHI access requires explicit break-glass authorization
- Break-glass sessions include ticket ID and TTL
- All admin actions logged with identity and justification
- Access reviews conducted quarterly

*End* *Administrator Access Policy Deployment* | **Hash**: bd1671e2
---

# REQ-o00027: Event Sourcing State Protection Policy Deployment

**Level**: Ops | **Implements**: p00040 | **Status**: Active

PostgreSQL Row-Level Security policies SHALL be deployed to prevent direct modification of the `record_state` table, enforcing event sourcing architecture through missing write policies.

Policy deployment SHALL include:
- No INSERT, UPDATE, or DELETE policies on `record_state` table
- All write operations directed to `record_audit` table
- Database triggers updating `record_state` from events
- Trigger functions secured with SECURITY DEFINER
- Event log immutability enforced by append-only policies
- State derivation logic tested for correctness

**Rationale**: Implements event sourcing state protection (p00040) ensuring audit trail is single source of truth. Missing RLS policies make direct state modification impossible, enforcing immutable event log architecture.

**Acceptance Criteria**:
- No RLS policies exist for modifying `record_state`
- Direct modification attempts return permission denied
- All changes flow through `record_audit` table
- Triggers automatically update `record_state`
- Event sourcing integrity maintained at database level

*End* *Event Sourcing State Protection Policy Deployment* | **Hash**: a2326ae4
---

## Deployment Procedures

### Pre-Deployment Validation

Before deploying RLS policies to production:

1. **Migration Script Review**:
   - SQL syntax validated by PostgreSQL parser
   - Rollback script tested in staging environment
   - Migration includes atomic transaction wrapping
   - Version control commit references requirement ID

2. **Policy Testing**:
   - Test suite covering all roles and scenarios
   - Positive tests: authorized access succeeds
   - Negative tests: unauthorized access blocked
   - Performance testing for policy overhead

3. **Documentation**:
   - Migration documented in change log
   - Requirement traceability verified
   - Rollback procedures documented
   - Monitoring alerts configured

### Deployment Process

1. **Staging Deployment**:
   - Deploy to staging database first
   - Execute full test suite
   - Validate policy behavior
   - Monitor for performance impact

2. **Production Deployment**:
   - Schedule during maintenance window
   - Execute migration within transaction
   - Verify policy activation
   - Run smoke tests
   - Monitor for 24 hours

3. **Post-Deployment**:
   - Verify all policies active via `pg_policies` view
   - Execute automated test suite
   - Review audit logs for policy violations
   - Update deployment documentation

### Rollback Procedures

If policy deployment fails or causes issues:

1. **Execute Rollback Migration**:
   - Rollback script drops policies
   - Transaction ensures atomic rollback
   - Database restored to pre-deployment state

2. **Root Cause Analysis**:
   - Review failed deployment logs
   - Identify policy configuration errors
   - Test fixes in staging environment
   - Document lessons learned

---

## Monitoring and Maintenance

### Policy Health Checks

Daily automated checks:

```sql
-- Verify RLS enabled on critical tables
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = false;

-- Verify policies exist
SELECT COUNT(*) FROM pg_policies
WHERE schemaname = 'public';
```

Alerts triggered if:
- RLS disabled on any table
- Policy count changes unexpectedly
- New table created without RLS

### Access Violation Monitoring

Monitor PostgreSQL logs for:
- Permission denied errors (policy violations)
- Unusual access patterns
- Failed authentication attempts
- Break-glass access events

Alert thresholds:
- >10 permission denied errors per user per hour
- Break-glass access outside business hours
- Cross-site access attempts

### Quarterly Access Reviews

Every 90 days:
- Review all user role assignments
- Verify site assignments current
- Audit break-glass access logs
- Remove inactive user accounts
- Update access documentation

---

## References

- **Product Requirements**: prd-security-RLS.md
- **Development Implementation**: dev-security-RLS.md
- **Database Setup**: ops-database-setup.md
- **Security Operations**: ops-security.md
- **PostgreSQL RLS Documentation**: https://www.postgresql.org/docs/current/ddl-rowsecurity.html

---

## Revision History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-10-26 | Initial RLS operations requirements | Development Team |

---

**Document Classification**: Internal Use - Operations Procedures
**Review Frequency**: Quarterly or after security changes
**Owner**: Database Operations Team / Security Team
