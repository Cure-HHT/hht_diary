# Questionnaire Completion — Participant User Journeys

> **Role**: Participant (Diary mobile app)
> **Source**: spec/prd-questionnaire-participant-workflow.md, spec/prd-mobile-notifications.md, spec/prd-score-calculation.md
> **Scope**: Diary Mobile Application. This is the participant-side lifecycle of an Assigned Questionnaire sent from the Sponsor Portal. The Study-Coordinator side (send, call back, finalize, unlock) is covered in questionnaire-management-journeys.md and is not repeated.

---

# JNY-COMPLETE-01: Complete and Submit an Assigned Questionnaire

**Actor**: Maria, a Participant
**Goal**: Complete an assigned questionnaire and submit it for Study Coordinator review
**Context**: Maria's Study Coordinator has sent her a questionnaire from the Sponsor Portal. Maria's device is online.

Validates: DIARY-PRD-notification-portal-sent-questionnaire-A, DIARY-PRD-questionnaire-portal-sent-rules-F+G+H+L+M+N+O, DIARY-GUI-questionnaire-portal-sent-workflow-K+L+M+N+Q+R+S, DIARY-GUI-participant-task-list-H+I+K+L

## Steps

1. Maria receives a push notification that a specific questionnaire is available and opens the Diary app.
2. Maria selects the Questionnaire Task, which navigates her into the questionnaire flow.
3. Maria answers every question one at a time; she cannot skip, and her in-progress answers are preserved locally.
4. On the Review Screen, Maria sees all questions and her selected answers and can navigate back to change any answer.
5. Maria confirms Submission; the app displays an Acknowledgement Dialog, and the task shows a completed "awaiting review" state.
6. Before the Study Coordinator finalizes, Maria re-opens the submitted questionnaire, which presents the Review Screen, and edits an answer.
7. After finalization by the Study Coordinator, the questionnaire opens read-only with no edit or submit actions; the score is calculated and stored at finalization.

## Expected Outcome

Maria completes and submits the assigned questionnaire; it is "Submitted — Awaiting Review". She may edit her answers with no time limit until finalization, after which the questionnaire is locked read-only and its score is calculated. The score is not calculated until finalization.

*End* *Complete and Submit an Assigned Questionnaire*
