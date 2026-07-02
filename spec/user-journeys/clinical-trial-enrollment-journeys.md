# Clinical Trial Enrollment — Participant User Journeys

> **Role**: Participant (Diary mobile app)
> **Source**: spec/prd-device-linking.md, spec/prd-questionnaire-management.md
> **Scope**: Diary Mobile Application. The participant-side of enrollment is joining the study on the device. The *Study Coordinator* links the *Participant* and starts their trial from the portal — those steps are covered in participant-management-journeys.md (JNY-PART-01, JNY-PART-03) and are referenced, not repeated.

---

# JNY-ENROLL-01: Joining the Study

**Actor**: Maria, a Participant
**Goal**: Join the clinical trial on her device so her diary data synchronizes once her trial is started
**Context**: Maria has been diagnosed with HHT and enrolled at her site. Her *Study Coordinator* has issued her a *Mobile Linking Code*. Maria installs the Diary app.

Validates: DIARY-GUI-join-study-screen-A+B+C+D+E, DIARY-PRD-questionnaire-system-C

## Steps

1. Maria installs and opens the Diary app and reaches the **Join the Study** screen.
2. Maria enters her *Mobile Linking Code* in the code-entry field.
3. Maria opens and reads the *Clinical Trial Privacy Policy* from the consent link, then checks the **Linking Consent** checkbox.
4. With a complete code entered and consent checked, the **Submit** action becomes enabled; Maria submits, and her device links to her *Participant* record. The system retains her consent acknowledgement together with the privacy-policy version against her record.
5. The app displays a successful-linking confirmation.
6. Maria's *Study Coordinator* starts her trial from the portal (see participant-management-journeys.md JNY-PART-03).
7. On **Trial Start**, *Diary Data Synchronization* activates and Maria's daily entries begin syncing to the *Sponsor Portal*.

## Expected Outcome

Maria is linked to the study with her consent and the privacy-policy version recorded, and once her *Study Coordinator* starts her trial her diary data synchronizes to the sponsor. Trial start is a *Study-Coordinator* action; the participant-observable effect is that synchronization activates on *Trial Start*.

*End* *Joining the Study*
