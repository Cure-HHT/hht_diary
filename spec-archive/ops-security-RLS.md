# Row-Level Security Operations

**Version**: 1.0
**Audience**: Operations
**Last Updated**: 2025-10-26
**Status**: Draft

> **See**: prd-security-RLS.md for product requirements
> **See**: dev-security-RLS.md for implementation details
> **See**: ops-database-setup.md for database provisioning

---

## Executive Summary

This document defines operational procedures for deploying, configuring, and monitoring PostgreSQL Row-Level Security (RLS) policies that enforce access control requirements. Each sponsor's Cloud SQL instance requires RLS policies to be enabled and properly configured to ensure data isolation and regulatory compliance.

---

## RLS Policy Deployment Requirements

# REQ-o00020: Patient Data Isolation Policy Deployment

**Level**: Ops | **Status**: Draft | **Implements**: p00035

## Rationale

This requirement establishes operational procedures for deploying and maintaining PostgreSQL Row-Level Security (RLS) policies that enforce patient data isolation as specified in REQ-p00035. Database-level access controls ensure that patients can only view and modify their own clinical diary entries, preventing unauthorized cross-patient data access. These deployment procedures guarantee consistent policy application across all sponsor instances and ensure the security controls cannot be bypassed through elevated privileges or administrative roles. The requirement addresses both initial deployment and ongoing maintenance through migration scripts with rollback capabilities, testing requirements, and change management logging to maintain audit trails for regulatory compliance.

## Assertions

A. The system SHALL deploy PostgreSQL Row-Level Security policies to enforce patient data isolation.

B. RLS SHALL be enabled on the record_state table.

C. RLS SHALL be enabled on the record_audit table.

D. The system SHALL deploy a SELECT policy that filters records by patient_id matching current_user_id().

E. The system SHALL deploy an INSERT policy that validates patient_id matches the authenticated user.

F. RLS policies SHALL NOT be bypassable by the service role.

G. Policies SHALL be deployed via migration scripts.

H. Migration scripts SHALL include rollback capability.

I. Policy testing SHALL be executed before production deployment.

J. RLS SHALL be enabled on patient data tables in all sponsor databases.

K. The system SHALL ensure patients can query only their own records.

L. Cross-patient access attempts SHALL return empty results.

M. Policies SHALL survive database restores.

N. Policies SHALL survive database migrations.

O. Policy deployment SHALL be logged in the change management system.

*End* *Patient Data Isolation Policy Deployment* | **Hash**: 21abbb15
---

# REQ-o00021: Investigator Site-Scoped Access Policy Deployment

**Level**: Ops | **Status**: Draft | **Implements**: p00036

## Rationale

This requirement implements site-scoped access control (p00036) at the database level for multi-site clinical trials. Investigators must only access clinical data from their explicitly assigned sites to maintain data integrity and regulatory compliance. PostgreSQL Row-Level Security (RLS) provides database-level enforcement that cannot be bypassed by application logic, ensuring that site de-assignment immediately revokes access. The assignment table serves as the authoritative source for access decisions, with proper indexing to maintain query performance. Atomic deployment via migration scripts ensures the assignment infrastructure and policies are created together, preventing security gaps during deployment.

## Assertions

A. The system SHALL deploy PostgreSQL Row-Level Security policies that restrict investigator access to clinical data at their assigned sites only.

B. RLS policies on clinical data tables SHALL filter rows by site assignment.

C. The system SHALL create and maintain an investigator_site_assignments table.

D. The investigator_site_assignments table SHALL have proper indexes to support RLS policy queries.

E. RLS policies SHALL validate investigator site access using subqueries against the investigator_site_assignments table.

F. Site de-assignment SHALL immediately revoke investigator access to that site's data.

G. The application SHALL enforce a single active site context through session management.

H. Migration scripts SHALL create both the assignment tables and RLS policies.

I. The assignment table and RLS policies SHALL be deployed atomically via migration scripts.

J. Investigators SHALL NOT be able to access data from sites they are not assigned to.

*End* *Investigator Site-Scoped Access Policy Deployment* | **Hash**: 06f5f0f4
---

# REQ-o00022: Investigator Annotation Access Policy Deployment

**Level**: Ops | **Status**: Draft | **Implements**: p00037

## Rationale

This requirement ensures that investigators can add clinical annotations to patient records while maintaining the integrity of patient-entered data through database-level access controls. By implementing Row-Level Security policies at the PostgreSQL database layer, the system enforces separation of concerns between patient-reported clinical data (which must remain immutable) and investigator annotations (which provide clinical context). This implements the annotation restrictions defined in p00037 and prevents both accidental and intentional modification of patient diary entries, supporting FDA 21 CFR Part 11 data integrity requirements. Site-scoped access ensures investigators can only annotate records at their assigned clinical sites, maintaining proper data segregation in multi-site trials.

## Assertions

A. The system SHALL deploy an investigator_annotations table with Row-Level Security policies enabled.

B. The system SHALL implement an INSERT policy on the investigator_annotations table that allows site-scoped creation.

C. The system SHALL NOT provide UPDATE policies on the record_audit table for investigator roles.

D. The system SHALL NOT provide DELETE policies on the record_audit table for investigator roles.

E. The system SHALL NOT provide modification policies on the record_state table for investigator roles.

F. The investigator_annotations table schema SHALL include investigator identity columns.

G. The investigator_annotations table schema SHALL include timestamp columns.

H. The investigator_annotations table SHALL include foreign key constraints linking annotations to clinical records.

I. The system SHALL allow investigators to create annotations only at their assigned sites.

J. The system SHALL prevent investigators from modifying the record_state table.

K. The system SHALL prevent investigators from modifying the record_audit table.

L. The system SHALL reject annotation creation attempts on unassigned sites.

M. All annotation records SHALL include investigator ID.

N. All annotation records SHALL include timestamp.

O. The system SHALL prevent modification of patient diary entries by investigators.

*End* *Investigator Annotation Access Policy Deployment* | **Hash**: c758cd88
---

# REQ-o00023: Analyst Read-Only Access Policy Deployment

**Level**: Ops | **Status**: Draft | **Implements**: p00022

## Rationale

This requirement operationalizes the analyst read-only access control model by deploying PostgreSQL Row-Level Security (RLS) policies for FDA 21 CFR Part 11 compliance. Analysts need access to de-identified clinical data for their assigned sites to perform research and analysis tasks while maintaining data integrity and regulatory compliance. The RLS policy approach provides database-level enforcement that cannot be bypassed by application logic, ensuring defense-in-depth security. Site-scoping through the analyst_site_assignments table implements the principle of least privilege by restricting each analyst's view to only authorized sites. The absence of INSERT, UPDATE, and DELETE policies for the analyst role creates an inherent read-only restriction at the database level, making it impossible for analysts to modify data even if application-level controls were compromised. Query audit logging provides the tamper-evident trail required for regulatory compliance.

## Assertions

A. The system SHALL deploy PostgreSQL Row-Level Security policies to provide analysts read-only access to de-identified clinical data at their assigned sites.

B. The deployment SHALL include SELECT policies on clinical data tables for the analyst role.

C. The deployment SHALL include site-scoping via the analyst_site_assignments table.

D. The deployment SHALL NOT include INSERT policies for the analyst role.

E. The deployment SHALL NOT include UPDATE policies for the analyst role.

F. The deployment SHALL NOT include DELETE policies for the analyst role.

G. The system SHALL enable query audit logging for analyst access.

H. The analyst_site_assignments table SHALL contain mappings between sites and analysts.

I. The policies SHALL enforce de-identified data access only.

J. Analysts SHALL be able to SELECT from clinical data tables at their assigned sites.

K. Analysts SHALL NOT be able to INSERT any records.

L. Analysts SHALL NOT be able to UPDATE any records.

M. Analysts SHALL NOT be able to DELETE any records.

N. Site assignments SHALL restrict data visibility to assigned sites only.

O. All analyst queries SHALL be logged in the audit trail.

P. Patient identity SHALL NOT be accessible to the analyst role.

*End* *Analyst Read-Only Access Policy Deployment* | **Hash**: 98aa758b
---

# REQ-o00024: Sponsor Global Access Policy Deployment

**Level**: Ops | **Status**: Draft | **Implements**: p00023

## Rationale

This requirement defines the operational deployment of sponsor-level access controls for multi-site clinical trial oversight. It implements the product requirement for sponsor global access (REQ-p00023) through PostgreSQL Row-Level Security policies combined with GCP project-level isolation. The architecture ensures sponsors can monitor and analyze de-identified clinical data across all sites within their isolated database instance while preventing unauthorized modification of trial data. This supports regulatory compliance with FDA 21 CFR Part 11 requirements for data integrity and audit trails by separating read access for oversight from write access for clinical operations. Administrative functions such as user management and configuration remain under full sponsor control within their isolated environment, while the physical separation of sponsor databases through distinct GCP Cloud SQL projects provides defense-in-depth isolation.

## Assertions

A. The deployment SHALL include PostgreSQL Row-Level Security policies that provide the sponsor role with SELECT access to all clinical data tables across all sites within their isolated database instance.

B. The SELECT policies for clinical data tables SHALL NOT include site-based filtering for the sponsor role.

C. The deployment SHALL include RLS policies that prohibit INSERT, UPDATE, and DELETE operations on clinical data tables for the sponsor role.

D. The deployment SHALL include RLS policies that grant the sponsor role full access (SELECT, INSERT, UPDATE, DELETE) to user management tables.

E. The deployment SHALL include RLS policies that grant the sponsor role full access (SELECT, INSERT, UPDATE, DELETE) to configuration tables.

F. Sponsor isolation SHALL be enforced through separate GCP projects, with each sponsor database deployed on a dedicated Cloud SQL instance.

G. The RLS policies SHALL provide sponsor access to de-identified clinical data only.

H. The sponsor role SHALL NOT have INSERT, UPDATE, or DELETE policies defined on clinical data tables.

I. Cross-sponsor data access SHALL be prevented through physical database separation in distinct GCP projects.

*End* *Sponsor Global Access Policy Deployment* | **Hash**: a3f24a6b
---

# REQ-o00025: Auditor Compliance Access Policy Deployment

**Level**: Ops | **Status**: Draft | **Implements**: p00038

## Rationale

This requirement ensures proper deployment of database-level access controls for regulatory auditors conducting FDA 21 CFR Part 11 compliance monitoring. Auditors require comprehensive read-only access to all clinical trial data, audit logs, and system tables to verify data integrity, review audit trails, and validate compliance with regulatory requirements. The requirement implements the access policy defined in p00038, ensuring auditors can perform their oversight function without risk of data modification. Export logging with justification provides accountability for data removal from the system, while quarterly access reviews ensure ongoing compliance with least-privilege principles. The separation of export activity into a dedicated audit table enables monitoring of auditor actions for security and compliance purposes.

## Assertions

A. The system SHALL deploy PostgreSQL Row-Level Security policies that provide auditors read-only access to all data including audit logs.

B. The system SHALL deploy SELECT policies on all tables for the auditor role without access restrictions.

C. The system SHALL NOT deploy INSERT, UPDATE, or DELETE policies for the auditor role.

D. The system SHALL deploy an export logging function that captures justification and case ID for all data exports.

E. The system SHALL provide quarterly access review procedures documented for auditor accounts.

F. RLS policies SHALL cover clinical data, audit logs, and system tables.

G. Export activity SHALL be tracked in a separate audit table.

H. Auditors SHALL be able to SELECT from all tables across all sites.

I. Auditors SHALL NOT be able to modify any records.

J. Data export functions SHALL require a justification parameter.

K. Export actions SHALL be logged with auditor identity and case ID.

L. Data export actions SHALL be logged with justification provided by the auditor.

*End* *Auditor Compliance Access Policy Deployment* | **Hash**: de3aa240
---

# REQ-o00026: Administrator Access Policy Deployment

**Level**: Ops | **Status**: Draft | **Implements**: p00039

## Rationale

This requirement operationalizes administrator access controls defined in p00039 by specifying how PostgreSQL Row-Level Security policies must be deployed and managed. The break-glass mechanism balances operational needs for emergency PHI access against regulatory requirements for accountability and audit trails. Time-limited authorizations with ticket tracking ensure that elevated access is both justified and traceable, supporting FDA 21 CFR Part 11 compliance and HIPAA security rule requirements. Quarterly reviews provide ongoing governance and help detect unauthorized access patterns.

## Assertions

A. PostgreSQL Row-Level Security policies SHALL be deployed for administrator access with comprehensive logging.

B. PostgreSQL Row-Level Security policies SHALL be deployed with break-glass access controls for protected health information.

C. The system SHALL deploy full access policies for the administrator role on all tables.

D. The system SHALL deploy a break-glass access logging function for PHI access.

E. The break-glass mechanism SHALL validate ticket ID for each break-glass session.

F. The break-glass mechanism SHALL validate time-to-live (TTL) for each break-glass session.

G. The system SHALL maintain separate policies for routine admin access and break-glass access.

H. Quarterly access review procedures SHALL be established for administrator access.

I. The system SHALL log justification for all administrative actions.

J. Administrators SHALL be able to modify configuration tables.

K. Administrators SHALL be able to modify user tables.

L. PHI access SHALL require explicit break-glass authorization.

M. Break-glass sessions SHALL include a ticket ID.

N. Break-glass sessions SHALL include a time-to-live (TTL).

O. All admin actions SHALL be logged with administrator identity.

P. All admin actions SHALL be logged with justification.

Q. Access reviews SHALL be conducted quarterly.

*End* *Administrator Access Policy Deployment* | **Hash**: bd4a9530
---

# REQ-o00027: Event Sourcing State Protection Policy Deployment

**Level**: Ops | **Status**: Draft | **Implements**: p00040

## Rationale

This requirement ensures the deployment of PostgreSQL Row-Level Security (RLS) policies that protect the event sourcing architecture at the database level. By implementing event sourcing state protection (p00040), the system ensures that the audit trail serves as the single source of truth. The architecture relies on deliberately omitting write policies on the record_state table, making direct state modification impossible and forcing all changes to flow through the immutable event log in the record_audit table. Database triggers then derive the current state from the event log, maintaining data integrity through architectural constraints rather than application-level enforcement. This approach provides tamper-evident audit trails required for FDA 21 CFR Part 11 compliance.

## Assertions

A. The system SHALL deploy PostgreSQL Row-Level Security policies that prevent direct modification of the record_state table.

B. The system SHALL NOT create INSERT policies on the record_state table.

C. The system SHALL NOT create UPDATE policies on the record_state table.

D. The system SHALL NOT create DELETE policies on the record_state table.

E. The system SHALL direct all write operations to the record_audit table.

F. The system SHALL deploy database triggers that update record_state from events in the record_audit table.

G. Trigger functions SHALL be secured with SECURITY DEFINER.

H. The system SHALL enforce event log immutability through append-only policies.

I. State derivation logic SHALL be tested for correctness prior to deployment.

J. Direct modification attempts on record_state SHALL return permission denied errors.

K. The system SHALL maintain event sourcing integrity at the database level.

*End* *Event Sourcing State Protection Policy Deployment* | **Hash**: bd5a22c4
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
