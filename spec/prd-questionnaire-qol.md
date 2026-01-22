# HHT Quality of Life Questionnaire

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2026-01-21

> **See**: prd-questionnaire-system.md for parent requirement (REQ-p01065)
> **See**: prd-questionnaire-approval.md for investigator approval workflow (REQ-p01064)

---

## Overview

This specification defines the platform's implementation of the HHT Quality of Life Questionnaire, a 4-question instrument measuring how nosebleeds and other HHT-related problems affect patients' daily activities and social engagement.

**Source**: Kasthuri RS, Chaturvedi S, Thomas S, et al. Development and performance of a hereditary hemorrhagic telangiectasia-specific quality-of-life instrument. *Blood Advances*. 2022;6(14):4301–4309. doi:10.1182/bloodadvances.2022007748

HHT Quality of Life is a **scored questionnaire** that may require investigator approval before score calculation per REQ-p01064.

---

## Instrument Description

**Full Name**: HHT Quality of Life Survey

**Recall Period**: Past 4 weeks

**Question Count**: 4 questions

**Response Type**: 5-point frequency scale (Never to Always)

---

## Question Structure

All questions use the same 5-point frequency response scale:

| Value | Label |
| ----- | ----- |
| 0 | Never |
| 1 | Rarely |
| 2 | Sometimes |
| 3 | Often |
| 4 | Always |

The 4 questions assess:
1. Work/school interruption due to nosebleeds
2. Social/family activity interruption due to nosebleeds
3. Avoidance of social activities due to nosebleed concerns
4. Missing commitments due to non-epistaxis HHT problems

The specific question wording follows the validated instrument as published in the source reference.

---

## Scoring Algorithm

### Total Score

**Total Score** = Sum of all 4 question values

**Total Range**: 0-16

**Interpretation**: Higher scores indicate greater impact of HHT on quality of life.

| Score Range | Interpretation |
| ----------- | -------------- |
| 0-4 | Minimal impact |
| 5-8 | Mild impact |
| 9-12 | Moderate impact |
| 13-16 | Severe impact |

---

## Completion Requirements

- Patient reviews all answers before final submission
- Patients MAY skip questions (consistent with paper-based administration)
- Score is NOT displayed to patient
- Score calculated only after investigator approval (when approval workflow is enabled)

---

## Requirements

# REQ-p01068: HHT Quality of Life Questionnaire

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p01065

## Rationale

The HHT Quality of Life questionnaire provides a brief, focused assessment of how HHT symptoms impact patients' daily activities and social life. The 4-question format minimizes patient burden while capturing key domains: work/school interruption, social interruption, social avoidance, and non-epistaxis HHT impact. The 4-week recall window aligns with typical clinical visit intervals. The platform implements this standard instrument faithfully while allowing the same flexibility patients would have with paper-based administration.

## Assertions

A. The system SHALL present the HHT Quality of Life questionnaire with 4 questions about HHT impact on daily activities.

B. The system SHALL display the instrument preamble text explaining the questionnaire purpose and 4-week recall period.

C. The system SHALL use a 5-point frequency response scale: Never, Rarely, Sometimes, Often, Always.

D. The system SHALL allow patients to skip individual questions, consistent with paper-based administration.

E. The system SHALL present a review screen allowing patients to verify and modify answers before final submission.

F. The system SHALL calculate the total score as the sum of all answered question values.

G. The system SHALL prevent modification of answers after the questionnaire has been finalized.

H. The system SHALL record the exact response value (0-4) for each answered question.

### Sponsor-Configurable Investigator Approval (Optional)

I. When investigator approval is enabled, the system SHALL NOT calculate or display the Quality of Life score until the investigator selects "Finalize and Score".

J. When investigator approval is enabled, the system SHALL store the calculated score permanently upon investigator finalization.

K. The system SHALL record the questionnaire version used for each response per REQ-p01051.

*End* *HHT Quality of Life Questionnaire* | **Hash**: a202bed2
---

## User Interface Requirements

The UI implementation SHALL:

- Display all 4 questions on a single screen or scrollable view
- Emphasize key phrases in questions (interrupted, avoided, had to miss, other than nosebleeds)
- Provide clear visual indication of completion status
- Allow easy modification of any answer before submission
- Display review summary before final submission
- Show clear confirmation when questionnaire is submitted

---

## References

- **Source Instrument**: Blood Advances. 2022;6(14):4301–4309
- **Parent Requirement**: prd-questionnaire-system.md (REQ-p01065)
- **Approval Workflow**: prd-questionnaire-approval.md (REQ-p01064)
- **Versioning Model**: prd-event-sourcing-system.md (REQ-p01051)
- **Event Sourcing**: prd-database.md (REQ-p00004)
