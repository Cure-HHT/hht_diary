# *Audit Log* Visibility and Presentation

This section defines per-*Role* visibility scope of *Audit Log* records and the *User* interface presentation of the **Audit Log View**, and the content captured in each **Audit Log Entry**.

## DIARY-GUI-audit-log-common: Audit Log View — Common Presentation

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-audit-trail

### Overview

The **Audit Log View** uses a consistent presentation across all roles. This requirement defines the shared display, ordering, content, and empty state behavior. *Role*-specific GUI requirements refine this base by adding *Role*-specific columns, controls, and entry points.


Audit Log
: A chronological record of Actions performed in the System, presented to each user according to their Role.

Audit Log View
: The Sponsor Portal screen that presents the Audit Log to a user according to their Role.

Audit Log Entry
: A single record in the Audit Log, capturing one Action with its actor, target, and timestamp.

### Assertions

**Display**

A. The interface SHALL display the **Audit Log View** as a table containing at minimum the following columns: Timestamp, *Action*, *User*, Details.

B. The interface SHALL display *Audit Log* Entries in reverse chronological order, with the most recent entry first.

**Content**

C. When an **Audit Log Entry** corresponds to an **Action** that included a free text input from the *User* (such as a reason, justification, or note), the interface SHALL include that text in the Details column.

D. The interface SHALL display in the Details column a human-readable summary of the **Action** that includes, where applicable, the previous state of the affected record and the parameter or option selected as part of the **Action**.

**Empty State**

E. When the **Audit Log View** contains no *Audit Log* Entries within the active scope or filter selection, the interface SHALL display a message indicating no results were found.

**Action Display**

F. The interface SHALL display the **Action** name in the *Action* column.

G. When an **Action** has parameters that distinguish meaningful variants (such as **Questionnaire Type**), the interface SHALL append the parameter to the **Action** name in the *Action* column for human readability.

**Detail View**

H. The interface SHALL provide a **More details** button on each **Audit Log Entry** that, when selected, displays the full **Audit Log Entry** record as raw text.

### Rationale

A consistent *Audit Log* presentation across roles reduces training overhead, allows reviewers comparing entries across roles to read them with the same mental model, and concentrates accessibility, formatting, and column-ordering decisions in one place. Reverse chronological ordering surfaces the most recent activity first, matching the typical investigative workflow of "what just happened?". The Details column carries the free-text reason that originated with the *Action* so reviewers do not have to drill into the raw record to understand intent. The raw-text **More details** affordance preserves the full record for inspectors who need every field, while keeping the table dense enough to scan quickly.

*End* *Audit Log View — Common Presentation* | **Hash**: 8187a8a1

## DIARY-GUI-audit-log-study-coordinator: Study Coordinator Audit Log View

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-GUI-audit-log-common

### Overview

The **Study Coordinator** **Audit Log View** presents the **Study Coordinator**'s own Actions. **Participant**-related Actions are displayed alongside a **Participant ID** column.

### Assertions

**Display**

A. The interface SHALL display the **Participant ID** column in addition to the columns defined in `DIARY-GUI-audit-log-common`.

**Controls**

B. The interface SHALL provide a **Participant ID** search input that filters the displayed *Audit Log* Entries by **Participant ID** in real time.

### Rationale

A *Study Coordinator*'s investigative workflow centers on individual participants — confirming what was done for a specific *Participant* during a specific visit, or assembling documentation in response to a monitoring request. Surfacing **Participant ID** as a first-class column and providing a dedicated search input collapses the most common filter operation to a single keystroke. Limiting the view to the Coordinator's own actions reinforces the separation-of-duties model encoded in the per-*Role* scope: Coordinators are accountable for their own *Audit Trail* and do not need (and should not have) visibility into peer actions.

*End* *Study Coordinator Audit Log View* | **Hash**: aeb42c07

## DIARY-GUI-audit-log-cra: CRA Audit Log View

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-GUI-audit-log-common

### Overview

The **CRA** **Audit Log View** is accessed by selecting a **Site** from the **CRA**'s list of *Assigned Sites* and presents **Study Coordinator** Actions for the selected **Site**. A **Study Coordinator** filter and a **Participant ID** search input enable focused review.

### Assertions

**Display**

A. The interface SHALL display the **Participant ID** and **Site** columns in addition to the columns defined in `DIARY-GUI-audit-log-common`.

B. The interface SHALL display the name of the selected **Site** in the **Audit Log View** header.

**Controls**

C. The interface SHALL provide a **Study Coordinator** selector that filters the displayed *Audit Log* Entries by the selected **Study Coordinator**.

D. The interface SHALL provide a default selection in the **Study Coordinator** selector that displays *Audit Log* Entries for all Study Coordinators at the selected **Site**.

E. The interface SHALL provide a **Participant ID** search input that filters the displayed *Audit Log* Entries by **Participant ID** in real time.

### Rationale

CRAs perform *Site* monitoring — verifying that *Study Coordinator* activity at a specific *Site* is compliant and consistent with protocol. The single-*Site* scope makes the unit of monitoring explicit (a CRA reviews one *Site* at a time, not their entire assignment portfolio in a single view), the *Site* name in the header keeps the active scope visible, and the Coordinator selector with an "all Coordinators" default supports both audit-wide review and Coordinator-specific drill-down without forcing the CRA to apply filters manually. The *Participant* ID search supports the same per-*Participant* investigation pattern the *Study Coordinator* view supports, but scoped to the *Site* under review.

*End* *CRA Audit Log View* | **Hash**: a5a86d21

## DIARY-GUI-audit-log-administrator: Administrator Audit Log View

**Level**: GUI | **Status**: Draft | **Implements**: -
**Refines**: DIARY-GUI-audit-log-common

### Overview

The *Administrator* *Audit Log View* is presented as a dedicated tab inside the *Administrator* dashboard, alongside the *User* Account management tab where *Administrator* actions originate.

### Assertions

A. The interface SHALL present the **Administrator** **Audit Log View** on a dedicated tab within the **Administrator** dashboard, alongside the **User Account** management tab.

### Rationale

*Administrator* actions are scoped to *User* Account management; placing the *Audit Log View* on the same dashboard as the *User* Account management surface keeps the *Administrator*'s investigative loop tight — review an account, switch to the audit tab, inspect the history of changes to that account, switch back. A separate top-level *Audit Log* surface would force navigation away from the *Administrator*'s working context for what is fundamentally an inline review activity.

*End* *Administrator Audit Log View* | **Hash**: 1f44ba79
