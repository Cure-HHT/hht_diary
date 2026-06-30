# Participant Management — Study Coordinator User Journeys

> **Role**: Study Coordinator (Study-Coordinator-only capabilities)
> **Source**: spec/prd-participant.md, spec/prd-rbac.md, spec/prd-questionnaire-management.md
> **Scope**: Sponsor Portal (web). Each journey is one happy-path interaction lifecycle that begins with the Study Coordinator already signed in and on the Participant Dashboard (the Study Coordinator's default landing view). The shared authentication journeys (log in, accept invite, reset password, switch role, log out) are covered in authentication-journeys.md and are not repeated.
>
> **Spec note**: For most participant lifecycle actions (start trial, disconnect, reconnect, mark not-participating, reactivate) the platform defines the PRD behavior, but the portal action UI itself is deployment/sponsor-configured (an action-availability table referenced by DIARY-GUI-participant-dashboard rather than a platform DIARY-GUI requirement). Those journeys validate the PRD behavior and flag the missing platform GUI requirement inline.

---

# JNY-PART-01: Link a New Participant

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Issue a mobile linking code so a newly enrolled participant can connect their app
**Context**: A participant has been enrolled and appears on the Participant Dashboard in "Not Connected" status.

Validates: DIARY-PRD-participant-link-new-A+B, DIARY-PRD-linking-code-lifecycle-A+D, DIARY-GUI-link-participant-flow-A+B+C

## Steps

1. Dr. Mitchell locates the "Not Connected" participant on the Participant Dashboard and triggers the "Link Participant" action.
2. A confirmation dialog appears showing the Participant ID and the linking code's expiry duration.
3. Dr. Mitchell confirms.
4. The system generates an unpredictable, single-use Mobile Linking Code and presents an acknowledgement dialog showing the code, a Copy action, and the remaining time before it expires.
5. Dr. Mitchell copies the code and provides it to the participant.
6. Dr. Mitchell dismisses the dialog; the participant's status badge updates to "Pending".

## Expected Outcome

A Mobile Linking Code is issued and the participant is in "Pending" status. The participant enters the code in their mobile app to establish the link; the code is single-use and expires after the configured duration.

*End* *Link a New Participant*

---

# JNY-PART-02: Show or Share a Participant's Linking Code

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Re-display a participant's linking code to help them connect, or save it to share
**Context**: A participant in "Pending" status needs the code again. Dr. Mitchell is on the Participant Dashboard.

Validates: DIARY-PRD-linking-code-lifecycle-H, DIARY-GUI-show-linking-code-A+B+C

## Steps

1. Dr. Mitchell selects the participant and triggers the "Show Linking Code" action.
2. For a "Pending" participant, the system displays the active Mobile Linking Code with a Copy action and a "Save as PDF" action.
3. Dr. Mitchell clicks "Save as PDF"; the system generates a PDF containing the code and the participant instructions.
4. For a participant in any other status, the same action instead displays the historical Participant Linking Code for reference.

## Expected Outcome

The participant's current Mobile Linking Code (or, for non-Pending participants, the retained historical code) is displayed and can be copied or exported to PDF for sharing.

*End* *Show or Share a Participant's Linking Code*

---

# JNY-PART-03: Start a Participant's Trial

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Activate diary data synchronization for a linked participant
**Context**: A participant has linked their device and is in "Linked - Awaiting Start" status on the Participant Dashboard.

Validates: DIARY-PRD-questionnaire-system-C

**Spec gap**: No platform DIARY-GUI requirement defines the Start Trial portal flow; the action UI is sponsor-configured. This journey validates the PRD behavior (trial start activates diary data synchronization) only.

## Steps

1. Dr. Mitchell selects the "Linked - Awaiting Start" participant and triggers the "Start Trial" action.
2. The system prompts for confirmation and Dr. Mitchell confirms.
3. The system transitions the participant to "Trial Active" and activates diary data synchronization from the mobile app to the portal (and onward to Rave EDC).

## Expected Outcome

The participant is "Trial Active" and their diary data begins synchronizing. The trial-start trigger and its effects follow the sponsor's configuration.

*End* *Start a Participant's Trial*

---

# JNY-PART-04: Disconnect a Participant

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Pause a participant's data synchronization while preserving their history
**Context**: An active participant must be temporarily disconnected (e.g., lost device). Dr. Mitchell is on the Participant Dashboard.

Validates: DIARY-PRD-participant-disconnection-A+B+C+D+E+F

**Spec gap**: No platform DIARY-GUI requirement defines the Disconnect portal flow; the action and reason dialog are sponsor-configured. This journey validates the PRD behavior only.

## Steps

1. Dr. Mitchell selects a participant whose status permits disconnection and triggers the "Disconnect Participant" action.
2. The system requires a reason and presents the reason input in the sponsor-configured format (free text or a predefined list).
3. Dr. Mitchell enters the reason and confirms.
4. The system stops data synchronization, preserves all participant data and history, and keeps sponsor-specific rules applied on the mobile app.

## Expected Outcome

The participant is "Disconnected"; synchronization is paused and all historical data is preserved. The disconnection is attributable with the recorded reason.

*End* *Disconnect a Participant*

---

# JNY-PART-05: Reconnect a Participant

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Restore a disconnected participant's link and recover data buffered while disconnected
**Context**: A previously disconnected participant has a working device again. Dr. Mitchell is on the Participant Dashboard.

Validates: DIARY-PRD-participant-reconnection-A+B+C+D+E+F

**Spec gap**: No platform DIARY-GUI requirement defines the Reconnect portal flow; the action and reason dialog are sponsor-configured. This journey validates the PRD behavior only.

## Steps

1. Dr. Mitchell selects the "Disconnected" participant and triggers the "Reconnect Participant" action.
2. The system requires a reason, captured by default via a free-text reason dialog (sponsor-configurable).
3. Dr. Mitchell enters the reason and confirms.
4. The system generates a new Mobile Linking Code; the participant re-enters it on their device to restore the link.
5. On successful re-linking, data buffered during the disconnected period synchronizes to the portal.

## Expected Outcome

The participant's link is restored via a new linking code, and any data collected while disconnected is recovered. The reconnection is attributable with the recorded reason.

*End* *Reconnect a Participant*

---

# JNY-PART-06: Mark a Participant as Not Participating

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Conclude a participant's involvement, removing trial-specific rules from their app
**Context**: A disconnected participant has completed or withdrawn from the trial. Dr. Mitchell is on the Participant Dashboard.

Validates: DIARY-PRD-participant-mark-not-participating-A+B+C+D

**Spec gap**: No platform DIARY-GUI requirement defines this portal flow; the action and reason dialog are sponsor-configured. This journey validates the PRD behavior only.

## Steps

1. Dr. Mitchell selects a "Disconnected" participant and triggers the "Mark as Not Participating" action.
2. The system requires a reason in the sponsor-configured format (free text or predefined list).
3. Dr. Mitchell enters the reason and confirms.
4. The system transitions the participant to "Not Participating" and removes trial-specific rules from their mobile app.

## Expected Outcome

The participant is "Not Participating" and trial-specific behavior is removed from their app, while their historical data is preserved. The change is attributable with the recorded reason.

*End* *Mark a Participant as Not Participating*

---

# JNY-PART-07: Reactivate a Participant

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Return a "Not Participating" participant to active status
**Context**: A participant was marked "Not Participating" (in error or is re-enrolling). Dr. Mitchell is on the Participant Dashboard.

Validates: DIARY-PRD-participant-reactivate-A+B+C

**Spec gap**: No platform DIARY-GUI requirement defines this portal flow; the action and reason dialog are sponsor-configured. This journey validates the PRD behavior only.

## Steps

1. Dr. Mitchell selects a "Not Participating" participant and triggers the "Reactivate Participant" action.
2. The system requires a free-text reason.
3. Dr. Mitchell enters the reason and confirms.
4. The system re-applies trial-specific rules to the participant's mobile app and routes Dr. Mitchell to the standard reconnection workflow to re-establish the link.

## Expected Outcome

The participant is reactivated with trial-specific rules restored, ready to be reconnected via the standard reconnection workflow. The reactivation is attributable with the recorded reason.

*End* *Reactivate a Participant*

---

# JNY-PART-08: Browse and Search Participants

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Find and review participants and their statuses
**Context**: Dr. Mitchell has just signed in and is on the Participant Dashboard (the default landing view).

Validates: DIARY-GUI-participant-dashboard-A+C+L+M+N

## Steps

1. Dr. Mitchell sees the Participant Dashboard listing participants with their status badges, organized into the dashboard's tabs.
2. Dr. Mitchell searches for a participant; the list filters to matching records.
3. Dr. Mitchell clicks a participant to open the participant actions modal, which shows the available actions for that participant's current status.
4. Dr. Mitchell reviews the participant's information from the modal.

## Expected Outcome

Dr. Mitchell can locate any participant, see their current status, and open the actions available for that participant given their status.

*End* *Browse and Search Participants*
