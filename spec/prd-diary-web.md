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

The Web Diary is a browser-based companion to the Clinical Diary mobile application. It allows patients to access their diary from any computer when the mobile app is unavailable. Due to the inherently less secure nature of web access (shared computers, public terminals), the Web Diary implements strict session management and stores no data locally after logout.

**Key Differences from Mobile App**:
- No offline capability (requires constant internet connection)
- Automatic logout after inactivity
- No local data persistence
- Session terminates on browser close
- Authentication via linking code from Sponsor Portal

---

# REQ-p01042: Web Diary Application

**Level**: PRD | **Implements**: p00043 | **Status**: Draft

A web browser-based diary application enabling clinical trial patients to record health observations from any computer, with automatic session timeout and no persistent data storage for privacy protection.

Web Diary application SHALL provide:
- Browser-based access to diary entry functionality
- Automatic session timeout after configurable inactivity period
- Complete session termination on browser/tab close
- No local data persistence after logout
- Integration with Sponsor Portal for authentication via linking codes
- Sponsor-specific branding and configuration

**Rationale**: Provides an alternative access method for patients who cannot use the mobile app or prefer web access. Web access introduces different security considerations than mobile (shared/public computers, no device-level security), requiring stricter session management and no persistent storage.

**Acceptance Criteria**:
- Accessible via standard web browsers (Chrome, Firefox, Safari, Edge)
- Functions as companion to mobile app, not replacement
- Complete audit trail of all patient actions
- No patient data retained in browser after logout
- Sponsor branding applied after successful authentication

*End* *Web Diary Application* | **Hash**: f663bc1b

---

# REQ-p01043: Web Diary Authentication via Linking Code

**Level**: PRD | **Implements**: p01042 | **Status**: Draft

Patients SHALL authenticate to the Web Diary using a unique linking code obtained from the Sponsor Portal, combined with a username and password created specifically for web access, without using email addresses or third-party authentication providers.

Authentication SHALL ensure:
- Linking code provided by Sponsor Portal establishes sponsor context
- Linking codes contain embedded patterns identifying the sponsor (similar to credit card prefix patterns)
- HHT Diary Auth service maintains mapping table of linking code patterns to Sponsor Portal URLs
- Mapping table updated when sponsors deploy or decommission portals
- Username and password created during initial setup (not linked to email)
- No personally identifiable information (PII) collected during authentication
- No third-party authentication providers used (no Firebase Auth, Google Sign-In, etc.)
- Password hashed before network transmission
- Authentication service validates credentials and returns session JWT

**Rationale**: GDPR restrictions prevent use of Firebase Authentication and similar services that process personal data. A custom authentication system using linking codes maintains sponsor isolation (p00001) while avoiding PII collection. Linking codes establish the trust relationship between the patient and their clinical trial without requiring email verification. Pattern-based sponsor identification enables a single auth service to route users to the correct sponsor without requiring users to know which sponsor they belong to.

**Acceptance Criteria**:
- Patient receives linking code through Sponsor Portal enrollment process
- Linking code pattern identifies sponsor without user input
- Auth service routes to correct Sponsor Portal URL based on pattern matching
- Invalid linking codes rejected with clear error message
- Unrecognized patterns rejected with guidance to contact Sponsor
- Linking codes expire after sponsor-configurable period
- Successful authentication returns JWT scoped to sponsor
- No email addresses stored or processed
- Authentication works across all supported browsers

*End* *Web Diary Authentication via Linking Code* | **Hash**: 31d36807

---

# REQ-p01044: Web Diary Session Management

**Level**: PRD | **Implements**: p01042 | **Status**: Draft

The Web Diary SHALL automatically terminate user sessions after a period of inactivity, on browser/tab close, and on explicit logout, ensuring no session persists beyond active use.

Session management SHALL ensure:
- Automatic logout after inactivity (default: 2 minutes, sponsor-configurable)
- Session terminated when browser window or tab is closed
- Explicit logout option always available to user
- Warning displayed before automatic timeout with countdown
- All session data cleared from browser on logout
- No "remember me" or persistent login option

**Rationale**: Web access may occur on shared or public computers where the next user could access patient data if sessions persist. Aggressive session timeout and complete data clearing protect patient privacy in these environments. The short default timeout (2 minutes) reflects the sensitive nature of clinical trial data.

**Acceptance Criteria**:
- Inactivity timer resets on any user interaction (mouse move, keystroke, touch)
- Warning modal appears 30 seconds before automatic logout
- User can extend session from warning modal
- Logout clears all browser storage (sessionStorage, localStorage, cookies)
- No patient data recoverable after logout
- Back button does not restore session after logout
- Multiple tabs share same session timeout
- Sponsor can configure timeout between 1-30 minutes

*End* *Web Diary Session Management* | **Hash**: cdc397b5

---

# REQ-p01045: Web Diary Privacy Protection

**Level**: PRD | **Implements**: p01042, p01043 | **Status**: Draft

The Web Diary SHALL collect no personally identifiable information (PII) and SHALL display clear privacy messaging to users during account creation and login.

Privacy protection SHALL ensure:
- No email addresses collected or stored
- Usernames cannot contain @ symbol (prevents email-like identifiers)
- Privacy messages displayed during account creation
- No biometric data or device identifiers collected
- Minimal data footprint in authentication system
- Clear disclosure of what data is stored and password recovery limitations

**Rationale**: Clinical trial participants have heightened privacy concerns. By explicitly avoiding email collection and displaying privacy messaging, the system builds trust while ensuring GDPR compliance. The @ restriction prevents users from accidentally using email addresses as usernames. Clear messaging about password recovery limitations helps users understand the importance of securely storing their credentials.

**Acceptance Criteria**:
- Account creation displays the following privacy messages:
  - "For your privacy we do not use email addresses for accounts"
  - "@ signs are not allowed for username"
  - "Store your username and password securely"
  - "If you lose your username and password then the app cannot send you a link to reset it"
  - "For a lost username and password, contact your Sponsor to obtain a new Linking Code"
- Username field rejects entries containing @ symbol with clear error message
- Privacy policy accessible from login and account creation screens
- Only username, hashed password, and app UUID stored in authentication system
- No analytics or tracking cookies beyond essential session management

*End* *Web Diary Privacy Protection* | **Hash**: 3185ed95

---

# REQ-p01046: Web Diary Account Creation

**Level**: PRD | **Implements**: p01042, p01043 | **Status**: Draft

Patients SHALL create a web-specific account with username and password meeting security requirements, stored securely in the authentication service.

Account creation SHALL ensure:
- Username minimum length: 6 characters
- Password minimum length: 8 characters
- Username must be unique within sponsor context
- Password hashed using industry-standard algorithm before network transmission
- Password stored securely on device using platform secure storage
- User document created in authentication database with username, password hash, and app UUID
- Account linked to sponsor via linking code
- Clear feedback on validation errors

**Rationale**: Separate credentials for web access (vs. mobile app) allow for different security policies appropriate to each platform. Minimum length requirements balance usability with security. Per-sponsor uniqueness prevents cross-sponsor conflicts while maintaining data isolation. Storing the app UUID with the account enables device attribution for audit trails.

**Acceptance Criteria**:
- Username validation enforces 6+ character minimum
- Password validation enforces 8+ character minimum
- Real-time validation feedback during input
- Duplicate username within sponsor rejected with clear message
- User document created with: username, password hash, app UUID
- Successful creation redirects to diary home screen
- Account creation audit logged for compliance

*End* *Web Diary Account Creation* | **Hash**: 915de272

---

# REQ-p01047: Web Diary User Profile

**Level**: PRD | **Implements**: p01042 | **Status**: Draft

The Web Diary SHALL provide a user profile view displaying account information and providing account management functions.

User profile SHALL display:
- Username (read-only after creation)
- Password (masked with toggle to reveal)
- Change password functionality
- Logout button
- Current session information

Profile functionality SHALL ensure:
- Profile accessible via menu icon (head/person icon)
- Password shown as asterisks/dots by default
- Eye icon toggles password visibility
- Change password requires current password verification
- Profile changes logged for audit trail

**Rationale**: Users need to view and manage their account credentials. The password visibility toggle helps users verify their password while maintaining default privacy. Change password functionality allows users to update credentials without administrator intervention.

**Acceptance Criteria**:
- Profile menu accessible from all diary screens
- Username displayed but not editable
- Password masked by default, revealed on eye icon click
- Change password workflow validates current password first
- Password change success confirmed to user
- Profile view shows when account was created
- All profile interactions logged for compliance

*End* *Web Diary User Profile* | **Hash**: 654d8be8

---

# REQ-p01048: Web Diary Login Interface

**Level**: PRD | **Implements**: p01042, p01043 | **Status**: Draft

The Web Diary SHALL provide a login interface accessible from the profile menu, with clear state indication of login status.

Login interface SHALL ensure:
- Login button visible in profile menu when not authenticated
- Logout button replaces login when authenticated
- Login form accepts username and password
- Logout confirmation prompts user to verify credentials were saved
- Clear error messages for failed authentication

**Rationale**: Users need clear indication of their authentication state. The logout confirmation asking about saved credentials helps users avoid being locked out if they created an account but didn't record their password.

**Acceptance Criteria**:
- Unauthenticated state shows "Login" button in profile menu
- Authenticated state shows "Logout" button in profile menu
- Login form validates input before submission
- Failed login displays specific error (invalid username, wrong password)
- Logout shows confirmation: "Did you save your username and password?"
- Confirmation allows cancel to return to diary
- Session indicators visible when logged in (username, session timer)

*End* *Web Diary Login Interface* | **Hash**: 1d24c597

---

# REQ-p01049: Web Diary Lost Credential Recovery

**Level**: PRD | **Implements**: p01042, p01043 | **Status**: Draft

Patients who lose their username or password SHALL recover access by obtaining a new linking code from their Sponsor, as the system cannot provide email-based password reset functionality.

Lost credential recovery SHALL ensure:
- No automated password reset mechanism (no email-based recovery)
- Patient contacts Sponsor to request new linking code
- Sponsor invalidates current linking code before issuing new one
- Patient creates new username and password using new linking code
- Previous account data remains accessible under new credentials (linked via patient enrollment)
- Clear guidance provided to users about recovery process

**Rationale**: Without email addresses, traditional password reset flows are not possible. The linking code recovery process maintains the trust chain through the Sponsor while preventing unauthorized account recovery. Invalidating the old linking code before issuing a new one prevents credential sharing or account duplication. Future multi-device support may provide alternative recovery mechanisms.

**Acceptance Criteria**:
- Login screen displays link to recovery instructions
- Recovery instructions explain: contact Sponsor for new linking code
- Old linking code becomes invalid when new code is issued by Sponsor
- New linking code allows creation of new username/password
- Patient's diary data preserved and accessible with new credentials
- Audit trail records credential recovery events
- Recovery process documented in user-facing help content

*End* *Web Diary Lost Credential Recovery* | **Hash**: 934b5e7f

---

## Technology Constraints

This section documents constraints that affect product decisions (not implementation details).

**Authentication Provider Restriction**:
- Firebase Authentication MUST NOT be used (GDPR data processing concerns)
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
