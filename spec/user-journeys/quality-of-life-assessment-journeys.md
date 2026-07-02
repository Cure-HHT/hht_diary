# Quality of Life Assessment — Participant User Journeys

> **Role**: Participant (Diary mobile app)
> **Source**: spec/prd-questionnaire-overview.md, spec/prd-questionnaire-participant-workflow.md
> **Scope**: Diary Mobile Application. Each journey is one happy-path interaction lifecycle beginning with the Participant signed in and on the Diary home screen with the questionnaire assigned.

---

# JNY-QOL-01: Completing the Quality of Life Assessment

**Actor**: Sarah, a Participant
**Goal**: Complete the HHT Quality of Life questionnaire to report how HHT has affected her daily life
**Context**: Sarah is in an HHT clinical trial. Her Study Coordinator has sent the HHT-QoL questionnaire as part of her monthly assessment; Sarah has four weeks of experience to reflect on.

Validates: DIARY-PRD-questionnaire-hht-qol-A+E, DIARY-PRD-questionnaire-portal-sent-rules-A+B+F+L+M, DIARY-GUI-questionnaire-portal-sent-workflow-K+L+N+Q

## Steps

1. Sarah opens the Diary app and selects the pending HHT QoL Questionnaire Task.
2. Sarah reads the Preamble stating the estimated time and that answers are submitted only at the end.
3. Sarah confirms readiness and answers the first question about work/school being interrupted, noting the emphasized key phrase.
4. Sarah answers the remaining questions about social activities, avoiding social situations, and non-epistaxis HHT symptoms.
5. After the final question, Sarah reaches the Review Screen showing all four answers.
6. Sarah reviews her responses and submits.
7. The app displays an Acknowledgement Dialog confirming the questionnaire was submitted and is awaiting Study Coordinator review.

## Expected Outcome

Sarah completes the brief four-question HHT-QoL questionnaire, with the validated key-phrase emphasis preserved. Her responses are submitted and await finalization, after which the score is calculated.

*End* *Completing the Quality of Life Assessment*
