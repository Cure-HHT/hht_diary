# HHT Epistaxis Data Capture Terminology

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-11-28
**Status**: Active

> **Scope**: Standard terminology for epistaxis (nosebleed) data capture in HHT clinical studies
>
> **See**: prd-clinical-trials.md for FDA compliance requirements
> **See**: prd-standards.md for CDISC standards compliance
> **See**: dev-CDISC.md for CDISC field mapping implementation

---

## Executive Summary

This document defines the **standard terminology and data capture format** for epistaxis events in HHT (Hereditary Hemorrhagic Telangiectasia) clinical studies. The terminology was developed specifically for HHT patient populations and uses descriptive, patient-friendly language that accurately captures the clinical severity of nosebleed events.

**Key Principles**:
- Patient-friendly descriptive terminology for intensity/severity
- Precise temporal data with timezone awareness
- Sponsor-configurable notes to prevent unblinding and PII exposure
- ALCOA+ compliant data capture

---

## Epistaxis Event Data Model

# REQ-p00042: HHT Epistaxis Data Capture Standard

**Level**: PRD | **Implements**: - | **Status**: Active

The system SHALL capture epistaxis (nosebleed) events using the HHT-specific terminology standard defined in this specification, ensuring consistent data collection across all HHT clinical studies.

### Required Data Fields

#### 1. Nosebleed Date

**Field**: `bleed_date`
**Format**: `YYYY-MM-DD` (ISO 8601)
**Description**: The calendar date on which the nosebleed started, as experienced by the patient in their local timezone.

**Validation Rules**:
- Must not be a future date
- Must match the date component of `start_time` when timezone is applied

#### 2. Bleed Today Indicator

**Field**: `bleed_today`
**Format**: Enumerated value
**Description**: Indicates the patient's nosebleed status for the reporting date.

**Standard Values**:

| Value | Display Text | Description |
| ----- | ------------ | ----------- |
| `had_nosebleed` | Yes, I had a nosebleed | Patient experienced one or more nosebleeds |
| `no_nosebleed` | No nosebleeds today | Patient confirms no nosebleeds occurred |
| `dont_remember` | I don't remember | Patient cannot recall events for this date |

**Behavior**:
- If `had_nosebleed`: Remaining fields (time, intensity, notes) are presented for data entry
- If `no_nosebleed`: Form submission ends; records explicit confirmation of no events
- If `dont_remember`: Form submission ends; records honest uncertainty

**Implicit Status Setting**:
The `had_nosebleed` status MAY be inferred rather than explicitly selected when the patient enters nosebleed event details directly. This supports UX flows where asking "did you have a nosebleed?" is not the most intuitive interaction pattern (e.g., when patient taps "Add nosebleed" or starts entering event data).

**Rationale for "I don't remember"**:
- Enables honest data capture when patient cannot recall
- Prevents arbitrary/fabricated event data for compliance
- Distinguishes between "confirmed no events" and "uncertain recall"
- Supports ALCOA+ principle of accuracy over completeness

**Mutual Exclusivity**: A diary entry can only have ONE of these states. The data model enforces this constraint.

#### 3. Start Time

**Field**: `start_time`
**Format**: ISO 8601 with timezone: `YYYY-MM-DDTHH:MM:SS±HH:MM`
**Display Format**: `HH:MM AM/PM` with timezone indicator
**Description**: The time when the nosebleed began, as experienced by the patient.

**Requirements**:
- Time displayed to user in 12-hour format with AM/PM
- Stored internally in ISO 8601 with explicit timezone offset
- Timezone reflects the patient's location at event start

#### 4. End Time

**Field**: `end_time`
**Format**: ISO 8601 with timezone: `YYYY-MM-DDTHH:MM:SS±HH:MM`
**Display Format**: `HH:MM AM/PM` with timezone indicator
**Description**: The time when the nosebleed stopped, as experienced by the patient.

**Requirements**:
- Time displayed to user in 12-hour format with AM/PM
- Stored internally in ISO 8601 with explicit timezone offset
- Timezone reflects the patient's location at event end
- Must be after `start_time` (accounting for timezone differences)

#### 5. Intensity (Speed of Flow)

**Field**: `intensity`
**Format**: Enumerated string value
**Description**: Patient-reported intensity of blood flow during the nosebleed.

**Standard Values** (in order of increasing severity):

| Value | Display Text | Clinical Description |
| ----- | ------------ | -------------------- |
| `spotting` | Spotting | Minimal blood, occasional drops |
| `dripping_slowly` | Dripping slowly | Slow, intermittent drips |
| `dripping_quickly` | Dripping quickly | Frequent, rapid drips |
| `steady_stream` | Steady stream | Continuous flow without gushing |
| `pouring` | Pouring | Heavy continuous flow |
| `gushing` | Gushing | Severe, uncontrolled flow |

**UI Presentation**:
- Display with accompanying graphic/visual aid
- Graphics help patients accurately self-assess intensity
- Order from least to most severe (top to bottom or left to right)

#### 6. Notes

**Field**: `notes`
**Format**: Text (selected from predefined list)
**Description**: Additional contextual information about the nosebleed event.

**Requirements**:
- Text options are sponsor-configurable per study protocol
- Free text entry MAY be prohibited to prevent:
  - Inadvertent unblinding of study treatment
  - Exposure of Protected Health Information (PHI)
  - Exposure of Personally Identifiable Information (PII)
- When free text is prohibited, user selects from predefined options only
- Predefined options are maintained in sponsor configuration

### Timezone Handling

**Requirement**: The system SHALL correctly handle timezone changes during events.

**Scenario**: Patient starts nosebleed in one timezone and ends in another (e.g., during travel).

**Solution**:
1. Start time and end time each store their own timezone offset
2. Duration is calculated as a derived value: `end_time - start_time`
3. User can verify correct timezone by checking calculated duration
4. If duration appears incorrect (off by whole hours), user can adjust:
   - The time value, OR
   - The timezone selection
5. System recalculates duration after any adjustment

**Example**:
```
Start: 2025-03-15T14:30:00-05:00 (EST)
End:   2025-03-15T16:45:00-04:00 (EDT, after DST change)
Duration: 1 hour 15 minutes (correctly calculated across TZ change)
```

### Derived Fields

The following fields are calculated, not entered:

| Field | Calculation | Purpose |
| ----- | ----------- | ------- |
| `duration_minutes` | `end_time - start_time` | Clinical analysis, patient verification |
| `date_recorded` | System timestamp (UTC) | Audit trail |
| `device_timezone` | Device setting at entry | Context for time interpretation |

**Rationale**: This terminology standard was developed specifically for HHT clinical studies. The six-level intensity scale ("Spotting" to "Gushing") uses patient-friendly language that accurately maps to clinical severity while being intuitive for self-reporting. The descriptive terms reduce inter-patient variability compared to numeric scales. Timezone-aware timestamps ensure accurate duration calculation for patients who travel or experience DST changes during events.

**Acceptance Criteria**:
- All six intensity levels available in data capture UI
- Intensity selection includes visual/graphic aids
- Times stored with explicit timezone offsets
- Duration calculated correctly across timezone boundaries
- Notes field respects sponsor free-text configuration
- Bleed date matches start time date in local timezone
- All three daily status options available: nosebleed, no nosebleed, don't remember
- "No nosebleed" and "Don't remember" entries do not require time/intensity fields
- Data model enforces mutual exclusivity of daily status states

*End* *HHT Epistaxis Data Capture Standard* | **Hash**: e2501d13

---

## Implementation Reference

### Data Model

The `EpistaxisIntensity` enum in `database/dart/models.dart` implements this terminology standard directly:

| HHT Intensity    | Enum Value           | Display Text       |
| ---------------- | -------------------- | ------------------ |
| Spotting         | `spotting`           | Spotting           |
| Dripping slowly  | `dripping_slowly`    | Dripping slowly    |
| Dripping quickly | `dripping_quickly`   | Dripping quickly   |
| Steady stream    | `steady_stream`      | Steady stream      |
| Pouring          | `pouring`            | Pouring            |
| Gushing          | `gushing`            | Gushing            |

### CDISC Mapping

See `dev-CDISC.md` REQ-d00074 for CDISC Controlled Terminology mapping.

---

## References

- **CDISC Standards**: prd-standards.md (REQ-p00041)
- **FDA Compliance**: prd-clinical-trials.md
- **Implementation**: database/dart/models.dart
- **CDISC Mapping**: dev-CDISC.md

---

*End of Document*
