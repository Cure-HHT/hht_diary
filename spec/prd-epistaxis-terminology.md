# HHT Epistaxis Data Capture Terminology

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-11-28
**Status**: Draft

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

**Level**: PRD | **Status**: Draft | **Implements**: p00044

## Rationale

This requirement establishes the HHT-specific data capture standard for epistaxis (nosebleed) events in clinical trials. The six-level intensity scale uses patient-friendly language that maps to clinical severity while remaining intuitive for self-reporting, reducing inter-patient variability compared to numeric scales. Timezone-aware timestamps enable accurate duration calculation for patients who travel or experience daylight saving time changes during events. The three-state daily status model (had nosebleed, no nosebleed, don't remember) supports ALCOA+ principles by allowing honest uncertainty rather than forcing fabricated data. This standard was developed specifically for HHT clinical studies to ensure consistent, accurate data collection across all participating sites.

## Assertions

A. The system SHALL capture epistaxis events using the HHT-specific terminology standard defined in this requirement.
B. The system SHALL store nosebleed date in bleed_date field using YYYY-MM-DD format (ISO 8601).
C. The system SHALL validate that bleed_date is not a future date.
D. The system SHALL validate that bleed_date matches the date component of start_time after timezone conversion.
E. The system SHALL provide bleed_today field with exactly three enumerated values: had_nosebleed, no_nosebleed, and dont_remember.
F. The system SHALL present remaining fields (time, intensity, notes) for data entry only when bleed_today is had_nosebleed.
G. The system SHALL end form submission without requiring time/intensity fields when bleed_today is no_nosebleed or dont_remember.
H. The system SHALL allow had_nosebleed status to be inferred when patient enters nosebleed event details directly.
I. The data model SHALL enforce mutual exclusivity of the three bleed_today states.
J. The system SHALL store start_time in ISO 8601 format with explicit timezone offset (YYYY-MM-DDTHH:MM:SS±HH:MM).
K. The system SHALL display start_time to users in localized 12-hour or 24-hour format with timezone indicator when different from user's local time or end_time timezone.
L. The system SHALL store the user-entered start timezone in a start_time_zone field.
M. The system SHALL store end_time in ISO 8601 format with explicit timezone offset (YYYY-MM-DDTHH:MM:SS±HH:MM).
N. The system SHALL display end_time to users in localized 12-hour or 24-hour format with timezone indicator when different from user's local time or start_time timezone.
O. The system SHALL validate that end_time is after start_time accounting for timezone differences.
P. The system SHALL store the user-entered end timezone in an end_time_zone field.
Q. The system SHALL provide intensity field with exactly six enumerated values in order: spotting, dripping_slowly, dripping_quickly, steady_stream, pouring, and gushing.
R. The system SHALL display intensity options with accompanying graphic or visual aids.
S. The system SHALL present intensity options ordered from least to most severe.
T. The system SHALL provide notes field for selection from predefined text options that are sponsor-configurable per study protocol.
U. The system SHALL prohibit free text entry in notes field when configured by sponsor to prevent unblinding, PHI exposure, or PII exposure.
V. The system SHALL calculate duration_minutes as a derived value using end_time minus start_time.
W. The system SHALL allow users to adjust either time values or timezone selections when calculated duration appears incorrect.
X. The system SHALL recalculate duration after any time or timezone adjustment.
Y. The system SHALL store date_recorded as a system-generated timestamp in UTC for audit trail purposes.
Z. The system SHALL display the actual user-entered timezone when loading stored data, not just the timezone offset.

*End* *HHT Epistaxis Data Capture Standard* | **Hash**: 36dc9faf

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
