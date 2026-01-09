# Role-Based Access Control (RBAC) Specification

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-27

> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment architecture
> **See**: prd-security.md for overall security architecture
> **See**: ops-security.md for deployment procedures
> **See**: dev-database.md for RLS policy implementation

---

## Overview

Defines user roles, permissions, and access-scoping rules for the clinical trial application. Database implementation details are out of scope; this focuses on who can access what.

---

## Multi-Sponsor Context

**Sponsor Isolation**: Each sponsor has a dedicated GCP project (separate Cloud SQL database + Identity Platform authentication). Users, roles, and permissions are completely isolated per sponsor.

**Implications**:
- User accounts exist in only one sponsor's system
- Roles are scoped to single sponsor
- No cross-sponsor user access or data sharing
- Each sponsor independently manages their users and roles

**See**: prd-architecture-multi-sponsor.md for complete architecture

---

## Core Principles

# REQ-p00005: Role-Based Access Control

**Level**: PRD | **Status**: Draft | **Implements**: p00011

## Rationale

Clinical trial data access must be tightly controlled to protect patient privacy, ensure data integrity, and comply with HIPAA and FDA regulations. Role-Based Access Control (RBAC) provides systematic, auditable access control by assigning specific permissions to defined roles (Patient, Investigator, Sponsor, Auditor, Analyst, Administrator) and enforcing the principle of least privilege. This ensures that users can only access data and perform actions appropriate to their assigned role, with all role-related activities captured in the audit trail for regulatory compliance and security analysis.

## Assertions

A. The system SHALL enforce role-based access control (RBAC) ensuring users can only access data and perform actions appropriate to their assigned role.
B. The system SHALL support assignment of one or more roles to each user from the following set: Patient, Investigator, Sponsor, Auditor, Analyst, Administrator.
C. Each role SHALL have specific, limited permissions.
D. The system SHALL base access decisions on the user's active role.
E. The system SHALL log all role changes in the audit trail.
F. The system SHALL enforce the principle of least privilege.
G. The system SHALL NOT allow users to access data outside their role permissions.
H. The system SHALL require a privileged account to make role assignment changes.
I. The system SHALL include role context in the audit log for all data access events.
J. The system SHALL deny unauthorized access attempts.
K. The system SHALL NOT allow role permissions to be bypassed.

*End* *Role-Based Access Control* | **Hash**: 83122106
---

# REQ-p00014: Least Privilege Access

**Level**: PRD | **Status**: Draft | **Implements**: p00005, p00010

## Rationale

Least privilege access is a fundamental security principle that minimizes the risk of accidental or intentional data misuse in clinical trial systems. This requirement supports the role-based access control framework and FDA 21 CFR Part 11 compliance by ensuring users can only access data necessary for their specific clinical trial role. By limiting permissions to the minimum required for each job function, the system reduces the potential impact of compromised accounts, prevents unauthorized access to sensitive patient data, and maintains clear accountability for all data access activities. This approach is particularly critical in multi-site clinical trials where staff should only access data from their assigned clinical sites.

## Assertions

A. The system SHALL grant users the minimum permissions necessary to perform their assigned job functions.
B. The system SHALL NOT grant users access beyond their role requirements.
C. The system SHALL assign permissions based on specific job function rather than user preference.
D. The system SHALL prevent users from accessing data outside their assigned scope.
E. The system SHALL restrict administrative functions to administrator roles.
F. The system SHALL limit patient data access to assigned clinical sites for staff roles.
G. The system SHALL require explicit justification and approval for elevated permissions.
H. The system SHALL prevent users from elevating their own permissions.
I. The system SHALL require approval workflow for access requests outside normal permissions.
J. The system SHALL remove unnecessary permissions promptly when job function changes.
K. The system SHALL capture all permission grant events in the audit log.
L. The system SHALL capture all permission revoke events in the audit log.

*End* *Least Privilege Access* | **Hash**: 84b123a2
---

### RBAC Principles

- **Single Active Role Context**: A user with multiple roles must explicitly select a single role before performing any action. All actions are attributed to that role.
- **Explicit Scope Selection**: When a role spans multiple scopes (e.g., multiple sites), the user must select a single scope per session/view. No cross-site blended views.
- TODO - should site staff users also select a site (would they ever have access to more than one?)
- **Least Privilege**: Grant only what is necessary for job functions.
- **Separation of Duties**: Sensitive operations require distinct roles to reduce conflict of interest.
- **Auditability**: All access and administrative actions must be logged with role context and scope.
- **Transparency**: All non-patient user accounts contain the user's name (PII). All users can see their own audit trail and audit actions which modify their account or data.
- **Patient Privacy**: No patient PII is stored by this system.

---

## Roles & Permissions

### Patient
- **Permissions**: read/write self only
- **Scope**: Own data
- **Access Pattern**: Can only see and modify their own records

### Investigator
- **Permissions**: site-scoped read/write; must select one site at a time; enroll/de-enroll patients
- **Scope**: Assigned sites (one active at a time)
- **Access Pattern**: Read-only access to patient data, can add annotations

### Sponsor
- **Permissions**: de-identified only; can create/assign Investigators, Analysts and Auditors; read-only across all auth and elevation tickets
- **Scope**: Global (all sites)
- **Access Pattern**: Aggregate data, user management, oversight

### Auditor
- **Permissions**: read-only across study; export requires justification
- **Scope**: Global (all sites)
- **Access Pattern**: Compliance monitoring, audit trail review

### Analyst
- **Permissions**: site-scoped read/write; de-identified datasets only
- **Scope**: Assigned sites
- **Access Pattern**: Read-only data access for analysis

### Administrator
- **Permissions**: user/role/config; no PHI by default (use break-glass)
- **Scope**: Global system administration
- **Access Pattern**: System configuration, no routine PHI access

### Developer Admin
- **Permissions**: infrastructure ops; no routine PHI; can assign break-glass access with TTL to any user
- **Scope**: System infrastructure
- **Access Pattern**: DevOps, emergency access management

**Note**: "de-identified" is specified for future-proofing. The current system does not store any PII for patients.

---

## Auditing Requirements

- All authentication and database actions are logged
- Tamper-evident/proofing measures are in place for all Roles, even super-users

---

## Implementation Notes (DRAFT)

1. Use Postgres pgaudit
2. Keep audit in same DB (audit schema) + daily Storage checkpoint
3. Cloud functions for break-glass, alerts, scheduler
4. Skip heavy SIEM initially; add later if needed
5. De-identify by default (future-proofing); require justification for exports
6. Enforce single active Role + Site via token claims
7. Dev/Admin guardrails: no routine PHI; TTL-based elevation with ticket
8. Weekly automated audit digest email; set 7-year retention

TODO - email? 
TODO - what's 25 year and what's 7 year?

### Automated Digest

- **Frequency**: Weekly
- **Recipients**: All Admins, Sponsors
- **Study activity**:
  - New enrollment count, de-enrollment count, current # of patients by Site ID, total current patients, total non-active patients, total patients
- **Admin activity**:
  - User names and number of elevated-access tickets; (log in to see details)

---

## User Stories by Role

### Investigator User Stories

1. Access assigned site data (one active site at a time)
2. Enroll/withdraw patients
3. Review study documents
4. Open/respond to data queries
5. Message patients at the active site (if enabled)

### Patient User Stories

1. View personal profile and health info
2. Submit outcomes/questionnaires
3. Update contact details
4. Withdraw consent
5. View consent status

### Auditor User Stories

1. Read-only access across study with robust filtering
2. Export audit logs with justification and case ID
3. Validate compliance and RLS policies
4. Verify data integrity and chain of custody
5. File anomaly reports

### Analyst User Stories

1. Access de-identified datasets
2. Build reports/dashboards
3. Run predefined analyses
4. Share findings with sponsor/site leads
5. Track analysis provenance

### Sponsor User Stories

1. Create/approve investigator accounts
2. Assign investigators to sites
3. Review aggregate metrics and progress
4. Manage study milestones
5. View and edit trial configuration (non-PHI)

### Administrator User Stories

1. Provision/deprovision users
2. Assign roles and site scopes
3. Configure forms/feature flags
4. Monitor access logs and alerts
5. Handle support requests and incidents

---

## References

- **Database Implementation**: dev-database.md
- **Security Operations**: ops-security.md
- **Compliance Requirements**: prd-clinical-trials.md

---

**Source Files**:
- `prd-role-based-access-spec.md` (merged)
- `prd-role-based-user-stories.md` (merged)
