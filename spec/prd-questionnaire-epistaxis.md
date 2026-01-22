# Daily Epistaxis Record Questionnaire

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2026-01-21

> **See**: prd-questionnaire-system.md for parent requirement (REQ-p01065)
> **See**: prd-questionnaire-approval.md for Study Start approval workflow (REQ-p01064)
> **See**: prd-epistaxis-terminology.md for clinical terminology standards (REQ-p00042)

---

## User Journeys

# JNY-Epistaxis-Diary-01: Recording a Nosebleed Event

**Actor**: James (Patient)
**Goal**: Record a nosebleed event that just occurred
**Context**: James is enrolled in an HHT clinical trial and uses the Diary app daily. He just had a nosebleed and wants to record it while the details are fresh.

## Steps

1. James opens the HHT Diary app
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

## Steps

1. James opens the HHT Diary app
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

## Steps

1. Sarah opens the HHT Diary app
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

## Steps

1. James opens the HHT Diary app
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

---

## Overview

This specification defines the Daily Epistaxis Record Questionnaire, the primary data collection instrument for capturing nosebleed events in the HHT Clinical Diary. This questionnaire supports both individual nosebleed event recording and daily summary entries.

---

## Requirements

# REQ-p01066: Daily Epistaxis Record Questionnaire

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p01065, REQ-p00042

Addresses: JNY-Epistaxis-Diary-01, JNY-Epistaxis-Diary-02, JNY-Epistaxis-Diary-03, JNY-Epistaxis-Diary-04

## Rationale

Daily epistaxis recording is the core data collection activity for HHT clinical trials. The questionnaire must capture event timing, duration, and severity while supporting patients who had no nosebleeds or cannot recall.
This questionnaire is derived from: 
```Clark et al. Nosebleeds in hereditary hemorrhagic telangiectasia: Development of a patient-completed daily eDiary. Laryngoscope Investig Otolaryngol. 2018 Nov 14;3(6):439-445. doi: 10.1002/lio2.211. PMID: 30599027; PMCID: PMC6302722
```
and includes modifications based on FDA feedback from the Pazapanib trial and pratical experience from trial use.

## Assertions

A. The system SHALL capture nosebleed start time as a required field for each nosebleed event.

B. The system SHALL capture nosebleed end time as an optional field.

C. The system SHALL capture nosebleed intensity using a 6-level scale: Spotting, Dripping, Dripping quickly, Steady stream, Pouring, Gushing.

D. The system SHALL NOT allow patients to add free-text notes to nosebleed records.

E. The system SHALL allow patients to record "No nosebleeds" as a daily summary entry.

F. The system SHALL allow patients to record "Don't remember" as a daily summary entry.

G. The system SHALL calculate duration in minutes when both start and end times are provided.

H. The system SHALL validate that end time is after start time when both are provided.

I. For overlap detection purposes, start time SHALL be considered inclusive and end time SHALL be considered exclusive (closed-open interval).

J. The system SHALL store each nosebleed record as aggregate of immutable events per the event sourcing model.

K. The system SHALL prevent entry of nosebleed records for future dates or times.

L. The system SHALL store all timestamps as the patient's wall-clock time, with timezone offset indicating the patient's location at entry time, to preserve the patient's experience of the event.

M. This Questionnaire SHALL support Study Start gating.

*End* *Daily Epistaxis Record Questionnaire* | **Hash**: 10695516
---

# REQ-p01069: Daily Epistaxis Record User Interface

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p01066

Addresses: JNY-Epistaxis-Diary-01, JNY-Epistaxis-Diary-02, JNY-Epistaxis-Diary-03, JNY-Epistaxis-Diary-04

## Rationale

The Daily Epistaxis Record is the most frequently used data entry interface in the Diary app. The UI must minimize friction for daily recording while maintaining clinical data quality. Patients may need to record events retrospectively, edit incomplete records, and understand sync status when enrolled in a trial.

## Assertions

A. The system SHALL provide an intuitive time picker for selecting nosebleed start and end times.

B. The system SHALL display intensity levels with visual indicators to aid patient selection.

C. The system SHALL provide quick-access options for "No nosebleeds" and "Don't remember" daily summary entries.

D. The system SHALL display the calculated duration in real-time as end time is entered.

E. The system SHALL support editing of records regardless of completion state.

F. The system SHALL support editing of records for any date within the allowed entry window.

G. The system SHALL display clear status indicators for sync state when the patient is enrolled in a trial.

*End* *Daily Epistaxis Record User Interface* | **Hash**: 3cd9c967
---

## References

- **Parent Requirement**: prd-questionnaire-system.md (REQ-p01065)
- **Epistaxis Terminology**: prd-epistaxis-terminology.md (REQ-p00042)
- **Approval Workflow**: prd-questionnaire-approval.md (REQ-p01064)
- **Temporal Validation**: prd-diary-app.md (REQ-p00050)
- **Event Sourcing**: prd-database.md (REQ-p00004)
