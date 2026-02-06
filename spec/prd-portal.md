# Clinical Trial Sponsor Portal

**Version**: 1.0
**Status**: Active
**Last Updated**: 2026-01-18

---

## What Is This Application?

The Sponsor Portal is a web-based application that enables clinical trial staff to manage clinical studies. It provides tools for linking patients to the mobile app, managing questionnaires, and monitoring trial activities.

**Important**: The Sponsor Portal is an **optional** component. It is only necessary when sponsors require a web interface for clinical trial staff to manage patients and monitor trial activities.

**Platform**: Web application only. Accessible via desktop and laptop browsers. Mobile browser access is not currently supported.

---

## Who Uses This Application?

The portal supports three generic role templates that sponsors map to their organization-specific roles (see REQ-p70008):

### Investigator

Investigators manage day-to-day patient operations at their assigned clinical sites. They:

- Link patients to the mobile app
- Send questionnaires (EQ, Nose HHT, Quality of Life)
- Approve completed questionnaires during patient visits
- Monitor patient linking status
- View their own audit logs

### Auditor

Auditors provide monitoring and oversight across multiple sites. They:

- View Investigator activities at assigned sites
- Review audit logs for compliance verification
- Monitor patient enrollment and linking metrics
- Prepare for monitoring visits

### Admin

Admins manage system configuration and user accounts. They:

- Create, edit, deactivate, and reactivate user accounts
- Assign users to roles and sites
- Unlock locked user accounts
- View sites (read-only)
- View their own administrative audit logs

**Note**: These are generic role templates. Each sponsor maps these to their own role names (e.g., "Study Coordinator" for Investigator, "CRA" for Auditor) and customizes capabilities to match their organizational requirements.

---

## How Do Multiple Sponsors Use The Same System?

**Isolated Portal Instances**: Each pharmaceutical company or research organization gets their own completely separate portal instance with its own database.

**How It Works**:

1. **Separate Deployments**: Each sponsor has their own portal URL (e.g., `sponsor-alpha.portal.example.com`)
2. **Isolated Databases**: Each sponsor's data is stored in a completely separate database
3. **Custom Branding**: Each portal displays that sponsor's logo and colors
4. **No Data Sharing**: Sponsors cannot see each other's data - complete isolation
5. We only use codenames for Sponsors in the public repository.
6. A new private repository using a code name is created for each Sponsor to store their configuration and branding

**Example**:

- ACME has `europa.portal.example.com` with their own database and branding
- PharmaStartup has `ganymede.portal.example.com` with their own database and branding
- The two portals are completely independent and isolated from each other

---

## Key Capabilities

### Patient Linking

Investigators can link patients to the mobile app by generating unique codes. Patients enter the code in their mobile app to establish connection.

### Questionnaire Management

Investigators can:

- Send EQ questionnaire immediately after patient linking (enables diary data sync)
- Send Nose HHT and Quality of Life questionnaires before patient visits
- Approve questionnaires during in-person patient visits
- Track questionnaire completion status

### Patient Monitoring

Investigators and Auditors can:

- Track Mobile Linking Status
- Receive inactivity alerts
- View patient enrollment metrics

### Audit Trail

All user actions are logged for regulatory compliance:

- Patient linking and disconnection
- Questionnaire sends and approvals
- User account changes
- Site assignment changes

### Multi-Site Support

- Investigators can be assigned to multiple sites
- Auditors can monitor multiple sites
- Admins have access to all sites by default

### Multi-Role Support

- Users can be assigned multiple roles
- Users can switch between roles without logging out

### Authentication and Security

- Password reset and account activation with mandatory email-based 2FA
- Account lockout after failed login attempts
- Session management with inactivity timeout

---

## User Journeys

# JNY-Portal-Enrollment-01: New Patient Enrollment

**Actor**: Dr. Sarah Mitchell (Investigator)
**Goal**: Enroll a new patient into the clinical trial and provide them with mobile app access
**Context**: A patient has consented to participate in the trial. Dr. Mitchell needs to create their portal record and provide credentials for the mobile app.

## Steps

1. Dr. Mitchell opens the Sponsor Portal and navigates to patient enrollment
2. Dr. Mitchell clicks "Enroll New Patient" and selects the patient's site
3. The system generates a unique linking code and displays it once on screen
4. Dr. Mitchell provides the linking code to the patient verbally or on paper
5. The patient downloads the mobile app and enters the linking code
6. The system validates the code and links the patient to the portal
7. The patient begins using the app for diary entries and questionnaires
8. The mobile app syncs data to the portal automatically

## Expected Outcome

The patient is successfully enrolled and can use the mobile app to participate in the trial. Their data syncs to the portal where Dr. Mitchell can monitor their progress.

*End* *New Patient Enrollment*

---

# JNY-Portal-Enrollment-02: Lost Mobile Phone Recovery

**Actor**: Dr. Sarah Mitchell (Investigator)
**Goal**: Secure a patient's trial data after they report a lost phone and restore their access on a new device
**Context**: A patient contacts Dr. Mitchell to report their phone was lost. The patient has obtained a new phone and wants to continue participating in the trial.

## Steps

1. The patient reports their lost phone to Dr. Mitchell
2. Dr. Mitchell opens the Sponsor Portal and locates the patient record
3. Dr. Mitchell clicks "Disconnect Patient" and selects reason "Lost Device"
4. The system invalidates the linking code immediately
5. The lost phone (if found by someone) can no longer sync or access trial data
6. Dr. Mitchell clicks "Reconnect Patient" and provides the reason for reconnection
7. The system generates a new linking code (the old code remains permanently invalid)
8. Dr. Mitchell provides the new code to the patient
9. The patient enters the new code in the mobile app on their new device
10. The system validates the code and reconnects the patient
11. The mobile app syncs any diary data that was collected locally during the disconnected period

## Expected Outcome

The patient's trial data is secured from unauthorized access on the lost device. The patient resumes participation on their new device with no data loss, and all locally stored entries sync successfully.

*End* *Lost Mobile Phone Recovery*

---

## Requirements

# REQ-p70007: Linking Code Lifecycle Management

**Level**: PRD | **Status**: Draft | **Implements**: p70001

## Rationale

Secure linking codes provide a mechanism for clinical staff to safely enroll patients into trials without requiring complex authentication setup. The 72-hour expiration window balances security (limited validity, single-use) with patient convenience, providing sufficient time to download the app and link their account. Time-limited, single-use codes minimize security risks while maintaining usability. Audit logging ensures traceability of patient enrollment events for regulatory compliance.

## Assertions

A. The Sponsor Portal SHALL generate a unique linking code when clinical staff initiates the patient enrollment workflow.

B. Linking codes SHALL expire after 72 hours from generation.

C. The linking code SHALL be cryptographically secure and not predictable or guessable.

D. The linking code SHALL be displayed in a format that is easy to communicate to the patient (e.g., short alphanumeric code).

E. Linking codes SHALL be single-use only.

F. The system SHALL mark linking codes as used after successful authentication.

G. The system SHALL reject invalid linking codes with a generic "Invalid Code" error message.

H. The system SHALL validate that the linking code is valid before completing the link.

I. The Mobile App SHALL provide input interface for linking codes during enrollment.

J. The system SHALL log all linking code generation, usage attempts, and validation results for audit purposes.

*End* *Linking Code Lifecycle Management* | **Hash**: 0a7d6119
---

# REQ-p70001: Sponsor Portal Application

**Level**: PRD | **Status**: Draft | **Implements**: p00044

## Rationale

The Sponsor Portal provides an optional sponsor-facing interface for clinical trial management when sponsors require a web interface for clinical trial staff. This component enables clinical trial staff to manage patients, monitor engagement, and maintain regulatory oversight while ensuring complete data isolation between sponsors. The portal supports generic role templates (Admin, Investigator, Auditor) that sponsors map to their organizational roles, and provides comprehensive audit capabilities required for FDA 21 CFR Part 11 compliance.

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

*End* *Sponsor Portal Application* | **Hash**: be01f827
---

# REQ-p70005: Customizable Role-Based Access Control

**Level**: PRD | **Status**: Draft | **Implements**: p00011, p00018

## Rationale

Different sponsors have different organizational structures and trial requirements. Customizable roles allow each sponsor to configure the system according to their specific needs while maintaining regulatory compliance and data integrity.

## Assertions

A. The system SHALL support customizable role-based access control where each sponsor defines their own roles and permissions.

B. Users SHALL be able to hold multiple roles.

C. Users SHALL be able to switch between their assigned roles without logging out.

D. Each role SHALL have configurable data access levels.

E. Each role SHALL have configurable action permissions.

F. All role-specific actions SHALL be logged in the audit trail.

G. Role definitions SHALL be isolated per sponsor.

*End* *Customizable Role-Based Access Control* | **Hash**: a9f3141f
---

# REQ-p70006: Comprehensive Audit Trail

**Level**: PRD | **Status**: Draft | **Implements**: p00004, p00011

## Rationale

Regulatory compliance (FDA 21 CFR Part 11, GCP) requires complete audit trails for all clinical trial activities. Configurable visibility ensures sponsors can define appropriate oversight levels based on their organizational structure.

## Assertions

A. The system SHALL maintain an immutable audit trail of all user actions.

B. The audit trail SHALL include timestamp for each action.

C. The audit trail SHALL include username for each action.

D. The audit trail SHALL include action type for each action.

E. The audit trail SHALL include action target for each action.

F. Audit logs SHALL NOT be editable.

G. Audit logs SHALL NOT be deletable.

H. Audit log visibility SHALL be configurable per role.

*End* *Comprehensive Audit Trail* | **Hash**: 6d89830c
---

# REQ-p70008: Sponsor-Specific Role Mapping

**Level**: PRD | **Status**: Draft | **Implements**: p70001, p70005

## Rationale

Clinical trial sponsors have established organizational structures with existing role definitions (e.g., "Study Coordinator", "Clinical Research Associate", "Site Administrator"). While the platform provides generic role templates (Investigator, Auditor, Admin), each sponsor needs to map these to their specific role names and customize capabilities to match their organizational requirements and SOPs. This mapping ensures the platform adapts to sponsor workflows rather than forcing sponsors to adopt new terminology and processes.

## Assertions

A. The system SHALL support mapping between platform generic roles and sponsor-specific role names.

B. The system SHALL support mapping between platform generic roles and sponsor-specific role capabilities.

C. Each sponsor SHALL be able to define custom role names that map to generic role templates.

D. The system SHALL maintain a role mapping configuration that translates sponsor-specific roles to platform permissions and access levels.

E. The platform SHALL define generic role templates (Investigator, Auditor, Admin) with baseline capabilities.

F. Users SHALL see sponsor-specific role names in the UI.

G. Users SHALL NOT see generic platform role names in the UI.

H. Role mapping changes SHALL be logged in the audit trail.

*End* *Sponsor-Specific Role Mapping* | **Hash**: 74b1201e

---

# REQ-p70009: Link New Patient Workflow

**Level**: PRD | **Status**: Draft | **Implements**: p00011, p00004

## Rationale

Patient linking establishes secure connection between patient's mobile device and sponsor portal, enabling questionnaire distribution and diary data collection. Unique codes prevent unauthorized access. Clinical staff controls when linking occurs, ensuring patient is ready to begin trial participation.

## Assertions

A. The system SHALL allow clinical staff to link patients to the mobile app by generating linking codes per REQ-p70007 (Linking Code Lifecycle Management).

B. The patient SHALL enter the code in the mobile app to complete linking.

C. The Mobile Linking Status SHALL change to "Pending" when code is generated.

D. The Mobile Linking Status SHALL change to "Connected" when patient successfully enters code.

E. The system SHALL reject invalid or expired codes.

F. The linking action SHALL be logged in the audit trail with timestamp and username.

*End* *Link New Patient Workflow* | **Hash**: 4f1edfe6

---

# REQ-p70010: Patient Disconnection Workflow

**Level**: PRD | **Status**: Draft | **Implements**: p00011, p00004

## Rationale

Patients may lose their phone, upgrade devices, or experience technical issues requiring disconnection. Disconnection invalidates the linking code to prevent unauthorized access from lost/stolen devices while preserving all patient data for reconnection. This is a temporary state allowing patients to resume participation after receiving replacement device or resolving technical issues.

## Assertions

A. The system SHALL allow clinical staff to disconnect patients from the mobile app.

B. The "Disconnect Patient" option SHALL be available in the patient actions menu for "Connected" patients.

C. The system SHALL display a confirmation dialog with patient ID and require reason selection.

D. The patient status SHALL change to "Disconnected" upon confirmation.

E. The linking code SHALL be invalidated immediately upon disconnection.

F. The patient mobile app SHALL stop syncing data after disconnection.

G. The mobile app SHALL display a prominent error message if its linking code is no longer valid.

H. Mobile App operation and local storage of data SHALL NOT change due to an expired or revoked linking code.

I. The disconnection SHALL be logged in the audit trail with reason, timestamp, and username.

J. The "Reconnect Patient" option SHALL become available after disconnection.

*End* *Patient Disconnection Workflow* | **Hash**: 0e956c62
---

# REQ-p70011: Patient Reconnection Workflow

**Level**: PRD | **Status**: Draft | **Implements**: p00011, p00004

## Rationale

Patients who were disconnected due to lost phone, device upgrade, or technical issues need ability to reconnect and resume trial participation. New linking code ensures security (old code cannot be reused) while enabling legitimate reconnection. Requiring reason documents why reconnection occurred for audit purposes. Clinical staff controls reconnection timing and provides code directly to patient.

## Assertions

A. The system SHALL allow clinical staff to reconnect patients with "Disconnected" status by generating a new linking code.

B. The "Reconnect Patient" action SHALL only be available for patients with "Disconnected" status.

C. The confirmation dialog SHALL display the patient ID and require a reason.

D. The system SHALL generate a new linking code upon confirmation.

E. The previous linking code SHALL remain invalidated and cannot be reused.

F. The patient SHALL enter the new code in the mobile app to restore access.

G. The Mobile Linking Status SHALL change to "Connected" after successful code entry.

H. The patient SHALL be able to resume data sync and questionnaire completion.

I. The reconnection SHALL be logged in the audit trail with reason, timestamp, and username.

J. The reconnected Mobile App SHALL sync data to the portal that was collected during the disconnected period.

*End* *Patient Reconnection Workflow* | **Hash**: c192cad5
