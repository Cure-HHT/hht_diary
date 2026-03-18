# Questionnaire Session User Journeys

> **Source**: prd-questionnaire-session.md

---

# JNY-Questionnaire-Session-01: Deferring a Questionnaire

**Actor**: Maria (Patient)
**Goal**: Defer a questionnaire she is not ready to complete right now
**Context**: Maria has been asked to complete the NOSE HHT questionnaire. She opens the app and sees the pending task, but she only has a few minutes before a meeting.

Validates: REQ-p01073

## Steps

1. Maria taps the questionnaire task notification
2. Maria sees a readiness screen: "This questionnaire takes about 10-12 minutes. Please ensure you have enough uninterrupted time to complete it."
3. Maria selects "Not now"
4. Maria is returned to the home screen
5. The questionnaire task remains visible for later completion

## Expected Outcome

Maria defers the questionnaire without penalty. The deferral is logged. She can start the questionnaire at a time that works for her.

*End* *Deferring a Questionnaire*

---

# JNY-Questionnaire-Session-02: Session Expiry After Interruption

**Actor**: Maria (Patient)
**Goal**: Resume a questionnaire after being interrupted
**Context**: Maria started the NOSE HHT questionnaire and answered 15 of 29 questions. She received a phone call and locked her phone. Over 30 minutes pass before she returns to the app.

Validates: REQ-p01073

## Steps

1. Maria reopens the Diary app
2. The app detects the questionnaire session has exceeded the 30-minute timeout
3. Maria sees a message: "Questionnaire Expired. Please redo."
4. Maria's partial responses are discarded
5. Maria taps the questionnaire task to begin again
6. Maria sees the readiness screen again and confirms she is ready
7. Maria completes the questionnaire from the beginning

## Expected Outcome

Maria's expired session is recorded for audit purposes. She restarts the questionnaire fresh and completes it in a single sitting.

*End* *Session Expiry After Interruption*
