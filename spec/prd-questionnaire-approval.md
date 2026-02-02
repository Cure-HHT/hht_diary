# Investigator Questionnaire Approval Workflow

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2026-02-02

> **See**: prd-portal.md for sponsor portal overview
> **See**: prd-diary-app.md for mobile app requirements
> **See**: prd-event-sourcing-system.md for questionnaire versioning (REQ-p01051, REQ-p01052, REQ-p01053)

---

## Overview

This specification defines the "Investigator Questionnaire Approval" workflow that enables clinical trial staff to request, review, and finalize patient questionnaire responses. This workflow ensures data integrity and regulatory compliance by requiring investigator approval before questionnaire scores are calculated and permanently recorded.

---

## Workflow Diagram

![Questionnaire Approval Workflow](images/questionnaire-approval-workflow.mmd)

---

## User Journey

### Investigator Journey

1. **Initiate Questionnaire Request**
   - Investigator logs into Sponsor Portal
   - Navigates to patient record
   - Selects questionnaire type to send (e.g., EQ, Nose HHT, Quality of Life)
   - Triggers push notification to patient's device

2. **Monitor Completion**
   - Portal updates status when patient completes and submits questionnaire
   - Patient may continue to edit answers until the questionnaire is finalized
   - Questionnaire status changes to "Ready for Review"

3. **Review and Finalize**
   - Investigator verifies with patient that the questionnaire is complete
   - Select "Finalize and Score" to calculate score, store permanently, and lock questionnaire
   - Patient can no longer edit answers after finalization

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
   - Patient may continue to edit and resubmit answers until investigator finalizes

---

## Status State Machine

| Diary Status | Portal Status | Description |
| ------------ | ------------- | ----------- |
| Active | Pending | Patient is completing questionnaire |
| Submitted (editable) | Ready to Review | Patient submitted, awaiting investigator decision. Patient may still edit and resubmit. |
| Read-only (permanent) | Finalized | Score calculated, questionnaire permanently locked |

---

## Requirements

# REQ-p01064: Investigator Questionnaire Approval Workflow

**Level**: PRD | **Status**: Draft | **Implements**: p70001, p01051

## Rationale

Clinical trials often require investigator oversight of patient-reported outcomes to ensure data quality and protocol compliance. The Investigator Questionnaire Approval workflow provides a controlled process where investigators can trigger questionnaires, review patient responses, and finalize with scoring. Patients may freely edit and resubmit their answers at any time until the investigator finalizes the questionnaire, reducing friction and enabling patients to correct mistakes without investigator intervention. Delaying score calculation until investigator approval prevents premature scoring. Once finalized, the questionnaire is permanently locked.

## Assertions

A. The system SHALL allow investigators to trigger questionnaire requests via push notification to specific patients.

B. The system SHALL deliver push notifications to the patient's enrolled device when an investigator requests questionnaire completion.

C. The system SHALL present the requested questionnaire to the patient in the Diary app upon notification acknowledgment.

D. The system SHALL require patients to complete all questions before enabling questionnaire submission.

E. The system SHALL present a review screen to patients for questionnaires that have associated scores, allowing answer modification before submission.

F. The system SHALL NOT calculate questionnaire scores until the investigator selects "Finalize and Score".

G. The system SHALL transition questionnaire status to "Submitted (editable)" in the Diary and "Ready to Review" in the Portal upon patient submission.

H. The system SHALL allow patients to modify and resubmit questionnaire answers at any time while the questionnaire has not been finalized.

I. The system SHALL allow investigators to select "Finalize and Score" for submitted questionnaires.

J. The system SHALL calculate and permanently store the questionnaire score when the investigator selects "Finalize and Score".

K. The system SHALL transition questionnaire status to "Read-only (permanent)" in the Diary and "Finalized" in the Portal after score calculation.

L. The system SHALL prevent any modification to questionnaire answers after finalization.

M. The system SHALL record all status transitions in the audit trail with timestamps and acting user.

N. The system SHALL record the investigator who finalized the questionnaire in the audit trail.

*End* *Investigator Questionnaire Approval Workflow* | **Hash**: 7ba8d6d5
---

## Audit Trail Events

The following events SHALL be recorded for this workflow:

| Event | Actor | Data Captured |
| ----- | ----- | ------------- |
| Questionnaire requested | Investigator | Patient ID, questionnaire type, timestamp |
| Notification delivered | System | Device ID, delivery timestamp |
| Questionnaire started | Patient | Start timestamp |
| Questionnaire submitted | Patient | Submit timestamp, answer snapshot |
| Answers modified (pre-finalization) | Patient | Change timestamp, previous/new values |
| Questionnaire resubmitted | Patient | Resubmit timestamp, updated answer snapshot |
| Review initiated | Investigator | Review start timestamp |
| Questionnaire finalized | Investigator | Finalization timestamp, calculated score |

---

## References

- **Portal**: prd-portal.md (REQ-p70001)
- **Questionnaire Versioning**: prd-event-sourcing-system.md (REQ-p01051, REQ-p01052, REQ-p01053)
- **Audit Trail**: prd-database.md (REQ-p00004)
- **FDA Compliance**: prd-clinical-trials.md (REQ-p00010)
