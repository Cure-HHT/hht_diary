# Role-Based Access Control (RBAC) Specification

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-01-24

> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment architecture
> **See**: prd-security.md for overall security architecture
> **See**: ops-security.md for deployment procedures
> **See**: dev-database.md for RLS policy implementation

---

## Overview

Defines user roles, permissions, and access-scoping rules for the clinical trial application. Database implementation details are out of scope; this focuses on who can access what.

---

## Multi-Sponsor Context

**Sponsor Isolation**: Each sponsor has a dedicated Supabase instance (separate database + authentication system). Users, roles, and permissions are completely isolated per sponsor.

**Implications**:
- User accounts exist in only one sponsor's system
- Roles are scoped to single sponsor
- No cross-sponsor user access or data sharing
- Each sponsor independently manages their users and roles

**See**: prd-architecture-multi-sponsor.md for complete architecture

---

## Core Principles

### REQ-p00005: Role-Based Access Control

**Level**: PRD | **Implements**: - | **Status**: Active

The system SHALL enforce role-based access control (RBAC) ensuring users can only access data and perform actions appropriate to their assigned role.

RBAC implementation SHALL ensure:
- Users assigned one or more roles (Patient, Investigator, Sponsor, Auditor, Analyst, Administrator)
- Each role has specific, limited permissions
- Access decisions based on user's active role
- Role changes logged in audit trail
- Least privilege principle enforced

**Rationale**: Clinical trial data access must be tightly controlled to protect patient privacy, ensure data integrity, and comply with HIPAA and FDA regulations. RBAC provides systematic, auditable access control.

**Acceptance Criteria**:
- Users cannot access data outside their role permissions
- Role assignment changes require privileged account
- All data access includes role context in audit log
- System denies unauthorized access attempts
- Role permissions cannot be bypassed

---

### REQ-p00014: Least Privilege Access

**Level**: PRD | **Implements**: p00005, p00010 | **Status**: Active

Users SHALL be granted the minimum permissions necessary to perform their assigned job functions, with no user having access beyond their role requirements.

Least privilege SHALL ensure:
- Permissions granted based on specific job function
- Users cannot access data outside their assigned scope
- Administrative functions restricted to administrator roles
- Patient data access limited to assigned clinical sites (for staff roles)
- Elevated permissions require explicit justification and approval

**Rationale**: Minimizes risk of accidental or intentional data misuse. Supports RBAC (p00005) and FDA compliance (p00010) by ensuring users can only access data necessary for their clinical trial role. Reduces impact of compromised accounts.

**Acceptance Criteria**:
- Role permissions defined by job function, not user preference
- Users cannot elevate their own permissions
- Access requests outside normal permissions require approval workflow
- Unnecessary permissions removed promptly when job function changes
- Audit log captures all permission grant/revoke events

---

### RBAC Principles

- **Single Active Role Context**: A user with multiple roles must explicitly select a single role before performing any action. All actions are attributed to that role.
- **Explicit Scope Selection**: When a role spans multiple scopes (e.g., multiple sites), the user must select a single scope per session/view. No cross-site blended views.
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
3. Edge Functions for break-glass, alerts, scheduler
4. Skip heavy SIEM initially; add later if needed
5. De-identify by default (future-proofing); require justification for exports
6. Enforce single active Role + Site via token claims
7. Dev/Admin guardrails: no routine PHI; TTL-based elevation with ticket
8. Weekly automated audit digest email; set 7-year retention

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
