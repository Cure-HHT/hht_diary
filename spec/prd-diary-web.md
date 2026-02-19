# Web Diary Application

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-05
**Status**: Draft

> **See**: prd-diary-app.md for mobile diary application
> **See**: prd-system.md for platform overview
> **See**: prd-security.md for security architecture
> **See**: prd-architecture-multi-sponsor.md for multi-sponsor deployment model

---

## Executive Summary

The Web Diary is a browser-based companion to the Diary mobile application. It allows patients to access their diary from any computer when the mobile app is unavailable. Due to the inherently less secure nature of web access (shared computers, public terminals), the Web Diary implements strict session management and stores no data locally after logout.

**Key Differences from Mobile App**:

- No offline capability (requires constant internet connection)
- Automatic logout after inactivity
- No local data persistence
- Session terminates on browser close
- Authentication via linking code from Sponsor Portal

---

# REQ-p01042: Web Diary Application

**Level**: PRD | **Status**: Draft | **Implements**: p00043

## Rationale

This requirement provides an alternative access method for patients who cannot use the mobile app or prefer web access. Web access introduces different security considerations than mobile applications, such as shared or public computers and lack of device-level security controls. These differences necessitate stricter session management policies and prohibition of persistent local storage to protect patient privacy and comply with FDA 21 CFR Part 11 security requirements.

## Assertions

A. The system SHALL provide browser-based access to diary entry functionality.

B. The system SHALL support standard web browsers including Chrome, Firefox, Safari, and Edge.

C. The system SHALL automatically terminate sessions after a configurable period of inactivity.

D. The system SHALL completely terminate sessions when the browser or tab is closed.

E. The system SHALL NOT retain any patient data in the browser after logout.

F. The system SHALL NOT persist any local data after session termination.

G. The system SHALL integrate with the Sponsor Portal for authentication via linking codes.

H. The system SHALL apply sponsor-specific branding after successful authentication.

I. The system SHALL apply sponsor-specific configuration after successful authentication.

J. The system SHALL create a complete audit trail of all patient actions.

K. The system SHALL function as a companion to the mobile app, not as a replacement.

*End* *Web Diary Application* | **Hash**: a19f716f

---

# REQ-p01043: Web Diary Authentication via Linking Code

**Level**: PRD | **Status**: Draft | **Implements**: p01042

## Rationale

GDPR restrictions prevent use of Identity Platform and similar services that process personal data. A custom authentication system using linking codes maintains sponsor isolation (REQ-p00001) while avoiding PII collection. Linking codes establish the trust relationship between the patient and their clinical trial without requiring email verification. Pattern-based sponsor identification enables a single auth service to route users to the correct sponsor without requiring users to know which sponsor they belong to. This requirement extends REQ-p01042 by specifying the technical implementation of linking code authentication for the web diary.

## Assertions

A. The system SHALL authenticate patients to the Web Diary using a unique linking code obtained from the Sponsor Portal.

B. The system SHALL require username and password credentials created specifically for web access during authentication.

C. The system SHALL NOT use email addresses for authentication.

D. The system SHALL NOT use third-party authentication providers.

E. Linking codes SHALL contain embedded patterns identifying the sponsor.

F. The Diary Auth service SHALL maintain a mapping table of linking code patterns to Sponsor Portal URLs.

G. The mapping table SHALL be updated when sponsors deploy or decommission portals.

H. The system SHALL NOT collect personally identifiable information during authentication.

I. The system SHALL hash passwords before network transmission.

J. The authentication service SHALL validate credentials and return a session JWT upon successful authentication.

K. The system SHALL identify the sponsor based on linking code pattern matching without requiring user input.

L. The system SHALL route authenticated users to the correct Sponsor Portal URL based on pattern matching.

M. The system SHALL reject invalid linking codes with a clear error message.

N. The system SHALL reject unrecognized linking code patterns with guidance to contact the Sponsor.

O. Linking codes SHALL expire after a sponsor-configurable period.

P. Session JWTs SHALL be scoped to the authenticated sponsor.

Q. The system SHALL NOT store or process email addresses.

R. The authentication system SHALL function correctly across all supported browsers.

*End* *Web Diary Authentication via Linking Code* | **Hash**: 8c7d6240
---

# REQ-p01044: Web Diary Session Management

**Level**: PRD | **Status**: Draft | **Implements**: p01042

## Rationale

Web access to clinical trial diaries may occur on shared or public computers where the next user could access patient data if sessions persist. Aggressive session timeout and complete data clearing protect patient privacy in these environments. The short default timeout (2 minutes) reflects the sensitive nature of clinical trial data and balances security with usability. This requirement implements the session security provisions of REQ-p01042.

## Assertions

A. The system SHALL automatically terminate user sessions after a configured period of inactivity.

B. The default inactivity timeout SHALL be 2 minutes.

C. Sponsors SHALL be able to configure the inactivity timeout to any value between 1 and 30 minutes.

D. The system SHALL terminate the session when the browser window or tab is closed.

E. The system SHALL provide an explicit logout option that is always available to the user.

F. The inactivity timer SHALL reset on any user interaction including mouse movement, keystrokes, and touch events.

G. The system SHALL display a warning modal 30 seconds before automatic timeout occurs.

H. The warning modal SHALL display a countdown timer showing remaining seconds.

I. The system SHALL allow the user to extend the session from the warning modal.

J. The system SHALL clear all sessionStorage data on logout.

K. The system SHALL clear all localStorage data on logout.

L. The system SHALL clear all cookies on logout.

M. The system SHALL ensure no patient data is recoverable from the browser after logout.

N. The system SHALL prevent the browser back button from restoring the session after logout.

O. The system SHALL synchronize session timeout across multiple tabs for the same user.

P. The system SHALL NOT provide a 'remember me' option.

Q. The system SHALL NOT provide a persistent login option.

*End* *Web Diary Session Management* | **Hash**: 8264ceb9

---

# REQ-p01045: Web Diary Privacy Protection

**Level**: PRD | **Status**: Draft | **Implements**: p01042, p01043

## Rationale

Clinical trial participants have heightened privacy concerns. By explicitly avoiding email collection and displaying privacy messaging, the system builds trust while ensuring GDPR compliance. The @ restriction prevents users from accidentally using email addresses as usernames, reducing the risk of PII exposure. Clear messaging about password recovery limitations helps users understand the importance of securely storing their credentials and the privacy-preserving design of the authentication system.

## Assertions

A. The system SHALL NOT collect email addresses during account creation or login.

B. The system SHALL NOT store email addresses in the authentication system.

C. The system SHALL reject usernames containing the @ symbol.

D. The system SHALL display an error message when a username contains the @ symbol.

E. The system SHALL display the message 'For your privacy we do not use email addresses for accounts' during account creation.

F. The system SHALL display the message '@ signs are not allowed for username' during account creation.

G. The system SHALL display the message 'Store your username and password securely' during account creation.

H. The system SHALL display the message 'If you lose your username and password then the app cannot send you a link to reset it' during account creation.

I. The system SHALL display the message 'For a lost username and password, contact your Sponsor to obtain a new Linking Code' during account creation.

J. The system SHALL NOT collect biometric data.

K. The system SHALL NOT collect device identifiers beyond what is required for essential session management.

L. The system SHALL make the privacy policy accessible from the login screen.

M. The system SHALL make the privacy policy accessible from the account creation screen.

N. The system SHALL store only username, hashed password, and app UUID in the authentication system.

O. The system SHALL NOT use analytics cookies beyond essential session management.

P. The system SHALL NOT use tracking cookies beyond essential session management.

*End* *Web Diary Privacy Protection* | **Hash**: 58e010cd

---

# REQ-p01046: Web Diary Account Creation

**Level**: PRD | **Status**: Draft | **Implements**: p01042, p01043

## Rationale

Separate credentials for web access (versus mobile app) allow for different security policies appropriate to each platform while maintaining FDA 21 CFR Part 11 compliance. Minimum length requirements balance usability with security. Per-sponsor uniqueness prevents cross-sponsor conflicts while maintaining data isolation. Storing the app UUID with the account enables device attribution for audit trails, supporting comprehensive audit logging requirements. This requirement ensures secure account creation with proper validation, hashing, and storage mechanisms appropriate for web-based clinical trial diary access.

## Assertions

A. The system SHALL require patients to create a web-specific account with username and password.

B. The system SHALL enforce a minimum username length of 6 characters.

C. The system SHALL enforce a minimum password length of 8 characters.

D. The system SHALL ensure username uniqueness within the sponsor context.

E. The system SHALL reject duplicate usernames within the same sponsor with a clear error message.

F. The system SHALL hash passwords using an industry-standard algorithm before network transmission.

G. The system SHALL store passwords securely on the device using platform secure storage.

H. The system SHALL create a user document in the authentication database containing username, password hash, and app UUID.

I. The system SHALL link the account to the sponsor via linking code during creation.

J. The system SHALL provide real-time validation feedback during username and password input.

K. The system SHALL provide clear feedback on validation errors during account creation.

L. The system SHALL redirect users to the diary home screen upon successful account creation.

M. The system SHALL log account creation events to the audit trail for compliance.

*End* *Web Diary Account Creation* | **Hash**: 8d39c8e6

---

# REQ-p01047: Web Diary User Profile

**Level**: PRD | **Status**: Draft | **Implements**: p01042

## Rationale

Users need to view and manage their account credentials in a self-service manner. The password visibility toggle helps users verify their password while maintaining default privacy. Change password functionality allows users to update credentials without administrator intervention. Profile access and account management operations must be auditable for FDA 21 CFR Part 11 compliance.

## Assertions

A. The system SHALL provide a user profile view accessible from all diary screens.

B. The system SHALL display the username in the profile view as read-only after account creation.

C. The system SHALL display the password masked as asterisks or dots by default.

D. The system SHALL provide an eye icon toggle control to reveal the masked password.

E. The system SHALL provide a change password functionality accessible from the profile view.

F. The system SHALL require verification of the current password before allowing password changes.

G. The system SHALL confirm successful password changes to the user.

H. The system SHALL display the account creation timestamp in the profile view.

I. The system SHALL provide a logout button in the profile view.

J. The system SHALL display current session information in the profile view.

K. The system SHALL make the profile accessible via a menu icon displaying a head or person symbol.

L. The system SHALL log all profile view interactions to the audit trail.

M. The system SHALL log all password visibility toggle actions to the audit trail.

N. The system SHALL log all password change attempts and outcomes to the audit trail.

*End* *Web Diary User Profile* | **Hash**: c132adc2

---

# REQ-p01048: Web Diary Login Interface

**Level**: PRD | **Status**: Draft | **Implements**: p01042, p01043

## Rationale

This requirement defines the web diary's authentication interface to provide clear visibility of login state and prevent users from accidentally logging out without having saved their credentials. The logout confirmation reduces support burden by reminding users to verify they have recorded their authentication information before terminating their session, which is particularly important in a clinical trial context where participants may not be able to easily recover access.

## Assertions

A. The system SHALL provide a login interface accessible from the profile menu.

B. The system SHALL display a Login button in the profile menu when the user is not authenticated.

C. The system SHALL display a Logout button in the profile menu when the user is authenticated.

D. The system SHALL NOT display both Login and Logout buttons simultaneously.

E. The login form SHALL accept username and password inputs.

F. The login form SHALL validate input before submission.

G. The system SHALL display specific error messages when authentication fails.

H. Error messages SHALL distinguish between invalid username and incorrect password.

I. The system SHALL display session indicators when the user is logged in.

J. Session indicators SHALL include the username.

K. Session indicators SHALL include a session timer.

L. The system SHALL prompt for confirmation when the user initiates logout.

M. The logout confirmation SHALL display the message: "Did you save your username and password?"

N. The logout confirmation SHALL provide a cancel option that returns the user to the diary without logging out.

O. The logout confirmation SHALL provide a confirm option that completes the logout action.

*End* *Web Diary Login Interface* | **Hash**: d643690a

---

# REQ-p01049: Web Diary Lost Credential Recovery

**Level**: PRD | **Status**: Draft | **Implements**: p01042, p01043

## Rationale

Without email addresses, traditional password reset flows are not possible for this clinical trial diary platform. The linking code recovery process maintains the trust chain through the Sponsor while preventing unauthorized account recovery. This design ensures that only verified patients can regain access to their accounts by requiring Sponsor intervention, preventing unauthorized access while preserving diary data continuity. Invalidating old linking codes before issuing new ones prevents credential sharing or account duplication. Future multi-device support may provide alternative recovery mechanisms, but the current design prioritizes security and regulatory compliance over convenience.

## Assertions

A. The system SHALL NOT provide automated password reset functionality.

B. The system SHALL NOT provide email-based credential recovery.

C. The system SHALL require patients to contact their Sponsor to request a new linking code for credential recovery.

D. The Sponsor SHALL invalidate the current linking code before issuing a new linking code.

E. The system SHALL allow patients to create a new username and password using a new linking code.

F. The system SHALL preserve all previous account data when new credentials are created via linking code recovery.

G. The system SHALL link recovered account data to the patient via their enrollment record.

H. The login screen SHALL display a link to credential recovery instructions.

I. The recovery instructions SHALL explain that patients must contact their Sponsor for a new linking code.

J. The system SHALL invalidate old linking codes when new codes are issued by the Sponsor.

K. The system SHALL record credential recovery events in the audit trail.

L. The system SHALL provide user-facing help content documenting the recovery process.

*End* *Web Diary Lost Credential Recovery* | **Hash**: 0af0c79c

---

## Technology Constraints

This section documents constraints that affect product decisions (not implementation details).

**Authentication Provider Restriction**:

- Identity Platform MUST NOT be used (GDPR data processing concerns)
- Google Identity Platform MUST NOT be used (same GDPR concerns)
- Custom authentication service required using GCP infrastructure

**Data Storage**:

- Patient diary data stored in Firestore (existing mobile app infrastructure)
- Authentication credentials stored separately in dedicated auth service
- Web Diary connects to same Firestore collections as mobile app

**Single Device Policy**:

- Web access counts as a separate "device" from mobile app
- Same patient may have mobile app AND web access simultaneously
- Conflict resolution follows existing multi-device patterns (see prd-diary-app.md)

---

## References

- **Mobile Diary Application**: prd-diary-app.md
- **Platform Overview**: prd-system.md
- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Security Architecture**: prd-security.md
- **FDA Compliance**: prd-clinical-trials.md

---

## Revision History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-12-05 | Initial Web Diary specification | CUR-423 |
| 1.1 | 2025-12-05 | Added linking code patterns, specific privacy messages, lost credential recovery (REQ-p01049) | CUR-423 |

---

**Document Classification**: Internal Use - Product Requirements
**Review Frequency**: Quarterly or when modifying web diary functionality
**Owner**: Product Team
