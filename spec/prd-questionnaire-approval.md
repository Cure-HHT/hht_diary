# Investigator Questionnaire Approval Workflow

**Version**: 1.0
**Status**: Draft
**Last Updated**: 2026-01-21

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
   - Diary no longer allows edits to the questionnaire
   - Questionnaire status changes to "Ready for Review"

3. **Review and Finalize**
   - Investigator verifies with patient that the questinnaire is complete
   - **Option A - Finalize**: Select "Finalize and Score" to calculate score, store permanently, and lock questionnaire
   - **Option B - Return for Edits**: Select "Unlock for Editing" to return questionnaire to patient for modifications

4. **Handle Edits (if applicable)**
   - If unlocked, wait for patient to resubmit
   - Repeat review process until finalized

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
   - Questionnaire becomes read-only in Diary
   - Answers sync to study database
   - Status visible as "Submitted - Awaiting Review"

5. **Handle Unlock Request (if applicable)**
   - If investigator unlocks for editing, patient receives notification
   - Questionnaire status changes to "Review"
   - Patient can modify answers
   - Patient resubmits when ready

---

## Status State Machine

| Diary Status | Portal Status | Description |
| ------------ | ------------- | ----------- |
| Active | Pending | Patient is completing questionnaire |
| Read-only | Ready to Review | Patient submitted, awaiting investigator decision |
| Review | Unlocked | Investigator returned for patient edits |
| Read-only (permanent) | Finalized | Score calculated, questionnaire permanently locked |

---

## Requirements

# REQ-p01064: Investigator Questionnaire Approval Workflow

**Level**: PRD | **Status**: Draft | **Implements**: p70001, p01051

## Rationale

Clinical trials often require investigator oversight of patient-reported outcomes to ensure data quality and protocol compliance. The Investigator Questionnaire Approval workflow provides a controlled process where investigators can trigger questionnaires, review patient responses, and either finalize with scoring or return for patient edits. Delaying score calculation until investigator approval prevents patients from iteratively adjusting answers to achieve desired scores, maintaining data integrity. The review cycle allows investigators to address incomplete or unclear responses before permanent finalization.

## Assertions

A. The system SHALL allow investigators to trigger questionnaire requests via push notification to specific patients.

B. The system SHALL deliver push notifications to the patient's enrolled device when an investigator requests questionnaire completion.

C. The system SHALL present the requested questionnaire to the patient in the Diary app upon notification acknowledgment.

D. The system SHALL require patients to complete all questions before enabling questionnaire submission.

E. The system SHALL present a review screen to patients for questionnaires that have associated scores, allowing answer modification before submission.

F. The system SHALL NOT calculate questionnaire scores until the investigator selects "Finalize and Score".

G. The system SHALL transition questionnaire status to "Read-only" in the Diary and "Ready to Review" in the Portal upon patient submission.

H. The system SHALL prevent patients from modifying submitted questionnaire answers while status is "Read-only".

I. The system SHALL allow investigators to select "Finalize and Score" for submitted questionnaires.

J. The system SHALL calculate and permanently store the questionnaire score when the investigator selects "Finalize and Score".

K. The system SHALL transition questionnaire status to "Read-only (permanent)" in the Diary and "Finalized" in the Portal after score calculation.

L. The system SHALL prevent any modification to questionnaire answers after finalization.

M. The system SHALL allow investigators to select "Unlock for Editing" for submitted questionnaires.

N. The system SHALL transition questionnaire status to "Review" in the Diary when the investigator unlocks for editing.

O. The system SHALL notify the patient when their questionnaire has been unlocked for editing.

P. The system SHALL allow patients to modify answers when questionnaire status is "Review".

Q. The system SHALL allow patients to resubmit after making edits, returning to "Read-only" / "Ready to Review" status.

R. The system SHALL support multiple review cycles until the questionnaire is finalized or deleted.

S. The system SHALL record all status transitions in the audit trail with timestamps and acting user.

T. The system SHALL record the investigator who finalized the questionnaire in the audit trail.

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
| Review initiated | Investigator | Review start timestamp |
| Questionnaire finalized | Investigator | Finalization timestamp, calculated score |
| Questionnaire unlocked | Investigator | Unlock timestamp, reason (optional) |
| Answers modified | Patient | Change timestamp, previous/new values |

---

## References

- **Portal**: prd-portal.md (REQ-p70001)
- **Questionnaire Versioning**: prd-event-sourcing-system.md (REQ-p01051, REQ-p01052, REQ-p01053)
- **Audit Trail**: prd-database.md (REQ-p00004)
- **FDA Compliance**: prd-clinical-trials.md (REQ-p00010)
