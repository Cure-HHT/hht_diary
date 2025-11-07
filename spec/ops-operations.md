# Daily Operations Playbook

**Version**: 1.0
**Audience**: Operations (SRE, DevOps, On-Call Engineers)
**Last Updated**: 2025-01-24
**Status**: Active

> **See**: ops-deployment.md for deployment procedures
> **See**: ops-database-migration.md for schema change procedures
> **See**: ops-security.md for security operations
> **See**: prd-architecture-multi-sponsor.md for architecture overview

---

## Executive Summary

Daily operational procedures, monitoring, incident response, and routine maintenance for the multi-sponsor clinical diary system. Each sponsor operates an independent Supabase instance requiring separate monitoring and maintenance.

**Architecture Context**: Multi-sponsor deployment with per-sponsor Supabase instances
**Monitoring Approach**: Per-sponsor dashboards + aggregated multi-sponsor view
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

**Supabase Dashboard** (per sponsor):

```bash
# List all sponsor Supabase projects
supabase projects list

# For each sponsor, check:
# - API uptime (should be 100% last 24h)
# - Database connections (should be <70% of pool)
# - Edge Function invocations (check error rate <1%)
# - Storage usage (alert if >80%)
```

**Metrics to Review**:
- [ ] API requests (last 24h): Check for anomalies
- [ ] Database CPU usage: <80% average
- [ ] Database memory usage: <90%
- [ ] Database disk usage: <80%
- [ ] Edge Function errors: <1% of invocations
- [ ] Authentication failures: <5% of attempts

#### 2. Portal Accessibility Check

**Automated Check** (runs every 5 minutes via monitoring service):

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

**Query per sponsor** (Supabase SQL):

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

**Supabase Automatic Backups**:

```bash
# Check last backup timestamp (via Supabase dashboard)
# Expected: Within last 6 hours

# Verify backup size is reasonable (not zero, not unexpectedly large)
```

**Manual Backup Check** (weekly):

```bash
# Restore latest backup to staging environment
supabase db restore --project-ref staging-xyz backup-latest.sql

# Run smoke tests against restored data
flutter test integration_test/smoke_test.dart --dart-define=ENV=staging
```

---

## Monitoring Dashboards

### Supabase Built-In Dashboard

**Location**: https://supabase.com/dashboard/project/{project-ref}

**Key Tabs**:

1. **Overview**:
   - API requests graph
   - Database CPU/memory
   - Active connections
   - Storage usage

2. **Logs**:
   - API logs (recent requests)
   - Database logs (slow queries, errors)
   - Edge Function logs

3. **Reports**:
   - Weekly usage summary
   - API usage by endpoint
   - Database query performance

### Custom Monitoring (Optional)

**Tools**: Grafana + Prometheus (if implemented)

**Dashboards**:

1. **Multi-Sponsor Overview**:
   - All sponsors on single dashboard
   - API uptime per sponsor
   - Error rates per sponsor
   - User activity per sponsor

2. **Per-Sponsor Deep Dive**:
   - Detailed metrics for single sponsor
   - Slow query analysis
   - User session duration
   - Sync conflict rate

3. **Mobile App Metrics**:
   - App crashes (via Firebase Crashlytics or Sentry)
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

**Supabase Alerts** (configure in dashboard):

1. **Database Down**:
   - Trigger: Database unreachable for >1 minute
   - Action: Page on-call, follow incident response runbook

2. **API Error Rate Spike**:
   - Trigger: Error rate >5% over 5 minutes
   - Action: Page on-call, check logs

3. **Disk Usage Critical**:
   - Trigger: Database disk >90% full
   - Action: Page on-call, expand storage immediately

4. **Backup Failure**:
   - Trigger: Backup failed or missing >12 hours
   - Action: Page on-call, investigate and run manual backup

### Warning Alerts (Review During Business Hours)

5. **High Database CPU**:
   - Trigger: CPU >80% for >30 minutes
   - Action: Investigate slow queries, consider scaling

6. **High Connection Count**:
   - Trigger: Connections >80% of pool for >15 minutes
   - Action: Review connection usage, check for leaks

7. **Edge Function Errors**:
   - Trigger: Error rate >2% over 15 minutes
   - Action: Check Edge Function logs, investigate EDC connectivity (proxy mode)

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

   # Check Netlify status page
   curl https://netlifystatus.com/api/v2/status.json
   ```

2. **Check Netlify Deployment** (3 minutes):
   - Login to Netlify dashboard
   - Check recent deployments for failures
   - Check build logs for errors

3. **Check Supabase Backend** (3 minutes):
   - Login to Supabase dashboard
   - Verify database is reachable
   - Check API logs for errors

4. **Rollback if Needed** (5 minutes):
   ```bash
   # Rollback to last working deployment
   netlify deploy:restore <previous-deploy-id>
   ```

5. **Escalate if Unresolved** (10 minutes):
   - Contact Netlify support
   - Post in team Slack channel
   - Update status page

**Resolution Time Target**: 15 minutes

### Runbook 2: Database Performance Degradation

**Symptoms**: Slow queries, high CPU, timeouts

**Response Steps**:

1. **Identify Slow Queries** (3 minutes):
   ```sql
   -- Find slowest queries
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
   - Upgrade Supabase plan (more CPU/memory)
   - Add read replicas (if available)
   - Enable connection pooling

**Resolution Time Target**: 20 minutes

### Runbook 3: Mobile App Sync Failures

**Symptoms**: Users report data not syncing, sync error rate elevated

**Response Steps**:

1. **Check Error Logs** (3 minutes):
   ```bash
   # Supabase API logs
   # Filter by status code 4xx, 5xx
   # Look for authentication failures, validation errors
   ```

2. **Verify API Accessibility** (2 minutes):
   ```bash
   # Test API endpoint
   curl -X POST https://abcd1234.supabase.co/rest/v1/record_audit \
     -H "apikey: ANON_KEY" \
     -H "Content-Type: application/json" \
     -d '{"test": true}'

   # Expected: 401 (auth required) or 200 (if test data valid)
   # NOT: timeout, 5xx errors
   ```

3. **Check RLS Policies** (5 minutes):
   ```sql
   -- Verify RLS enabled
   SELECT tablename, rowsecurity
   FROM pg_tables
   WHERE schemaname = 'public';

   -- Test policy for specific user
   SET ROLE authenticated;
   SET request.jwt.claim.sub = 'user-uuid-here';
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

**Symptoms**: Edge Function errors, data not appearing in EDC system

**Response Steps**:

1. **Check Edge Function Logs** (3 minutes):
   ```bash
   # View recent errors
   supabase functions logs edc_sync --tail=100
   ```

2. **Verify EDC API Connectivity** (2 minutes):
   ```bash
   # Test EDC endpoint
   curl -I https://rave.mdsol.com/api/v1/status \
     -H "Authorization: Bearer $EDC_API_KEY"

   # Expected: 200 OK
   ```

3. **Check Dead Letter Queue** (3 minutes):
   ```sql
   -- Check failed sync attempts
   SELECT
     audit_id,
     event_uuid,
     attempts,
     last_error,
     created_at
   FROM edc_sync_failures
   ORDER BY created_at DESC
   LIMIT 20;
   ```

4. **Retry Failed Syncs** (5 minutes):
   ```bash
   # Invoke Edge Function to retry
   curl -X POST https://abcd1234.supabase.co/functions/v1/edc_sync_retry \
     -H "Authorization: Bearer SERVICE_ROLE_KEY" \
     -d '{"audit_ids": [123, 124, 125]}'
   ```

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
   ```sql
   -- Disable user account
   UPDATE auth.users
   SET banned_until = NOW() + INTERVAL '24 hours'
   WHERE id = 'suspicious-user-id';

   -- Revoke all sessions
   DELETE FROM auth.sessions
   WHERE user_id = 'suspicious-user-id';
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
   - Review API logs for bulk data access
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
- [ ] Supabase automatic backups (every 6 hours)
- [ ] Log rotation
- [ ] Certificate renewal checks

**Manual Review**:
- [ ] Review overnight alerts
- [ ] Check daily health dashboard
- [ ] Verify backup completion

### Weekly Tasks

**Mondays** (30 minutes):
- [ ] Review error logs for patterns
- [ ] Check database performance trends
- [ ] Review sync conflict rate
- [ ] Test backup restore (sample sponsor)
- [ ] Update on-call schedule

**Script**: `scripts/weekly_maintenance.sh`

```bash
#!/bin/bash
# Weekly maintenance script

echo "=== Weekly Maintenance: $(date) ==="

# 1. Generate weekly report
supabase db query --file scripts/weekly_report.sql > reports/weekly-$(date +%Y%m%d).txt

# 2. Check for unused indexes
supabase db query --file scripts/unused_indexes.sql

# 3. Check database bloat
supabase db query --file scripts/check_bloat.sql

# 4. Test backup restore (staging)
./scripts/test_backup_restore.sh staging

echo "=== Weekly Maintenance Complete ==="
```

### Monthly Tasks

**First Monday of Month** (2 hours):
- [ ] Review and update monitoring dashboards
- [ ] Security audit (review access logs)
- [ ] Performance tuning (analyze slow queries)
- [ ] Capacity planning review
- [ ] Update documentation for any operational changes
- [ ] Review incident response effectiveness (postmortems)

**Script**: `scripts/monthly_maintenance.sh`

### Quarterly Tasks

**End of Quarter** (4 hours):
- [ ] Supabase plan usage review (upgrade if needed)
- [ ] Disaster recovery test (full restore)
- [ ] Review and update incident runbooks
- [ ] SLA compliance review
- [ ] Compliance audit preparation
- [ ] Contract renewal review (Supabase, Netlify)

---

## Log Analysis

### Useful Supabase Log Queries

**API Logs**:

```bash
# View last 100 API errors
supabase logs --type api --filter "status>=400" --tail=100

# Track specific user's requests
supabase logs --type api --filter "user_id=abc123" --tail=50

# Slow requests (>1 second)
supabase logs --type api --filter "duration>1000" --tail=50
```

**Database Logs**:

```bash
# Slow queries (>100ms)
supabase logs --type db --filter "duration>100" --tail=50

# Connection errors
supabase logs --type db --filter "error" --tail=100
```

**Edge Function Logs**:

```bash
# View Edge Function errors
supabase functions logs edc_sync --filter "level=error" --tail=100

# Track specific event
supabase functions logs edc_sync --filter "event_uuid=xyz789"
```

### Log Retention

**Supabase Free Tier**: 7 days
**Supabase Pro**: 90 days
**Archived Logs**: Export to S3/GCS for long-term storage (7 years for compliance)

**Export Script**:

```bash
#!/bin/bash
# Export logs for archival (run weekly)

DATE=$(date +%Y%m%d)
PROJECT_REF="abcd1234"

# Export API logs
supabase logs --type api --output json > logs/api-$PROJECT_REF-$DATE.json

# Export database logs
supabase logs --type db --output json > logs/db-$PROJECT_REF-$DATE.json

# Upload to S3 (compliance archive)
aws s3 cp logs/ s3://clinical-diary-logs-archive/ --recursive

echo "Logs archived: $DATE"
```

---

## Performance Monitoring

### Key Performance Indicators (KPIs)

**Target Metrics**:

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Portal uptime | 99.9% | <99.5% |
| API response time (p95) | <500ms | >1000ms |
| Database query time (p95) | <100ms | >300ms |
| Mobile sync success rate | 99.5% | <98% |
| Edge Function success rate | 99% | <97% |
| Backup success rate | 100% | <100% |

### Performance Analysis Queries

**Slow Query Analysis**:

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
1. Scale up Supabase plan
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
- Supabase Support: support@supabase.com (Pro plan: <4 hour SLA)
- Netlify Support: support@netlify.com
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

Database connection pool (100 connections) exceeded due to...

## Resolution

Increased connection pool to 200, added monitoring for connection usage.

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

**Tool**: Statuspage.io or similar

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
- Automated database backups every 6 hours
- Point-in-time recovery capability for 30 days
- Long-term archive retention per study requirements
- Regular backup restore testing (weekly)
- Disaster recovery procedures tested quarterly

**Rationale**: Implements data retention requirements (p00012) through operational backup policies. Regular testing ensures backups are actually restorable, not just created.

**Acceptance Criteria**:
- Automated backups run every 6 hours without failure
- Backup retention meets or exceeds study-specific requirements
- Weekly backup restore tests to staging environment
- Quarterly disaster recovery drills documented
- Backup integrity verification automated

*End* *Backup and Retention Policy* | **Hash**: 6268dd48
---

### Automated Backups

**Supabase Automatic Backups**:
- Frequency: Every 6 hours
- Retention: 30 days (point-in-time recovery)
- Storage: Encrypted, geo-redundant

**No action required** (automated by Supabase)

### Manual Backup Verification

**Weekly Test** (every Monday):

```bash
#!/bin/bash
# Test backup restore to staging

PROJECT_REF="staging-xyz"
BACKUP_FILE="backup-latest.sql"

echo "1. Export production backup"
supabase db dump --project-ref prod-abc > $BACKUP_FILE

echo "2. Restore to staging"
supabase db restore --project-ref $PROJECT_REF $BACKUP_FILE

echo "3. Run smoke tests"
flutter test integration_test/smoke_test.dart --dart-define=ENV=staging

if [ $? -eq 0 ]; then
  echo "✓ Backup restore test PASSED"
else
  echo "✗ Backup restore test FAILED - investigate immediately"
  exit 1
fi
```

### Disaster Recovery Test

**Quarterly** (full DR drill):

1. Simulate complete Supabase project failure
2. Create new Supabase project
3. Restore from backup
4. Deploy database schema
5. Deploy Edge Functions
6. Configure authentication
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

---

**Document Status**: Active operations playbook
**Review Cycle**: Monthly or after major incidents
**Owner**: DevOps Team / SRE
