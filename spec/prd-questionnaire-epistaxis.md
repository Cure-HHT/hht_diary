# Daily Epistaxis Record Questionnaire

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2026-01-21

> **See**: prd-questionnaire-system.md for parent requirement (REQ-p01065)
> **See**: prd-questionnaire-approval.md for Study Start approval workflow (REQ-p01064)
> **See**: prd-epistaxis-terminology.md for clinical terminology standards (REQ-p00042)

---

## User Journeys

> **See**: [user-journeys/epistaxis-diary-journeys.md](user-journeys/epistaxis-diary-journeys.md)

---

## Overview

This specification defines the Daily Epistaxis Record Questionnaire, the primary data collection instrument for capturing nosebleed events in the HHT Clinical Diary. This questionnaire supports both individual nosebleed event recording and daily summary entries.

---

## Requirements

# REQ-p01066: Daily Epistaxis Record Questionnaire

**Level**: PRD | **Status**: Draft | **Refines**: REQ-p01065-A, REQ-p00042-A

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

*End* *Daily Epistaxis Record Questionnaire* | **Hash**: 29498f8f
---

# REQ-p01069: Daily Epistaxis Record User Interface

**Level**: PRD | **Status**: Draft | **Refines**: REQ-p01066-A

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

*End* *Daily Epistaxis Record User Interface* | **Hash**: 0efa31a6
---

## References

- **Parent Requirement**: prd-questionnaire-system.md (REQ-p01065)
- **Epistaxis Terminology**: prd-epistaxis-terminology.md (REQ-p00042)
- **Approval Workflow**: prd-questionnaire-approval.md (REQ-p01064)
- **Temporal Validation**: prd-diary-app.md (REQ-p00050)
- **Event Sourcing**: prd-database.md (REQ-p00004)
