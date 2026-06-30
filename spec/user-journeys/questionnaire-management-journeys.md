# Questionnaire Management — Study Coordinator User Journeys

> **Role**: Study Coordinator (Study-Coordinator-only capabilities)
> **Source**: spec/prd-questionnaire-management.md, spec/prd-questionnaire-participant-workflow.md, spec/prd-score-calculation.md, spec/prd-rbac.md
> **Scope**: Sponsor Portal (web). Each journey is one happy-path interaction lifecycle beginning with the Study Coordinator signed in and working from the Participant Dashboard.
>
> **Spec note**: The questionnaire actions (send, call back, finalize, unlock) have platform PRD behavior, but the portal action UI is deployment/sponsor-configured rather than fixed by a platform DIARY-GUI requirement. These journeys validate the PRD behavior and flag the missing platform GUI requirement inline.

---

# JNY-QNR-01: Send a Questionnaire

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Issue a questionnaire to a participant for completion on their mobile app
**Context**: A participant is "Trial Active". Dr. Mitchell is on the Participant Dashboard.

Validates: DIARY-PRD-questionnaire-system-B

**Spec gap**: No platform DIARY-GUI requirement defines the Send Questionnaire portal dialog. This journey validates the PRD behavior only.

## Steps

1. Dr. Mitchell opens the participant's questionnaires and triggers the "Send Questionnaire" action for a questionnaire that is "Not Sent".
2. Dr. Mitchell confirms the send.
3. The system transmits the questionnaire to the participant's mobile app and transitions the instance to "Sent".
4. The participant's app receives a push notification that a questionnaire is available (deferred until the device is online if necessary).

## Expected Outcome

The questionnaire is "Sent" and awaiting participant completion, and the participant has been notified on their mobile app.

*End* *Send a Questionnaire*

---

# JNY-QNR-02: Call Back a Sent Questionnaire

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Withdraw a questionnaire that was sent but not yet submitted
**Context**: A questionnaire was sent (e.g., in error) and the participant has not submitted it. Dr. Mitchell is on the Participant Dashboard.

Validates: DIARY-PRD-questionnaire-system-B

**Spec gap**: The call-back action's behavior is implied by the questionnaire lifecycle rather than a dedicated PRD requirement, and no platform DIARY-GUI requirement defines the portal flow. This journey anchors to the questionnaire-system PRD and flags both gaps.

## Steps

1. Dr. Mitchell selects the "Sent" questionnaire and triggers the "Call Back Questionnaire" action.
2. Dr. Mitchell confirms.
3. The system withdraws the questionnaire and removes the corresponding task from the participant's mobile task list.

## Expected Outcome

The questionnaire is no longer available to the participant and its task is removed from their app; the questionnaire returns to a not-sent state for the cycle.

*End* *Call Back a Sent Questionnaire*

---

# JNY-QNR-03: Finalize a Submitted Questionnaire

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Lock a submitted questionnaire, compute its score, and push it to Rave EDC
**Context**: A participant has submitted a questionnaire, which is now "Ready to Review". Dr. Mitchell is on the Participant Dashboard.

Validates: DIARY-PRD-questionnaire-portal-sent-rules-O, DIARY-PRD-questionnaire-score-calculation-A+B

**Spec gap**: No platform DIARY-GUI requirement defines the portal review-and-finalize UI. This journey validates the PRD behavior only.

## Steps

1. Dr. Mitchell opens the "Ready to Review" questionnaire and reviews the submitted answers.
2. Dr. Mitchell triggers the "Finalize Questionnaire" action and confirms.
3. The system computes the score per the validated algorithm and stores it with the questionnaire record.
4. The system pushes the finalized data to Rave EDC and transitions the questionnaire to "Closed".
5. The participant can no longer edit the answers; the questionnaire is presented to them read-only.

## Expected Outcome

The questionnaire is "Closed" with a calculated, stored score and has been pushed to Rave EDC. The participant's copy is locked and read-only.

*End* *Finalize a Submitted Questionnaire*

---

# JNY-QNR-04: Unlock a Finalized Questionnaire

**Actor**: Dr. Sarah Mitchell, a Study Coordinator
**Goal**: Reopen a finalized questionnaire so the participant can correct answers
**Context**: A "Closed" questionnaire needs correction. Dr. Mitchell is on the Participant Dashboard.

Validates: DIARY-PRD-questionnaire-system-B

**Spec gap**: No dedicated PRD requirement documents the unlock action's preconditions/effect, and no platform DIARY-GUI requirement defines the portal flow. This journey anchors to the questionnaire-system PRD and flags both gaps.

## Steps

1. Dr. Mitchell selects the "Closed" questionnaire and triggers the "Unlock Questionnaire" action.
2. Dr. Mitchell confirms.
3. The system reopens the questionnaire, restoring it to "Ready to Review" and permitting the participant to edit answers again.

## Expected Outcome

The questionnaire is reopened (back to "Ready to Review") and the participant may edit and resubmit, after which it can be finalized again.

*End* *Unlock a Finalized Questionnaire*
