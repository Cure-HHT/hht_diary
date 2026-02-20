# Investigator Questionnaire Approval Workflow

**Version**: 2.0
**Status**: Draft
**Last Updated**: 2026-02-18

> **See**: prd-portal.md for sponsor portal overview
> **See**: prd-diary-app.md for mobile app requirements
> **See**: prd-event-sourcing-system.md for questionnaire versioning (REQ-p01051, REQ-p01052, REQ-p01053)

---

## Overview

This specification defines the "Investigator Questionnaire Approval" workflow that enables clinical trial staff to request, review, and finalize patient questionnaire responses. This workflow ensures data integrity and regulatory compliance by requiring investigator approval before questionnaire scores are calculated and permanently recorded.

Patients may edit their answers at any time before finalization. Study coordinators may delete a questionnaire at any step after it has been sent.

---

## Workflow Diagram

![Questionnaire Approval Workflow](images/questionnaire-approval-workflow.mmd)

---

## User Journey

### Study Coordinator / Investigator Journey

1. **Initiate Questionnaire Request**

   - Investigator logs into Sponsor Portal
   - Navigates to patient record
   - Selects questionnaire type to send (e.g., EQ, Nose HHT, Quality of Life)
   - Triggers push notification to patient's device

2. **Monitor Completion**
   - Portal updates status as patient progresses through the questionnaire
   - Questionnaire status changes to "Ready for Review" when patient submits

3. **Review and Finalize**
   - Investigator verifies with patient that the questionnaire is complete
   - Select "Finalize and Score" to calculate score, store permanently, and lock questionnaire

4. **Delete (if applicable)**
   - Study coordinator may delete the questionnaire at any step after it was sent (Sent, In Progress, or Ready to Review)
   - A deletion reason is recorded in the audit trail
   - Deletion is NOT permitted after finalization

### Patient Journey

1. **Receive Notification**

   - Patient receives push notification on mobile device
   - Notification indicates specific questionnaire to complete
   - Patient opens Diary app

2. **Complete Questionnaire**

   - Patient answers all questions in the questionnaire
   - Progress is saved locally during completion
   - All questions must be answered before submission

3. **Review Before Submission (Scored Questionnaires)**

   - For questionnaires with calculated scores, patient sees review screen
   - Patient can navigate back to modify any answers
   - Score is NOT calculated until after investigator approval

4. **Submit Questionnaire**

   - Patient selects "Complete and Submit"
   - Answers sync to study database
   - Status visible as "Submitted - Awaiting Review"

5. **Edit Before Finalization (if applicable)**
   - Patient may edit their answers at any time before the investigator finalizes the questionnaire
   - Edits are permitted during Sent, In Progress, and Ready to Review statuses
   - If the patient edits after submission, the questionnaire returns to "In Progress" status

---

## Status State Machine

| Diary Status | Portal Status | Description |
| ------------ | ------------- | ----------- |
| Active | Sent | Questionnaire sent; patient has not started |
| Active | In Progress | Patient is completing questionnaire |
| Editable | Ready to Review | Patient submitted; awaiting investigator decision; patient may still edit |
| Read-only (permanent) | Finalized | Score calculated, questionnaire permanently locked |

### Permitted Transitions

| From | To | Trigger |
| ---- | -- | ------- |
| Not Sent | Sent | Investigator sends questionnaire |
| Sent | In Progress | Patient opens and starts answering |
| In Progress | Ready to Review | Patient submits |
| Ready to Review | In Progress | Patient edits after submission |
| Ready to Review | Finalized | Investigator selects "Finalize and Score" |
| Sent / In Progress / Ready to Review | Deleted (soft) | Study coordinator deletes |

---

## Requirements

# REQ-p01064: Investigator Questionnaire Approval Workflow

**Level**: PRD | **Status**: Draft | **Implements**: p70001, p01051

## Rationale

Clinical trials often require investigator oversight of patient-reported outcomes to ensure data quality and protocol compliance. The Investigator Questionnaire Approval workflow provides a controlled process where investigators can trigger questionnaires, review patient responses, and finalize with scoring. Delaying score calculation until investigator approval prevents patients from iteratively adjusting answers to achieve desired scores, maintaining data integrity. Patients retain edit access until finalization so they can correct mistakes without requiring investigator intervention. Study coordinators can delete questionnaires at any active lifecycle step to handle protocol deviations or errors.

## Assertions

A. The system SHALL allow investigators to trigger questionnaire requests via push notification to specific patients.

B. The system SHALL deliver push notifications to the patient's enrolled device when an investigator requests questionnaire completion.

C. The system SHALL present the requested questionnaire to the patient in the Diary app upon notification acknowledgment.

D. The system SHALL require patients to complete all questions before enabling questionnaire submission.

E. The system SHALL present a review screen to patients for questionnaires that have associated scores, allowing answer modification before submission.

F. The system SHALL NOT calculate questionnaire scores until the investigator selects "Finalize and Score".

G. The system SHALL transition questionnaire status to "Ready to Review" in the Portal upon patient submission.

H. The system SHALL allow patients to edit their answers at any time before the investigator finalizes the questionnaire, including after submission.

I. The system SHALL allow investigators to select "Finalize and Score" for submitted questionnaires.

J. The system SHALL calculate and permanently store the questionnaire score when the investigator selects "Finalize and Score".

K. The system SHALL transition questionnaire status to "Read-only (permanent)" in the Diary and "Finalized" in the Portal after score calculation.

L. The system SHALL prevent any modification to questionnaire answers after finalization.

M. The system SHALL allow study coordinators to delete a questionnaire at any step after it has been sent (Sent, In Progress, or Ready to Review).

N. The system SHALL NOT allow deletion of a finalized questionnaire.

O. The system SHALL require a deletion reason when a study coordinator deletes a questionnaire.

P. The system SHALL transition the questionnaire status from "Ready to Review" back to "In Progress" when a patient edits after submission.

Q. The system SHALL support the questionnaire lifecycle until the questionnaire is finalized or deleted.

R. The system SHALL record all status transitions in the audit trail with timestamps and acting user.

S. The system SHALL record the investigator who finalized the questionnaire in the audit trail.

T. The system SHALL record the study coordinator who deleted the questionnaire and the deletion reason in the audit trail.

*End* *Investigator Questionnaire Approval Workflow* | **Hash**: 8790cf5d
---

## Audit Trail Events

The following events SHALL be recorded for this workflow:

| Event | Actor | Data Captured |
| ----- | ----- | ------------- |
| Questionnaire requested | Investigator | Patient ID, questionnaire type, timestamp |
| Notification delivered | System | Device ID, delivery timestamp |
| Questionnaire started | Patient | Start timestamp |
| Questionnaire submitted | Patient | Submit timestamp, answer snapshot |
| Answers modified | Patient | Change timestamp, previous/new values |
| Review initiated | Investigator | Review start timestamp |
| Questionnaire finalized | Investigator | Finalization timestamp, calculated score |
| Questionnaire deleted | Study Coordinator | Deletion timestamp, deletion reason |

---

## References

- **Portal**: prd-portal.md (REQ-p70001)
- **Questionnaire Versioning**: prd-event-sourcing-system.md (REQ-p01051, REQ-p01052, REQ-p01053)
- **Audit Trail**: prd-database.md (REQ-p00004)
- **FDA Compliance**: prd-clinical-trials.md (REQ-p00010)
