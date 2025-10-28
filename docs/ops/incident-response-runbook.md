# Incident Response Runbook

**Purpose**: Procedures for responding to production incidents
**Audience**: On-call engineers, operations team
**Status**: Ready to use (activate when production monitoring is live)

---

## Overview

This runbook defines procedures for detecting, responding to, and resolving production incidents in the Clinical Diary application.

**Incident Severity Levels**:
- **Critical (P0)**: Production down, data loss, security breach
- **High (P1)**: Major feature broken, performance severely degraded
- **Medium (P2)**: Minor feature broken, performance degraded
- **Low (P3)**: Cosmetic issues, non-critical bugs

---

## Incident Response Team

| Role | Responsibilities | Contact |
|------|------------------|---------|
| **Primary On-Call** | First responder, incident commander | Rotates weekly |
| **Secondary On-Call** | Backup, escalation | Rotates weekly |
| **Tech Lead** | Technical escalation, major decisions | Fixed |
| **Product Owner** | Stakeholder communication | Fixed |
| **Security Lead** | Security incidents | Fixed |

**On-Call Schedule**: See Better Uptime dashboard

---

## Incident Response Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Detection                                                    │
│    • Monitoring alert (Better Uptime, Sentry)                   │
│    • User report                                                │
│    • Internal discovery                                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Triage (< 5 minutes)                                         │
│    • Assess severity (P0/P1/P2/P3)                              │
│    • Determine impact (users affected, services down)           │
│    • Create incident ticket                                     │
│    • Notify team                                                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Response (< 15 minutes)                                      │
│    • Assign incident commander                                  │
│    • Start incident call/war room                               │
│    • Begin investigation                                        │
│    • Update status page                                         │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Mitigation (< 1 hour for P0)                                 │
│    • Implement fix or workaround                                │
│    • Test in staging (if time permits)                          │
│    • Deploy to production                                       │
│    • Verify resolution                                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. Recovery (< 2 hours)                                         │
│    • Verify all services operational                            │
│    • Check for data integrity issues                            │
│    • Monitor for recurrence                                     │
│    • Update status page to resolved                             │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. Post-Mortem (within 48 hours)                                │
│    • Document timeline                                          │
│    • Identify root cause                                        │
│    • Create action items                                        │
│    • Update runbooks                                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Incident Types and Procedures

### P0: Production Down

**Symptoms**:
- Health check endpoints returning errors
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

---

### P0: Security Breach

**Symptoms**:
- Unauthorized access detected
- Audit trail tampering alert
- Data exfiltration detected
- Suspicious authentication activity

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

---

### P2: Performance Degradation

**Symptoms**:
- p95 response time >2 seconds
- Database queries slow
- Page load times increased
- Better Uptime shows increased latency

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

### Required Tools for On-Call

- [ ] Access to Better Uptime dashboard
- [ ] Access to Sentry dashboard
- [ ] Access to Supabase dashboard
- [ ] Doppler CLI installed and authenticated
- [ ] Supabase CLI installed and authenticated
- [ ] GitHub CLI installed and authenticated
- [ ] Access to incident call link (Zoom/Google Meet)

### Quick Access Links

| Tool | URL | Purpose |
|------|-----|---------|
| Better Uptime | https://betteruptime.com/team/clinical-diary | Uptime monitoring |
| Sentry | https://sentry.io/organizations/clinical-diary | Error tracking |
| Supabase Dashboard | https://app.supabase.com | Database management |
| Status Page | https://status.clinical-diary.com | Public status |
| Incident Tickets | https://github.com/your-org/clinical-diary/issues?q=label%3Aincident | Incident history |

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

### Post-Mortem Template

Create a document with the following sections:

1. **Incident Summary**:
   - Date and time
   - Duration (detection to resolution)
   - Severity
   - Services affected
   - User impact

2. **Timeline**:
   - Chronological list of events
   - Include detection, actions taken, resolution

3. **Root Cause**:
   - What caused the incident?
   - Why did our systems not prevent it?
   - Why did it take X minutes to detect/resolve?

4. **What Went Well**:
   - Positive aspects of response
   - Tools/processes that worked

5. **What Went Poorly**:
   - Delays or mistakes
   - Tools/processes that didn't work

6. **Action Items**:
   - Preventative measures
   - Detection improvements
   - Response improvements
   - Assign owners and due dates

7. **Lessons Learned**:
   - Key takeaways for team

### Post-Mortem Meeting

- **Timing**: Within 48 hours of incident resolution
- **Attendees**: Incident responders, Tech Lead, Product Owner
- **Duration**: 30-60 minutes
- **Output**: Action items assigned with due dates

---

## Common Issues and Solutions

### Issue: Database Connection Pool Exhausted

**Symptoms**:
- Sentry errors: "Too many connections"
- Users cannot perform actions
- API returns 500 errors

**Quick Fix**:
```sql
-- Kill idle connections
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle' AND state_change < now() - interval '10 minutes';
```

**Long-term Solution**:
- Increase connection pool size in Supabase
- Implement connection pooling in application
- Review and optimize long-running queries

---

### Issue: Supabase Platform Outage

**Symptoms**:
- All health checks failing
- Supabase status page shows incident

**Response**:
- Check Supabase status page: https://status.supabase.com
- Update our status page linking to Supabase incident
- Monitor Supabase for resolution
- No action required on our end (platform issue)

---

### Issue: SSL Certificate Expiration

**Symptoms**:
- Better Uptime alert: "SSL certificate expiring soon"
- Browser warnings about certificate

**Response**:
- Supabase handles SSL automatically
- If alert occurs, verify with Supabase support
- Certificate should auto-renew

---

## Validation

This runbook should be tested annually through incident drills:

1. **Fire Drill**: Simulate production down scenario
2. **Security Drill**: Simulate security breach
3. **Communication Drill**: Practice stakeholder communication

Document drill results and update runbook accordingly.

---

## References

- Better Uptime dashboard: https://betteruptime.com/team/clinical-diary
- Sentry dashboard: https://sentry.io/organizations/clinical-diary
- Supabase dashboard: https://app.supabase.com
- spec/ops-monitoring-observability.md - Monitoring specification

---

## Change History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-01-27 | 1.0 | Claude | Initial runbook (ready to use) |
