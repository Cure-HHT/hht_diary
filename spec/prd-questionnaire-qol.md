# HHT Quality of Life Questionnaire

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2026-01-21

> **See**: prd-questionnaire-system.md for parent requirement (REQ-p01065)
> **See**: prd-questionnaire-approval.md for investigator approval workflow (REQ-p01064)

---

## User Journeys

# JNY-HHT-QoL-01: Completing the Quality of Life Assessment

**Actor**: Sarah (Patient)
**Goal**: Complete the HHT Quality of Life questionnaire to report how HHT has affected her daily life
**Context**: Sarah is participating in an HHT clinical trial. Her investigator has triggered the HHT Quality of Life questionnaire as part of her monthly assessment. Sarah has four weeks of experience to reflect on.

## Steps

1. Sarah opens the Diary app and sees the pending HHT QoL questionnaire
2. Sarah reads the preamble explaining the four-week recall period
3. Sarah answers the first question about work/school interruption, noting the emphasized key phrase
4. Sarah moves to the second question about social activities being interrupted
5. Sarah answers the third question about avoiding social situations
6. Sarah answers the fourth question about non-epistaxis HHT symptoms
7. Sarah reaches the review screen showing all four answers
8. Sarah reviews her responses and taps to submit
9. The app shows confirmation that the questionnaire is submitted for investigator review

## Expected Outcome

Sarah successfully completes the brief HHT QoL questionnaire. Her responses are submitted and await investigator approval before the score is calculated.

*End* *Completing the Quality of Life Assessment*

---

## Overview

This specification defines the platform's implementation of the HHT Quality of Life Questionnaire, a 4-question instrument measuring how nosebleeds and other HHT-related problems affect patients' daily activities and social engagement.

**Source**: Kasthuri RS, Chaturvedi S, Thomas S, et al. Development and performance of a hereditary hemorrhagic telangiectasia-specific quality-of-life instrument. *Blood Advances*. 2022;6(14):4301–4309. doi:10.1182/bloodadvances.2022007748

HHT Quality of Life is a **scored questionnaire** that may require investigator approval before score calculation per REQ-p01064.

---

## Questionnaire Content

### Preamble

> This questionnaire helps us understand how your nosebleeds affect your daily life and wellbeing.
> Please think about your experiences over the past 4 weeks when answering these questions. There are no right or wrong answers.
> Your honest responses will help healthcare providers develop better treatment plans and support strategies.
> You must answer all questions to submit the survey.

### Questions

| # | Question |
| --- | ---------- |
| 1 | How often in the past 4 weeks has an activity for your work, school, or regularly scheduled commitments been **interrupted** by a nose bleed? |
| 2 | How often in the past 4 weeks has an activity with your partner, family, or friends been **interrupted** by a nose bleed? |
| 3 | How often in the past 4 weeks have you **avoided** social activities because you were worried about having a nose bleed? |
| 4 | How often in the past 4 weeks have you **had to miss** your work, school, or regularly scheduled commitments because of HHT-related problems **other than nosebleeds**? |

### Response Options

All questions use a single 5-point frequency scale (scored 0–4):

| Value | Label |
| ----- | ----- |
| 0 | Never |
| 1 | Rarely |
| 2 | Sometimes |
| 3 | Often |
| 4 | Always |

---

## Requirements

# REQ-p01068: HHT Quality of Life Questionnaire

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p01065

Addresses: JNY-HHT-QoL-01

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

H. The system SHALL record the exact response value (0-4) for each answered question, along with the answer the text of the answer the user selected and the normalized (English) text.

K. The system SHALL record the questionnaire version used for each record.

*End* *HHT Quality of Life Questionnaire* | **Hash**: 12efcb9b
---

# REQ-p01071: HHT Quality of Life User Interface

**Level**: PRD | **Status**: Draft | **Implements**: REQ-p01068

Addresses: JNY-HHT-QoL-01

## Rationale

The HHT Quality of Life questionnaire is brief (4 questions) but requires careful reading of key phrases that distinguish each question's focus. The UI must emphasize these distinguishing phrases as formatted in the original validated instrument to ensure patients understand and respond accurately.

## Assertions

A. The system SHALL display each question on a separate screen during HHT QoL completion.

B. The system SHALL emphasize key phrases in questions (interrupted, avoided, had to miss, other than nosebleeds) matching the formatting of the original paper instrument.

C. The system SHALL provide clear visual indication of completion status throughout the questionnaire.

D. The system SHALL allow easy modification of any answer before final submission.

E. The system SHALL display a review summary allowing patients to see all answers before final submission.

F. The system SHALL show clear confirmation when the questionnaire is submitted.

G. The system SHALL display the preamble as a multi-screen sequence before presenting questions.

H. The system SHALL require the patient to acknowledge each preamble screen before advancing.

I. The system SHALL display the preamble every time the patient opens the questionnaire, regardless of prior completion attempts.

*End* *HHT Quality of Life User Interface* | **Hash**: a231a942
---

## References

- **Source Instrument**: Blood Advances. 2022;6(14):4301–4309
- **Parent Requirement**: prd-questionnaire-system.md (REQ-p01065)
- **Approval Workflow**: prd-questionnaire-approval.md (REQ-p01064)
- **Versioning Model**: prd-event-sourcing-system.md (REQ-p01051)
- **Event Sourcing**: prd-database.md (REQ-p00004)
