# Compliance Operations Requirements (Roadmap)

**Audience**: Operations team, Compliance team
**Purpose**: Compliance-specific operational requirements deferred to roadmap during spec refactor
**Status**: Draft
**Version**: 1.0.0

---

## Requirements

# REQ-o00049: Artifact Retention and Archival

**Level**: Ops | **Status**: Draft | **Implements**: o80020

## Rationale

This requirement establishes the operational framework for artifact retention and archival to ensure FDA 21 CFR Part 11 compliance. The FDA mandates a minimum 7-year retention period for production artifacts to support regulatory audits and inspection readiness. The requirement defines a tiered storage strategy optimizing cost versus access requirements, with hot storage for recent artifacts requiring frequent access and cold storage for long-term retention. Different retention periods for production, staging, and development environments reflect the regulatory significance of each environment. Lifecycle management policies automate the transition between storage tiers and enforce deletion schedules, reducing operational overhead while maintaining compliance. Integrity verification and immutability protections ensure that archived artifacts remain tamper-evident throughout their retention period.

## Assertions

A. The system SHALL retain production artifacts for a minimum of 7 years.

B. The system SHALL retain staging artifacts for a minimum of 30 days.

C. The system SHALL retain development artifacts for a minimum of 7 days.

D. The system SHALL retain audit trail records for a minimum of 7 years.

E. The system SHALL retain deployment logs for a minimum of 7 years.

F. The system SHALL retain incident records for a minimum of 7 years.

G. The system SHALL archive source code artifacts including all Git repository commits.

H. The system SHALL archive build artifacts including compiled binaries and container images.

I. The system SHALL archive deployment records including deployment logs, approvals, and timestamps.

J. The system SHALL archive test results including validation reports (IQ/OQ/PQ) and test logs.

K. The system SHALL archive audit trail artifacts including database audit records and access logs.

L. The system SHALL archive incident records including incident tickets, post-mortems, and resolutions.

M. The system SHALL archive database backups including full backups and migration scripts.

N. The system SHALL store production artifacts from the last 90 days in hot storage with immediate retrieval capability.

O. The system SHALL store production artifacts from 91 days to 7 years in cold storage.

P. The system SHALL transition production artifacts from hot storage to cold storage automatically after 90 days.

Q. The system SHALL delete production artifacts automatically after 7 years unless subject to manual retention extension.

R. The system SHALL enable object retention policy (immutable) for production artifacts.

S. The system SHALL transition staging artifacts to Nearline storage after 7 days.

T. The system SHALL delete staging artifacts automatically after 30 days.

U. The system SHALL delete development artifacts automatically after 7 days.

V. The system SHALL verify archival integrity through monthly checksum validation for all storage tiers.

W. The system SHALL support manual retention extension for production artifacts subject to regulatory holds.

X. Cloud Storage buckets SHALL be created with encryption enabled.

Y. Lifecycle policies SHALL be configured for all storage buckets.

Z. Retrieval procedures SHALL be documented for all storage classes.

*End* *Artifact Retention and Archival* | **Hash**: 9bbb7f6e
---

# REQ-o00051: Change Control and Audit Trail

**Level**: Ops | **Status**: Draft | **Implements**: o80030

## Rationale

This requirement ensures comprehensive change control and audit trails across all layers of the clinical trial system to meet FDA 21 CFR Part 11 compliance. The requirement addresses infrastructure changes, code modifications, configuration updates, and deployment activities. The 7-year retention period aligns with FDA regulatory requirements for clinical trial record retention. Audit trails enable investigation of system changes, support regulatory inspections, and provide tamper-evident evidence of who made what changes and when. The requirement implements parent requirement p00010 which establishes overall audit trail and data integrity obligations.

## Assertions

A. The system SHALL maintain a change control audit trail for all infrastructure, code, configuration, and deployment changes.

B. The system SHALL log all Terraform changes with author identity, timestamp, and reason for change.

C. The system SHALL retain Terraform state versions for a minimum of 7 years using GCS backend storage.

D. The system SHALL implement infrastructure drift detection and generate alerts when drift is detected.

E. The system SHALL require approval before applying Terraform changes to production environments.

F. The system SHALL link all code commits to requirements via pre-commit hook enforcement.

G. The system SHALL require all code commits to be signed with GPG keys.

H. The system SHALL require pull request approvals from 2 reviewers before merging to production branches.

I. The system SHALL retain merge commit history indefinitely in Git repositories.

J. The system SHALL log all Doppler secrets changes with audit trail information.

K. The system SHALL log all feature flag changes.

L. The system SHALL require approval for environment configuration changes.

M. The system SHALL log every deployment with deployer identity, timestamp in UTC, version deployed, approval records, and deployment outcome.

N. Deployment outcome records SHALL indicate success, failure, or rollback status.

O. The system SHALL archive deployment logs for a minimum of 7 years.

P. Audit logging SHALL be configured and verified during Installation Qualification (IQ).

Q. Audit record capture SHALL be verified during Operational Qualification (OQ).

R. Seven-year retention of audit records SHALL be verified during Performance Qualification (PQ).

S. Terraform state versioning SHALL be enabled on GCS backend.

T. Git commit signing SHALL be enforced for all commits.

U. Doppler audit trail SHALL be enabled for all secret management operations.

*End* *Change Control and Audit Trail* | **Hash**: e9a92b1f
---

# REQ-o00066: Multi-Framework Compliance Automation

**Level**: Ops | **Status**: Draft | **Implements**: o80010, o80020, o80030

## Rationale

Small clinical trial teams lack resources to maintain separate compliance programs for FDA 21 CFR Part 11, SOC 2, ISO 27001, HIPAA, and GDPR. By implementing unified operational controls that satisfy overlapping requirements across multiple frameworks, the platform reduces operational burden while ensuring comprehensive regulatory coverage. This approach enables a single audit trail, evidence collection system, and set of security controls to serve multiple regulatory purposes simultaneously, making compliance feasible for resource-constrained organizations.

## Assertions

A. The platform SHALL implement automated compliance controls that satisfy overlapping requirements across FDA 21 CFR Part 11, SOC 2, ISO 27001, HIPAA, and GDPR.

B. Each operational control SHALL be mapped to all applicable framework requirements it satisfies.

C. The platform SHALL collect compliance evidence automatically for all implemented controls.

D. Compliance evidence SHALL be tagged by framework to enable selective export per regulatory requirement.

E. The platform SHALL maintain a unified audit trail that supports all regulatory framework needs simultaneously.

F. The platform SHALL provide cross-framework compliance reporting capabilities.

G. The platform SHALL perform automated gap analysis when new framework requirements are introduced.

H. The platform SHALL NOT implement duplicate controls for equivalent requirements across different frameworks.

I. The platform SHALL enable on-demand compliance status reporting for each individual framework.

J. The platform SHALL perform automated annual framework gap analysis.

K. Access control implementations SHALL satisfy FDA 21 CFR Part 11 §11.10(d), SOC 2 CC6.1, ISO 27001 A.9, HIPAA §164.312(a), and GDPR Article 32.

L. Audit trail implementations SHALL satisfy FDA 21 CFR Part 11 §11.10(e), SOC 2 CC7.2, ISO 27001 A.12.4, HIPAA §164.312(b), and GDPR Article 30.

M. Data integrity implementations SHALL satisfy FDA 21 CFR Part 11 §11.10(a), SOC 2 CC1.1, ISO 27001 A.12.2, HIPAA §164.312(c), and GDPR Article 5.

N. Encryption implementations SHALL satisfy FDA 21 CFR Part 11 §11.10(c), SOC 2 CC6.7, ISO 27001 A.10, HIPAA §164.312(e), and GDPR Article 32.

O. Incident response implementations SHALL satisfy FDA 21 CFR Part 11 §11.10(k), SOC 2 CC7.4, ISO 27001 A.16, HIPAA §164.308(a)(6), and GDPR Article 33.

*End* *Multi-Framework Compliance Automation* | **Hash**: 3088420e

---

# REQ-o00067: Automated Compliance Evidence Collection

**Level**: Ops | **Status**: Draft | **Implements**: o00066, o80020

## Rationale

Manual evidence collection for regulatory compliance is error-prone, time-consuming, and often leads to audit scrambles when evidence cannot be quickly located or is incomplete. Automated evidence collection ensures that compliance artifacts are continuously captured as a natural byproduct of system operations, making them always current, complete, and auditor-ready. This approach supports FDA 21 CFR Part 11 and other regulatory frameworks that require demonstrable control over electronic records and systems throughout their lifecycle. By eliminating manual intervention, the platform reduces compliance overhead while improving audit readiness and reducing the risk of missing critical evidence during regulatory inspections.

## Assertions

A. The platform SHALL automatically collect compliance evidence as a byproduct of normal system operations without manual intervention.

B. The platform SHALL timestamp all collected compliance evidence.

C. The platform SHALL archive all collected compliance evidence.

D. The platform SHALL capture system configuration snapshots on a daily basis.

E. The platform SHALL capture system configuration snapshots whenever configuration changes occur.

F. The platform SHALL capture access control reviews continuously.

G. The platform SHALL capture security scan results per-deployment.

H. The platform SHALL capture security scan results on a scheduled basis.

I. The platform SHALL capture change management records automatically from CI/CD processes.

J. The platform SHALL capture audit trail integrity verification results continuously.

K. The platform SHALL capture backup verification results for each backup operation.

L. The platform SHALL retain configuration evidence for a minimum of 7 years.

M. The platform SHALL retain access logs for a minimum of 7 years.

N. The platform SHALL retain security scan results for a minimum of 3 years.

O. The platform SHALL retain change records for the life of the product plus 7 years.

P. The platform SHALL retain audit verification records for the life of the product plus 7 years.

Q. The platform SHALL enable retrieval of evidence by date range.

R. The platform SHALL enable retrieval of evidence by control type.

S. The platform SHALL enable retrieval of evidence by regulatory framework.

T. The platform SHALL verify evidence integrity via cryptographic hash.

U. The platform SHALL export evidence in PDF format.

V. The platform SHALL export evidence in CSV format.

W. The platform SHALL export evidence in JSON format.

X. The platform SHALL generate automated alerts when evidence is missing.

*End* *Automated Compliance Evidence Collection* | **Hash**: 2f678f41
