# *Mobile Application* Foundation

The **Mobile Application** foundation comprises the dual-mode (personal vs. linked) operating model, *Offline-First* data entry, the **Diary Start Day** invariant, the *Sponsor*-configurable **Clinical Trial Privacy Policy**, and the **Application Lock**.

## DIARY-PRD-mobile-application: Diary Mobile Application

**Level**: PRD | **Status**: Draft | **Implements**: -

### Overview

The *Mobile Application* serves dual purposes: personal health tracking for individual **Users** and compliant data capture for clinical trials. In personal use mode the application requires no account and stores data locally. In linked use mode the application synchronizes data with the *Sponsor* portal for clinical *Trial* participation.


Mobile Application
: The iOS and Android application provided by the System for participant-reported diary data capture and questionnaire completion. Operates in personal use mode without an account or in linked use mode connected to a **Sponsor Portal** deployment.

User
: An individual using the **Mobile Application** in personal use mode, without an account and without a link to a clinical trial. A User who subsequently links to a study becomes a **Participant**.

### Assertions

A. The System SHALL provide a *Mobile Application* for iOS platforms, available via the iOS app store.

B. The System SHALL provide a *Mobile Application* for Android platforms, available via the Android app store.

C. The *Mobile Application* SHALL support full offline operation for core *Diary* functions in both personal use mode and linked use mode.

D. The *Mobile Application* SHALL NOT require account creation or login for personal use mode.

E. The **User** SHALL retain control over locally-entered data, including the right to delete it from the device while in personal use mode.

F. The *Mobile Application* SHALL obtain explicit **User** consent before synchronizing pre-existing local data to the **Sponsor Portal** upon linking.

### Rationale

The dual-mode design serves two distinct populations from a single codebase: individuals tracking nosebleeds for personal health reasons (no clinical-*Trial* context, no *Sponsor*, no account) and clinical-*Trial* participants whose data feeds the *Sponsor*'s regulatory *Submission*. Personal mode is account-less by design — it removes onboarding friction for the first population, who would not benefit from an account they cannot use against any backend, and it keeps the device the single point of control for their data. Linked mode adds the **Sponsor Portal** synchronization path; the explicit-consent gate on first sync ensures the **User** transitioning to **Participant** affirmatively chooses to share their previously-private local entries with the *Sponsor*, rather than that data being silently uploaded on link. iOS and Android coverage is required because participants in any plausible clinical-*Trial* population will hold devices on both platforms; restricting to one would exclude participants without a fallback.

*End* *Diary Mobile Application* | **Hash**: 910bb065

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

**Level**: PRD | **Status**: Draft | **Implements**: -

### Overview

Clinical *Trial* **Participants** may need to record nosebleeds that occurred before their first *Mobile Application* usage. The **Diary Start Day** establishes the earliest date for which *Diary* entries are valid, balancing the need for historical data capture with the requirement to maintain reliable data quality. The **Diary Start Day** is set automatically based on the **Participant**'s actual entries, when a **Participant** records data for a date earlier than any prior entry, the **Diary Start Day** moves backward to that date. The **Diary Start Day** never moves forward, even if the earliest entry is subsequently deleted, to preserve the historical scope of the *Diary* and ensure that documented gaps remain visible.


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

*End* *Diary Start Day Definition* | **Hash**: b0c35e38

## DIARY-PRD-privacy-policy: Clinical Trial Privacy Policy

**Level**: PRD | **Status**: Draft | **Implements**: -

### Overview

The *Mobile Application* SHALL provide access to a **Clinical Trial Privacy Policy** governing *Sponsor*-side data handling for a linked study, distinct from the **Application Privacy Policy**.


Application Privacy Policy
: The privacy policy governing the Mobile Application itself, covering platform-level data handling.

Clinical Trial Privacy Policy
: The privacy policy governing a Participant's participation in a specific clinical trial, covering sponsor-side data handling. Sponsor-configurable per deployment.

### Assertions

A. The System SHALL support a *Sponsor*-configurable **Clinical Trial Privacy Policy** per deployment.

B. The System SHALL make the **Clinical Trial Privacy Policy** accessible to the *Participant* only when the *Participant* is linked to a study or is in the process of linking to a study.

C. The System SHALL retain the **Clinical Trial Privacy Policy** version that was in effect at the time of consent against the *Participant* record.

### Rationale

Two privacy policies coexist in the **Mobile Application** because two distinct controllers handle distinct data flows: the **Application Privacy Policy** covers platform-level data handling (the **Mobile Application** itself, the platform vendor's data-processor *Role*), while the **Clinical Trial Privacy Policy** covers the *Sponsor*'s clinical-*Trial* data handling for participants in a specific study. Surfacing the *Trial*-specific policy only when the *Participant* is linked or actively linking prevents the application from showing *Sponsor*-specific terms to **Users** who are using the app in personal mode and have no relationship with the *Sponsor*. Retaining the version in effect at time of consent against the *Participant* record satisfies the regulatory expectation that the document the *Participant* actually consented to (which may change over the life of the *Trial*) is preserved as evidence of informed consent.

*End* *Clinical Trial Privacy Policy* | **Hash**: defed08d

## DIARY-PRD-application-lock: Application Lock

**Level**: PRD | **Status**: Draft | **Implements**: -

### Overview

The *Mobile Application* contains *Participant*-reported clinical data and identifying information that must be protected from unauthorized access on the *Participant*'s device. An *Application Lock* requires the *Participant* to authenticate before each use, ensuring that someone who picks up an unattended device cannot view or modify *Diary* entries. The lock is configurable so each *Sponsor* deployment can select the *Authentication Method* appropriate to its risk profile and *Participant* population. When the configured method is unavailable on a *Participant*'s device, a fallback to *Device Authentication* ensures continuity of access without compromising the protective intent.


Application Lock
: The state in which the **Mobile Application** requires the **Participant** to authenticate before any **Participant**-facing screen, action, or data is accessible.

PIN
: A numeric secret of configurable length set by the **Participant** and used to release the **Application Lock**.

Device Authentication
: Authentication performed by the device operating system using the credential the **Participant** has configured at the device level, including but not limited to device passcode, fingerprint, or face recognition.

Authentication Method
: The mechanism required to release the **Application Lock**. The configured **Authentication Method** is one of: **PIN**, **Device Authentication**, or none.

Idle Timeout
: The configurable elapsed time the **Mobile Application** may remain in the background before the **System** re-applies the **Application Lock** on return to the foreground.

### Assertions

**Lock Application**

A. The **System** SHALL apply the **Application Lock** when the **Mobile Application** is launched from a fully closed state.

B. The **System** SHALL apply the **Application Lock** when the **Mobile Application** returns to the foreground after spending more than the **Idle Timeout** in the background.

C. While the **Application Lock** is applied, the **System** SHALL NOT display **Participant** data and SHALL NOT permit any **Participant** *Action* other than authentication.

**Authentication Method**

D. The **System** SHALL release the **Application Lock** only upon successful authentication using the configured **Authentication Method**.

E. When the configured **Authentication Method** is **PIN**, the **System** SHALL require the **Participant** to enter their **PIN** to release the **Application Lock**.

F. When the configured **Authentication Method** is **Device Authentication**, the **System** SHALL invoke the device operating system's authentication prompt to release the **Application Lock**.

G. When the configured **Authentication Method** is none, the **System** SHALL NOT apply the **Application Lock**.

**PIN Setup and Reset**

H. When the configured **Authentication Method** is **PIN** and the **Participant** has not yet set a **PIN**, the **System** SHALL require the **Participant** to set a **PIN** before any **Participant** data is accessible.

I. The **System** SHALL require the **Participant** to enter the **PIN** twice during setup and SHALL reject the setup when the two entries do not match.

J. The **System** SHALL allow the **Participant** to change their **PIN** from the **Mobile Application** settings, after first authenticating with their existing **PIN** or **Device Authentication**.

**Failed Attempt Handling**

K. The **System** SHALL track consecutive failed **PIN** entry attempts.

L. When the number of consecutive failed **PIN** entry attempts reaches the configured **Failed Attempt Threshold**, the **System** SHALL fall back to **Device Authentication**.

M. Upon successful **Device Authentication** following a fallback, the **System** SHALL require the **Participant** to reset their **PIN** before any **Participant** data is accessible.

N. The **System** SHALL reset the failed attempt counter upon successful authentication.

**Configuration**

O. The **System** SHALL support *Sponsor*-configurable selection of the **Authentication Method** per deployment.

P. The **System** SHALL support *Sponsor*-configurable **PIN** length per deployment.

Q. The **System** SHALL support *Sponsor*-configurable **Idle Timeout** per deployment.

R. The **System** SHALL support *Sponsor*-configurable **Failed Attempt Threshold** per deployment.

### Rationale

The **Application Lock** is the per-device gate that protects *Participant* clinical data when a device is left unattended, lost, or stolen. The lock applies at two boundaries — fresh launch and resume-from-background-after-idle — because both are realistic re-entry points after an interval in which the device could have changed hands. The "no data, no *Action* other than authentication" rule while locked closes the leakage channels that would otherwise exist (e.g., notification preview, deep-link routing into a partial workflow). The *Sponsor*-configurable **Authentication Method** lets each deployment choose between three security-posture options: **PIN** (cheapest, works on every device, controlled by the platform), **Device Authentication** (delegates to the OS-managed credential, which may include biometrics), or none (when the deployment determines a separate lock is not required). The failed-attempt fallback to **Device Authentication** rather than account lockout preserves *Participant* access — a *Participant* who has forgotten their **PIN** can still recover by authenticating against the OS credential and resetting — while still raising the bar against a casual unauthorized attempt. Failed-attempt counter reset on success prevents accumulated rare typos from compounding into a fallback over normal use.

> OPEN: Should the **Application Lock** be bypassed for **Push Notification** taps that lead to time-sensitive flows (e.g., Ongoing *Epistaxis Event* Reminder), or always enforced?

*End* *Application Lock* | **Hash**: 6798a92e
