# Epistaxis Diary — Participant User Journeys

> **Role**: Participant (Diary mobile app)
> **Source**: spec/prd-epistaxis.md
> **Scope**: Diary Mobile Application. Each journey is one happy-path interaction lifecycle beginning with the Participant signed in and on the Diary home screen.

---

# JNY-EDIARY-01: Recording a Nosebleed Event

**Actor**: James, a Participant
**Goal**: Record a nosebleed event that just occurred
**Context**: James is enrolled in an HHT clinical trial and uses the Diary app daily. He just had a nosebleed and wants to record it while the details are fresh.

Validates: DIARY-PRD-epistaxis-capture-standard-A+C+D+E, DIARY-GUI-epistaxis-record-E+F+G+I+J+K

## Steps

1. James opens the Diary app and taps to add a new nosebleed record.
2. James sets the start time in the Time Picker, which defaults to the current time, and confirms it.
3. James selects the Max Intensity that best matches his experience from the six-level scale; the flow advances automatically.
4. James sets the end time once his nosebleed has stopped.
5. The app displays the calculated duration derived from the start and end times.
6. James saves the record and the app confirms it is saved and shows its sync status.

## Expected Outcome

James records his nosebleed with accurate timing and intensity. The Epistaxis Event is saved with a calculated duration and syncs to the sponsor.

*End* *Recording a Nosebleed Event*

---

# JNY-EDIARY-02: Recording a Day Without Nosebleeds

**Actor**: James, a Participant
**Goal**: Record that he had no nosebleeds today
**Context**: James has had a good day with no nosebleed episodes and wants to record it before bed.

Validates: DIARY-PRD-epistaxis-capture-standard-A+B, DIARY-PRD-day-disposition-A+B

## Steps

1. James opens the Diary app and navigates to today's date.
2. James selects the "No Nosebleed" Daily Status.
3. The app records the day's disposition as a No-Nosebleed marker and confirms it.
4. The record syncs to the sponsor.

## Expected Outcome

The day's summary disposition is a No-Nosebleed marker, captured as part of James's trial data. The three Daily Status values are mutually exclusive, so this excludes any other marker for the day.

*End* *Recording a Day Without Nosebleeds*

---

# JNY-EDIARY-03: Recording When Memory Is Uncertain

**Actor**: Sarah, a Participant
**Goal**: Record her nosebleed history when she cannot clearly recall the day's events
**Context**: Sarah is completing her diary at the end of a busy day and cannot remember if she had any minor nosebleeds.

Validates: DIARY-PRD-epistaxis-capture-standard-A+B, DIARY-PRD-day-disposition-A+B

## Steps

1. Sarah opens the Diary app and navigates to today's date.
2. Sarah realizes she cannot accurately recall whether she had nosebleeds.
3. Sarah selects the "Don't Remember" Daily Status.
4. The app records the day's disposition as a Don't-Remember marker and confirms it.

## Expected Outcome

Sarah records her uncertainty rather than guessing. The day carries a Don't-Remember marker, distinguishing missing data from a confirmed absence of events and preserving data integrity for the trial.

*End* *Recording When Memory Is Uncertain*

---

# JNY-EDIARY-04: Editing a Previous Record

**Actor**: James, a Participant
**Goal**: Correct a nosebleed record he entered earlier with the wrong end time
**Context**: James recorded a nosebleed earlier but entered the wrong end time. He wants to correct it.

Validates: DIARY-PRD-epistaxis-capture-standard-D, DIARY-PRD-day-disposition-D

**Spec gap**: No dedicated GUI assertion specifies the post-save edit flow from event history; the recording-flow GUI (DIARY-GUI-epistaxis-record) covers creation, and DIARY-PRD-day-disposition-D establishes only that a recorded event is changed by editing or deleting. This journey anchors to those PRD behaviors. TODO(port): post-save Epistaxis Event edit-from-event-history flow (participant edit UI + its audit capture).

## Steps

1. James opens the Diary app and navigates to the date containing the record.
2. James selects the nosebleed record and opens it to edit.
3. James corrects the end time.
4. The app shows the updated calculated duration.
5. James saves the changes and the app confirms the update.

## Expected Outcome

James corrects his nosebleed record; the recalculated duration reflects the new end time and the edit is captured in the event history for audit purposes.

*End* *Editing a Previous Record*
