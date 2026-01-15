# Development Specification: Clinical Trial Web Portal

**Document Type**: Development Specification (Implementation Blueprint)
**Audience**: Software Engineers, Flutter Developers, DevOps Engineers
**Status**: Draft
**Last Updated**: 2025-12-27

---

## Overview

This document specifies the technical implementation requirements for the Clinical Trial Web Portal, a sponsor-specific web application built with **Flutter Web** that enables Admins and Investigators to manage clinical trial users, enroll patients, monitor patient engagement, and manage questionnaires.

The portal is a **separate application** from the patient diary mobile app, deployed as a web-only Flutter application. It provides role-based dashboards with site-level data isolation, integrates with Identity Platform for authentication and Cloud Run API for database access, and generates linking codes for patient enrollment.

**Related Documents**:
- Product Requirements: `spec/prd-portal.md` (Portal product requirements)
- Operations Requirements: `spec/ops-portal.md` (Portal deployment and operations)
- Multi-Sponsor Architecture: `spec/prd-architecture-multi-sponsor.md` (REQ-p00009)
- Overall Deployment: `spec/ops-deployment.md` (REQ-o00009)
- Database Schema: `database/schema.sql`
- RLS Policies: `database/rls_policies.sql`
- Security: `spec/prd-security-RBAC.md`, `spec/prd-security-RLS.md`

---

## Architecture Overview

The portal is a standalone Flutter web application, separate from the patient diary mobile app:

```
┌─────────────────────────────────────────────────────────────┐
│         Clinical Trial Portal (Flutter Web)                  │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │    Admin     │  │ Investigator │                         │
│  │  Dashboard   │  │  Dashboard   │                         │
│  └──────────────┘  └──────────────┘                         │
│           │                │                                 │
│           └────────────────┘                                 │
│                            │                                 │
│                  ┌─────────▼─────────┐                      │
│                  │  Identity Platform    │ (OAuth + Email/Pwd)  │
│                  └─────────┬─────────┘                      │
│                            │                                 │
│                  ┌─────────▼─────────┐                      │
│                  │   HTTP Client +   │ (JWT in headers)     │
│                  │   Cloud Run API   │                       │
│                  └─────────┬─────────┘                      │
└────────────────────────────┼─────────────────────────────────┘
                             │
                   ┌─────────▼─────────┐
                   │   Cloud Run API   │
                   │   (Dart Server)   │
                   └─────────┬─────────┘
                             │
                   ┌─────────▼─────────┐
                   │    Cloud SQL      │
                   │  (PostgreSQL 15)  │
                   │  - portal_users   │
                   │  - patients       │
                   │  - sites          │
                   │  - questionnaires │
                   │  - RLS policies   │
                   └───────────────────┘
                             │
                             │ (Separate database connection)
                             │
┌─────────────────────────────────────────────────────────────┐
│       Patient Diary App (Flutter Mobile - Separate)         │
│  - Patient diary entries (offline-first)                     │
│  - Multi-sponsor support                                     │
│  - Demo mode: "START-DEMO1" / "00END-DEMO1" codes          │
└─────────────────────────────────────────────────────────────┘
```

**Key Principles**:
- **Flutter Web**: Single codebase, potential future merge with mobile app
- **Web-Only**: No mobile deployment (separate from patient diary app)
- **Authentication First**: All routes protected, role-based access
- **Database-Driven UI**: RLS policies enforce data isolation
- **Responsive Design**: Desktop-first, tablet support
- **Cloud Run API**: HTTP client calls to Dart server with RLS enforcement
- **Separate App**: Independent from patient diary mobile app (may merge later)

**Scope Simplifications**:
- **Three Roles**: Admin, Investigator, Auditor (no Analyst role)
- **No Diary Viewing**: Patient diary entries viewed in 3rd party EDC system
- **No Event Viewer**: Event sourcing exists at database level, not exposed in portal UI
- **Essential Functions Only**: Login, user management, patient enrollment, questionnaire management, audit viewing

---

## Technology Stack Requirements

# REQ-d00028: Portal Frontend Framework

**Level**: Dev | **Status**: Draft | **Implements**: p00009, p00038

## Rationale

This requirement establishes Flutter as the web framework for the clinical trial portal, enabling potential code reuse with mobile applications while ensuring broad browser compatibility. The HTML renderer is chosen over CanvasKit for wider browser support, accepting some performance trade-offs. The specified dependencies provide core functionality for authentication, routing, state management, and API communication. Development and production build processes must support rapid iteration and optimized delivery.

## Assertions

A. The portal SHALL be implemented using Flutter framework version 3.24 or higher from the stable channel.
B. The portal SHALL use Dart language version 3.10 or higher.
C. The portal SHALL target web as the deployment platform.
D. The portal SHALL use the HTML renderer for web compilation to ensure wide browser compatibility.
E. The portal SHALL use Flutter's build web tool for production builds.
F. The portal SHALL use pub as the package manager.
G. The portal SHALL include firebase_core version 2.24.0 or higher for Firebase initialization.
H. The portal SHALL include firebase_auth version 4.16.0 or higher for Identity Platform integration.
I. The portal SHALL include http version 1.1.0 or higher for HTTP client functionality.
J. The portal SHALL include go_router version 14.0.0 or higher for declarative routing.
K. The portal SHALL include provider version 6.1.0 or higher for state management.
L. The portal SHALL include flutter_svg version 2.0.0 or higher for SVG icon support.
M. The portal SHALL include intl version 0.19.0 or higher for date formatting.
N. The portal SHALL include url_strategy version 0.3.0 or higher for URL configuration.
O. The portal SHALL support hot reload functionality in development mode.
P. The portal SHALL implement URL strategy to remove hash symbols from routes.
Q. Production builds SHALL produce optimized bundles with total size less than 2MB.
R. The portal SHALL function correctly on the latest versions of Chrome browser.
S. The portal SHALL function correctly on the latest versions of Firefox browser.
T. The portal SHALL function correctly on the latest versions of Safari browser.
U. The portal SHALL function correctly on the latest versions of Edge browser.

*End* *Portal Frontend Framework* | **Hash**: 9abb5505

---

# REQ-d00029: Portal UI Design System

**Level**: Dev | **Status**: Draft | **Implements**: p00009

## Rationale

This requirement establishes the UI design system for the portal to ensure consistent, accessible, and maintainable user interfaces. Material Design 3 provides a modern, well-documented component library that supports responsive layouts and accessibility standards. The custom theme ensures visual consistency with sponsor mockups while maintaining WCAG AA accessibility compliance for regulatory and usability requirements.

## Assertions

A. The portal SHALL use Flutter's Material Design 3 widgets for all UI components.
B. The portal SHALL implement a custom theme that matches the portal mockups.
C. The theme configuration SHALL define custom colors, typography, and spacing values.
D. The portal SHALL use Material Design 3 components including Card, Button, DataTable, Dialog, and Badge widgets.
E. The portal SHALL support Material Icons and custom SVG icons.
F. The portal SHALL implement responsive layouts using MediaQuery-based breakpoints.
G. The portal SHALL provide a StatusBadge widget that displays color-coded patient status for Recent, Warning, At Risk, and No Data states.
H. The portal SHALL provide a LinkingCodeDisplay widget that shows monospace code with a copy button.
I. The portal SHALL provide a DaysWithoutDataCell widget that calculates and displays days since last_data_entry_date.
J. The portal SHALL provide a QuestionnaireActions widget that displays Send, Resend, or Acknowledge buttons based on questionnaire status.
K. The responsive layout SHALL support desktop viewports at 1024px width and above.
L. The responsive layout SHALL support tablet viewports at 768px width and above.
M. All UI components SHALL meet WCAG AA contrast ratio requirements for accessibility compliance.

*End* *Portal UI Design System* | **Hash**: 0e7d0956
---

# REQ-d00052: Role-Based Banner Component

**Level**: Dev | **Status**: Draft | **Implements**: p00030, o00055

## Rationale

This requirement provides visual role awareness for users navigating the authenticated portal, supporting security awareness and reducing context-switching errors. The color-coded banner immediately communicates the user's current role, which is critical in a multi-role system where users may switch contexts or where auditors need clear visual confirmation of their operational role. The requirement implements product requirement p00030 (role-based UI differentiation) and operations requirement o00055 (audit trail context visibility). WCAG AA compliance ensures accessibility for users with visual impairments.

## Assertions

A. The system SHALL display a RoleBanner component at the top of all authenticated pages.
B. The RoleBanner component SHALL be placed above the AppBar in the authenticated scaffold.
C. The RoleBanner component SHALL have a fixed height of 48 pixels.
D. The RoleBanner component SHALL display the current user's role name in white text, centered horizontally.
E. The RoleBanner component SHALL retrieve the role name from the authenticated user's role claim.
F. The RoleBanner component SHALL use color code #2196F3 (blue) for the Patient role.
G. The RoleBanner component SHALL use color code #4CAF50 (green) for the Investigator role.
H. The RoleBanner component SHALL use color code #9C27B0 (purple) for the Sponsor role.
I. The RoleBanner component SHALL use color code #FF9800 (orange) for the Auditor role.
J. The RoleBanner component SHALL use color code #009688 (teal) for the Analyst role.
K. The RoleBanner component SHALL use color code #F44336 (red) for the Administrator role.
L. The RoleBanner component SHALL use color code #C62828 (dark red) for the Developer Admin role.
M. The text contrast between the white text and background color SHALL meet WCAG AA standards with a minimum contrast ratio of 4.5:1.
N. The RoleBanner component SHALL be included in the core platform codebase for use across all sponsor portals.

*End* *Role-Based Banner Component* | **Hash**: 49f5f38e
---

# REQ-d00030: Portal Routing and Navigation

**Level**: Dev | **Status**: Draft | **Implements**: p00009

## Rationale

This requirement establishes the routing architecture for the portal web application, ensuring secure navigation based on authentication state and user roles. Declarative routing with go_router provides type-safe navigation and deep linking support, which is critical for clinical trial portal usability. Role-based route guards enforce the principle of least privilege required by FDA 21 CFR Part 11, ensuring users can only access functionality appropriate to their assigned role (Admin, Investigator, or Auditor). Automatic redirects based on authentication state protect sensitive clinical data by preventing unauthorized access and providing clear user feedback when access is denied. The routing structure supports both security requirements from REQ-p00009 and maintains a positive user experience through standard browser navigation behaviors.

## Assertions

A. The portal SHALL implement declarative routing using the go_router package.
B. The portal SHALL define a route structure consisting of: root (/), /login, /admin, /investigator, /auditor, and /unauthorized paths.
C. The portal SHALL redirect unauthenticated users to the /login route when attempting to access any protected route.
D. The portal SHALL redirect authenticated users from the /login route to their role-specific dashboard.
E. The portal SHALL redirect authenticated users with Admin role from /login to the /admin route.
F. The portal SHALL redirect authenticated users with Investigator role from /login to the /investigator route.
G. The portal SHALL redirect authenticated users with Auditor role from /login to the /auditor route.
H. The portal SHALL redirect authenticated users without a recognized role from /login to the /unauthorized route.
I. The portal SHALL prevent access to the /admin route for users without the Admin role.
J. The portal SHALL prevent access to the /investigator route for users without the Investigator role.
K. The portal SHALL prevent access to the /auditor route for users without the Auditor role.
L. The portal SHALL redirect users attempting unauthorized access to role-specific routes to the /unauthorized route.
M. The portal SHALL display the UnauthorizedPage component when users access the /unauthorized route.
N. The portal SHALL support browser back button functionality correctly within the routing system.
O. The portal SHALL preserve the intended destination route and redirect users to it after successful login (deep linking support).

*End* *Portal Routing and Navigation* | **Hash**: 80b2e394
---

## Authentication & Authorization Requirements

# REQ-d00031: Identity Platform Integration

**Level**: Dev | **Status**: Draft | **Implements**: p00009, p00038, p00028

## Rationale

This requirement defines the authentication architecture for the portal application. Identity Platform (Firebase Authentication) provides enterprise-grade OAuth integration with Google and Microsoft, along with email/password authentication. The SDK automatically handles session management, token refresh, and secure credential storage, reducing implementation complexity while maintaining FDA 21 CFR Part 11 compliance for user authentication and audit trails. The requirement implements product requirements for authentication (p00009), user management (p00038), and security controls (p00028).

## Assertions

A. The portal SHALL use Firebase Identity Platform as the authentication provider.
B. The system SHALL support Google Workspace OAuth 2.0 authentication.
C. The system SHALL support Microsoft 365 OAuth 2.0 authentication.
D. The system SHALL support email/password authentication via Identity Platform.
E. The system SHALL require email verification for email/password signups.
F. The system SHALL initialize Firebase with configuration from environment variables (FIREBASE_API_KEY, FIREBASE_AUTH_DOMAIN, GCP_PROJECT_ID, FIREBASE_APP_ID).
G. The system SHALL store JWT tokens using Identity Platform SDK's browser localStorage implementation.
H. The system SHALL automatically refresh authentication tokens via the Identity Platform SDK.
I. The system SHALL persist user sessions across browser refresh.
J. The API client SHALL include the Firebase authentication token in the Authorization header as a Bearer token for all authenticated requests.
K. The authentication provider SHALL listen for Firebase auth state changes and update application state accordingly.
L. The authentication provider SHALL fetch user role information from the /api/portal/me endpoint after successful authentication.
M. The system SHALL expose user authentication state (authenticated/unauthenticated) to the application.
N. The system SHALL expose user role information to the application after authentication.
O. The logout function SHALL clear Firebase authentication state.
P. The logout function SHALL clear user role information from application state.
Q. The system SHALL configure authorized domains in GCP Identity Platform Console to include the Cloud Run URL and custom domain.
R. The API client SHALL return parsed JSON response bodies for successful requests (status 200, 201).
S. The API client SHALL throw an exception with the HTTP status code for failed requests.

*End* *Identity Platform Integration* | **Hash**: 96139a3c
---

# REQ-d00032: Role-Based Access Control Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p00038, p00028

## Rationale

This requirement establishes role-based access control for the clinical trial portal system to ensure appropriate data segregation and authorization. The RBAC implementation supports three distinct user roles (Admin, Investigator, Auditor) with specific permissions aligned to their responsibilities in the clinical trial workflow. This supports compliance with 21 CFR Part 11 requirements for access controls and audit trails. The system uses a defense-in-depth approach with both UI-level routing guards and server-side row-level security policies to prevent unauthorized access.

## Assertions

A. The system SHALL enforce role-based access control using exactly three roles: Admin, Investigator, and Auditor.
B. The system SHALL store user roles in the portal_users.role column using an enum type.
C. The system SHALL retrieve the user role from the portal_users table after authentication.
D. The system SHALL implement router guards that check user role before rendering UI components.
E. The system SHALL enforce role-based data access using database row-level security policies.
F. The system SHALL filter all API queries by role using server-side RLS policies enforced by the Cloud Run API.
G. The AuthProvider SHALL provide user identity, role, and loading state to the application.
H. The system SHALL protect all dashboard routes by role authorization.
I. The system SHALL display a 403 error page when a user attempts unauthorized access.
J. Admin users SHALL be permitted to view all users.
K. Admin users SHALL be permitted to create Investigator and Auditor users.
L. Admin users SHALL be permitted to view patient data across all sites.
M. Admin users SHALL be permitted to revoke investigator and auditor tokens.
N. Admin users SHALL be permitted to access all dashboards.
O. Investigator users SHALL be permitted to generate linking codes.
P. Investigator users SHALL be permitted to enroll patients only at their own sites.
Q. Investigator users SHALL be permitted to view patient data only from their own sites.
R. Investigator users SHALL be permitted to send questionnaires only to patients at their own sites.
S. Investigator users SHALL be permitted to revoke patient tokens only for their own sites.
T. Investigator users SHALL be permitted to generate monthly reports.
U. Auditor users SHALL be permitted to view all users.
V. Auditor users SHALL be permitted to view patient data across all sites.
W. Auditor users SHALL be permitted to export the database.
X. Investigator users SHALL NOT be permitted to view all users.
Y. Investigator users SHALL NOT be permitted to create users.
Z. Auditor users SHALL NOT be permitted to create users, generate linking codes, enroll patients, send questionnaires, revoke tokens, or generate reports.

*End* *Role-Based Access Control Implementation* | **Hash**: 9d9a502a
---

# REQ-d00033: Site-Based Data Isolation

**Level**: Dev | **Status**: Draft | **Implements**: p00009, d00016

## Rationale

This requirement implements site-based data segregation for clinical trial investigators, ensuring that each investigator can only access patient data from sites they are explicitly assigned to. This isolation is critical for multi-site clinical trials to maintain data privacy, prevent unauthorized access across sites, and comply with FDA 21 CFR Part 11 requirements for access controls. The requirement supports PRD requirement p00009 (site-based access control) and dev requirement d00016 (RLS policy infrastructure). Site assignment is managed through a user_site_access mapping table, with enforcement at both the database layer (via Row-Level Security policies) and UI layer (via filtered queries). Administrators require elevated privileges to view cross-site data for oversight purposes.

## Assertions

A. The system SHALL enforce site-based data isolation such that investigators can only view and manage patients from their explicitly assigned sites.
B. The system SHALL maintain a user_site_access table that maps user_id to site_id relationships.
C. The user_site_access table SHALL enforce referential integrity through foreign key constraints to users and sites tables.
D. The investigator dashboard SHALL display a 'My Sites' section showing only sites assigned to the current investigator.
E. Patient list queries in the investigator dashboard SHALL be filtered to return only patients whose site_id matches the investigator's assigned sites.
F. The enrollment dialog SHALL display only sites from the investigator's assigned sites in the site selection dropdown.
G. The patients table SHALL implement a Row-Level Security policy named 'investigators_own_sites_patients' that restricts SELECT operations to patients from the investigator's assigned sites.
H. The RLS policy SHALL verify that current_setting('app.role', true) equals 'investigator' before applying site-based filtering.
I. The RLS policy SHALL filter patients by checking that site_id exists in the user_site_access table for the current user identified by current_setting('app.user_id', true)::uuid.
J. The Cloud Run API SHALL set session variables app.role and app.user_id from the Identity Platform authentication token before executing database queries.
K. The system SHALL prevent investigators from accessing patient data across sites not explicitly assigned to them through the RLS policy.
L. The system SHALL allow administrators to view patients from all sites by bypassing the investigator RLS policy.
M. UI queries SHALL NOT implement site filtering logic that could be bypassed, relying instead on server-side RLS enforcement for security.

*End* *Site-Based Data Isolation* | **Hash**: 2eff596e
---

## Frontend Components Requirements

# REQ-d00034: Login Page Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p00009, d00031

## Rationale

This requirement defines the user interface and interaction patterns for the authentication entry point of the clinical trial portal. The login page serves as the initial access control mechanism, supporting multiple authentication methods (OAuth and traditional email/password) to accommodate diverse organizational security policies. The implementation must provide clear visual feedback during authentication operations and gracefully handle error conditions to ensure users understand the system state. This requirement implements the authentication user experience portion of the broader security architecture defined in REQ-p00009 and builds upon the technical authentication infrastructure specified in REQ-d00031.

## Assertions

A. The system SHALL provide a login page accessible at the route '/login'.
B. The login page SHALL include a button labeled 'Continue with Google' that triggers Google OAuth authentication.
C. The login page SHALL include a button labeled 'Continue with Microsoft' that triggers Microsoft OAuth authentication.
D. The login page SHALL include an email input field for email/password authentication.
E. The login page SHALL include a password input field for email/password authentication.
F. The login page SHALL include a 'Sign In' button that triggers email/password authentication.
G. The login page SHALL use a centered card layout with maximum width constraint of 400 pixels.
H. The login page SHALL display the title 'Clinical Trial Portal' using the theme's displayMedium text style.
I. The login page SHALL display the subtitle 'Sign in to access your dashboard' using the theme's bodyMedium text style.
J. The system SHALL validate email and password input before submission.
K. The system SHALL disable all authentication buttons during an active authentication operation.
L. The system SHALL display a loading indicator on the 'Sign In' button during email/password authentication.
M. The system SHALL display error messages via SnackBar when authentication fails.
N. The system SHALL dispose of text input controllers when the login page is removed from the widget tree.
O. The system SHALL redirect authenticated users to their role-specific dashboard upon successful login.
P. The login page SHALL separate OAuth options from email/password authentication with a visual divider.
Q. The system SHALL invoke AuthProvider.signInWithGoogle() when the Google OAuth button is activated.
R. The system SHALL invoke AuthProvider.signInWithMicrosoft() when the Microsoft OAuth button is activated.
S. The system SHALL invoke AuthProvider.signInWithEmail() with trimmed email and password when the email login is submitted.
T. The system SHALL check widget mount state before displaying error messages or updating loading state after asynchronous operations.

*End* *Login Page Implementation* | **Hash**: 64108d53
---

# REQ-d00035: Admin Dashboard Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p00009

## Rationale

This requirement specifies the Admin dashboard implementation for portal user management. The dashboard enables Admins to view all portal users, create new Investigators with site assignments, monitor system usage through summary metrics, and revoke investigator access when necessary. This implements the higher-level product requirement REQ-p00009 for administrative user management capabilities. The dashboard provides a centralized interface for user administration tasks essential for clinical trial site management and investigator oversight.

## Assertions

A. The system SHALL provide an Admin dashboard accessible at route '/admin'.
B. The system SHALL restrict access to the Admin dashboard to users with Admin role only.
C. The dashboard SHALL display a user management table showing all portal users.
D. The user management table SHALL display user name, email, role, and site assignments for each user.
E. The dashboard SHALL provide a 'Create New User' button that opens a modal dialog.
F. The system SHALL display summary cards showing Investigator count, total users count, and user statistics.
G. The dashboard SHALL display role badges that are color-coded with Admin in red and Investigator in grey.
H. The dashboard SHALL display site assignments for investigators showing site numbers.
I. The system SHALL provide a revoke button for investigator accounts that initiates token revocation.
J. The system SHALL display a confirmation dialog before revoking investigator access.
K. The system SHALL update investigator status to 'revoked' when access is revoked.
L. The system SHALL log out investigators and prevent portal access after token revocation.
M. The system SHALL display a success notification after successfully revoking investigator access.
N. The system SHALL display an error notification if token revocation fails.
O. The system SHALL reload the user list after successful user creation or token revocation.
P. The system SHALL display a loading indicator while fetching user data.
Q. The system SHALL fetch user data from endpoint '/api/portal/users'.
R. The system SHALL handle API errors gracefully and display error messages to the user.
S. The dashboard layout SHALL be responsive on desktop and tablet screen sizes.
T. The dashboard SHALL match the approved portal mockup design.

*End* *Admin Dashboard Implementation* | **Hash**: 733c97d1
---

# REQ-d00036: Create User Dialog Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p00038

## Rationale

This requirement defines the administrative interface for creating new portal users (Investigators and Auditors) in the clinical trial system. Admins need a streamlined workflow to onboard new staff members, assign them to appropriate clinical sites, and generate secure device linking codes for Investigators to enroll their mobile devices. The linking code mechanism enables secure pairing between the investigator's identity and their device without requiring complex authentication flows during initial setup. Role-based field visibility ensures Auditors (who only need read access to portal data) are not burdened with irrelevant site assignments or device enrollment steps. This implements the user management functionality defined in the product requirements (REQ-p00038).

## Assertions

A. The system SHALL provide a modal dialog triggered by a "Create New User" button on the Admin dashboard.
B. The dialog SHALL include a Name field implemented as a required text input.
C. The dialog SHALL include an Email field implemented as a required email input with format validation.
D. The dialog SHALL include a Role field implemented as a dropdown with options "Investigator" and "Auditor".
E. The dialog SHALL display a Sites field as multi-checkbox selection only when the Investigator role is selected.
F. The system SHALL require at least one site selection when the Investigator role is selected.
G. The dialog SHALL display a Linking Code field as read-only text only when the Investigator role is selected.
H. The system SHALL auto-generate a linking code in XXXXX-XXXXX format when the dialog opens for an Investigator.
I. Linking codes SHALL use only non-ambiguous characters from the set ABCDEFGHJKLMNPQRSTUVWXYZ23456789, excluding 0, O, 1, and I.
J. The system SHALL use a cryptographically secure random number generator for linking code generation.
K. The dialog SHALL provide a copy button that copies the linking code to the clipboard.
L. The system SHALL validate that the Name field is not empty before form submission.
M. The system SHALL validate that the Email field is not empty and contains an '@' character before form submission.
N. The system SHALL prevent form submission if validation fails.
O. The system SHALL create a portal_users record upon successful form submission.
P. The system SHALL set the linking_code field in portal_users only when creating an Investigator.
Q. The system SHALL set the linking_code field to null when creating an Auditor.
R. The system SHALL create user_site_access records for each selected site only when creating an Investigator.
S. The system SHALL prevent creation of a user with a duplicate email address.
T. The system SHALL display a success message containing the linking code after creating an Investigator.
U. The system SHALL display a success message without a linking code after creating an Auditor.
V. The system SHALL close the dialog after successful user creation.
W. The system SHALL refresh the user table after successful user creation via the onUserCreated callback.
X. The system SHALL display an error message if user creation fails.
Y. The system SHALL show a loading indicator on the submit button while user creation is in progress.
Z. The system SHALL disable the Cancel and Submit buttons while user creation is in progress.

*End* *Create User Dialog Implementation* | **Hash**: 619ef6f4
---

# REQ-d00037: Investigator Dashboard Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p00040, p00027

## Rationale

This requirement defines the Investigator Dashboard user interface, which serves as the primary workspace for clinical investigators to monitor patient participation, manage questionnaires, and oversee trial activities at their assigned sites. The dashboard provides real-time visibility into patient engagement through status indicators and data entry tracking, enabling investigators to identify patients requiring follow-up intervention. The interface enforces role-based access control through Row-Level Security (RLS), ensuring investigators can only view and manage patients enrolled at their authorized sites. This access restriction is critical for maintaining data privacy and regulatory compliance in multi-site clinical trials.

## Assertions

A. The system SHALL provide an Investigator dashboard accessible at route '/investigator'.
B. The system SHALL restrict dashboard access to users with the Investigator role through RLS enforcement.
C. The dashboard SHALL display a 'My Sites' section showing all sites assigned to the current investigator.
D. The dashboard SHALL display a Patient Summary table containing patient ID, site, status, days without data, last login, and questionnaire states.
E. The Patient Summary table SHALL display only patients enrolled at sites where the investigator has authorized access, enforced through RLS.
F. The system SHALL calculate patient status as 'recent' when last data entry occurred within 3 days, 'warning' when 4-7 days, 'atRisk' when more than 7 days, and 'noData' when no data entry exists.
G. The system SHALL display status badges color-coded as green for 'recent', orange for 'warning', red for 'atRisk', and grey for 'noData'.
H. The system SHALL calculate and display days without data as the number of days elapsed since the patient's last data entry.
I. The system SHALL display last login time using relative time formatting (e.g., '2 days ago').
J. The dashboard SHALL display three summary cards showing Total Patients, Active Today, and Requires Follow-up counts.
K. The system SHALL calculate 'Active Today' as the count of patients with data entry on the current day.
L. The system SHALL calculate 'Requires Follow-up' as the count of patients with no data entry or last data entry more than 7 days ago.
M. The dashboard SHALL provide an 'Enroll New Patient' button that opens a patient enrollment dialog.
N. The enrollment dialog SHALL generate a patient linking code upon successful enrollment.
O. The dashboard SHALL display questionnaire status for NOSE HHT and QoL questionnaires for each patient.
P. The system SHALL provide a 'Send' button for questionnaires with status 'not_sent' or null.
Q. The system SHALL display a 'Pending' badge and 'Resend' button for questionnaires with status 'sent'.
R. The system SHALL display completion date, 'Completed' badge, and 'Acknowledge' button for questionnaires with status 'completed'.
S. The system SHALL send questionnaires via POST request to '/api/portal/questionnaires/send' with patient_id and questionnaire type parameters.
T. The system SHALL acknowledge questionnaires via POST request to '/api/portal/questionnaires/acknowledge' with patient_id and questionnaire type parameters.
U. The dashboard SHALL provide a 'Generate Monthly Report' button that triggers monthly report generation.
V. The dashboard SHALL provide an unenroll action for each patient that revokes the patient's access token.
W. The system SHALL display a confirmation dialog before unenrolling a patient, warning that the patient will lose access to trial data.
X. The system SHALL update patient status to 'unenrolled' via PATCH request to '/api/portal/patients/{patientId}' when unenrollment is confirmed.
Y. The system SHALL display success or error notifications to the investigator after questionnaire actions and patient enrollment operations.
Z. The dashboard layout SHALL be responsive and functional on desktop and tablet screen sizes.

*End* *Investigator Dashboard Implementation* | **Hash**: f8e9c137
---

# REQ-d00038: Enroll Patient Dialog Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p00039

## Rationale

This requirement defines the Enroll Patient dialog component that enables investigators to initiate patient enrollment in the clinical trial. The dialog generates a secure linking code that patients use to self-enroll via the mobile app, maintaining a clear separation between investigator actions (code generation) and patient actions (enrollment completion). This approach supports FDA 21 CFR Part 11 compliance by ensuring patient identity is established through the mobile app enrollment flow rather than investigator-entered data. The linking code format and character set are designed to minimize transcription errors during manual entry.

## Assertions

A. The system SHALL provide a modal dialog accessible via an 'Enroll Patient' button on the Investigator dashboard.
B. The dialog SHALL display a site dropdown field populated only with sites assigned to the current investigator.
C. The dialog SHALL auto-generate a 10-character linking code in format XXXXX-XXXXX when the dialog opens.
D. The linking code generator SHALL use only non-ambiguous characters from the set 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.
E. The dialog SHALL display the linking code in a read-only text field.
F. The dialog SHALL provide a copy button that copies the linking code to the system clipboard.
G. The dialog SHALL require site selection before allowing form submission.
H. The dialog SHALL display a validation error message when submission is attempted without site selection.
I. The system SHALL verify linking code uniqueness before creating the patient record.
J. The system SHALL create a patients record with status 'pending_enrollment' when the form is submitted.
K. The system SHALL create initial questionnaire records (NOSE_HHT and QoL) when the patient record is created.
L. The dialog SHALL display a success message containing the linking code after successful enrollment preparation.
M. The success message SHALL remain visible for at least 5 seconds.
N. The dialog SHALL close automatically after successful enrollment preparation.
O. The system SHALL refresh the patient table after the dialog closes from successful enrollment.
P. The dialog SHALL display an error message if enrollment preparation fails.
Q. The dialog SHALL provide a Cancel button that closes the dialog without creating records.
R. The dialog SHALL disable form controls and display a loading indicator during submission processing.
S. The dialog SHALL match the approved portal mockup design specifications.
T. The dialog component file SHALL be located at lib/dialogs/enroll_patient_dialog.dart.

*End* *Enroll Patient Dialog Implementation* | **Hash**: 7c62bbb7
---

# REQ-d00051: Auditor Dashboard Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p00029

## Rationale

This requirement defines the Auditor dashboard implementation to support FDA 21 CFR Part 11 compliance auditing activities. Auditors need comprehensive read-only visibility across all portal data (users, patients, sites, questionnaires) to perform regulatory compliance reviews and verify data integrity. The dashboard consolidates multi-site data into a single view while preventing any data modification through strictly read-only access controls enforced by Row-Level Security policies. The stubbed export function provides a placeholder for future compliance reporting capabilities.

## Assertions

A. The system SHALL provide a dashboard accessible at the route '/auditor'.
B. The dashboard SHALL be accessible only to users with the Auditor role, enforced via RLS policies.
C. The dashboard SHALL display read-only views of all portal users across all sites.
D. The dashboard SHALL display read-only views of all patients across all sites.
E. The dashboard SHALL display read-only views of all sites.
F. The dashboard SHALL display questionnaire status information for all patients.
G. The dashboard SHALL include an 'Export Database' button visible in the application bar.
H. The 'Export Database' button SHALL display a 'Database export coming soon' message when activated.
I. The dashboard SHALL NOT provide any create, update, or delete actions for data modification.
J. The dashboard SHALL display an 'AUDIT MODE' indicator to clearly identify the read-only audit context.
K. The dashboard SHALL display summary cards showing the total count of users.
L. The dashboard SHALL display summary cards showing the total count of patients.
M. The dashboard SHALL display summary cards showing the total count of sites.
N. The dashboard SHALL display summary cards showing the total count of investigators.
O. The users table SHALL display user name, email, role, site assignments, status, and creation date.
P. The patients table SHALL display patient ID, site assignment, enrollment status, enrollment date, days without data entry, last login time, NOSE HHT questionnaire status, and QoL questionnaire status.
Q. RLS policies SHALL allow Auditor role read access to all users via the '/api/portal/users' endpoint.
R. RLS policies SHALL allow Auditor role read access to all patients via the '/api/portal/patients' endpoint.
S. RLS policies SHALL allow Auditor role read access to all sites via the '/api/portal/sites' endpoint.
T. The dashboard SHALL load user, patient, and site data concurrently during initialization.
U. The dashboard SHALL display a loading indicator while data is being retrieved.
V. Summary card counts SHALL accurately reflect the loaded data.
W. The dashboard SHALL provide a logout action accessible from the application bar.

*End* *Auditor Dashboard Implementation* | **Hash**: ed881a6b
---

## Database Schema Requirements

# REQ-d00039: Portal Users Table Schema

**Level**: Dev | **Status**: Draft | **Implements**: p00009, d00016

## Rationale

This requirement defines the database schema for portal user accounts in the clinical trial system. The table stores user identity, roles, and enrollment linking codes to support authentication via Firebase Identity Platform and device enrollment workflows. Row-level security policies enforce role-based access control, ensuring Admins have full access, Investigators can only view their own records, and Auditors have read-only visibility. The schema supports the user lifecycle from creation through device enrollment to potential revocation.

## Assertions

A. The portal database SHALL include a table named `portal_users` to store portal user accounts.
B. The system SHALL create a PostgreSQL enum type `user_role` with values ('Admin', 'Investigator', 'Auditor').
C. The `portal_users` table SHALL include an `id` column as UUID primary key with default value `gen_random_uuid()`.
D. The `portal_users` table SHALL include a `firebase_uid` column as TEXT with UNIQUE constraint, nullable until user enrolls.
E. The `portal_users` table SHALL include an `email` column as TEXT that is NOT NULL and UNIQUE.
F. The `portal_users` table SHALL include a `name` column as TEXT that is NOT NULL.
G. The `portal_users` table SHALL include a `role` column of type `user_role` that is NOT NULL.
H. The `portal_users` table SHALL include a `linking_code` column as TEXT with UNIQUE constraint for device enrollment.
I. The `portal_users` table SHALL include a `status` column as TEXT that is NOT NULL with default value 'active'.
J. The `portal_users` table SHALL include a `created_at` column as TIMESTAMPTZ that is NOT NULL with default value `now()`.
K. The `portal_users` table SHALL include an `updated_at` column as TIMESTAMPTZ that is NOT NULL with default value `now()`.
L. The system SHALL create an index `idx_portal_users_firebase_uid` on the `firebase_uid` column for fast role lookup.
M. The system SHALL create an index `idx_portal_users_email` on the `email` column for email lookups.
N. The system SHALL create an index `idx_portal_users_linking_code` on the `linking_code` column for mobile app lookups.
O. The system SHALL enable row-level security on the `portal_users` table.
P. The system SHALL create an RLS policy `admins_auditors_see_all_users` that allows users with role 'Admin' or 'Auditor' to SELECT all rows.
Q. The system SHALL create an RLS policy `users_see_themselves` that allows Investigators to SELECT only rows where `firebase_uid` matches their user ID.
R. The system SHALL create an RLS policy `admins_insert_users` that allows only users with role 'Admin' to INSERT rows.
S. The system SHALL create an RLS policy `admins_update_users` that allows only users with role 'Admin' to UPDATE rows.

*End* *Portal Users Table Schema* | **Hash**: ab792ed7
---

# REQ-d00040: User Site Access Table Schema

**Level**: Dev | **Status**: Draft | **Implements**: p00009, d00033

## Rationale

This requirement defines the database schema for managing site-level access assignments in the clinical trial portal. The user_site_access table enables investigators to be assigned to specific trial sites, supporting data isolation requirements from REQ-p00009 and REQ-d00033. The schema includes referential integrity constraints, performance indexes, and row-level security policies that enforce role-based access control using application-set session variables. This design ensures that investigators can only access data for sites they are assigned to, while administrators and auditors maintain broader visibility for their respective functions.

## Assertions

A. The system SHALL include a user_site_access table in the portal database.
B. The user_site_access table SHALL include an id column as UUID primary key with default value gen_random_uuid().
C. The user_site_access table SHALL include a user_id column as UUID NOT NULL with foreign key constraint to portal_users(id) with ON DELETE CASCADE.
D. The user_site_access table SHALL include a site_id column as UUID NOT NULL with foreign key constraint to sites(id) with ON DELETE CASCADE.
E. The user_site_access table SHALL include an assigned_at column as TIMESTAMPTZ NOT NULL with default value now().
F. The user_site_access table SHALL enforce a UNIQUE constraint on the combination of user_id and site_id.
G. The system SHALL create an index named idx_user_site_access_user on user_site_access(user_id).
H. The system SHALL create an index named idx_user_site_access_site on user_site_access(site_id).
I. The system SHALL enable row level security on the user_site_access table.
J. The system SHALL create a policy named admins_auditors_see_all_site_access that allows SELECT access when current_setting('app.role', true) is 'Admin' or 'Auditor'.
K. The system SHALL create a policy named users_see_own_site_access that allows SELECT access when user_id matches current_setting('app.user_id', true)::uuid.
L. The system SHALL create a policy named admins_insert_site_access that allows INSERT access when current_setting('app.role', true) is 'Admin'.
M. The system SHALL automatically delete user_site_access records when the referenced portal_users record is deleted.
N. The system SHALL automatically delete user_site_access records when the referenced sites record is deleted.

*End* *User Site Access Table Schema* | **Hash**: f6e3af89
---

# REQ-d00041: Patients Table Extensions for Portal

**Level**: Dev | **Status**: Draft | **Implements**: p00009

## Rationale

This requirement extends the patients table to support the patient enrollment workflow in the portal, where investigators generate linking codes that patients use to connect their mobile app. The extensions track enrollment lifecycle (code generation, app linking, ongoing engagement) and enforce site-based access control. The status field transitions from pending_enrollment (code generated) to enrolled (patient linked app) to unenrolled (access revoked). Row-level security policies ensure investigators can only interact with patients at their assigned sites, while admins and auditors have broader access. This implements the enrollment and access control aspects of the portal functionality defined in PRD p00009.

## Assertions

A. The system SHALL extend the patients table with a linking_code column of type TEXT with a UNIQUE constraint.
B. The system SHALL extend the patients table with an enrollment_date column of type TIMESTAMPTZ.
C. The system SHALL extend the patients table with a last_login_at column of type TIMESTAMPTZ.
D. The system SHALL extend the patients table with a last_data_entry_date column of type TIMESTAMPTZ.
E. The system SHALL extend the patients table with a mobile_app_linked_at column of type TIMESTAMPTZ.
F. The system SHALL extend the patients table with a status column of type TEXT with a default value of 'pending_enrollment'.
G. The status column SHALL support the values: 'pending_enrollment', 'enrolled', and 'unenrolled'.
H. The system SHALL create an index idx_patients_linking_code on the patients table linking_code column.
I. The system SHALL create an index idx_patients_status on the patients table status column.
J. The system SHALL create an index idx_patients_last_data_entry on the patients table last_data_entry_date column in descending order.
K. The system SHALL create an RLS policy 'investigators_own_sites_patients' for SELECT operations that allows users with app.role 'Admin' or 'Auditor' to view all patient records.
L. The system SHALL create an RLS policy 'investigators_own_sites_patients' for SELECT operations that allows users with app.role 'Investigator' to view only patients from sites assigned to them via user_site_access.
M. The system SHALL create an RLS policy 'investigators_insert_own_sites_patients' for INSERT operations that allows users with app.role 'Admin' to insert patient records at any site.
N. The system SHALL create an RLS policy 'investigators_insert_own_sites_patients' for INSERT operations that allows users with app.role 'Investigator' to insert patient records only at sites assigned to them via user_site_access.
O. The system SHALL create an RLS policy 'investigators_update_own_sites_patients' for UPDATE operations that allows users with app.role 'Admin' to update all patient records.
P. The system SHALL create an RLS policy 'investigators_update_own_sites_patients' for UPDATE operations that allows users with app.role 'Investigator' to update only patients from sites assigned to them via user_site_access.
Q. The linking_code column SHALL store unique 10-character codes in the format XXXXX-XXXXX.
R. The enrollment_date column SHALL store the timestamp when the linking code is generated by an investigator.
S. The last_login_at column SHALL store the timestamp of the patient's last mobile app login.
T. The last_data_entry_date column SHALL store the timestamp of the patient's last diary entry.
U. The mobile_app_linked_at column SHALL store the timestamp when the patient successfully linked the mobile app using the linking code.

*End* *Patients Table Extensions for Portal* | **Hash**: f12125f3
---

# REQ-d00042: Questionnaires Table Schema

**Level**: Dev | **Status**: Draft | **Implements**: p00009

## Rationale

This requirement defines the database schema for tracking questionnaire status (NOSE HHT and QoL questionnaires) for each patient in the clinical trial. The schema supports the questionnaire lifecycle workflow where investigators send questionnaires to patients via mobile app, patients complete them, and investigators acknowledge completion. The status flow cycles through not_sent → sent → completed → not_sent to enable repeated questionnaire administrations. Row-level security policies ensure site-based data isolation per FDA compliance requirements. The schema supports REQ-p00009 which defines the questionnaire management feature requirements.

## Assertions

A. The system SHALL include a questionnaires table in the portal database.
B. The system SHALL define a questionnaire_type ENUM with values 'NOSE_HHT' and 'QoL'.
C. The system SHALL define a questionnaire_status ENUM with values 'not_sent', 'sent', and 'completed'.
D. The questionnaires table SHALL include an id column as UUID primary key with default value gen_random_uuid().
E. The questionnaires table SHALL include a patient_id column as UUID NOT NULL with foreign key reference to patients(id) with ON DELETE CASCADE.
F. The questionnaires table SHALL include a type column as questionnaire_type NOT NULL.
G. The questionnaires table SHALL include a status column as questionnaire_status NOT NULL with default value 'not_sent'.
H. The questionnaires table SHALL include sent_at, completed_at, last_completion_date, and acknowledged_at columns as TIMESTAMPTZ.
I. The questionnaires table SHALL include created_at and updated_at columns as TIMESTAMPTZ NOT NULL with default value now().
J. The questionnaires table SHALL enforce a UNIQUE constraint on (patient_id, type) to prevent duplicate questionnaire records per patient.
K. The system SHALL create an index idx_questionnaires_patient on questionnaires(patient_id) for fast patient lookups.
L. The system SHALL create an index idx_questionnaires_status on questionnaires(status) for status-based queries.
M. The questionnaires table SHALL have row-level security enabled.
N. The system SHALL create a SELECT policy 'investigators_own_sites_questionnaires' that allows investigators to view questionnaires only for patients at their sites.
O. The system SHALL create an UPDATE policy 'investigators_update_own_sites_questionnaires' that allows investigators to update questionnaires only for patients at their sites.
P. The system SHALL create an INSERT policy 'investigators_insert_own_sites_questionnaires' that allows investigators to insert questionnaires only for patients at their sites.
Q. The system SHALL create a trigger function update_questionnaires_updated_at() that sets updated_at to now() on every row update.
R. The system SHALL create a BEFORE UPDATE trigger 'questionnaires_updated_at' on the questionnaires table that executes update_questionnaires_updated_at() for each row.
S. The system SHALL cascade delete questionnaire records when the associated patient record is deleted.

*End* *Questionnaires Table Schema* | **Hash**: 353a9b0a
---

## Deployment Requirements

# REQ-d00043: Cloud Run Deployment Configuration

**Level**: Dev | **Status**: Draft | **Implements**: o00009

## Rationale

This requirement defines the deployment architecture for the portal web application using Google Cloud Platform services. Cloud Run provides serverless container hosting with automatic scaling, while Cloud Build enables continuous deployment from the main branch. The multi-stage Docker build optimizes container size by separating the Flutter build environment from the nginx runtime environment. Sponsor isolation is maintained through separate GCP projects, each with unique Firebase configurations and custom domains. The nginx configuration ensures proper single-page application routing and implements security best practices including CSP headers, frame protection, and content type enforcement to protect against common web vulnerabilities.

## Assertions

A. The system SHALL deploy the portal to Google Cloud Run as a containerized web service.
B. The system SHALL build the Flutter web application using the command 'flutter build web --release --web-renderer html'.
C. The system SHALL use a multi-stage Docker build with Flutter stable image for building and nginx alpine image for serving.
D. The Dockerfile SHALL accept build arguments for FIREBASE_API_KEY, FIREBASE_AUTH_DOMAIN, GCP_PROJECT_ID, FIREBASE_APP_ID, and API_BASE_URL.
E. The Dockerfile SHALL pass Firebase and API configuration to Flutter build via --dart-define parameters.
F. The nginx container SHALL listen on port 8080.
G. The nginx configuration SHALL serve index.html for all routes to support SPA routing using 'try_files $uri $uri/ /index.html'.
H. The nginx configuration SHALL set X-Frame-Options header to 'DENY'.
I. The nginx configuration SHALL set X-Content-Type-Options header to 'nosniff'.
J. The nginx configuration SHALL set Referrer-Policy header to 'strict-origin-when-cross-origin'.
K. The nginx configuration SHALL set Permissions-Policy header to disable geolocation, microphone, and camera.
L. The nginx configuration SHALL configure Content-Security-Policy headers restricting script, style, image, font, and connection sources.
M. The nginx configuration SHALL enable gzip compression for text/plain, text/css, application/json, application/javascript, text/xml, and application/xml content types.
N. The system SHALL store container images in Google Artifact Registry within the sponsor's GCP project.
O. Cloud Build SHALL trigger automatic deployments on push to the main branch.
P. Each sponsor SHALL have a separate Cloud Run service deployed in their dedicated GCP project.
Q. Each sponsor deployment SHALL use sponsor-specific environment variables for Firebase and API configuration.
R. The system SHALL support custom domain configuration for each sponsor with SSL certificates.
S. Cloud Build authentication SHALL use Workload Identity Federation for GitHub integration.

*End* *Cloud Run Deployment Configuration* | **Hash**: 5a86d9bd
---

## Summary

This development specification defines the technical implementation requirements for the Clinical Trial Web Portal, a **Flutter web application** (separate from patient diary mobile app) with role-based dashboards (Admin, Investigator), site-level data isolation, and patient enrollment/questionnaire management.

**Key Technologies**:
- Flutter 3.24+ for web
- Dart 3.10+
- Identity Platform / Identity Platform (OAuth + email/password)
- Cloud SQL PostgreSQL with RLS policies
- Cloud Run API (Dart server with HTTP client)
- Cloud Run deployment (nginx container)

**Simplified Scope**:
- **Two roles only**: Admin, Investigator (no Auditor/Analyst)
- **Essential features**: Login, user management, patient enrollment, questionnaire management, token revocation, monthly reports
- **No diary viewing**: Patient diaries viewed in 3rd party EDC
- **No event viewer**: Event sourcing at database level only
- **Separate app**: Independent from patient diary mobile app (may merge later for code reuse)

**Implementation Priority**:
1. **P1 (Critical)**: Auth, routing, Admin/Investigator dashboards, database schema, linking codes, token revocation
2. **P2 (High)**: Monthly report generation, testing
3. **P3 (Future)**: Merge with patient diary app for code reuse (if "Investigator Mode" on mobile is needed)

**Next Steps**:
1. Review this specification with stakeholders
2. Create Linear tickets for each REQ-d00xxx requirement
3. Set up Flutter development environment
4. Implement authentication and routing (REQ-d00030, d00031)
5. Build Admin dashboard (REQ-d00035, d00036)
6. Build Investigator dashboard (REQ-d00037, d00038)
7. Deploy to Cloud Run (REQ-d00043)

---

**Document Control**:
- **Created**: 2025-10-27
- **Author**: Claude Code
- **Status**: Draft (awaiting review)
- **Next Review**: After stakeholder feedback
