# Mobile App Linking Implementation

**Version**: 1.0
**Audience**: Development
**Last Updated**: 2026-01-27
**Status**: Draft

> **See**: prd-diary-app.md for product requirements (REQ-p00043, REQ-p00007)
> **See**: prd-portal.md for linking code lifecycle (REQ-p70007, REQ-p70009, REQ-p70010, REQ-p70011)
> **See**: dev-linking.md for server-side linking code validation (REQ-d00078, REQ-d00079)

---

## Executive Summary

This specification defines the mobile app implementation details for linking to the Sponsor Portal. It covers linking code entry UI, token lifecycle management, error handling, enrollment state machine, and Study Start questionnaire integration.

**Technology Stack**:
- **Platform**: Flutter (iOS/Android)
- **Secure Storage**: iOS Keychain / Android Keystore via flutter_secure_storage
- **State Management**: Event sourcing with local-first architecture
- **Network**: HTTPS with certificate pinning

---

## Section 1: Linking Code Entry

# REQ-d00094: Linking Code Entry Interface

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p70007, REQ-p00007

Addresses: JNY-Portal-Enrollment-01

## Rationale

The linking code entry interface is the patient's first interaction with the enrollment process. Clear visual feedback and input formatting reduce data entry errors, while real-time validation provides immediate feedback on code format before submission. The interface design mirrors proven patterns from activation code entry systems (e.g., software licenses, gift cards) that users are familiar with.

## Assertions

A. The system SHALL provide a single text input field for linking code entry on the enrollment screen.

B. The system SHALL accept linking codes in both formatted (XX-XXX-XXXXX) and unformatted (XXXXXXXXXX) input styles.

C. The system SHALL automatically strip any dash or space characters from user input before processing.

D. The system SHALL automatically convert lowercase input to uppercase for display and processing.

E. The system SHALL limit input to 12 characters maximum (10 alphanumeric plus 2 optional dashes).

F. The system SHALL display the linking code in formatted style (XX-XXX-XXXXX) as the user types.

G. The system SHALL use a monospace font for the linking code input field to aid visual verification.

H. The system SHALL display character count feedback showing entered/required (e.g., "8/10 characters").

I. The system SHALL disable the submit button until exactly 10 alphanumeric characters have been entered.

J. The system SHALL display a keyboard optimized for alphanumeric input (no special characters).

K. The system SHALL provide a "Paste" action to support linking code entry from clipboard.

L. The system SHALL strip invalid characters from pasted content and retain only valid alphanumerics.

M. The system SHALL support QR code scanning as an alternative input method for linking codes.

N. The system SHALL extract and populate the linking code from scanned QR code content.

O. The system SHALL display clear visual feedback during linking code validation (loading indicator).

P. The system SHALL provide haptic feedback on successful code submission (iOS/Android native).

*End* *Linking Code Entry Interface* | **Hash**: dae36394

---

# REQ-d00095: Linking Code Input Validation

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p70007 | **Refines**: REQ-d00079

## Rationale

Client-side validation provides immediate feedback on obvious input errors before network round-trip, improving user experience. The validation rules enforce the linking code format defined in REQ-d00079 (two-character sponsor prefix + 8-character random alphanumeric). Distinguishing between client-side format validation and server-side semantic validation helps provide appropriate error messages.

## Assertions

A. The system SHALL validate that linking code input contains only uppercase letters A-Z and digits 0-9.

B. The system SHALL reject input characters that are visually ambiguous per REQ-d00079: I, 1, O, 0, S, 5, Z, 2.

C. The system SHALL display inline validation error when ambiguous characters are detected: "Please check your code. The characters I, 1, O, 0, S, 5, Z, 2 are not used in linking codes."

D. The system SHALL validate that the linking code is exactly 10 alphanumeric characters before submission.

E. The system SHALL perform format validation on input change (debounced by 300ms).

F. The system SHALL indicate valid format with a checkmark icon next to the input field.

G. The system SHALL indicate invalid format with an error icon and descriptive message.

H. The system SHALL NOT submit the linking code to the server if client-side validation fails.

I. The system SHALL preserve user input on validation failure to allow correction.

J. The system SHALL clear validation errors when the user modifies the input.

*End* *Linking Code Input Validation* | **Hash**: d124cbf4

---

## Section 2: Token Lifecycle Management

# REQ-d00096: Enrollment Token Secure Storage

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p00043 | **Refines**: REQ-d00078

## Rationale

Clinical trial data requires protection at rest per FDA 21 CFR Part 11 security requirements. Platform-native secure storage (iOS Keychain, Android Keystore) provides hardware-backed encryption and protection against unauthorized access. Storing tokens in secure storage prevents extraction through device backup, app data inspection, or rooted/jailbroken device access. The flutter_secure_storage package provides a unified API across platforms while leveraging native security mechanisms.

## Assertions

A. The system SHALL store enrollment tokens in iOS Keychain on iOS devices.

B. The system SHALL store enrollment tokens in Android Keystore on Android devices.

C. The system SHALL use the flutter_secure_storage package for cross-platform secure storage access.

D. The system SHALL configure iOS Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly accessibility.

E. The system SHALL configure Android Keystore to require user authentication for token access when biometrics are available.

F. The system SHALL encrypt stored token data using AES-256-GCM.

G. The system SHALL NOT include enrollment tokens in device backups (iCloud, Google backup).

H. The system SHALL store the following token data: accessToken, refreshToken, expiresAt, sponsorUrl, patientId.

I. The system SHALL NOT store tokens in SharedPreferences, UserDefaults, or other non-secure storage.

J. The system SHALL NOT log token values to console, crash reports, or analytics.

K. The system SHALL securely delete all stored tokens when the user disconnects from the study.

L. The system SHALL securely delete all stored tokens when the app is uninstalled.

M. The system SHALL regenerate storage encryption key if device security state changes (e.g., device rooted/jailbroken).

*End* *Enrollment Token Secure Storage* | **Hash**: 2f2321ae

---

# REQ-d00097: Token Lifecycle and Network Resilience

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p00006 | **Refines**: REQ-d00078

## Rationale

Enrollment tokens issued during the linking process are perpetual—they have no expiration date and remain valid until explicitly revoked through portal-side actions (patient disconnection, lost device reported, administrative action). This simplifies client implementation and ensures uninterrupted data collection. The client must handle network unavailability gracefully, queuing synchronization requests and retrying when connectivity is restored. Token revocation is detected through server responses, not client-side expiration checks.

## Assertions

A. The system SHALL treat enrollment tokens as perpetual with no client-enforced expiration.

B. The system SHALL NOT implement client-side token expiration or automatic refresh cycles.

C. The system SHALL determine token validity solely through server response codes (valid request succeeds, revoked token returns HTTP 401/403).

D. The system SHALL queue synchronization requests when network is unavailable.

E. The system SHALL process queued synchronization requests when network connectivity is restored.

F. The system SHALL retry failed synchronization requests with exponential backoff (1s, 2s, 4s, 8s, max 60s).

G. The system SHALL limit consecutive retry attempts to 5 before pausing synchronization until next app foreground or network change event.

H. The system SHALL continue offline diary entry creation regardless of network or token state.

I. The system SHALL NOT interrupt diary entry creation during synchronization operations.

J. The system SHALL timestamp the last successful server communication in local storage for diagnostic purposes.

K. The system SHALL distinguish between network errors (retry-able) and token revocation errors (not retry-able) based on HTTP response codes.

*End* *Token Lifecycle and Network Resilience* | **Hash**: 8b7af588

---

# REQ-d00098: Token Invalidation on Disconnection

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p70010 | **Refines**: REQ-d00078

## Rationale

When a patient is disconnected from a study (lost device, voluntary withdrawal), the Sponsor Portal invalidates their linking code. The mobile app must detect this invalidation and transition to the appropriate state. Server-side invalidation is the authoritative source; the app detects invalidation through failed synchronization attempts or explicit server responses.

## Assertions

A. The system SHALL detect token invalidation through HTTP 401 response on any authenticated API request.

B. The system SHALL detect token invalidation through HTTP 403 response with error code "TOKEN_REVOKED".

C. The system SHALL immediately clear all stored tokens upon detecting server-side invalidation.

D. The system SHALL transition the app to "Not Participating" enrollment state upon token invalidation.

E. The system SHALL preserve all locally stored diary entries when tokens are invalidated.

F. The system SHALL continue to allow local diary entry creation when tokens are invalidated.

G. The system SHALL NOT attempt data synchronization after token invalidation until re-enrollment.

H. The system SHALL display the "Contact Study Coordinator" screen upon detecting token invalidation.

I. The system SHALL log token invalidation event with timestamp to local diagnostics (no PHI).

J. The system SHALL NOT automatically request a new linking code; this must be initiated by clinical staff.

*End* *Token Invalidation on Disconnection* | **Hash**: 654a51e8

---

## Section 3: Diary Linking Error Scenarios

# REQ-d00099: Linking Code Error Handling

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p70007 | **Refines**: REQ-d00078

Addresses: JNY-Portal-Enrollment-01

## Rationale

Linking code validation can fail for multiple reasons: expired codes, already-used codes, invalid format, or unknown sponsor prefix. Per REQ-p70007-G, the system returns a generic "Invalid Code" error message to prevent information disclosure about code validity. However, the mobile app must provide actionable guidance for users to resolve the issue. The error messages guide users to contact their clinical staff, who have visibility into the specific failure reason in the Sponsor Portal.

## Assertions

A. The system SHALL display error message "Invalid linking code. Please check the code and try again, or contact your study coordinator for a new code." when the server returns an invalid code response.

B. The system SHALL NOT distinguish between expired, already-used, or unrecognized codes in error messages displayed to users.

C. The system SHALL display error message "This linking code is not recognized. Please verify you have the correct code and try again." when the sponsor prefix is not found in the pattern table.

D. The system SHALL display a "Contact Study Coordinator" button on all linking error screens.

E. The system SHALL clear the linking code input field after displaying an error to allow re-entry.

F. The system SHALL preserve the enrollment screen state (not navigate away) on linking code error.

G. The system SHALL log linking code validation failures with error type to local diagnostics (code value NOT logged).

H. The system SHALL limit consecutive linking code validation attempts to 5 per 5-minute window.

I. The system SHALL display rate limit message "Too many attempts. Please wait 5 minutes before trying again." when rate limit is exceeded.

J. The system SHALL disable the submit button during the rate limit cooldown period.

K. The system SHALL display remaining cooldown time in the rate limit message.

*End* *Linking Code Error Handling* | **Hash**: 3a1f9cc5

---

# REQ-d00100: Network Failure Handling During Linking

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p00006 | **Refines**: REQ-d00078

## Rationale

Linking code validation requires network connectivity because the Sponsor Portal is the authoritative source for code validity. When network is unavailable, the app must provide clear feedback and retry mechanisms. Unlike diary data entry (which works offline), linking is an inherently online operation. The retry logic balances user convenience with server load management.

## Assertions

A. The system SHALL detect network unavailability before attempting linking code submission.

B. The system SHALL display error message "No internet connection. Please check your connection and try again." when network is unavailable.

C. The system SHALL provide a "Retry" button on network error screens.

D. The system SHALL automatically retry linking code validation when network connectivity is restored (if user is still on enrollment screen).

E. The system SHALL display a network status indicator on the enrollment screen.

F. The system SHALL timeout linking code validation requests after 30 seconds.

G. The system SHALL display error message "Connection timed out. Please try again." on request timeout.

H. The system SHALL retry failed requests automatically up to 3 times with 2-second delays before showing error.

I. The system SHALL distinguish between network errors (retry-able) and server errors (not retry-able) in UI feedback.

J. The system SHALL display error message "Server error. Please try again later or contact your study coordinator." on HTTP 5xx responses.

K. The system SHALL NOT cache linking code validation responses.

L. The system SHALL preserve entered linking code during network retry attempts.

*End* *Network Failure Handling During Linking* | **Hash**: fe5b5e9a

---

## Section 4: Diary-Sponsor Lifecycle Definition

# REQ-d00101: Enrollment State Machine

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p00043, REQ-p70000, REQ-p01065

Addresses: JNY-Portal-Enrollment-01, JNY-Portal-Enrollment-02

## Rationale

The mobile app must track the patient's enrollment lifecycle to determine which features are available and how data flows. The state machine defines clear transitions between personal use, enrollment pending, active study participation, and disconnected states. Each state has specific behaviors for data storage, synchronization, and UI presentation. The state machine is the authoritative source for enrollment status within the app.

## Assertions

A. The system SHALL implement an enrollment state machine with the following states: PERSONAL_USE, LINKING_PENDING, STUDY_START_PENDING, ENROLLED, NOT_PARTICIPATING.

B. The system SHALL persist enrollment state to local storage to survive app restart.

C. The system SHALL initialize new app installations in PERSONAL_USE state.

D. The system SHALL transition from PERSONAL_USE to LINKING_PENDING when user initiates enrollment.

E. The system SHALL transition from LINKING_PENDING to STUDY_START_PENDING upon successful linking code validation.

F. The system SHALL transition from STUDY_START_PENDING to ENROLLED upon Study Start questionnaire approval by investigator.

G. The system SHALL transition from ENROLLED to NOT_PARTICIPATING upon token invalidation or disconnection.

H. The system SHALL transition from NOT_PARTICIPATING to LINKING_PENDING when user initiates re-enrollment with new linking code.

I. The system SHALL NOT allow transition from PERSONAL_USE directly to ENROLLED (must go through LINKING_PENDING and STUDY_START_PENDING).

J. The system SHALL persist state transition history with timestamps for audit purposes.

K. The system SHALL emit state change events for UI and synchronization components to observe.

L. The system SHALL store all diary entries locally in all states.

M. The system SHALL synchronize diary entries to Sponsor Portal only in ENROLLED state.

N. The system SHALL queue synchronization requests during STUDY_START_PENDING state for processing after transition to ENROLLED.

*End* *Enrollment State Machine* | **Hash**: 2505852b

---

# REQ-d00102: Enrollment State Behaviors

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p70000 | **Refines**: REQ-d00101

## Rationale

Each enrollment state has specific behaviors that determine app functionality. Clear definition of state behaviors ensures consistent user experience and proper data handling. The behaviors implement the product requirements for personal use mode, enrolled use mode, and the Study Start gating workflow.

## Assertions

A. In PERSONAL_USE state, the system SHALL store all data locally only with no network synchronization.

B. In PERSONAL_USE state, the system SHALL display "Personal Diary" branding with no sponsor customization.

C. In PERSONAL_USE state, the system SHALL display "Join a Study" option in settings menu.

D. In LINKING_PENDING state, the system SHALL display the linking code entry screen.

E. In LINKING_PENDING state, the system SHALL continue storing diary entries locally.

F. In LINKING_PENDING state, the system SHALL allow navigation back to personal use mode.

G. In STUDY_START_PENDING state, the system SHALL display sponsor branding.

H. In STUDY_START_PENDING state, the system SHALL display prompt to complete Study Start questionnaire.

I. In STUDY_START_PENDING state, the system SHALL store diary entries locally without synchronization.

J. In STUDY_START_PENDING state, the system SHALL display "Waiting for study approval" status indicator.

K. In ENROLLED state, the system SHALL display full sponsor branding.

L. In ENROLLED state, the system SHALL synchronize diary entries automatically when online.

M. In ENROLLED state, the system SHALL display synchronization status indicators.

N. In NOT_PARTICIPATING state, the system SHALL preserve all locally stored data.

O. In NOT_PARTICIPATING state, the system SHALL NOT attempt data synchronization.

P. In NOT_PARTICIPATING state, the system SHALL display the "Contact Study Coordinator" screen.

Q. In NOT_PARTICIPATING state, the system SHALL allow continued diary entry creation for personal use.

*End* *Enrollment State Behaviors* | **Hash**: ae21987f

---

# REQ-d00103: Disconnection Detection

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p70010 | **Refines**: REQ-d00098

## Rationale

The app must detect when the patient has been disconnected from the study by the Sponsor Portal. Disconnection can occur for various reasons (lost device reported, patient withdrawal, administrative action). The app detects disconnection through failed API calls, as the server invalidates tokens upon disconnection. Graceful handling ensures no data loss and clear communication to the patient.

## Assertions

A. The system SHALL detect disconnection through HTTP 401 response during synchronization attempts.

B. The system SHALL detect disconnection through HTTP 403 response with error body containing "PATIENT_DISCONNECTED" code.

C. The system SHALL detect disconnection through WebSocket connection termination with close code 4001.

D. The system SHALL verify disconnection by attempting token refresh before transitioning state.

E. The system SHALL transition to NOT_PARTICIPATING state only after confirming token refresh failure.

F. The system SHALL NOT transition to NOT_PARTICIPATING state due to transient network errors.

G. The system SHALL display a non-dismissible modal when disconnection is detected during active app use.

H. The system SHALL automatically transition to NOT_PARTICIPATING state on next app launch if disconnection occurred while app was backgrounded.

I. The system SHALL preserve the last successful sync timestamp for display on the Contact Study Coordinator screen.

J. The system SHALL log disconnection detection with timestamp and detection method to local diagnostics.

*End* *Disconnection Detection* | **Hash**: 0ef54680

---

# REQ-d00104: Contact Study Coordinator Screen

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p70010, REQ-p70011 | **Refines**: REQ-d00101

## Rationale

When a patient is disconnected from a study, they need clear guidance on what happened and what to do next. The Contact Study Coordinator screen provides this information without exposing sensitive details about why the disconnection occurred. The screen must balance informative messaging with actionable next steps while allowing continued diary use for personal tracking.

## Assertions

A. The system SHALL display the Contact Study Coordinator screen when enrollment state is NOT_PARTICIPATING.

B. The screen SHALL display heading "Study Connection Paused".

C. The screen SHALL display message "Your connection to the study has been paused. Your diary entries are still being saved on this device. Please contact your study coordinator for assistance."

D. The screen SHALL display the sponsor name if available from cached configuration.

E. The screen SHALL display a "Call Study Coordinator" button if phone number is available in cached sponsor configuration.

F. The screen SHALL display a "Email Study Coordinator" button if email is available in cached sponsor configuration.

G. The system SHALL launch the native phone dialer when "Call Study Coordinator" is tapped.

H. The system SHALL launch the native email client when "Email Study Coordinator" is tapped.

I. The screen SHALL display "Continue to Diary" button to allow personal diary use.

J. The screen SHALL display "Enter New Linking Code" button to initiate re-enrollment.

K. The screen SHALL display last successful sync date/time: "Last synced: [date] [time]".

L. The screen SHALL NOT display the reason for disconnection (this information is not available to the app).

M. The screen SHALL be displayed as the default view when app is opened in NOT_PARTICIPATING state.

N. The screen SHALL use sponsor branding colors if available in cached configuration, otherwise default branding.

*End* *Contact Study Coordinator Screen* | **Hash**: 9e53fe8a

---

# REQ-d00105: Reconnection Recovery Path

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p70011 | **Refines**: REQ-d00101

Addresses: JNY-Portal-Enrollment-02

## Rationale

After disconnection, patients may be reconnected to the study with a new linking code provided by clinical staff. The reconnection process must verify the new code, restore synchronization, and upload any diary entries created during the disconnected period. The recovery path ensures data continuity and seamless resumption of study participation.

## Assertions

A. The system SHALL allow entry of a new linking code from the NOT_PARTICIPATING state.

B. The system SHALL validate the new linking code through the standard linking code validation flow.

C. The system SHALL verify that the new linking code is associated with the same patient record on the server.

D. The system SHALL clear cached sponsor configuration before applying configuration from the new enrollment.

E. The system SHALL transition from NOT_PARTICIPATING to STUDY_START_PENDING upon successful linking code validation if Study Start is required.

F. The system SHALL transition from NOT_PARTICIPATING directly to ENROLLED if prior Study Start approval is still valid.

G. The system SHALL queue all locally stored diary entries for synchronization upon reconnection.

H. The system SHALL synchronize entries created during disconnection period with accurate timestamps.

I. The system SHALL display synchronization progress indicator during bulk upload of backlogged entries.

J. The system SHALL handle sync conflicts by applying server-side conflict resolution rules.

K. The system SHALL log reconnection event with new linking timestamp and number of backlogged entries.

L. The system SHALL NOT require the user to re-enter diary entries created during disconnection.

*End* *Reconnection Recovery Path* | **Hash**: 01389d10

---

## Section 5: Study Start Questionnaire

# REQ-d00106: Study Start Questionnaire Rendering

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p01065, REQ-p01066

Addresses: JNY-Study-Start-01

## Rationale

The Study Start questionnaire is a gating requirement for clinical trial enrollment. The questionnaire must be rendered consistently with the overall app experience while following the specific questionnaire design defined in REQ-p01066. The rendering implementation uses custom Flutter components per REQ-p01065-B, not a generic form builder.

## Assertions

A. The system SHALL display the Study Start questionnaire prompt immediately after successful linking code validation.

B. The system SHALL render the questionnaire using the custom Flutter questionnaire component for the configured questionnaire type.

C. The system SHALL load questionnaire definition including questions, response options, and validation rules from local configuration.

D. The system SHALL apply sponsor-specific theming to questionnaire components.

E. The system SHALL display questionnaire progress indicator showing current section and total sections.

F. The system SHALL support scrolling for questionnaires that exceed viewport height.

G. The system SHALL preserve questionnaire state when app is backgrounded or interrupted, subject to session timeout constraints defined in REQ-p01073.

H. Unless the session has expired per REQ-p01073, the system SHALL restore questionnaire progress on app resume.

I. The system SHALL render validation errors inline with the corresponding question.

J. The system SHALL prevent submission until all required questions are answered.

K. The system SHALL display clear indication of required vs optional questions.

L. The system SHALL support the Daily Epistaxis Record questionnaire type as the default Study Start questionnaire.

M. The system SHALL allow sponsors to configure alternative Study Start questionnaire types.

*End* *Study Start Questionnaire Rendering* | **Hash**: cbb2b7e7

---

# REQ-d00107: Questionnaire Response Collection and Storage

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p01066, REQ-p00004

## Rationale

Questionnaire responses must be captured and stored following the event sourcing model. Local storage ensures responses are preserved even if network is unavailable. Each response interaction is captured as an immutable event for audit trail compliance. The storage format supports both immediate local access and eventual synchronization to the Sponsor Portal.

## Assertions

A. The system SHALL store each questionnaire response as an immutable event per the event sourcing model.

B. The system SHALL capture response events including: questionId, responseValue, responseTimestamp, questionnaireInstanceId.

C. The system SHALL store questionnaire responses in local database immediately upon user input.

D. The system SHALL NOT require network connectivity for questionnaire response storage.

E. The system SHALL capture response modification events when users change answers before submission.

F. The system SHALL preserve the complete response history including modifications in the event log.

G. The system SHALL associate questionnaire responses with the questionnaire version used.

H. The system SHALL store timestamps in patient's wall-clock time with timezone offset per REQ-p01066-L.

I. The system SHALL generate unique questionnaire instance IDs for each questionnaire attempt.

J. The system SHALL maintain referential integrity between questionnaire instance and individual response events.

K. The system SHALL encrypt stored questionnaire responses using the same encryption as diary entries.

*End* *Questionnaire Response Collection and Storage* | **Hash**: d5097084

---

# REQ-d00108: Questionnaire Submission Flow

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p01065, REQ-p01064

Addresses: JNY-Study-Start-01

## Rationale

Questionnaire submission initiates the investigator approval workflow. The submission creates a final event that marks the questionnaire as complete from the patient's perspective. The app must handle the asynchronous approval process and notify the patient when approval is received, enabling the transition to full study participation.

## Assertions

A. The system SHALL display a "Submit" button when all required questions are answered.

B. The system SHALL display a submission confirmation dialog before final submission.

C. The confirmation dialog SHALL display message "Once submitted, your responses will be sent to your study coordinator for review. You will not be able to change your answers after submission."

D. The system SHALL create a "QUESTIONNAIRE_SUBMITTED" event upon user confirmation.

E. The system SHALL queue the submission event for synchronization to Sponsor Portal.

F. The system SHALL display "Submitting..." progress indicator during network submission.

G. The system SHALL display "Submitted - Awaiting Review" status after successful network submission.

H. The system SHALL display "Saved - Will Submit When Online" status if network is unavailable at submission time.

I. The system SHALL automatically submit queued submissions when network connectivity is restored.

J. The system SHALL poll for approval status every 60 seconds while app is active in STUDY_START_PENDING state.

K. The system SHALL receive approval notification via push notification when available.

L. The system SHALL transition to ENROLLED state upon receiving investigator approval confirmation.

M. The system SHALL display celebratory confirmation screen upon transitioning to ENROLLED state.

N. The confirmation screen SHALL display message "Welcome to the study! Your daily diary entries will now sync automatically."

O. The system SHALL preserve questionnaire responses indefinitely for audit purposes.

*End* *Questionnaire Submission Flow* | **Hash**: 50d5db71

---

## References

- **Mobile App Requirements**: prd-diary-app.md (REQ-p00043, REQ-p00006, REQ-p00007)
- **Portal Requirements**: prd-portal.md (REQ-p70007, REQ-p70009, REQ-p70010, REQ-p70011)
- **Linking Code Validation**: dev-linking.md (REQ-d00078, REQ-d00079, REQ-d00081)
- **Questionnaire System**: prd-questionnaire-system.md (REQ-p01065)
- **Epistaxis Questionnaire**: prd-questionnaire-epistaxis.md (REQ-p01066)
- **Event Sourcing**: prd-database.md (REQ-p00004)
- **Security Implementation**: dev-security.md

---

## Revision History

| Version | Date | Changes | Ticket |
| --- | --- | --- | --- |
| 1.0 | 2026-01-27 | Initial mobile app linking implementation specification | CUR-774 |

---

**Document Classification**: Internal Use - Development Specification
**Review Frequency**: Quarterly or when modifying mobile app linking implementation
**Owner**: Development Team
