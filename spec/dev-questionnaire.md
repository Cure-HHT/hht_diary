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

---

---

# REQ-d80064: Questionnaire Version Integrity Enforcement

**Level**: Dev | **Status**: Draft | **Implements**: REQ-p01051, REQ-p00004, REQ-p00011-H

> **See**: [docs/questionnaire-versioning.md](../docs/questionnaire-versioning.md) for architecture decisions: directory structure, locking workflow, hash algorithm, and CI check design.

## Rationale

REQ-p01051-T establishes that deployed questionnaire versions are immutable. REQ-p00004 requires immutable, append-only records with tamper prevention through database constraints. REQ-p00011-H requires data to be "original by representing the first recording." These principles extend beyond runtime data to the version artifacts themselves: if the code, content, or schema definition behind a version can be silently modified after deployment, the system can no longer guarantee that reconstructed patient experiences are authentic.

Convention alone is insufficient for FDA compliance -- immutability must be mechanically enforced. The CI/CD system serves as the enforcement layer, using cryptographic hashes to detect unauthorized modifications to locked version artifacts. The version lock registry follows the same append-only principle as the event store (REQ-p00004-B, REQ-p00004-P): entries are added but never modified or removed, providing a tamper-evident chain of version provenance.

Each questionnaire version exists as a self-contained set of artifacts (widget code for GUI, content bundles for content, JSON Schema definitions for schema). Locking a version computes a deterministic cryptographic hash over its artifacts, recording the hash in a registry file. The CI system validates both that locked artifacts remain unchanged and that the registry itself has not been tampered with, using the branch-protected baseline as the trust anchor.

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
