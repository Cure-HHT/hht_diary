# *Mobile Application* Navigation and Screens

The foundational navigation surfaces of the **Mobile Application** comprise the **Main Screen** layout (zones, task area, content area, fixed bottom actions), the two top-navigation-bar menus (*User* Menu, *Application Menu*) and their dependent screens, and the *Calendar* / *Day View* pair the *Participant* uses to navigate to any past date.

## DIARY-GUI-main-screen-layout: Main Screen Layout

**Level**: GUI | **Status**: Draft | **Implements**: -

### Overview

The **Main Screen** is the **Participant's** primary interface for daily *Diary* use. Organizing the screen into distinct zones ensures that urgent items (disconnection alerts and tasks) are always visible, *Diary* content is scrollable, and the primary recording *Action* is always accessible. When no tasks or alerts are active, the content area expands to use the full available space.


Main Screen
: The default screen displayed to the **Participant** upon opening the mobile application.

System Notice Area
: A dedicated zone at the top of the Main Screen reserved for persistent, non-dismissable system notices that require the Participant's attention.

### Assertions

**Screen Zones**

A. The *Main Screen* SHALL display the following zones in order from top to bottom: *System Notice Area* (when applicable), top navigation bar, *Task List* (when tasks are active), content area, and fixed bottom actions.

B. The *System Notice Area* SHALL appear above the top navigation bar.

C. When the *System Notice Area* is displayed, it SHALL NOT reduce the space available for any other *Main Screen* zone.

**Task List Area**

D. When the **Task List** contains more tasks than the available space allows, the **Task List** SHALL scroll within its allocated area.

E. When no tasks are active and no **Disconnection Notification** is displayed, the content area SHALL expand to fill the available space.

**Content Area**

F. The content area SHALL display *Diary* entries grouped by date, showing Yesterday and Today sections.

G. The content area SHALL be scrollable between the task area and the fixed bottom actions.

H. When a date section contains no entries, the content area SHALL display a message indicating no events for that date.

**Fixed Bottom Actions**

I. The **Main Screen** SHALL display a Record Nosebleed button fixed at the bottom, regardless of scroll position.

J. The **Main Screen** SHALL display a *Calendar* button fixed at the bottom below the Record Nosebleed button, regardless of scroll position.

### Rationale

The five-zone structure (*System Notice Area*, top navigation bar, *Task List*, content area, fixed bottom actions) reflects an attention-priority ordering: persistent system notices appear above everything because they typically encode a state the *Participant* must acknowledge (e.g. **Disconnection Notification**), and the fixed bottom actions appear at the most-reachable thumb position because they are the two highest-frequency *Participant* actions (Record Nosebleed, open *Calendar*). The *Task List* zone collapsing when empty (with the content area expanding to fill the space) keeps the screen from carrying empty chrome for participants in a quiet stretch of the *Trial* — most days, when there are no incomplete records or pending portal-sent questionnaires, the content area uses the full middle of the screen. Yesterday / Today grouping in the content area matches the everyday read pattern: the most recent days are what the *Participant* actually wants to see; the *Calendar* is the path to anything older.

> **Follow-up — configurability**: This requirement currently encodes
> the only option implemented in code. Future sponsors may require
> different rules; introduce a configurable seam (e.g. a parameter on
> the CAL-PRD-* parent, or a new platform-side template the CAL- REQ
> Satisfies) when the need arises. Until that seam exists, this REQ is
> normative for the Callisto deployment.

*End* *Main Screen Layout* | **Hash**: 0e9dccb1

## DIARY-GUI-mobile-navigation: Mobile Application Navigation and Screens

**Level**: GUI | **Status**: Draft | **Implements**: -

### Overview

The *Mobile Application* provides two menus accessible from the top navigation bar: a **User Menu** for account and study-related actions, and an **Application Menu** for application-level functions. Each menu leads to dedicated screens. The top navigation bar is visible on the **Main Screen** at all times.


User Menu
: The menu accessed from the right side of the top navigation bar, grouping account and study-related actions.

Application Menu
: The menu accessed from the left side of the top navigation bar, grouping application-level functions.

### Assertions

**Top Navigation Bar**

A. The **Main Screen** SHALL display a top navigation bar containing the **Application Menu** access on the left, the *Sponsor* or Application logo in the center, and the **User Menu** access on the right.

B. The top navigation bar SHALL remain visible on the **Main Screen** at all times.

C. Only one menu SHALL be open at a time. Opening one menu SHALL close the other if it is open.

D. Tapping anywhere outside an open menu SHALL dismiss it.

**User Menu**

E. The **User Menu** SHALL contain the following items: Join the Study, *User* Profile, and Help Center.

F. When the **User** clicks the "Join the Study" button SHALL navigate to the *Linking Code* entry screen.

G. When the **Participant** is linked to a study, "Join the Study" button SHALL not be visible on the menu.

H. The Help Center screen SHALL display contact information for support.

**User Profile Screen**

I. When the **User** is not linked to any study, the Clinical *Trial* section SHALL display a message indicating no active study link and guidance on how to join.

J. When the **Participant** is linked to a study, the Clinical *Trial* section SHALL display the **Participation Status Badge**.

**Application Menu**

K. The **Application Menu** SHALL contain the following items: Accessibility and Preferences, **Application Privacy Policy**, and Licenses.

L. The **Application Privacy Policy** screen SHALL display or link to the **Application Privacy Policy**.

M. The Licenses screen SHALL display open-source and third-party license information.

### Rationale

The two-menu split (*User* Menu on the right, *Application Menu* on the left) groups actions by the question the *Participant* is asking: "something about my study" (*User* Menu: Join the Study, *User* Profile, Help Center) vs. "something about the app itself" (*Application Menu*: Accessibility, *Application Privacy Policy*, Licenses). Single-menu-open-at-a-time is a standard mobile-UX safety (opening one menu closes the other) so the *Participant* never sees two competing surfaces *Overlap*. Hiding Join the Study when already linked (assertion G) removes the no-op *Action* from the menu — once the *Participant* is a **Participant**, the *Action* that converted them from **User** to **Participant** is no longer meaningful. The *User* Profile's Clinical *Trial* section is the *Participant*'s anchor for their study status: empty + guidance when unlinked, **Participation Status Badge** when linked. The *Application Menu*'s three items are the standard app-level metadata participants may need to reach but rarely do (privacy, accessibility, licenses).

> **Follow-up — configurability**: This requirement currently encodes
> the only option implemented in code. Future sponsors may require
> different rules; introduce a configurable seam (e.g. a parameter on
> the CAL-PRD-* parent, or a new platform-side template the CAL- REQ
> Satisfies) when the need arises. Until that seam exists, this REQ is
> normative for the Callisto deployment.

*End* *Mobile Application Navigation and Screens* | **Hash**: ecc7e268

## DIARY-GUI-calendar-day-view: Calendar and Day View

**Level**: GUI | **Status**: Draft | **Implements**: -

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

P. Submitted **Portal-Sent Questionnaires** SHALL appear in the entries list on the date they were submitted.

**Entry Selection**

Q. When the **Participant** selects an entry, the interface SHALL navigate to the nosebleed recording flow for editing if the entry has not exceeded the **Lock Threshold**, or display the entry details in a read-only state if it has.

**Day View Navigation**

R. The **Day View** SHALL present a back *Action* that returns the **Participant** to the **Calendar**.

**Locked Dates**

S. When a date has exceeded the **Lock Threshold**, the **Calendar** SHALL display that date in a greyed-out visual style distinct from other date states.

T. When the **Participant** selects a locked date with no **Daily Status** recorded, the **Day View** SHALL display a message indicating no record exists for that date and that the date can no longer be edited. The three *Action* buttons (Add nosebleed event, No nosebleed events, I don't recall / unknown) SHALL NOT be displayed.

U. When the **Participant** selects a locked date with a **Daily Status** recorded, the **Day View** SHALL display the existing entries in a read-only state and SHALL display a message indicating the date can no longer be edited. The Add new event *Action* SHALL NOT be displayed.

### Rationale

The *Calendar* is the *Participant*'s at-a-glance survey of their *Diary* period: every date's visual indicator answers "have I recorded for this day, and if so, what?" without forcing the *Participant* to drill into each date. The seven-state legend (recorded events, confirmed no-events, don't-remember, incomplete-or-missing, not-recorded, locked, today) covers every *Diary*-state distinction the platform tracks; collapsing two states into one indicator would hide either incomplete-record warnings or locked-date evidence that the *Participant* needs to see. The *Day View* bifurcation (no-status-recorded prompt vs. status-recorded list) reflects two distinct *Participant* journeys — first-time entry for a date (Add / No / Don't recall three-*Action* prompt) vs. revisiting an already-recorded date (entry list with Add new event affordance). Lock-state handling on a locked date suppresses every *Action* that would attempt to modify the date, surfacing the lock explicitly rather than letting the *Participant* tap an *Action* and discover the rejection — the explanatory message ("can no longer be edited") is what makes the lock comprehensible. Submitted **Portal-Sent Questionnaires** appearing in the date's entry list grounds the *Questionnaire* as a part of the *Diary* record on the date it landed, rather than as an out-of-band artifact the *Participant* has to navigate separately to find.

> **Follow-up — configurability**: This requirement currently encodes
> the only option implemented in code. Future sponsors may require
> different rules; introduce a configurable seam (e.g. a parameter on
> the CAL-PRD-* parent, or a new platform-side template the CAL- REQ
> Satisfies) when the need arises. Until that seam exists, this REQ is
> normative for the Callisto deployment.

*End* *Calendar and Day View* | **Hash**: 8051d0f5
