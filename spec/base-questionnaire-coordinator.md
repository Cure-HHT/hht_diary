# *Questionnaire* Coordinator Workflow (BASE)

Core, study-neutral coordinator workflow for issuing, recalling, and finalizing
*Questionnaires* from the *Sponsor Portal*. These requirements are
authored at the BASE level because they are real, traceable product behavior that
a *Sponsor* may opt to exclude from its own requirements documentation set: a
deployment selects which capabilities (*Cycle* tracking, starting-*Cycle* selection,
lock-after-*Submission*) it uses, but the platform offers the full workflow to any
study. The status names referenced here are the authoritative values defined in
the *Questionnaire Status* section of `spec/prd-status-registry.md`
(Not Sent / Sent / Delivery Failed / Ready to Review / Closed).

## DIARY-BASE-questionnaire-coordinator-workflow: Coordinator Questionnaire Workflow

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-system

### Overview

A *Study Coordinator* administers a *Questionnaire* to a *Participant* by
sending it to the *Participant*'s *Mobile Application*, optionally per protocol
*Cycle*. This requirement governs the per-*Questionnaire* workflow from send,
through *Participant* completion and coordinator review, to *Finalization*. It is
study-neutral: the set of enabled *Questionnaire Types* and whether *Cycle*
tracking applies are deployment configuration, but the workflow itself is the
platform's.

### Assertions

**Sending**

A. The System SHALL enforce a limit of one active **Questionnaire** per **Cycle** per **Questionnaire Type** per *Participant*.

B. When a **Questionnaire** fails to reach the *Participant*'s *Mobile Application*, the System SHALL change its status to **Delivery Failed**.

C. After the first **Cycle** has been finalized for a **Questionnaire Type**, the System SHALL make a **Start Next Cycle** *Action* available in place of **Send Now** for that **Questionnaire Type**.

**Recalling**

D. The System SHALL allow a *Study Coordinator* to call back a **Questionnaire** with **Sent**, **Delivery Failed**, or **Ready to Review** status, tombstoning the active instance.

E. The System SHALL NOT allow a *Study Coordinator* to call back a **Questionnaire** that has been finalized by the *Study Coordinator*.

**Participant Completion**

F. The System SHALL allow the *Participant* to edit their answers at any time before their answers are locked (subject to *DIARY-BASE-questionnaire-lock-after-submission*). There is no limit on how many times a *Participant* may edit their answers.

G. When a *Participant* submits a **Questionnaire**, the System SHALL change its status to **Ready to Review**.

**Review**

H. The System SHALL allow a *Study Coordinator* to review submitted **Questionnaire** answers before *Finalization*.

**Finalizing**

I. The System SHALL allow a *Study Coordinator* to finalize a **Questionnaire** with **Ready to Review** or **Delivery Failed** status.

J. Upon *Finalization*, the System SHALL lock the answers, calculate the **Questionnaire** score, and transmit the answers to the configured data destination.

K. When the *Finalization* operation fails, the System SHALL automatically retry the operation in the background, and the **Questionnaire** SHALL remain in **Ready to Review** status throughout.

L. While a *Finalization* retry is in progress, the System SHALL inform the *Study Coordinator* that the operation is retrying and no *Action* is required.

M. Upon successful *Finalization* with a non-terminal **Cycle** value, the System SHALL change the **Questionnaire** status to **Not Sent**.

### Rationale

The send / edit / submit / review / finalize sequence mirrors the
workflow: the *Participant* fills out the instrument (with unlimited edits before
their answers are locked), the *Study Coordinator* reviews the submitted answers,
and the Coordinator finalizes only after review. *Finalization* is the locking
event — it transmits to the data destination, calculates the score, and
freezes the answers, after which call-back is no longer available. The
retry-on-failure pattern with a coordinator-facing message is operationally
important because data connectivity can be transient, and a failure
during *Finalization* should not block the workflow. Returning a card to
**Not Sent** on successful non-terminal *Finalization* signals that the next
**Cycle** can be initiated. Recalling a sent **Questionnaire** tombstones the
active instance so the *Participant*'s task is withdrawn and the **Cycle** can be
re-sent.

*End* *Coordinator Questionnaire Workflow* | **Hash**: 584e86b9

## DIARY-BASE-questionnaire-manage-modal: Manage Questionnaires Modal

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-questionnaire-coordinator-workflow
**Satisfies**: DIARY-PRD-reason-field-constraints

The **Questionnaire Card** and **Select Starting Cycle Dialog** terms used
below are defined by the deploying study's requirement set (each *Sponsor*
overlay defines them once for the federated glossary; defining them here
as well would duplicate the definitions).

### Assertions

**Modal**

A. The interface SHALL display the **Manage Questionnaires** surface with the *Participant* identifier in its header.

B. The interface SHALL display one **Questionnaire Card** per enabled **Questionnaire Type**.

C. The interface SHALL present a close *Action* that dismisses the surface without making any changes.

**Questionnaire Card — Display and Actions**

D. Each **Questionnaire Card** SHALL display the **Questionnaire Type** name and the current **Questionnaire Status**. Date and time information SHALL be paired inline with the **Cycle** it describes (e.g., "*Cycle* 1 . Apr 24, 2026, 11:34 AM"), not as a standalone field.

E. The interface SHALL present *Cycle* information, status placement, and available actions on each **Questionnaire Card** according to the following table:

| *Questionnaire* Status | *Cycle* Fields Displayed | Status Placement | Actions Available |
| ----- | ----- | ----- | ----- |
| **Not Sent** — never sent | None | Below **Questionnaire Type** name | **Send Now** |
| **Not Sent** — after finalize or call back | **Finalized Cycle** (with date), **Next Cycle** | Inline with **Finalized Cycle** row | **Start Next Cycle** |
| **Sent** | **Current Cycle** | Inline with **Current Cycle** row | **Call Back** |
| **Delivery Failed** | **Current Cycle** | Inline with **Current Cycle** row, with information icon | **Finalize**, **Call Back** |
| **Ready to Review** | **Current Cycle** (with completion date) | Inline with **Current Cycle** row | **Finalize**, **Call Back** |
| **Closed** | **Finalized Cycle** (with date) | Inline with **Finalized Cycle** row, as combined badge ("Closed . End of Treatment" or "Closed . End of Study") | None |

**Call Back Interaction**

F. When a *Study Coordinator* selects the **Call Back** *Action*, the interface SHALL display a Reason Dialog (free text) before proceeding.

G. When the *Study Coordinator* confirms the **Call Back** *Action* with a reason, the interface SHALL update the **Questionnaire Card** status to **Not Sent**.

H. When the *Study Coordinator* cancels the Reason Dialog, the **Questionnaire** SHALL remain unchanged.

**Send Now**

I. The **Send Now** *Action* is displayed only when the first **Questionnaire** of a **Questionnaire Type** will be sent. When a *Study Coordinator* selects **Send Now** and starting-*Cycle* selection is required, the interface SHALL display the **Select Starting Cycle Dialog**.

J. The **Select Starting Cycle Dialog** SHALL present a **Confirm and Send** button and a Cancel *Action*.

K. When the *Study Coordinator* confirms the **Select Starting Cycle Dialog**, the interface SHALL update the **Questionnaire Card** status to **Sent**.

L. If the *Study Coordinator* cancels the **Select Starting Cycle Dialog**, the **Questionnaire Card** SHALL remain unchanged.

**Start Next Cycle**

M. When a *Study Coordinator* selects **Start Next Cycle**, the interface SHALL update the **Questionnaire Card** status to **Sent** without displaying the **Select Starting Cycle Dialog**.

**Delivery Failed Troubleshooting**

N. When the **Questionnaire Status** is **Delivery Failed**, the interface SHALL display an information icon adjacent to the status. When the *Study Coordinator* selects this icon, the interface SHALL display a **Troubleshooting Popover** with guidance on resolving delivery issues.

O. The **Troubleshooting Popover** SHALL dismiss when the *Study Coordinator* clicks outside its bounds or selects a close *Action* within it.

### Rationale

The **Manage Questionnaires** surface is the per-*Participant* control surface for
the *Questionnaire* workflow, and its card-per-type layout matches the
*Study Coordinator*'s mental model ("what is the state of each enabled
*Questionnaire Type* for this *Participant*?") rather than a flat list of every
*Questionnaire* ever sent. The status-driven *Action* table collapses the workflow's
branch logic into a visible matrix: each status shows exactly the actions it
permits and no others, and the status sits next to the **Cycle** it describes so
the **Cycle** context is never ambiguous. The **Select Starting Cycle Dialog**
appears only on first send because that is the only moment the **Starting Cycle**
is a Coordinator choice — every subsequent **Cycle** is auto-incremented per
*DIARY-BASE-questionnaire-cycle-tracking*. The information-icon Troubleshooting
Popover handles the **Delivery Failed** state inline without a separate screen.

*End* *Manage Questionnaires Modal* | **Hash**: 27cf8328

## DIARY-BASE-questionnaire-finalization: Questionnaire Finalization Workflow

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-questionnaire-coordinator-workflow

The **Finalization Dialog** term used below is defined by the deploying
study's requirement set.

Terminal Cycle Warning Dialog
: The additional confirmation dialog displayed when a **Terminal Cycle** value is selected for finalization, warning that the **Questionnaire Type** will be permanently closed for the *Participant*.

### Assertions

**Finalization Dialog**

A. When a *Study Coordinator* selects **Finalize**, the interface SHALL display the **Finalization Dialog** containing a **Cycle** dropdown.

B. The **Cycle** dropdown SHALL present the following selectable options: the **Current Cycle N Day 1** value, **End of Treatment**, and **End of Study**.

C. The **Finalization Dialog** SHALL present a **Finalize Questionnaire** button and a Cancel *Action*.

**Finalization Outcomes**

D. When the *Study Coordinator* finalizes the **Questionnaire** with a **Cycle N Day 1** value selected, the interface SHALL update the **Questionnaire Card** status to **Not Sent** and display the **Finalized Cycle** (paired with the *Finalization* date and time) and the **Next Cycle** on the card.

E. When the *Study Coordinator* finalizes the **Questionnaire** with a **Terminal Cycle** value (**End of Treatment** or **End of Study**) selected, the interface SHALL display the **Terminal Cycle Warning Dialog**, and upon confirmation SHALL update the **Questionnaire Card** status to **Closed** and display the **Terminal Cycle** value alongside the **Closed** status as a combined badge.

F. When the *Study Coordinator* cancels the **Finalization Dialog**, the **Questionnaire** SHALL remain unchanged.

G. When the *Study Coordinator* cancels the **Terminal Cycle Warning Dialog**, the **Questionnaire** SHALL remain unchanged and the *Study Coordinator* SHALL be returned to the **Finalization Dialog**.

### Rationale

*Finalization* is the *Action* that locks a *Questionnaire*'s answers and commits
its score to the data destination, and the **Finalization Dialog**
captures the two pieces of information that must be set at lock time: the **Cycle**
value being finalized and the Coordinator's confirmation. Presenting the
**Current Cycle N Day 1** plus the two terminal options covers every legitimate
*Finalization* case — most cycles finalize to their own N Day 1, and the two
terminal cases mark the *Participant*'s endpoint for this **Questionnaire Type**.
The **Terminal Cycle Warning Dialog** exists because terminal *Finalization* is
irreversible — no further **Questionnaires** of this type can be sent — and
warrants a confirmation step distinct from the standard *Finalization*
confirmation. Cancelling either dialog returns the **Questionnaire** to its prior
state.

*End* *Questionnaire Finalization Workflow* | **Hash**: 1c17145b

## DIARY-BASE-questionnaire-cycle-tracking: Questionnaire Cycle Tracking

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-questionnaire-coordinator-workflow

### Overview

Each *Questionnaire* may be traceable to a specific protocol **Cycle** for
regulatory compliance and data integrity. Automatic *Cycle* incrementing reduces
manual error. Because a protocol typically allows only one *Questionnaire* of each
type per *Cycle*, no two finalized questionnaires of the same type for a given
*Participant* may share the same **Cycle** value. Some participants start a study
on paper, so their first electronic *Questionnaire* may not be **Cycle 1 Day 1**;
a *Study Coordinator* may select the starting *Cycle* when sending the first
*Questionnaire* of each type. Whether *Cycle* tracking and starting-*Cycle* selection
apply is per-study configuration. *Cycle* tracking is independent per
**Questionnaire Type**.


The **Cycle**, **Current Cycle**, **Finalized Cycle**, **Next Cycle**,
**Starting Cycle**, and **Terminal Cycle** terms used below are defined by
the deploying study's requirement set (each *Sponsor* overlay defines them
once for the federated glossary; defining them here as well would
duplicate the definitions).

### Assertions

**Cycle Assignment**

A. When *Cycle* tracking is enabled, the System SHALL assign a **Cycle** value to each **Questionnaire** at the time it is sent.

B. The System SHALL NOT allow two **Questionnaires** of the same **Questionnaire Type** for the same *Participant* to share the same finalized **Cycle** value.

C. When a *Study Coordinator* sends the first **Questionnaire** of a given **Questionnaire Type** and starting-*Cycle* selection is required, the System SHALL require the *Study Coordinator* to select a **Starting Cycle** before the **Questionnaire** is sent.

D. For each subsequent **Questionnaire** of a given **Questionnaire Type**, the System SHALL assign the **Next Cycle** value automatically by incrementing the **Cycle N** value by 1.

E. When a **Questionnaire** is called back before *Finalization*, the System SHALL reassign the same **Cycle** value to the next **Questionnaire** of that **Questionnaire Type** for that *Participant*.

**Terminal Cycles**

F. When a **Questionnaire** is finalized with a **Terminal Cycle** value, the System SHALL change the **Questionnaire** status to **Closed**.

G. The System SHALL NOT allow a **Terminal Cycle** value to be assigned to more than one **Questionnaire** of the same **Questionnaire Type** per *Participant*.

H. When the **Questionnaire** status is **Closed**, the System SHALL NOT permit a new **Questionnaire** of that **Questionnaire Type** to be sent to that *Participant*.

**Configuration**

I. The System SHALL support per-study configuration of whether *Cycle* tracking is enabled for a given deployment.

J. When *Cycle* tracking is enabled, the System SHALL support per-study configuration of whether the *Study Coordinator* is required to select a **Starting Cycle** when sending the first **Questionnaire** of a given **Questionnaire Type**.

K. When starting-*Cycle* selection is disabled, the System SHALL assign **Cycle 1 Day 1** as the **Starting Cycle**.

### Rationale

The **Cycle** value is the protocol coordinate that lets the data
destination and downstream analyses know which treatment *Cycle* a given
**Questionnaire** answer corresponds to. Two **Questionnaires** of the same
**Questionnaire Type** sharing a **Cycle** value would break that coordinate, so
the uniqueness rule is structural. Automatic incrementing removes a category of
manual data-entry error; the **Starting Cycle** Coordinator-selection at
first-send accommodates the paper-then-electronic pattern. Reassigning the same
**Cycle** value after a call-back preserves the protocol coordinate across the
recall/resend round-trip (an "undo and redo", not a "skip and advance"). Terminal
cycles end the **Questionnaire Type** stream for the *Participant*; uniqueness of
terminal cycles prevents two end markers for the same instrument. Encoding *Cycle*
tracking and starting-*Cycle* selection as configuration keeps the platform neutral
across studies that do and do not track cycles.

*End* *Questionnaire Cycle Tracking* | **Hash**: 6dcb965e

## DIARY-BASE-questionnaire-lock-after-submission: Lock-After-Submission and Unlock

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-PRD-questionnaire-portal-sent-rules

### Overview

In an in-clinic workflow the *Participant* completes a *Questionnaire* while with
the *Study Coordinator*, so answers need not be frozen at *Submission*. In a remote
electronic-PRO workflow the *Participant* completes the *Questionnaire* away from
the clinic and the *Study Coordinator* reviews it afterward; the answers must not
change during that review, so the platform locks them at *Submission* and lets the
Coordinator **Unlock** them if the *Participant* needs to revise based on their
communication. Whether answers are locked at *Submission* is per-study
configuration, defaulting to not-locked. This capability is authored at the BASE
level because it is real product behavior a *Sponsor* may opt to exclude.

### Assertions

A. The System SHALL support per-study configuration of whether a *Participant*'s answers are locked upon **Submission**, defaulting to not locked.

B. When lock-after-*Submission* is disabled, the System SHALL allow the *Participant* to edit their answers at any time after **Submission** until *Finalization*.

C. When lock-after-*Submission* is enabled, the System SHALL lock the *Participant*'s answers upon **Submission** so they cannot be edited while the **Questionnaire** is in **Ready to Review**.

D. When lock-after-*Submission* is enabled, the System SHALL allow a *Study Coordinator* to **Unlock** a **Ready to Review** **Questionnaire**, after which the *Participant* may again edit their answers until the next **Submission** or *Finalization*.

E. The System SHALL NOT permit **Unlock** on a finalized **Questionnaire**; *Finalization* is the irreversible lock.

### Rationale

The lock boundary differs by administration model. In-clinic administration
(answers entered with the Coordinator present) does not need a *Submission* lock,
because review is contemporaneous; freezing answers there would only obstruct the
*Participant*. Remote administration needs the *Submission* lock so the answers the
Coordinator reviews are the answers that were submitted, with **Unlock** as the
controlled path back to editing when the review surfaces a correction the
*Participant* should make. Making the lock configurable (default off) lets the
platform serve both models from one workflow: a deployment that only administers
in-clinic leaves it off and keeps the open edit-until-finalize window of
*DIARY-PRD-questionnaire-portal-sent-rules*; a deployment that administers
remotely turns it on and gains the lock/unlock review *Cycle*. *Finalization*
remains the irreversible terminal lock in both models.

*End* *Lock-After-Submission and Unlock* | **Hash**: a4f69437
