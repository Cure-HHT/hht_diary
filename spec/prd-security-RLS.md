# Row-Level Security (RLS) Specification

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-27
**Status**: Draft

> **See**: prd-security.md for overall security architecture
> **See**: prd-security-RBAC.md for role-based access control
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture
> **See**: ops-security.md for RLS deployment and monitoring

---

## Executive Summary
TODO - this violates the "No tech in PRDs", is that OK or should this be a dev- doc?

Row-Level Security (RLS) provides **database-level enforcement** of access control policies. RLS policies are implemented in PostgreSQL and enforced by Cloud SQL, ensuring that application code cannot bypass data access restrictions.

**Key Principles**:

- **Database-enforced**: Cannot be bypassed by application
- **Role-based**: Policies tied to user roles in JWT
- **Site-scoped**: Investigators and analysts limited to assigned sites
- **User-isolated**: Patients can only access own data
- **Multi-sponsor safe**: Each sponsor has separate GCP project with isolated Cloud SQL instance

---

## Multi-Sponsor RLS Architecture

### Sponsor-Level Isolation

Each sponsor operates a **separate GCP project with isolated Cloud SQL instance**, providing infrastructure-level isolation:

```
Sponsor A                          Sponsor B
                                                             
  GCP Project A                GCP Project B       
                                                             
  Cloud SQL with RLS               Cloud SQL with RLS      
     sponsor_a_data                    sponsor_b_data        
     RLS policies                      RLS policies          
     JWT validation                    JWT validation        
                                                             
```

**Isolation Guarantees**:

- Separate databases = impossible cross-sponsor data access
- RLS policies within each sponsor's database
- JWT tokens scoped to single sponsor
- No shared authentication system

---

## RLS Enforcement Model

# REQ-p00015: Database-Level Access Enforcement

**Level**: PRD | **Status**: Draft | **Refines**: p00005-A+G, p00014-D

## Rationale

Application-level access control can be bypassed through SQL injection, API manipulation, or compromised application code. Database-level enforcement using Row-Level Security (RLS) provides defense-in-depth protection, ensuring that role-based access control (REQ-p00005) and least privilege principles (REQ-p00014) cannot be circumvented even when application layers are compromised. This architectural pattern aligns with FDA 21 CFR Part 11 requirements for preventing unauthorized access to electronic records by placing the enforcement mechanism at the most trusted layer of the system architecture.

## Assertions

A. The system SHALL enforce all access control policies at the database layer.

B. The database SHALL filter all data queries based on the authenticated user's identity and role.

C. The database SHALL evaluate access policies independently of application code.

D. The database SHALL prevent application code from disabling or bypassing access policies.

E. The database SHALL enforce access policies for SELECT operations.

F. The database SHALL enforce access policies for INSERT operations.

G. The database SHALL enforce access policies for UPDATE operations.

H. The database SHALL enforce access policies for DELETE operations.

I. The database SHALL log all failed access attempts.

J. The database SHALL prevent users from querying data outside their assigned permissions regardless of how the query is initiated.

K. The database SHALL enforce access policies for direct database connections when such access is granted.

L. The database SHALL log all policy violations to the audit trail.

*End* *Database-Level Access Enforcement* | **Hash**: e0b19391
---

### How RLS Works

**Request Flow**:
```
1. User authenticates → Receives JWT from Cloud Identity Platform
2. JWT contains claims: {sub: "user-id", role: "INVESTIGATOR|PATIENT|ANALYST|SPONSOR|AUDITOR", ...}
3. User runs SQL against the database → Cloud Run validates JWT
4. PostgreSQL RLS policies filter results based on JWT claims
5. Only authorized rows returned to application
```

**Key Features**:

- Automatic filtering of SELECT, INSERT, UPDATE, DELETE
- Policies evaluated for every query
- Cannot be disabled by application code
- Transparent to application (uses standard SQL)
- Performance optimized by PostgreSQL query planner

---

## Core RLS Policies

# REQ-p00035: Patient Data Isolation

**Level**: PRD | **Status**: Draft | **Refines**: p00005-A+G, p00014-A+D

## Rationale

This requirement protects patient privacy and supports HIPAA compliance by ensuring complete data isolation between patients. As required by RBAC (p00005) and least privilege (p00014), enforcement occurs at the data layer rather than application layer alone, preventing bypass through application bugs, API manipulation, or UI vulnerabilities. This architectural decision ensures that even compromised application code cannot violate patient data boundaries, which is critical for maintaining patient trust and regulatory compliance.

## Assertions

A. The system SHALL restrict each patient to accessing only their own clinical diary entries.

B. The system SHALL restrict each patient to viewing only their own health information.

C. The system SHALL prevent patients from viewing any other patient's data.

D. The system SHALL allow patients to create diary entries only when attributed to themselves.

E. The system SHALL prevent patients from creating entries attributed to other patients.

F. The system SHALL prevent patients from updating entries attributed to other patients.

G. The system SHALL prevent patients from deleting entries attributed to other patients.

H. The system SHALL enforce patient data access restrictions at the data layer.

I. The system SHALL verify patient identity at the data access layer before granting access to any patient data.

J. The system SHALL return empty results when a patient attempts to access another patient's data.

K. The system SHALL NOT return error messages that could reveal the existence of other patients' data.

L. Access controls SHALL NOT be bypassable through application code.

*End* *Patient Data Isolation* | **Hash**: d519a005
---

# REQ-p00036: Investigator Site-Scoped Access

**Level**: PRD | **Status**: Draft | **Refines**: p00005-A+D, p00014-D+F, p00018-E+L

## Rationale

This requirement implements multi-site support with proper access control for clinical investigators. In multi-center trials, investigators at one hospital must not view another hospital's patient data, maintaining data integrity and regulatory compliance. Site-level data isolation ensures that investigators can only access clinical data from sites where they are actively assigned, with automatic access revocation when site assignments change. This prevents unauthorized cross-site data access and supports the principle of least privilege required by FDA 21 CFR Part 11.

## Assertions

A. The system SHALL limit investigator read access to clinical data from their assigned sites only.

B. The system SHALL automatically revoke an investigator's access to a site's data immediately upon removal from that site assignment.

C. The system SHALL require investigators to select exactly one active site per session.

D. The system SHALL validate site assignments at the data access layer before returning any clinical data.

E. The system SHALL return a 401 unauthorized error when an investigator attempts to access data from an unassigned site.

F. Investigators SHALL NOT be permitted to create, update, or delete any data except for creating annotations.

G. Site assignments SHALL determine the complete scope of data visibility for each investigator.

*End* *Investigator Site-Scoped Access* | **Hash**: 8cba2876
---

# REQ-p00037: Investigator Annotation Restrictions

**Level**: PRD | **Status**: Draft | **Refines**: p00005-A+C, p00014-A

## Rationale

This requirement maintains data integrity by preventing investigators from altering patient-reported outcomes, which is critical for regulatory compliance and scientific validity. Role-Based Access Control (REQ-p00005) and least privilege principles (REQ-p00014) dictate that investigators should have read-only access to patient-entered data while retaining the ability to add clinical annotations for their professional assessments. FDA 21 CFR Part 11 mandates clear attribution of data entry, requiring that patient data and investigator annotations be distinguishable with complete audit trails. This separation ensures that patient-reported outcomes remain unaltered while allowing clinical staff to document their observations and interpretations.

## Assertions

A. The system SHALL permit investigators to create annotations on patient records at their assigned sites.

B. The system SHALL NOT permit investigators to modify patient-entered data.

C. The system SHALL NOT permit investigators to create patient diary entries.

D. The system SHALL NOT permit investigators to modify patient diary entries.

E. The system SHALL NOT permit investigators to delete patient diary entries.

F. The system SHALL NOT permit investigators to alter clinical data records.

G. The system SHALL NOT permit investigators to alter audit trail records.

H. The system SHALL store annotations separately from patient-entered data.

I. Annotation records SHALL include the investigator's identity.

J. Annotation records SHALL include a timestamp of when the annotation was created.

*End* *Investigator Annotation Restrictions* | **Hash**: 18789c92
---

# REQ-p00022: Analyst Read-Only Access

**Level**: PRD | **Status**: Draft | **Refines**: p00005-A+F, p00014-A+D, p00018-E+G

## Rationale

Analysts need to review clinical data for analysis but must not alter records, adhering to the principle of least privilege (p00014) and role-based access control (p00005). Read-only access prevents accidental or intentional data modification while supporting analytical activities. Site-scoping (p00018) limits exposure to only data the analyst is authorized to analyze, and de-identification protects patient privacy. This requirement ensures analysts can perform their duties without compromising data integrity or regulatory compliance.

## Assertions

A. The system SHALL grant analysts read-only access to clinical data at their assigned sites.

B. The system SHALL restrict analyst access to de-identified data only.

C. The system SHALL NOT allow analysts to create any records.

D. The system SHALL NOT allow analysts to modify any records.

E. The system SHALL NOT allow analysts to delete any records.

F. The system SHALL enforce read-only access restrictions at the data layer.

G. The system SHALL scope analyst data visibility to their assigned sites only.

H. The system SHALL grant analysts the ability to view audit history for their assigned sites.

I. The system SHALL log all analyst data access events in the audit trail.

*End* *Analyst Read-Only Access* | **Hash**: f6c37670
---

# REQ-p00023: Sponsor Global Data Access

**Level**: PRD | **Status**: Draft | **Refines**: p00005-A+D, p00014-A

## Rationale

Sponsors need oversight of entire clinical trial across all sites to enable trial-wide analysis and monitoring, while maintaining data integrity through read-only restrictions on clinical records. This requirement balances sponsors' need for comprehensive trial visibility with the principle of least privilege, ensuring patient-entered data cannot be altered. Sponsor isolation via separate system instances prevents cross-sponsor data access, supporting multi-tenant deployment models. The read-only restriction on clinical data protects the integrity of patient-entered records while allowing sponsors to perform administrative functions necessary for trial management.

## Assertions

A. The system SHALL grant sponsors read access to de-identified clinical data across all sites within their sponsor instance.

B. The system SHALL NOT allow sponsors to modify patient-entered clinical data.

C. The system SHALL NOT restrict sponsor access to data from any site within their sponsor instance.

D. The system SHALL allow sponsors to manage user accounts within their sponsor instance.

E. The system SHALL allow sponsors to manage site configurations within their sponsor instance.

F. The system SHALL maintain multi-sponsor isolation by deploying separate system instances for each sponsor.

G. The system SHALL provide sponsors access only to de-identified data.

H. The system SHALL NOT grant sponsors access to data from other sponsors' instances.

I. The system SHALL enforce read-only access to clinical data at the data layer.

J. The system SHALL NOT allow sponsors to modify audit records.

*End* *Sponsor Global Data Access* | **Hash**: de7caa72
---

# REQ-p00038: Auditor Compliance Access

**Level**: PRD | **Status**: Draft | **Refines**: p00005-A+I

## Rationale

This requirement supports FDA 21 CFR Part 11 compliance verification and regulatory audit readiness. Auditors serve as independent validators of data integrity, system controls, and procedural compliance across the entire clinical trial. The global read-only access model enables comprehensive oversight without compromising data integrity. Export justification and logging requirements create a transparent audit trail of all auditor activities, ensuring accountability while facilitating their compliance monitoring role. Regular access reviews ensure that auditor permissions remain appropriate and aligned with current organizational needs.

## Assertions

A. The system SHALL grant auditor role read-only access to all clinical data across all sites in the study.

B. The system SHALL grant auditor role read-only access to all audit logs across all sites in the study.

C. The system SHALL prevent auditors from creating any records.

D. The system SHALL prevent auditors from modifying any records.

E. The system SHALL prevent auditors from deleting any records.

F. The system SHALL require a justification text field for all data export actions initiated by auditors.

G. The system SHALL NOT permit data export actions by auditors unless justification text is provided.

H. The system SHALL log all auditor data export actions with the auditor identity.

I. The system SHALL log all auditor data export actions with the case ID of exported data.

J. The system SHALL log all auditor data export actions with a timestamp.

K. The system SHALL enforce quarterly access reviews for all auditor accounts.

*End* *Auditor Compliance Access* | **Hash**: b5c84953
---

# REQ-p00039: Administrator Access with Audit Trail

**Level**: PRD | **Status**: Draft | **Refines**: p00005-A+E+H

## Rationale

Administrators require comprehensive system access to perform configuration and support tasks while maintaining FDA 21 CFR Part 11 compliance through detailed audit trails. The break-glass mechanism provides a controlled pathway for emergency access to protected health information (PHI) when urgent clinical or operational needs arise, balancing operational necessity with regulatory accountability. Regular access excludes PHI to enforce the principle of least privilege, ensuring administrators only access sensitive data when explicitly authorized with time-bounded, justified credentials. Quarterly reviews ensure ongoing compliance with role-based access control policies and detect any access anomalies or unauthorized privilege escalation.

## Assertions

A. The system SHALL grant administrators the ability to modify system configuration settings.

B. The system SHALL grant administrators the ability to create, modify, and deactivate user accounts.

C. The system SHALL log all administrative actions with the administrator's identity.

D. The system SHALL require administrators to provide justification for administrative actions that is captured in the audit log.

E. The system SHALL exclude protected health information (PHI) from regular administrator access privileges.

F. The system SHALL require a valid ticket ID to authorize break-glass access to PHI.

G. The system SHALL require a time-to-live (TTL) value for break-glass access authorizations.

H. The system SHALL enforce the time-to-live limitation on break-glass access, revoking access automatically when the TTL expires.

I. The system SHALL log break-glass access events with administrator identity, ticket ID, TTL, and timestamp.

J. The system SHALL conduct access reviews for all administrator accounts on a quarterly basis.

K. The system SHALL record the results of quarterly access reviews in the audit trail.

*End* *Administrator Access with Audit Trail* | **Hash**: 5082758c
---

# REQ-p00040: Event Sourcing State Protection

**Level**: PRD | **Status**: Draft | **Refines**: p00004-A+B+C+L

## Rationale

Event sourcing architecture requires an immutable audit trail where all data changes are captured as events, with clinical data state derived from those events. This pattern ensures FDA 21 CFR Part 11 compliance by establishing the audit trail as the single source of truth for all clinical data modifications. Database-level enforcement mechanisms prevent unauthorized direct modification of derived state, ensuring that no changes can bypass the event log regardless of user privileges. This architectural constraint maintains data integrity and creates a tamper-evident record required for regulatory compliance in clinical trials.

## Assertions

A. The system SHALL prohibit direct modification of derived clinical data state.

B. The system SHALL prohibit direct modification of derived clinical data state by administrators.

C. The system SHALL require all clinical data changes to be written as events to the audit trail.

E. The system SHALL maintain event sourcing integrity at the data layer.

F. The system SHALL prevent tampering with derived state through access controls.

G. The system SHALL return permission denied for any attempts to directly modify derived state.

H. The system SHALL enforce the event sourcing pattern at the data layer.

*End* *Event Sourcing State Protection* | **Hash**: 2067e3e6
---

### Policy Implementation Details

The following sections describe how the above requirements are implemented through PostgreSQL Row-Level Security policies.

#### Policy 1: Patient Data Isolation (Implements REQ-p00035)

**Requirement**: Patients can only access their own diary entries.

**RLS Policy**:

**Enforcement**:

- `current_user_id()` returns user ID from JWT claim (`sub`)
- `current_user_role()` returns role from JWT claim (`role`)
- Patient cannot query other patients' data (query returns empty)
- Patient cannot insert data for other patients (INSERT fails)

---

#### Policy 2: Investigator Site-Scoped Access (Implements REQ-p00036)

**Requirement**: Investigators can view data only at their assigned sites.

**RLS Policy**:

**Enforcement**:

- Subquery checks `investigator_site_assignments` table
- Only sites where investigator is actively assigned
- If investigator de-assigned from site, access immediately revoked
- Cannot query data from unassigned sites

**Single Active Site Context**:

- Investigators must select one active site per session
- Application stores `active_site_id` in session state
- Queries filter by `site_id = active_site_id`
- RLS policy ensures site_id is in allowed list

---

#### Policy 3: Investigator Annotation Permissions (Implements REQ-p00037)

**Requirement**: Investigators can add annotations at assigned sites but cannot modify patient data.

**RLS Policy**:

**Enforcement**:

- Can INSERT into `investigator_annotations` table
- Cannot INSERT into `record_audit` with patient data
- Cannot UPDATE `record_state` (no policy = permission denied)
- All annotations logged with investigator ID

---

#### Policy 4: Analyst Read-Only Access (Implements REQ-p00022)

**Requirement**: Analysts have read-only access to de-identified data at assigned sites.

**RLS Policy**:

**Enforcement**:

- Can SELECT from `record_state` and `record_audit`
- Cannot INSERT, UPDATE, or DELETE (no policies = denied)
- Site-scoped via `analyst_site_assignments`
- All queries logged in audit trail

---

#### Policy 5: Sponsor Global Access (Implements REQ-p00023)

**Requirement**: Sponsors can view de-identified data across all sites within their sponsor instance.

**RLS Policy**:

**Enforcement**:

- No site restriction (sponsor sees all sites in their GCP project)
- Cannot modify patient data (no INSERT/UPDATE policies)
- Can manage users (separate policies on user management tables)
- Multi-sponsor isolation via separate GCP projects

---

#### Policy 6: Auditor Read-Only Global Access (Implements REQ-p00038)

**Requirement**: Auditors have read-only access across entire study for compliance monitoring.

**RLS Policy**:

**Enforcement**:

- Global SELECT access to all tables
- No INSERT/UPDATE/DELETE permissions
- All data export actions must be justified and logged
- Access reviews quarterly

---

#### Policy 7: Administrator Access with Logging (Implements REQ-p00039)

**Requirement**: Administrators have full access but all actions are logged.

**RLS Policy**:

**Enforcement**:

- Full access to all data
- All actions logged with justification
- Break-glass access for PHI requires TTL and ticket
- Regular access reviews

---

#### Policy 8: State Protection (Implements REQ-p00040)

**Requirement**: record_state table cannot be directly modified (Event Sourcing pattern).

**Implementation**:

**Enforcement**:

- Direct modification of `record_state` blocked (no policies)
- All changes via `record_audit` table
- Triggers automatically update `record_state`
- Maintains Event Sourcing integrity

---

## Helper Functions for RLS

### current_user_id()

Returns user ID from JWT token.


### current_user_role()

Returns role from JWT custom claims.

TODO
### current_user_site()

Returns site from JWT custom claims.

**Note**: Custom claims added to JWT via Cloud Identity Platform custom claims.

---

## RLS Policy Matrix

| Role | record_state | record_audit | annotations | sites | users |
| --- | --- | --- | --- | --- | --- |
| **USER** | SELECT own<br>INSERT via audit | INSERT own | - | - | SELECT own |
| **INVESTIGATOR** | SELECT site | SELECT site | INSERT site | SELECT site | SELECT site |
| **ANALYST** | SELECT site | SELECT site | - | SELECT site | SELECT site |
| **SPONSOR** | SELECT all | SELECT all | - | ALL | ALL |
| **AUDITOR** | SELECT all | SELECT all | SELECT all | SELECT all | SELECT all |
| **ADMIN** | ALL | ALL | ALL | ALL | ALL |

Legend:

- **SELECT own**: User can only see their own data
- **SELECT site**: User can see data at assigned sites
- **SELECT all**: User can see all data in sponsor's database
- **INSERT site**: User can insert at assigned sites
- **ALL**: Full CRUD access

---

## RLS Performance Optimization

### Indexes for RLS Policies

**Critical Indexes**:

### Query Plan Analysis

**Monitor RLS performance**:

---

## Testing RLS Policies

### Test Methodology

**1. Positive Tests** (should succeed):

**2. Negative Tests** (should fail/return empty):

**3. Cross-Role Tests**:

### Automated RLS Tests

**Test Suite** (run on deployment):

**See**: ops-security.md for deployment test procedures

---

## RLS Monitoring & Alerting

### Daily Checks


### Security Alerts

**Alert Conditions**:
1. RLS disabled on any table (critical)
2. New table created without RLS (critical)
3. Policy modification (warning - log for review)
4. Failed permission attempts spike (warning)

**See**: ops-security.md for monitoring setup

---

## Common RLS Scenarios

### Scenario 1: Patient Views Own Diary


### Scenario 2: Investigator Reviews Site Data


### Scenario 3: Analyst Exports Data


### Scenario 4: Admin Emergency Access


---

## RLS Limitations & Workarounds

### Limitation 1: Performance on Large Tables

**Issue**: RLS policies add WHERE clauses to every query.

**Mitigation**:

- Proper indexing on filter columns
- Materialized views for common queries
- Partition tables by site_id if very large

### Limitation 2: Complex Policy Logic

**Issue**: Subqueries in RLS policies can be slow.

**Mitigation**:

- Denormalize site assignments if needed
- Cache policy evaluation results (PostgreSQL does this)
- Use SECURITY DEFINER functions for complex checks

### Limitation 3: Debugging Access Issues

**Issue**: Hard to debug why query returns empty.

**Mitigation**:

- Log JWT claims in application
- Test policies in development with SET request.jwt.claims
- Use EXPLAIN to see policy evaluation

---

## Security Considerations

### RLS Cannot Prevent

- L Application bugs that leak data
- L SQL injection (still need parameterized queries)
- L Compromised service role key (bypasses RLS)
- L Physical database access (encryption at rest needed)

### RLS Does Prevent

-   Application code bypassing access control
-   Unauthorized data access via API
-   Horizontal privilege escalation
-   Accidental data exposure from bugs

**Defense in Depth**: RLS is one layer; combine with application security, encryption, monitoring.

---


## Compliance

RLS policies support regulatory compliance by enforcing access control at the database level.

**See**: prd-clinical-trials.md for FDA 21 CFR Part 11, HIPAA, and GDPR compliance requirements and how RLS contributes to meeting them.
---

## References

- **Security Overview**: prd-security.md
- **Role Definitions**: prd-security-RBAC.md
- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Database Architecture**: prd-database.md
- **Security Operations**: ops-security.md
- **PostgreSQL RLS Docs**: https://www.postgresql.org/docs/current/ddl-rowsecurity.html
- **Cloud SQL Security**: https://cloud.google.com/sql/docs/postgres/configure-ssl-instance

---

## Revision History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-01-24 | Initial RLS specification | Development Team |

---

**Document Classification**: Internal Use - Security Specification
**Review Frequency**: Quarterly or after security changes
**Owner**: Security Team / Database Architect
