# SLA Operations and Monitoring

**Version**: 1.0
**Audience**: Operations (SRE, DevOps, On-Call Engineers)
**Last Updated**: 2025-12-04
**Status**: Active

> **See**: prd-SLA.md for SLA commitments
> **See**: ops-monitoring-observability.md for monitoring infrastructure
> **See**: ops-operations.md for daily operations procedures

---

## Executive Summary

This document specifies operational procedures and tooling for achieving, measuring, and maintaining SLA commitments defined in prd-SLA.md. Focus is on maximum automation suitable for a small development team.

**Automation Philosophy**:
- Automated measurement and alerting (no manual uptime tracking)
- Automated customer communication (status page updates)
- Automated escalation (on-call rotation and paging)
- Automated reporting (monthly SLA reports generated)
- Manual intervention only for incident response and CAPA

---

## Tool Stack for SLA Compliance

### Recommended Tooling (Small Team, Maximum Automation)

| Function | Tool | Cost | Justification |
| --- | --- | --- | --- |
| **SLO Tracking** | GCP Cloud Monitoring SLO | Included | Native GCP, 500 SLOs per service |
| **Uptime Monitoring** | GCP Uptime Checks | Free (100 checks) | Already integrated, 60-second intervals |
| **On-Call Management** | PagerDuty or Grafana OnCall | $21/user/mo or Free | Automated paging, schedules, escalation |
| **Status Page** | Instatus or Better Stack | $20/mo | Automated updates, subscriber notifications |
| **Incident Tracking** | Linear (existing) | Existing | Ticket integration, requirement traceability |
| **CAPA Tracking** | Linear (existing) | Existing | Workflow automation, audit trail |
| **Automated Reports** | Cloud Scheduler + Functions | ~$5/mo | Monthly SLA report generation |

### Tool Integration Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ GCP Cloud Monitoring                                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────┐     ┌─────────────────────┐                │
│  │ Uptime Checks       │     │ SLO Definitions     │                │
│  │ (60-second intervals)│     │ (Error Budgets)     │                │
│  └──────────┬──────────┘     └──────────┬──────────┘                │
│             │                           │                            │
│             └───────────┬───────────────┘                            │
│                         │                                            │
│                         ▼                                            │
│  ┌─────────────────────────────────────────────┐                    │
│  │ Alerting Policies                           │                    │
│  │ • Uptime failures → P0/P1 alerts            │                    │
│  │ • Error budget burn → Warning alerts        │                    │
│  │ • Performance degradation → P2 alerts       │                    │
│  └─────────────────────┬───────────────────────┘                    │
│                        │                                             │
└────────────────────────┼─────────────────────────────────────────────┘
                         │
           ┌─────────────┴─────────────┐
           │                           │
           ▼                           ▼
┌──────────────────────┐    ┌──────────────────────┐
│ PagerDuty/OnCall     │    │ Status Page          │
│ • On-call paging     │    │ • Auto-update status │
│ • Escalation         │    │ • Subscriber notify  │
│ • Acknowledgment     │    │ • Incident history   │
└──────────┬───────────┘    └──────────┬───────────┘
           │                           │
           ▼                           ▼
┌──────────────────────┐    ┌──────────────────────┐
│ Linear Tickets       │    │ Customer Email       │
│ • Incident tracking  │    │ • P0/P1 notifications│
│ • CAPA workflow      │    │ • Resolution updates │
│ • Requirement links  │    │ • RCA delivery       │
└──────────────────────┘    └──────────────────────┘
```

---

## Requirements

# REQ-o00056: SLO Definition and Tracking

**Level**: Ops | **Implements**: p01021 | **Status**: Draft

The system SHALL define and track Service Level Objectives (SLOs) using GCP Cloud Monitoring.

SLO configuration SHALL include:

1. **Portal Availability SLO**:
   - SLI: Uptime check success rate
   - Target: 99.9% over rolling 30 days
   - Error budget: 43 minutes/month

2. **API Availability SLO**:
   - SLI: Cloud Run request success rate (non-5xx)
   - Target: 99.9% over rolling 30 days
   - Error budget: 43 minutes/month

3. **API Latency SLO**:
   - SLI: Cloud Run response latency p95
   - Target: 95% of requests < 500ms
   - Measurement: Rolling 7 days

4. **Sync Success SLO**:
   - SLI: Mobile sync API success rate
   - Target: 99.5% success
   - Measurement: Rolling 7 days

**GCP Configuration** (create availability SLO for portal):

```bash
gcloud monitoring slo create portal-availability \
  --service=portal \
  --project=$PROJECT_ID \
  --display-name="Portal 99.9% Availability" \
  --sli-request-based-good-total-ratio \
  --goal=0.999 \
  --rolling-period-days=30
```

**Rationale**: Native GCP SLO tracking provides automated measurement, error budget visualization, and alerting integration without additional tooling cost.

**Acceptance Criteria**:
- SLOs defined for all production services
- Error budget dashboards visible in Cloud Console
- Burn rate alerts configured
- Monthly SLO compliance exportable

*End* *SLO Definition and Tracking* | **Hash**: 5efae38e
---

# REQ-o00057: Automated Uptime Monitoring

**Level**: Ops | **Implements**: p01021, o00046 | **Status**: Draft

Production services SHALL be monitored for availability with automated health checks.

Uptime check configuration:

| Service | Endpoint | Interval | Timeout | Regions |
| --- | --- | --- | --- | --- |
| Portal | /health | 60 seconds | 10 seconds | 3 regions |
| API | /api/health | 60 seconds | 10 seconds | 3 regions |
| Auth | /auth/health | 60 seconds | 10 seconds | 3 regions |

**Multi-region monitoring**:
- us-central1 (primary)
- us-east4 (secondary)
- europe-west1 (EU compliance)

**Alert triggers**:
- **Immediate (P0)**: 2 consecutive failures from 2+ regions
- **Warning**: 1 failure or latency > 5 seconds

**GCP Configuration** (create uptime check):

```bash
gcloud monitoring uptime-check-configs create portal-health \
  --display-name="Portal Health Check" \
  --http-check-path="/health" \
  --monitored-resource-type="uptime_url" \
  --monitored-resource-labels="host=portal.clinicaldiary.com" \
  --period=60s \
  --timeout=10s \
  --regions=usa-oregon,usa-virginia,europe-belgium
```

**Rationale**: Multi-region monitoring detects both service outages and regional connectivity issues, with 60-second intervals providing rapid detection while avoiding false positives.

**Acceptance Criteria**:
- All production endpoints monitored
- Multi-region checks active
- Alerts trigger within 2 minutes of outage
- False positive rate < 1%

*End* *Automated Uptime Monitoring* | **Hash**: 29c323db
---

# REQ-o00058: On-Call Automation

**Level**: Ops | **Implements**: p01023 | **Status**: Draft

On-call management SHALL be automated to ensure rapid incident response.

**Recommended Tool**: PagerDuty (industry standard) or Grafana OnCall (free with Grafana Cloud)

On-call configuration:

1. **Schedule Management**:
   - Weekly rotation (Monday 9am handoff)
   - Primary and secondary on-call
   - Holiday/vacation overrides
   - Automatic schedule generation

2. **Escalation Policies**:
   - Level 1: Primary on-call (immediate)
   - Level 2: Secondary on-call (after 10 minutes)
   - Level 3: Engineering lead (after 20 minutes)
   - Level 4: CTO (after 30 minutes for P0)

3. **Notification Channels**:
   - Push notification (mobile app)
   - SMS
   - Phone call (for P0 after 5 minutes)
   - Email (backup)

4. **Acknowledgment Tracking**:
   - Alert acknowledged within response SLA
   - Auto-escalation if unacknowledged
   - Acknowledgment logged for reporting

**Integration** (PagerDuty service configuration):

```yaml
service:
  name: "Clinical Diary Production"
  escalation_policy: "production-critical"
  alert_creation: "create_alerts_and_incidents"
  integrations:
    - type: "events_api_v2"
      name: "GCP Cloud Monitoring"
```

**Rationale**: Automated on-call management eliminates manual paging, ensures coverage, and provides audit trail for SLA compliance reporting.

**Acceptance Criteria**:
- 24/7 on-call coverage maintained
- Escalation triggers automatically
- Response time tracked per incident
- Monthly on-call reports generated

*End* *On-Call Automation* | **Hash**: 545e519a
---

# REQ-o00059: Automated Status Page

**Level**: Ops | **Implements**: p01033 | **Status**: Draft

Customer-facing status page SHALL provide real-time service status with automated updates.

**Recommended Tool**: Instatus ($20/month) or Better Stack (includes monitoring)

Status page configuration:

1. **Components**:
   - Portal Application
   - Mobile Sync API
   - Authentication Service
   - Database Services

2. **Automated Updates**:
   - Webhook integration with GCP Cloud Monitoring
   - Automatic status change on uptime check failure
   - Automatic resolution when checks pass

3. **Subscriber Notifications**:
   - Email notifications for P0/P1 incidents
   - SMS option for critical subscribers
   - Slack/Teams webhooks for sponsor channels
   - RSS feed for automation

4. **Incident Templates**:
   - Investigating: "We are investigating elevated error rates..."
   - Identified: "We have identified the issue as..."
   - Monitoring: "A fix has been implemented. We are monitoring..."
   - Resolved: "This incident has been resolved..."

**Integration Flow**:

```
GCP Alert → Webhook → Status Page API → Auto-update status
                                      → Notify subscribers
                                      → Create incident timeline
```

**Rationale**: Automated status page reduces communication overhead during incidents, ensures consistent messaging, and meets customer notification SLAs without manual intervention.

**Acceptance Criteria**:
- Status page updated within 5 minutes of outage detection
- All P0/P1 incidents automatically posted
- Subscriber notification delivery rate > 99%
- Incident history retained 1 year

*End* *Automated Status Page* | **Hash**: 6ef867f8
---

# REQ-o00060: SLA Reporting Automation

**Level**: Ops | **Implements**: p01021 | **Status**: Draft

Monthly SLA compliance reports SHALL be generated automatically.

**Implementation**: Cloud Scheduler + Cloud Functions

Report content:

1. **Uptime Summary**:
   - Monthly uptime percentage per service
   - Total downtime minutes
   - Incident count by severity
   - SLA compliance status (met/missed)

2. **Incident Summary**:
   - List of all incidents with severity, duration, impact
   - Response time compliance (% within SLA)
   - Resolution time compliance (% within SLA)

3. **Trend Analysis**:
   - Month-over-month uptime comparison
   - Error budget consumption trend
   - Recurring issue identification

4. **Delivery**:
   - PDF report generated on 1st of month
   - Emailed to sponsor contacts
   - Archived in Cloud Storage (7 years)

**Cloud Scheduler Configuration** (monthly SLA report generation):

```bash
gcloud scheduler jobs create http sla-monthly-report \
  --location=$REGION \
  --schedule="0 6 1 * *" \
  --uri="https://${CLOUD_RUN_URL}/admin/reports/sla-monthly" \
  --http-method=POST \
  --oidc-service-account-email=${SERVICE_ACCOUNT}
```

**Rationale**: Automated reporting eliminates manual data gathering, ensures consistent delivery, and provides audit-ready documentation for regulatory compliance.

**Acceptance Criteria**:
- Reports generated by 6am on 1st of each month
- Reports delivered to sponsor contacts
- Reports archived per retention policy
- Report format approved by compliance

*End* *SLA Reporting Automation* | **Hash**: 037b0946
---

# REQ-o00061: Incident Classification Automation

**Level**: Ops | **Implements**: p01022 | **Status**: Draft

Incident severity SHALL be automatically classified based on alert characteristics.

Classification rules:

| Alert Type | Auto-Classification | Override Allowed |
| --- | --- | --- |
| Uptime check failure (2+ regions) | P0 Critical | Downgrade only |
| API error rate > 10% | P0 Critical | Downgrade only |
| API error rate > 5% | P1 High | Yes |
| Latency p95 > 2 seconds | P1 High | Yes |
| Single region failure | P2 Medium | Yes |
| Non-critical service down | P2 Medium | Yes |
| Performance degradation | P3 Low | Yes |

**Auto-classification logic** (alert policy with severity label):

```yaml
alertPolicy:
  displayName: "API High Error Rate"
  conditions:
    - conditionThreshold:
        filter: 'resource.type="cloud_run_revision"'
        comparison: COMPARISON_GT
        thresholdValue: 0.05
        duration: "300s"
  userLabels:
    severity: "P1"
    team: "backend"
```

**Override process**:
- On-call engineer may adjust severity with justification
- All adjustments logged in incident ticket
- Downgrade requires confirmation of limited impact

**Rationale**: Automatic classification ensures consistent severity assignment and immediate appropriate response, while allowing human override for context-specific situations.

**Acceptance Criteria**:
- All monitored alerts have default severity
- Classification applied within 1 minute of alert
- Override history tracked
- Classification accuracy reviewed monthly

*End* *Incident Classification Automation* | **Hash**: 5e96a7aa
---

# REQ-o00062: RCA and CAPA Workflow

**Level**: Ops | **Implements**: p01034, p01035 | **Status**: Draft

Root Cause Analysis and CAPA processes SHALL be tracked through automated workflows.

**Implementation**: Linear ticket workflow with automation rules

Workflow stages:

1. **Incident Created** (auto):
   - Ticket created from alert
   - Severity label applied
   - On-call assigned
   - Timer started

2. **Investigating** (manual):
   - Engineer updates status
   - Investigation notes added
   - Timeline documented

3. **Resolved** (manual):
   - Resolution documented
   - Downtime recorded
   - If P0/P1 → RCA ticket auto-created

4. **RCA In Progress** (P0/P1 only):
   - Template applied
   - Due date set (5/10 business days)
   - Reminder automation

5. **CAPA Required** (if data integrity affected):
   - CAPA ticket linked
   - 72-hour initiation deadline
   - 30-day effectiveness deadline

**Linear Automation Rules** (auto-create RCA ticket for P0/P1):

```yaml
automation:
  trigger: incident_resolved
  conditions:
    - label: ["P0", "P1"]
  actions:
    - create_issue:
        title: "RCA: ${incident.title}"
        template: "rca-template"
        due_date: "+5 business days"
        labels: ["RCA", "${incident.severity}"]
```

**Rationale**: Automated workflow ensures RCA/CAPA processes are initiated on time and tracked to completion, meeting regulatory requirements without manual overhead.

**Acceptance Criteria**:
- RCA tickets auto-created for P0/P1
- Due date reminders sent at 50% and 90% of deadline
- CAPA effectiveness tracking automated
- Workflow audit trail complete

*End* *RCA and CAPA Workflow* | **Hash**: ecec7aed
---

# REQ-o00063: Error Budget Alerting

**Level**: Ops | **Implements**: p01021, p01037 | **Status**: Draft

Error budget consumption SHALL be monitored with proactive alerts before SLA breach.

Alert thresholds:

| Budget Consumed | Alert Level | Action |
| --- | --- | --- |
| 50% | Warning | Engineering team Slack notification |
| 75% | Elevated | Engineering lead notified |
| 90% | Critical | Freeze non-critical deployments |
| 100% | SLA Breach | Executive notification, remediation plan |

**Burn rate alerts**:
- Fast burn (3x rate): Alert immediately
- Slow burn (1.5x rate): Alert after 1 hour sustained

**GCP Configuration** (error budget burn rate alert):

```bash
gcloud monitoring alerting-policies create \
  --display-name="Fast Error Budget Burn" \
  --condition-threshold-value=0.5 \
  --condition-threshold-duration=300s \
  --notification-channels=${NOTIFICATION_CHANNEL}
```

**Chronic failure detection**:
- Track monthly uptime for 3-month window
- Alert if any month < 99.0%
- Alert if 2 consecutive months < 99.5%
- Trigger escalation process per prd-SLA.md REQ-p01029

**Rationale**: Proactive error budget monitoring provides early warning before SLA breach, allowing corrective action while buffer remains.

**Acceptance Criteria**:
- Error budget visible in real-time dashboard
- Alerts trigger at each threshold
- Deployment freeze enforceable (CI/CD gate)
- Chronic failure detected automatically

*End* *Error Budget Alerting* | **Hash**: 60d8b564
---

# REQ-o00064: Maintenance Window Management

**Level**: Ops | **Implements**: p01021 | **Status**: Draft

Scheduled maintenance SHALL be managed with advance notification and SLA exclusion tracking.

Maintenance window process:

1. **Scheduling** (48+ hours in advance):
   - Create maintenance window in monitoring system
   - Publish to status page (scheduled maintenance)
   - Notify subscribers automatically
   - Update SLA tracking (exclude window)

2. **During Maintenance**:
   - Status page shows "Under Maintenance"
   - Alerts suppressed for affected services
   - Timer tracks actual duration

3. **Completion**:
   - Status page updated to operational
   - Actual vs. planned duration logged
   - Post-maintenance verification run

**Automation** (create maintenance window):

```bash
gcloud monitoring snooze create maintenance-window \
  --display-name="Scheduled Database Maintenance" \
  --criteria-policies=all \
  --start-time="2025-12-15T02:00:00Z" \
  --end-time="2025-12-15T04:00:00Z"
```

**Status page integration**:
- Maintenance auto-published on creation
- Reminder sent 24 hours before
- Auto-resolve when window ends

**Rationale**: Proper maintenance window management ensures scheduled work doesn't count against SLA while keeping customers informed.

**Acceptance Criteria**:
- All maintenance announced 48+ hours in advance
- Alerts suppressed during window
- Downtime excluded from SLA calculation
- Overrun triggers immediate notification

*End* *Maintenance Window Management* | **Hash**: 3732f8ca
---

## Implementation Checklist

### Phase 1: Core Monitoring (Week 1-2)
- [ ] Configure GCP SLOs for all production services
- [ ] Set up multi-region uptime checks
- [ ] Create error budget dashboards
- [ ] Configure burn rate alerts

### Phase 2: On-Call Setup (Week 2-3)
- [ ] Set up PagerDuty or Grafana OnCall
- [ ] Configure escalation policies
- [ ] Integrate with GCP Cloud Monitoring
- [ ] Test alert flow end-to-end

### Phase 3: Status Page (Week 3-4)
- [ ] Set up Instatus or Better Stack
- [ ] Configure webhook automation
- [ ] Create incident templates
- [ ] Test subscriber notifications

### Phase 4: Automation (Week 4-5)
- [ ] Deploy Cloud Function for SLA reports
- [ ] Configure Linear workflow automation
- [ ] Set up maintenance window process
- [ ] Document runbooks

### Phase 5: Validation (Week 5-6)
- [ ] Run chaos engineering tests
- [ ] Verify SLA measurement accuracy
- [ ] Train team on procedures
- [ ] Document in validation package

---

## Runbooks

### Runbook: SLA Breach Response

**Trigger**: Monthly uptime falls below 99.9%

**Steps**:

1. **Document** (within 1 hour):
   - Calculate exact uptime percentage
   - List all contributing incidents
   - Prepare preliminary impact assessment

2. **Notify** (within 24 hours):
   - Inform sponsor via email
   - Update status page with monthly summary
   - Schedule remediation review

3. **Remediate** (within 5 business days):
   - Complete RCA for contributing incidents
   - Identify systemic improvements
   - Present remediation plan to sponsor

4. **Report** (within 10 business days):
   - Deliver formal incident report
   - Document credit if applicable
   - Update CAPA tracking

### Runbook: Chronic Failure Initiation

**Trigger**: 3 consecutive months below 99.0%

**Steps**:

1. **Escalate** (immediate):
   - Notify CTO and sponsor executive contact
   - Prepare executive briefing

2. **Schedule** (within 5 business days):
   - Mandatory meeting with sponsor
   - Prepare root cause presentation

3. **Remediation Plan** (within 15 business days):
   - Written plan with milestones
   - Resource commitment
   - Timeline for improvement

4. **Track** (ongoing):
   - Weekly progress updates
   - Monthly review meetings
   - Document improvement trajectory

---

## References

- **SLA Commitments**: prd-SLA.md
- **Monitoring Infrastructure**: ops-monitoring-observability.md
- **Daily Operations**: ops-operations.md
- **GCP SLO Documentation**: https://cloud.google.com/stackdriver/docs/solutions/slo-monitoring
- **PagerDuty Integration**: https://www.pagerduty.com/docs/
- **Instatus API**: https://instatus.com/help/api

---

**Document Status**: Active Operations Specification
**Review Cycle**: Quarterly or after SLA events
**Owner**: SRE / DevOps Team
