# NOSE HHT Assessment — Participant User Journeys

> **Role**: Participant (Diary mobile app)
> **Source**: spec/prd-questionnaire-overview.md, spec/prd-questionnaire-participant-workflow.md
> **Scope**: Diary Mobile Application. Each journey is one happy-path interaction lifecycle beginning with the Participant signed in and on the Diary home screen with the questionnaire assigned.

---

# JNY-NOSE-01: Completing the NOSE HHT Assessment

**Actor**: Maria, a Participant
**Goal**: Complete the NOSE HHT questionnaire to report how nosebleeds have impacted her life
**Context**: Maria is in an HHT clinical trial. Her Study Coordinator has sent the NOSE HHT questionnaire as part of her scheduled assessment, and Maria is notified it is available.

Validates: DIARY-PRD-questionnaire-nose-hht-A+E, DIARY-PRD-questionnaire-portal-sent-rules-A+B+F+G+I+L+M, DIARY-GUI-questionnaire-portal-sent-workflow-D+K+L+N+Q

## Steps

1. Maria opens the Diary app and selects the pending NOSE HHT Questionnaire Task.
2. Maria reads the Preamble, which states the estimated completion time and that answers are submitted only at the end.
3. Maria confirms she is ready and answers questions one at a time, unable to skip.
4. Maria notices the category header change as she moves from Physical to Functional to Emotional questions (the three source-instrument categories).
5. A Progress Indicator shows her position (Question #X out of 29).
6. After the final question, Maria reaches the Review Screen showing all her answers.
7. Maria reviews her answers and submits.
8. The app displays an Acknowledgement Dialog confirming the questionnaire was submitted and is awaiting Study Coordinator review.

## Expected Outcome

Maria completes the 29-question NOSE HHT questionnaire across its Physical, Functional, and Emotional categories. Her responses are submitted and await finalization by the Study Coordinator, after which the score is calculated.

*End* *Completing the NOSE HHT Assessment*
