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

## Incident Response Team

| Role | Responsibilities | Contact |
| --- | --- | --- |
| **Primary On-Call** | First responder, incident commander | Rotates weekly |
| **Secondary On-Call** | Backup, escalation | Rotates weekly |
| **Tech Lead** | Technical escalation, major decisions | Fixed |
| **Product Owner** | Stakeholder communication | Fixed |
| **Security Lead** | Security incidents | Fixed |

**On-Call Schedule**: See Better Uptime dashboard

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
- Database unreachable
- Authentication service down

**Response Time**: < 5 minutes

**Procedure**:

1. **Acknowledge Alert** (< 1 minute):
   - Click alert link to acknowledge
   - Prevents escalation to secondary on-call

2. **Assess Scope** (< 2 minutes):
   - Check Better Uptime dashboard: Which services are down?
   - Check Sentry dashboard: Are errors spiking?
   - Check Supabase status page: Is it a platform issue?

3. **Create Incident Ticket** (< 1 minute):
   ```bash
   gh issue create \
     --title "[P0 INCIDENT] Production Down - $(date)" \
     --body "Detected: $(date)\nServices affected: [list]\nOn-call: @username" \
     --label "incident,P0,production"
   ```

4. **Notify Team** (< 1 minute):
    - Post in `#production-alerts` Slack channel:
      ```
      @channel P0 INCIDENT: Production is down
      Services affected: [list]
      Incident commander: @username
      War room: [Zoom/Google Meet link]
      Status: Investigating
      ```

5. **Start War Room** (< 5 minutes):
    - Start video call
    - Invite: Secondary on-call, Tech Lead
    - Share screen for collaboration

6. **Investigate Root Cause** (< 10 minutes):
    - Check recent deployments:
      ```bash
      gh run list --workflow=deploy-production.yml --limit 5
      ```
    - Check Supabase logs:
      ```bash
      supabase logs --project-ref [prod-id] --limit 100
      ```
    - Check Sentry for new errors:
        - Go to Sentry dashboard
        - Filter by last 30 minutes
        - Look for new error spikes

7. **Decide on Mitigation**:
    - **Option A: Rollback** (if recent deployment caused issue):
      ```bash
      gh workflow run rollback.yml \
        --ref main \
        -f environment=production \
        -f target_version=[previous-version] \
        -f reason="P0 incident - production down"
      ```
    - **Option B: Hotfix** (if critical bug needs immediate fix):
        - Create hotfix branch
        - Implement minimal fix
        - Deploy to production
    - **Option C: External Issue** (if Supabase or third-party down):
        - Check status page
        - Communicate issue to users
        - Monitor for resolution

8. **Verify Resolution** (< 5 minutes after mitigation):
    - Check Better Uptime: Are all monitors green?
    - Test critical user flow manually
    - Check Sentry: Are errors resolved?

9. **Update Status Page**:
    - Log into Better Uptime
    - Update incident: "Investigating" → "Identified" → "Monitoring" → "Resolved"
    - Add incident timeline and resolution notes

10. **Monitor for Recurrence** (30 minutes):
    - Watch dashboards closely
    - Verify no new errors
    - Confirm uptime stable

**Post-Incident**:
- Schedule post-mortem within 24 hours
- Document timeline in incident ticket
- Create follow-up action items

---

### P1: Major Feature Broken

**Symptoms**:
- User authentication failing
- Diary entry creation failing
- Data sync issues
- Critical API endpoints returning errors

**Response Time**: < 15 minutes

**Procedure**:

1. **Acknowledge and Assess** (< 5 minutes):
    - Acknowledge alert
    - Determine which feature is broken
    - Estimate user impact (% of users affected)

2. **Create Incident Ticket**:
   ```bash
   gh issue create \
     --title "[P1 INCIDENT] [Feature] Broken - $(date)" \
     --body "Feature: [name]\nImpact: [description]\nUsers affected: [estimate]" \
     --label "incident,P1,production"
   ```

3. **Notify Team**:
    - Post in `#production-alerts`:
      ```
      P1 INCIDENT: [Feature] is broken
      Users affected: [estimate]
      Investigating: @username
      Status: Investigating
      ```

4. **Investigate** (< 10 minutes):
    - Check Sentry for errors related to feature
    - Review recent code changes to feature
    - Test feature manually in staging/production

5. **Implement Fix**:
    - **Option A: Rollback** (if recent deployment broke feature)
    - **Option B: Hotfix** (if simple fix available)
    - **Option C: Feature flag** (temporarily disable feature):
      ```bash
      # Update feature flag in Doppler
      doppler secrets set FEATURE_X_ENABLED=false --project clinical-diary --config prd
      ```

6. **Verify and Communicate**:
    - Test feature after fix
    - Update status page
    - Post resolution in Slack


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
- Data exfiltration detected
- Suspicious authentication activity

**Immediate Actions (< 5 minutes)**:
- **DO NOT** discuss publicly
- Create CONFIDENTIAL Linear ticket
- Notify Security Lead

**Response Time**: Immediate (< 1 minute to start response)

**Procedure**:

1. **Immediate Actions** (< 5 minutes):
    - **DO NOT** investigate publicly (no Slack announcements)
    - Create CONFIDENTIAL incident ticket (restricted access)
    - Notify Security Lead immediately (phone call)
    - Preserve evidence:
      ```bash
      # Capture current logs (do not modify)
      supabase logs --project-ref [prod-id] --limit 1000 > incident-logs-$(date +%s).log
 
      # Capture audit trail snapshot
      psql $DATABASE_URL -c "SELECT * FROM audit_trail WHERE created_at > NOW() - INTERVAL '1 hour'" > audit-snapshot.csv
      ```

2. **Contain Threat** (< 15 minutes):
    - Rotate compromised credentials:
      ```bash
      # Rotate service keys in Doppler
      doppler secrets set SUPABASE_SERVICE_KEY="[new-key]" --project clinical-diary --config prd
      ```
    - Disable compromised user accounts:
      ```sql
      UPDATE auth.users SET disabled = true WHERE id = '[compromised-user-id]';
      ```
    - If widespread, consider temporary service shutdown (consult Tech Lead + Security Lead)

3. **Investigate** (< 1 hour):
    - Review audit trail for unauthorized actions:
      ```sql
      SELECT * FROM audit_trail
      WHERE user_id = '[compromised-user]'
      ORDER BY created_at DESC
      LIMIT 1000;
      ```
    - Check Sentry for suspicious errors/activities
    - Review authentication logs:
      ```bash
      supabase logs --project-ref [prod-id] --filter 'auth'
      ```
    - Identify scope of breach:
        - What data was accessed?
        - What actions were performed?
        - How many users affected?

4. **Notify Stakeholders**:
    - **Internal**: Tech Lead, Product Owner, Legal team
    - **External (if required)**:
        - Users (if PHI compromised): Email within 24 hours
        - Regulators (if FDA compliance breached): Report within 5 business days
        - Law enforcement (if criminal activity suspected)

5. **Remediate**:
    - Apply security patches
    - Reset affected user passwords
    - Restore data from backup if corrupted
    - Verify audit trail integrity

6. **Post-Incident**:
    - Full security audit
    - Mandatory post-mortem with Security Lead
    - Regulatory reporting if required
    - Update security procedures

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
- p95 response time >2 seconds
- Database queries slow
- Page load times increased
- Better Uptime shows increased latency
- `http_request_duration_seconds` histogram shows elevated latencies
- `database_query_duration_seconds` shows slow queries
- Health check response time > 2s

**Response Time**: < 30 minutes

**Procedure**:

1. **Assess Impact** (< 10 minutes):
    - Check Sentry performance dashboard
    - Identify affected endpoints/queries
    - Determine if degradation is widespread or localized

2. **Investigate** (< 20 minutes):
    - Check database connection pool:
      ```sql
      SELECT count(*) FROM pg_stat_activity;
      ```
    - Check for slow queries:
      ```sql
      SELECT pid, now() - pg_stat_activity.query_start AS duration, query
      FROM pg_stat_activity
      WHERE state = 'active' AND now() - pg_stat_activity.query_start > interval '5 seconds';
      ```
    - Check Supabase metrics dashboard for resource usage spikes

3. **Mitigate**:
    - Kill slow queries if necessary:
      ```sql
      SELECT pg_terminate_backend([pid]);
      ```
    - Scale up database if resource-constrained (Supabase dashboard)
    - Enable caching if not already enabled
    - Rate limit expensive endpoints temporarily

4. **Create Follow-up Task**:
    - If mitigation is temporary, create ticket for permanent fix
    - Example: Optimize slow query, add database index, implement caching


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

## Communication Templates

### Status Page Update - Investigating

```
We are currently investigating an issue affecting [service/feature].
Users may experience [specific symptoms].

We are actively working to resolve this issue and will provide updates as we learn more.

Last updated: [timestamp]
```

### Status Page Update - Identified

```
We have identified the root cause of the issue affecting [service/feature].
The issue is due to [brief explanation without technical jargon].

Our team is working on a fix and we expect to have this resolved within [timeframe].

Last updated: [timestamp]
```

### Status Page Update - Resolved

```
The issue affecting [service/feature] has been resolved.

Root cause: [brief explanation]
Resolution: [what was done]

All systems are now operating normally. We apologize for any inconvenience.

Last updated: [timestamp]
```

### User Email - Security Breach Notification

```
Subject: Important Security Notice - Clinical Diary

Dear Clinical Diary User,

We are writing to inform you of a security incident that may have affected your account.

What happened:
[Brief description of incident]

What information was affected:
[Specific data types]

What we are doing:
[Actions taken to secure the system]

What you should do:
1. Reset your password immediately
2. Enable two-factor authentication
3. Review your recent account activity

We take the security of your data very seriously and deeply regret this incident. If you have any questions, please contact our support team at security@clinical-diary.com.

Sincerely,
Clinical Diary Security Team
```

---

## Tools and Access

 
- [ ] `gcloud` CLI authenticated (`gcloud auth login`)
- [ ] Doppler CLI authenticated (`doppler login`)
- [ ] GitHub CLI authenticated (`gh auth login`)
- [ ] Access to GCP Console for the target project
- [ ] Deployment doctor scripts (`apps/*/tool/deployment-doctor.sh`)
- [ ] Linear access for incident tickets
- [ ] Doppler CLI installed and authenticated
- [ ] Access to incident call link (Zoom/Google Meet)

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


## On-Call Best Practices

### Before Your On-Call Shift

- [ ] Review recent incidents and resolutions
- [ ] Verify access to all required tools
- [ ] Test alerting (ensure phone/SMS work)
- [ ] Review this runbook
- [ ] Know how to escalate to secondary on-call and Tech Lead

### During Your On-Call Shift

- [ ] Acknowledge alerts within 5 minutes
- [ ] Keep phone/laptop nearby
- [ ] Update status page regularly during incidents
- [ ] Document actions in incident ticket
- [ ] Don't hesitate to escalate if needed

### After Resolving an Incident

- [ ] Update incident ticket with resolution
- [ ] Post resolution in Slack
- [ ] Update status page to "Resolved"
- [ ] Schedule post-mortem if P0 or P1
- [ ] Get rest (incidents are stressful)

---

## Escalation

### When to Escalate

- Incident is P0 and not resolved within 30 minutes
- Incident requires expertise you don't have
- Incident involves security breach
- Incident requires major decision (e.g., taking service offline)

### How to Escalate

1. **To Secondary On-Call**:
    - Better Uptime will auto-escalate if you don't acknowledge
    - Or manually call: See Better Uptime dashboard for phone number

2. **To Tech Lead**:
    - Call directly (see contact info in Better Uptime)
    - Explain situation concisely
    - Share incident ticket link

3. **To Security Lead** (security incidents only):
    - Call immediately
    - Do not investigate publicly
    - Preserve evidence

---

## Post-Mortem Process

### When to Conduct Post-Mortem

- **Required**: All P0 and P1 incidents
- **Optional**: P2 incidents with interesting learnings

### Template

1. **Incident Summary**: Date, duration, severity, services affected, user impact
2. **Timeline**: Chronological events from detection to resolution
3. **Root Cause**: What caused it? Why wasn't it prevented?
4. **What Went Well**: Positive aspects of response
5. **What Went Poorly**: Delays, gaps, missing tools
6. **Action Items**: Preventative measures with owners and due dates
7. **Lessons Learned**:
    - Key takeaways for team
   
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
