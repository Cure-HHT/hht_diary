# Monitoring and Observability Specification

**Audience**: Operations team
**Purpose**: Define monitoring, error tracking, and observability requirements
**Status**: Active
**Version**: 2.0.0
**Last Updated**: 2025-11-24

---

## Overview

This document specifies the monitoring and observability stack for the Clinical Trial Diary Platform on Google Cloud Platform. The stack uses GCP Cloud Operations (formerly Stackdriver) for centralized logging, monitoring, and tracing with OpenTelemetry compliance.

**Technology Stack**:

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Logging** | Cloud Logging | Centralized log aggregation |
| **Monitoring** | Cloud Monitoring | Metrics and dashboards |
| **Tracing** | Cloud Trace | Distributed tracing (OpenTelemetry) |
| **Error Reporting** | Cloud Error Reporting | Exception aggregation |
| **Uptime** | Cloud Monitoring Uptime Checks | Health monitoring |
| **Alerting** | Cloud Monitoring Alerting | Incident notification |

---

## Requirements

# REQ-o00045: Error Tracking and Monitoring

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
   - User ID (if authenticated, anonymized)
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
- **IQ**: Verify Cloud Error Reporting configured correctly
- **OQ**: Verify errors captured and grouped correctly
- **PQ**: Verify error capture latency <5 seconds

**Acceptance Criteria**:
- ✅ Cloud Error Reporting enabled for all services
- ✅ All environments configured (dev/staging/production)
- ✅ PII scrubbing enabled
- ✅ Alerts configured for critical errors
- ✅ Error retention meets FDA requirements

*End* *Error Tracking and Monitoring* | **Hash**: 4e736f6d
---

# REQ-o00046: Uptime Monitoring

**Level**: Ops | **Implements**: p00005 | **Status**: Active

**Specification**:

The system SHALL provide uptime monitoring that:

1. **Health Checks**:
   - API endpoint availability (every 60 seconds)
   - Database connectivity (every 60 seconds)
   - Authentication service availability (every 60 seconds)
   - Response time monitoring (<2 seconds)

2. **Geographic Monitoring**:
   - Monitor from multiple GCP regions
   - Detect regional outages
   - Measure latency by region

3. **Incident Detection**:
   - Automatic incident creation on downtime
   - Incident escalation after 5 minutes
   - Automatic incident resolution on recovery
   - Root cause analysis via Cloud Trace

4. **Status Page** (Optional):
   - Public status page via Cloud Monitoring
   - Real-time status updates
   - Incident history
   - Scheduled maintenance announcements

5. **Alerting**:
   - Immediate alert on downtime
   - SMS/email/Slack notifications
   - On-call rotation support via PagerDuty integration
   - Alert acknowledgment tracking

**Validation**:
- **IQ**: Verify uptime checks configured
- **OQ**: Verify downtime detected within 1 minute
- **PQ**: Verify alert delivery within 30 seconds

**Acceptance Criteria**:
- ✅ Uptime checks configured for all critical endpoints
- ✅ Multi-region monitoring enabled
- ✅ Alerting configured with on-call rotation
- ✅ 99.9% uptime SLA monitored

*End* *Uptime Monitoring* | **Hash**: b1a74a81
---

# REQ-o00047: Performance Monitoring

**Level**: Ops | **Implements**: p00005 | **Status**: Active

**Specification**:

The system SHALL monitor application performance with:

1. **Metrics Collection**:
   - API response times (p50, p95, p99)
   - Database query performance
   - Frontend page load times
   - Mobile app performance metrics
   - Resource utilization (CPU, memory, database connections)

2. **Transaction Tracing** (OpenTelemetry):
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
- **IQ**: Verify Cloud Trace configured
- **OQ**: Verify traces captured correctly
- **PQ**: Verify dashboard updates within 1 minute

**Acceptance Criteria**:
- ✅ Cloud Trace enabled with OpenTelemetry
- ✅ Cloud Monitoring dashboards configured
- ✅ Performance alerts configured
- ✅ SLA compliance tracked (95% of requests <2 seconds)

*End* *Performance Monitoring* | **Hash**: 6b0d1af7
---

# REQ-o00048: Audit Log Monitoring

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
   - Monitor archival to Cloud Storage Coldline
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

*End* *Audit Log Monitoring* | **Hash**: 600b3f14
---

## Architecture

### Monitoring Stack

```
┌─────────────────────────────────────────────────────────────────┐
│ Application Layer                                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐        ┌──────────────┐                      │
│  │ Flutter App  │        │ Dart Server  │                      │
│  │ (Frontend)   │        │ (Cloud Run)  │                      │
│  └──────┬───────┘        └──────┬───────┘                      │
│         │                       │                              │
│         │ OpenTelemetry         │ OpenTelemetry                │
│         │ (via Cloud Trace)     │ + Cloud Logging              │
│         │                       │                              │
└─────────┼───────────────────────┼──────────────────────────────┘
          │                       │
          └───────────┬───────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│ GCP Cloud Operations                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────┐                    │
│  │ Cloud Logging                          │                    │
│  │ • Centralized log aggregation          │                    │
│  │ • Structured logging (JSON)            │                    │
│  │ • Log-based metrics                    │                    │
│  │ • Log routing and filtering            │                    │
│  └────────────────┬───────────────────────┘                    │
│                   │                                             │
│  ┌────────────────▼───────────────────────┐                    │
│  │ Cloud Error Reporting                  │                    │
│  │ • Error aggregation                    │                    │
│  │ • Stack trace deduplication            │                    │
│  │ • Error trends and alerts              │                    │
│  │ • PII scrubbing                        │                    │
│  └────────────────┬───────────────────────┘                    │
│                   │                                             │
│  ┌────────────────▼───────────────────────┐                    │
│  │ Cloud Trace (OpenTelemetry)            │                    │
│  │ • Distributed tracing                  │                    │
│  │ • Latency analysis                     │                    │
│  │ • Service dependency mapping           │                    │
│  │ • Performance bottlenecks              │                    │
│  └────────────────┬───────────────────────┘                    │
│                   │                                             │
│  ┌────────────────▼───────────────────────┐                    │
│  │ Cloud Monitoring                       │                    │
│  │ • Custom dashboards                    │                    │
│  │ • Alerting policies                    │                    │
│  │ • Uptime checks                        │                    │
│  │ • SLO tracking                         │                    │
│  └────────────────┬───────────────────────┘                    │
│                   │                                             │
│                   ├─────────▶ Email                             │
│                   ├─────────▶ Slack                             │
│                   ├─────────▶ PagerDuty                         │
│                   └─────────▶ Pub/Sub (for automation)          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│ Database Monitoring                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────┐                   │
│  │ Cloud SQL Insights                      │                   │
│  │ • Query performance analysis            │                   │
│  │ • Connection pool utilization           │                   │
│  │ • Storage usage and growth              │                   │
│  │ • Slow query detection                  │                   │
│  └─────────────────────────────────────────┘                   │
│                                                                 │
│  ┌─────────────────────────────────────────┐                   │
│  │ Built-in Cloud SQL Metrics              │                   │
│  │ • CPU utilization                       │                   │
│  │ • Memory usage                          │                   │
│  │ • Disk I/O                              │                   │
│  │ • Connections                           │                   │
│  └─────────────────────────────────────────┘                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│ Audit Trail Monitoring                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────┐                   │
│  │ Tamper Detection (Cloud Scheduler)      │                   │
│  │ • Runs every 5 minutes                  │                   │
│  │ • Verifies cryptographic hashes         │                   │
│  │ • Checks sequence number continuity     │                   │
│  │ • Triggers Cloud Function on anomaly    │                   │
│  └─────────────────┬───────────────────────┘                   │
│                    │                                            │
│         ┌──────────┴──────────┐                                │
│         │                     │                                │
│         ▼ TAMPERING           ▼ NORMAL                         │
│  ┌──────────────┐      ┌──────────────┐                        │
│  │ Emergency    │      │ Log Success  │                        │
│  │ Alert        │      │ to Cloud     │                        │
│  │ + Incident   │      │ Logging      │                        │
│  └──────────────┘      └──────────────┘                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

| Component | Technology | Cost | Purpose |
| --- | --- | --- | --- |
| **Logging** | Cloud Logging | ~$0.50/GB ingested | Centralized log aggregation |
| **Monitoring** | Cloud Monitoring | Free tier + ~$0.10/metric | Dashboards and alerts |
| **Tracing** | Cloud Trace | $0.20/million spans | Distributed tracing |
| **Error Reporting** | Cloud Error Reporting | Free | Exception aggregation |
| **Uptime Checks** | Cloud Monitoring | Free (up to 100) | Health monitoring |
| **Long-term Storage** | Cloud Storage Coldline | ~$0.004/GB/month | 7-year compliance retention |

**Estimated Monthly Cost**: ~$20-50/month (depending on volume)

---

## Integration Guides

### Cloud Logging Integration

**Dart Server (Cloud Run)**:

```dart
import 'dart:convert';
import 'dart:io';

/// Structured logging for Cloud Logging
class CloudLogger {
  final String serviceName;
  final String environment;

  CloudLogger({
    required this.serviceName,
    required this.environment,
  });

  void info(String message, {Map<String, dynamic>? labels}) {
    _log('INFO', message, labels: labels);
  }

  void warning(String message, {Map<String, dynamic>? labels}) {
    _log('WARNING', message, labels: labels);
  }

  void error(String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? labels}) {
    _log('ERROR', message, error: error, stackTrace: stackTrace, labels: labels);
  }

  void _log(
    String severity,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? labels,
  }) {
    final logEntry = {
      'severity': severity,
      'message': message,
      'serviceContext': {
        'service': serviceName,
        'version': Platform.environment['K_REVISION'] ?? 'unknown',
      },
      'labels': {
        'environment': environment,
        ...?labels,
      },
      if (error != null) 'error': {
        'message': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      },
    };

    // Cloud Run captures stdout as Cloud Logging entries
    print(jsonEncode(logEntry));
  }
}

// Usage
final logger = CloudLogger(
  serviceName: 'clinical-diary-api',
  environment: Platform.environment['ENVIRONMENT'] ?? 'development',
);

logger.info('Request processed', labels: {'userId': userId, 'endpoint': '/api/entries'});
logger.error('Database connection failed', error: e, stackTrace: stackTrace);
```

### Cloud Trace Integration (OpenTelemetry)

**Dart Server with OpenTelemetry**:

```dart
import 'package:opentelemetry/api.dart';
import 'package:opentelemetry/sdk.dart';
import 'package:opentelemetry_exporter_cloud_trace/cloud_trace_exporter.dart';

void initializeTracing() {
  final exporter = CloudTraceExporter(
    projectId: Platform.environment['GCP_PROJECT_ID']!,
  );

  final tracerProvider = TracerProviderBase(
    processors: [BatchSpanProcessor(exporter)],
  );

  registerGlobalTracerProvider(tracerProvider);
}

// Usage in request handler
Future<Response> handleRequest(Request request) async {
  final tracer = globalTracerProvider.getTracer('clinical-diary-api');

  return tracer.startActiveSpan('handleRequest', (span) async {
    span.setAttribute('http.method', request.method);
    span.setAttribute('http.url', request.url.toString());

    try {
      // Database query with child span
      final result = await tracer.startActiveSpan('database.query', (dbSpan) async {
        dbSpan.setAttribute('db.system', 'postgresql');
        dbSpan.setAttribute('db.statement', 'SELECT * FROM record_state');

        final data = await db.query('SELECT * FROM record_state');
        return data;
      });

      span.setStatus(StatusCode.ok);
      return Response.ok(jsonEncode(result));
    } catch (e, stackTrace) {
      span.setStatus(StatusCode.error, e.toString());
      span.recordException(e, stackTrace: stackTrace);
      rethrow;
    }
  });
}
```

### Cloud Error Reporting

Errors logged to Cloud Logging are automatically picked up by Cloud Error Reporting when properly formatted:

```dart
void reportError(Object error, StackTrace stackTrace, {String? userId}) {
  final errorReport = {
    'severity': 'ERROR',
    'message': error.toString(),
    '@type': 'type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent',
    'serviceContext': {
      'service': 'clinical-diary-api',
      'version': Platform.environment['K_REVISION'] ?? 'unknown',
    },
    'context': {
      'reportLocation': {
        'functionName': 'handleRequest',
      },
      if (userId != null) 'user': userId,
    },
    'stack_trace': stackTrace.toString(),
  };

  print(jsonEncode(errorReport));
}
```

### Uptime Checks Configuration

```bash
# Create uptime check for API health endpoint
gcloud monitoring uptime-check-configs create clinical-diary-api-health \
  --display-name="Clinical Diary API Health" \
  --http-check-path="/health" \
  --http-check-port=443 \
  --monitored-resource-type="uptime_url" \
  --monitored-resource-labels="project_id=${PROJECT_ID},host=api.clinical-diary.com" \
  --period=60s \
  --timeout=10s \
  --regions=usa-oregon,usa-virginia,europe-belgium

# Create uptime check for authentication
gcloud monitoring uptime-check-configs create clinical-diary-auth-health \
  --display-name="Clinical Diary Auth Health" \
  --http-check-path="/auth/health" \
  --http-check-port=443 \
  --monitored-resource-type="uptime_url" \
  --monitored-resource-labels="project_id=${PROJECT_ID},host=api.clinical-diary.com" \
  --period=60s \
  --timeout=10s
```

---

## Dashboards

### Operations Dashboard

Create via Cloud Console or Terraform:

```hcl
resource "google_monitoring_dashboard" "operations" {
  dashboard_json = jsonencode({
    displayName = "Clinical Diary Operations"
    gridLayout = {
      widgets = [
        {
          title = "API Request Rate"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\""
                }
              }
            }]
          }
        },
        {
          title = "API Latency (p95)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
                  aggregation = {
                    alignmentPeriod = "60s"
                    perSeriesAligner = "ALIGN_PERCENTILE_95"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Error Rate"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"logging.googleapis.com/log_entry_count\" AND metric.labels.severity=\"ERROR\""
                }
              }
            }]
          }
        },
        {
          title = "Cloud SQL CPU"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
                }
              }
            }]
          }
        }
      ]
    }
  })
}
```

### Key Metrics

**Operations Dashboard**:
- Uptime percentage (rolling 24h/7d/30d)
- Error rate (errors per 1000 requests)
- p95 API response time
- Active users
- Database connection pool utilization

**Compliance Dashboard**:
- Audit trail tamper checks (last 7 days)
- Audit record completeness (% of actions with records)
- Retention compliance (7-year verification)
- Access control violations
- Failed authentication attempts

---

## Alerting Strategy

### Alert Policies

```bash
# Create alert for high error rate
gcloud monitoring alert-policies create \
  --display-name="High Error Rate" \
  --condition-filter='resource.type="cloud_run_revision" AND metric.type="logging.googleapis.com/log_entry_count" AND metric.labels.severity="ERROR"' \
  --condition-threshold-value=10 \
  --condition-threshold-duration=300s \
  --condition-threshold-comparison=COMPARISON_GT \
  --notification-channels=${NOTIFICATION_CHANNEL_ID} \
  --documentation='High error rate detected. Check Cloud Error Reporting for details.'

# Create alert for API latency
gcloud monitoring alert-policies create \
  --display-name="High API Latency" \
  --condition-filter='resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/request_latencies"' \
  --condition-threshold-value=2000 \
  --condition-threshold-duration=300s \
  --condition-threshold-comparison=COMPARISON_GT \
  --aggregations='alignmentPeriod=60s,perSeriesAligner=ALIGN_PERCENTILE_95' \
  --notification-channels=${NOTIFICATION_CHANNEL_ID}

# Create alert for database CPU
gcloud monitoring alert-policies create \
  --display-name="Database High CPU" \
  --condition-filter='resource.type="cloudsql_database" AND metric.type="cloudsql.googleapis.com/database/cpu/utilization"' \
  --condition-threshold-value=0.8 \
  --condition-threshold-duration=300s \
  --condition-threshold-comparison=COMPARISON_GT \
  --notification-channels=${NOTIFICATION_CHANNEL_ID}
```

### Critical Alerts (Immediate Response Required)

- **Production downtime** → On-call engineer (SMS + phone call via PagerDuty)
- **Audit trail tampering detected** → Security team + Tech Lead
- **Database connection pool exhausted** → On-call engineer
- **Error rate >5%** → On-call engineer
- **Authentication service down** → On-call engineer

### Warning Alerts (Response within 1 hour)

- **p95 response time >2 seconds** → Tech Lead
- **Error rate >1%** → Engineering team (Slack)
- **Staging smoke tests failed** → QA team
- **Backup failure** → Operations team
- **Disk space >80%** → Operations team

### Info Alerts (Daily Digest)

- **New error types introduced** → Engineering team
- **Performance degradation trends** → Tech Lead
- **Security: Failed login attempts summary** → Security team
- **Audit: Daily audit summary** → Compliance team

---

## Notification Channels

### Setup Notification Channels

```bash
# Email notification channel
gcloud monitoring channels create \
  --display-name="Engineering Team Email" \
  --type=email \
  --channel-labels=email_address=engineering@clinical-diary.com

# Slack notification channel
gcloud monitoring channels create \
  --display-name="Ops Slack Channel" \
  --type=slack \
  --channel-labels=channel_name=#clinical-diary-ops \
  --channel-labels=auth_token=${SLACK_WEBHOOK_URL}

# PagerDuty integration (for critical alerts)
gcloud monitoring channels create \
  --display-name="PagerDuty On-Call" \
  --type=pagerduty \
  --channel-labels=service_key=${PAGERDUTY_SERVICE_KEY}
```

---

## Audit Trail Monitoring

### Tamper Detection Scheduler

```bash
# Create Cloud Scheduler job for tamper detection
gcloud scheduler jobs create http audit-tamper-check \
  --location=$REGION \
  --schedule="*/5 * * * *" \
  --uri="https://${CLOUD_RUN_URL}/admin/audit/verify" \
  --http-method=POST \
  --oidc-service-account-email=${SERVICE_ACCOUNT}
```

### Tamper Detection Function

```dart
// Endpoint: POST /admin/audit/verify
Future<Response> verifyAuditIntegrity(Request request) async {
  final logger = CloudLogger(serviceName: 'audit-monitor', environment: environment);

  try {
    // Check for tampered records
    final tamperedRecords = await db.query('''
      SELECT * FROM detect_tampered_records(
        now() - interval '10 minutes',
        now()
      )
    ''');

    if (tamperedRecords.isNotEmpty) {
      // CRITICAL: Tampering detected
      logger.error(
        'AUDIT TAMPERING DETECTED',
        labels: {
          'tampered_count': tamperedRecords.length.toString(),
          'alert_type': 'SECURITY_CRITICAL',
        },
      );

      // Create incident
      await createSecurityIncident(
        title: 'Audit Trail Tampering Detected',
        severity: 'CRITICAL',
        recordCount: tamperedRecords.length,
      );

      return Response.internalServerError(
        body: jsonEncode({'status': 'TAMPERING_DETECTED', 'count': tamperedRecords.length}),
      );
    }

    // Check for sequence gaps
    final sequenceGaps = await db.query('SELECT * FROM check_audit_sequence_gaps()');

    if (sequenceGaps.isNotEmpty) {
      logger.warning(
        'Audit sequence gaps detected',
        labels: {'gap_count': sequenceGaps.length.toString()},
      );
    }

    logger.info('Audit integrity check passed');
    return Response.ok(jsonEncode({'status': 'OK', 'checked_at': DateTime.now().toIso8601String()}));

  } catch (e, stackTrace) {
    logger.error('Audit integrity check failed', error: e, stackTrace: stackTrace);
    return Response.internalServerError();
  }
}
```

---

## Log Retention and Export

### Configure Log Retention

```bash
# Set log retention to 90 days for hot storage
gcloud logging buckets update _Default \
  --location=global \
  --retention-days=90

# Create log sink for long-term compliance storage
gcloud logging sinks create compliance-archive \
  --destination=storage.googleapis.com/${BUCKET_NAME}/logs \
  --log-filter='resource.type="cloud_run_revision" OR resource.type="cloudsql_database"'
```

### Cloud Storage Lifecycle for Compliance

```bash
# Set lifecycle policy for 7-year retention
cat > lifecycle.json << EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {"age": 90}
      },
      {
        "action": {"type": "Delete"},
        "condition": {"age": 2555}
      }
    ]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://${BUCKET_NAME}
```

---

## Validation Procedures

### Installation Qualification (IQ)

**Objective**: Verify monitoring integrations installed correctly

**Procedure**:
1. Verify Cloud Logging receiving logs from Cloud Run
2. Verify Cloud Trace receiving spans
3. Verify Cloud Error Reporting detecting errors
4. Verify uptime checks configured
5. Verify alert policies created
6. Document installation in validation log

**Acceptance**: All integrations operational

### Operational Qualification (OQ)

**Objective**: Verify monitoring captures events correctly

**Procedure**:
1. Generate test error → Verify captured in Error Reporting within 5 seconds
2. Simulate API downtime → Verify uptime check fails within 1 minute
3. Test audit tampering detection → Verify alert within 5 minutes
4. Test alerting → Verify alerts delivered to correct channels
5. Document results in validation log

**Acceptance**: All test events captured and alerted correctly

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

### Logs Not Appearing in Cloud Logging

**Symptoms**: Application logs not visible in Cloud Logging

**Diagnosis**:
1. Verify logs are being written to stdout/stderr
2. Check log format is valid JSON
3. Verify Cloud Run service has logging permissions

**Resolution**:
```bash
# Verify logging permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --filter="bindings.members:serviceAccount:*@$PROJECT_ID.iam.gserviceaccount.com"

# Check for logging.logWriter role
```

### Traces Not Appearing in Cloud Trace

**Symptoms**: Distributed traces not visible

**Diagnosis**:
1. Verify OpenTelemetry SDK initialized
2. Check Cloud Trace API enabled
3. Verify service account has trace writer role

**Resolution**:
```bash
# Enable Cloud Trace API
gcloud services enable cloudtrace.googleapis.com

# Grant trace writer role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudtrace.agent"
```

### False Uptime Alerts

**Symptoms**: Uptime checks report downtime but service is up

**Diagnosis**:
1. Check health endpoint response time
2. Verify health endpoint returns 200 status
3. Check for regional connectivity issues

**Resolution**:
1. Optimize health endpoint response time (<10s)
2. Increase uptime check timeout
3. Review regional check results separately

---

## Migration from Previous Stack

If migrating from Sentry/Better Uptime:

1. **Remove Sentry SDK** from Flutter app and backend
2. **Add Cloud Logging/Trace** integration as shown above
3. **Create Cloud Monitoring dashboards** to replace Sentry dashboards
4. **Configure uptime checks** to replace Better Uptime monitors
5. **Update alert channels** to Cloud Monitoring notification channels
6. **Verify error capture** working before decommissioning Sentry

---

## References

- [Cloud Logging Documentation](https://cloud.google.com/logging/docs)
- [Cloud Monitoring Documentation](https://cloud.google.com/monitoring/docs)
- [Cloud Trace Documentation](https://cloud.google.com/trace/docs)
- [Cloud Error Reporting Documentation](https://cloud.google.com/error-reporting/docs)
- [OpenTelemetry for Dart](https://opentelemetry.io/docs/instrumentation/dart/)
- spec/dev-audit-trail.md - Audit trail implementation details

---

## Change History

| Date | Version | Author | Changes |
| --- | --- | --- | --- |
| 2025-01-27 | 1.0 | Claude | Initial specification with Sentry/Better Uptime |
| 2025-11-24 | 2.0 | Claude | Migration to GCP Cloud Operations (removed Sentry) |
