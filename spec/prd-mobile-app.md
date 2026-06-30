# *Mobile Application* Foundation

The **Mobile Application** foundation comprises the dual-mode (personal vs. linked) operating model, *Offline-First* data entry, the **Diary Start Day** invariant, the *Sponsor*-configurable **Clinical Trial Privacy Policy**, and **Diary User Authentication**.

## DIARY-PRD-mobile-application: Diary Mobile Application

**Level**: PRD | **Status**: Draft | **Implements**: -

### Overview

The *Mobile Application* serves dual purposes: personal health tracking for individual **Users** and compliant data capture for clinical trials. In *Personal use mode* the application requires no account and stores data locally. In *Linked use mode* the application synchronizes data with the *Sponsor* Portal for clinical *Trial* participation.


Mobile Application
: The *Mobile Application* (iOS and Android) operates in personal use mode with no account required, or in linked use mode connected to a **Sponsor Portal**.

User
: An individual using the **Mobile Application** in personal use mode, without an account and without a link to a clinical trial. A User who subsequently links to a study becomes a **Participant**.

Personal use mode
: The **Mobile Application** operating with no account, storing all data locally for private health tracking outside any clinical trial.

Linked use mode
: The **Mobile Application** connected to a **Sponsor Portal**, operating as the electronic source (eSource) for the clinical trial.

### Assertions

A. The System SHALL provide a *Mobile Application* for iOS platforms, available via the iOS app store.

B. The System SHALL provide a *Mobile Application* for Android platforms, available via the Android app store.

C. The *Mobile Application* SHALL support full offline operation for core *Diary* functions in both *Personal use mode* and *Linked use mode*.

D. The *Mobile Application* SHALL NOT require account creation or login for *Personal use mode*.

E. The **User** SHALL retain control over locally-entered data, including the right to delete it from the device while in *Personal use mode*.

F. The *Mobile Application* SHALL obtain explicit **User** consent before synchronizing pre-existing local data to the **Sponsor Portal** upon linking.

### Rationale

The dual-mode design serves two distinct populations from a single codebase: individuals tracking nosebleeds for personal health reasons (no clinical-*Trial* context, no *Sponsor*, no account) and clinical-*Trial* participants whose data feeds the *Sponsor*'s regulatory *Submission*. Personal mode is account-less by design — it removes onboarding friction for the first population, who would not benefit from an account they cannot use against any backend, and it keeps the device the single point of control for their data. Linked mode adds the **Sponsor Portal** synchronization path; the explicit-consent gate on first sync ensures the **User** transitioning to **Participant** affirmatively chooses to share their previously-private local entries with the *Sponsor*, rather than that data being silently uploaded on link. iOS and Android coverage is required because participants in any plausible clinical-*Trial* population will hold devices on both platforms; restricting to one would exclude participants without a fallback.

*End* *Diary Mobile Application* | **Hash**: aa9928f9

## DIARY-PRD-mobile-offline-first: Offline-First Data Entry

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-mobile-application

### Overview

*Offline-First* architecture ensures reliable data collection regardless of network conditions. All **Users** benefit from local storage for immediate, reliable data entry. For **Participants** linked to clinical trials, automatic synchronization provides cloud backup and enables remote monitoring while maintaining the *Offline-First* experience.

### Assertions

A. The System SHALL allow **Users** to create *Diary* entries without requiring internet connectivity.

B. The System SHALL allow **Users** to edit *Diary* entries without requiring internet connectivity.

C. The System SHALL allow **Users** to view their complete entry history without requiring internet connectivity.

D. For linked **Participants**, the System SHALL indicate which entries have not yet synchronized to the **Sponsor Portal**.

E. For linked **Participants**, the System SHALL automatically synchronize unsynchronized entries when network connectivity becomes available.

### Rationale

*Diary* entries are time-sensitive: a nosebleed event must be captured as it occurs or shortly afterward to preserve recall accuracy and satisfy the ALCOA+ Contemporaneous principle. A network-required entry model would push participants toward either delayed entry (when connectivity is restored, by which time recall has degraded) or non-entry (when connectivity never recovers in the relevant window). *Offline-First* inverts that: every entry succeeds locally regardless of network state, and synchronization to the **Sponsor Portal** is a background concern handled by the platform whenever connectivity is available. The unsynchronized indicator preserves transparency for the *Participant* — they can see whether their data has reached the *Sponsor* — without making sync a gate on entry.

*End* *Offline-First Data Entry* | **Hash**: ab325a3c

## DIARY-PRD-diary-start-day: Diary Start Day Definition

**Level**: PRD | **Status**: Active | **Implements**: -

### Overview

The **Diary Start Day** establishes the earliest date for which *Diary* entries are valid, balancing the need for historical data capture with the requirement to maintain reliable data quality. The **Diary Start Day** is set automatically based on the **Participant**'s actual entries, when a **Participant** records data for a date earlier than any prior entry, the **Diary Start Day** moves backward to that date. The **Diary Start Day** never moves forward, even if the earliest entry is subsequently deleted, to preserve the historical scope of the *Diary* and ensure that documented gaps remain visible.


Diary Start Day
: The earliest date for which diary entries are valid for a given **User**.

### Assertions

A. The System SHALL establish and maintain a **Diary Start Day** for each **User**.

B. The System SHALL set the **Diary Start Day** to the date of the earliest entry the **Participant** has ever recorded.

C. When a **Participant** records an entry for a date earlier than the current **Diary Start Day**, the System SHALL move the **Diary Start Day** backward to that date.

D. The System SHALL NOT allow the **Diary Start Day** to be set earlier than 365 days before *Mobile Application* installation on the current device.

E. The **Diary Start Day** SHALL only move backward, never forward, once set.

F. The System SHALL NOT prompt **Users** to set the **Diary Start Day** during onboarding.

G. Data entered for dates before the ***Trial** Start* date SHALL NOT synchronize to the **Sponsor Portal** or Rave EDC.

H. The **System** SHALL NOT allow the **Participant** to record an entry for a date in the future.

I. The **System** SHALL display each *Calendar* day between the **Diary Start Day** and the current day, exclusive of any day for which a **Daily Status** has been recorded, as a missing day in the *Calendar*.

### Rationale

The **Diary Start Day** is the single boundary the **Mobile Application** uses to distinguish "no entry expected" from "missing entry" — every day from the **Diary Start Day** to today is part of the *Diary* period and therefore a candidate for the missing-day display in the *Calendar*. Automatic backward expansion (set to the earliest entry, can move backward but never forward) reflects two operational realities: participants discover the need to backfill historical events incrementally rather than declaring a start date up front, and once a date is recognized as part of the *Diary* period, the visible gaps on dates within it are evidence the audit and *Sponsor* reporting rely on — collapsing those gaps by moving the start day forward when the earliest entry is deleted would silently erase that evidence. The 365-day floor below installation date caps the historical window at a clinically meaningful range while leaving room for retrospective capture early in a *Trial*. Future-date rejection is a contemporaneous-data integrity floor. The non-sync rule for pre-*Trial* dates keeps the **Sponsor Portal** dataset bounded to the *Trial* period regardless of how far back the personal *Diary* extends.

### Changelog

- 2026-06-25 | b0c35e38 | - | Michael Lewis (michael@anspar.org) | First approved version

*End* *Diary Start Day Definition* | **Hash**: b0c35e38

## DIARY-PRD-privacy-policy: Clinical Trial Privacy Policy

**Level**: PRD | **Status**: Draft | **Implements**: -

### Overview

The *Mobile Application* SHALL provide access to a **Clinical Trial Privacy Policy** governing *Sponsor*-side data handling for a linked study, distinct from the **Application Privacy Policy**.


Application Privacy Policy
: The privacy policy governing the Mobile Application itself, covering platform-level data handling.

Clinical Trial Privacy Policy
: The privacy policy governing a Participant's participation in a specific clinical trial, covering sponsor-side data handling. Sponsor-configurable per study.

### Assertions

A. The System SHALL support a *Sponsor*-configurable **Clinical Trial Privacy Policy** per study.

B. The System SHALL make the **Clinical Trial Privacy Policy** accessible to the *Participant* only when the *Participant* is linked to a study or is in the process of linking to a study.

C. The System SHALL retain the **Clinical Trial Privacy Policy** version that was in effect at the time of consent against the *Participant* record.

### Rationale

Two privacy policies coexist in the **Mobile Application** because two distinct controllers handle distinct data flows: the **Application Privacy Policy** covers platform-level data handling (the **Mobile Application** itself, the platform vendor's data-processor *Role*), while the **Clinical Trial Privacy Policy** covers the *Sponsor*'s clinical-*Trial* data handling for participants in a specific study. Surfacing the *Trial*-specific policy only when the *Participant* is linked or actively linking prevents the application from showing *Sponsor*-specific terms to **Users** who are using the app in personal mode and have no relationship with the *Sponsor*. Retaining the version in effect at time of consent against the *Participant* record satisfies the regulatory expectation that the document the *Participant* actually consented to (which may change over the life of the *Trial*) is preserved as evidence of informed consent.

*End* *Clinical Trial Privacy Policy* | **Hash**: 0296fa8c

## DIARY-PRD-user-authentication: Diary User Authentication

**Level**: PRD | **Status**: Draft | **Implements**: -

### Overview

**Diary User Authentication** protects **Participant** data on the device while keeping the authentication step lightweight enough not to deter contemporaneous recording. Authentication is satisfied through one of two paths: **Device Authentication**, when the **Participant**'s device has a screen lock enabled, or the **Application Biometric Lock**, when it does not. In *Personal use mode*, no authentication is required; the **Participant** may set up the **Application Biometric Lock** from profile settings at any time. Once linked to a study, at least one authentication path must be active — the **System** detects whether a device screen lock is present and, if not, requires the **Participant** to set up the **Application Biometric Lock** before proceeding, informing the **Participant** that they may alternatively enable a screen lock at the device level to satisfy the requirement.


Device Authentication
: Authentication performed by the device operating system using the credential the **Participant** has configured at the device level, including device passcode, fingerprint, or face recognition.

Application Biometric Lock
: Authentication performed within the **Mobile Application** using the biometric sensors of the **Participant**'s device, used when the **Participant**'s device does not have a screen lock enabled.

Diary User Authentication
: The mechanism that requires the **Participant** to authenticate before accessing data or performing actions in the **Mobile Application**. The authentication method used is determined by the **Active Authentication Path**.

Active Authentication Path
: The specific authentication method the **System** applies to a given **Participant**, determined by their device and setup:
    - **Device Authentication** if the **Participant**'s device has a screen lock enabled.
    - **Application Biometric Lock** if the **Participant**'s device has no screen lock enabled and the **Participant** has set up the **Application Biometric Lock**.
    - **None** if the **Participant** is in personal use mode and has not set up the **Application Biometric Lock**.

Idle Timeout
: The configurable elapsed time used as the maximum period of **Participant** inactivity before re-authentication is required, and as the trust window for the most recent successful authentication on the **Active Authentication Path**.

### Assertions

**When — Authentication Triggers**

A. The **System** SHALL require **Diary User Authentication** when the **Participant** opens the **Mobile Application**.

B. The **System** SHALL require **Diary User Authentication** when the **Participant** returns to the **Mobile Application** after switching away.

C. The **System** SHALL require **Diary User Authentication** when the **Participant** has been inactive in the **Mobile Application** for longer than the **Idle Timeout**.

**How — Authentication Path**

D. When a successful authentication on the **Active Authentication Path** occurred within the **Idle Timeout**, the **System** SHALL satisfy **Diary User Authentication** without further **Participant** interaction.

E. When the **Active Authentication Path** is **Device Authentication** and no successful **Device Authentication** event occurred within the **Idle Timeout**, the **System** SHALL prompt the **Participant** to authenticate via **Device Authentication**.

F. When the **Active Authentication Path** is **Application Biometric Lock** and no successful **Application Biometric Lock** authentication occurred within the **Idle Timeout**, the **System** SHALL prompt the **Participant** to authenticate via the **Application Biometric Lock**.

G. When the **Active Authentication Path** is **None**, the **System** SHALL satisfy **Diary User Authentication** without further **Participant** interaction.

**While Prompting**

H. While prompting the **Participant** for authentication, the **System** SHALL NOT display **Participant** data and SHALL NOT permit any **Participant** *Action* other than authentication.

**Study Linking — Authentication Requirement**

I. When a **Participant** completes the study linking process and the **Participant**'s device does not have a screen lock enabled, the **System** SHALL require the **Participant** to set up the **Application Biometric Lock** before accessing any **Participant** data.

J. The **System** SHALL inform the **Participant** that they may alternatively enable a device screen lock to satisfy the authentication requirement.

K. When a **Participant** completes the study linking process and the **Participant**'s device has a screen lock enabled, the **System** SHALL NOT prompt the **Participant** for additional authentication setup.

**Settings**

L. The **System** SHALL allow a **Participant** to enable or disable the **Application Biometric Lock** from the **Participant**'s profile settings.

M. When a **Participant** linked to a study attempts to disable the **Application Biometric Lock** and the **Participant**'s device does not have a screen lock enabled, the **System** SHALL NOT permit the change and SHALL inform the **Participant** that either a device screen lock or the **Application Biometric Lock** is required.

**Configuration**

N. The **System** SHALL support *Sponsor*-configurable **Idle Timeout** per study.

### Rationale

**Diary User Authentication** has to clear two bars at once: protect **Participant** data on a personal device and stay light enough that it never deters contemporaneous recording of an acute *Epistaxis Event*. **Device Authentication** meets both wherever a device screen lock is already configured — it reuses the credential the **Participant** already trusts (passcode, fingerprint, or face) and adds no in-application step. Where no screen lock exists, the platform adds the **Application Biometric Lock** as an in-application path so that a linked **Participant** is never left with no authentication at all; the study-linking flow detects the missing screen lock and requires biometric enrollment — or, at the **Participant**'s choice, a device screen lock — before any data is accessible. Trusting a successful authentication on the **Active Authentication Path** for the duration of the **Idle Timeout** keeps re-prompts off the critical recording path, and the single **Idle Timeout** value serves as both the inactivity bound and the trust window so a *Sponsor* tunes one number for both.

The platform additionally defines an in-application **PIN** path (`DIARY-BASE-user-authentication-pin`) as a knowledge-factor alternative for studies that require one. That path is authored at the BASE level — its implementation is deferred and it is not used in the initial deployment — so it is excluded from the generated URS while remaining a recognized **Active Authentication Path** the platform can enable.

*End* *Diary User Authentication* | **Hash**: 6e2db0c7

## DIARY-GUI-user-authentication: Diary User Authentication — Interface

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-authentication

### Overview

This requirement defines the interface behaviors for **Diary User Authentication**: the **Application Biometric Lock** configuration option available in the **Participant**'s profile settings, and the setup prompt presented when a **Participant** links to a study on a device without a screen lock enabled.

### Assertions

**Profile Settings**

A. The **System** SHALL display the **Application Biometric Lock** as a configurable option labeled "Use Face ID / Fingerprint" in the *User Profile*.

**Study Linking Setup Screen**

B. When the study linking process determines that the **Participant**'s device does not have a screen lock enabled, the **System** SHALL display the **Application Biometric Lock** setup screen with an **Enable biometrics** button.

C. The **Application Biometric Lock** setup screen SHALL NOT present an option to skip or dismiss the enrollment requirement.

### Rationale

Surfacing the **Application Biometric Lock** as a labeled profile-settings toggle ("Use Face ID / Fingerprint") lets a **Participant** in *Personal use mode* opt into in-application protection at any time, and lets a linked **Participant** add or manage it from one place. The dedicated setup screen at study linking exists for the one case where authentication is mandatory but absent — a linked device with no screen lock — and it deliberately offers no skip or dismiss affordance, because allowing the **Participant** to bypass enrollment would leave **Participant** data unprotected in violation of the parent **Diary User Authentication** requirement.

*End* *Diary User Authentication — Interface* | **Hash**: 86acaf51

## DIARY-PRD-device-health-diagnostics: Device Health Diagnostic Export

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-mobile-application

### Overview

When synchronization to the **Sponsor Portal** is broken, the broken channel cannot report its own failure, yet a regulated incident still needs root-cause information. The *Mobile Application* therefore offers an on-demand, on-device diagnostic export that a **User** can produce and hand off out-of-band, limited to structural and operational metadata so that no *Diary* entry content leaves the device.

### Assertions

A. The *Mobile Application* SHALL provide an on-device diagnostic export that a **User** can produce on demand, reachable without network connectivity, sign-in, or an active *Sponsor* link.

B. The diagnostic export SHALL describe device health conditions affecting data capture and synchronization, including a stuck (wedged) synchronization queue.

C. The diagnostic export SHALL be limited to structural and operational metadata and SHALL NOT include *Diary* entry content.

D. The **System** SHALL allow the **User** to copy the diagnostic export and to share it through the device's standard sharing facilities.

### Rationale

A wedged outbound queue blocks every event behind it, so the *Mobile Application*'s normal synchronization path — the very thing that is broken — cannot carry a report of the failure. An out-of-band export sidesteps that and rides the existing human escalation path from **User** to *Sponsor*. The export is deliberately confined to metadata (identifiers, types, sequence numbers, timestamps, hash links, queue attempt errors, cursors, counts, versions) because it leaves the regulated boundary; that metadata is sufficient to diagnose synchronization, ordering, and integrity faults without exposing *Diary* content. On-demand production with no sign-in or link requirement keeps the export reachable in exactly the degraded states — broken auth, broken link, broken sync — where it is most needed.

*End* *Device Health Diagnostic Export* | **Hash**: 5071c90a

## DIARY-GUI-service-mode-entry: Service Mode Entry and Presentation

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-device-health-diagnostics

### Overview

The diagnostic export is presented on a "Service Mode" screen that is revealed by a deliberate, support-instructable gesture so that it stays out of a **User**'s everyday path while remaining reachable on request. Findings are presented so their severity is legible at a glance, and the export is offered as one selectable artifact with copy and share controls.

### Assertions

A. The *Mobile Application* SHALL reveal the diagnostic ("Service Mode") screen when the **User** taps the displayed application version seven times.

B. The Service Mode screen SHALL present each health condition with a severity indication and a human-readable detail.

C. The Service Mode screen SHALL present the export as a single selectable text artifact and SHALL provide copy and share controls.

### Rationale

A version-tap gesture is familiar from common mobile operating systems and is easy for support to read aloud to a **User** over the phone, while keeping the screen invisible to ordinary use. Because the export is metadata-only, the gesture is a clutter-avoidance measure rather than a security boundary. Presenting findings with explicit severity lets a non-technical **User** or *Sponsor* contact triage at a glance, and a single selectable artifact with copy and share controls supports both the paste-into-message and attach-as-file paths without dictating the channel.

*End* *Service Mode Entry and Presentation* | **Hash**: 0b05472a
