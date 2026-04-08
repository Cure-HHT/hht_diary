# Incident Response Runbook

**Purpose**: Procedures for responding to production incidents
**Audience**: On-call engineers, operations team
**Updated**: 2026-04-08
**Version**: 2.0

---

## REFERENCES REQUIREMENTS

- REQ-o00045: Error Tracking and Monitoring
- REQ-o00046: Uptime Monitoring
- REQ-o00005: Audit Trail Monitoring
- REQ-o00047: Performance Monitoring

## Overview

This runbook defines procedures for detecting, responding to, and resolving production incidents for the HHT Diary Platform running on GCP Cloud Run.

**Production Stack**:
- **Compute**: Cloud Run (diary-server, portal-server) in europe-west9
- **Database**: Cloud SQL PostgreSQL 17 (private VPC)
- **Auth**: GCP Identity Platform (portal), JWT (diary)
- **Secrets**: Doppler
- **Observability**: OpenTelemetry (traces + logs + metrics via OTLP), Cloud Logging, Cloud Error Reporting
- **Notifications**: FCM via cure-hht-admin project

**Incident Severity Levels**:
- **Critical (P0)**: Production down, data loss, security breach
- **High (P1)**: Major feature broken, performance severely degraded
- **Medium (P2)**: Minor feature broken, performance degraded
- **Low (P3)**: Cosmetic issues, non-critical bugs

---

## Quick Diagnostics

### Deployment Doctor (First Step)

Run the deployment doctor scripts to get an instant health summary:

```bash
# Portal server
./apps/sponsor-portal/tool/deployment-doctor.sh --verbose

# Diary server
./apps/daily-diary/tool/deployment-doctor.sh --verbose
```

These check health endpoints, version verification, HTTPS, API smoke tests, Cloud Logging signals, and Cloud Run configuration.

### Cloud Run Service Status

```bash
# List services and their status
gcloud run services list --region=europe-west9 --project=$PROJECT_ID

# Describe a specific service
gcloud run services describe portal-server --region=europe-west9 --project=$PROJECT_ID

# Check recent revisions
gcloud run revisions list --service=portal-server --region=europe-west9 --project=$PROJECT_ID --limit=5
```

### Cloud Logging (Structured Logs + OTel Traces)

```bash
# Recent errors for portal-server (last 1 hour)
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="portal-server" AND severity>=ERROR' \
  --project=$PROJECT_ID --limit=20 --format='table(timestamp,jsonPayload.message)'

# Recent errors for diary-server
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="diary-server" AND severity>=ERROR' \
  --project=$PROJECT_ID --limit=20 --format='table(timestamp,jsonPayload.message)'

# Trace-correlated logs (find all logs for a specific trace)
gcloud logging read \
  'jsonPayload."logging.googleapis.com/trace"="projects/$PROJECT_ID/traces/TRACE_ID_HERE"' \
  --project=$PROJECT_ID --format='table(timestamp,jsonPayload.severity,jsonPayload.message)'

# OTel exporter errors (indicates collector connectivity issues)
gcloud logging read \
  'resource.type="cloud_run_revision" AND textPayload:"OtlpHttp"' \
  --project=$PROJECT_ID --limit=5
```

### Database Health

```bash
# Cloud SQL instance status
gcloud sql instances describe $INSTANCE_NAME --project=$PROJECT_ID \
  --format='table(state,settings.tier,settings.availabilityType)'

# Active connections
gcloud sql connect $INSTANCE_NAME --user=postgres --project=$PROJECT_ID <<'SQL'
SELECT count(*) AS active_connections FROM pg_stat_activity WHERE state = 'active';
SELECT pid, now() - query_start AS duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '5 seconds'
ORDER BY duration DESC;
SQL
```

---

## Incident Response Workflow

```
1. Detection
   - Cloud Logging alert / Cloud Error Reporting
   - Deployment doctor script
   - User report / internal discovery

2. Triage (< 5 minutes)
   - Run deployment doctor scripts
   - Check Cloud Logging for errors
   - Assess severity (P0/P1/P2/P3)
   - Create Linear ticket with incident label

3. Response (< 15 minutes)
   - Assign incident commander
   - Start investigation
   - Post in team Slack channel

4. Mitigation (< 1 hour for P0)
   - Implement fix or rollback
   - Deploy to Cloud Run
   - Verify resolution

5. Recovery (< 2 hours)
   - Verify all services operational
   - Check data integrity
   - Monitor for recurrence

6. Post-Mortem (within 48 hours)
   - Document timeline
   - Identify root cause
   - Create action items
```

---

## Incident Types and Procedures

### P0: Service Down (HTTP 000 / 5xx)

**Symptoms**:
- Health check returns non-200 or times out
- Deployment doctor shows FAIL
- Users cannot access application

**Common Causes & Fixes**:

**1. Container won't start (image pull failure)**
```bash
# Check if the latest revision is healthy
gcloud run revisions list --service=portal-server --region=europe-west9 --project=$PROJECT_ID --limit=3

# Check revision logs for startup errors
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.revision_name="REVISION_NAME"' \
  --project=$PROJECT_ID --limit=20
```

If image pull fails (GAR/GHCR issue):
```bash
# Verify image exists in GAR
gcloud artifacts docker images list europe-west9-docker.pkg.dev/cure-hht-admin/ghcr-remote --limit=5

# Check GAR remote repo auth (Secret Manager)
gcloud secrets list --project=cure-hht-admin --filter="name:ghcr"
```

**2. Cold start failure (min-instances=0)**
```bash
# Temporarily set min instances to 1 to keep service warm
gcloud run services update portal-server \
  --region=europe-west9 --project=$PROJECT_ID \
  --min-instances=1
```

**3. Database unreachable**
```bash
# Check Cloud SQL status
gcloud sql instances describe $INSTANCE_NAME --project=$PROJECT_ID --format='value(state)'

# Check VPC connector
gcloud compute networks vpc-access connectors describe $CONNECTOR_NAME \
  --region=europe-west9 --project=$PROJECT_ID
```

**4. Rollback to previous revision**
```bash
# List recent healthy revisions
gcloud run revisions list --service=portal-server --region=europe-west9 \
  --project=$PROJECT_ID --format='table(name,active,created)'

# Route 100% traffic to a known-good revision
gcloud run services update-traffic portal-server \
  --region=europe-west9 --project=$PROJECT_ID \
  --to-revisions=REVISION_NAME=100
```

---

### P0: Security Breach

**Symptoms**:
- Unauthorized access detected in Cloud Logging
- Audit trail anomalies
- Suspicious auth patterns in `auth_attempts_total` metric

**Immediate Actions (< 5 minutes)**:
- **DO NOT** discuss publicly
- Create CONFIDENTIAL Linear ticket
- Notify Security Lead

**Containment**:
```bash
# Capture logs before they rotate
gcloud logging read \
  'resource.type="cloud_run_revision" AND timestamp>="TIME_OF_INCIDENT"' \
  --project=$PROJECT_ID --limit=5000 --format=json > incident-logs-$(date +%s).json

# Disable compromised user in Identity Platform
gcloud identity-platform accounts delete USER_UID --project=$PROJECT_ID

# Rotate Doppler secrets if compromised
doppler secrets set KEY=NEW_VALUE --project=hht-diary --config=ENVIRONMENT
```

---

### P1: Feature Broken (e.g., Questionnaire Send Fails)

**Symptoms**:
- API returns 500 for specific operations
- OTel traces show errors in specific handlers
- `questionnaire_operations_total` metric shows failures

**Investigation**:
```bash
# Check structured logs for the specific handler
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="portal-server" AND jsonPayload.message:"sendQuestionnaireHandler" AND severity>=WARNING' \
  --project=$PROJECT_ID --limit=20 --format='table(timestamp,jsonPayload.message,jsonPayload.error)'

# Check FCM notification failures
gcloud logging read \
  'resource.type="cloud_run_revision" AND jsonPayload.message:"FCM" AND severity>=WARNING' \
  --project=$PROJECT_ID --limit=20

# Check auth failures
gcloud logging read \
  'resource.type="cloud_run_revision" AND jsonPayload.message:"Auth failed"' \
  --project=$PROJECT_ID --limit=20 --format='table(timestamp,jsonPayload.reason)'
```

---

### P2: Performance Degradation

**Symptoms**:
- `http_request_duration_seconds` histogram shows elevated latencies
- `database_query_duration_seconds` shows slow queries
- Health check response time > 2s

**Investigation**:
```bash
# Check Cloud Run instance count and CPU
gcloud run services describe portal-server --region=europe-west9 --project=$PROJECT_ID \
  --format='json(status.traffic,spec.template.spec.containers[0].resources)'

# Check database performance
gcloud sql operations list --instance=$INSTANCE_NAME --project=$PROJECT_ID --limit=5

# Kill slow queries
gcloud sql connect $INSTANCE_NAME --user=postgres --project=$PROJECT_ID <<'SQL'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '30 seconds';
SQL
```

---

## Tools and Access

### Required for On-Call

- [ ] `gcloud` CLI authenticated (`gcloud auth login`)
- [ ] Doppler CLI authenticated (`doppler login`)
- [ ] GitHub CLI authenticated (`gh auth login`)
- [ ] Access to GCP Console for the target project
- [ ] Deployment doctor scripts (`apps/*/tool/deployment-doctor.sh`)
- [ ] Linear access for incident tickets

### Key GCP Resources

| Resource | How to Find |
| --- | --- |
| Cloud Run services | `gcloud run services list --region=europe-west9 --project=$PROJECT_ID` |
| Cloud SQL instances | `gcloud sql instances list --project=$PROJECT_ID` |
| Cloud Logging | Console: Logging > Logs Explorer |
| Cloud Error Reporting | Console: Error Reporting |
| Secret Manager | `gcloud secrets list --project=cure-hht-admin` |
| Artifact Registry | Console: Artifact Registry > ghcr-remote |

### OTel Observability Signals

The platform uses OpenTelemetry for all three signal types:

| Signal | What It Shows | Where to Find |
| --- | --- | --- |
| **Traces** | Request flow across handlers, DB queries, FCM sends | Cloud Trace (if collector deployed) or `x-trace-id` response header |
| **Logs** | Structured JSON with trace correlation | Cloud Logging (`jsonPayload.severity`, `jsonPayload.message`) |
| **Metrics** | `http_requests_total`, `auth_attempts_total`, `fcm_notifications_total`, `database_query_duration_seconds` | Cloud Monitoring custom metrics (if collector deployed) |

---

## Post-Mortem Process

### When Required
- **Required**: All P0 and P1 incidents
- **Optional**: P2 incidents with interesting learnings

### Template

1. **Incident Summary**: Date, duration, severity, services affected, user impact
2. **Timeline**: Chronological events from detection to resolution
3. **Root Cause**: What caused it? Why wasn't it prevented?
4. **What Went Well**: Positive aspects of response
5. **What Went Poorly**: Delays, gaps, missing tools
6. **Action Items**: Preventative measures with owners and due dates

### Meeting
- **Timing**: Within 48 hours of resolution
- **Attendees**: Incident responders, Tech Lead
- **Duration**: 30-60 minutes
- **Output**: Action items in Linear with due dates

---

## Change History

| Date | Version | Author | Changes |
| --- | --- | --- | --- |
| 2025-01-27 | 1.0 | Claude | Initial runbook (Supabase/Sentry/Better Uptime) |
| 2026-04-08 | 2.0 | Claude | Complete rewrite for GCP/Cloud Run/OTel stack |
