# *Mobile Application* Foundation

The **Mobile Application** foundation comprises the dual-mode (personal vs. linked) operating model, *Offline-First* data entry, the **Diary Start Day** invariant, the *Sponsor*-configurable **Clinical Trial Privacy Policy**, and **Diary User Authentication**.

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

## DIARY-PRD-user-authentication: Diary User Authentication

**Level**: PRD | **Status**: Draft | **Implements**: -

### Overview

The *Mobile Application* captures acute *Epistaxis Event* data and supporting *Diary* entries that must be recorded as close to event onset as feasible. **Diary User Authentication** protects **Participant** data on the device by requiring authentication at three sensible boundaries — opening the *Mobile Application*, coming back to the *Mobile Application* after switching away, and resuming after a stretch of inactivity — while keeping that authentication step as lightweight as possible so it does not deter contemporaneous recording. Which authentication path applies for a given **Participant** is determined by the **PIN Policy** — a tri-state setting that ranges from no in-application **PIN** at all, to **PIN** as a fallback when **Device Authentication** is unavailable, to **PIN** always — combined with whether **Device Authentication** is enabled on the **Participant**'s device. A successful authentication on the active path within the **Idle Timeout** is trusted (no prompt); otherwise the **Participant** is prompted to authenticate via the active path. The whitepaper at `docs/whitepapers/authentication-strategy.md` (Sections 2–5) develops the regulatory rationale.


Diary User Authentication
: The access-control mechanism that gates **Participant** data and **Participant** *Actions* in the **Mobile Application**, satisfied via the **Active Authentication Path** for the **Participant**.

Device Authentication
: Authentication performed by the device operating system using the credential the **Participant** has configured at the device level, including device passcode, fingerprint, or face recognition.

PIN Policy
: The setting that determines whether the in-application **PIN** mechanism is used for a given **Participant**. Permitted values: **Not Required** (the in-application **PIN** mechanism is never used), **Required When Device Authentication Is Not Enabled** (the in-application **PIN** mechanism is used only when **Device Authentication** is not enabled on the **Participant**'s device), and **Required** (the in-application **PIN** mechanism is always used).

Active Authentication Path
: The authentication path engaged by **Diary User Authentication** for a given **Participant**, derived from the **PIN Policy** and the **Device Authentication** state on the **Participant**'s device:
    - **In-application PIN** when the **PIN Policy** is **Required**, or when the **PIN Policy** is **Required When Device Authentication Is Not Enabled** and **Device Authentication** is not enabled on the **Participant**'s device.
    - **Device Authentication** when the **PIN Policy** is not **Required** and **Device Authentication** is enabled on the **Participant**'s device.
    - **None** when the **PIN Policy** is **Not Required** and **Device Authentication** is not enabled on the **Participant**'s device.

Idle Timeout
: The configurable elapsed time, used both as the maximum **Participant** in-app inactivity before re-authentication is required and as the trust window for the most recent successful authentication on the **Active Authentication Path**.

### Assertions

**When — Authentication Triggers**

A. The **System** SHALL require **Diary User Authentication** when the **Participant** opens the **Mobile Application**.

B. The **System** SHALL require **Diary User Authentication** when the **Participant** comes back to the **Mobile Application** after switching away.

C. The **System** SHALL require **Diary User Authentication** when the **Participant** has been inactive in the **Mobile Application** for longer than the **Idle Timeout**.

**How — Authentication Path**

D. When a successful authentication on the **Active Authentication Path** for the **Participant** occurred within the **Idle Timeout**, the **System** SHALL satisfy **Diary User Authentication** without further **Participant** interaction.

E. When the **Active Authentication Path** for the **Participant** is **Device Authentication** and no successful **Device Authentication** event occurred within the **Idle Timeout**, the **System** SHALL prompt the **Participant** to authenticate via **Device Authentication**.

F. When the **Active Authentication Path** for the **Participant** is **In-application PIN** and no successful in-application **PIN** entry occurred within the **Idle Timeout**, the **System** SHALL prompt the **Participant** to authenticate via the in-application **PIN** mechanism.

G. When the **Active Authentication Path** for the **Participant** is **None**, the **System** SHALL satisfy **Diary User Authentication** without further **Participant** interaction.

**While Prompting**

H. While the **System** is prompting the **Participant** for authentication, the **System** SHALL NOT display **Participant** data and SHALL NOT permit any **Participant** *Action* other than authentication.

**Configuration**

I. The **System** SHALL allow a **User** in personal-use mode to select the **PIN Policy** for the **User**'s own use.

J. The **System** SHALL support *Sponsor*-configurable **PIN Policy** per deployment; when a **User** is linked to a *Sponsor* deployment, the *Sponsor*'s **PIN Policy** SHALL govern for that **Participant**, overriding any prior personal-mode selection.

K. The **System** SHALL support *Sponsor*-configurable **Idle Timeout** per deployment.

### Rationale

**Device Authentication** already addresses casual device access at the OS level; an additional in-application step adds seconds to the acute-event recording flow without materially raising the access-control bar against that threat. Trusting a fresh device unlock supports under-ten-second nosebleed recording — the contemporaneous-data property anchoring the *Sponsor*'s data-integrity case. The three triggers cover realistic re-entry points after the device could have changed hands; **Idle Timeout** does double duty as both the in-app inactivity bound and the trust window for prior authentication, so a *Sponsor* tunes one number for both.

The **PIN Policy** spans three points along the access-control spectrum: **Not Required** trusts the OS lock alone; **Required When Device Authentication Is Not Enabled** ensures a **PIN** floor for devices without a credential; **Required** invokes the in-application **PIN** unconditionally as a procedural control beyond OS unlock. **Users** choose in personal-use mode; *Sponsors* override on link. Identity assurance otherwise rests on device–subject pairing, procedural controls, and monitoring (see `docs/whitepapers/authentication-strategy.md` Section 6).

*End* *Diary User Authentication* | **Hash**: c516100c

## DIARY-PRD-user-authentication-pin: Diary User Authentication — In-Application PIN Mechanism

**Level**: PRD | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-user-authentication

### Overview

When the **Active Authentication Path** selected by the parent **Diary User Authentication** is **In-application PIN**, the **Participant** authenticates by entering a numeric secret within the *Mobile Application*. This REQ covers initial **PIN** setup, **PIN** entry to satisfy authentication, **PIN** change from settings, lockout on repeated failed entries, and *Sponsor*-initiated **PIN Reset** for recovery.


PIN
: A numeric secret of configurable length set by the **Participant** and used to satisfy **Diary User Authentication** when the in-application **PIN** mechanism is the active path.

PIN Reset
: A *Sponsor*-initiated command that clears the **Participant**'s **PIN** and returns the **Participant** to the **PIN** setup state on next access.

Failed Attempt Threshold
: The configurable number of consecutive failed **PIN** entry attempts that triggers a **Participant** lockout pending **PIN Reset**.

### Assertions

**PIN Entry**

A. The **System** SHALL satisfy **Diary User Authentication** upon successful **PIN** entry by the **Participant**.

**PIN Setup**

B. When the **Participant** has not yet set a **PIN**, the **System** SHALL require the **Participant** to set a **PIN** before any **Participant** data is accessible.

C. The **System** SHALL require the **Participant** to enter the **PIN** twice during setup and SHALL reject the setup when the two entries do not match.

**PIN Change**

D. The **System** SHALL allow the **Participant** to change their **PIN** from the **Mobile Application** settings, after first authenticating with their existing **PIN**.

**Failed Attempts and PIN Reset**

E. The **System** SHALL track consecutive failed **PIN** entry attempts.

F. When the number of consecutive failed **PIN** entry attempts reaches the configured **Failed Attempt Threshold**, the **System** SHALL prevent **Participant** access to the **Mobile Application** until a **PIN Reset** is received.

G. The **System** SHALL accept a **PIN Reset** issued by the *Sponsor* for the **Participant** and SHALL clear the **Participant**'s **PIN**.

H. Following a **PIN Reset**, the **System** SHALL require the **Participant** to set a new **PIN** before any **Participant** data is accessible.

I. The **System** SHALL reset the failed attempt counter upon successful **PIN** entry.

**Configuration**

J. The **System** SHALL support *Sponsor*-configurable **PIN** length per deployment.

K. The **System** SHALL support *Sponsor*-configurable **Failed Attempt Threshold** per deployment.

### Rationale

The in-application **PIN** mechanism is the **Diary User Authentication** path engaged when the **PIN Policy** plus **Device Authentication** state on the **Participant**'s device resolve to the **In-application PIN** **Active Authentication Path** — either because the **PIN Policy** is **Required**, or because the **PIN Policy** is **Required When Device Authentication Is Not Enabled** and the device does not have **Device Authentication** enabled. The double-entry rule at **PIN** setup catches mistyped secrets before they become a lock-out risk. The **PIN** change path is gated by re-entry of the existing **PIN** to prevent an unattended *Mobile Application* from being trivially repurposed by another person. The **Failed Attempt Threshold** bounds the brute-force surface: on reaching it, the **Participant** is held in a locked state until the *Sponsor* issues a **PIN Reset**, restoring continuity of access through a controlled, attributable channel rather than an in-application self-recovery that would re-open the brute-force surface. Failed-attempt counter reset on success prevents accumulated rare typos from compounding into a lockout over normal use. The trigger timing for **Diary User Authentication** (open, return, **Idle Timeout** of inactivity) is governed by the parent REQ and applies uniformly across paths.

*End* *Diary User Authentication — In-Application PIN Mechanism* | **Hash**: edd1b330

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
