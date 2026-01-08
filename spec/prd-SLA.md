# Service Level Agreement Requirements

**Version**: 1.0
**Audience**: Product Requirements
**Last Updated**: 2025-12-04
**Status**: Draft

> **See**: ops-SLA.md for operational implementation
> **See**: ops-monitoring-observability.md for monitoring infrastructure
> **See**: prd-clinical-trials.md for regulatory compliance context

---

## Executive Summary

This document defines the Service Level Agreement (SLA) commitments provided to customers (Sponsors) for the Clinical Trial Diary Platform. These guarantees ensure reliable service delivery for FDA-regulated clinical trial data collection.

**Key Commitments**:
- 99.9% monthly uptime for production services
- Defined incident response and resolution times by severity
- 24-hour Recovery Time Objective (RTO) / 4-hour Recovery Point Objective (RPO)
- Root cause analysis and corrective action for significant incidents
- Transparent customer communication during incidents

---

## Definitions

| Term | Definition |
| --- | --- |
| **Availability/Uptime** | Percentage of time production service is accessible, excluding scheduled maintenance |
| **Incident** | Event disrupting or degrading normal service operation |
| **Recovery Time Objective (RTO)** | Maximum targeted duration to restore service after disruption |
| **Recovery Point Objective (RPO)** | Maximum targeted period of data loss due to disruption |

---

## Requirements

# REQ-p01021: Service Availability Commitment

**Level**: PRD | **Status**: Draft | **Implements**: p00048

## Rationale

99.9% uptime (~43 minutes monthly downtime) is industry standard for healthcare SaaS platforms requiring 24/7 availability. This commitment balances reliability with operational feasibility for a clinical trial platform. The requirement establishes clear service level expectations for sponsors and participants, ensuring the platform maintains sufficient availability for clinical trial operations while allowing for necessary maintenance windows and circumstances beyond operational control.

## Assertions

A. The platform SHALL provide 99.9% monthly uptime for all customer-facing production services.
B. The availability commitment SHALL include portal web application accessibility.
C. The availability commitment SHALL include mobile app synchronization API availability.
D. The availability commitment SHALL include authentication service availability.
E. The availability commitment SHALL include database connectivity for read/write operations.
F. Uptime percentage SHALL be calculated as (Total Minutes in Month - Downtime Minutes) / Total Minutes in Month × 100.
G. Scheduled maintenance with 48-hour advance notice SHALL be excluded from downtime calculation.
H. Force majeure events, including natural disasters and widespread internet outages, SHALL be excluded from downtime calculation.
I. Customer-caused outages or failures SHALL be excluded from downtime calculation.
J. Beta or trial services SHALL be excluded from downtime calculation.
K. The system SHALL measure uptime monthly per sponsor.
L. The system SHALL report uptime monthly per sponsor.
M. The system SHALL perform automated uptime monitoring with 60-second check intervals.
N. Uptime reports SHALL be available to sponsors on request.
O. Historical uptime data SHALL be retained for 2 years.

*End* *Service Availability Commitment* | **Hash**: fc65d10f
---

# REQ-p01022: Incident Severity Classification

**Level**: PRD | **Status**: Draft | **Implements**: p00048

## Rationale

Standardized severity classification ensures consistent prioritization, appropriate resource allocation, and clear customer expectations for incident handling. This requirement establishes a four-tier severity model that aligns response timelines, escalation procedures, and customer communications with the actual business and patient safety impact of service incidents. The classification system enables operational teams to make rapid triage decisions while providing stakeholders with predictable expectations for incident resolution.

## Assertions

A. The system SHALL classify all service incidents by severity level.
B. The system SHALL support a Critical (P0) severity level for complete service loss or security events with active exploitation, data breach, or risk to patient safety where no workaround is available.
C. The system SHALL support a High (P1) severity level for significant service degradation or security events with high exploitation likelihood where partial workarounds may exist.
D. The system SHALL support a Medium (P2) severity level for moderate impact to non-critical functions or security events with limited risk where workarounds are available.
E. The system SHALL support a Low (P3) severity level for minor impact, cosmetic issues, or negligible security risk with no immediate operational threat.
F. Critical (P0) severity SHALL include incidents such as database down, authentication failure, data corruption, or active security breach.
G. High (P1) severity SHALL include incidents such as slow response times exceeding 10 seconds, sync failures for subset of users, or elevated error rates.
H. Medium (P2) severity SHALL include incidents such as minor feature unavailable, cosmetic issues, or non-critical integrations down.
I. Low (P3) severity SHALL include incidents such as UI inconsistencies, minor performance degradation, or documentation errors.
J. The system SHALL assign a severity level to all incidents at the time of detection.
K. The incident severity level SHALL determine the response timeline for the incident.
L. The incident severity level SHALL determine the escalation path for the incident.
M. The system SHALL notify customers of the severity level for incidents impacting them.
N. The system SHALL allow severity levels to be upgraded with documented justification.
O. The system SHALL allow severity levels to be downgraded with documented justification.

*End* *Incident Severity Classification* | **Hash**: b38ac116
---

# REQ-p01023: Incident Response Times

**Level**: PRD | **Status**: Draft | **Implements**: p01022

## Rationale

Defined response times set clear expectations for customers and ensure appropriate urgency in incident handling. Resolution timelines account for complexity while maintaining accountability. This requirement establishes service level commitments for incident management, ensuring that incidents are acknowledged and resolved within timeframes appropriate to their severity. The tiered approach balances customer expectations with practical considerations of incident complexity, while tracking and reporting mechanisms ensure organizational accountability.

## Assertions

A. The platform SHALL respond to Critical (P0) incidents within 1 hour of detection.
B. The platform SHALL respond to High (P1) incidents within 4 hours of detection.
C. The platform SHALL respond to Medium (P2) incidents within 1 business day of detection.
D. The platform SHALL respond to Low (P3) incidents within 2 business days of detection.
E. The platform SHALL resolve Critical (P0) incidents within 7 days of detection.
F. The platform SHALL resolve High (P1) incidents within 14 days of detection.
G. The platform SHALL resolve Medium (P2) incidents within 30 days of detection.
H. The platform SHALL resolve Low (P3) incidents within 90 days of detection.
I. Initial response SHALL include confirmation that the incident is being investigated.
J. Initial response SHALL include the assigned severity level.
K. Initial response SHALL include a preliminary impact assessment.
L. Initial response SHALL include the timeline for next communication.
M. Resolution SHALL include restoration of service to normal operation.
N. Resolution SHALL include identification of root cause for Critical (P0) incidents.
O. Resolution SHALL include identification of root cause for High (P1) incidents.
P. Resolution SHALL include preventive measures that are either implemented or scheduled.
Q. The system SHALL track response time from incident detection to first customer communication.
R. The system SHALL track resolution time from incident detection to service restoration.
S. The platform SHALL report SLA compliance monthly.
T. The system SHALL trigger escalation when approaching response or resolution deadlines.

*End* *Incident Response Times* | **Hash**: dcee0291
---

# REQ-p01024: Disaster Recovery Objectives

**Level**: PRD | **Status**: Draft | **Implements**: p00012

## Rationale

This requirement ensures business continuity for clinical trial operations through defined disaster recovery capabilities. The 4-hour RPO (Recovery Point Objective) aligns with backup frequency to minimize data loss in FDA-regulated environments, while the 24-hour RTO (Recovery Time Objective) allows for thorough recovery verification required for regulated systems. Regular drills and documented procedures ensure preparedness for actual disaster scenarios, and timely sponsor communication maintains transparency during incidents.

## Assertions

A. The platform SHALL maintain a Recovery Time Objective (RTO) of 24 hours for full production service restoration.
B. The platform SHALL maintain a Recovery Point Objective (RPO) of 4 hours representing the maximum acceptable data loss window.
C. The platform SHALL support point-in-time database recovery within the RPO window.
D. The platform SHALL support service restoration to alternate infrastructure when needed.
E. The platform SHALL verify data integrity after recovery completion.
F. The platform SHALL communicate recovery status to affected sponsors during recovery operations.
G. Automated backups SHALL run at intervals meeting the RPO objective of every 4 hours minimum.
H. Disaster recovery drills SHALL be conducted quarterly.
I. Disaster recovery drills SHALL be documented.
J. Recovery procedures SHALL be validated.
K. Recovery procedures SHALL be documented.
L. The platform SHALL notify sponsors within 1 hour of disaster declaration.

*End* *Disaster Recovery Objectives* | **Hash**: 5db46324
---

# REQ-p01033: Customer Incident Notification

**Level**: PRD | **Status**: Draft | **Implements**: p01022

## Rationale

Proactive customer communication maintains trust and allows sponsors to inform their study teams about system incidents. Transparent incident notification is essential for FDA-regulated clinical trial environments where sponsors have regulatory oversight responsibilities and must maintain awareness of any issues affecting data collection or system availability. Timely and structured notifications enable sponsors to take appropriate actions, such as informing study coordinators or documenting potential impacts on trial conduct.

## Assertions

A. The system SHALL notify customers of Critical (P0) incidents within 15 minutes of incident declaration.
B. The system SHALL notify customers of High (P1) incidents within the initial response time defined for that severity level.
C. The system SHALL notify customers of Medium (P2) incidents within the initial response time defined for that severity level.
D. The system SHALL notify customers of Low (P3) incidents when the incident is resolved.
E. The system SHALL deliver Critical (P0) incident notifications via email, status page, and direct contact channels.
F. The system SHALL deliver High (P1) incident notifications via email and status page channels.
G. The system SHALL deliver Medium (P2) incident notifications via email channel.
H. The system SHALL deliver Low (P3) incident notifications via status page channel.
I. Incident notifications SHALL include a brief description of the issue.
J. Incident notifications SHALL include the impact scope identifying affected functionality.
K. Incident notifications SHALL include the current status as one of: investigating, identified, monitoring, or resolved.
L. Incident notifications SHALL include the estimated time to resolution when such estimate is known.
M. Incident notifications SHALL include the timeline for the next update.
N. The system SHALL automatically update the status page for all P0 incidents.
O. The system SHALL automatically update the status page for all P1 incidents.
P. The system SHALL maintain pre-approved customer notification templates.
Q. The system SHALL track notification timing for all customer notifications.
R. The system SHALL report on notification timing metrics.
S. The system SHALL provide subscriber management functionality for status update notifications.

*End* *Customer Incident Notification* | **Hash**: a8193b60
---

# REQ-p01034: Root Cause Analysis

**Level**: PRD | **Status**: Draft | **Implements**: p01023

## Rationale

Root cause analysis prevents recurring incidents and demonstrates due diligence for regulatory compliance. The systematic investigation of significant incidents ensures that underlying causes are identified and addressed, reducing the likelihood of recurrence. This documentation supports sponsor audit requirements, demonstrates continuous improvement efforts, and maintains compliance with FDA 21 CFR Part 11 record retention requirements.

## Assertions

A. The system SHALL require documented root cause analysis (RCA) for all Critical (P0) incidents within 5 business days.
B. The system SHALL require documented root cause analysis (RCA) for all High (P1) incidents within 10 business days.
C. The system SHALL support summary RCA documentation for Medium (P2) incidents upon request.
D. The system SHALL NOT require RCA documentation for Low (P3) incidents.
E. RCA documentation SHALL include an incident timeline from detection to resolution.
F. RCA documentation SHALL include root cause identification.
G. RCA documentation SHALL include contributing factors.
H. RCA documentation SHALL include impact assessment.
I. RCA documentation SHALL include corrective actions taken.
J. RCA documentation SHALL include preventive measures implemented.
K. The system SHALL retain all RCA documentation for FDA inspection per 21 CFR Part 11 requirements.
L. The system SHALL use a standardized RCA template.
M. RCAs SHALL be reviewed by a technical lead before delivery.
N. The system SHALL track RCA delivery against defined timelines.
O. The system SHALL archive RCAs for 7 years.

*End* *Root Cause Analysis* | **Hash**: 69a5318a
---

# REQ-p01035: Corrective and Preventive Action

**Level**: PRD | **Status**: Draft | **Implements**: p01034, p00010

## Rationale

CAPA (Corrective and Preventive Action) processes are a cornerstone of FDA quality management systems for regulated software. By establishing formal processes to respond to incidents affecting data integrity or regulatory compliance, the system demonstrates a commitment to continuous improvement and proactive risk management. This requirement aligns with FDA expectations for quality systems under 21 CFR Part 820 (Quality System Regulation) and ICH Q9 (Quality Risk Management). CAPA processes provide sponsors with confidence that issues are systematically addressed through root cause analysis, implementation of corrective actions, and verification of effectiveness. The documentation and tracking requirements ensure transparency and accountability throughout the remediation lifecycle.

## Assertions

A. The system SHALL trigger a Corrective and Preventive Action (CAPA) process for all incidents affecting data integrity or regulatory compliance.
B. The system SHALL initiate CAPA within 72 hours of incident confirmation.
C. CAPA documentation SHALL be made available to the sponsor for audit purposes.
D. The system SHALL document effectiveness verification within 30 days of CAPA implementation.
E. The system SHALL track all CAPAs to completion.
F. CAPA documentation SHALL include a problem description and scope.
G. CAPA documentation SHALL include a root cause analysis reference.
H. CAPA documentation SHALL include corrective actions (immediate fixes).
I. CAPA documentation SHALL include preventive actions (systemic improvements).
J. CAPA documentation SHALL include effectiveness criteria.
K. CAPA documentation SHALL include verification results.
L. The system SHALL initiate CAPA for all P0 incidents.
M. The system SHALL initiate CAPA for all P1 incidents affecting data integrity.
N. The system SHALL maintain a CAPA tracking system.
O. CAPA status SHALL be visible to the sponsor upon request.
P. The system SHALL perform an annual CAPA effectiveness review.

*End* *Corrective and Preventive Action* | **Hash**: 23046f23
---

# REQ-p01036: Data Recovery Guarantee

**Level**: PRD | **Status**: Draft | **Implements**: p01024

## Rationale

Data recovery guarantees are critical for maintaining clinical trial integrity and regulatory compliance when disaster scenarios occur. This requirement ensures that sponsors can fulfill their obligations to regulatory authorities (FDA, EMA) to maintain complete and accurate trial records, even after data loss or corruption events. The no-cost guarantee protects sponsors from financial exposure during recovery operations. Clear communication protocols support sponsor responsibilities under 21 CFR Part 11 and ICH-GCP to document and report data integrity incidents. Recovery procedures must be tested and documented to demonstrate preparedness during regulatory audits.

## Assertions

A. The platform SHALL provide data recovery services at no additional cost in the event of data loss or corruption.
B. The platform SHALL restore data to the most recent Recovery Point Objective (RPO) checkpoint during recovery operations.
C. The platform SHALL provide a detailed impact assessment if full data recovery is not possible.
D. The platform SHALL reconstruct affected audit trails where technically feasible during recovery operations.
E. The platform SHALL document all recovery actions for regulatory reporting purposes.
F. Recovery communication SHALL include the scope of data affected.
G. Recovery communication SHALL include the recovery actions taken.
H. Recovery communication SHALL include data verification results.
I. Recovery communication SHALL include recommendations for sponsor regulatory notification.
J. Recovery procedures SHALL be documented.
K. Recovery procedures SHALL be tested.
L. The platform SHALL use a recovery verification checklist post-recovery.
M. Recovery documentation SHALL be suitable for regulatory submission.

*End* *Data Recovery Guarantee* | **Hash**: 0224912a
---

# REQ-p01037: Chronic Failure Escalation

**Level**: PRD | **Status**: Draft | **Implements**: p01021

## Rationale

Chronic failure provisions protect sponsors from persistent service degradation and provide clear accountability for sustained reliability issues. This requirement establishes contractual safeguards when service reliability consistently falls below acceptable thresholds, defining specific uptime criteria that trigger escalation processes, mandatory remediation timelines, and sponsor exit rights. The provisions ensure that sponsors have recourse when platform reliability problems persist over extended periods, preventing situations where individual incidents meet SLA requirements but cumulative degradation creates unacceptable risk to clinical trial operations.

## Assertions

A. The system SHALL trigger escalation and remediation processes when service reliability falls below acceptable thresholds for sustained periods.
B. A chronic failure condition SHALL be defined as uptime below 99.0% for three (3) consecutive months.
C. The platform SHALL enable sponsors to request a mandatory executive escalation meeting within 10 business days when chronic failure occurs.
D. The platform SHALL provide a written remediation plan with milestones within 15 business days of chronic failure escalation.
E. The platform SHALL grant sponsors the right to terminate without penalty upon 60 days written notice if remediation is unsuccessful.
F. The system SHALL track monthly uptime for each sponsor.
G. The system SHALL report monthly uptime metrics to each sponsor.
H. The system SHALL automatically notify sponsors when approaching the chronic failure threshold.
I. The platform SHALL maintain a remediation plan template for chronic failure scenarios.
J. The system SHALL document escalation contacts per sponsor.
K. The platform SHALL provide service remedies when uptime commitments are not met, as defined in operational specifications.

*End* *Chronic Failure Escalation* | **Hash**: 3a07854b
---

# REQ-p01038: Regulatory Event Support

**Level**: PRD | **Status**: Draft | **Implements**: p00010, p01034

## Rationale

SLA failures in FDA-regulated clinical trial systems may trigger sponsor obligations for regulatory notification, inspection responses, or audit findings under FDA 21 CFR Part 11 and ICH-GCP guidelines. Provider support ensures sponsors can meet their regulatory responsibilities by providing timely documentation, technical expertise, and corrective action implementation without imposing additional financial burden during regulatory events.

## Assertions

A. The system SHALL provide support services when an SLA failure results in a regulatory inquiry or inspection finding.
B. The system SHALL provide all relevant documentation within 5 business days of a regulatory request.
C. The system SHALL participate in regulatory responses at no additional cost to the sponsor.
D. The system SHALL implement required corrective actions within agreed timelines.
E. The system SHALL support the sponsor in preparing regulatory submissions.
F. Documentation packages SHALL include incident timeline and root cause analysis.
G. Documentation packages SHALL include system validation documentation.
H. Documentation packages SHALL include audit trail exports.
I. Documentation packages SHALL include CAPA documentation.
J. Documentation packages SHALL be prepared within 5 business days of a regulatory event.
K. Technical staff SHALL be available for regulatory calls.
L. Corrective action timelines SHALL be negotiated in good faith.
M. The system SHALL NOT impose additional charges for regulatory support services.

*End* *Regulatory Event Support* | **Hash**: 64f84d80
---

## SLA Exclusions

This SLA does not apply to:

1. **Force Majeure**: Natural disasters, widespread internet outages, government actions
2. **Customer-Caused Issues**: Outages caused by customer actions or configurations
3. **Scheduled Maintenance**: Pre-announced maintenance with 48-hour notice
4. **Beta/Trial Services**: Non-production services explicitly designated as beta
5. **Third-Party Dependencies**: Failures in customer-provided integrations

---

## References

- **Operational Implementation**: ops-SLA.md
- **Monitoring Infrastructure**: ops-monitoring-observability.md
- **Regulatory Compliance**: prd-clinical-trials.md
- **Data Architecture**: prd-database.md
- **Backup Procedures**: ops-operations.md

---

**Document Status**: Active SLA Requirements
**Review Cycle**: Annually or after significant SLA events
**Owner**: Product Management
