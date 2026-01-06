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

**Level**: Ops | **Implements**: p00044 | **Status**: Draft

The Clinical Trial Diary Platform SHALL be operated with automated compliance controls, continuous monitoring, and documented procedures ensuring regulatory requirements are met without requiring large operational staff.

Platform operations SHALL ensure:
- All platform components (mobile app, portals, database, services) operate within compliance boundaries
- Compliance evidence generated automatically by platform operations
- Incident response procedures documented and tested
- Change control processes enforced via automation
- Audit readiness maintained continuously

**Rationale**: Operational complement to the platform definition (p00044). A small team cannot manually verify compliance - operations must be designed so compliance is an inherent property of normal system operation.

**Acceptance Criteria**:
- Automated compliance checks run on every deployment
- Compliance dashboards reflect real-time system state
- Audit evidence exportable on demand (not assembled per-audit)
- Zero manual steps required for routine compliance maintenance
- Incident response runbooks tested quarterly

*End* *Clinical Trial Diary Platform Operations* | **Hash**: 371ff818

---

## Compliance Framework Operations

# REQ-o00066: Multi-Framework Compliance Automation

**Level**: Ops | **Implements**: p00010 | **Status**: Draft

The platform SHALL implement automated compliance controls satisfying overlapping requirements across FDA 21 CFR Part 11, SOC 2, ISO 27001, HIPAA, and GDPR through unified operational processes.

Multi-framework compliance SHALL include:
- Single control implementation satisfying multiple frameworks
- Automated evidence collection mapped to framework requirements
- Unified audit trail supporting all regulatory needs
- Cross-framework compliance reporting
- Gap analysis automation for new framework requirements

**Framework Alignment Matrix**:

| Control Domain | 21 CFR Part 11 | SOC 2 | ISO 27001 | HIPAA | GDPR |
| -------------- | -------------- | ----- | --------- | ----- | ---- |
| Access Control | 11.10(d) | CC6.1 | A.9 | 164.312(a) | Art.32 |
| Audit Trail | 11.10(e) | CC7.2 | A.12.4 | 164.312(b) | Art.30 |
| Data Integrity | 11.10(a) | CC1.1 | A.12.2 | 164.312(c) | Art.5 |
| Encryption | 11.10(c) | CC6.7 | A.10 | 164.312(e) | Art.32 |
| Incident Response | 11.10(k) | CC7.4 | A.16 | 164.308(a)(6) | Art.33 |

**Rationale**: Small teams cannot maintain separate compliance programs for each framework. Unified controls reduce operational burden while ensuring comprehensive regulatory coverage.

**Acceptance Criteria**:
- Each operational control mapped to applicable framework requirements
- Compliance evidence tagged by framework for selective export
- Annual framework gap analysis automated
- No duplicate controls for equivalent requirements
- Compliance status reportable per-framework on demand

*End* *Multi-Framework Compliance Automation* | **Hash**: d148d026

---

# REQ-o00067: Automated Compliance Evidence Collection

**Level**: Ops | **Implements**: p00010, o00066 | **Status**: Draft

The platform SHALL automatically collect, timestamp, and archive compliance evidence as a byproduct of normal system operations, eliminating manual evidence gathering.

Evidence collection SHALL capture:
- System configuration snapshots (daily and on-change)
- Access control reviews (continuous)
- Security scan results (per-deployment and scheduled)
- Change management records (automated from CI/CD)
- Audit trail integrity verification (continuous)
- Backup verification results (per-backup)

**Evidence Retention**:
- Configuration evidence: 7 years minimum
- Access logs: 7 years minimum
- Security scans: 3 years
- Change records: Life of product + 7 years
- Audit verification: Life of product + 7 years

**Rationale**: Manual evidence collection is error-prone and creates audit scrambles. Automated collection ensures evidence is always current, complete, and auditor-ready.

**Acceptance Criteria**:
- Evidence collection requires zero manual intervention
- Evidence retrievable by date range, control type, or framework
- Evidence integrity verifiable via cryptographic hash
- Evidence export in regulatory-accepted formats (PDF, CSV, JSON)
- Missing evidence generates automated alerts

*End* *Automated Compliance Evidence Collection* | **Hash**: 040c6a7c

---

## Access Control Operations

# REQ-o00068: Automated Access Review

**Level**: Ops | **Implements**: p00005 | **Status**: Draft

User access rights SHALL be automatically reviewed and validated against role requirements, with anomalies flagged for human review rather than requiring manual access audits.

Automated access review SHALL include:
- Continuous comparison of assigned vs. used permissions
- Detection of dormant accounts (no activity > 90 days)
- Identification of privilege escalation patterns
- Cross-sponsor access violation detection
- Orphaned account detection (no associated identity)

**Alert Thresholds**:
- Unused privilege: 30 days without use
- Dormant account: 90 days without login
- Privilege escalation: Any same-day elevation
- Cross-sponsor access: Any attempt (zero tolerance)

**Rationale**: Quarterly manual access reviews are compliance theater. Continuous automated review detects issues in real-time and reduces audit burden to exception handling.

**Acceptance Criteria**:
- Access anomalies detected within 24 hours
- Weekly automated access reports generated
- Dormant account alerts trigger within 24 hours of threshold
- Access review evidence exportable for auditors
- False positive rate < 5%

TODO - this needs details on how alerts are managed.  They often pile up.

*End* *Automated Access Review* | **Hash**: f2b6b596

---

## Data Protection Operations

# REQ-o00069: Encryption Verification

**Level**: Ops | **Implements**: p00017 | **Status**: Draft

Encryption of data at rest and in transit SHALL be continuously verified through automated checks, with any encryption failures immediately escalated.

Encryption verification SHALL include:
- TLS certificate validity monitoring (expiration, revocation)
- Database encryption status verification (Cloud SQL)
- Backup encryption verification
- Client-server communication encryption verification
- Offline queue encryption verification (mobile devices)

**Verification Schedule**:
- TLS certificates: Hourly
- Database encryption: Daily
- Backup encryption: Per-backup
- Communication encryption: Per-connection
- Mobile encryption: Per-sync

**Rationale**: Encryption is assumed but rarely verified. Automated verification ensures encryption is actually functioning, not just configured.

**Acceptance Criteria**:
- TLS certificate expiration alerts 30 days in advance
- Encryption verification failures block deployments
- Unencrypted data transmission attempts logged and blocked
- Encryption status included in compliance dashboard
- Monthly encryption compliance report generated automatically

*End* *Encryption Verification* | **Hash**: c0f366df

---

# REQ-o00070: Data Residency Enforcement

**Level**: Ops | **Implements**: p00001 | **Status**: Draft

Data residency requirements SHALL be enforced through infrastructure configuration with automated verification that clinical data remains within approved geographic boundaries.

Data residency enforcement SHALL include:
- Cloud resource region restrictions via IAM policies
- Automated detection of cross-region data transfer attempts
- Sponsor-specific residency configuration
- GDPR data localization for EU participants
- Backup storage region verification

**Supported Residency Configurations**:
- US-only: Data restricted to US regions
TODO - this would violate GDPR for EU residents in the US
- EU-only: Data restricted to EU regions (GDPR)
- Global: Data replicated across approved regions

**Rationale**: Data residency violations create regulatory exposure. Infrastructure-level enforcement prevents accidental data sovereignty violations that could invalidate clinical trials.

**Acceptance Criteria**:
- Cross-region data transfer blocked at infrastructure level
- Data residency configurable per sponsor
- Residency compliance auditable via infrastructure logs
- Attempted violations generate immediate alerts
- Annual residency verification report generated

*End* *Data Residency Enforcement* | **Hash**: 4969d3b2

---

## Incident Management Operations

# REQ-o00071: Automated Incident Detection

**Level**: Ops | **Implements**: p01022 | **Status**: Draft

Security and compliance incidents SHALL be automatically detected through monitoring systems, with severity classification and initial response initiated without human intervention.

Automated detection SHALL cover:
- Authentication anomalies (failed logins, unusual patterns)
- Authorization violations (access attempts beyond permissions)
- Data integrity anomalies (unexpected modifications)
- System availability degradation
- Audit trail tampering attempts

**Severity Auto-Classification**:
- P1 (Critical): Data breach indicators, audit trail compromise
- P2 (High): Authentication system compromise, data integrity violation
- P3 (Medium): Access control violation, encryption failure
- P4 (Low): Policy violation, anomalous but non-threatening activity

**Rationale**: Manual incident detection delays response and may miss incidents entirely. Automated detection ensures rapid response and creates evidence of security monitoring for auditors.

**Acceptance Criteria**:
- Incident detection latency < 5 minutes for P1/P2
- False positive rate < 10% for auto-classified incidents
- Incident timeline automatically constructed
- Automated initial containment for defined scenarios
- Incident evidence preserved automatically

TODO - similar to the above, then what? Incidents need human management.

*End* *Automated Incident Detection* | **Hash**: 1b62574e

---

# REQ-o00072: Regulatory Breach Notification

**Level**: Ops | **Implements**: p01033 | **Status**: Draft

Data breaches requiring regulatory notification SHALL be identified, documented, and escalated through automated workflows ensuring notification deadlines are met.

Breach notification workflow SHALL include:
- Automated breach severity assessment
- Regulatory notification deadline calculation (HIPAA: 60 days, GDPR: 72 hours)
- Notification template generation with incident details
- Escalation to designated compliance officer
- Notification status tracking and deadline alerts

**Notification Requirements by Framework**:

| Framework | Deadline | Recipient |
| --------- | -------- | --------- |
| HIPAA | 60 days | HHS, affected individuals |
| GDPR | 72 hours | Supervisory authority |
| FDA | Varies | FDA (if affects trial integrity) |
| Sponsor SLA | Per contract | Sponsor compliance team |

**Rationale**: Missed breach notification deadlines create additional regulatory violations. Automated workflows ensure deadlines are tracked and escalated appropriately.

**Acceptance Criteria**:
- Breach severity auto-assessed within 1 hour of detection
- Notification deadlines calculated automatically
- Daily deadline alerts until notification complete
- Notification evidence archived for audit
- Post-breach analysis workflow initiated automatically

*End* *Regulatory Breach Notification* | **Hash**: c52f30e7

---

## Change Management Operations

# REQ-o00073: Automated Change Control

**Level**: Ops | **Implements**: o00051 | **Status**: Draft

All system changes SHALL be controlled through automated CI/CD pipelines that enforce approval workflows, testing requirements, and audit trail generation without manual tracking.

Automated change control SHALL enforce:
- Required approvals before deployment (configurable per environment)
- Automated test execution before promotion
- Compliance scan passage before production deployment
- Automatic rollback on deployment failure
- Change record generation from CI/CD metadata

**Change Categories and Automation**:

| Category | Approval | Testing | Compliance Scan |
| -------- | -------- | ------- | --------------- |
| Security patch | Auto-approve | Required | Required |
| Bug fix | 1 approval | Required | Required |
| Feature | 2 approvals | Required | Required |
| Database migration | 2 approvals + DBA | Required | Required + manual |
| Infrastructure | 2 approvals | Required | Required + manual |

**Rationale**: Manual change tracking is error-prone and creates compliance gaps. CI/CD-integrated change control ensures every change is tracked, tested, and approved by design.

**Acceptance Criteria**:
- No changes deployable outside CI/CD pipeline
- Change records auto-generated with approver, timestamp, and scope
- Unapproved changes blocked at deployment
- Change audit trail exportable for compliance review
- Emergency change process documented and auditable

*End* *Automated Change Control* | **Hash**: cb807e9b

---

## Backup and Recovery Operations

# REQ-o00074: Automated Backup Verification

**Level**: Ops | **Implements**: o00008 | **Status**: Draft

Database backups SHALL be automatically verified for integrity and restorability, with verification results recorded as compliance evidence.

Backup verification SHALL include:
- Backup completion verification (daily)
- Backup integrity check via checksum (daily)
- Restore test to isolated environment (weekly)
- Point-in-time recovery test (monthly)
- Cross-region backup replication verification (daily)

**Verification Schedule**:
- Completion check: Within 1 hour of backup
- Integrity check: Within 4 hours of backup
- Restore test: Weekly, automated
- PITR test: Monthly, with compliance officer notification
- DR drill: Quarterly, with documented results

**Rationale**: Backups that cannot be restored provide false confidence. Automated verification ensures recovery capability is validated, not assumed.

**Acceptance Criteria**:
- Backup verification failures alert within 1 hour
- Weekly restore test results archived as compliance evidence
- Backup integrity verifiable via independent checksum
- Recovery time measured and tracked against RTO
- Backup verification included in compliance dashboard

*End* *Automated Backup Verification* | **Hash**: d580ec6f

---

## Vendor and Third-Party Operations

# REQ-o00075: Third-Party Security Assessment

**Level**: Ops | **Implements**: p00010 | **Status**: Draft

Third-party services integrated with the platform SHALL undergo security assessment, with assessment results tracked and reassessed annually or upon significant changes.

Third-party assessment SHALL cover:
- SOC 2 Type II report review (required for data processors)
- Data processing agreement compliance
- Security questionnaire completion
- Penetration test result review (where applicable)
- Incident notification capability verification

**Critical Third-Party Services**:

| Service | Type | Assessment Frequency | Required Certifications |
| ------- | ---- | ------------------- | ---------------------- |
| GCP | Infrastructure | Annual | SOC 2, ISO 27001, HIPAA BAA |
| Doppler | Secrets management | Annual | SOC 2 |
| Identity Platform | Authentication | Annual | SOC 2, ISO 27001 |
| Linear | Issue tracking | Annual | SOC 2 |

**Rationale**: Third-party security is platform security. Automated tracking ensures vendor assessments remain current without manual calendar management.

**Acceptance Criteria**:
- All third-party services documented with security status
- Assessment expiration alerts 60 days in advance
- Expired assessments block new integrations
- Third-party incident notification tested annually
- Vendor security status visible in compliance dashboard

*End* *Third-Party Security Assessment* | **Hash**: 17585690

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
