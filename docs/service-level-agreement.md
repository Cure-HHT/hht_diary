# Service Level Agreement (SLA)

This Service Level Agreement ("SLA") sets forth the service levels and commitments provided by Anspar ("Provider") to its customers ("Customer") for cloud-hosted services. This SLA is supported by Anspar's approved security and operational policies, which are available upon request.

## 1. Definitions

| Term | Definition |
| --- | --- |
| **Availability/Uptime** | The percentage of total time in a calendar month that the primary production service is accessible and operational, excluding scheduled maintenance. |
| **Incident** | Any event that disrupts or degrades the normal operation of the service. |
| **Recovery Time Objective (RTO)** | The maximum targeted duration to restore a service after a disruption. |
| **Recovery Point Objective (RPO)** | The maximum targeted period in which data might be lost due to a disruption. |

### Severity Levels

| Severity | Description |
| --- | --- |
| **Critical (P0)** | Complete loss of service or a security event with active exploitation, data breach, or risk of physical harm. No workaround is available. |
| **High (P1)** | Significant degradation of service, or a security event with a high likelihood of exploitation or unauthorized access to sensitive data. Partial workaround may exist. |
| **Medium (P2)** | Moderate impact to non-critical functions, or a security event with limited risk or exposure. Workaround is available. |
| **Low (P3)** | Minor impact, cosmetic issues, or a security event with negligible risk and no immediate threat to operations. |

## 2. Service Availability

### Uptime Commitment

Anspar commits to **99.9% monthly uptime** for all customer-facing production services, excluding scheduled maintenance windows.

### Measurement

Uptime is measured as:

```
Uptime % = (Total Minutes in Month - Downtime Minutes) / Total Minutes in Month × 100
```

### Remedy

If uptime falls below 99.9%, remedies apply as specified in Section 5.

> **Note**: 99.9% uptime (~43 minutes monthly downtime) is industry standard for healthcare SaaS platforms requiring 24/7 availability. Higher tiers (99.99%) are available under Enterprise agreements.

## 3. Incident Response & Resolution

### Incident Classification & Response Times

| Severity | Initial Response Time | Resolution Time (Remediation) |
| --- | --- | --- |
| Critical (P0) | 1 hour | 7 days |
| High (P1) | 4 hours | 14 days |
| Medium (P2) | 1 business day | 30 days |
| Low (P3) | 2 business days | 90 days |

### Notification

- **Critical incidents**: Immediate notification to customer.
- **High/Medium/Low**: Notification within the initial response time.

## 4. Data Backup & Recovery

### Backups

Backups are performed at least daily and stored separately from production data.

### Recovery Objectives

| Objective | Target |
| --- | --- |
| **RTO** (Recovery Time Objective) | 24 hours for production cloud services |
| **RPO** (Recovery Point Objective) | 4 hours for production cloud services |

## 5. Remedies

### Incident Reporting and Root Cause Analysis

For any incident affecting service availability or data integrity:

| Severity | Reporting Requirement |
| --- | --- |
| Critical (P0) | Root cause analysis (RCA) within 5 business days |
| High (P1) | RCA within 10 business days |
| Medium (P2) | Incident summary upon request |

All RCAs are documented and retained for regulatory inspection per 21 CFR Part 11.

### Corrective and Preventive Action (CAPA)

For incidents affecting data integrity or regulatory compliance:

- **CAPA initiation**: Within 72 hours of incident confirmation
- **CAPA documentation**: Available to Sponsor for audit purposes
- **Effectiveness verification**: Documented within 30 days of implementation

### Data Recovery Guarantee

In the event of data loss or corruption:

- Anspar will restore data to the most recent RPO checkpoint at no additional cost
- If data cannot be fully recovered, Anspar will provide a detailed impact assessment for regulatory reporting
- Affected audit trails and evidence records will be reconstructed where technically feasible

### Chronic Failure Escalation

If uptime falls below 99.0% for three (3) consecutive months:

1. **Executive escalation**: Mandatory meeting with Sponsor within 10 business days
2. **Remediation plan**: Written plan with milestones provided within 15 business days
3. **Termination right**: Sponsor may terminate without penalty upon 60 days written notice if remediation is unsuccessful

### Regulatory Event Support

If an SLA failure results in a regulatory inquiry or inspection finding:

- Anspar will provide all relevant documentation within 5 business days
- Anspar will participate in regulatory responses at no additional cost
- Anspar will implement required corrective actions within agreed timelines

## 6. Exclusions

This SLA does not apply to:

- Downtime or issues caused by factors outside Anspar's reasonable control (e.g., force majeure, internet outages)
- Customer-caused outages or failures
- Scheduled maintenance with advance notice
- Beta or trial services

## 7. Reference to Policies

Anspar maintains industry-standard security, incident response, and operational controls as described in the following approved policies, which are available upon request:

- Incident Response Plan
- Business Continuity and Disaster Recovery Plan
- Information Security Policy
- Access Control Policy
- Operations Security Policy
- Third-Party Management Policy

## 8. Review & Updates

This SLA is reviewed at least annually and may be updated to reflect changes in policy, technology, or regulatory requirements. Customers will be notified of material changes.

---

*Document Version: 1.0*
*Last Updated: December 2025*
