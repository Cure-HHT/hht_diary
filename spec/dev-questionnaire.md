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

**Level**: dev | **Status**: Draft | **Implements**: REQ-p01064, REQ-p01074

## Rationale

REQ-p01064 assertions M-O allow study coordinators to delete questionnaires at any active lifecycle step (Sent, In Progress, Ready to Review). A race condition exists: a patient may be mid-questionnaire when the coordinator deletes it. Without specific handling, the patient encounters a generic or confusing error on submit. This requirement specifies the server-side validation, error code, client-side messaging, and navigation behavior for this scenario. The design validates at submission time only, avoiding the complexity and infrastructure cost of real-time push or polling.

## Assertions

A. When a patient submits a questionnaire, the server SHALL validate that the questionnaire has not been deleted before accepting the submission.

B. If the questionnaire was deleted since the patient began filling it out, the server SHALL reject the submission with a `questionnaire_deleted` error code.

C. `PrimaryDiaryServerDestination.send` SHALL translate an HTTP 409 response with body containing `"error": "questionnaire_deleted"` to `SendOk`. The submitted event remains in the local event log as the audit fact.

D. The portal inbound-poll endpoint SHALL deliver `{"type": "tombstone", "entry_id": "<uuid>", "entry_type": "<type>"}` messages for entries withdrawn server-side. On receipt, the app SHALL invoke `EntryService.record(entryType: <type>, aggregateId: <entry_id>, eventType: 'tombstone', answers: {}, changeReason: 'portal-withdrawn')`.

E. After a tombstone event materializes, the entry SHALL appear in the materialized `diary_entries` view with `is_deleted = true`. The home screen SHALL NOT offer the entry as an actionable task. The audit history view SHALL still show the entry.

F. Withdrawal becomes visible to the patient via the entry's tombstoned state in their history; submit-time error dialogs are not used.

*End* *Deleted Questionnaire Submission Handling* | **Hash**: 80d904c9
