# Clinical Trial Web Portal

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-10-27
**Status**: Draft

> **See**: ops-portal.md for deployment and operations procedures
> **See**: dev-portal.md for implementation details
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture (REQ-p00009)
> **See**: prd-security-RBAC.md for role-based access control
> **See**: prd-database.md for data architecture

---

## Executive Summary

The Clinical Trial Web Portal is a sponsor-specific web application that enables clinical trial staff (Admins, Investigators, and Auditors) to manage users, enroll patients, monitor patient engagement, manage questionnaires, and access audit trails. Each sponsor receives their own isolated portal instance with customized branding and data access limited to that sponsor's trials only.

**Key Benefits**:
- **Centralized Management**: Single interface for all administrative and investigator tasks
- **Real-Time Monitoring**: Track patient engagement and data entry activity
- **Sponsor Isolation**: Each sponsor's portal completely isolated from others
- **Role-Based Access**: Admins, Investigators, and Auditors have appropriate permissions
- **Compliance Ready**: Full audit trail and regulatory compliance support

---

## How It Works

# REQ-p00024: Portal User Roles and Permissions

**Level**: PRD | **Implements**: p00009 | **Status**: Draft

The portal SHALL support three user roles with distinct permissions: Admin (user management), Investigator (patient operations), and Auditor (compliance oversight).

Role permissions SHALL ensure:
- **Admins** create and manage Investigator and Auditor accounts
- **Admins** revoke access for Investigators and Auditors
- **Investigators** enroll patients at their assigned clinical sites
- **Investigators** send questionnaires and monitor patient engagement
- **Investigators** generate monthly reports for their sites
- **Auditors** view all data in read-only mode
- **Auditors** export database for compliance reviews
- Users can only access data from their assigned sponsor
- Each user assigned to exactly one role
- No user has permissions across multiple sponsors

**Rationale**: Clinical trials require clear separation of responsibilities. Admins manage system access, Investigators perform day-to-day patient operations, and Auditors provide independent oversight. This separation ensures proper controls and audit trails for regulatory compliance (21 CFR Part 11).

**Acceptance Criteria**:
- Admin role can create Investigator and Auditor accounts
- Admin role can revoke tokens for Investigators and Auditors
- Admin role cannot enroll patients or send questionnaires
- Investigator role can enroll patients at assigned sites only
- Investigator role can send questionnaires to patients at assigned sites
- Investigator role cannot create other users
- Auditor role can view all portal data in read-only mode
- Auditor role can export database (compliance function)
- Auditor role cannot create, update, or delete any records
- All user actions captured in audit trail
- Users cannot switch roles without Admin intervention

*End* *Portal User Roles and Permissions* | **Hash**: cf1917cb
---

# REQ-p00025: Patient Enrollment Workflow

**Level**: PRD | **Implements**: p00009, p00024 | **Status**: Draft

Investigators SHALL be able to enroll new patients using IRT-provided patient IDs and generate unique linking codes for patients to connect their mobile diary applications.

Patient enrollment SHALL ensure:
- Investigator enters patient ID from IRT system (format: SSS-PPPPPPP)
- Investigator selects patient's clinical site from assigned sites
- System generates unique 10-character linking code (format: XXXXX-XXXXX)
- Linking code uses non-ambiguous characters only (no 0, O, 1, I, l)
- Patient uses linking code to connect mobile app to portal
- Enrolled patients visible in Investigator's patient monitoring dashboard
- Investigators can only enroll patients at their assigned sites
- Each patient ID can only be enrolled once
- Linking codes never reused

**Rationale**: Patient enrollment connects the IRT system (which randomizes and assigns patient IDs) with the diary system. Linking codes provide a secure, user-friendly method for patients to connect their mobile apps to the correct sponsor and trial without exposing technical details or requiring complex setup.

**Acceptance Criteria**:
- Investigator can enter patient ID from IRT (SSS-PPPPPPP format)
- System validates patient ID format before enrollment
- Investigator selects site from dropdown (only assigned sites shown)
- System auto-generates 10-character linking code on enrollment
- Linking code displayed to Investigator for patient communication
- Linking code uses alphanumeric characters excluding 0, O, 1, I, l
- Duplicate patient ID rejected with clear error message
- Enrolled patient appears in monitoring dashboard immediately
- Patient can link mobile app using generated code
- Linking code association permanent (cannot be changed after linking)

*End* *Patient Enrollment Workflow* | **Hash**: 46eedac4
---

# REQ-p00026: Patient Monitoring Dashboard

**Level**: PRD | **Implements**: p00009, p00024 | **Status**: Draft

Investigators SHALL have real-time visibility into patient engagement through a monitoring dashboard showing patient status, days without data entry, last login time, and questionnaire completion status.

Patient monitoring SHALL provide:
- **Patient Status Indicators**:
  - Active (Green): Patient entered data within last 3 days
  - Attention (Yellow): 4-7 days since last data entry
  - At Risk (Red): More than 7 days since last data entry
  - No Data (Gray): Patient has never entered diary data
- **Engagement Metrics**:
  - Days without data entry (calculated from last entry timestamp)
  - Last login time (e.g., "2 hours ago", "3 days ago")
  - Enrollment date
  - Assigned clinical site
- **Data Filtering**:
  - Investigators see only patients from their assigned sites
  - Auditors see all patients across all sites (read-only)
  - Admins see all patients but cannot perform operational tasks
- **Summary Statistics**:
  - Total patients enrolled
  - Patients active today
  - Patients requiring follow-up (attention or at risk)

**Rationale**: Investigators need real-time awareness of patient engagement to identify patients who may need reminders or support. Status indicators provide quick visual scanning of large patient lists. Site-based filtering ensures Investigators focus on their assigned locations while maintaining data isolation.

**Acceptance Criteria**:
- Dashboard shows patient ID, site, status badge, days without data
- Status color updates automatically based on last data entry
- "Days Without Data" calculated from last diary entry timestamp
- Last login shows time since patient's last app login
- Investigators see patients from assigned sites only
- Auditors see all patients across all sites
- Summary cards show total, active today, requires follow-up counts
- Dashboard refreshes to show newly enrolled patients
- Visual indicators distinguishable for accessibility (color + text)

*End* *Patient Monitoring Dashboard* | **Hash**: 256f8363
---

# REQ-p00027: Questionnaire Management

**Level**: PRD | **Implements**: p00009, p00024 | **Status**: Draft

Investigators SHALL be able to send push notifications to patients to complete specific questionnaires (NOSE HHT and Quality of Life) and track questionnaire completion status.

Questionnaire management SHALL provide:
- **Questionnaire Types**:
  - NOSE HHT: Nasal Obstruction Symptom Evaluation for Hereditary Hemorrhagic Telangiectasia
  - QoL: Quality of Life assessment
- **Status Workflow**:
  - Not Sent: Ready to send questionnaire
  - Sent: Questionnaire pushed to patient's mobile app (shows "Pending")
  - Completed: Patient finished questionnaire (shows completion date)
  - Acknowledged: Investigator reviewed completion, resets to "Not Sent" for next cycle
- **Actions Available**:
  - Send: Push questionnaire notification to patient's mobile app
  - Resend: Send questionnaire again if needed
  - Acknowledge: Mark questionnaire as reviewed, reset to "Not Sent"
- **Tracking Features**:
  - Last completion date displayed for each questionnaire type
  - Independent status tracking per questionnaire type per patient
  - Investigators can only send to patients at assigned sites

**Rationale**: Clinical trial protocols often require periodic questionnaires separate from daily diary entries. Push notifications ensure patients receive timely reminders. Status tracking enables Investigators to monitor compliance and follow up with patients who haven't completed required questionnaires.

**Acceptance Criteria**:
- Investigator can send NOSE HHT questionnaire to patient
- Investigator can send QoL questionnaire to patient
- Each questionnaire type tracked independently
- Status changes from "Not Sent" to "Sent" when pushed
- Status changes to "Completed" when patient finishes (with date)
- Investigator can acknowledge completion (resets to "Not Sent")
- Last completion date displayed above each questionnaire column
- Resend option available for sent questionnaires
- Investigators can only send to patients at assigned sites
- Auditors can view questionnaire status but cannot send or acknowledge

*End* *Questionnaire Management* | **Hash**: 72da93bc
---

# REQ-p00028: Token Revocation and Access Control

**Level**: PRD | **Implements**: p00009, p00024, p00014 | **Status**: Draft

Admins SHALL be able to revoke access for Investigators and Auditors, and Investigators SHALL be able to revoke patient mobile app access when necessary.

Token revocation SHALL ensure:
- **Admin Capabilities**:
  - Revoke Investigator device access (prevents portal login)
  - Revoke Auditor access
  - Revocation immediate (no grace period)
  - Revoked users cannot re-activate themselves
- **Investigator Capabilities**:
  - Revoke patient mobile app access (for lost/stolen devices)
  - Revoke only for patients at assigned sites
- **Audit Trail**:
  - All revocations logged with timestamp and revoking user
  - Revocation reason captured (optional but recommended)
  - Revoked tokens never reused
- **Security**:
  - Revocation implemented via status field (soft delete)
  - Active tokens checked on every request
  - No residual access after revocation

**Rationale**: Clinical trials must be able to immediately terminate access when staff leave, devices are lost, or security incidents occur. Soft delete via status field maintains audit trail while preventing access. Immediate revocation ensures no window of unauthorized access.

**Acceptance Criteria**:
- Admin can click "Revoke Access" for Investigator or Auditor
- Investigator can click "Revoke Token" for patient at assigned site
- Revocation takes effect immediately (next request denied)
- Revoked user/device receives clear error message on next access
- All revocations logged in audit trail with timestamp and actor
- Revoked tokens cannot be re-enabled (must generate new linking code)
- Investigator cannot revoke other Investigators or Auditors
- Investigator cannot revoke patients at non-assigned sites
- Auditor cannot revoke any tokens (read-only role)

*End* *Token Revocation and Access Control* | **Hash**: 2edf0218
---

# REQ-p00029: Auditor Dashboard and Data Export

**Level**: PRD | **Implements**: p00009, p00024, p00004 | **Status**: Draft

Auditors SHALL have read-only access to all portal data across all sites and the ability to export the complete database for compliance reviews.

Auditor capabilities SHALL ensure:
- **Read-Only Access**:
  - View all portal users (Admins, Investigators, Auditors)
  - View all patients across all sites
  - View questionnaire statuses
  - View enrollment dates and engagement metrics
  - No create, update, or delete permissions
- **Data Export**:
  - Export complete database (stub for future implementation)
  - Export formats: CSV, JSON, or SQL dump (to be determined)
  - Export includes all audit trail data
  - Export action logged in audit trail
- **Visual Indicators**:
  - Dashboard shows "AUDIT MODE" or similar indicator
  - Clear indication that view is read-only
  - No action buttons for create/update/delete operations

**Rationale**: Auditors provide independent oversight for regulatory compliance and must be able to view all trial data without ability to modify it. Database export enables compliance reviews, regulatory submissions, and external audits. Read-only access ensures auditor actions cannot affect trial operations.

**Acceptance Criteria**:
- Auditor can view all users across all sites
- Auditor can view all patients across all sites
- Auditor can view all questionnaire statuses
- Auditor dashboard shows "AUDIT MODE" indicator
- No "Create", "Edit", "Delete", "Send", or "Revoke" buttons visible
- "Export Database" button present (stub for future implementation)
- Export action logged in audit trail when implemented
- Auditor cannot enroll patients or send questionnaires
- Auditor cannot create users or revoke tokens
- All auditor actions logged in audit trail

*End* *Auditor Dashboard and Data Export* | **Hash**: 5a77e3bb
---

# REQ-p00030: Role-Based Visual Indicators

**Level**: PRD | **Implements**: p00005, p00024 | **Status**: Active

The portal SHALL display a color-coded banner at the top of the interface indicating the user's current role to prevent accidental actions in the wrong role context.

Role colors SHALL be:
- Patient: Blue | Investigator: Green | Sponsor: Purple | Auditor: Orange
- Analyst: Teal | Administrator: Red | Developer Admin: Dark Red

**Rationale**: Visual role indication reduces cognitive load and prevents role confusion for users with multiple roles.

**Acceptance Criteria**:
- Banner displays current role name with role-specific color
- Banner visible on all portal pages
- Colors meet accessibility contrast standards

*End* *Role-Based Visual Indicators* | **Hash**: 59059266
---

## Architecture Overview

The portal connects to the sponsor-specific Cloud SQL database with role-based access control enforced both at the application and database levels:

```
┌──────────────────────────────────────────────────────────┐
│             CLINICAL TRIAL WEB PORTAL                     │
│                                                            │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Admin    │  │ Investigator │  │   Auditor    │     │
│  │ Dashboard  │  │  Dashboard   │  │  Dashboard   │     │
│  └─────┬──────┘  └──────┬───────┘  └──────┬───────┘     │
│        │                │                  │              │
│        └────────────────┴──────────────────┘              │
│                         │                                 │
│              ┌──────────▼────────────┐                    │
│              │  Authentication       │                    │
│              │  (OAuth + Email/Pwd)  │                    │
│              └──────────┬────────────┘                    │
│                         │                                 │
│              ┌──────────▼────────────┐                    │
│              │  Role-Based Access    │                    │
│              │  (RLS Policies)       │                    │
│              └──────────┬────────────┘                    │
└─────────────────────────┼──────────────────────────────────┘
                          │
            ┌─────────────▼─────────────┐
            │  SPONSOR DATABASE         │
            │  (Isolated per Sponsor)   │
            │                           │
            │  Tables:                  │
            │  - portal_users           │
            │  - patients               │
            │  - sites                  │
            │  - questionnaires         │
            │  - user_site_access       │
            │  - record_audit (events)  │
            │                           │
            │  Access Control:          │
            │  - Row-Level Security     │
            │  - Site-based isolation   │
            │  - Role-based policies    │
            └───────────────────────────┘
```

**Key Architecture Principles**:
- **Sponsor Isolation**: Each sponsor has separate portal deployment and database instance
- **Database-Level Security**: Row-Level Security (RLS) policies enforce access control at database layer
- **Site-Based Isolation**: Investigators see only patients from assigned sites
- **No Backend API**: Portal connects directly to database with RLS enforcement
- **Separate from Mobile App**: Portal is independent web application, not part of patient diary app

**See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment architecture

---

## User Workflows

### Admin Creates New Investigator

1. Admin logs into portal using OAuth or email/password
2. Admin clicks "Create User" button
3. Admin enters investigator name and email
4. Admin selects "Investigator" role from dropdown
5. Admin selects clinical sites to assign to investigator
6. System generates unique 10-character device linking code
7. Admin copies linking code and shares with investigator
8. Investigator uses linking code to link their device to portal
9. Investigator can now log in and access assigned sites

### Admin Creates New Auditor

1. Admin logs into portal using OAuth or email/password
2. Admin clicks "Create User" button
3. Admin enters auditor name and email
4. Admin selects "Auditor" role from dropdown
5. System creates auditor account with read-only access to all sites
6. Auditor can now log in and view all data

### Investigator Enrolls Patient

1. Investigator logs into portal
2. Investigator clicks "Enroll New Patient" button
3. Investigator enters patient ID from IRT system (format: SSS-PPPPPPP)
4. Investigator selects patient's clinical site from dropdown (only assigned sites shown)
5. System validates patient ID format and checks for duplicates
6. System generates unique 10-character linking code for patient
7. Investigator copies linking code
8. Investigator communicates linking code to patient (verbal, written, etc.)
9. Patient enters linking code in mobile app to complete enrollment
10. Patient appears in Investigator's monitoring dashboard

### Investigator Sends Questionnaire

1. Investigator reviews patient monitoring dashboard
2. Investigator identifies patient needing questionnaire
3. Investigator clicks "Send" button for NOSE HHT or QoL questionnaire
4. System sends push notification to patient's mobile app
5. Questionnaire status changes to "Sent" (shows "Pending" in dashboard)
6. Patient completes questionnaire on mobile app
7. Status changes to "Completed" with completion date
8. Investigator clicks "Acknowledge" to review completion
9. Status returns to "Not Sent" for next questionnaire cycle

### Investigator Monitors Patient Engagement

1. Investigator logs into portal
2. Dashboard shows all patients from assigned sites
3. Investigator scans status indicators:
   - Green badges: Patients active within last 3 days
   - Yellow badges: Patients with 4-7 days without data
   - Red badges: Patients with more than 7 days without data
4. Investigator notes "Days Without Data" column for each patient
5. Investigator contacts at-risk patients to provide support or reminders
6. Investigator checks "Last Login" to see recent app engagement
7. Summary cards show quick counts: Total, Active Today, Requires Follow-up

### Auditor Reviews Trial Data

1. Auditor logs into portal
2. Auditor dashboard shows "AUDIT MODE" indicator
3. Auditor views all users across all sites (read-only)
4. Auditor views all patients across all sites (read-only)
5. Auditor checks questionnaire completion rates
6. Auditor reviews patient engagement metrics
7. Auditor clicks "Export Database" for compliance review (future feature)
8. All auditor actions logged in audit trail

---

## Security and Compliance

**Access Control**:
- Role-based access control (RBAC) enforces permissions
- Site-based data isolation for Investigators
- Database Row-Level Security (RLS) policies enforce access rules
- All authentication via OAuth (Google, Microsoft) or secure email/password

**Audit Trail**:
- All user actions logged with timestamp and user ID
- Audit trail immutable (append-only)
- Includes user creation, patient enrollment, questionnaire sends, token revocations
- Auditor actions logged for oversight accountability

**Sponsor Isolation**:
- Each sponsor has separate portal instance
- Separate database per sponsor (no shared data)
- No cross-sponsor access possible
- Portal URL unique per sponsor (e.g., sponsor-alpha.portal.example.com)

**Compliance**:
- Meets FDA 21 CFR Part 11 requirements
- ALCOA+ principles (Attributable, Legible, Contemporaneous, Original, Accurate)
- Complete audit trail for regulatory submissions

**See**: prd-security.md for security architecture
**See**: prd-security-RBAC.md for role-based access control details
**See**: prd-clinical-trials.md for compliance requirements

---

## References

- **Implementation**: dev-portal.md
- **Operations**: ops-portal.md
- **Architecture**: prd-architecture-multi-sponsor.md
- **Security**: prd-security.md, prd-security-RBAC.md, prd-security-RLS.md
- **Database**: prd-database.md
- **Compliance**: prd-clinical-trials.md
