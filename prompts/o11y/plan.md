# OpenTelemetry Observability Plan — HHT Diary Platform

**Ticket**: CUR-1100 — GCP base OTel
**Date**: 2026-03-20
**Scope**: GCP infrastructure, CloudRun Dart servers, database — NOT Flutter
**Library**: `dartastic_opentelemetry` (OTLP export → OTel Collector → GCP)

---

## Current State

| Layer | What Exists | What's Missing |
|-------|------------|----------------|
| **Logging** | Basic JSON to stdout (Cloud Logging picks it up) | No trace correlation, no structured context propagation |
| **Tracing** | IAM roles granted (`cloudtrace.agent`) but unused | No OTel SDK, no spans, no context propagation |
| **Metrics** | IAM role granted (`monitoring.metricWriter`) but unused | No custom metrics, no histograms, no counters |
| **Error Reporting** | Errors printed to stdout | No Cloud Error Reporting format, no span linkage |
| **Database** | `postgres` package, 10-connection pool | No query tracing, no connection pool metrics |
| **Infrastructure** | Cloud Run + Terraform | No OTel Collector sidecar |

## Architecture Decision

`dartastic_opentelemetry` exports via **OTLP only** (no native GCP exporter). The standard GCP pattern is:

```
Dart Server → OTLP → OTel Collector Sidecar → GCP Cloud Trace / Cloud Monitoring
```

This is Google's recommended approach and provides:
- Vendor-neutral instrumentation in code
- Collector handles GCP auth, batching, retry
- Can fan out to multiple backends (Cloud Trace + Cloud Monitoring + Cloud Logging)
- Collector config changes don't require code deploys

---

## Implementation Phases

### Phase 1: GCP Infrastructure (IaC)

**Goal**: Deploy OTel Collector as a Cloud Run sidecar, enable GCP APIs

#### 1A. Enable GCP APIs (Terraform)
- `cloudtrace.googleapis.com` (may already be enabled)
- `monitoring.googleapis.com`
- `clouderrorreporting.googleapis.com`

#### 1B. OTel Collector Sidecar Container
- Create `infrastructure/otel-collector/` directory
- Build a minimal OTel Collector container image with the `googlecloud` exporter
- Collector config (`otel-collector-config.yaml`):
  - **Receivers**: OTLP (gRPC on :4317, HTTP on :4318)
  - **Processors**: Batch, memory limiter, resource detection (GCP)
  - **Exporters**: `googlecloud` (traces → Cloud Trace, metrics → Cloud Monitoring)
  - **Extensions**: Health check on :13133
- Dockerfile based on `otel/opentelemetry-collector-contrib`

#### 1C. Cloud Run Multi-Container (Sidecar) Configuration
- Update Terraform `cloud-run` module to add OTel Collector as a sidecar container
- Sidecar receives OTLP on localhost:4317/4318
- Environment variables:
  - `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318` (on the Dart container)
  - `OTEL_SERVICE_NAME` (per service)
  - `OTEL_RESOURCE_ATTRIBUTES=deployment.environment=${env},service.namespace=hht-diary`
- Cloud Run sidecar requires `cloud_run_v2_service` (already using v2?)
- Health check: collector must start before app sends spans

**Files to create/modify**:
- `infrastructure/otel-collector/Dockerfile`
- `infrastructure/otel-collector/otel-collector-config.yaml`
- `infrastructure/terraform/modules/cloud-run/main.tf` (add sidecar)
- `infrastructure/terraform/modules/cloud-run/variables.tf` (collector image var)

**Requirement traceability**: REQ-o00047 (Performance Monitoring — OpenTelemetry integration)

---

### Phase 2: Core OTel Package (`packages/otel_common/`)

**Goal**: Shared OTel initialization and utilities for all Dart servers

#### 2A. Create `packages/otel_common/` package
A thin wrapper that standardizes OTel setup across diary_server and portal_server.

```dart
// packages/otel_common/lib/otel_common.dart

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Initialize OTel for a Cloud Run Dart server.
/// Reads config from environment variables (OTEL_*).
Future<void> initializeOTel({
  required String serviceName,
  required String serviceVersion,
}) async {
  await OTel.initialize(
    serviceName: serviceName,
    serviceVersion: serviceVersion,
    resourceAttributes: {
      'deployment.environment': env('ENVIRONMENT', 'development'),
      'service.namespace': 'hht-diary',
      'cloud.provider': 'gcp',
      'cloud.platform': 'gcp_cloud_run',
      'service.instance.id': env('K_REVISION', 'unknown'),
    },
  );
}

/// Graceful shutdown — flush pending spans/metrics
Future<void> shutdownOTel() async {
  await OTel.shutdown();
}
```

#### 2B. Shelf Middleware for Request Tracing
```dart
/// HTTP middleware that creates a span per request,
/// propagates trace context, and records status.
Middleware otelMiddleware({String? serviceName}) {
  return (Handler innerHandler) {
    return (Request request) async {
      final tracer = OTel.tracer('http');
      // Extract parent context from incoming headers (W3C TraceContext)
      // Start span with HTTP semantic conventions
      // Set attributes: http.method, http.route, http.status_code
      // Record exceptions
      // End span
    };
  };
}
```

#### 2C. Database Tracing Wrapper
```dart
/// Wraps postgres queries with OTel spans following DB semantic conventions.
/// Attributes: db.system=postgresql, db.statement (sanitized), db.operation
Future<T> tracedQuery<T>(
  String operation,
  String sql,
  Future<T> Function() execute,
) async {
  final tracer = OTel.tracer('db');
  final span = tracer.startSpan('db.$operation');
  span.setAttribute('db.system', 'postgresql');
  span.setAttribute('db.operation', operation);
  // Sanitize SQL (strip literals) before setting db.statement
  try {
    final result = await execute();
    span.setStatus(SpanStatusCode.ok);
    return result;
  } catch (e, st) {
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.error);
    rethrow;
  } finally {
    span.end();
  }
}
```

#### 2D. Structured Logging with Trace Correlation
```dart
/// Enhanced logger that includes trace_id and span_id in JSON output.
/// Cloud Logging uses these to correlate logs with traces.
void logWithTrace(String severity, String message, {Map<String, dynamic>? labels}) {
  final currentSpan = OTel.currentSpan;
  final logEntry = {
    'severity': severity,
    'message': message,
    'logging.googleapis.com/trace': currentSpan?.spanContext.traceId.toString(),
    'logging.googleapis.com/spanId': currentSpan?.spanContext.spanId.toString(),
    'logging.googleapis.com/trace_sampled': currentSpan?.spanContext.traceFlags.isSampled,
    ...?labels,
  };
  print(jsonEncode(logEntry));
}
```

**Files to create**:
- `packages/otel_common/pubspec.yaml`
- `packages/otel_common/lib/otel_common.dart`
- `packages/otel_common/lib/src/init.dart`
- `packages/otel_common/lib/src/middleware.dart`
- `packages/otel_common/lib/src/db_tracing.dart`
- `packages/otel_common/lib/src/logging.dart`
- `packages/otel_common/lib/src/error_reporting.dart`
- `packages/otel_common/test/` (unit tests)

**Dependencies**:
- `dartastic_opentelemetry: ^0.9.3`
- `shelf: ^1.4.2`

**Requirement traceability**: REQ-o00047F (end-to-end tracing), REQ-o00047G (DB query tracing), REQ-o00045 (error tracking)

---

### Phase 3: Instrument `diary_server`

**Goal**: Full tracing for the diary API server

#### 3A. Add `otel_common` dependency
- Update `apps/daily-diary/diary_server/pubspec.yaml`
- Update `apps/daily-diary/diary_functions/pubspec.yaml`

#### 3B. Initialize OTel at startup
- Modify `diary_server/bin/server.dart`:
  - Call `initializeOTel(serviceName: 'diary-server', ...)`
  - Register shutdown hook for `shutdownOTel()`
  - Replace raw JSON logging with trace-correlated logging

#### 3C. Add Shelf middleware
- Modify `diary_server/lib/src/server.dart` or `routes.dart`:
  - Add `otelMiddleware()` to the pipeline
  - This wraps ALL requests with spans automatically

#### 3D. Instrument database calls
- Modify `diary_functions/lib/src/database.dart`:
  - Wrap `pool.execute()` / `pool.run()` with `tracedQuery()`
  - Add connection pool metrics (active connections gauge)

#### 3E. Instrument key handlers
- Add child spans for business-critical operations:
  - `auth.dart` — login, registration (security-relevant)
  - `questionnaire_submit.dart` — form submission (data integrity)
  - `user.dart` — patient enrollment (compliance)

#### 3F. Cloud Error Reporting format
- Update error logging to use Cloud Error Reporting `@type` annotation
- Link errors to active trace/span

**Files to modify**:
- `apps/daily-diary/diary_server/bin/server.dart`
- `apps/daily-diary/diary_server/lib/src/server.dart`
- `apps/daily-diary/diary_server/pubspec.yaml`
- `apps/daily-diary/diary_functions/lib/src/database.dart`
- `apps/daily-diary/diary_functions/lib/src/auth.dart`
- `apps/daily-diary/diary_functions/lib/src/questionnaire_submit.dart`
- `apps/daily-diary/diary_functions/pubspec.yaml`

**Requirement traceability**: REQ-o00045A-L (error tracking), REQ-o00047F-I (tracing)

---

### Phase 4: Instrument `portal_server`

**Goal**: Same instrumentation as diary_server, for the sponsor portal

Same pattern as Phase 3, applied to:
- `apps/sponsor-portal/portal_server/`
- `apps/sponsor-portal/portal_functions/`

Key handlers to instrument:
- Admin operations
- Patient linking
- Data sync
- Report generation

**Files to modify**:
- `apps/sponsor-portal/portal_server/bin/server.dart`
- `apps/sponsor-portal/portal_server/lib/src/server.dart`
- `apps/sponsor-portal/portal_server/pubspec.yaml`
- `apps/sponsor-portal/portal_functions/lib/src/database.dart`
- `apps/sponsor-portal/portal_functions/pubspec.yaml`
- Key handler files in `portal_functions/lib/src/`

**Requirement traceability**: Same as Phase 3

---

### Phase 5: Custom Metrics

**Goal**: Application-level metrics exported to Cloud Monitoring

#### 5A. Define key metrics in `otel_common`
```
# Counters
http.server.request.count          {method, route, status_code}
auth.login.count                   {result: success|failure}
auth.registration.count            {result: success|failure}
questionnaire.submission.count     {sponsor, form_type}
audit.integrity_check.count        {result: pass|fail}

# Histograms
http.server.request.duration       {method, route}
db.query.duration                  {operation, table}
db.connection_pool.wait_time       {}

# Gauges (async/observable)
db.connection_pool.active          {}
db.connection_pool.idle            {}
```

#### 5B. Instrument metrics in servers
- HTTP middleware records request count + duration automatically
- Database wrapper records query duration
- Auth handlers record login/registration counts
- Health check records connection pool gauge

**Files to create/modify**:
- `packages/otel_common/lib/src/metrics.dart`
- Handler files as needed

**Requirement traceability**: REQ-o00047A-E (metrics collection)

---

### Phase 6: Database-Level Monitoring

**Goal**: Cloud SQL Insights + query-level observability

#### 6A. Enable Cloud SQL Insights (Terraform)
- Enable query insights in Cloud SQL instance config
- Configure query length and sampling rate

#### 6B. SQL query sanitization
- Strip literal values from SQL before setting `db.statement` span attribute
- Prevent PII/PHI leakage into traces (REQ-o00045Q-T)

#### 6C. Connection pool health
- Observable gauge for active/idle connections
- Alert when pool nears saturation (REQ-o00047K)

**Files to modify**:
- `infrastructure/terraform/modules/cloud-sql/` (if exists, or cloud-run module)
- `packages/otel_common/lib/src/db_tracing.dart`

**Requirement traceability**: REQ-o00047B,G,K (DB monitoring)

---

### Phase 7: Alerting & Dashboards (IaC)

**Goal**: Terraform-managed alerting policies and dashboards

#### 7A. Alert policies (Terraform)
- High error rate (>5%) → PagerDuty
- p95 latency >2s → Slack
- DB connection pool saturation → PagerDuty
- Audit trail tampering → Security team
- Service downtime → On-call

#### 7B. Dashboards (Terraform)
- Operations dashboard (request rate, latency, errors, DB CPU)
- Compliance dashboard (audit checks, retention status)

#### 7C. Uptime checks (Terraform)
- `/health` endpoint for both diary-server and portal-server
- Multi-region (Oregon, Virginia, Belgium)

**Files to create**:
- `infrastructure/terraform/modules/monitoring/main.tf`
- `infrastructure/terraform/modules/monitoring/alerts.tf`
- `infrastructure/terraform/modules/monitoring/dashboards.tf`
- `infrastructure/terraform/modules/monitoring/uptime.tf`
- `infrastructure/terraform/modules/monitoring/variables.tf`

**Requirement traceability**: REQ-o00046 (uptime), REQ-o00047J-Q (alerting & dashboards)

---

## Execution Order & Dependencies

```
Phase 1 (IaC)           ──► can deploy collector independently
    │
Phase 2 (otel_common)   ──► no infra dependency, can develop in parallel with Phase 1
    │
    ├──► Phase 3 (diary_server)   ──► needs Phase 2
    │
    ├──► Phase 4 (portal_server)  ──► needs Phase 2, can run in parallel with Phase 3
    │
    └──► Phase 5 (metrics)        ──► needs Phase 2, can run in parallel with 3 & 4
              │
Phase 6 (DB monitoring) ──► needs Phase 2 + some Phase 1 (Cloud SQL Insights)
    │
Phase 7 (alerts/dashboards) ──► needs Phases 1-6 to be generating data
```

**Phases 1 & 2 can run in parallel** — infra and code have no mutual dependency.
**Phases 3, 4, 5 can run in parallel** — they all build on Phase 2.
**Phase 7 is last** — alerting needs telemetry flowing to configure thresholds.

---

## PII/PHI Safety (FDA Compliance)

Every phase must enforce:
1. **SQL sanitization** — strip literal values before setting `db.statement`
2. **No patient data in spans** — span attributes must not contain PHI
3. **Anonymized user IDs only** — use opaque IDs, never names/emails in traces
4. **PII scrubbing** — error messages must be scrubbed before export
5. **Trace data retention** — follows same retention policy as logs (90-day hot, 7-year cold for audit)

---

## Testing Strategy

| Phase | Test Type | What |
|-------|-----------|------|
| 1 | Integration | Collector receives OTLP, forwards to GCP |
| 2 | Unit | Middleware creates spans, DB wrapper traces queries, logs include trace IDs |
| 3-4 | Integration | End-to-end request produces trace in Cloud Trace |
| 5 | Integration | Metrics appear in Cloud Monitoring |
| 6 | Manual | Cloud SQL Insights shows query performance |
| 7 | Manual | Alerts fire for simulated conditions |

---

## Risk & Mitigation

| Risk | Mitigation |
|------|-----------|
| OTel Collector adds latency | Sidecar on same host, async OTLP export, batch processor |
| Collector OOM on Cloud Run | Memory limiter processor, conservative batch sizes |
| Span volume costs (Cloud Trace $0.20/M) | Sampler: always-on for errors, probabilistic for success (e.g. 10%) |
| Breaking existing logging | Additive changes only — keep stdout JSON, add trace fields |
| dartastic_opentelemetry breaking changes | Pin to ^0.9.3, test in staging first |
| Cold start latency increase | Lazy OTel init, collector health check with startup probe |

---

## Environment Variables (New)

| Variable | Value | Where Set |
|----------|-------|-----------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318` | Cloud Run env |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` | Cloud Run env |
| `OTEL_SERVICE_NAME` | `diary-server` / `portal-server` | Cloud Run env |
| `OTEL_RESOURCE_ATTRIBUTES` | `deployment.environment=prod,...` | Cloud Run env |
| `OTEL_TRACES_SAMPLER` | `parentbased_traceidratio` | Cloud Run env |
| `OTEL_TRACES_SAMPLER_ARG` | `0.1` (10% in prod) | Cloud Run env |
| `GCP_PROJECT_ID` | (existing) | Doppler |

---

## Estimated Scope per Phase

| Phase | New Files | Modified Files | Complexity |
|-------|-----------|---------------|------------|
| 1 — IaC | 4-5 | 2-3 | Medium (Terraform + Docker) |
| 2 — otel_common | 8-10 | 0 | Medium (new package) |
| 3 — diary_server | 0 | 6-8 | Low-Medium (integration) |
| 4 — portal_server | 0 | 5-7 | Low-Medium (same pattern) |
| 5 — Metrics | 1-2 | 4-6 | Low |
| 6 — DB monitoring | 0-1 | 2-3 | Low |
| 7 — Alerts/Dashboards | 4-5 | 0-1 | Medium (Terraform) |

---

## Next Steps

1. Review this plan
2. Decide phase ordering / priority
3. Create sub-tickets under CUR-1100 for each phase
4. Start with Phases 1 & 2 in parallel
