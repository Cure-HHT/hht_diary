# Diary Mobile Application GUI

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2026-03-05
**Status**: Draft

> **See**: prd-diary-app.md for the parent Diary Mobile Application requirement
> **See**: prd-system.md for platform overview

---

## Top Navigation Bar

# REQ-p01075: Top Navigation Bar

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p00043

## Rationale

A consistent, always-visible navigation bar gives patients reliable access to both application-level and account-level functions. Separating app concerns from user concerns into two distinct menus reduces cognitive load and follows standard mobile UI conventions (hamburger menu for app features, person icon for account features).

## Assertions

A. The mobile app SHALL display a fixed top navigation bar containing a hamburger menu icon (three horizontal lines) on the left side, opening the App Menu.

B. The top navigation bar SHALL contain the sponsor/app logo in the center.

C. The top navigation bar SHALL contain a person icon on the right side, opening the User Menu.

D. The top navigation bar SHALL remain visible on the main screen at all times.

E. Tapping anywhere outside an open menu SHALL dismiss it.

F. Only one menu SHALL be open at a time. Opening one menu SHALL close the other if it is open.

*End* *Top Navigation Bar* | **Hash**: 027debad

---

## User Menu

# REQ-p01076: User Menu

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01075

## Rationale

The User Menu groups account and study-related actions under the person icon, which is the standard location patients expect for personal settings.

## Assertions

A. The User Menu SHALL be accessed by tapping the person icon on the right side of the top navigation bar.

B. The User Menu SHALL display a dropdown/popover with the heading "User Settings".

C. The User Menu SHALL contain links to the following items in order: User Profile Screen, Join Study Shortcut, Help Center Screen.

D. Each menu item SHALL display an appropriate icon to the left of its label.

E. The Join Study Shortcut SHALL navigate to the User Profile Screen scrolled to the Clinical Trial section.

F. When the patient is linked to at least one study, the Join Study Shortcut SHALL be replaced with a Study Status Shortcut that navigates to the User Profile Screen scrolled to the Clinical Trial section.

*End* *User Menu* | **Hash**: 9c51b097

---

## Join Study Screen

# REQ-p01082: Join Study Screen

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01077-D

## Rationale

The Join Study screen is the patient's entry point into clinical trial participation. Providing a dedicated screen for linking code entry ensures the process is discoverable, focused, and free from distractions.

## Assertions

A. The Join Study screen SHALL provide a text input for entering a linking code.

B. The Join Study screen SHALL accept linking codes in both formatted (XX-XXX-XXXXX) and unformatted (XXXXXXXXXX) styles.

C. The Join Study screen SHALL display visual feedback during linking code validation.

D. The Join Study screen SHALL display a back arrow or close button that returns the patient to the previous screen.

*End* *Join Study Screen* | **Hash**: 8eb89d10

---

## User Profile Screen

# REQ-p01077: User Profile Screen

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01076-C

## Rationale

The User Profile screen provides a dedicated space for account management and clinical trial status. Displaying the Participation Status Badge here gives patients a clear view of their study linking status without cluttering the main screen. Maintaining a consistent branding presence at the top of this screen gives users a sense of continuity when transitioning to/from study participation.

## Assertions

A. The User Profile screen SHALL be accessed from the User Menu.

B. The User Profile screen SHALL display the app logo at the top, regardless of study linking status.

C. The User Profile screen SHALL display a back arrow in the top-left corner that returns the patient to the previous screen.

D. The User Profile screen SHALL contain exactly the following items, in order: Account Settings Screen, Join Study Screen.

E. The User Profile screen SHALL display a "Clinical Trial" section below the menu items.

F. The "Clinical Trial" section SHALL display the Participation Status Badge reflecting the patient's current study participation status.

G. When the patient is not linked to any clinical trial, the "Clinical Trial" section SHALL display a message indicating that the patient is not currently linked to a clinical trial, with guidance on how to join.

*End* *User Profile Screen* | **Hash**: fc061bcc

---

## Account Settings Screen

# REQ-p01083: Account Settings Screen

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01077-D

## Rationale

A dedicated Account Settings screen allows patients to manage their account credentials and preferences without cluttering the User Profile screen with editable fields.

## Assertions

A. The Account Settings screen SHALL be accessible from the User Profile screen.

B. The Account Settings screen SHALL allow the patient to change their password.

C. The Account Settings screen SHALL allow the patient to change their email address.

D. The Account Settings screen SHALL display a back arrow or close button that returns the patient to the previous screen.

*End* *Account Settings Screen* | **Hash**: 63efe18c

---

## Participation Status Badge

# REQ-p00076: Participation Status Badge

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01077-F

## Rationale

The Participation Status Badge gives patients a persistent, at-a-glance view of their clinical trial involvement. The badge adapts its appearance based on the patient's current linking state so that patients always know whether they are connected, disconnected, or no longer participating in a study.

## Assertions

A. The Participation Status Badge SHALL be displayed in the "Clinical Trial" section of the User Profile screen.

B. The badge SHALL display the sponsor logo when the patient is or has been linked to a study.

C. When the patient's status is "Linked - Awaiting Start" or "Trial Active", the badge SHALL display a confirmation message, the linking code, and the date the patient joined.

D. When the patient's status is "Disconnected", the badge SHALL display a warning indicator, a message that the connection has been interrupted, the current linking code, and a prompt to enter a new linking code.

E. When the patient is no longer participating, the badge SHALL display in an inactive style with the end date of participation.

F. The badge SHALL update automatically when the patient's participation status changes.

*End* *Participation Status Badge* | **Hash**: 852e6036

---

## App Menu

# REQ-p01078: App Menu

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01075

## Rationale

The App Menu groups application-level functions that are not specific to the patient's account or study participation. Data Export empowers patients with access to their own health data, supporting transparency and patient rights. Policies and Licenses provides a standard location for legal and compliance documents, which is expected by app store review guidelines and regulatory requirements.

## Assertions

A. The App Menu SHALL be accessed by tapping the hamburger menu icon (three horizontal lines) on the left side of the top navigation bar.

B. The App Menu SHALL display a dropdown/popover or slide-out panel.

C. The App Menu SHALL contain the following items, in order: Data Export, Policies, Licenses, App Version.

D. Each menu item SHALL display an icon, if appropriate, to the left of its label.

E. The App Version SHALL display the full semver+buildnumber of the application.

*End* *App Menu* | **Hash**: 115fd33c

---

## Policies Screen

# REQ-p01080: Policies Screen

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01078-C

## Rationale

App store review guidelines and regulatory requirements expect a standard location for legal and compliance documents. A dedicated Policies Screen groups these documents so patients can review the terms governing their use of the application and the handling of their data.

## Assertions

A. The Policies Screen SHALL display or link to the Terms of Use.

B. The Policies Screen SHALL display or link to the Privacy Policy.

C. The application SHALL NOT fetch policy content from external URLs at runtime.

D. The Policies Screen SHALL display a back arrow or close button that returns the patient to the previous screen.

*End* *Policies Screen* | **Hash**: 0962c04b

---

## Help Center Screen

# REQ-p01081: Help Center Screen

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01076-C

## Rationale

Patients need a clear path to get help when they encounter issues with the application or their study participation. A dedicated Help Center screen provides contact information and guidance without requiring the patient to leave the application. Customer service inquiries are routed to a monitored Slack channel staffed by support personnel.

## Assertions

A. The Help Center Screen SHALL be accessible from the User Menu.

B. The Help Center Screen SHALL display contact information for customer support.

C. The Help Center Screen SHALL display a back arrow or close button that returns the patient to the previous screen.

*End* *Help Center Screen* | **Hash**: f5ecea75

---

## Diary App Licenses Screen

# REQ-p01084: Diary App Licenses Screen

**Level**: prd | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01079-A

## Rationale

The Diary App must comply with the platform-wide license display requirement by providing a Licenses Screen accessible from its App Menu. The list of licenses displayed is derived from the build-time manifest.

## Assertions

A. The Diary App SHALL have a Licenses Screen accessible from the App Menu.

*End* *Diary App Licenses Screen* | **Hash**: 621882cb

---

## Disconnection Notification

# REQ-p05004: Disconnection Notification

**Level**: prd | **Status**: Draft | **Implements**: -

<!-- PLACEHOLDER REQUIREMENT — TODO(CUR-1164 follow-up):
     Code in apps/daily-diary/clinical_diary/lib/widgets/disconnection_banner.dart,
     apps/daily-diary/clinical_diary/lib/services/enrollment_service.dart, and
     related test files declares Implements: REQ-p05004 (introduced by PR #539
     for CUR-1164) but the requirement was never authored in spec/. This
     placeholder exists to keep elspais's spec.broken_references check green
     so unrelated PRs can merge.

     The CUR-1164 author SHOULD replace the Rationale and Assertions below
     with the canonical product-level definition of the disconnection
     notification contract, then promote Status from Draft to Active. The
     placeholder deliberately does not invent product-level intent; only the
     minimum prescriptive statement evidenced by the existing implementation
     appears below. -->

## Rationale

TODO(CUR-1164 follow-up): canonical product-level rationale not yet authored.
The existing implementation in `apps/daily-diary/clinical_diary/lib/widgets/disconnection_banner.dart`
reflects as-built behavior only.

## Assertions

A. The mobile app SHALL surface a notification to the patient when the
   patient enters the disconnected state.
   <!-- TODO(CUR-1164 follow-up): refine this assertion to the canonical
        product specification; current text is the minimum SHALL statement
        evidenced by existing code. -->

*End* *Disconnection Notification* | **Hash**: a5c5984b

---

## References

- **Parent**: prd-diary-app.md
- **Platform**: prd-system.md
- **Implementation**: dev-app.md
- **Architecture**: prd-architecture-multi-sponsor.md
- **Security**: prd-security.md
