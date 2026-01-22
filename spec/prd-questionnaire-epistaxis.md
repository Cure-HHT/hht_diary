# Daily Epistaxis Record Questionnaire

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2026-01-21

> **See**: prd-questionnaire-system.md for parent requirement (REQ-p01065)
> **See**: prd-questionnaire-approval.md for Study Start approval workflow (REQ-p01064)
> **See**: prd-epistaxis-terminology.md for clinical terminology standards (REQ-p00042)

---

## Overview

This specification defines the Daily Epistaxis Record Questionnaire, the primary data collection instrument for capturing nosebleed events in the HHT Clinical Diary. This questionnaire supports both individual nosebleed event recording and daily summary entries.

Unlike scored questionnaires (NOSE HHT, Quality of Life), daily epistaxis records do not require per-entry investigator approval after the initial Study Start questionnaire is approved. Patients self-report daily, and data syncs automatically.

---

## Study Start Workflow

The epistaxis questionnaire serves as the **Study Start** gating mechanism:

1. **Sponsor pushes** initial Study Start epistaxis questionnaire to patient
2. **Patient completes** the questionnaire (may record initial nosebleed events)
3. **Investigator reviews** and approves via REQ-p01064 workflow
4. **Study officially begins** upon approval
5. **Ongoing recording** - patient records daily without further approval

### Pre-Approval Behavior

- Epistaxis records stored locally on device only
- Data does NOT sync to Sponsor Portal or study database
- Patient can use app normally but data remains isolated

### Post-Approval Behavior

- Daily records self-reported without per-entry approval
- Data syncs automatically to Sponsor Portal
- Investigator can view but not approve individual daily entries

---

## Data Fields

### Nosebleed Event Record

| Field | Type | Required | Description |
| ----- | ---- | -------- | ----------- |
| id | UUID | Yes | Unique record identifier |
| startTime | DateTime | Yes | When the nosebleed started |
| endTime | DateTime | No | When the nosebleed stopped |
| intensity | Enum | No | Severity level (6 options) |
| isNoNosebleedsEvent | Boolean | No | "No nosebleeds" daily summary |
| isUnknownEvent | Boolean | No | "Don't remember" daily summary |

### Intensity Levels

The system uses a 6-level intensity scale per REQ-p00042:

| Level | Display Name | Description |
| ----- | ------------ | ----------- |
| 1 | Spotting | Minimal blood, small spots |
| 2 | Dripping | Slow, occasional drops |
| 3 | Dripping quickly | Rapid successive drops |
| 4 | Steady stream | Continuous flow |
| 5 | Pouring | Heavy continuous flow |
| 6 | Gushing | Severe, uncontrolled bleeding |

### Special Event Types

Patients may record daily summary entries instead of individual events:

| Event Type | Flag | Description |
| ---------- | ---- | ----------- |
| No nosebleeds | isNoNosebleedsEvent | Patient had no nosebleeds that day |
| Don't remember | isUnknownEvent | Patient cannot recall nosebleed status |

---

## Duration Calculation

Duration is calculated from startTime and endTime:

- Duration = endTime - startTime (in minutes)
- Duration is null if endTime is not recorded
- Duration is null if endTime is before startTime (validation error)

---

## Temporal Validation

- endTime must be after startTime
- Records cannot be entered for future dates or times
- For overlap detection: start time is inclusive, end time is exclusive (closed-open interval)

---

## Requirements

# REQ-p01066: Daily Epistaxis Record Questionnaire

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p01065, REQ-p00042

## Rationale

Daily epistaxis recording is the core data collection activity for HHT clinical trials. The questionnaire must capture event timing, duration, and severity while supporting patients who had no nosebleeds or cannot recall. The 6-level intensity scale provides clinically meaningful gradation. Separating Study Start approval from ongoing daily recording reduces investigator burden while maintaining enrollment gate control.

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

J. The system SHALL store each nosebleed record as an immutable event per the event sourcing model.

K. The system SHALL prevent entry of nosebleed records for future dates or times.

L. The system SHALL store all timestamps as the patient's wall-clock time, with timezone offset indicating the patient's location at entry time, to preserve the patient's experience of the event.

### Sponsor-Configurable Study Start Gating (Optional)

M. When enabled, the system SHALL use a designated questionnaire as the Study Start gating mechanism for patient enrollment.

N. When Study Start gating is enabled, the system SHALL NOT sync patient data to the Sponsor Portal until the Study Start questionnaire has been approved.

O. When Study Start gating is enabled, the system SHALL sync daily records automatically after Study Start approval without requiring per-entry investigator approval.

*End* *Daily Epistaxis Record Questionnaire* | **Hash**: 570d86f2
---

## User Interface Requirements

The UI implementation SHALL:

- Provide intuitive time picker for start and end times
- Display intensity levels with visual indicators
- Allow quick selection of "No nosebleeds" and "Don't remember" options
- Show duration calculation in real-time as end time is entered
- Support editing of incomplete records
- Display clear status indicators for sync state

---

## References

- **Parent Requirement**: prd-questionnaire-system.md (REQ-p01065)
- **Epistaxis Terminology**: prd-epistaxis-terminology.md (REQ-p00042)
- **Approval Workflow**: prd-questionnaire-approval.md (REQ-p01064)
- **Temporal Validation**: prd-diary-app.md (REQ-p00050)
- **Event Sourcing**: prd-database.md (REQ-p00004)
