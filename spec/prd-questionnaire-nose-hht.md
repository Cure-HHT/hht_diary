# NOSE HHT Questionnaire

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2026-01-21

> **See**: prd-questionnaire-system.md for parent requirement (REQ-p01065)
> **See**: prd-questionnaire-approval.md for investigator approval workflow (REQ-p01064)

---

## User Journeys

# JNY-NOSE-HHT-01: Completing the NOSE HHT Assessment

**Actor**: Maria (Patient)
**Goal**: Complete the NOSE HHT questionnaire to assess how nosebleeds have impacted her life
**Context**: Maria is participating in an HHT clinical trial. Her investigator has triggered the NOSE HHT questionnaire as part of her scheduled assessment. Maria receives a notification to complete it.

## Steps

1. Maria opens the Diary app and sees the pending NOSE HHT questionnaire
2. Maria reads the preamble explaining the two-week recall period
3. Maria begins answering questions, seeing one question at a time
4. Maria notices the category header changes as she moves from Physical to Functional questions
5. Maria sees the progress indicator showing how many questions remain
6. Maria is unsure about one question and decides to skip it
7. Maria continues through the Emotional category questions
8. Maria reaches the review screen showing all her answers
9. Maria goes back to answer the skipped question
10. Maria reviews her final answers and taps to submit
11. The app shows confirmation that the questionnaire is submitted for investigator review

## Expected Outcome

Maria successfully completes the NOSE HHT questionnaire. Her responses are submitted and await investigator approval before the score is calculated.

*End* *Completing the NOSE HHT Assessment*

---

## Overview

This specification defines the platform's implementation of the NOSE HHT (Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia) questionnaire, a validated 29-question instrument measuring the physical, functional, and emotional impact of nosebleeds on HHT patients.

**Source**: Engelbrecht AM, Engel BJ, Engel ME, et al. Development and Validation of the Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia (NOSE HHT). *JAMA Otolaryngol Head Neck Surg*. 2020;146(11):999–1005. doi:10.1001/jamaoto.2020.3040

NOSE HHT is a **scored questionnaire** that may require investigator approval before score calculation per REQ-p01064.

## Requirements

# REQ-p01067: NOSE HHT Questionnaire

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p01065

Addresses: JNY-NOSE-HHT-01

## Rationale

NOSE HHT is a validated patient-reported outcome measure specifically designed for assessing the impact of epistaxis in HHT patients. The three-domain structure (physical, functional, emotional) provides comprehensive assessment of nosebleed burden. The platform implements this standard instrument faithfully while allowing the same flexibility patients would have with paper-based administration (e.g., ability to skip questions).

## Assertions

A. The system SHALL present the NOSE HHT questionnaire with 29 questions across three categories: Physical (6), Functional (14), and Emotional (9).

B. The system SHALL display the instrument preamble text explaining the questionnaire purpose and two-week recall period.

C. The system SHALL use a 5-point response scale for all questions with category-specific labels as defined in the validated instrument.

D. The system SHALL allow patients to skip individual questions, consistent with paper-based administration.

E. The system SHALL present a review screen allowing patients to verify and modify answers before final submission.

G. The system SHALL calculate the score according to the source description.

H. The system SHALL prevent modification of answers after the questionnaire has been finalized.

I. The system SHALL record the exact response value (0-4) for each answered question as well as the displayed and normalized (English) versions of the answers.


*End* *NOSE HHT Questionnaire* | **Hash**: 7473ad89
---

# REQ-p01070: NOSE HHT User Interface

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p01067

Addresses: JNY-NOSE-HHT-01

## Rationale

The NOSE HHT questionnaire contains 29 questions across three categories. The UI must guide patients through the instrument while preventing fatigue and confusion. Single-question display with progress indication and category context helps patients maintain focus and complete the questionnaire accurately.

## Assertions

A. The system SHALL display one question at a time during NOSE HHT completion.

B. The system SHALL show category headers (Physical, Functional, Emotional) to orient the patient within the questionnaire.

C. The system SHALL provide clear indication of completion progress throughout the questionnaire.

D. The system SHALL allow navigation back to previous questions before final submission.

E. The system SHALL display a review summary allowing patients to see all answers before final submission.

F. The system SHALL show clear confirmation when the questionnaire is submitted.

*End* *NOSE HHT User Interface* | **Hash**: 1f1f5598
---

## References

- **Source Instrument**: JAMA Otolaryngol Head Neck Surg. 2020;146(11):999–1005
- **Parent Requirement**: prd-questionnaire-system.md (REQ-p01065)
- **Approval Workflow**: prd-questionnaire-approval.md (REQ-p01064)
- **Versioning Model**: prd-event-sourcing-system.md (REQ-p01051)
- **Event Sourcing**: prd-database.md (REQ-p00004)
