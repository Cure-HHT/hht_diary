# Better Uptime Integration Setup Guide

**Purpose**: Step-by-step guide to set up uptime monitoring and status page
**Audience**: Operations team, DevOps engineers
**Status**: Ready to activate (follow steps when ready)

---

## Overview

Better Uptime provides uptime monitoring, status pages, and incident management for the Clinical Diary application. This guide covers setup for all environments.

**Benefits**:
- Multi-region health checks (30-second intervals)
- Public status page for transparency
- SMS/email/Slack alerting
- On-call scheduling
- Incident management

**Cost**: Free tier (sufficient for our needs)
- 10 monitors
- 3 status pages
- Unlimited team members
- 1-minute check intervals

---

## Prerequisites

- [ ] Better Uptime account (create at https://betteruptime.com)
- [ ] Access to DNS for status page custom domain (optional)
- [ ] Slack workspace (for alerts)
- [ ] Phone numbers for SMS alerts (production on-call)

---

## Step 1: Create Better Uptime Account

1. Sign up at https://betteruptime.com
2. Select **Free Plan**
3. Create team: `clinical-diary`
4. Verify email address

---

## Step 2: Configure Monitors

### 2.1 Development Environment Monitor

**Purpose**: Verify dev environment is accessible

1. Go to **Monitors** > **Create Monitor**
2. Configure:
   - **Name**: Dev API Health
   - **URL**: `https://[dev-project-id].supabase.co/rest/v1/health`
   - **Method**: GET
   - **Check frequency**: Every 5 minutes
   - **Timeout**: 30 seconds
   - **Regions**: US West (single region sufficient for dev)
   - **Expected status code**: 200
   - **Keyword check**: `"status":"healthy"` (optional)
   - **Alert after**: 2 failed checks
3. Click **Create Monitor**

**Additional Dev Monitors**:

**Dev Auth Health**:
- **URL**: `https://[dev-project-id].supabase.co/auth/v1/health`
- **Check frequency**: Every 5 minutes

---

### 2.2 Staging Environment Monitors

**Purpose**: Verify staging environment before promoting to production

1. Create monitor: **Staging API Health**
   - **URL**: `https://[staging-project-id].supabase.co/rest/v1/health`
   - **Check frequency**: Every 2 minutes
   - **Regions**: US West, US East (multi-region)
   - **Alert after**: 2 failed checks

2. Create monitor: **Staging Auth Health**
   - **URL**: `https://[staging-project-id].supabase.co/auth/v1/health`
   - **Check frequency**: Every 2 minutes

3. Create monitor: **Staging Database Health**
   - **URL**: `https://[staging-project-id].supabase.co/rest/v1/rpc/health_check`
   - **Check frequency**: Every 5 minutes
   - **Expected response**: JSON with `"database":"connected"`

---

### 2.3 Production Environment Monitors (Critical)

**Purpose**: 24/7 monitoring of production with immediate alerting

1. Create monitor: **Production API Health**
   - **URL**: `https://[prod-project-id].supabase.co/rest/v1/health`
   - **Check frequency**: Every 30 seconds (fastest on free tier)
   - **Regions**: US West, US East, EU West (global coverage)
   - **Timeout**: 10 seconds
   - **Alert after**: 1 failed check (immediate)
   - **SSL check**: Enabled
   - **Certificate expiry alert**: 30 days before expiration

2. Create monitor: **Production Auth Health**
   - **URL**: `https://[prod-project-id].supabase.co/auth/v1/health`
   - **Check frequency**: Every 1 minute
   - **Regions**: US West, US East, EU West
   - **Alert after**: 1 failed check

3. Create monitor: **Production Database Health**
   - **URL**: `https://[prod-project-id].supabase.co/rest/v1/rpc/health_check`
   - **Check frequency**: Every 1 minute
   - **Alert after**: 2 failed checks

4. Create monitor: **Production Critical User Flow** (Heartbeat)
   - **Type**: Heartbeat (expects regular check-ins)
   - **Name**: Critical User Actions
   - **Expected heartbeat**: Every 5 minutes
   - **Alert after**: 15 minutes of no heartbeat
   - **Purpose**: Ensure users can perform critical actions (login, create diary entry)

**To implement heartbeat**:
```dart
// In your app, after successful critical action
Future<void> sendHeartbeat() async {
  try {
    await http.post(
      Uri.parse('https://betteruptime.com/api/v1/heartbeat/[heartbeat-id]'),
    );
  } catch (e) {
    // Log but don't fail user action
    debugPrint('Heartbeat failed: $e');
  }
}
```

---

## Step 3: Configure Alert Escalation

### 3.1 Create On-Call Schedule (Production Only)

1. Go to **On-call** > **Create Schedule**
2. Configure:
   - **Name**: Production On-Call
   - **Time zone**: Team's primary time zone
   - **Rotation**: Weekly (rotate every Monday 9 AM)
   - **Team members**: Add all engineers

3. Set up escalation layers:
   - **Layer 1**: Primary on-call (immediate alert)
   - **Layer 2**: Secondary on-call (if not acknowledged in 10 minutes)
   - **Layer 3**: Team lead (if not acknowledged in 20 minutes)

---

### 3.2 Configure Alert Channels

**Email Alerts (All Environments)**:

1. Go to **Integrations** > **Email**
2. Add emails:
   - Development: `dev-team@clinical-diary.com`
   - Staging: `qa-team@clinical-diary.com`
   - Production: `ops-team@clinical-diary.com`

**Slack Alerts**:

1. Go to **Integrations** > **Slack**
2. Click **Connect to Slack**
3. Authorize Better Uptime
4. Map monitors to channels:
   - Development → `#dev-alerts` (low priority)
   - Staging → `#qa-alerts` (medium priority)
   - Production → `#production-alerts` (high priority, @channel on incident)

**SMS Alerts (Production Only)**:

1. Go to **Integrations** > **SMS**
2. Add phone numbers for on-call team members
3. Configure SMS alerts:
   - Trigger: Production monitors down
   - Delay: Immediate (0 seconds)
   - Rate limit: Maximum 1 SMS per 5 minutes per person

**Phone Call Alerts (Production Critical)**:

1. Go to **Integrations** > **Phone Calls**
2. Add phone numbers for on-call engineers
3. Configure phone call escalation:
   - Trigger: Production down for >5 minutes
   - Call sequence: Primary → Secondary → Team Lead
   - Interval: 2 minutes between calls

---

## Step 4: Create Status Page

### 4.1 Create Public Status Page

1. Go to **Status Pages** > **Create Status Page**
2. Configure:
   - **Name**: Clinical Diary Status
   - **Subdomain**: `clinical-diary` (URL: https://clinical-diary.betteruptime.com)
   - **Theme**: Light (default)
   - **Logo**: Upload Clinical Diary logo
   - **Timezone**: UTC (standard for public status pages)

3. Add monitors to status page:
   - ✅ Production API Health
   - ✅ Production Auth Health
   - ✅ Production Database Health
   - ❌ Do NOT add dev/staging monitors (internal only)

4. Configure display:
   - **Show uptime percentage**: Last 90 days
   - **Show response time**: p95
   - **Group monitors**: Group by service (API, Auth, Database)

---

### 4.2 Configure Custom Domain (Optional)

If you want `status.clinical-diary.com` instead of Better Uptime subdomain:

1. Go to **Status Pages** > **[Your status page]** > **Settings**
2. Click **Custom domain**
3. Add domain: `status.clinical-diary.com`
4. Update DNS (in your DNS provider):
   ```
   CNAME status status.betteruptime.com
   ```
5. Verify domain ownership
6. Enable SSL (automatic)

---

### 4.3 Configure Incident Management

1. Go to **Status Pages** > **[Your status page]** > **Incidents**
2. Enable **Automatic incident creation**:
   - Create incident when any production monitor goes down
   - Incident title: "[Service] is experiencing issues"
   - Incident status: Investigating → Identified → Monitoring → Resolved

3. Configure incident updates:
   - **Manual updates**: Require manual status updates every 30 minutes during incident
   - **Auto-resolve**: Automatically resolve incident when all monitors are up for 5 minutes

4. Configure subscribers:
   - Enable **Email subscriptions** (users can subscribe to status updates)
   - Enable **Slack subscriptions**
   - Enable **RSS feed**

---

## Step 5: Test Monitoring

### 5.1 Test Downtime Detection

**Simulate downtime** (in dev environment only):

1. Temporarily make health endpoint return 500:
   ```sql
   -- In dev database, create a function that returns error
   CREATE OR REPLACE FUNCTION health()
   RETURNS json AS $$
   BEGIN
     RAISE EXCEPTION 'Simulated error';
   END;
   $$ LANGUAGE plpgsql;
   ```

2. Wait for Better Uptime to detect (should be within 5 minutes for dev)

3. Verify:
   - Monitor shows "Down" status
   - Alert sent to configured channels (email, Slack)
   - Incident created on status page

4. Fix the issue:
   ```sql
   DROP FUNCTION health();
   ```

5. Verify:
   - Monitor shows "Up" status
   - Incident auto-resolved

---

### 5.2 Test Alert Escalation (Production Staging Test)

**Do NOT test in production**. Use staging:

1. Simulate staging downtime (temporarily disable staging environment)
2. Verify:
   - Immediate alert to staging team (email + Slack)
   - No escalation (only production escalates)
3. Restore staging
4. Verify auto-resolution

---

## Step 6: Configure Maintenance Windows

### 6.1 Schedule Maintenance Window

When planning maintenance (e.g., database migration):

1. Go to **Maintenance Windows** > **Create Maintenance Window**
2. Configure:
   - **Name**: Database Migration - Production
   - **Start time**: Planned maintenance start (e.g., 2025-02-01 02:00 UTC)
   - **Duration**: 2 hours
   - **Affected monitors**: Select all production monitors
   - **Notify subscribers**: Yes (send email to status page subscribers)

3. During maintenance window:
   - Monitors continue running but don't trigger alerts
   - Status page shows "Scheduled Maintenance" banner
   - Subscribers notified automatically

---

## Step 7: Configure SLA Tracking

### 7.1 Set SLA Targets

1. Go to **Reports** > **SLA**
2. Configure SLA targets:
   - **Production Uptime**: 99.9% (8.76 hours downtime/year max)
   - **Response Time**: p95 < 2 seconds

3. Enable SLA reports:
   - **Frequency**: Monthly
   - **Recipients**: ops-team@clinical-diary.com, stakeholders
   - **Format**: PDF

---

## Step 8: Integrate with Incident Response

### 8.1 Webhook to GitHub Issues (Automatic Incident Tickets)

1. Go to **Integrations** > **Webhooks**
2. Create webhook:
   - **URL**: `https://api.github.com/repos/your-org/clinical-diary/issues`
   - **Events**: Monitor down, Monitor up
   - **Headers**:
     ```
     Authorization: Bearer [GitHub token]
     Content-Type: application/json
     ```
   - **Payload template**:
     ```json
     {
       "title": "[INCIDENT] {{monitor_name}} is down",
       "body": "Monitor: {{monitor_name}}\nStatus: {{monitor_status}}\nTimestamp: {{timestamp}}\nRegions affected: {{regions}}\n\nSee incident details: {{incident_url}}",
       "labels": ["incident", "production", "urgent"]
     }
     ```

3. Test webhook by simulating downtime

---

## Troubleshooting

### False Downtime Alerts

**Symptoms**: Alerts triggered but service is actually up

**Diagnosis**:
1. Check recent alerts: **Monitors** > **[Monitor name]** > **Incident Log**
2. Review response times: May be timing out due to slow response
3. Check geographic region: May be region-specific issue

**Resolution**:
1. Increase timeout if response is consistently slow (but <30 seconds)
2. If region-specific, investigate network routing issues
3. If persistent, check health endpoint implementation

---

### No Alerts Received

**Symptoms**: Monitor down but no alert

**Diagnosis**:
1. Check alert configuration: **Monitors** > **[Monitor]** > **Edit** > **Notifications**
2. Verify integration status: **Integrations** > Check connection status
3. Check email spam folder

**Resolution**:
1. Re-enable notifications if accidentally disabled
2. Reconnect integration (Slack, email)
3. Test alert by manually triggering test incident

---

### Status Page Not Updating

**Symptoms**: Status page shows outdated information

**Diagnosis**:
1. Check if monitor is added to status page: **Status Pages** > **[Page]** > **Monitors**
2. Verify CDN cache (may take up to 1 minute to update)

**Resolution**:
1. Add monitor to status page if missing
2. Force refresh status page (Ctrl+F5)
3. Contact Better Uptime support if issue persists

---

## Maintenance

### Weekly Tasks

- [ ] Review incident log for patterns
- [ ] Verify on-call schedule is up to date
- [ ] Check alert delivery (ensure no bounced emails)

### Monthly Tasks

- [ ] Review uptime percentage (target: 99.9%)
- [ ] Review response time trends
- [ ] Audit team member access
- [ ] Update on-call rotation if team changes

### Quarterly Tasks

- [ ] Review and adjust alert thresholds
- [ ] Update status page design/branding
- [ ] Review SLA compliance reports
- [ ] Test disaster recovery procedures

---

## References

- [Better Uptime Documentation](https://betteruptime.com/docs)
- [Status Page Best Practices](https://betteruptime.com/blog/status-page-best-practices)
- spec/ops-monitoring-observability.md - Monitoring specification
- docs/ops/incident-response-runbook.md - Incident response procedures

---

## Change History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-01-27 | 1.0 | Claude | Initial setup guide (ready to activate) |
