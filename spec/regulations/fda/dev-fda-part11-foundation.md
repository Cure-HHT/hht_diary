# REQ-d80101: Tamper-Evident Append-Only Event Store

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80002-D, REQ-p80002-E, REQ-p80004-A, REQ-p80004-B, REQ-p80004-O, REQ-p80004-Q, REQ-p80004-Z, REQ-p80005-D, REQ-p80005-M

## Rationale

Clinical trial data integrity depends on an immutable record of all events. An append-only event store with cryptographic chaining provides tamper evidence, prevents silent data loss, and ensures that corrections are always visible as new events rather than overwrites. This architecture directly supports the regulatory expectation that changes never obscure original entries.

## Assertions

A. The event store SHALL be append-only; no physical deletes or in-place updates of event records SHALL be permitted at the application or database level.

B. Each event record SHALL include a cryptographic hash that chains to the previous event, forming a verifiable sequence that makes tampering, insertion, or reordering detectable.

C. The system SHALL record corrections as new compensating events rather than modifications to existing events, preserving full data history visibility.

D. The system SHALL capture changes at the individual field level (not at the page or form level), recording both the previous and current values.

E. The system SHALL prevent direct modification of data in the database; all changes SHALL go through the application layer with audit trail capture.

*End* *Tamper-Evident Append-Only Event Store* | **Hash**: aaebac92

---

# REQ-d80102: System Clock and Timestamp Infrastructure

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80002-D, REQ-p80004-J, REQ-p80004-S, REQ-p80004-AA, REQ-p80005-O

## Rationale

Reliable timestamps are foundational to audit trail integrity. A server-authoritative clock prevents client-side manipulation, UTC removes time-zone ambiguity, and capturing both observation and storage times supports the contemporaneous recording principle required by GCP and EMA guidelines.

## Assertions

A. The system SHALL automatically generate timestamps for all data entries, modifications, deletions, and data transfers using a server-authoritative clock source, preventing client-side timestamp manipulation.

B. All timestamps SHALL be recorded in an unambiguous format using Coordinated Universal Time (UTC).

C. The system SHALL capture both the time point of observation (when data was originally recorded at the device) and the time point of storage (when it was persisted to the event store) as distinct metadata elements.

*End* *System Clock and Timestamp Infrastructure* | **Hash**: 53a310b8

---

# REQ-d80103: Audit Trail Storage, Protection, and Non-Disablement

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80002-D, REQ-p80002-F, REQ-p80004-H, REQ-p80004-U, REQ-p80004-V, REQ-p80004-M, REQ-p80004-Q, REQ-p80005-J, REQ-p80005-M, REQ-p80005-N

## Rationale

Audit trails are only trustworthy if they cannot be tampered with, silently disabled, or separated from the data they describe. Co-locating audit data with operational records, protecting it at the infrastructure level, and ensuring automatic generation without user intervention provides defense in depth against both accidental and deliberate interference.

## Assertions

A. Audit trails SHALL be stored within the system itself, co-located with the data they describe.

B. Audit trail entries SHALL be protected against change, deletion, and access modification at the infrastructure level.

C. The audit trail SHALL NOT be capable of being disabled or deactivated by normal users; if an administrative user deactivates an audit trail component, the system SHALL automatically create a log entry recording this action and the responsible individual.

D. Audit trail documentation SHALL be retained for a period at least as long as that required for the subject electronic records.

E. The system SHALL generate audit trail entries automatically without user intervention.

F. The system SHALL maintain audit trail data separately from operational data to ensure independence.

G. The system SHALL audit all access to audit trail data itself.

*End* *Audit Trail Storage, Protection, and Non-Disablement* | **Hash**: 5f349356

---

# REQ-d80104: Audit Trail Export, Inspection, and Interpretability

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80002-A, REQ-p80004-I, REQ-p80004-W, REQ-p80004-AB, REQ-p80004-AC, REQ-p80005-K, REQ-p80005-L, REQ-p80005-P, REQ-p80005-V

## Rationale

Regulatory agencies, monitors, auditors, and inspectors need to review audit trail data in multiple formats and contexts. Providing both human-readable and electronic export, real-time data-point-level visibility, and dynamic export for pattern analysis enables the full range of inspection and oversight activities expected during clinical trials.

## Assertions

A. The system SHALL generate accurate and complete copies of records (including audit trails and metadata) in both human-readable and electronic form suitable for inspection, review, and copying by regulatory agencies.

B. The system SHALL support export of the entire audit trail as a dynamic data file to allow identification of systematic patterns or concerns across trial participants, sites, and other dimensions.

C. Audit trails SHALL be visible at the data-point level in the live system, enabling real-time review of change history for any individual data element.

D. Audit trails and logs SHALL be interpretable and able to support review by monitors, auditors, and inspectors.

E. The system SHALL provide direct access to source records, including audit trails, for investigators, monitors, auditors, and inspectors, without compromising participant confidentiality.

*End* *Audit Trail Export, Inspection, and Interpretability* | **Hash**: 98b18618

---

# REQ-d80105: Blinding Protection in Audit Trails

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80004-AF, REQ-p80004-AG, REQ-p80005-S, REQ-p80005-T

## Rationale

Clinical trial blinding is a critical control for reducing bias. Audit trails, by their nature, record detailed change history that could inadvertently reveal treatment assignments. The system must enforce blinding boundaries across all data access pathways, including audit trail views, exports, and query results.

## Assertions

A. The system SHALL ensure that information that could compromise study blinding does not appear in audit trail views accessible to blinded users.

B. The system SHALL maintain access logs (including username and user role) for systems containing critical unblinded data, with these logs retained throughout the study duration.

C. The system SHALL implement access controls that prevent blinded users from accessing unblinding information through any system pathway, including audit trail review, data export, and query interfaces.

*End* *Blinding Protection in Audit Trails* | **Hash**: 43c72c48

---

# REQ-d80106: Data Retention, Migration, and Decommissioning Infrastructure

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80002-B, REQ-p80004-AD, REQ-p80004-AE, REQ-p80005-R, REQ-p80005-U, REQ-p80005-V

## Rationale

Clinical trial data must remain accessible, intact, and interpretable for years or decades after a study concludes. Data migration, system decommissioning, and software upgrades all pose risks to data integrity if the link between data, metadata, and audit trails is broken. Infrastructure-level safeguards ensure continuity across the full system lifecycle.

## Assertions

A. The system SHALL ensure that data, contextual information (metadata), and audit trails are not separated during data migration; the link between data and metadata SHALL always be maintained.

B. Upon database or system decommissioning, the system SHALL ensure that archived formats provide the possibility to restore databases including dynamic functionality and all relevant metadata.

C. The system SHALL maintain backup and recovery procedures to protect against data loss, including backups stored in a secure location separate from the original records.

D. The system SHALL ensure that system changes (including software upgrades, security patches, equipment replacements) do not adversely affect the traceability, authenticity, or integrity of new or existing data.

*End* *Data Retention, Migration, and Decommissioning Infrastructure* | **Hash**: f194cb4e

---

# REQ-d80107: ALCOA+ System-Level Properties

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80004-R, REQ-p80005-A, REQ-p80005-B

## Rationale

ALCOA+ principles (Attributable, Legible, Contemporaneous, Original, Accurate, Complete, Consistent, Enduring, Available) are the foundational data integrity framework for clinical trials. At the system level, these principles translate into architectural properties: immutable originals, gap detection in event sequences, consistent data formats, and durable, accessible record storage.

## Assertions

A. The system SHALL preserve the original record as first captured, ensuring that the event store retains the initial entry as an immutable event and that all subsequent changes are recorded as separate events.

B. The system SHALL ensure that no data silently fails to persist; every accepted submission SHALL result in a durable event record, and the system SHALL detect and report any gap in the event sequence.

C. The system SHALL enforce data format consistency across all records, including consistent timestamp formats, identifier schemes, and metadata structures.

D. The system SHALL ensure that electronic records are preserved in a durable format that remains accessible and interpretable throughout the required retention period.

E. The system SHALL ensure that electronic records, including audit trails and metadata, are available for retrieval and inspection throughout the applicable retention period.

*End* *ALCOA+ System-Level Properties* | **Hash**: eafbf63d

---

# REQ-d80108: Authentication Infrastructure

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80002-Q, REQ-p80002-R, REQ-p80002-V, REQ-p80002-W, REQ-p80002-X, REQ-p80002-Y, REQ-p80002-Z, REQ-p80002-AA

## Rationale

FDA 21 CFR Part 11 requires electronic signatures to be trustworthy, unique, and protected against unauthorized use. The authentication infrastructure provides the technical foundation for identity verification, credential management, and detection of unauthorized access attempts that underpin all signature and access control functions.

## Assertions

A. Electronic signatures that are not based upon biometrics SHALL employ at least two distinct identification components.

B. Each electronic signature SHALL be unique to one individual and SHALL NOT be reused by, or reassigned to, anyone else.

C. The system SHALL maintain the uniqueness of each combined identification code and password.

D. The system SHALL ensure that identification code and password issuances are periodically checked, recalled, or revised.

E. The system SHALL follow loss management procedures to electronically deauthorize lost, stolen, missing, or otherwise potentially compromised tokens, cards, and other devices, and to issue replacements using suitable controls.

F. The system SHALL use transaction safeguards to prevent unauthorized use of passwords and/or identification codes, and to detect and report in an immediate and urgent manner any attempts at their unauthorized use.

G. The system SHALL support initial and periodic testing of authentication devices to ensure they function properly and have not been altered.

*End* *Authentication Infrastructure* | **Hash**: 2b5dd722

---

# REQ-d80109: Session Management and Access Control Infrastructure

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80002-C, REQ-p80002-H, REQ-p80002-S, REQ-p80002-T, REQ-p80002-U, REQ-p80004-E

## Rationale

Access controls and session management are the gatekeepers of system integrity. Limiting access to authorized individuals, enforcing session timeouts, tracking login attempts, and maintaining user account logs ensures that all system interactions are attributable and that unauthorized access is detected and prevented.

## Assertions

A. The system SHALL limit system access to authorized individuals through logical access controls.

B. The system SHALL use authority checks to ensure that only authorized individuals can use the system, electronically sign a record, or alter a record.

C. The system SHALL implement automatic session timeout for idle periods and require re-authentication.

D. The system SHALL limit the number of login attempts and record unauthorized login attempts.

E. The system SHALL ensure that individuals work only under their own usernames and do not share login information.

F. The system SHALL maintain logs of user account creation, changes to user roles and permissions, and user access.

G. When an individual executes a series of signings during a single continuous session, the first signing SHALL use all electronic signature components; subsequent signings SHALL use at least one component executable only by that individual.

H. The system SHALL provide the capability to immediately disable user accounts in response to security incidents.

I. The system SHALL enforce separation of duties between user account administration and clinical data access.

J. The system SHALL differentiate between initial data entry and subsequent corrections in the audit trail.

*End* *Session Management and Access Control Infrastructure* | **Hash**: 97f29818

---

# REQ-d80110: Security Safeguards Infrastructure

**Level**: Dev | **Status**: Draft | **Refines**: REQ-p80005-Q, REQ-p80005-R

## Rationale

Data authenticity, integrity, and confidentiality must be protected both at rest and in transit. Security safeguards provide the technical controls that prevent unauthorized access, detect tampering, and ensure that data transfers preserve the complete audit chain. These safeguards work in concert with access controls and audit trails to form a comprehensive defense.

## Assertions

A. The system SHALL ensure the authenticity, integrity, and confidentiality of data at rest and in transit.

B. The system SHALL support data governance that includes control over both intentional and unintentional changes to data.

C. The system SHALL ensure that data transfers are pre-planned, validated, include audit trails, and are conducted in such a way that data is continuously accessible.

*End* *Security Safeguards Infrastructure* | **Hash**: 1a06d5c3
