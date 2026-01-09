# Row-Level Security Implementation

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-10-26
**Status**: Draft

> **See**: prd-security-RLS.md for product requirements
> **See**: ops-security-RLS.md for deployment procedures
> **See**: dev-database.md for database schema details

---

## Executive Summary

This document specifies the implementation details for PostgreSQL Row-Level Security (RLS) policies that enforce access control at the database layer. Each policy is implemented as SQL functions and RLS policy definitions that validate user identity and permissions using JWT claims.

**Technology Stack**:
- PostgreSQL 15+ Row-Level Security
- Identity Platform (Identity Platform) with JWT-based authentication
- Application-set session variables for RLS context
- PL/pgSQL functions for claim extraction
- Migration scripts for deployment

---

## RLS Policy Implementation Requirements

# REQ-d00019: Patient Data Isolation RLS Implementation

**Level**: Dev | **Status**: Draft | **Implements**: o00020

## Rationale

This requirement implements patient data isolation at the database layer through PostgreSQL Row-Level Security (RLS) policies, fulfilling the operational requirement o00020. RLS provides defense-in-depth security by enforcing data isolation directly in the database, preventing patients from accessing each other's records even if application-layer authorization fails. The implementation extracts user identity and role from JWT claims passed through PostgreSQL session variables, ensuring that each patient can only view and create their own records. The event sourcing architecture eliminates the need for UPDATE/DELETE policies since records are immutable. This approach ensures ALCOA+ compliance by maintaining data integrity through database-enforced access controls rather than relying solely on application logic.

## Assertions

A. The system SHALL implement PostgreSQL RLS policies to enforce patient data isolation by filtering queries based on the authenticated user's patient ID from JWT claims.
B. The system SHALL provide a helper function current_user_id() that extracts the 'sub' claim from the JWT and returns it as a UUID.
C. The current_user_id() function SHALL return NULL when the JWT claim is not available.
D. The system SHALL provide a helper function current_user_role() that extracts the 'role' claim from the JWT and returns it as TEXT.
E. The current_user_role() function SHALL return 'anon' as the default value when the JWT role claim is not available.
F. The system SHALL enable Row-Level Security on the record_state table.
G. The system SHALL enable Row-Level Security on the record_audit table.
H. The system SHALL create an RLS policy on record_state that allows SELECT operations only when current_user_role() equals 'USER' and patient_id matches current_user_id().
I. The system SHALL create an RLS policy on record_audit that allows SELECT operations only when current_user_role() equals 'USER' and patient_id matches current_user_id().
J. The system SHALL create an RLS policy on record_audit that allows INSERT operations only when current_user_role() equals 'USER' and patient_id matches current_user_id().
K. The system SHALL NOT create UPDATE policies on record_state or record_audit tables.
L. The system SHALL NOT create DELETE policies on record_state or record_audit tables.
M. Patients SHALL be able to SELECT only records where patient_id matches their authenticated user ID.
N. Patients SHALL NOT be able to INSERT records with a patient_id different from their authenticated user ID.
O. RLS policy execution SHALL complete with less than 50ms overhead per query.

*End* *Patient Data Isolation RLS Implementation* | **Hash**: 51425522
---

# REQ-d00020: Investigator Site-Scoped RLS Implementation

**Level**: Dev | **Status**: Draft | **Implements**: o00021

## Rationale

This requirement implements site-scoped access control for investigators as specified in o00021. Row-level security (RLS) policies enforce that investigators can only access clinical data from sites to which they are actively assigned. The design uses a dedicated assignment table with an active flag to track site assignments, enabling immediate access revocation without losing historical assignment records. A composite index on the assignment table ensures that the RLS policy subqueries perform efficiently during data access operations. This approach maintains both security and auditability while meeting performance requirements for production clinical trial operations.

## Assertions

A. The system SHALL implement PostgreSQL RLS policies to restrict investigator access to data at their assigned sites through subquery validation against the site assignment table.
B. The system SHALL provide an investigator_site_assignments table with columns for investigator_id, site_id, and active status.
C. The investigator_site_assignments table SHALL reference auth.users(id) for investigator_id.
D. The investigator_site_assignments table SHALL reference sites(id) for site_id.
E. The investigator_site_assignments table SHALL enforce a unique constraint on the combination of investigator_id and site_id.
F. The system SHALL create a composite index on investigator_site_assignments for (investigator_id, active) where active is true.
G. The system SHALL implement RLS policies on clinical data tables using subqueries to the investigator_site_assignments table.
H. RLS policies SHALL apply to SELECT operations for the INVESTIGATOR role.
I. RLS policies SHALL restrict investigators to SELECT only records where site_id matches an active site assignment.
J. The system SHALL verify that site_id is IN the set of site_id values from investigator_site_assignments where investigator_id matches current_user_id() and active is true.
K. Setting active to false for a site assignment SHALL immediately revoke investigator access to that site's data.
L. The system SHALL apply RLS policies to the record_state table for investigators.
M. The system SHALL apply RLS policies to the record_audit table for investigators.
N. RLS policy subqueries SHALL execute in less than 100 milliseconds.
O. Database migrations implementing these policies SHALL include rollback scripts.

*End* *Investigator Site-Scoped RLS Implementation* | **Hash**: 75c2466d
---

# REQ-d00021: Investigator Annotation RLS Implementation

**Level**: Dev | **Status**: Draft | **Implements**: o00022

## Rationale

This requirement implements the technical infrastructure for investigator annotations as specified in REQ-o00022. Investigators need the ability to add notes and observations to patient records for review and monitoring purposes, but must not be able to alter the underlying clinical data collected by patients. This is accomplished through PostgreSQL Row-Level Security (RLS) policies that grant INSERT permissions on a dedicated annotations table while withholding UPDATE and DELETE policies on both the annotations and clinical data tables. This ensures data integrity and maintains the immutability of patient-entered clinical records, which is critical for FDA 21 CFR Part 11 compliance and ALCOA+ principles. The automatic population of investigator_id and timestamps via triggers prevents spoofing and ensures complete audit trails.

## Assertions

A. The system SHALL implement an investigator_annotations table containing id, record_id, site_id, investigator_id, annotation_text, and created_at columns.
B. The investigator_annotations table SHALL enable Row-Level Security (RLS).
C. The investigator_annotations.record_id column SHALL reference record_state(id) via foreign key constraint.
D. The investigator_annotations.site_id column SHALL reference sites(id) via foreign key constraint.
E. The investigator_annotations.investigator_id column SHALL reference auth.users(id) via foreign key constraint.
F. The system SHALL create an index on investigator_annotations(record_id).
G. The system SHALL create an index on investigator_annotations(investigator_id).
H. The system SHALL implement an INSERT policy on investigator_annotations that restricts access to users with INVESTIGATOR role.
I. The INSERT policy on investigator_annotations SHALL restrict inserts to sites where the investigator has active assignments in investigator_site_assignments.
J. The INSERT policy on investigator_annotations SHALL enforce that investigator_id matches current_user_id().
K. The system SHALL implement a SELECT policy on investigator_annotations that restricts access to users with INVESTIGATOR role.
L. The SELECT policy on investigator_annotations SHALL restrict reads to sites where the investigator has active assignments in investigator_site_assignments.
M. The system SHALL NOT implement UPDATE policies on investigator_annotations for the INVESTIGATOR role.
N. The system SHALL NOT implement DELETE policies on investigator_annotations for the INVESTIGATOR role.
O. The system SHALL NOT implement UPDATE policies on record_audit for the INVESTIGATOR role.
P. The system SHALL NOT implement DELETE policies on record_audit for the INVESTIGATOR role.
Q. The system SHALL NOT implement UPDATE policies on record_state for the INVESTIGATOR role.
R. The system SHALL NOT implement DELETE policies on record_state for the INVESTIGATOR role.
S. The system SHALL implement a trigger that automatically populates investigator_id with current_user_id() before INSERT on investigator_annotations.
T. The system SHALL implement a trigger that automatically populates created_at with now() before INSERT on investigator_annotations.

*End* *Investigator Annotation RLS Implementation* | **Hash**: c020fead
---

# REQ-d00022: Analyst Read-Only RLS Implementation

**Level**: Dev | **Status**: Draft | **Implements**: o00023

## Rationale

This requirement implements read-only data access for analysts reviewing de-identified clinical trial data at assigned sites, supporting the operational requirement o00023. Analysts need visibility into clinical data for their assigned sites without the ability to modify records, ensuring data integrity while enabling analysis and reporting functions. The implementation uses PostgreSQL Row-Level Security (RLS) to enforce site-scoped read-only access at the database level, complemented by query audit logging for compliance with FDA 21 CFR Part 11. The absence of write policies (INSERT, UPDATE, DELETE) inherently prevents data modification, while pgaudit extension provides tamper-evident logs of all analyst query activity. Site assignments mirror the investigator assignment structure to maintain consistent authorization patterns across roles. De-identification enforcement ensures patient privacy by restricting access to identity columns.

## Assertions

A. The system SHALL implement PostgreSQL RLS policies to provide analysts read-only access to de-identified clinical data at assigned sites.
B. The system SHALL create an analyst_site_assignments table that mirrors the investigator assignment structure.
C. The analyst_site_assignments table SHALL include columns for analyst_id, site_id, active status, assigned_at timestamp, and assigned_by user ID.
D. The analyst_site_assignments table SHALL enforce a UNIQUE constraint on the combination of analyst_id and site_id.
E. The system SHALL create an index on analyst_site_assignments(analyst_id, active) filtered to active assignments only.
F. The system SHALL implement SELECT-only RLS policies on clinical data tables for users with ANALYST role.
G. SELECT policies for ANALYST role SHALL scope data visibility to sites where the analyst has active assignments in analyst_site_assignments.
H. The system SHALL NOT implement INSERT policies for ANALYST role on clinical data tables.
I. The system SHALL NOT implement UPDATE policies for ANALYST role on clinical data tables.
J. The system SHALL NOT implement DELETE policies for ANALYST role on clinical data tables.
K. RLS policies for analysts SHALL use subqueries to analyst_site_assignments table for site-scoping enforcement.
L. The system SHALL enable PostgreSQL pgaudit extension for logging analyst queries.
M. The system SHALL configure pgaudit to log all SELECT operations performed by ANALYST role.
N. RLS policies SHALL enforce de-identification by preventing analyst access to patient identity columns.
O. Analysts SHALL be able to SELECT from clinical data tables at their assigned sites when policies are active.
P. Analysts SHALL NOT be able to INSERT any records into clinical data tables.
Q. Analysts SHALL NOT be able to UPDATE any records in clinical data tables.
R. Analysts SHALL NOT be able to DELETE any records from clinical data tables.
S. The system SHALL log all analyst SELECT queries via pgaudit for compliance auditing.
T. RLS policy query execution SHALL complete in less than 100ms when proper indexes are present.

*End* *Analyst Read-Only RLS Implementation* | **Hash**: 62c367e5
---

# REQ-d00023: Sponsor Global Access RLS Implementation

**Level**: Dev | **Status**: Draft | **Implements**: o00024

## Rationale

This requirement implements sponsor-level access control for FDA 21 CFR Part 11 compliant clinical trial systems. Sponsors need visibility across all sites in their trial for monitoring and regulatory reporting, but must not modify clinical data to maintain data integrity and ALCOA+ compliance. Administrative capabilities (user management, site configuration) are necessary for trial operations. Cross-sponsor isolation is achieved through separate database instances rather than RLS filtering, simplifying the security model while maintaining compliance. De-identification protects subject privacy in accordance with regulatory requirements.

## Assertions

A. The system SHALL implement PostgreSQL RLS policies providing SELECT access to all clinical data tables for users with SPONSOR role without site-based filtering.
B. The system SHALL NOT provide INSERT, UPDATE, or DELETE policies on clinical data tables for users with SPONSOR role.
C. The system SHALL implement RLS policies providing full CRUD (CREATE, READ, UPDATE, DELETE) access to the users table for users with SPONSOR role.
D. The system SHALL implement RLS policies providing full CRUD access to the sites table for users with SPONSOR role.
E. The system SHALL implement RLS policies providing full CRUD access to configuration tables for users with SPONSOR role.
F. The system SHALL implement RLS policies providing full CRUD access to the investigator_site_assignments table for users with SPONSOR role.
G. The system SHALL enforce sponsor isolation through separate database instances rather than through RLS policies.
H. The system SHALL enforce de-identification of data in SELECT policies for SPONSOR role access to clinical data.
I. The system SHALL log all administrative actions performed by users with SPONSOR role.
J. Administrative action logs SHALL include user_id, action_type, table_name, record_id, and timestamp for each logged action.
K. The system SHALL create audit log entries for INSERT operations on administrative tables performed by SPONSOR role users.
L. The system SHALL create audit log entries for UPDATE operations on administrative tables performed by SPONSOR role users.
M. The system SHALL create audit log entries for DELETE operations on administrative tables performed by SPONSOR role users.
N. The system SHALL prevent SPONSOR role users from accessing data belonging to other sponsors through database instance separation.

*End* *Sponsor Global Access RLS Implementation* | **Hash**: dba73524
---

# REQ-d00024: Auditor Compliance RLS Implementation

**Level**: Dev | **Status**: Draft | **Implements**: o00025

## Rationale

This requirement implements auditor compliance access controls mandated by REQ-o00025, ensuring FDA 21 CFR Part 11 compliance for regulatory inspections. Auditors require unrestricted read access to all clinical data and audit logs for compliance verification, but must not have the ability to modify records to maintain data integrity. All data exports must be justified and logged to create a tamper-evident audit trail of regulatory activities. The requirement supports quarterly access reviews and compliance reporting necessary for demonstrating ongoing regulatory adherence. Export controls ensure that data extraction events are documented with business justification, linking to specific compliance cases or investigations.

## Assertions

A. The system SHALL implement SELECT policies on all tables that grant unrestricted read access to users with AUDITOR role.
B. The system SHALL implement SELECT policies on the record_state table for users with AUDITOR role.
C. The system SHALL implement SELECT policies on the record_audit table for users with AUDITOR role.
D. The system SHALL implement SELECT policies on the auth.users table for users with AUDITOR role.
E. The system SHALL NOT implement write policies (INSERT, UPDATE, DELETE) for users with AUDITOR role on any table.
F. The system SHALL provide an auditor_export_log table that records auditor_id, export_timestamp, justification, case_id, table_name, record_count, and export_format.
G. The system SHALL provide an export_clinical_data function that accepts p_table_name, p_justification, p_case_id, and p_format parameters.
H. The export_clinical_data function SHALL validate that the current user has AUDITOR role before proceeding.
I. The export_clinical_data function SHALL reject export requests if the current user does not have AUDITOR role.
J. The export_clinical_data function SHALL require justification text with a minimum length of 10 characters.
K. The export_clinical_data function SHALL reject export requests if justification is NULL or less than 10 characters.
L. The export_clinical_data function SHALL require case ID text with a minimum length of 5 characters.
M. The export_clinical_data function SHALL reject export requests if case_id is NULL or less than 5 characters.
N. The export_clinical_data function SHALL log each export action to the auditor_export_log table before performing the export.
O. Each export log entry SHALL include the auditor's user ID, justification text, case ID, table name, record count, and export format.
P. The export_clinical_data function SHALL return the export_id and record_count for each successful export.
Q. The system SHALL provide a generate_access_review_report function that accepts p_start_date and p_end_date parameters.
R. The generate_access_review_report function SHALL return user_id, user_email, role, access_count, and last_access for each user.
S. The generate_access_review_report function SHALL include users with AUDITOR or ADMIN roles in the access review report.
T. The generate_access_review_report function SHALL count audit log entries within the specified date range for each user.
U. The generate_access_review_report function SHALL identify the most recent access timestamp for each user within the specified date range.
V. The generate_access_review_report function SHALL order results by access_count in descending order.

*End* *Auditor Compliance RLS Implementation* | **Hash**: c263fd32
---

# REQ-d00025: Administrator Break-Glass RLS Implementation

**Level**: Dev | **Status**: Draft | **Implements**: o00026

## Rationale

This requirement implements administrator access controls with break-glass authorization for protected health information (PHI) access, supporting REQ-o00026's administrator access audit trail needs. The break-glass pattern allows emergency PHI access by administrators while maintaining strict accountability through ticket-based justification, time-to-live (TTL) validation, and comprehensive logging. This approach balances operational necessity (emergency access) with FDA 21 CFR Part 11 compliance requirements for audit trails and access controls. The automatic cleanup mechanism prevents misuse of expired authorizations and ensures the system maintains a current security posture.

## Assertions

A. The system SHALL implement PostgreSQL RLS policies for administrator access with break-glass authorization for protected health information access.
B. The system SHALL validate break-glass authorizations by ticket ID and TTL.
C. The system SHALL provide full access policies for the ADMIN role on configuration tables.
D. The system SHALL maintain a break_glass_authorizations table storing admin_id, ticket_id, justification, granted_at, expires_at, granted_by, revoked_at, and revoked_by.
E. The system SHALL enforce that break-glass expiry timestamps are after grant timestamps.
F. The system SHALL enforce a maximum TTL of 24 hours for break-glass authorizations.
G. The system SHALL provide a break-glass validation function that checks ticket validity and TTL.
H. The system SHALL implement separate RLS policies for routine admin access versus break-glass PHI access.
I. The system SHALL allow administrators to modify configuration tables without break-glass authorization.
J. The system SHALL require valid break-glass authorization for administrator PHI access.
K. The system SHALL verify break-glass authorizations are not revoked before granting access.
L. The system SHALL verify break-glass authorizations have not expired before granting access.
M. The system SHALL log all break-glass access to PHI tables.
N. Break-glass access logs SHALL include admin_id, table_name, action, and timestamp.
O. The system SHALL automatically clean up expired break-glass sessions.
P. The system SHALL revoke expired break-glass authorizations by setting revoked_at to the current timestamp.
Q. The system SHALL NOT allow reuse of expired break-glass sessions.

*End* *Administrator Break-Glass RLS Implementation* | **Hash**: 93358063
---

# REQ-d00026: Event Sourcing State Protection RLS Implementation

**Level**: Dev | **Status**: Draft | **Implements**: o00027

## Rationale

This requirement implements event sourcing state protection by ensuring the record_state table cannot be modified directly by users or application code. Instead, all state changes must flow through the immutable event log (record_audit table), with a secure trigger function deriving state by replaying events. This pattern enforces the event log as the single source of truth, prevents state tampering, and supports FDA 21 CFR Part 11 compliance by maintaining tamper-evident audit trails. The absence of write policies combined with forced RLS enforcement creates a technical barrier against direct state manipulation, while the SECURITY DEFINER trigger provides the controlled mechanism for legitimate state updates derived from audited events.

## Assertions

A. The system SHALL enable Row Level Security on the record_state table.
B. The system SHALL NOT define INSERT policies on the record_state table.
C. The system SHALL NOT define UPDATE policies on the record_state table.
D. The system SHALL NOT define DELETE policies on the record_state table.
E. The system SHALL force Row Level Security enforcement on the record_state table even for the table owner.
F. The system SHALL provide a trigger function that updates record_state from record_audit events.
G. The trigger function SHALL execute with SECURITY DEFINER privilege.
H. The trigger function SHALL create initial state when a record_id is first encountered in record_audit.
I. The trigger function SHALL update existing state by merging event_data from new record_audit events.
J. The trigger function SHALL increment the version number in record_state with each event.
K. The trigger function SHALL update the updated_at timestamp in record_state to match the event_timestamp.
L. The system SHALL create an AFTER INSERT trigger on record_audit that invokes the state update function for each row.
M. The system SHALL provide a validation function that verifies state integrity by replaying events.
N. The validation function SHALL derive state by aggregating event_data in event_timestamp order.
O. The validation function SHALL compare derived state against actual record_state data.
P. The validation function SHALL return a boolean indicating whether derived state matches actual state.
Q. Direct INSERT attempts on record_state SHALL return permission denied.
R. Direct UPDATE attempts on record_state SHALL return permission denied.
S. Direct DELETE attempts on record_state SHALL return permission denied.
T. State updates SHALL occur exclusively through the record_audit trigger mechanism.

*End* *Event Sourcing State Protection RLS Implementation* | **Hash**: 46e9dc01
---

## Implementation Guidelines

### Migration Script Structure

Each RLS policy implementation MUST be deployed via versioned migration script:

```sql
-- Migration: 001_rls_patient_isolation.sql
-- IMPLEMENTS REQUIREMENTS: REQ-d00019
-- Description: Patient data isolation RLS policies

BEGIN;

-- Create helper functions
CREATE OR REPLACE FUNCTION current_user_id() ...

-- Enable RLS
ALTER TABLE record_state ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY patient_isolation_state ON record_state ...

-- Verify deployment
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'record_state'
    AND policyname = 'patient_isolation_state'
  ) THEN
    RAISE EXCEPTION 'Policy deployment failed';
  END IF;
END $$;

COMMIT;
```

### Rollback Script Structure

Each migration MUST include rollback script:

```sql
-- Rollback: 001_rollback.sql
-- Reverts: 001_rls_patient_isolation.sql

BEGIN;

DROP POLICY IF EXISTS patient_isolation_state ON record_state;
DROP FUNCTION IF EXISTS current_user_id();

COMMIT;
```

### Testing Requirements

Each RLS policy MUST include unit tests:

```sql
-- Test: test_patient_isolation.sql
-- Tests: REQ-d00019

-- Setup test data
INSERT INTO auth.users (id, email, role) VALUES
  ('user-1', 'patient1@example.com', 'USER'),
  ('user-2', 'patient2@example.com', 'USER');

-- Set JWT context for patient 1
SET request.jwt.claims = '{"sub": "user-1", "role": "USER"}';

-- Positive test: Can access own data
SELECT assert_equals(
  (SELECT COUNT(*) FROM record_state WHERE patient_id = 'user-1'),
  10,
  'Patient should see own records'
);

-- Negative test: Cannot access other patient data
SELECT assert_equals(
  (SELECT COUNT(*) FROM record_state WHERE patient_id = 'user-2'),
  0,
  'Patient should not see other records'
);
```

---

## Performance Considerations

### Index Strategy

RLS policies with subqueries require proper indexing:

```sql
-- For site assignment lookups
CREATE INDEX idx_investigator_active_sites
  ON investigator_site_assignments(investigator_id, active)
  WHERE active = true;

-- For patient lookups
CREATE INDEX idx_record_state_patient
  ON record_state(patient_id);

-- For site filtering
CREATE INDEX idx_record_state_site
  ON record_state(site_id);
```

### Query Plan Analysis

Monitor policy overhead:

```sql
-- Analyze query with RLS enabled
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM record_state WHERE site_id = 'test-site';

-- Expected overhead: <50ms for patient policies, <100ms for site policies
```

### Caching Strategies

Helper functions should be STABLE to enable caching:

```sql
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS UUID AS $$
  SELECT ...
$$ LANGUAGE SQL STABLE;  -- STABLE enables caching within query
```

---

## Security Considerations

### Service Role Bypass

Service role BYPASSES RLS policies. Use with extreme caution:

```sql
-- Service role can bypass RLS for system operations
-- Only use for:
-- - Trigger functions (SECURITY DEFINER)
-- - Background jobs
-- - Database migrations
```

### JWT Claim Validation

Always validate JWT claims exist before use:

```sql
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS UUID AS $$
  SELECT COALESCE(
    current_setting('request.jwt.claims', true)::json->>'sub',
    NULL  -- Return NULL if claim missing (policy will deny)
  )::UUID;
$$ LANGUAGE SQL STABLE;
```

### Policy Testing in Production

Never disable RLS in production:

```sql
-- NEVER do this in production:
-- ALTER TABLE record_state DISABLE ROW LEVEL SECURITY;

-- Instead, test policies in staging with real JWT tokens
```

---

## References

- **Product Requirements**: prd-security-RLS.md
- **Operations Procedures**: ops-security-RLS.md
- **Database Schema**: dev-database.md
- **PostgreSQL RLS Documentation**: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- **Cloud SQL Documentation**: https://cloud.google.com/sql/docs/postgres

---

## Revision History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-10-26 | Initial RLS implementation requirements | Development Team |

---

**Document Classification**: Internal Use - Development Specifications
**Review Frequency**: After security changes or schema modifications
**Owner**: Backend Engineering Team / Database Team
