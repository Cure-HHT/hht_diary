# *Mobile Application* Navigation and Screens

The foundational navigation surfaces of the **Mobile Application** comprise the **Main Screen** layout (zones, the **Needs your attention** task panel, the **Your Records** content area, fixed bottom actions), the single **Application Menu** and the screens it reaches (**User Profile**, Accessibility and Preferences), and the *Calendar* / *Day View* pair the *Participant* uses to navigate to any past date.

## DIARY-GUI-main-screen-layout: Main Screen Layout

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-mobile-application

### Overview

The **Main Screen** is the **Participant**'s primary interface for daily *Diary* use. Organizing the screen into distinct zones ensures that tasks are always visible, *Diary* content is scrollable, and the primary recording *Action* is always accessible.


Main Screen
: The default screen displayed to the **Participant** upon opening the **Mobile Application**.

Needs your attention
: The collapsible panel within the **Task List** zone that displays the count of active tasks and, when expanded, the individual task items requiring **Participant** action.

Yesterday Confirmation Prompt
: An inline prompt displayed within the **Your Records** content area under the Yesterday date section when the **Participant** has not recorded a **Daily Status** for the previous day.

Your Records
: The zone on the **Mobile Application** **Main Screen** that displays the **Participant**'s recorded diary entries.

### Assertions

**Screen Zones**

A. The **Main Screen** SHALL display the following zones in order from top to bottom: top navigation bar, **Task List** zone, **Your Records** content area, and fixed bottom actions.

**Task List Zone**

B. The **Task List** zone SHALL contain a **Needs your attention** panel.

C. The **Needs your attention** panel SHALL display the count of active tasks regardless of whether the panel is expanded or collapsed.

D. When the **Participant** taps the **Needs your attention** panel header, the **System** SHALL toggle the panel between collapsed and expanded states.

E. When expanded, the **Needs your attention** panel SHALL display all active task items.

F. When collapsed, the **Needs your attention** panel SHALL display the task count and SHALL NOT display individual task items.

G. When a **Disconnection Notification** is active, the **System** SHALL display it within the **Task List** zone above the **Needs your attention** panel.

**Your Records Content Area**

H. The **Your Records** content area SHALL display *Diary* entries and completed **Assigned Questionnaires** grouped by date, showing Yesterday and Today sections.

I. The **Your Records** content area SHALL be scrollable between the **Task List** zone and the fixed bottom actions.

J. When a date section contains no entries, the **Your Records** content area SHALL display a message indicating no records for that date.

K. When the **Participant** has not recorded a **Daily Status** for the previous day, the **System** SHALL display the **Yesterday Confirmation Prompt** within the **Your Records** content area under the Yesterday date section.

L. The **Yesterday Confirmation Prompt** SHALL present three response options: Yes, No, and Don't Remember.

M. When the **Participant** selects Yes, the interface SHALL navigate the **Participant** to the nosebleed recording flow with the date set to the previous day.

N. When the **Participant** selects No, the interface SHALL record a **Daily Status** of No Nosebleed for the previous day and remove the **Yesterday Confirmation Prompt**.

O. When the **Participant** selects Don't Remember, the interface SHALL record a **Daily Status** of Don't Remember for the previous day and remove the **Yesterday Confirmation Prompt**.

P. The **Yesterday Confirmation Prompt** SHALL NOT appear if the **Participant** has already recorded a **Daily Status** for the previous day.

**Fixed Bottom Actions**

Q. The **Main Screen** SHALL display a Record Nosebleed button fixed at the bottom, regardless of scroll position.

R. The **Main Screen** SHALL display a View *Calendar* button fixed at the bottom below the Record Nosebleed button, regardless of scroll position.

### Rationale

The zone ordering — top navigation bar, **Task List** zone, **Your Records** content area, fixed bottom actions — is an attention-priority layout: the **Needs your attention** panel sits directly under the navigation bar so pending work is the first thing the **Participant** sees, and the two highest-frequency actions (Record Nosebleed, View *Calendar*) are pinned at the most-reachable thumb position regardless of scroll. Making the **Needs your attention** panel collapsible keeps a persistent, always-visible task count without forcing the full *Task List* to compete with *Diary* content for vertical space; a **Participant** with nothing pending sees a small count rather than empty chrome. Surfacing the **Disconnection Notification** inside the **Task List** zone above the panel keeps connection state in the same attention region as tasks. The **Yesterday Confirmation Prompt** lives inline in **Your Records** under the Yesterday section — where the **Participant** naturally looks to check whether yesterday is accounted for — and its three options (Yes / No / Don't Remember) map directly to the three valid **Daily Status** values, so confirming the previous day is a one-tap *Action* resolved in place.

> **Follow-up — configurability**: This requirement currently encodes
> the only option implemented in code. Future sponsors may require
> different rules; introduce a configurable seam (e.g. a parameter on
> the *Sponsor*-overlay parent, or a new platform-side template the
> *Sponsor*-overlay REQ Satisfies) when the need arises. Until that seam
> exists, this REQ is normative for the current deployment.

*End* *Main Screen Layout* | **Hash**: 29975741

## DIARY-GUI-mobile-navigation: Mobile Application Navigation and Screens

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-mobile-application

### Overview

The **Mobile Application** provides a single **Application Menu** accessible from the top navigation bar, containing account, study, and support actions. The top navigation bar is visible on the **Main Screen** at all times.


Application Menu
: The menu accessed from the right side of the top navigation bar, providing access to account, study, and support functions.

### Assertions

**Top Navigation Bar**

A. The **Main Screen** SHALL display a top navigation bar containing the *Sponsor* or **Mobile Application** logo on the left and the **Application Menu** access on the right.

B. The top navigation bar SHALL remain visible on the **Main Screen** at all times.

C. Tapping anywhere outside the open **Application Menu** SHALL dismiss it.

**Application Menu**

D. The **Application Menu** SHALL contain the following items: *User* Profile, Join the Study, and Help Center.

E. When the **Participant** is linked to a study, the **Application Menu** SHALL NOT display the Join the Study item.

F. When the **User** selects Join the Study, the **System** SHALL navigate the **User** to the *Linking Code* entry screen.

### Rationale

Collapsing the former two-menu split (a separate *User* Menu and *Application Menu*) into a single **Application Menu** removes the navigation ambiguity of deciding which menu holds a given *Action* — every account, study, and support destination now lives behind one affordance on the right of the navigation bar. The menu carries only the three entry points a **Participant** reaches directly from the navigation bar — *User* Profile (which in turn surfaces status, settings, privacy, and accessibility), Join the Study, and Help Center — while the richer per-screen detail lives in the dedicated screen requirements (`DIARY-GUI-user-profile`, `DIARY-GUI-accessibility-preferences`). Hiding Join the Study once the **Participant** is linked removes the no-op *Action* that converted them from **User** to **Participant** in the first place. Dismiss-on-outside-tap is the standard mobile affordance for a transient menu surface.

> **Follow-up — configurability**: This requirement currently encodes
> the only option implemented in code. Future sponsors may require
> different rules; introduce a configurable seam (e.g. a parameter on
> the *Sponsor*-overlay parent, or a new platform-side template the
> *Sponsor*-overlay REQ Satisfies) when the need arises. Until that seam
> exists, this REQ is normative for the current deployment.

*End* *Mobile Application Navigation and Screens* | **Hash**: 059118bb

## DIARY-GUI-calendar-day-view: Calendar and Day View

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-mobile-application

### Overview

The **Calendar** provides **Participants** with a monthly overview of their *Diary* activity and a way to navigate to any past date to view, add, or edit entries. The **Day View** is the screen displayed when a **Participant** selects a date from the **Calendar**.


Calendar
: The monthly view modal displaying date states and allowing the **Participant** to navigate to a specific date.

Day View
: The screen displayed when the **Participant** selects a date from the **Calendar**, showing the entries for that date or prompting the **Participant** to record a **Daily Status**.

### Assertions

**Calendar Modal**

A. When the **Participant** selects the *Calendar* button, the interface SHALL display the **Calendar** as a modal overlay.

B. The **Calendar** SHALL display a monthly view with navigation arrows to move between months.

C. Each date in the **Calendar** SHALL display a visual indicator representing its *Diary* state.

D. The **Calendar** SHALL display a legend identifying each visual indicator state.

E. The **Calendar** SHALL display the following date states: nosebleed events recorded, no nosebleeds confirmed, unknown / don't remember, incomplete or missing data, not recorded, **locked, and today**.

F. A date SHALL display the incomplete state when the **Participant** has one or more **Incomplete Records** for that date.

G. A date SHALL display the missing state when the date is within the *Diary* period (from *Diary* Start Day to yesterday) and the *Participant* has not recorded any *Daily Status* for that date.

H. The **Calendar** SHALL present a close *Action* that dismisses the modal and returns the **Participant** to the **Main Screen**.

**Day View — No Daily Status Recorded**

I. When the selected date has no **Daily Status** recorded, the **Day View** SHALL display the date and the prompt "What happened on this day?" with three actions: Add nosebleed event, No nosebleed events, and I don't recall / unknown.

J. When the **Participant** selects No nosebleed events, the interface SHALL record a **Daily Status** of No Nosebleed for that date.

K. When the **Participant** selects I don't recall / unknown, the interface SHALL record a **Daily Status** of Don't Remember for that date.

L. When the **Participant** selects Add nosebleed event, the interface SHALL navigate the **Participant** to the nosebleed recording flow with the date set to the selected date.

**Day View — Daily Status Recorded**

M. When the selected date has a **Daily Status** recorded, the **Day View** SHALL display the date, the total event count, an Add new event *Action*, and a list of all entries for that date.

N. Each nosebleed entry in the list SHALL display the start time, timezone, severity, and duration.

O. Each entry in the list SHALL be selectable.

P. Submitted **Assigned Questionnaires** SHALL appear in the entries list on the date they were submitted.

**Entry Selection**

Q. When the **Participant** selects an entry, the interface SHALL navigate to the nosebleed recording flow for editing if the entry has not exceeded the **Lock Threshold**, or display the entry details in a read-only state if it has.

**Day View Navigation**

R. The **Day View** SHALL present a back *Action* that returns the **Participant** to the **Calendar**.

**Locked Dates**

S. When a date has exceeded the **Lock Threshold**, the **Calendar** SHALL display that date in a greyed-out visual style distinct from other date states.

T. When the **Participant** selects a locked date with no **Daily Status** recorded, the **Day View** SHALL display a message indicating no record exists for that date and that the date can no longer be edited. The three *Action* buttons (Add nosebleed event, No nosebleed events, I don't recall / unknown) SHALL NOT be displayed.

U. When the **Participant** selects a locked date with a **Daily Status** recorded, the **Day View** SHALL display the existing entries in a read-only state and SHALL display a message indicating the date can no longer be edited. The Add new event *Action* SHALL NOT be displayed.

### Rationale

The *Calendar* is the *Participant*'s at-a-glance survey of their *Diary* period: every date's visual indicator answers "have I recorded for this day, and if so, what?" without forcing the *Participant* to drill into each date. The seven-state legend (recorded events, confirmed no-events, don't-remember, incomplete-or-missing, not-recorded, locked, today) covers every *Diary*-state distinction the platform tracks; collapsing two states into one indicator would hide either incomplete-record warnings or locked-date evidence that the *Participant* needs to see. The *Day View* bifurcation (no-status-recorded prompt vs. status-recorded list) reflects two distinct *Participant* journeys — first-time entry for a date (Add / No / Don't recall three-*Action* prompt) vs. revisiting an already-recorded date (entry list with Add new event affordance). Lock-state handling on a locked date suppresses every *Action* that would attempt to modify the date, surfacing the lock explicitly rather than letting the *Participant* tap an *Action* and discover the rejection — the explanatory message ("can no longer be edited") is what makes the lock comprehensible. Submitted **Assigned Questionnaires** appearing in the date's entry list grounds the *Questionnaire* as a part of the *Diary* record on the date it landed, rather than as an out-of-band artifact the *Participant* has to navigate separately to find.

> **Follow-up — configurability**: This requirement currently encodes
> the only option implemented in code. Future sponsors may require
> different rules; introduce a configurable seam (e.g. a parameter on
> the *Sponsor*-overlay parent, or a new platform-side template the
> *Sponsor*-overlay REQ Satisfies) when the need arises. Until that seam
> exists, this REQ is normative for the current deployment.

*End* *Calendar and Day View* | **Hash**: dc55717e

## DIARY-GUI-user-profile: User Profile Screen

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-mobile-application

### Overview

The **User Profile** screen consolidates the **Participant**'s study connection status, personal settings, and application information in a single place. **Participants** use it to check their study link, join a study, manage authentication preferences, and access privacy and legal information.


User Profile Screen
: The screen accessible from the **Application Menu** that displays the **Participant**'s study participation status and application settings.

User Profile
: The screen in the **Mobile Application** showing the **Participant**'s study participation details and settings.

### Assertions

**Your Status**

A. The **User Profile** screen SHALL display a Your Status section showing the **Participant**'s current study participation state.

B. When the **User** is not linked to a study, the Your Status section SHALL display a message indicating no active study link and a Join the Study button.

C. When the **User** selects the Join the Study button from the **User Profile** screen, the **System** SHALL navigate the **User** to the *Linking Code* entry screen.

D. When the **Participant** is linked to a study, the Your Status section SHALL display the **Participation Status Badge** as defined in `DIARY-GUI-participation-status-badge`.

**Export Data**

E. The **User Profile** screen SHALL display an Export Data option.

**Settings and Information**

F. The **User Profile** screen SHALL display an **Application Privacy Policy** option that navigates the **User** to the **Application Privacy Policy** screen.

G. The **User Profile** screen SHALL display a Licenses option that navigates the **User** to a screen showing open-source and third-party license information.

H. The **User Profile** screen SHALL display an Accessibility and Preferences option that navigates the **User** to the accessibility and preferences settings.

I. The **User Profile** screen SHALL display the **Application Biometric Lock** configuration option as defined in `DIARY-GUI-user-authentication`.

### Rationale

The **User Profile** screen is the single destination for everything personal-to-the-**Participant** that is not part of the daily recording flow: study status, data export, and the app-level settings and legal information. Consolidating these behind one **Application Menu** entry keeps the navigation bar uncluttered and gives the **Participant** one predictable place to look. The Your Status section is the anchor for study connection — guidance plus a Join the Study button when unlinked, the **Participation Status Badge** when linked — so a **Participant** can always confirm and act on their link state from one screen. Delegating the biometric-lock control (`DIARY-GUI-user-authentication`) and the accessibility settings (`DIARY-GUI-accessibility-preferences`) to their own requirements keeps each concern independently specified while presenting them to the **Participant** as entries on this one screen.

> **Follow-up — configurability**: This requirement currently encodes
> the only option implemented in code. Future sponsors may require
> different rules; introduce a configurable seam (e.g. a parameter on
> the *Sponsor*-overlay parent, or a new platform-side template the
> *Sponsor*-overlay REQ Satisfies) when the need arises. Until that seam
> exists, this REQ is normative for the current deployment.

*End* *User Profile Screen* | **Hash**: c915b967

## DIARY-GUI-accessibility-preferences: Accessibility and Preferences

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-mobile-application

### Overview

The Accessibility and Preferences screen allows **Participants** to customize the **Mobile Application** for better readability and usability, accommodating different visual and reading needs.

### Assertions

A. The Accessibility and Preferences screen SHALL display a Dyslexia-friendly font option.

B. When the **Participant** enables the Dyslexia-friendly font, the **System** SHALL apply the OpenDyslexic font throughout the **Mobile Application**.

C. The Accessibility and Preferences screen SHALL display a Larger Text and Controls option.

D. When the **Participant** enables Larger Text and Controls, the **System** SHALL increase the size of text and interactive elements throughout the **Mobile Application**.

### Rationale

*Participant*-reported outcome data is only as reliable as the **Participant**'s ability to read the prompts and operate the controls, and an HHT *Trial* population spans a wide range of ages and visual needs. Offering an OpenDyslexic font option and a Larger Text and Controls option — applied application-wide rather than per-screen — lets a **Participant** who needs either accommodation set it once and have it hold across the whole recording and *Questionnaire* flow, reducing miskeyed entries and abandoned tasks that would otherwise degrade data completeness.

> **Follow-up — configurability**: This requirement currently encodes
> the only option implemented in code. Future sponsors may require
> different rules; introduce a configurable seam (e.g. a parameter on
> the *Sponsor*-overlay parent, or a new platform-side template the
> *Sponsor*-overlay REQ Satisfies) when the need arises. Until that seam
> exists, this REQ is normative for the current deployment.

*End* *Accessibility and Preferences* | **Hash**: 95c62ef0
