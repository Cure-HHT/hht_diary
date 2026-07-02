# Questionnaire Session — Participant User Journeys

> **Role**: Participant (Diary mobile app)
> **Source**: spec/prd-questionnaire-participant-workflow.md
> **Scope**: Diary Mobile Application. Each journey is one happy-path interaction lifecycle beginning with the Participant signed in and on the Diary home screen with a questionnaire assigned.

---

# JNY-SESSION-01: Deferring a Questionnaire

**Actor**: Maria, a Participant
**Goal**: Defer a questionnaire she is not ready to complete right now
**Context**: Maria has been sent the NOSE HHT questionnaire. She opens the app and sees the pending task but only has a few minutes before a meeting.

Validates: DIARY-PRD-questionnaire-portal-sent-rules-A+B+D+E, DIARY-GUI-questionnaire-portal-sent-workflow-A+B

## Steps

1. Maria selects the pending NOSE HHT Questionnaire Task.
2. Maria sees the Preamble stating the estimated completion time and asking her to ensure she has enough uninterrupted time.
3. Maria selects "Not Now".
4. The interface returns Maria to the home screen.
5. The questionnaire task remains visible for later completion.

## Expected Outcome

Maria defers the questionnaire without penalty. She can start it later; the task stays on her list until completed.

*End* *Deferring a Questionnaire*

---

# JNY-SESSION-02: Session Expiry After Interruption

**Actor**: Maria, a Participant
**Goal**: Resume a questionnaire after being interrupted
**Context**: Maria started the NOSE HHT questionnaire and answered 15 of 29 questions. She was interrupted and locked her phone; more than the configured Session Timeout passes before she returns.

Validates: DIARY-PRD-questionnaire-session-timeout-A+C+D, DIARY-GUI-questionnaire-session-expiry-B+C+D

## Steps

1. Maria reopens the Diary app and returns to the questionnaire.
2. The app detects the session has exceeded the configured Session Timeout.
3. Maria sees a Session Expiry Dialog informing her the session expired and her previous answers were not saved.
4. Maria selects "Start Again".
5. The interface dismisses the dialog and presents the Preamble.
6. Maria confirms readiness and completes the questionnaire from the beginning in one sitting.

## Expected Outcome

Maria's expired session is handled per the Session Timeout rules: her partial answers were discarded and she restarts fresh from the Preamble, completing the questionnaire in a single sitting.

*End* *Session Expiry After Interruption*
