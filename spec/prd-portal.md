# Clinical Trial Web Portal

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-02
**Status**: Draft

> **See**: prd-system.md for platform overview
> **See**: ops-portal.md for deployment and operations procedures
> **See**: dev-portal.md for implementation details
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor architecture (REQ-p00009)
> **See**: prd-security-RBAC.md for role-based access control
> **See**: prd-database.md for data architecture

---

# REQ-p00045: Sponsor Portal Application

**Level**: PRD | **Status**: Draft | **Implements**: p00044

## Rationale

The Sponsor Portal provides an optional sponsor-facing interface for clinical trial management when direct EDC integration is not available or when sponsor-specific requirements dictate its use. This component enables clinical trial staff to manage patients, monitor engagement, and maintain regulatory oversight while ensuring complete data isolation between sponsors. The portal supports various roles (Admins, Investigators, Auditors) and provides comprehensive audit capabilities required for FDA 21 CFR Part 11 compliance.

## Assertions

A. The platform SHALL support optional deployment of a Sponsor Portal component based on sponsor configuration requirements.
B. The Sponsor Portal SHALL be deployed as a separate instance per sponsor.
C. The platform SHALL enforce role-based access control distinguishing between Admin, Investigator, and Auditor roles.
D. The Sponsor Portal SHALL provide patient enrollment workflows.
E. The Sponsor Portal SHALL provide patient monitoring workflows.
F. The Sponsor Portal SHALL provide questionnaire management capabilities.
G. The Sponsor Portal SHALL provide questionnaire distribution capabilities.
H. The Sponsor Portal SHALL provide access to audit trail data for compliance reviews.
I. The Sponsor Portal SHALL record all staff actions in the audit trail.
J. The Sponsor Portal SHALL provide real-time patient engagement monitoring.
K. The Sponsor Portal SHALL apply sponsor-specific branding throughout the interface.
L. The Sponsor Portal SHALL maintain complete data isolation between sponsors.

*End* *Sponsor Portal Application* | **Hash**: 5944889c

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

**Level**: PRD | **Status**: Draft | **Implements**: p00009

## Rationale

Clinical trials require clear separation of responsibilities to maintain regulatory compliance and proper oversight. Admins manage system access control, Investigators perform day-to-day patient operations, and Auditors provide independent compliance oversight. This role-based access control model ensures proper controls, prevents conflicts of interest, and maintains complete audit trails as required by FDA 21 CFR Part 11. Sponsor isolation prevents cross-contamination of trial data between different clinical studies.

## Assertions

A. The portal SHALL support exactly three user roles: Admin, Investigator, and Auditor.
B. The system SHALL assign each user to exactly one role.
C. The system SHALL restrict each user to accessing data from only their assigned sponsor.
D. The system SHALL prevent users from having permissions across multiple sponsors.
E. Admin users SHALL be able to create Investigator accounts.
F. Admin users SHALL be able to create Auditor accounts.
G. Admin users SHALL be able to revoke access tokens for Investigator users.
H. Admin users SHALL be able to revoke access tokens for Auditor users.
I. Admin users SHALL NOT be able to enroll patients.
J. Admin users SHALL NOT be able to send questionnaires.
K. Investigator users SHALL be able to enroll patients at their assigned clinical sites only.
L. Investigator users SHALL be able to send questionnaires to patients at their assigned sites.
M. Investigator users SHALL be able to monitor patient engagement for their assigned sites.
N. Investigator users SHALL be able to generate monthly reports for their assigned sites.
O. Investigator users SHALL NOT be able to create other user accounts.
P. Auditor users SHALL be able to view all portal data in read-only mode for their assigned sponsor.
Q. Auditor users SHALL be able to export the database for compliance reviews.
R. Auditor users SHALL NOT be able to create any records.
S. Auditor users SHALL NOT be able to update any records.
T. Auditor users SHALL NOT be able to delete any records.
U. The system SHALL capture all user actions in the audit trail.
V. The system SHALL prevent users from switching roles without Admin intervention.

*End* *Portal User Roles and Permissions* | **Hash**: bfcc5610
---

# REQ-p00025: Patient Enrollment Workflow

**Level**: PRD | **Status**: Draft | **Implements**: p00009, p00024

## Rationale

Patient enrollment bridges the Interactive Response Technology (IRT) system, which handles randomization and patient ID assignment, with the clinical trial diary platform. The linking code mechanism provides a secure yet user-friendly method for patients to connect their mobile diary applications to the correct trial and sponsor without exposing technical infrastructure details or requiring complex configuration. This approach balances security requirements with usability for non-technical patient users while maintaining strict data isolation between sponsors and sites. The non-ambiguous character set prevents transcription errors during the manual code entry process.

## Assertions

A. The system SHALL allow Investigators to enroll new patients using IRT-provided patient IDs.
B. The system SHALL accept patient IDs in the format SSS-PPPPPPP where S represents site digits and P represents patient digits.
C. The system SHALL validate patient ID format before completing enrollment.
D. The system SHALL require Investigators to select the patient's clinical site from their assigned sites during enrollment.
E. The system SHALL display only sites assigned to the Investigator in the site selection dropdown.
F. The system SHALL generate a unique 10-character linking code in the format XXXXX-XXXXX upon successful patient enrollment.
G. The system SHALL generate linking codes using only alphanumeric characters excluding the characters 0, O, 1, I, and l.
H. The system SHALL display the generated linking code to the Investigator for communication to the patient.
I. The system SHALL allow patients to connect their mobile diary application using the linking code.
J. The system SHALL map each linking code to the correct sponsor to enable proper authentication routing.
K. The system SHALL reject attempts to enroll a patient ID that has already been enrolled.
L. The system SHALL display a clear error message when a duplicate patient ID is submitted for enrollment.
M. The system SHALL immediately display newly enrolled patients in the Investigator's patient monitoring dashboard.
N. The system SHALL prevent Investigators from enrolling patients at sites not assigned to them.
O. The system SHALL NOT allow reuse of linking codes.
P. The system SHALL make the linking code association permanent once a patient has linked their mobile application.
Q. The system SHALL NOT allow modification of the linking code association after the patient has linked their mobile application.

*End* *Patient Enrollment Workflow* | **Hash**: 088991b7
---

# REQ-p00026: Patient Monitoring Dashboard

**Level**: PRD | **Status**: Draft | **Implements**: p00009, p00024

## Rationale

Investigators need real-time awareness of patient engagement to identify patients who may need reminders or support. Status indicators provide quick visual scanning of large patient lists to prioritize intervention. Site-based filtering ensures Investigators focus on their assigned locations while maintaining data isolation required for multi-site clinical trials. This monitoring capability enables proactive patient retention and data quality management, which are critical for trial integrity and regulatory compliance.

## Assertions

A. The system SHALL provide a patient monitoring dashboard accessible to Investigators, Auditors, and Admins.
B. The dashboard SHALL display the following fields for each patient: patient ID, assigned clinical site, status indicator, days without data entry, and last login time.
C. The system SHALL calculate 'days without data entry' from the timestamp of the patient's last diary entry.
D. The system SHALL display a Green 'Active' status indicator when a patient has entered data within the last 3 days.
E. The system SHALL display a Yellow 'Attention' status indicator when 4-7 days have elapsed since the patient's last data entry.
F. The system SHALL display a Red 'At Risk' status indicator when more than 7 days have elapsed since the patient's last data entry.
G. The system SHALL display a Gray 'No Data' status indicator when a patient has never entered diary data.
H. The system SHALL update status indicators automatically based on the timestamp of the last data entry.
I. The system SHALL display last login time in relative format (e.g., '2 hours ago', '3 days ago').
J. The system SHALL display enrollment date for each patient on the dashboard.
K. The system SHALL display assigned clinical site for each patient on the dashboard.
L. The system SHALL filter the patient list for Investigators to show only patients from their assigned sites.
M. The system SHALL display all patients across all sites to Auditors with read-only access.
N. The system SHALL display all patients across all sites to Admins.
O. The system SHALL display a summary statistic showing total patients enrolled.
P. The system SHALL display a summary statistic showing patients active today.
Q. The system SHALL display a summary statistic showing patients requiring follow-up (Attention or At Risk status).
R. The dashboard SHALL refresh to show newly enrolled patients without requiring manual page reload.
S. The system SHALL make status indicators visually distinguishable through both color and text to meet accessibility requirements.

*End* *Patient Monitoring Dashboard* | **Hash**: d361e406
---

# REQ-p00027: Questionnaire Management

**Level**: PRD | **Status**: Draft | **Implements**: p00009, p00024

## Rationale

Clinical trial protocols often require periodic questionnaires (such as NOSE HHT and Quality of Life assessments) to be administered separately from daily diary entries. Push notification capabilities ensure patients receive timely reminders to complete required assessments. Independent status tracking per questionnaire type enables Investigators to monitor protocol compliance, identify non-responders, and follow up appropriately. The status workflow (Not Sent → Sent → Completed → Acknowledged → Not Sent) supports cyclical administration of questionnaires throughout the trial. Role-based access controls ensure that only Investigators can initiate questionnaire sends while Auditors maintain read-only visibility for regulatory oversight. Site-based restrictions on send capabilities maintain proper investigator-patient relationships and data integrity.

## Assertions

A. The system SHALL support two questionnaire types: NOSE HHT (Nasal Obstruction Symptom Evaluation for Hereditary Hemorrhagic Telangiectasia) and QoL (Quality of Life assessment).
B. The system SHALL implement a questionnaire status workflow with four states: Not Sent, Sent, Completed, and Acknowledged.
C. The system SHALL enable Investigators to send push notifications to patients to complete specific questionnaires.
D. The system SHALL enable Investigators to resend questionnaire notifications when needed.
E. The system SHALL enable Investigators to acknowledge questionnaire completion.
F. The system SHALL change questionnaire status from Not Sent to Sent when a push notification is delivered to the patient's mobile app.
G. The system SHALL change questionnaire status to Completed when the patient finishes the questionnaire.
H. The system SHALL record the completion date when questionnaire status changes to Completed.
I. The system SHALL change questionnaire status from Acknowledged to Not Sent when an Investigator acknowledges completion.
J. The system SHALL display the last completion date for each questionnaire type.
K. The system SHALL track questionnaire status independently for each questionnaire type per patient.
L. The system SHALL display Sent status questionnaires as Pending in the patient's mobile app.
M. The system SHALL restrict Investigators to sending questionnaires only to patients assigned to their sites.
N. The system SHALL enable Auditors to view questionnaire status.
O. The system SHALL NOT enable Auditors to send questionnaire notifications.
P. The system SHALL NOT enable Auditors to acknowledge questionnaire completion.

*End* *Questionnaire Management* | **Hash**: 6d930ebf
---

# REQ-p00028: Token Revocation and Access Control

**Level**: PRD | **Status**: Draft | **Implements**: p00009, p00024, p00014

## Rationale

Clinical trials must be able to immediately terminate access when staff leave, devices are lost, or security incidents occur. This requirement addresses FDA 21 CFR Part 11 requirements for access control and audit trails. The soft delete approach via status field maintains complete audit trail integrity while preventing further access. Immediate revocation ensures no window of unauthorized access between revocation decision and enforcement. This implements parent requirements for authentication (p00009), role-based access control (p00024), and audit trails (p00014).

## Assertions

A. The system SHALL provide Admins with the capability to revoke Investigator device access.
B. The system SHALL provide Admins with the capability to revoke Auditor access.
C. The system SHALL provide Investigators with the capability to revoke patient mobile app access for patients at their assigned sites.
D. The system SHALL NOT allow Investigators to revoke access for patients at non-assigned sites.
E. The system SHALL NOT allow Investigators to revoke access for other Investigators or Auditors.
F. The system SHALL NOT allow Auditors to revoke any tokens.
G. The system SHALL enforce token revocation immediately with no grace period.
H. The system SHALL deny the next request from a revoked token.
I. The system SHALL NOT allow revoked users to re-activate themselves.
J. The system SHALL implement token revocation via a status field rather than deletion.
K. The system SHALL check token active status on every authenticated request.
L. The system SHALL log all revocation events with timestamp and revoking user identity.
M. The system SHALL capture revocation reason when provided.
N. The system SHALL NOT reuse revoked tokens.
O. The system SHALL NOT allow re-enablement of revoked tokens.
P. The system SHALL require generation of a new linking code for re-enabling access.
Q. The system SHALL provide a user interface element for Admins to revoke Investigator access.
R. The system SHALL provide a user interface element for Admins to revoke Auditor access.
S. The system SHALL provide a user interface element for Investigators to revoke patient tokens.
T. The system SHALL display a clear error message to revoked users on their next access attempt.

*End* *Token Revocation and Access Control* | **Hash**: fcc67e9c
---

# REQ-p00029: Auditor Dashboard and Data Export

**Level**: PRD | **Status**: Draft | **Implements**: p00009, p00024, p00004

## Rationale

Auditors provide independent oversight for regulatory compliance and must be able to view all trial data without ability to modify it. Database export enables compliance reviews, regulatory submissions, and external audits. Read-only access ensures auditor actions cannot affect trial operations. This requirement implements the audit access controls defined in REQ-p00009, REQ-p00024, and REQ-p00004.

## Assertions

A. The system SHALL grant Auditors read-only access to all portal data across all sites.
B. The system SHALL allow Auditors to view all portal users including Admins, Investigators, and other Auditors.
C. The system SHALL allow Auditors to view all patients across all sites.
D. The system SHALL allow Auditors to view all questionnaire statuses.
E. The system SHALL allow Auditors to view enrollment dates and engagement metrics.
F. The system SHALL NOT grant Auditors permission to create any data.
G. The system SHALL NOT grant Auditors permission to update any data.
H. The system SHALL NOT grant Auditors permission to delete any data.
I. The system SHALL provide Auditors with the ability to export the complete database.
J. The system SHALL include all audit trail data in database exports.
K. The system SHALL log each database export action in the audit trail.
L. The Auditor dashboard SHALL display an 'AUDIT MODE' or similar visual indicator.
M. The Auditor interface SHALL provide clear indication that the view is read-only.
N. The Auditor interface SHALL NOT display action buttons for create operations.
O. The Auditor interface SHALL NOT display action buttons for update operations.
P. The Auditor interface SHALL NOT display action buttons for delete operations.
Q. The Auditor interface SHALL NOT display 'Send' buttons for questionnaire operations.
R. The Auditor interface SHALL NOT display 'Revoke' buttons for token operations.
S. The system SHALL prevent Auditors from enrolling patients.
T. The system SHALL prevent Auditors from sending questionnaires.
U. The system SHALL prevent Auditors from creating users.
V. The system SHALL prevent Auditors from revoking tokens.
W. The system SHALL log all Auditor actions in the audit trail.

*End* *Auditor Dashboard and Data Export* | **Hash**: 67438675
---

# REQ-p00030: Role-Based Visual Indicators

**Level**: PRD | **Status**: Draft | **Implements**: p00005, p00024

## Rationale

Visual role indication reduces cognitive load and prevents role confusion for users with multiple roles. This requirement supports FDA 21 CFR Part 11 compliance by providing clear visual feedback about the user's current operational context, helping prevent unauthorized or accidental actions performed under incorrect role privileges. The color-coding system provides immediate, intuitive feedback that complements the technical role-based access controls implemented elsewhere in the system.

## Assertions

A. The system SHALL display a color-coded banner at the top of the interface indicating the user's current role.
B. The role banner SHALL be visible on all portal pages.
C. The role banner SHALL display the current role name.
D. The role banner SHALL use blue color for the Patient role.
E. The role banner SHALL use green color for the Investigator role.
F. The role banner SHALL use purple color for the Sponsor role.
G. The role banner SHALL use orange color for the Auditor role.
H. The role banner SHALL use teal color for the Analyst role.
I. The role banner SHALL use red color for the Administrator role.
J. The role banner SHALL use dark red color for the Developer Admin role.
K. The role banner colors SHALL meet WCAG accessibility contrast standards.

*End* *Role-Based Visual Indicators* | **Hash**: 761ae5c1
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
