# Daily Operations Playbook

**Version**: 2.0
**Audience**: Operations (SRE, DevOps, On-Call Engineers)
**Last Updated**: 2025-11-24
**Status**: Active

> **See**: ops-deployment.md for deployment procedures
> **See**: ops-database-migration.md for schema change procedures
> **See**: ops-security.md for security operations
> **See**: prd-architecture-multi-sponsor.md for architecture overview

---

## Executive Summary

Daily operational procedures, monitoring, incident response, and routine maintenance for the multi-sponsor clinical diary system. Each sponsor operates an independent GCP project with Cloud SQL, Identity Platform, and Cloud Run services requiring separate monitoring and maintenance.

**Architecture Context**: Multi-sponsor deployment with per-sponsor GCP projects
**Monitoring Approach**: Cloud Monitoring per project + aggregated multi-sponsor view
**On-Call Model**: 24/7 coverage for production incidents
**SLA Targets**:
- Portal uptime: 99.9% (43 minutes downtime/month)
- Mobile sync success rate: 99.5%
- API response time: <500ms (p95)
- Database query time: <100ms (p95)

---

## Daily Health Checks

### Morning Checklist (Start of Business Day)

**Run Time**: 9:00 AM local time (automated + manual review)

#### 1. System Health Dashboard Review

**GCP Console** (per sponsor project):

```bash
# List all sponsor GCP projects
gcloud projects list --filter="labels.app=clinical-diary"

# For each sponsor project, check:
# - Cloud Run service health
# - Cloud SQL instance status
# - Identity Platform metrics
# - Cloud Monitoring alerts
```

**Metrics to Review**:
- [ ] Cloud Run requests (last 24h): Check for anomalies
- [ ] Cloud SQL CPU usage: <80% average
- [ ] Cloud SQL memory usage: <90%
- [ ] Cloud SQL disk usage: <80%
- [ ] Cloud Run errors: <1% of requests
- [ ] Identity Platform auth failures: <5% of attempts

#### 2. Portal Accessibility Check

**Automated Check** (runs every 5 minutes via Cloud Monitoring uptime checks):

```bash
# Check each sponsor portal
curl -I https://orion-portal.clinicaldiary.com
curl -I https://andromeda-portal.clinicaldiary.com

# Expected: HTTP 200, <2 second response time
```

**Manual Spot Check**:
- [ ] Portal loads without errors
- [ ] Login functional
- [ ] Dashboard displays data
- [ ] No console errors

#### 3. Mobile App Sync Status

**Query per sponsor** (via Cloud SQL Proxy):

```sql
-- Check sync activity last 24 hours
SELECT
  COUNT(DISTINCT patient_id) as active_users,
  COUNT(*) as total_syncs,
  AVG(EXTRACT(EPOCH FROM (server_timestamp - client_timestamp))) as avg_sync_delay_seconds
FROM record_audit
WHERE server_timestamp > NOW() - INTERVAL '24 hours';

-- Expected: avg_sync_delay_seconds < 5
```

**Alerts**:
- If `active_users` drops >20% from previous day → investigate
- If `avg_sync_delay_seconds` >10 → check database performance

# REQ-o00005: Audit Trail Monitoring

**Level**: Ops | **Implements**: p00004, p00010, p00011 | **Status**: Active

Operations SHALL continuously monitor audit trail integrity, ensuring all clinical data changes are properly recorded and tamper-proof chain remains intact.

Monitoring SHALL include:
- Automated checks for audit trail completeness
- Verification of event chain integrity (no orphaned events)
- Detection of missing or corrupted audit records
- Alerts for audit trail anomalies
- Regular audit log review and analysis

**Rationale**: Implements event sourcing (p00004) and compliance requirements (p00010, p00011) through operational monitoring. Continuous validation ensures audit trails remain trustworthy for regulatory submission.

**Acceptance Criteria**:
- Daily automated audit trail integrity checks
- Alerts triggered for any integrity violations
- All data changes have corresponding audit events
- Event chain links validated (parent_audit_id relationships)
- Monitoring dashboards show audit trail health status

*End* *Audit Trail Monitoring* | **Hash**: f48b8b6b
---

#### 4. Audit Trail Integrity

**Verification Script** (per sponsor):

```sql
-- Verify audit trail completeness
SELECT
  COUNT(*) as total_events,
  COUNT(DISTINCT parent_audit_id) + 1 as chain_length,
  COUNT(CASE WHEN parent_audit_id IS NULL THEN 1 END) as orphaned_events
FROM record_audit;

-- Expected: orphaned_events = 0 or 1 (genesis event)
```

#### 5. Backup Verification

**Cloud SQL Automatic Backups**:

```bash
# Check last backup timestamp
gcloud sql backups list --instance=prod-instance --project=sponsor-project --limit=5

# Expected: Within last 6 hours
# Verify backup size is reasonable (not zero, not unexpectedly large)
```

**Manual Backup Check** (weekly):

```bash
# Point-in-time recovery test to staging
gcloud sql instances clone prod-instance staging-test-instance \
  --project=sponsor-project \
  --point-in-time="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)"

# Run smoke tests against restored instance
flutter test integration_test/smoke_test.dart --dart-define=ENV=staging
```

---

## Monitoring Dashboards

### Cloud Monitoring Dashboard

**Location**: GCP Console → Monitoring → Dashboards

**Key Dashboards**:

1. **Overview**:
   - Cloud Run request count and latency
   - Cloud SQL CPU/memory
   - Cloud SQL connections
   - Error rates

2. **Logs**:
   - Cloud Logging (API logs, app logs)
   - Cloud SQL logs (slow queries, errors)
   - Cloud Run logs

3. **Uptime**:
   - Portal health checks
   - API endpoint checks

### Custom Monitoring (Cloud Monitoring)

**Dashboards**:

1. **Multi-Sponsor Overview**:
   - All sponsors on single dashboard
   - Cloud Run uptime per sponsor
   - Error rates per sponsor
   - User activity per sponsor

2. **Per-Sponsor Deep Dive**:
   - Detailed metrics for single sponsor
   - Slow query analysis (Cloud SQL Insights)
   - User session duration
   - Sync conflict rate

3. **Mobile App Metrics**:
   - App crashes (via Firebase Crashlytics)
   - Sync success/failure rate
   - Offline duration
   - Device types

4. **Compliance Metrics**:
   - Audit trail completeness
   - RLS policy enforcement
   - Failed authorization attempts
   - Suspicious access patterns

---

## Alerting Rules

### Critical Alerts (Page On-Call Immediately)

**Cloud Monitoring Alerts** (configure per project):

1. **Database Down**:
   - Trigger: Cloud SQL instance unreachable for >1 minute
   - Action: Page on-call, follow incident response runbook

2. **Cloud Run Error Rate Spike**:
   - Trigger: Error rate >5% over 5 minutes
   - Action: Page on-call, check logs

3. **Disk Usage Critical**:
   - Trigger: Cloud SQL disk >90% full
   - Action: Page on-call, expand storage immediately

4. **Backup Failure**:
   - Trigger: Backup failed or missing >12 hours
   - Action: Page on-call, investigate and run manual backup

### Warning Alerts (Review During Business Hours)

5. **High Database CPU**:
   - Trigger: CPU >80% for >30 minutes
   - Action: Investigate slow queries, consider scaling

6. **High Connection Count**:
   - Trigger: Connections >80% of max for >15 minutes
   - Action: Review connection usage, check for leaks

7. **Cloud Run Service Errors**:
   - Trigger: Error rate >2% over 15 minutes
   - Action: Check Cloud Run logs, investigate EDC connectivity (proxy mode)

8. **Sync Conflicts Increasing**:
   - Trigger: Conflict rate >5% of syncs
   - Action: Investigate multi-device usage patterns, check sync logic

### Informational Alerts (Email/Slack)

9. **Low User Activity**:
   - Trigger: Daily active users <50% of average
   - Action: Verify no outage, inform sponsor of low engagement

10. **Unusual Access Patterns**:
    - Trigger: Login from new country, unusual hours
    - Action: Security review, verify legitimate access

---

## Incident Response Runbooks

### Runbook 1: Portal Down

**Symptoms**: Portal returns 5xx errors, users cannot access

**Response Steps**:

1. **Verify Outage** (2 minutes):
   ```bash
   # Check portal status
   curl -I https://orion-portal.clinicaldiary.com

   # Check Cloud Run service status
   gcloud run services describe portal \
     --project=sponsor-project \
     --region=us-central1
   ```

2. **Check Cloud Run Logs** (3 minutes):
   ```bash
   # View recent errors
   gcloud run services logs tail portal \
     --project=sponsor-project \
     --region=us-central1

   # Or via Cloud Logging
   gcloud logging read "resource.type=cloud_run_revision AND severity>=ERROR" \
     --project=sponsor-project \
     --limit=50
   ```

3. **Check Cloud SQL Backend** (3 minutes):
   ```bash
   # Check Cloud SQL instance status
   gcloud sql instances describe prod-instance --project=sponsor-project

   # Expected: state: RUNNABLE
   ```

4. **Rollback if Needed** (5 minutes):
   ```bash
   # Route traffic to previous revision
   gcloud run services update-traffic portal \
     --project=sponsor-project \
     --region=us-central1 \
     --to-revisions=PREVIOUS_REVISION=100
   ```

5. **Escalate if Unresolved** (10 minutes):
   - Contact GCP support (if on support plan)
   - Post in team Slack channel
   - Update status page

**Resolution Time Target**: 15 minutes

### Runbook 2: Database Performance Degradation

**Symptoms**: Slow queries, high CPU, timeouts

**Response Steps**:

1. **Identify Slow Queries** (3 minutes):
   ```sql
   -- Find slowest queries (requires pg_stat_statements)
   SELECT
     query,
     calls,
     total_time,
     mean_time
   FROM pg_stat_statements
   ORDER BY mean_time DESC
   LIMIT 10;
   ```

2. **Check Active Connections** (2 minutes):
   ```sql
   SELECT
     COUNT(*) as connection_count,
     state,
     wait_event_type
   FROM pg_stat_activity
   GROUP BY state, wait_event_type;
   ```

3. **Kill Long-Running Queries** (if blocking) (2 minutes):
   ```sql
   -- Find queries running >5 minutes
   SELECT pid, query_start, state, query
   FROM pg_stat_activity
   WHERE state != 'idle'
     AND query_start < NOW() - INTERVAL '5 minutes';

   -- Kill if necessary (use with caution!)
   SELECT pg_terminate_backend(pid);
   ```

4. **Review Recent Changes** (5 minutes):
   - Check recent deployments
   - Review migration history
   - Check for missing indexes

5. **Scale if Needed** (10 minutes):
   ```bash
   # Increase Cloud SQL tier
   gcloud sql instances patch prod-instance \
     --project=sponsor-project \
     --tier=db-custom-4-15360

   # Enable Query Insights if not already
   gcloud sql instances patch prod-instance \
     --project=sponsor-project \
     --insights-config-query-insights-enabled
   ```

**Resolution Time Target**: 20 minutes

### Runbook 3: Mobile App Sync Failures

**Symptoms**: Users report data not syncing, sync error rate elevated

**Response Steps**:

1. **Check Error Logs** (3 minutes):
   ```bash
   # Cloud Run API logs
   gcloud logging read "resource.type=cloud_run_revision AND severity>=WARNING" \
     --project=sponsor-project \
     --limit=100
   ```

2. **Verify API Accessibility** (2 minutes):
   ```bash
   # Test API endpoint
   curl -X GET https://api-sponsor.example.com/health

   # Expected: HTTP 200
   # NOT: timeout, 5xx errors
   ```

3. **Check RLS Policies** (5 minutes):
   ```sql
   -- Verify RLS enabled
   SELECT tablename, rowsecurity
   FROM pg_tables
   WHERE schemaname = 'public';

   -- Test policy for specific user
   SET app.user_id = 'user-uuid-here';
   SET app.role = 'USER';
   SELECT * FROM record_audit WHERE patient_id = 'user-uuid-here';
   ```

4. **Review Recent Schema Changes** (3 minutes):
   - Check migration history
   - Verify triggers still functional
   - Check for breaking changes

5. **Mobile App Version Check** (2 minutes):
   - Verify users on latest version
   - Check for known bugs in current version
   - Consider hotfix release if widespread

**Resolution Time Target**: 15 minutes

### Runbook 4: EDC Sync Failure (Proxy Mode)

**Symptoms**: Cloud Run EDC sync service errors, data not appearing in EDC system

**Response Steps**:

1. **Check Cloud Run Logs** (3 minutes):
   ```bash
   # View EDC sync service logs
   gcloud run services logs tail edc-sync \
     --project=sponsor-project \
     --region=us-central1
   ```

2. **Verify EDC API Connectivity** (2 minutes):
   ```bash
   # Test EDC endpoint
   curl -I https://rave.mdsol.com/api/v1/status \
     -H "Authorization: Bearer $EDC_API_KEY"

   # Expected: 200 OK
   ```

3. **Check Sync Position** (3 minutes):
   ```sql
   -- Find current sync position (last successfully synced event)
   SELECT
     audit_id,
     event_uuid,
     synced_at
   FROM edc_sync_log
   WHERE sync_status = 'SUCCESS'
   ORDER BY audit_id DESC
   LIMIT 1;

   -- Check if any event is currently failing (blocking subsequent events)
   SELECT
     sync_id,
     audit_id,
     event_uuid,
     attempt_count,
     last_error,
     synced_at
   FROM edc_sync_log
   WHERE sync_status = 'FAILED'
   ORDER BY audit_id ASC  -- Shows blocking event (lowest audit_id)
   LIMIT 1;
   ```

4. **Monitor Sync Worker** (2 minutes):
   ```bash
   # Check worker health
   curl https://edc-sync-sponsor.run.app/health

   # View worker logs
   gcloud run services logs tail edc-sync \
     --project=sponsor-project \
     --region=us-central1
   ```

   **Note**: Worker automatically retries failed events with exponential backoff. No manual retry needed unless worker is stuck.

5. **Contact EDC Support** (if API down) (10 minutes):
   - Check EDC system status page
   - Contact sponsor's EDC administrator
   - Document outage for audit trail

**Resolution Time Target**: 20 minutes

### Runbook 5: Suspected Security Breach

**Symptoms**: Unusual access patterns, unauthorized data access, suspicious logins

**Response Steps**:

1. **Immediate Actions** (5 minutes):
   - Document initial observations (timestamps, user IDs, IP addresses)
   - DO NOT delete or modify audit logs
   - Notify security team immediately

2. **Isolate Affected Accounts** (5 minutes):
   ```bash
   # Disable user in Identity Platform
   gcloud identity-platform users update USER_UID \
     --project=sponsor-project \
     --disabled

   # Or via Firebase Admin SDK in Cloud Function
   ```

3. **Review Audit Trail** (10 minutes):
   ```sql
   -- Check all actions by user
   SELECT
     audit_id,
     operation,
     patient_id,
     created_by,
     server_timestamp,
     client_timestamp
   FROM record_audit
   WHERE created_by = 'suspicious-user-id'
   ORDER BY server_timestamp DESC;
   ```

4. **Check for Data Exfiltration** (10 minutes):
   - Review Cloud Logging for bulk data access
   - Check for export operations
   - Verify RLS policies were enforced

5. **Escalate to Security Team** (immediate):
   - Provide audit trail export
   - Document timeline of events
   - Preserve all logs (do not truncate)

6. **Notify Sponsor** (per incident response plan):
   - Inform sponsor security contact
   - Provide initial incident summary
   - Coordinate further investigation

**Resolution Time Target**: N/A (ongoing investigation)

**Follow-up**: See ops-security.md for complete security incident procedures

---

## Routine Maintenance Tasks

### Daily Tasks

**Automated** (no manual intervention):
- [ ] Cloud SQL automatic backups (configurable frequency)
- [ ] Log rotation (Cloud Logging)
- [ ] SSL certificate renewal (Cloud Run managed)

**Manual Review**:
- [ ] Review overnight alerts
- [ ] Check daily health dashboard
- [ ] Verify backup completion

### Weekly Tasks

**Mondays** (30 minutes):
- [ ] Review error logs for patterns
- [ ] Check database performance trends (Cloud SQL Insights)
- [ ] Review sync conflict rate
- [ ] Test backup restore (sample sponsor)
- [ ] Update on-call schedule

**Script**: `scripts/weekly_maintenance.sh`

```bash
#!/bin/bash
# Weekly maintenance script

echo "=== Weekly Maintenance: $(date) ==="

# 1. Generate weekly report
cloud-sql-proxy sponsor-project:us-central1:prod-instance --port=5432 &
sleep 3
psql -h 127.0.0.1 -U app_user -d clinical_diary -f scripts/weekly_report.sql > reports/weekly-$(date +%Y%m%d).txt

# 2. Check for unused indexes
psql -h 127.0.0.1 -U app_user -d clinical_diary -f scripts/unused_indexes.sql

# 3. Check database bloat
psql -h 127.0.0.1 -U app_user -d clinical_diary -f scripts/check_bloat.sql

# 4. Test backup restore (staging)
./scripts/test_backup_restore.sh staging

echo "=== Weekly Maintenance Complete ==="
```

### Monthly Tasks

**First Monday of Month** (2 hours):
- [ ] Review and update monitoring dashboards
- [ ] Security audit (review access logs)
- [ ] Performance tuning (analyze slow queries via Cloud SQL Insights)
- [ ] Capacity planning review
- [ ] Update documentation for any operational changes
- [ ] Review incident response effectiveness (postmortems)

**Script**: `scripts/monthly_maintenance.sh`

### Quarterly Tasks

**End of Quarter** (4 hours):
- [ ] GCP resource usage review (optimize costs)
- [ ] Disaster recovery test (full restore)
- [ ] Review and update incident runbooks
- [ ] SLA compliance review
- [ ] Compliance audit preparation
- [ ] Contract renewal review (GCP, external services)

---

## Log Analysis

### Useful Cloud Logging Queries

**Cloud Run Logs**:

```bash
# View last 100 API errors
gcloud logging read 'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --project=sponsor-project \
  --limit=100

# Track specific user's requests
gcloud logging read 'resource.type="cloud_run_revision" AND jsonPayload.user_id="abc123"' \
  --project=sponsor-project \
  --limit=50

# Slow requests (>1 second)
gcloud logging read 'resource.type="cloud_run_revision" AND httpRequest.latency>"1s"' \
  --project=sponsor-project \
  --limit=50
```

**Cloud SQL Logs**:

```bash
# View database logs
gcloud logging read 'resource.type="cloudsql_database"' \
  --project=sponsor-project \
  --limit=100

# Slow queries (enable pgAudit or use Cloud SQL Insights)
gcloud logging read 'resource.type="cloudsql_database" AND textPayload:"duration:"' \
  --project=sponsor-project \
  --limit=50
```

**Identity Platform Logs**:

```bash
# Authentication events
gcloud logging read 'resource.type="identitytoolkit.googleapis.com/Project"' \
  --project=sponsor-project \
  --limit=100
```

### Log Retention

**Cloud Logging Default**: 30 days
**Cloud Logging with Log Sink**: Configurable (export to Cloud Storage)
**Compliance Archive**: 7 years (export to Cloud Storage with retention policy)

**Export Script**:

```bash
#!/bin/bash
# Export logs for archival (configure as Cloud Logging sink)

PROJECT_ID="sponsor-project"
BUCKET="gs://clinical-diary-logs-archive-${PROJECT_ID}"

# Create log sink for long-term archival
gcloud logging sinks create compliance-archive \
  "${BUCKET}" \
  --project=${PROJECT_ID} \
  --log-filter='resource.type="cloud_run_revision" OR resource.type="cloudsql_database"'

echo "Log sink created - logs will automatically export to ${BUCKET}"
```

---

## Performance Monitoring

### Key Performance Indicators (KPIs)

**Target Metrics**:

| Metric | Target | Alert Threshold |
| --- | --- | --- |
| Portal uptime | 99.9% | <99.5% |
| API response time (p95) | <500ms | >1000ms |
| Database query time (p95) | <100ms | >300ms |
| Mobile sync success rate | 99.5% | <98% |
| Cloud Run success rate | 99% | <97% |
| Backup success rate | 100% | <100% |

### Performance Analysis Queries

**Slow Query Analysis** (via Cloud SQL Insights or pg_stat_statements):

```sql
-- Top 10 slowest queries
SELECT
  substring(query, 1, 100) as query_preview,
  calls,
  total_time,
  mean_time,
  max_time
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

**Index Usage Analysis**:

```sql
-- Unused indexes (candidates for removal)
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan as index_scans
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexname NOT LIKE '%pkey';
```

**Table Bloat Check**:

```sql
-- Check for table bloat
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Performance Tuning Actions

**If queries slow**:
1. Add missing indexes
2. Optimize query structure
3. Enable query plan caching
4. Consider materialized views

**If database CPU high**:
1. Scale up Cloud SQL tier
2. Add read replicas
3. Optimize expensive queries
4. Implement caching layer

**If disk usage high**:
1. Archive old audit records (after 2 years)
2. Clean up deleted records (vacuum)
3. Expand storage capacity
4. Compress JSONB fields

---

## On-Call Procedures

### On-Call Schedule

**Coverage**: 24/7/365
**Rotation**: Weekly (Monday 9am to Monday 9am)
**Handoff**: Monday morning standup

**On-Call Responsibilities**:
- Respond to critical alerts within 15 minutes
- Resolve incidents or escalate within 1 hour
- Document all incidents in incident log
- Perform daily health checks during business hours
- Participate in weekly maintenance tasks

### Escalation Path

**Level 1**: On-Call Engineer (primary responder)
**Level 2**: Senior DevOps Engineer (if L1 cannot resolve within 1 hour)
**Level 3**: Platform Architect (for architecture decisions)
**Level 4**: CTO (for business-critical decisions)

**External Escalation**:
- GCP Support: Via GCP Console (depends on support plan)
- Sponsor Contact: (per sponsor contact list)

### Incident Documentation

**For each incident**:
1. Create incident ticket (Jira/GitHub Issues)
2. Document timeline of events
3. Record actions taken
4. Note resolution time
5. Identify root cause
6. Create postmortem (for major incidents)

**Postmortem Template**:

```markdown
# Incident Postmortem: [Brief Title]

**Date**: 2025-10-24
**Severity**: Critical / High / Medium
**Duration**: 45 minutes
**Impact**: 500 users unable to sync

## Timeline

- 14:30: Alert triggered (high API error rate)
- 14:32: On-call engineer paged
- 14:35: Investigation started
- 14:40: Root cause identified (database connection pool exhausted)
- 14:50: Mitigation applied (increased pool size)
- 15:15: Incident resolved

## Root Cause

Database connection pool exceeded due to...

## Resolution

Increased Cloud SQL max connections, added monitoring for connection usage.

## Action Items

- [ ] Review connection pooling configuration (Owner: DevOps)
- [ ] Add connection usage alerts (Owner: SRE)
- [ ] Update incident runbook (Owner: On-Call)

## Lessons Learned

...
```

---

## Communication Procedures

### Status Page Updates

**Tool**: Cloud Monitoring uptime dashboard or external status page service

**Update Policy**:
- Critical incidents: Update immediately
- Degraded performance: Update within 15 minutes
- Scheduled maintenance: Announce 48 hours in advance

**Template**:

```
[2025-10-24 14:35 UTC] Investigating
We are currently investigating elevated API error rates affecting the Orion portal.

[2025-10-24 14:50 UTC] Identified
We have identified the issue as database connection pool exhaustion and are implementing a fix.

[2025-10-24 15:15 UTC] Resolved
The issue has been resolved. All services are operating normally.
```

### Sponsor Communication

**Contact Channels**:
- Email: sponsor-ops@clinicaldiary.com
- Slack: #sponsor-orion-ops (private channel per sponsor)
- Phone: Emergency contact list (for critical incidents)

**Communication Policy**:
- Notify sponsor of incidents affecting their users within 30 minutes
- Provide hourly updates during major incidents
- Send postmortem within 48 hours of resolution

---

## Backup Verification Procedures

# REQ-o00008: Backup and Retention Policy

**Level**: Ops | **Implements**: p00012 | **Status**: Active

Clinical trial data and audit trails SHALL be backed up regularly with retention policies meeting regulatory requirements (minimum 7 years), ensuring data recoverability and compliance.

Backup and retention SHALL include:
- Automated database backups (Cloud SQL automated backups)
- Point-in-time recovery capability for 30 days (Cloud SQL PITR)
- Long-term archive retention per study requirements
- Regular backup restore testing (weekly)
- Disaster recovery procedures tested quarterly

**Rationale**: Implements data retention requirements (p00012) through operational backup policies. Regular testing ensures backups are actually restorable, not just created.

**Acceptance Criteria**:
- Automated backups run without failure
- Backup retention meets or exceeds study-specific requirements
- Weekly backup restore tests to staging environment
- Quarterly disaster recovery drills documented
- Backup integrity verification automated

*End* *Backup and Retention Policy* | **Hash**: 6268dd48
---

### Automated Backups

**Cloud SQL Automatic Backups**:
- Frequency: Configurable (recommended: every 4-6 hours)
- Retention: 30 days (point-in-time recovery)
- Storage: Encrypted, regional (optionally cross-regional)

**Verify backup configuration**:
```bash
gcloud sql instances describe prod-instance \
  --project=sponsor-project \
  --format="yaml(settings.backupConfiguration)"
```

### Manual Backup Verification

**Weekly Test** (every Monday):

```bash
#!/bin/bash
# Test backup restore to staging

PROJECT_ID="sponsor-project"
PROD_INSTANCE="prod-instance"
STAGING_INSTANCE="staging-restore-test"

echo "1. Clone production to staging (point-in-time)"
gcloud sql instances clone $PROD_INSTANCE $STAGING_INSTANCE \
  --project=$PROJECT_ID \
  --point-in-time="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)"

echo "2. Wait for clone to complete"
gcloud sql operations list --instance=$STAGING_INSTANCE --project=$PROJECT_ID --limit=1

echo "3. Run smoke tests"
flutter test integration_test/smoke_test.dart --dart-define=ENV=staging

if [ $? -eq 0 ]; then
  echo "✓ Backup restore test PASSED"
  # Clean up test instance
  gcloud sql instances delete $STAGING_INSTANCE --project=$PROJECT_ID --quiet
else
  echo "✗ Backup restore test FAILED - investigate immediately"
  exit 1
fi
```

### Disaster Recovery Test

**Quarterly** (full DR drill):

1. Simulate complete GCP project failure
2. Create new GCP project (or use DR project)
3. Restore Cloud SQL from backup
4. Deploy database schema
5. Deploy Cloud Run services
6. Configure Identity Platform
7. Deploy portal
8. Test end-to-end functionality

**Success Criteria**: Full restore within 4 hours

---

## References

- **Deployment Procedures**: ops-deployment.md
- **Database Migrations**: ops-database-migration.md
- **Security Operations**: ops-security.md
- **Multi-Sponsor Architecture**: prd-architecture-multi-sponsor.md
- **Database Implementation**: dev-database.md
- **Cloud SQL Documentation**: https://cloud.google.com/sql/docs
- **Cloud Run Documentation**: https://cloud.google.com/run/docs
- **Cloud Monitoring Documentation**: https://cloud.google.com/monitoring/docs

---

**Document Status**: Active operations playbook
**Review Cycle**: Monthly or after major incidents
**Owner**: DevOps Team / SRE
