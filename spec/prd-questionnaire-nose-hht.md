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
6. Maria continues through the Emotional category questions
7. Maria reaches the review screen showing all her answers
8. Maria reviews her final answers and taps to submit
9. The app shows confirmation that the questionnaire is submitted for investigator review

## Expected Outcome

Maria successfully completes the NOSE HHT questionnaire. Her responses are submitted and await investigator approval before the score is calculated.

*End* *Completing the NOSE HHT Assessment*

---

## Overview

This specification defines the platform's implementation of the NOSE HHT (Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia) questionnaire, a validated 29-question instrument measuring the physical, functional, and emotional impact of nosebleeds on HHT patients.

**Source**: Engelbrecht AM, Engel BJ, Engel ME, et al. Development and Validation of the Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia (NOSE HHT). *JAMA Otolaryngol Head Neck Surg*. 2020;146(11):999–1005. doi:10.1001/jamaoto.2020.3040

NOSE HHT is a **scored questionnaire** that may require investigator approval before score calculation per REQ-p01064.

---

## Questionnaire Content

### Preamble

> Nasal Outcome Score for Epistaxis in Hereditary Hemorrhagic Telangiectasia. Below you will find a list of physical, functional, and emotional consequences of your nosebleeds. We would like to know more about these problems and would appreciate you answering the following questions to the best of your ability.
> There are no right or wrong answers, as your responses are unique to you.
> Please rate your problems as they have been over the past two weeks.

### Questions

#### Physical (Questions 1–6)

Stem: *Please rate how severe the following problems are due to your nosebleeds:*

| # | Question |
| --- | ---------- |
| 1 | Blood running down the back of your throat |
| 2 | Blocked up, stuffy nose |
| 3 | Nasal crusting |
| 4 | Fatigue |
| 5 | Shortness of breath |
| 6 | Decreased sense of smell or taste |

#### Functional (Questions 7–20)

Stem: *How difficult is it to perform the following tasks due to your nosebleeds?*

| # | Question |
| --- | ---------- |
| 7 | Blow your nose |
| 8 | Bend over/pick something up off the ground |
| 9 | Breathe through your nose |
| 10 | Exercise |
| 11 | Work at your job (or school) |
| 12 | Stay asleep |
| 13 | Enjoy time with friends or family |
| 14 | Eat certain foods (e.g. spicy) |
| 15 | Have intimacy with spouse or significant other |
| 16 | Travel (e.g. by plane) |
| 17 | Fall asleep |
| 18 | Clean your house/apartment |
| 19 | Go outdoors regardless of the weather or season |
| 20 | Cook or prepare meals |

#### Emotional (Questions 21–29)

Stem: *How bothered are you by the following due to your nosebleeds?*

| # | Question |
| --- | ---------- |
| 21 | Fear of nosebleeds in public |
| 22 | Fear of not knowing when next nosebleed |
| 23 | Getting blood on your clothes |
| 24 | Fear of not being able to stop a nosebleed |
| 25 | Embarrassment |
| 26 | Frustration, restlessness, irritability |
| 27 | Reduced concentration |
| 28 | Sadness |
| 29 | The need to buy new clothes |

### Response Options

Each category uses a 5-point scale (scored 0–4) with category-specific labels:

#### Physical Response Scale

| Value | Label |
| ----- | ----- |
| 0 | No problem |
| 1 | Mild problem |
| 2 | Moderate problem |
| 3 | Severe problem |
| 4 | As bad as possible |

#### Functional Response Scale

| Value | Label |
| ----- | ----- |
| 0 | No difficulty |
| 1 | Mild difficulty |
| 2 | Moderate difficulty |
| 3 | Severe difficulty |
| 4 | Complete difficulty |

#### Emotional Response Scale

| Value | Label |
| ----- | ----- |
| 0 | Not bothered |
| 1 | Very rarely bothered |
| 2 | Rarely bothered |
| 3 | Frequently bothered |
| 4 | Very frequently bothered |

---

## Requirements

# REQ-p01067: NOSE HHT Questionnaire

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p01065

Addresses: JNY-NOSE-HHT-01

## Rationale

NOSE HHT is a validated patient-reported outcome measure specifically designed for assessing the impact of epistaxis in HHT patients. The three-domain structure (physical, functional, emotional) provides comprehensive assessment of nosebleed burden. The platform implements this standard instrument faithfully. Patients must answer all questions before submission, consistent with paper-based administration where all fields must be completed.

## Assertions

A. The system SHALL present the NOSE HHT questionnaire with 29 questions across three categories: Physical (6), Functional (14), and Emotional (9).

B. The system SHALL display the instrument preamble text explaining the questionnaire purpose and two-week recall period.

C. The system SHALL use a 5-point response scale for all questions with category-specific labels as defined in the validated instrument.

D. The system SHALL NOT allow patients to skip individual questions, consistent with paper-based administration.

E. The system SHALL present a review screen allowing patients to verify and modify answers before final submission.

G. The system SHALL calculate the score according to the source description.

H. The system SHALL prevent modification of answers after the questionnaire has been finalized.

I. The system SHALL record the exact response value (0-4) for each answered question as well as the displayed and normalized (English) versions of the answers.


*End* *NOSE HHT Questionnaire* | **Hash**: 23b411c6
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

G. The system SHALL display the preamble as a multi-screen sequence before presenting questions.

H. The system SHALL require the patient to acknowledge each preamble screen before advancing.

I. The system SHALL display the preamble every time the patient opens the questionnaire, regardless of prior completion attempts.

*End* *NOSE HHT User Interface* | **Hash**: 84fa171d
---

## References

- **Source Instrument**: JAMA Otolaryngol Head Neck Surg. 2020;146(11):999–1005
- **Parent Requirement**: prd-questionnaire-system.md (REQ-p01065)
- **Approval Workflow**: prd-questionnaire-approval.md (REQ-p01064)
- **Versioning Model**: prd-event-sourcing-system.md (REQ-p01051)
- **Event Sourcing**: prd-database.md (REQ-p00004)
