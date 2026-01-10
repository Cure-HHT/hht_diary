# System Operations Requirements

**Version**: 1.0
**Audience**: Operations (DevOps, Compliance Officers, System Administrators)
**Last Updated**: 2025-12-28
**Status**: Draft

> **See**: prd-system.md for platform requirements
> **See**: prd-clinical-trials.md for compliance requirements
> **See**: ops-deployment.md for deployment procedures
> **See**: ops-monitoring-observability.md for monitoring details
> **See**: ops-SLA.md for service level agreements

---

## Executive Summary

Operational requirements for the Clinical Trial Diary Platform ensuring FDA 21 CFR Part 11 compliance, SOC 2 controls, ISO 27001 alignment, HIPAA protections, and GDPR compliance. Designed for a small team leveraging automation to maintain regulatory compliance without operational bloat.

**Operating Philosophy**:
- Automation-first: Manual processes are compliance risks
- Evidence-driven: Every compliance claim backed by auditable artifacts
- Fail-safe defaults: Systems default to secure, compliant states
- Continuous validation: Compliance verified continuously, not periodically

---

# REQ-o00065: Clinical Trial Diary Platform Operations

**Level**: Ops | **Status**: Draft | **Implements**: p00044

## Rationale

This requirement establishes the operational framework for maintaining FDA 21 CFR Part 11 compliance in a clinical trial platform with minimal manual intervention. It recognizes that small operational teams cannot manually verify compliance across all platform components, so compliance must be embedded into automated operations. This is the operational counterpart to REQ-p00044 (platform definition), ensuring that the platform's design for compliance is realized through operational practices. The requirement focuses on automation, continuous monitoring, and pre-generated audit evidence to maintain regulatory readiness without requiring a large staff.

## Assertions

A. The platform SHALL operate all components (mobile app, portals, database, services) within compliance boundaries.
B. The platform SHALL generate compliance evidence automatically through normal operations.
C. The platform SHALL execute automated compliance checks on every deployment.
D. The platform SHALL maintain compliance dashboards reflecting real-time system state.
E. The platform SHALL provide exportable audit evidence on demand without per-audit assembly.
F. The platform SHALL enforce change control processes via automation.
G. The platform SHALL maintain continuous audit readiness.
H. The platform SHALL document incident response procedures.
I. The platform SHALL test incident response procedures quarterly.
J. Routine compliance maintenance SHALL require zero manual steps.

*End* *Clinical Trial Diary Platform Operations* | **Hash**: bfc2940e

---

## Compliance Framework Operations

# REQ-o00066: Multi-Framework Compliance Automation

**Level**: Ops | **Status**: Draft | **Implements**: p00010

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

*End* *Multi-Framework Compliance Automation* | **Hash**: 567513fa

---

# REQ-o00067: Automated Compliance Evidence Collection

**Level**: Ops | **Status**: Draft | **Implements**: p00010, o00066

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

*End* *Automated Compliance Evidence Collection* | **Hash**: 78c147a2

---

## Access Control Operations

# REQ-o00068: Automated Access Review

**Level**: Ops | **Status**: Draft | **Implements**: p00005

## Rationale

Traditional quarterly access reviews create a reactive compliance posture where access violations may persist for months before detection. This requirement establishes continuous automated monitoring that detects access anomalies in real-time, transforming the audit burden from exhaustive manual reviews to exception-based investigation. By continuously comparing assigned versus used permissions and identifying patterns like dormant accounts or privilege escalation, the system provides timely alerts while maintaining exportable evidence for regulatory auditors. This approach aligns with modern security operations practices and reduces the operational overhead of compliance while improving detection speed.

## Assertions

A. The system SHALL automatically review user access rights continuously by comparing assigned permissions against used permissions.
B. The system SHALL validate user access rights against role requirements.
C. The system SHALL flag access anomalies for human review.
D. The system SHALL detect dormant accounts that have had no activity for more than 90 days.
E. The system SHALL identify privilege escalation patterns.
F. The system SHALL detect cross-sponsor access violations.
G. The system SHALL detect orphaned accounts that have no associated identity.
H. The system SHALL flag unused privileges that have not been used for 30 days.
I. The system SHALL flag dormant accounts that have had no login activity for 90 days.
J. The system SHALL flag any same-day privilege elevation as privilege escalation.
K. The system SHALL flag any cross-sponsor access attempt with zero tolerance.
L. The system SHALL detect access anomalies within 24 hours of occurrence.
M. The system SHALL generate automated access reports on a weekly basis.
N. The system SHALL trigger dormant account alerts within 24 hours of the account reaching the dormant threshold.
O. The system SHALL provide exportable access review evidence in a format suitable for auditors.
P. The system SHALL maintain a false positive rate of less than 5% for access anomaly detection.

*End* *Automated Access Review* | **Hash**: 2b4f314b

---

## Data Protection Operations

# REQ-o00069: Encryption Verification

**Level**: Ops | **Status**: Draft | **Implements**: p00017

## Rationale

This requirement establishes continuous automated verification of encryption mechanisms to ensure regulatory compliance with FDA 21 CFR Part 11 and data protection standards. While encryption configuration is standard practice, active verification confirms that encryption remains functional throughout system operations. This addresses the gap between configured security controls and operational reality, particularly critical for clinical trial systems handling protected health information (PHI). The verification regime covers all encryption domains: transport layer security for data in transit, database-level encryption for data at rest, backup protection, and mobile device offline storage. Different verification frequencies reflect the varying risk profiles and change rates of each encryption domain.

## Assertions

A. The system SHALL continuously verify encryption of data at rest and in transit through automated checks.
B. The system SHALL immediately escalate any encryption failures detected during verification.
C. The system SHALL monitor TLS certificate validity including expiration and revocation status.
D. The system SHALL verify database encryption status for Cloud SQL instances.
E. The system SHALL verify encryption of backup files.
F. The system SHALL verify encryption of client-server communications.
G. The system SHALL verify encryption of offline queue data on mobile devices.
H. TLS certificate verification SHALL execute on an hourly schedule.
I. Database encryption verification SHALL execute on a daily schedule.
J. Backup encryption verification SHALL execute for each backup operation.
K. Communication encryption verification SHALL execute for each connection establishment.
L. Mobile device encryption verification SHALL execute for each synchronization operation.
M. The system SHALL generate alerts for TLS certificate expiration 30 days in advance.
N. Encryption verification failures SHALL block deployment operations.
O. The system SHALL log all unencrypted data transmission attempts.
P. The system SHALL block all unencrypted data transmission attempts.
Q. The system SHALL include encryption status in the compliance dashboard.
R. The system SHALL automatically generate a monthly encryption compliance report.

*End* *Encryption Verification* | **Hash**: 0f8caa4c

---

# REQ-o00070: Data Residency Enforcement

**Level**: Ops | **Status**: Draft | **Implements**: p00001

## Rationale

Data residency violations create regulatory exposure and can invalidate clinical trials. Infrastructure-level enforcement prevents accidental data sovereignty violations by ensuring clinical data remains within approved geographic boundaries. This requirement supports GDPR data localization requirements for EU participants and enables sponsor-specific residency configurations to meet varying regulatory obligations across jurisdictions.

## Assertions

A. The system SHALL enforce data residency requirements through infrastructure configuration.
B. The system SHALL restrict cloud resources to sponsor-approved geographic regions via IAM policies.
C. The system SHALL automatically detect cross-region data transfer attempts.
D. The system SHALL support sponsor-specific residency configuration.
E. The system SHALL enforce GDPR data localization for EU participants.
F. The system SHALL verify that backup storage remains within approved geographic regions.
G. The system SHALL support US-only residency configuration restricting data to US regions.
H. The system SHALL support EU-only residency configuration restricting data to EU regions.
I. The system SHALL support global residency configuration with data replication across approved regions.
J. The system SHALL block cross-region data transfers at the infrastructure level.
K. The system SHALL generate immediate alerts when data residency violations are attempted.
L. Infrastructure logs SHALL enable audit verification of residency compliance.
M. The system SHALL generate an annual residency verification report.

*End* *Data Residency Enforcement* | **Hash**: 63dab109

---

## Incident Management Operations

# REQ-o00071: Automated Incident Detection

**Level**: Ops | **Status**: Draft | **Implements**: p01022

## Rationale

Regulatory compliance and security best practices require timely detection and response to security incidents. Manual incident detection introduces delays that can exacerbate breaches and fails to meet FDA expectations for continuous monitoring of electronic records systems. Automated detection provides evidence of proactive security monitoring required during regulatory audits and ensures rapid response to potential 21 CFR Part 11 violations such as audit trail tampering or unauthorized access attempts.

## Assertions

A. The system SHALL automatically detect authentication anomalies including failed login attempts and unusual authentication patterns.
B. The system SHALL automatically detect authorization violations including access attempts that exceed granted permissions.
C. The system SHALL automatically detect data integrity anomalies including unexpected or unauthorized data modifications.
D. The system SHALL automatically detect system availability degradation events.
E. The system SHALL automatically detect audit trail tampering attempts.
F. The system SHALL automatically classify incidents as P1 (Critical) severity when data breach indicators or audit trail compromise are detected.
G. The system SHALL automatically classify incidents as P2 (High) severity when authentication system compromise or data integrity violations are detected.
H. The system SHALL automatically classify incidents as P3 (Medium) severity when access control violations or encryption failures are detected.
I. The system SHALL automatically classify incidents as P4 (Low) severity when policy violations or anomalous but non-threatening activity are detected.
J. The system SHALL detect and classify P1 and P2 severity incidents within 5 minutes of occurrence.
K. The system SHALL maintain a false positive rate of less than 10% for automatically classified incidents.
L. The system SHALL automatically construct a timeline for each detected incident.
M. The system SHALL automatically initiate containment actions for defined incident scenarios.
N. The system SHALL automatically preserve all evidence associated with detected incidents.

*End* *Automated Incident Detection* | **Hash**: 66296f8a

---

# REQ-o00072: Regulatory Breach Notification

**Level**: Ops | **Status**: Draft | **Implements**: p01033

## Rationale

Regulatory frameworks impose strict deadlines for breach notifications, with penalties for non-compliance that compound the original breach violation. HIPAA requires notification within 60 days to HHS and affected individuals, while GDPR mandates reporting to supervisory authorities within 72 hours. FDA notification requirements vary based on whether the breach affects trial integrity. Automated workflows reduce human error in deadline tracking and ensure consistent documentation for regulatory audits. This requirement supports REQ-p01033 by operationalizing breach response procedures.

## Assertions

A. The system SHALL automatically assess breach severity within 1 hour of breach detection.
B. The system SHALL automatically calculate regulatory notification deadlines based on applicable frameworks (HIPAA: 60 days, GDPR: 72 hours, FDA: as specified, Sponsor SLA: per contract).
C. The system SHALL generate notification templates populated with incident details for identified breaches.
D. The system SHALL escalate breach notifications to the designated compliance officer.
E. The system SHALL track notification status for all identified breaches.
F. The system SHALL generate daily alerts for pending notification deadlines until notification is marked complete.
G. The system SHALL archive notification evidence for regulatory audit purposes.
H. The system SHALL automatically initiate post-breach analysis workflows upon breach identification.
I. The system SHALL identify data breaches requiring regulatory notification based on severity assessment.
J. The system SHALL document all breach notification activities with timestamp and user attribution.
K. Notification templates SHALL include recipient information appropriate to the regulatory framework (HHS and affected individuals for HIPAA, supervisory authority for GDPR, FDA for trial integrity impacts, sponsor compliance team per contract).

*End* *Regulatory Breach Notification* | **Hash**: 71f2357b

---

## Change Management Operations

# REQ-o00073: Automated Change Control

**Level**: Ops | **Status**: Draft | **Implements**: o00051

## Rationale

Manual change tracking is error-prone and creates compliance gaps in regulated clinical trial systems. FDA 21 CFR Part 11 requires complete, tamper-evident records of all system modifications. CI/CD-integrated change control ensures every change is automatically tracked, tested, and approved by design, eliminating human error in the change management process. This requirement establishes the automation framework for enforcing approval workflows, testing gates, and audit trail generation across different change categories, with controls scaled appropriately to the risk level of each change type.

## Assertions

A. The system SHALL control all changes through automated CI/CD pipelines.
B. The CI/CD pipeline SHALL enforce approval workflows before deployment.
C. The CI/CD pipeline SHALL enforce testing requirements before deployment.
D. The CI/CD pipeline SHALL generate audit trails for all changes without manual tracking.
E. The system SHALL enforce required approvals before deployment based on environment-specific configuration.
F. The system SHALL execute automated tests before promoting changes to the next environment.
G. The system SHALL require compliance scan passage before production deployment.
H. The system SHALL automatically roll back deployments upon failure.
I. The system SHALL automatically generate change records from CI/CD metadata.
J. The system SHALL auto-approve security patches while requiring testing and compliance scans.
K. The system SHALL require 1 approval for bug fixes before deployment.
L. The system SHALL require 2 approvals for feature changes before deployment.
M. The system SHALL require 2 approvals plus DBA approval for database migrations.
N. The system SHALL require manual compliance review in addition to automated scans for database migrations.
O. The system SHALL require 2 approvals for infrastructure changes before deployment.
P. The system SHALL require manual compliance review in addition to automated scans for infrastructure changes.
Q. The system SHALL block deployment of any changes attempted outside the CI/CD pipeline.
R. Change records SHALL include approver identity, timestamp, and scope of change.
S. The system SHALL block deployment of unapproved changes.
T. The system SHALL provide exportable change audit trails for compliance review.
U. The system SHALL document the emergency change process.
V. Emergency changes SHALL be auditable through the same audit trail mechanisms.

*End* *Automated Change Control* | **Hash**: 55aac77d

---

## Backup and Recovery Operations

# REQ-o00074: Automated Backup Verification

**Level**: Ops | **Status**: Draft | **Implements**: o00008

## Rationale

Database backups are a critical component of disaster recovery and business continuity for clinical trial systems. Under FDA 21 CFR Part 11, organizations must ensure the ability to restore electronic records in case of system failure. However, unverified backups create a false sense of security—backup processes may complete successfully while producing corrupted or incomplete data. This requirement establishes a comprehensive verification regime that validates not just backup completion, but actual restorability through testing. The multi-layered approach (checksums, restore tests, point-in-time recovery) ensures that recovery capabilities are validated through evidence rather than assumed, providing auditable compliance evidence that the organization can actually recover from various failure scenarios within acceptable time windows.

## Assertions

A. The system SHALL automatically verify all database backups for integrity and restorability.
B. The system SHALL record all backup verification results as compliance evidence.
C. The system SHALL perform backup completion verification daily within 1 hour of backup completion.
D. The system SHALL perform backup integrity checks via checksum daily within 4 hours of backup completion.
E. The system SHALL perform restore tests to an isolated environment weekly on an automated basis.
F. The system SHALL perform point-in-time recovery tests monthly.
G. The system SHALL verify cross-region backup replication daily.
H. The system SHALL send alerts within 1 hour when backup verification failures occur.
I. The system SHALL archive weekly restore test results as compliance evidence.
J. The system SHALL verify backup integrity using independent checksums.
K. The system SHALL measure recovery time for all restore tests.
L. The system SHALL track measured recovery times against Recovery Time Objective (RTO).
M. The system SHALL include backup verification status in the compliance dashboard.
N. The system SHALL notify the compliance officer when monthly point-in-time recovery tests are performed.
O. The system SHALL conduct quarterly disaster recovery drills with documented results.

*End* *Automated Backup Verification* | **Hash**: cf3ee0ab

---

## Vendor and Third-Party Operations

# REQ-o00075: Third-Party Security Assessment

**Level**: Ops | **Status**: Draft | **Implements**: p00010

## Rationale

Third-party services that handle or process platform data represent an extension of the platform's security perimeter. Under FDA 21 CFR Part 11 and data protection regulations, the platform must ensure that vendors maintain appropriate security controls and certifications. This requirement establishes the framework for ongoing vendor security assessment to ensure continuous compliance without relying on manual tracking. Annual reassessment and change-triggered reviews ensure that vendor security posture remains acceptable throughout the vendor relationship lifecycle.

## Assertions

A. The platform SHALL undergo security assessment for all third-party services integrated with the platform.
B. Third-party security assessments SHALL be reassessed annually.
C. Third-party security assessments SHALL be reassessed upon significant changes to the third-party service.
D. Assessment results for third-party services SHALL be tracked.
E. Third-party assessments SHALL include SOC 2 Type II report review for all data processors.
F. Third-party assessments SHALL include data processing agreement compliance verification.
G. Third-party assessments SHALL include security questionnaire completion.
H. Third-party assessments SHALL include penetration test result review where applicable.
I. Third-party assessments SHALL include incident notification capability verification.
J. GCP infrastructure services SHALL be assessed annually and maintain SOC 2, ISO 27001, and HIPAA BAA certifications.
K. Doppler secrets management services SHALL be assessed annually and maintain SOC 2 certification.
L. Identity Platform authentication services SHALL be assessed annually and maintain SOC 2 and ISO 27001 certifications.
M. Linear issue tracking services SHALL be assessed annually and maintain SOC 2 certification.
N. All third-party services SHALL be documented with their current security status.
O. The platform SHALL generate assessment expiration alerts 60 days in advance.
P. The platform SHALL block new integrations for third-party services with expired assessments.
Q. Third-party incident notification capabilities SHALL be tested annually.
R. Vendor security status SHALL be visible in the compliance dashboard.

*End* *Third-Party Security Assessment* | **Hash**: 372a4c1e

---

## Operational Automation Summary

**Automation Philosophy**: If a compliance control requires human intervention to function, it will eventually fail. All controls designed for continuous automated operation with human oversight for exceptions only.

**Key Automation Points**:
1. Evidence collection - automatic, continuous
2. Access review - automatic, exception-based alerts
3. Change control - CI/CD integrated, approval-gated
4. Incident detection - monitoring-driven, auto-classified
5. Backup verification - scheduled, tested, documented
6. Compliance reporting - on-demand, pre-generated

**Human Oversight Required**:
- Exception approval (access anomalies, emergency changes)
- Incident response decisions (beyond automated containment)
- Quarterly compliance review and attestation
- Annual framework gap analysis review
- Audit response and explanation

---

## References

- **Platform Definition**: prd-system.md
- **Compliance Requirements**: prd-clinical-trials.md
- **Deployment Operations**: ops-deployment.md
- **Monitoring**: ops-monitoring-observability.md
- **SLA Operations**: ops-SLA.md
- **Security Operations**: ops-security.md
- **Database Operations**: ops-database-setup.md

---

## Change History

| Version | Date | Changes | Author |
| --- | --- | --- | --- |
| 1.0 | 2025-12-12 | Initial document | Claude |
