# NOSE HHT Questionnaire

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2026-01-21

> **See**: prd-questionnaire-system.md for parent requirement (REQ-p01065)
> **See**: prd-questionnaire-approval.md for investigator approval workflow (REQ-p01064)

---

## Overview

This specification defines the platform's implementation of the NOSE HHT (Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia) questionnaire, a validated 29-question instrument measuring the physical, functional, and emotional impact of nosebleeds on HHT patients.

**Source**: Engelbrecht AM, Engel BJ, Engel ME, et al. Development and Validation of the Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia (NOSE HHT). *JAMA Otolaryngol Head Neck Surg*. 2020;146(11):999–1005. doi:10.1001/jamaoto.2020.3040

NOSE HHT is a **scored questionnaire** that may require investigator approval before score calculation per REQ-p01064.

---

## Instrument Description

**Full Name**: Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia

**Recall Period**: Past two weeks

**Question Count**: 29 questions across 3 categories

**Response Type**: 5-point Likert-style scales (varies by category)

---

## Question Categories

| Category | Questions | Response Scale |
| -------- | --------- | -------------- |
| Physical | 6 items | No problem → As bad as possible |
| Functional | 14 items | No difficulty → Complete difficulty |
| Emotional | 9 items | Not bothered → Very frequently bothered |

The specific question content follows the validated instrument as published in the source reference.

---

## Scoring Algorithm

### Subscale Scores

| Subscale | Questions | Range |
| -------- | --------- | ----- |
| Physical | 6 items | 0-24 |
| Functional | 14 items | 0-56 |
| Emotional | 9 items | 0-36 |

**Subscale Score** = Sum of item values within category

### Total Score

**Total Score** = Physical + Functional + Emotional

**Total Range**: 0-116

**Interpretation**: Higher scores indicate greater impact of epistaxis on quality of life.

---

## Completion Requirements

- Patient reviews all answers before final submission
- Patients MAY skip questions (consistent with paper-based administration)
- Score is NOT displayed to patient
- Score calculated only after investigator approval (when approval workflow is enabled)

---

## Requirements

# REQ-p01067: NOSE HHT Questionnaire

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p01065

## Rationale

NOSE HHT is a validated patient-reported outcome measure specifically designed for assessing the impact of epistaxis in HHT patients. The three-domain structure (physical, functional, emotional) provides comprehensive assessment of nosebleed burden. The platform implements this standard instrument faithfully while allowing the same flexibility patients would have with paper-based administration (e.g., ability to skip questions).

## Assertions

A. The system SHALL present the NOSE HHT questionnaire with 29 questions across three categories: Physical (6), Functional (14), and Emotional (9).

B. The system SHALL display the instrument preamble text explaining the questionnaire purpose and two-week recall period.

C. The system SHALL use a 5-point response scale for all questions with category-specific labels as defined in the validated instrument.

D. The system SHALL allow patients to skip individual questions, consistent with paper-based administration.

E. The system SHALL present a review screen allowing patients to verify and modify answers before final submission.

F. The system SHALL calculate subscale scores by summing item values within each category.

G. The system SHALL calculate the total score as the sum of all three subscale scores.

H. The system SHALL prevent modification of answers after the questionnaire has been finalized.

I. The system SHALL record the exact response value (0-4) for each answered question.

### Sponsor-Configurable Investigator Approval (Optional)

J. When investigator approval is enabled, the system SHALL NOT calculate or display the NOSE HHT score until the investigator selects "Finalize and Score".

K. When investigator approval is enabled, the system SHALL store the calculated score permanently upon investigator finalization.

L. The system SHALL record the questionnaire version used for each response per REQ-p01051.

*End* *NOSE HHT Questionnaire* | **Hash**: eeaa5a12
---

## User Interface Requirements

The UI implementation SHALL:

- Display one question at a time or scrollable list (sponsor-configurable)
- Show category headers to orient the patient
- Provide clear indication of completion progress (e.g., "Question 15 of 29")
- Allow navigation back to previous questions
- Display review summary before final submission
- Show clear confirmation when questionnaire is submitted

---

## References

- **Source Instrument**: JAMA Otolaryngol Head Neck Surg. 2020;146(11):999–1005
- **Parent Requirement**: prd-questionnaire-system.md (REQ-p01065)
- **Approval Workflow**: prd-questionnaire-approval.md (REQ-p01064)
- **Versioning Model**: prd-event-sourcing-system.md (REQ-p01051)
- **Event Sourcing**: prd-database.md (REQ-p00004)
