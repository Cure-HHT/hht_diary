# REQ-d80201: Action Template — Create

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80004-R, REQ-p80004-AV, REQ-p80005-A, REQ-p80005-C, REQ-p80005-O

## Rationale

This template is instantiated once per user action that creates new data in the system (e.g., diary entry, questionnaire submission, device linking). Each instance inherits these assertions; individual assertions may be marked N/A where the action context makes them inapplicable. Coverage for this requirement is computed as the aggregate of all its instances.

## Assertions

A. The system SHALL record the identity of the actor performing the action.

B. The system SHALL capture the timestamp of the action at the time it occurs, not retrospectively.

C. The system SHALL capture data at the individual field level with metadata identifying the data source.

D. The system SHALL hash-chain the event into the immutable event store.

E. The system SHALL associate each data element with an authorized data originator (person, system, DHT, or EHR).

*End* *Action Template — Create* | **Hash**: 19640f37

---

# REQ-d80202: Action Template — Mutate

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80002-E, REQ-p80004-A, REQ-p80004-B, REQ-p80004-C, REQ-p80004-F, REQ-p80004-K, REQ-p80004-X, REQ-p80004-AJ, REQ-p80004-AK, REQ-p80004-AO, REQ-p80004-AQ, REQ-p80004-AS, REQ-p80004-AU, REQ-p80005-C, REQ-p80005-D, REQ-p80005-E, REQ-p80005-F, REQ-p80005-G, REQ-p80005-H

## Rationale

This template is instantiated once per user action that modifies or logically deletes existing data. It includes all Create template assertions plus additional obligations for change tracking. Each instance inherits these assertions; individual assertions may be marked N/A where the action context makes them inapplicable (e.g., "approval required" may be N/A for routine diary edits). Coverage is computed as the aggregate of all instances.

## Assertions

A. The system SHALL record the identity of the actor performing the action.

B. The system SHALL capture the timestamp of the action at the time it occurs, not retrospectively.

C. The system SHALL capture data at the individual field level with metadata identifying the data source.

D. The system SHALL hash-chain the event into the immutable event store.

E. The system SHALL record both the previous value and the new value for each changed field.

F. The system SHALL ensure that the modification does not obscure the original entry or any previously recorded information.

G. The system SHALL capture the reason for the change, where required by the action context.

H. The system SHALL ensure the correction is dated and explained where necessary.

I. The system SHALL ensure the change is attributable to the person or system making it, with corrections justified and supported by source records.

J. The system SHALL document approval of data changes, including investigator sign-off, where required by the action context.

K. The system SHALL ensure that if changes are made after an electronic signature has been applied, the changes are reflected in the audit trail and trigger re-signature requirements where applicable.

*End* *Action Template — Mutate* | **Hash**: cbb3cfd0

---

# REQ-d80203: Action Template — Sign

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80002-L, REQ-p80002-M, REQ-p80002-N, REQ-p80002-O, REQ-p80002-P, REQ-p80002-S, REQ-p80002-T

## Rationale

This template is instantiated once per user action that applies an electronic signature. Coverage is computed as the aggregate of all its instances.

## Assertions

A. The signed record SHALL contain the printed name of the signer.

B. The signed record SHALL contain the date and time when the signature was executed.

C. The signed record SHALL contain the meaning of the signature (such as review, approval, responsibility, or authorship).

D. The signer name, date/time, and meaning SHALL be included as part of any human-readable form of the electronic record.

E. The electronic signature SHALL be cryptographically linked to the signed record such that it cannot be excised, copied, or otherwise transferred.

F. The system SHALL execute the signing using the appropriate signature components based on session continuity (all components for first/non-continuous signing, at least one exclusive component for subsequent continuous-session signings).

G. The system SHALL ensure that any changes made to the record after signing are reflected in the audit trail.

*End* *Action Template — Sign* | **Hash**: 68120b67
