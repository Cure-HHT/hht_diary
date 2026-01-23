# Web Diary Application Implementation

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2025-12-27
**Status**: Draft

> **See**: prd-diary-web.md for product requirements
> **See**: dev-app.md for mobile app implementation patterns
> **See**: dev-security.md for security implementation details
> **See**: dev-linking.md for linking codes and authentication service

---

## Executive Summary

This specification defines the implementation details for the Web Diary application, a browser-based companion to the mobile Clinical Diary app. The Web Diary uses Flutter Web for the frontend, a custom HHT Diary Auth service for authentication (avoiding Identity Platform for GDPR compliance), and Firestore for data storage.

**Technology Stack**:
- **Frontend**: Flutter Web (Dart)
- **Authentication**: Custom HHT Diary Auth service on Cloud Run
- **Database**: Firestore (same collections as mobile app)
- **Hosting**: Firebase Hosting or Cloud Run
- **Password Hashing**: Argon2id (client-side before transmission)

## Status

Web security does not have the hardware-level safety that mobile apps allow.  The web app needs to have a review of
it's security posture.

The lack of a local database conflicts with REQ-p01001: Offline Event Queue with Automatic Synchronization

---

# REQ-d00077: Web Diary Frontend Framework

**Level**: Dev | **Status**: Draft | **Implements**: p01042

## Rationale

Flutter Web enables significant code reuse from the mobile application, reducing development and maintenance effort while ensuring UI consistency across platforms. Disabling service workers prevents cached data from persisting beyond the user session, which is critical for FDA 21 CFR Part 11 compliance where clinical data must not remain on uncontrolled client devices. This approach balances security requirements with the benefits of a shared codebase.

## Assertions

A. The Web Diary SHALL be implemented using Flutter Web.
B. The Web Diary SHALL reuse the same codebase as the mobile application.
C. The system SHALL include a shared widget library between web and mobile applications to ensure consistent UI patterns.
D. The Web Diary SHALL implement Material Design 3 theming.
E. The theming system SHALL support sponsor-specific customization.
F. The Web Diary SHALL implement responsive layouts supporting desktop viewports.
G. The Web Diary SHALL implement responsive layouts supporting tablet viewports.
H. The Web Diary SHALL disable service workers to prevent offline caching.
I. The Web Diary SHALL unregister any existing service worker registrations on application initialization.
J. The Web Diary SHALL load and function correctly in the latest two versions of Chrome.
K. The Web Diary SHALL load and function correctly in the latest two versions of Firefox.
L. The Web Diary SHALL load and function correctly in the latest two versions of Safari.
M. The Web Diary SHALL load and function correctly in the latest two versions of Edge.
N. The system SHALL NOT register a service worker after application initialization.
O. The Web Diary SHALL apply sponsor-specific theming after user authentication.
P. The responsive layout SHALL adapt rendering based on viewport width.
Q. Shared components SHALL render consistently between web and mobile applications.

*End* *Web Diary Frontend Framework* | **Hash**: a84bf289

---

# REQ-d00080: Web Session Management Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p01044

## Rationale

This requirement ensures patient data protection on shared computers through comprehensive web session management. The implementation addresses FDA 21 CFR Part 11 security requirements by preventing unauthorized access through abandoned sessions and ensuring complete data cleanup when sessions end. Multiple interaction event listeners provide a user-friendly experience while maintaining security, and browser-level event handlers prevent data leakage through cached content or local storage.

## Assertions

A. The Web Diary SHALL implement client-side session management with configurable inactivity timeout.
B. The system SHALL track user interactions including mouse movement, keyboard input, touch events, and clicks to detect activity.
C. The system SHALL reset the inactivity timer when any tracked user interaction occurs.
D. The system SHALL display a warning modal 30 seconds before the inactivity timeout expires.
E. The system SHALL provide a mechanism for users to extend their session from the warning modal.
F. The system SHALL terminate the session when the inactivity timeout expires without user extension.
G. The system SHALL register a beforeunload event handler to detect browser tab or window close events.
H. The system SHALL clear all local storage when a beforeunload event is triggered.
I. The system SHALL clear all session storage when a beforeunload event is triggered.
J. The system SHALL clear all cookies when a beforeunload event is triggered.
K. The system SHALL register a visibilitychange event handler to detect tab switching.
L. The system SHALL NOT trigger logout when the user switches to a different browser tab.
M. The system SHALL trigger logout only when the browser tab or window is closed.
N. The system SHALL clear all client-side storage on explicit user logout.
O. The system SHALL display the login page when the user navigates back after logout.
P. The system SHALL NOT display cached data when the user navigates back after logout.

*End* *Web Session Management Implementation* | **Hash**: 1ed9928f

---

TODO - move to dev-app.md

# REQ-d00082: Password Hashing Implementation

**Level**: Dev | **Status**: Draft | **Implements**: p01043, p01046

## Rationale

This requirement implements secure password handling for the clinical trial platform to protect user credentials from interception and compromise. Client-side hashing with Argon2id ensures that plaintext passwords are minimized in transmission and never stored on the server. Argon2id was selected as the password hashing algorithm because it is the current OWASP recommendation, providing resistance to GPU-based attacks and side-channel attacks. The implementation supports FDA 21 CFR Part 11 security requirements by ensuring authentication credentials are protected through cryptographically strong methods. TLS provides transport security for the initial salt retrieval during login flows.

## Assertions

A. The system SHALL hash all passwords client-side using the Argon2id variant before network transmission during registration.
B. The system SHALL use the argon2 Dart package for client-side password hashing, with WASM build support for web platforms.
C. The system SHALL configure Argon2id with memory parameter of 65536 KB (64 MB).
D. The system SHALL configure Argon2id with iteration count of 3.
E. The system SHALL configure Argon2id with parallelism parameter of 4 lanes.
F. The system SHALL configure Argon2id with hash length of 32 bytes.
G. The system SHALL generate a unique cryptographic salt for each user account.
H. The system SHALL store the salt value alongside the password hash in the database.
I. The system SHALL transmit only the password hash to the server during registration, never the plaintext password.
J. The system SHALL verify login credentials by re-hashing the provided password with the stored salt and comparing the resulting hash.
K. The system SHALL NOT store passwords in plaintext format at any time.
L. The system SHALL NOT log passwords in plaintext format at any time.
M. The system SHALL transmit the username, hash, salt, linkingCode, and appUuid to the server during registration.
N. The system SHALL generate a new unique salt when a user changes their password.
O. The system SHALL re-hash the password with the new salt when a user changes their password.

*End* *Password Hashing Implementation* | **Hash**: 2f426f50

---

# REQ-d00083: Browser Storage Clearing

**Level**: Dev | **Status**: Draft | **Implements**: p01044

## Rationale

Complete storage clearing prevents the next user on a shared computer from accessing any patient data. Browsers persist data in multiple storage mechanisms (localStorage, sessionStorage, cookies, IndexedDB, and Cache Storage), all of which must be cleared on logout, session timeout, and browser close to ensure no Protected Health Information (PHI) remains accessible. This requirement implements FDA 21 CFR Part 11 controls for data access termination and supports ALCOA+ principles by preventing unauthorized data access after session termination.

## Assertions

A. The Web Diary SHALL clear localStorage on logout.
B. The Web Diary SHALL clear sessionStorage on logout.
C. The Web Diary SHALL clear all cookies on logout by setting their expiry to a past date.
D. The Web Diary SHALL clear IndexedDB databases on logout.
E. The Web Diary SHALL clear Cache Storage (service worker caches) on logout.
F. The Web Diary SHALL clear localStorage on session timeout.
G. The Web Diary SHALL clear sessionStorage on session timeout.
H. The Web Diary SHALL clear all cookies on session timeout by setting their expiry to a past date.
I. The Web Diary SHALL clear IndexedDB databases on session timeout.
J. The Web Diary SHALL clear Cache Storage on session timeout.
K. The Web Diary SHALL clear localStorage on browser close.
L. The Web Diary SHALL clear sessionStorage on browser close.
M. The Web Diary SHALL clear all cookies on browser close by setting their expiry to a past date.
N. The Web Diary SHALL clear IndexedDB databases on browser close.
O. The Web Diary SHALL clear Cache Storage on browser close.
P. The Web Diary SHALL navigate to the login page after clearing all storage mechanisms.
Q. The browser back button SHALL display the login page after logout, not cached content.
R. Patient data SHALL NOT be recoverable via browser developer tools after logout.

*End* *Browser Storage Clearing* | **Hash**: 781a1594

---
TODO - remove or move to dev-app.md
# REQ-d00084: Sponsor Configuration Loading

**Level**: Dev | **Status**: Draft | **Implements**: p01042, p01043

## Rationale

This requirement ensures the Web Diary application retrieves sponsor-specific configuration directly from the authoritative source (Sponsor Portal) after authentication. This architecture simplifies the authentication service by delegating configuration management to the Sponsor Portal, which already maintains sponsor branding and settings. Direct fetching ensures clients always receive current configuration without requiring separate configuration distribution mechanisms. The design supports multi-sponsor deployment while maintaining sponsor isolation and enabling real-time configuration updates.

## Assertions

A. The system SHALL obtain the Sponsor Portal URL from the authentication token after successful login.
B. The system SHALL fetch sponsor configuration directly from the Sponsor Portal API using the URL provided in the authentication token.
C. The system SHALL complete the sponsor configuration fetch from the Sponsor Portal within 1 second.
D. The system SHALL cache sponsor configuration in memory only.
E. The system SHALL NOT persist sponsor configuration to browser storage.
F. The system SHALL apply sponsor branding including logo and colors immediately after fetching configuration.
G. The system SHALL configure session timeout using the sponsor-specific value obtained from the Sponsor Portal.
H. Sponsor-configured session timeout values SHALL have a default of 2 minutes and support a range of 1-30 minutes.
I. The system SHALL provide graceful fallback behavior using default values if the Sponsor Portal configuration fetch fails.
J. The authentication token SHALL include the sponsorUrl field containing the Sponsor Portal base URL.
K. The sponsor configuration response SHALL include sponsorId, sponsorName, sessionTimeoutMinutes, and branding properties.
L. The branding configuration SHALL include logoUrl, primaryColor, and secondaryColor fields.
M. Primary and secondary colors SHALL be provided in hexadecimal color format.
N. The system SHALL start the session timer using the sessionTimeoutMinutes value from the sponsor configuration.

*End* *Sponsor Configuration Loading* | **Hash**: 654added

---

## Security Considerations

**Transport Security**:
- All communication over HTTPS (TLS 1.3)
- HSTS headers enabled on all endpoints
- Certificate pinning not applicable for web

**Content Security Policy**:
```
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'wasm-unsafe-eval';
  style-src 'self' 'unsafe-inline';
  connect-src 'self' https://*.googleapis.com https://*.firebaseio.com;
  img-src 'self' data: https:;
  frame-ancestors 'none';
```

**Cookie Security**:
- All cookies set with `Secure`, `HttpOnly`, `SameSite=Strict`
- Session cookies only (no persistent cookies)

---

## References

- **Product Requirements**: prd-diary-web.md
- **Mobile App Implementation**: dev-app.md
- **Security Implementation**: dev-security.md
- **OWASP Password Storage**: https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- **Argon2 Specification**: https://github.com/P-H-C/phc-winner-argon2

---

## Revision History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-12-05 | Initial Web Diary implementation specification | CUR-423 |

---

**Document Classification**: Internal Use - Development Specification
**Review Frequency**: Quarterly or when modifying web diary implementation
**Owner**: Development Team
