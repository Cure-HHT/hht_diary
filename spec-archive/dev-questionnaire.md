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

**Level**: dev | **Status**: Draft | **Implements**: -
**Refines**: REQ-p01064, REQ-p01074

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

---

---

# REQ-d80064: Questionnaire Version Integrity Enforcement

**Level**: dev | **Status**: Draft | **Implements**: -
**Refines**: REQ-p00004, REQ-p01051

> **See**: [docs/questionnaire-versioning.md](../docs/questionnaire-versioning.md) for architecture decisions: directory structure, locking workflow, hash algorithm, and CI check design.

## Rationale

REQ-p01051-T establishes that deployed questionnaire versions are immutable. REQ-p00004 requires immutable, append-only records with tamper prevention through database constraints. The ALCOA++ Original principle (see `spec/regulations/fda/prd-fda-21-cfr-11.md` REQ-p80004-R) requires data to be preserved as first captured. These principles extend beyond runtime data to the version artifacts themselves: if the catalog entry, renderer class bundle, or schema definition behind a version can be silently modified after deployment, the system can no longer guarantee that reconstructed patient experiences are authentic.

The locked artifacts are clinically validated. A questionnaire catalog entry encodes the result of formal research validation; each translation is independently validated per language at considerable expense. The lock machinery enforces that the bytes the clinical team validated are the bytes that ship -- not that an engineer did not accidentally edit a widget. Convention alone is insufficient for this guarantee under FDA 21 CFR Part 11; immutability must be mechanically enforced.

The CI/CD system serves as the enforcement layer, using cryptographic hashes to detect unauthorized modifications to locked artifacts. The version lock registry follows the same append-only principle as the event store (REQ-p00004-B, REQ-p00004-P): entries are added but never modified or removed, providing a tamper-evident chain of version provenance. Locked units are small and slow-changing -- catalog entry JSON files, translation bundles, schema definitions, and the source bundle of each versioned renderer class. The CI system validates both that locked artifacts remain unchanged and that the registry itself has not been tampered with, using the branch-protected baseline as the trust anchor.

## Assertions

A. The system SHALL track schema version via the `versioned_type` field.

B. The system SHALL record content version in `event_data` for each response.

C. The system SHALL record GUI version in `event_data` for each response.

D. Version relationships SHALL be documented in the questionnaire registry.

E. The CI/CD system SHALL compute a cryptographic hash of each version's artifacts at lock time.

F. The CI/CD system SHALL reject changes to artifacts of any locked version.

G. The version lock registry SHALL be append-only.

H. Existing entries in the version lock registry SHALL NOT be modified.

I. Existing entries in the version lock registry SHALL NOT be removed.

J. The CI/CD system SHALL validate the lock registry against the branch-protected baseline to detect tampering.

K. Each lock registry entry SHALL record the questionnaire type, versioning dimension, version identifier, cryptographic hash, and the file paths covered.

L. Schema version locks SHALL include the migration function from the prior version as part of the locked artifact.

*End* *Questionnaire Version Integrity Enforcement* | **Hash**: dd2e9ea1
