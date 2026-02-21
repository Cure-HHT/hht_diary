# Questionnaire Implementation

**Version**: 1.0
**Audience**: Development Specification
**Status**: Draft
**Last Updated**: 2026-02-21

> **See**: prd-questionnaire-system.md for clinical questionnaire system (REQ-p01065)
> **See**: prd-questionnaire-approval.md for questionnaire lifecycle (REQ-p01064)
> **See**: prd-system.md for platform state change communication principle (REQ-p01074)

---

# REQ-d00113: Deleted Questionnaire Submission Handling

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p01074, REQ-p01064

## Rationale

REQ-p01064 assertions M-O allow study coordinators to delete questionnaires at any active lifecycle step (Sent, In Progress, Ready to Review). A race condition exists: a patient may be mid-questionnaire when the coordinator deletes it. Without specific handling, the patient encounters a generic or confusing error on submit. This requirement specifies the server-side validation, error code, client-side messaging, and navigation behavior for this scenario. The design validates at submission time only, avoiding the complexity and infrastructure cost of real-time push or polling.

## Assertions

A. When a patient submits a questionnaire, the server SHALL validate that the questionnaire has not been deleted before accepting the submission.

B. If the questionnaire was deleted since the patient began filling it out, the server SHALL reject the submission with a `questionnaire_deleted` error code.

C. Upon receiving a `questionnaire_deleted` error, the app SHALL display a message that clearly communicates the questionnaire was removed by the study team.

D. The error message SHALL acknowledge that the patient's responses could not be submitted.

E. After displaying the error, the app SHALL return the patient to their home or task screen, and the deleted questionnaire SHALL no longer appear as an actionable item.

F. The system SHALL NOT require real-time polling, push notifications, or mid-session interruption to handle this scenario; validation SHALL occur at submission time only.

*End* *Deleted Questionnaire Submission Handling* | **Hash**: 6aaa85fd
