# Monitoring and Observability Specification

**Audience**: Operations team
**Purpose**: Define monitoring, error tracking, and observability requirements
**Status**: Ready to activate (integrations ready, not connected)

---

## Requirements

### REQ-o00045: Error Tracking and Monitoring

**Level**: Ops | **Implements**: p00005 | **Status**: Active

**Specification**:

The system SHALL provide comprehensive error tracking and monitoring that:

1. **Error Capture**:
   - Capture all unhandled exceptions in frontend and backend
   - Capture API errors with full request context
   - Capture database errors with query context
   - Group similar errors automatically
   - Capture user actions leading to errors (breadcrumbs)

2. **Error Metadata**:
   - Timestamp (UTC)
   - User ID (if authenticated)
   - Session ID
   - Device information (OS, browser, version)
   - Application version
   - Environment (dev/staging/production)
   - Stack trace with source mapping

3. **Alerting**:
   - Real-time alerts for critical errors
   - Alert escalation after repeated failures
   - Alert grouping to prevent notification fatigue
   - Configurable alert channels (email, Slack, PagerDuty)

4. **Privacy Compliance**:
   - PII scrubbing from error messages
   - Sensitive data redaction (passwords, tokens)
   - Patient data exclusion from error context
   - HIPAA-compliant data handling

5. **Retention**:
   - Error data retained for 90 days (hot storage)
   - Critical errors archived for 7 years (cold storage)
   - FDA audit trail compliance

**Validation**:
- **IQ**: Verify Sentry integration configured correctly
- **OQ**: Verify errors captured and grouped correctly
- **PQ**: Verify error capture latency <5 seconds

**Acceptance Criteria**:
- ✅ Sentry SDK integrated in frontend and backend
- ✅ All environments configured (dev/staging/production)
- ✅ PII scrubbing enabled
- ✅ Alerts configured for critical errors
- ✅ Error retention meets FDA requirements

---

### REQ-o00046: Uptime Monitoring

**Level**: Ops | **Implements**: p00005 | **Status**: Active

**Specification**:

The system SHALL provide uptime monitoring that:

1. **Health Checks**:
   - API endpoint availability (every 30 seconds)
   - Database connectivity (every 1 minute)
   - Authentication service availability (every 1 minute)
   - Response time monitoring (<2 seconds)

2. **Geographic Monitoring**:
   - Monitor from multiple geographic locations
   - Detect regional outages
   - Measure latency by region

3. **Incident Detection**:
   - Automatic incident creation on downtime
   - Incident escalation after 5 minutes
   - Automatic incident resolution on recovery
   - Root cause analysis prompts

4. **Status Page**:
   - Public status page (status.clinical-diary.com)
   - Real-time status updates
   - Incident history
   - Scheduled maintenance announcements

5. **Alerting**:
   - Immediate alert on downtime
   - SMS/email/Slack notifications
   - On-call rotation support
   - Alert acknowledgment tracking

**Validation**:
- **IQ**: Verify Better Uptime monitors configured
- **OQ**: Verify downtime detected within 1 minute
- **PQ**: Verify alert delivery within 30 seconds

**Acceptance Criteria**:
- ✅ Uptime monitors configured for all critical endpoints
- ✅ Multi-region monitoring enabled
- ✅ Status page published
- ✅ Alerting configured with on-call rotation
- ✅ 99.9% uptime SLA monitored

---

### REQ-o00047: Performance Monitoring

**Level**: Ops | **Implements**: p00005 | **Status**: Active

**Specification**:

The system SHALL monitor application performance with:

1. **Metrics Collection**:
   - API response times (p50, p95, p99)
   - Database query performance
   - Frontend page load times
   - Mobile app performance metrics
   - Resource utilization (CPU, memory, database connections)

2. **Transaction Tracing**:
   - End-to-end request tracing
   - Database query analysis
   - External API call tracking
   - Bottleneck identification

3. **Performance Alerts**:
   - Alert on p95 response time >2 seconds
   - Alert on database connection pool saturation
   - Alert on elevated error rates
   - Alert on abnormal resource usage

4. **Dashboards**:
   - Real-time performance dashboard
   - Historical trend analysis
   - Comparison across environments
   - Custom metric visualization

**Validation**:
- **IQ**: Verify performance monitoring configured
- **OQ**: Verify metrics collected correctly
- **PQ**: Verify dashboard updates within 1 minute

**Acceptance Criteria**:
- ✅ Supabase metrics dashboard configured
- ✅ Sentry performance monitoring enabled
- ✅ Performance alerts configured
- ✅ SLA compliance tracked (95% of requests <2 seconds)

---

### REQ-o00048: Audit Log Monitoring

**Level**: Ops | **Implements**: p00004 | **Status**: Active

**Specification**:

The system SHALL monitor audit trail integrity with:

1. **Tamper Detection**:
   - Continuous verification of audit trail cryptographic hashes
   - Alert on hash mismatch (potential tampering)
   - Automatic incident creation on tampering detection
   - Forensic logging for investigation

2. **Completeness Monitoring**:
   - Verify all user actions generate audit records
   - Detect gaps in audit sequence numbers
   - Alert on missing audit records
   - Audit trail backup verification

3. **Compliance Reporting**:
   - Daily audit summary reports
   - Weekly compliance dashboard
   - Monthly FDA-ready audit reports
   - Audit trail query interface for regulators

4. **Retention Verification**:
   - Verify 7-year retention policy compliance
   - Monitor archival to S3 Glacier
   - Alert on retention policy violations
   - Automatic lifecycle management verification

**Validation**:
- **IQ**: Verify audit monitoring configured
- **OQ**: Verify tampering detected within 1 minute
- **PQ**: Verify 100% of user actions generate audit records

**Acceptance Criteria**:
- ✅ Tamper detection monitoring active
- ✅ Alerts configured for audit anomalies
- ✅ Compliance reports generated automatically
- ✅ 7-year retention verified monthly

---

## Architecture

### Monitoring Stack

```
┌─────────────────────────────────────────────────────────────────┐
│ Application Layer                                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐        ┌──────────────┐                      │
│  │ Flutter App  │        │ Supabase API │                      │
│  │ (Frontend)   │        │ (Backend)    │                      │
│  └──────┬───────┘        └──────┬───────┘                      │
│         │                       │                              │
│         │ Sentry SDK            │ Sentry SDK                   │
│         │                       │                              │
└─────────┼───────────────────────┼──────────────────────────────┘
          │                       │
          └───────────┬───────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│ Error Tracking (Sentry)                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────┐                    │
│  │ Error Aggregation                      │                    │
│  │ • Group similar errors                 │                    │
│  │ • Extract stack traces                 │                    │
│  │ • Scrub PII/PHI                        │                    │
│  │ • Enrich with context                  │                    │
│  └────────────────┬───────────────────────┘                    │
│                   │                                             │
│                   ▼                                             │
│  ┌────────────────────────────────────────┐                    │
│  │ Alerting Engine                        │                    │
│  │ • Critical errors → Immediate alert    │                    │
│  │ • Recurring errors → Escalation        │                    │
│  │ • Spike detection → Auto-alert         │                    │
│  └────────────────┬───────────────────────┘                    │
│                   │                                             │
│                   ├─────────▶ Email                             │
│                   ├─────────▶ Slack                             │
│                   └─────────▶ PagerDuty                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│ Uptime Monitoring (Better Uptime)                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Health Check Monitors (every 30-60 seconds):                  │
│                                                                 │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐       │
│  │ US East      │   │ US West      │   │ EU West      │       │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘       │
│         │                  │                  │                │
│         └──────────────────┼──────────────────┘                │
│                            │                                   │
│                            ▼                                   │
│         ┌──────────────────────────────────┐                   │
│         │ Endpoints:                       │                   │
│         │ • API Health: /health            │                   │
│         │ • Auth: /auth/v1/health          │                   │
│         │ • Database: /db/health           │                   │
│         └──────────────┬───────────────────┘                   │
│                        │                                       │
│         ┌──── DOWN ────┤                                       │
│         │              │                                       │
│         ▼              ▼ UP                                    │
│  ┌──────────────┐  ┌──────────────┐                           │
│  │ Create       │  │ Update       │                           │
│  │ Incident     │  │ Status Page  │                           │
│  └──────┬───────┘  └──────────────┘                           │
│         │                                                      │
│         ├─────────▶ SMS                                        │
│         ├─────────▶ Email                                      │
│         └─────────▶ Slack                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│ Performance Monitoring                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────┐                   │
│  │ Supabase Metrics Dashboard              │                   │
│  │ • Database query performance            │                   │
│  │ • Connection pool utilization           │                   │
│  │ • Storage usage and growth              │                   │
│  │ • API request rates                     │                   │
│  └─────────────────────────────────────────┘                   │
│                                                                 │
│  ┌─────────────────────────────────────────┐                   │
│  │ Sentry Performance                      │                   │
│  │ • Transaction tracing                   │                   │
│  │ • API response times (p50/p95/p99)      │                   │
│  │ • Frontend page load times              │                   │
│  │ • Database query analysis               │                   │
│  └─────────────────────────────────────────┘                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│ Audit Trail Monitoring                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────┐                   │
│  │ Tamper Detection (PostgreSQL Function)  │                   │
│  │ • Runs every 5 minutes                  │                   │
│  │ • Verifies cryptographic hashes         │                   │
│  │ • Checks sequence number continuity     │                   │
│  │ • Alerts on anomalies                   │                   │
│  └─────────────────┬───────────────────────┘                   │
│                    │                                            │
│         ┌──────────┴──────────┐                                │
│         │                     │                                │
│         ▼ TAMPERING           ▼ NORMAL                         │
│  ┌──────────────┐      ┌──────────────┐                        │
│  │ Emergency    │      │ Log Success  │                        │
│  │ Alert        │      └──────────────┘                        │
│  │ + Incident   │                                              │
│  └──────────────┘                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

| Component | Technology | Cost | Purpose |
|-----------|-----------|------|---------|
| **Error Tracking** | Sentry | $26/month | Exception capture, performance monitoring |
| **Uptime Monitoring** | Better Uptime | Free | Multi-region health checks, status page |
| **Database Metrics** | Supabase Built-in | Included | Query performance, connection pools |
| **Audit Monitoring** | Custom (PostgreSQL) | Included | Tamper detection, compliance reporting |
| **Long-term Storage** | S3 Glacier | ~$1/month | 7-year retention for critical errors |

**Total Cost**: ~$27/month

---

## Integration Guides

### Sentry Integration

See `docs/monitoring/sentry-setup.md` for complete setup instructions.

**Quick Start**:

1. Create Sentry account and project
2. Install SDKs:
   ```bash
   # Flutter
   flutter pub add sentry_flutter

   # Backend (if using custom functions)
   npm install @sentry/node
   ```

3. Configure in application:
   ```dart
   // lib/main.dart
   await SentryFlutter.init(
     (options) {
       options.dsn = const String.fromEnvironment('SENTRY_DSN');
       options.environment = const String.fromEnvironment('ENVIRONMENT');
       options.beforeSend = scr ubPii;  // Remove PII
     },
     appRunner: () => runApp(MyApp()),
   );
   ```

4. Store DSN in Doppler:
   ```bash
   doppler secrets set SENTRY_DSN="https://xxx@sentry.io/xxx"
   ```

---

### Better Uptime Integration

See `docs/monitoring/better-uptime-setup.md` for complete setup instructions.

**Quick Start**:

1. Create Better Uptime account (free tier)

2. Add monitors:
   - API Health: `https://your-project.supabase.co/rest/v1/health`
   - Auth Health: `https://your-project.supabase.co/auth/v1/health`

3. Configure alerts:
   - Email: your-team@example.com
   - Slack: Install Slack integration
   - SMS: Configure for production on-call

4. Create status page:
   - Subdomain: status.clinical-diary.com
   - Custom domain (optional): Configure DNS

---

## Dashboards

### Operations Dashboard

**Key Metrics**:
- Uptime percentage (rolling 24h/7d/30d)
- Error rate (errors per 1000 requests)
- p95 API response time
- Active users
- Database connection pool utilization

**Access**: ops.clinical-diary.com (internal only)

---

### Compliance Dashboard

**Key Metrics**:
- Audit trail tamper checks (last 7 days)
- Audit record completeness (% of actions with records)
- Retention compliance (7-year verification)
- Access control violations
- Failed authentication attempts

**Access**: compliance.clinical-diary.com (restricted to QA/Compliance team)

---

## Alerting Strategy

### Critical Alerts (Immediate Response Required)

- **Production downtime** → On-call engineer (SMS + phone call)
- **Audit trail tampering detected** → Security team + Tech Lead
- **Database connection pool exhausted** → On-call engineer
- **Error rate >5%** → On-call engineer
- **Authentication service down** → On-call engineer

---

### Warning Alerts (Response within 1 hour)

- **p95 response time >2 seconds** → Tech Lead
- **Error rate >1%** → Engineering team (Slack)
- **Staging smoke tests failed** → QA team
- **Backup failure** → Operations team
- **Disk space >80%** → Operations team

---

### Info Alerts (Daily Digest)

- **New error types introduced** → Engineering team
- **Performance degradation trends** → Tech Lead
- **Security: Failed login attempts summary** → Security team
- **Audit: Daily audit summary** → Compliance team

---

## Incident Response Integration

### Incident Creation

Automatic incident creation for:
- Production downtime >1 minute
- Critical errors affecting >10 users
- Audit trail tampering
- Security breaches

**Incident Ticket Created In**: GitHub Issues with `incident` label

**Incident Runbook**: See `docs/ops/incident-response-runbook.md`

---

## Activation Instructions

To activate monitoring:

1. **Set up Sentry** (see `docs/monitoring/sentry-setup.md`):
   ```bash
   # Create Sentry organization and projects
   # Add DSNs to Doppler
   doppler secrets set SENTRY_DSN_DEV="..."
   doppler secrets set SENTRY_DSN_STAGING="..."
   doppler secrets set SENTRY_DSN_PROD="..."
   ```

2. **Set up Better Uptime** (see `docs/monitoring/better-uptime-setup.md`):
   ```bash
   # Create monitors for each environment
   # Configure status page
   # Set up alert integrations (email, Slack, SMS)
   ```

3. **Enable audit monitoring**:
   ```sql
   -- Deploy audit tamper detection function
   -- (Already included in database/schema.sql)
   SELECT cron.schedule(
     'audit-tamper-check',
     '*/5 * * * *',  -- Every 5 minutes
     $$ SELECT check_audit_trail_integrity() $$
   );
   ```

4. **Configure dashboards**:
   - Access Sentry dashboard
   - Access Better Uptime dashboard
   - Access Supabase metrics dashboard

See `infrastructure/ACTIVATION_GUIDE.md` for complete activation procedures.

---

## Validation Procedures

### Installation Qualification (IQ)

**Objective**: Verify monitoring integrations installed correctly

**Procedure**:
1. Verify Sentry SDK integrated in Flutter app and backend
2. Verify Better Uptime monitors configured
3. Verify audit monitoring function deployed
4. Verify dashboards accessible
5. Document installation in validation log

**Acceptance**: All integrations installed and accessible

---

### Operational Qualification (OQ)

**Objective**: Verify monitoring captures events correctly

**Procedure**:
1. Generate test error → Verify captured in Sentry within 5 seconds
2. Simulate API downtime → Verify Better Uptime detects within 1 minute
3. Test audit tampering detection → Verify alert within 5 minutes
4. Test alerting → Verify alerts delivered to correct channels
5. Document results in validation log

**Acceptance**: All test events captured and alerted correctly

---

### Performance Qualification (PQ)

**Objective**: Verify monitoring performance meets SLAs

**Procedure**:
1. Measure error capture latency (100 test errors)
2. Measure downtime detection latency (10 test outages)
3. Measure alert delivery latency (20 test alerts)
4. Verify SLAs met:
   - Error capture: <5 seconds
   - Downtime detection: <1 minute
   - Alert delivery: <30 seconds
5. Document results in validation log

**Acceptance**: 95% of events meet SLA

---

## Troubleshooting

### Errors Not Appearing in Sentry

**Symptoms**: Errors occur in application but not captured in Sentry

**Diagnosis**:
1. Verify Sentry DSN configured correctly
2. Check network connectivity to Sentry
3. Verify Sentry SDK initialized before app code runs

**Resolution**:
1. Check Doppler secrets: `doppler secrets get SENTRY_DSN`
2. Test connectivity: `curl https://sentry.io/api/`
3. Verify SDK initialization order in `main.dart`

---

### False Downtime Alerts

**Symptoms**: Better Uptime reports downtime but application is up

**Diagnosis**:
1. Check application response time (may be timing out)
2. Check geographic-specific issues
3. Verify health check endpoint functioning

**Resolution**:
1. Optimize slow endpoints
2. Adjust timeout thresholds in Better Uptime
3. Fix health check endpoint if broken

---

### Audit Tamper Detection False Positives

**Symptoms**: Tamper detection alerts but no actual tampering

**Diagnosis**:
1. Check for concurrent writes causing hash race conditions
2. Verify hash algorithm consistency
3. Check for clock skew issues

**Resolution**:
1. Review audit trail locking mechanism
2. Verify PostgreSQL version and hash functions
3. Fix timestamp generation if needed

---

## References

- INFRASTRUCTURE_GAP_ANALYSIS.md - Phase 1 implementation plan
- docs/monitoring/sentry-setup.md - Sentry integration guide
- docs/monitoring/better-uptime-setup.md - Better Uptime integration guide
- docs/ops/incident-response-runbook.md - Incident response procedures
- spec/dev-audit-trail.md - Audit trail implementation details

---

## Change History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-01-27 | 1.0 | Claude | Initial specification (ready to activate) |
