# Monitoring and Observability Specification

**Audience**: Operations team
**Purpose**: Define monitoring, error tracking, and observability requirements
**Status**: Draft
**Version**: 2.0.0
**Last Updated**: 2025-11-24

---

## Overview

This document specifies the monitoring and observability stack for the Clinical Trial Diary Platform on Google Cloud Platform. The stack uses GCP Cloud Operations (formerly Stackdriver) for centralized logging, monitoring, and tracing with OpenTelemetry compliance.

**Technology Stack**:

| Component | Technology | Purpose |
| --- | --- | --- |
| **Logging** | Cloud Logging | Centralized log aggregation |
| **Monitoring** | Cloud Monitoring | Metrics and dashboards |
| **Tracing** | Cloud Trace | Distributed tracing (OpenTelemetry) |
| **Error Reporting** | Cloud Error Reporting | Exception aggregation |
| **Uptime** | Cloud Monitoring Uptime Checks | Health monitoring |
| **Alerting** | Cloud Monitoring Alerting | Incident notification |

---

## Requirements

# REQ-o00045: Error Tracking and Monitoring

**Level**: Ops | **Status**: Draft | **Implements**: p00005

## Rationale

This requirement ensures comprehensive error tracking and monitoring for a clinical trial system operating under FDA 21 CFR Part 11 compliance. Effective error tracking is critical for maintaining system reliability, supporting regulatory audits, and protecting patient data privacy. The system must capture sufficient context to diagnose and resolve issues while simultaneously protecting personally identifiable information (PII) and patient health information (PHI) in accordance with HIPAA regulations. Error data retention periods align with FDA requirements for electronic records, balancing operational needs (hot storage) with long-term regulatory compliance (cold storage for critical errors). Real-time alerting capabilities enable rapid response to system failures that could impact clinical trial data integrity or patient safety.

## Assertions

A. The system SHALL capture all unhandled exceptions in frontend and backend components.
B. The system SHALL capture API errors with full request context.
C. The system SHALL capture database errors with query context.
D. The system SHALL automatically group similar errors.
E. The system SHALL capture user actions leading to errors as breadcrumbs.
F. Error records SHALL include timestamp in UTC format.
G. Error records SHALL include anonymized user ID when the user is authenticated.
H. Error records SHALL include session ID.
I. Error records SHALL include device information including OS, browser, and version.
J. Error records SHALL include application version.
K. Error records SHALL include environment identifier (dev/staging/production).
L. Error records SHALL include stack trace with source mapping.
M. The system SHALL provide real-time alerts for critical errors.
N. The system SHALL escalate alerts after repeated failures.
O. The system SHALL group alerts to prevent notification fatigue.
P. The system SHALL support configurable alert channels including email, Slack, and PagerDuty.
Q. The system SHALL scrub PII from error messages.
R. The system SHALL redact sensitive data including passwords and tokens from error context.
S. The system SHALL NOT include patient data in error context.
T. The system SHALL handle error data in compliance with HIPAA requirements.
U. The system SHALL retain error data in hot storage for 90 days.
V. The system SHALL archive critical errors in cold storage for 7 years.
W. Error data retention SHALL comply with FDA audit trail requirements.
X. Cloud Error Reporting SHALL be enabled for all services.
Y. Error tracking SHALL be configured for all environments including dev, staging, and production.
Z. Error capture latency SHALL be less than 5 seconds.

*End* *Error Tracking and Monitoring* | **Hash**: 0b3b3002
---

# REQ-o00046: Uptime Monitoring

**Level**: Ops | **Status**: Draft | **Implements**: p00005

## Rationale

This requirement ensures continuous availability monitoring of the clinical trial platform to meet FDA 21 CFR Part 11 compliance and regulatory expectations for system reliability. Uptime monitoring is critical for detecting service degradation, coordinating incident response, and maintaining the 99.9% uptime SLA defined in REQ-p00005. Multi-region monitoring provides geographic redundancy verification, while automated incident management ensures rapid response to service disruptions that could impact clinical data collection and trial operations.

## Assertions

A. The system SHALL monitor API endpoint availability every 60 seconds.
B. The system SHALL monitor database connectivity every 60 seconds.
C. The system SHALL monitor authentication service availability every 60 seconds.
D. The system SHALL monitor API response times and detect when response times exceed 2 seconds.
E. The system SHALL perform uptime monitoring from multiple GCP regions.
F. The system SHALL detect regional outages through multi-region monitoring.
G. The system SHALL measure latency by region.
H. The system SHALL automatically create an incident when downtime is detected.
I. The system SHALL escalate incidents after 5 minutes of continued downtime.
J. The system SHALL automatically resolve incidents when service recovery is detected.
K. The system SHALL provide root cause analysis via Cloud Trace integration.
L. The system SHALL send immediate alerts when downtime is detected.
M. The system SHALL deliver alerts via SMS, email, and Slack notifications.
N. The system SHALL support on-call rotation through PagerDuty integration.
O. The system SHALL track alert acknowledgment status.
P. The system SHALL detect downtime within 1 minute of occurrence.
Q. The system SHALL deliver alerts within 30 seconds of downtime detection.
R. The system SHALL monitor uptime against a 99.9% SLA target.
S. Uptime checks SHALL be configured for all critical endpoints.
T. Multi-region monitoring SHALL be enabled.
U. Alerting SHALL be configured with on-call rotation support.

*End* *Uptime Monitoring* | **Hash**: 89ca2abc
---

# REQ-o00047: Performance Monitoring

**Level**: Ops | **Status**: Draft | **Implements**: p00005

## Rationale

This requirement establishes comprehensive performance monitoring for the clinical trial platform to ensure system reliability and regulatory compliance. Performance monitoring is critical for FDA 21 CFR Part 11 systems to demonstrate consistent operation and identify issues before they impact data integrity. The requirement implements product requirement p00005 by defining operational metrics collection, distributed tracing, alerting thresholds, and visualization dashboards. This monitoring infrastructure enables proactive identification of performance degradation, supports SLA compliance validation, and provides evidence of system performance for regulatory audits.

## Assertions

A. The system SHALL collect API response times at p50, p95, and p99 percentiles.
B. The system SHALL collect database query performance metrics.
C. The system SHALL collect frontend page load times.
D. The system SHALL collect mobile app performance metrics.
E. The system SHALL collect resource utilization metrics including CPU, memory, and database connections.
F. The system SHALL implement end-to-end request tracing using OpenTelemetry.
G. The system SHALL trace database query execution.
H. The system SHALL trace external API calls.
I. The system SHALL identify performance bottlenecks through transaction tracing.
J. The system SHALL generate an alert when p95 response time exceeds 2 seconds.
K. The system SHALL generate an alert when database connection pool reaches saturation.
L. The system SHALL generate an alert when error rates are elevated.
M. The system SHALL generate an alert when resource usage is abnormal.
N. The system SHALL provide a real-time performance dashboard.
O. The system SHALL provide historical performance trend analysis.
P. The system SHALL enable performance comparison across environments.
Q. The system SHALL provide custom metric visualization capabilities.
R. The system SHALL use Cloud Trace with OpenTelemetry integration.
S. The system SHALL use Cloud Monitoring dashboards.
T. The system SHALL update performance dashboards within 1 minute of metric collection.
U. The system SHALL track SLA compliance with a target of 95% of requests completing in less than 2 seconds.

*End* *Performance Monitoring* | **Hash**: cc6097be
---

# REQ-o00048: Audit Log Monitoring

**Level**: Ops | **Status**: Draft | **Implements**: p00004

## Rationale

This requirement ensures continuous monitoring and verification of audit trail integrity to maintain FDA 21 CFR Part 11 compliance. The monitoring system must detect tampering attempts, verify completeness of audit records, generate regulatory reports, and enforce long-term retention policies. These capabilities are essential for demonstrating the trustworthiness of electronic records during regulatory inspections and ensuring that any integrity violations are detected and addressed promptly. The requirement supports the parent product requirement (p00004) by implementing operational monitoring controls that protect the audit trail from modification, deletion, or loss over its required retention period.

## Assertions

A. The system SHALL continuously verify audit trail cryptographic hashes to detect tampering.
B. The system SHALL generate an alert when an audit trail hash mismatch is detected.
C. The system SHALL automatically create an incident record when audit trail tampering is detected.
D. The system SHALL create forensic logs for tampering investigations.
E. The system SHALL verify that all user actions generate corresponding audit records.
F. The system SHALL detect gaps in audit sequence numbers.
G. The system SHALL generate an alert when missing audit records are detected.
H. The system SHALL verify successful backup of audit trail records.
I. The system SHALL generate daily audit summary reports.
J. The system SHALL generate weekly compliance dashboard reports.
K. The system SHALL generate monthly FDA-ready audit reports.
L. The system SHALL provide an audit trail query interface for regulatory access.
M. The system SHALL verify compliance with the 7-year audit retention policy.
N. The system SHALL monitor archival of audit records to Cloud Storage Coldline.
O. The system SHALL generate an alert when retention policy violations are detected.
P. The system SHALL verify automatic lifecycle management of archived audit records.
Q. The system SHALL detect tampering attempts within 1 minute of occurrence.
R. The system SHALL ensure 100% of user actions generate audit records.
S. Tamper detection monitoring SHALL be active at all times.
T. The system SHALL verify retention policy compliance on a monthly basis.

*End* *Audit Log Monitoring* | **Hash**: ddecc3fd
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
