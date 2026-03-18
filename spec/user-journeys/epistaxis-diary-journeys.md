# Epistaxis Diary User Journeys

> **Source**: prd-questionnaire-epistaxis.md

---

# JNY-Epistaxis-Diary-01: Recording a Nosebleed Event

**Actor**: James (Patient)
**Goal**: Record a nosebleed event that just occurred
**Context**: James is enrolled in an HHT clinical trial and uses the Diary app daily. He just had a nosebleed and wants to record it while the details are fresh.

Validates: REQ-p01066, REQ-p01069

## Steps

1. James opens the Diary app
2. James taps to add a new nosebleed record
3. James selects the start time using the time picker (defaults to current time)
4. James observes that his nosebleed has stopped and enters the end time
5. James selects the intensity level that best matches his experience from the visual scale
6. James sees the calculated duration displayed
7. James saves the record
8. The app confirms the record is saved and shows sync status

## Expected Outcome

James successfully records his nosebleed with accurate timing and intensity. The record is saved and syncs to the trial sponsor.

*End* *Recording a Nosebleed Event*

---

# JNY-Epistaxis-Diary-02: Recording a Day Without Nosebleeds

**Actor**: James (Patient)
**Goal**: Record that he had no nosebleeds today
**Context**: James has had a good day with no nosebleed episodes. He wants to record this in his diary before going to bed.

Validates: REQ-p01066, REQ-p01069

## Steps

1. James opens the Diary app
2. James navigates to today's date
3. James selects the "No nosebleeds" option
4. The app confirms the daily summary is recorded
5. The record syncs to the trial sponsor

## Expected Outcome

James successfully records a "No nosebleeds" entry for the day, which is captured as part of his trial data.

*End* *Recording a Day Without Nosebleeds*

---

# JNY-Epistaxis-Diary-03: Recording When Memory Is Uncertain

**Actor**: Sarah (Patient)
**Goal**: Record her nosebleed history when she cannot clearly recall the day's events
**Context**: Sarah is completing her diary at the end of a busy day and cannot remember if she had any minor nosebleeds.

Validates: REQ-p01066, REQ-p01069

## Steps

1. Sarah opens the Diary app
2. Sarah navigates to today's date
3. Sarah realizes she cannot accurately recall if she had nosebleeds
4. Sarah selects the "Don't remember" option
5. The app confirms the daily summary is recorded

## Expected Outcome

Sarah honestly records her uncertainty rather than guessing, maintaining data integrity for the trial.

*End* *Recording When Memory Is Uncertain*

---

# JNY-Epistaxis-Diary-04: Editing a Previous Record

**Actor**: James (Patient)
**Goal**: Correct a nosebleed record he entered earlier with the wrong end time
**Context**: James recorded a nosebleed earlier but accidentally entered the wrong end time. He realizes the mistake and wants to correct it.

Validates: REQ-p01066, REQ-p01069

## Steps

1. James opens the Diary app
2. James navigates to the date containing the record to edit
3. James selects the nosebleed record he wants to modify
4. James taps to edit the record
5. James corrects the end time
6. The app shows the updated calculated duration
7. James saves the changes
8. The app confirms the update is saved

## Expected Outcome

James successfully corrects his nosebleed record. The edit is captured in the event history for audit purposes.

*End* *Editing a Previous Record*
