# Clinical Trial Enrollment — Participant User Journeys

> **Role**: Participant (Diary mobile app)
> **Source**: spec/prd-questionnaire-management.md
> **Scope**: Diary Mobile Application. Each journey is one happy-path interaction lifecycle beginning with the Participant having installed the app and linked their device (device linking and authentication are covered in their own journeys and not repeated).
>
> **Spec note**: The current platform models trial start as a Study-Coordinator portal action (see participant-management-journeys.md JNY-PART-03), with diary data synchronization activating on Trial Start (DIARY-PRD-questionnaire-system-C). The legacy participant-completed "Study Start questionnaire" and its investigator-approval gate are not yet a platform requirement; this journey validates the sync-activation behavior and flags the gap inline.

---

# JNY-ENROLL-01: Enrolling in a Clinical Trial

**Actor**: Maria, a Participant
**Goal**: Begin active participation in the clinical trial so her diary data syncs to the sponsor
**Context**: Maria has been diagnosed with HHT and invited to a clinical trial. Her site has enrolled her and she has installed and linked the Diary app. She is prompted to complete the Study Start questionnaire before her data can sync.

Validates: DIARY-PRD-questionnaire-system-B+C

**Spec gap**: No platform requirement defines a participant-completed Study Start (enrollment) questionnaire or the investigator-approval gate that begins trial participation. This journey validates only the platform behavior that diary data synchronization activates on Trial Start. TODO(port): participant-completed Study Start / enrollment questionnaire and its investigator-approval gate (legacy REQ-d00106, REQ-d00108 have no DIARY-* successor).

## Steps

1. Maria opens the Diary app and sees a prompt for the Study Start questionnaire.
2. Maria reads the introduction explaining the questionnaire's purpose.
3. Maria completes and submits the required questionnaire.
4. The app confirms the questionnaire is submitted and awaiting review.
5. The Study Coordinator reviews Maria's responses and starts her trial.
6. Maria receives confirmation that her trial participation has begun.
7. Maria's daily diary entries now synchronize automatically to the Sponsor Portal.

## Expected Outcome

Maria's trial participation begins and her ongoing daily records synchronize to the sponsor. Diary data synchronization is active from Trial Start onward.

*End* *Enrolling in a Clinical Trial*
