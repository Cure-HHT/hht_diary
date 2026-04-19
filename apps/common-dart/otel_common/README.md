# otel_common

Shared OpenTelemetry instrumentation for HHT Diary platform servers. Pure Dart package with no Flutter dependencies.

## Features

- Standardized OTel initialization for Cloud Run services
- Shelf HTTP middleware with W3C TraceContext propagation
- Database query tracing with SQL sanitization (PII/PHI safe)
- Trace-correlated structured logging (Cloud Logging format)
- Cloud Error Reporting integration with PII scrubbing

## Requirements Implemented

| Requirement | Description                                         |
|-------------|-----------------------------------------------------|
| REQ-o00047  | Performance Monitoring -- OpenTelemetry integration |
| REQ-o00047F | End-to-end distributed tracing                      |
| REQ-o00047G | Database query tracing                              |
| REQ-o00047I | HTTP request tracing with semantic conventions      |
| REQ-o00045  | Error tracking with Cloud Error Reporting           |
| REQ-o00045Q | PII/PHI scrubbing in traces and error messages      |

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  otel_common:
    path: ../common-dart/otel_common
```

### Basic Usage

```dart
import 'package:otel_common/otel_common.dart';

Future<void> main() async {
  // 1. Initialize OpenTelemetry
  await initializeOTel(
    serviceName: 'diary-server',
    serviceVersion: '1.0.0',
  );

  // 2. Configure trace-correlated logging
  configureTracedLogging(gcpProjectId: 'hht-diary-prod');

  // 3. Add HTTP middleware to your Shelf pipeline
  final handler = const Pipeline()
      .addMiddleware(otelMiddleware())
      .addHandler(router);

  // 4. Wrap database queries
  final result = await tracedQuery(
    'SELECT',
    'SELECT * FROM users WHERE id = @id',
    () => pool.execute(Sql.named(query), parameters: {'id': userId}),
    table: 'users',
  );

  // 5. Report errors with trace linkage
  try {
    await riskyOperation();
  } catch (e, st) {
    reportAndRecordError(e, stackTrace: st);
  }

  // 6. Graceful shutdown
  await shutdownOTel();
}
```

## API Reference

### Initialization

- `initializeOTel({serviceName, serviceVersion, additionalAttributes})` -- Initialize OTel for a Cloud Run Dart server. Reads `ENVIRONMENT`, `K_REVISION`, and `OTEL_EXPORTER_OTLP_ENDPOINT` from environment.
- `shutdownOTel()` -- Flush pending spans/metrics and shut down. Call in SIGTERM/SIGINT handler.

### HTTP Middleware

- `otelMiddleware({tracerName})` -- Shelf middleware that creates a server span per request with HTTP semantic conventions. Propagates W3C TraceContext and injects `x-trace-id`/`x-span-id` response headers.

### Database Tracing

- `tracedQuery<T>(operation, sql, execute, {table, tracerName})` -- Wrap a DB query with an OTel span. SQL is sanitized to strip literal values before recording.
- `sanitizeSql(sql)` -- Strip string/numeric literals from SQL to prevent PII leakage.

### Logging

- `configureTracedLogging({level, gcpProjectId})` -- Set up the root logger to output Cloud Logging JSON with trace correlation.
- `logWithTrace(severity, message, {labels, gcpProjectId})` -- Ad-hoc structured log entry with trace correlation.

### Error Reporting

- `reportError(error, {stackTrace, serviceName, serviceVersion, context})` -- Emit a Cloud Error Reporting JSON entry to stderr.
- `reportAndRecordError(error, {stackTrace, serviceName, serviceVersion})` -- Record on active span and emit error report.
- `scrubPii(message)` -- Remove emails, JWTs, and phone numbers from a string.

## Testing

### Run Tests

```bash
# Simple test run
./tool/test.sh

# With custom concurrency
./tool/test.sh --concurrency 20
```

### Run Tests with Coverage

```bash
# Generate coverage report
./tool/coverage.sh

# View HTML report
open coverage/html/index.html  # Mac
xdg-open coverage/html/index.html  # Linux
```

### Install lcov (for coverage HTML reports)

**Mac**:
```bash
brew install lcov
```

**Linux** (Ubuntu/Debian):
```bash
sudo apt-get update
sudo apt-get install lcov
```

**Linux** (Fedora/RHEL):
```bash
sudo dnf install lcov
```

## Project Structure

```
lib/
├── otel_common.dart          # Public API exports
└── src/
    ├── init.dart             # OTel initialization & shutdown
    ├── middleware.dart        # Shelf HTTP middleware
    ├── db_tracing.dart       # Database query tracing & SQL sanitization
    ├── logging.dart          # Trace-correlated structured logging
    └── error_reporting.dart  # Cloud Error Reporting & PII scrubbing
test/
├── helpers/
│   └── otel_test_helpers.dart  # InMemorySpanExporter & test setup
├── db_tracing_test.dart        # SQL sanitization unit tests
├── error_reporting_test.dart   # PII scrubbing unit tests
├── middleware_integration_test.dart
├── db_tracing_integration_test.dart
├── error_reporting_integration_test.dart
└── logging_integration_test.dart
tool/
├── test.sh                   # Test runner
└── coverage.sh               # Coverage wrapper
```

## Environment Variables

| Variable                      | Default                 | Description                                       |
|-------------------------------|-------------------------|---------------------------------------------------|
| `ENVIRONMENT`                 | `development`           | `development` or `production` -- controls sampler |
| `K_REVISION`                  | `unknown`               | Cloud Run revision ID                             |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | *(library default)*     | Override only if collector is non-standard                           |
| `OTEL_TRACES_SAMPLER_ARG`     | `0.1`                   | Trace sampling ratio (production only)            |
| `OTEL_SERVICE_NAME`           | `unknown`               | Fallback service name for error reports           |

## Dependencies

- [dartastic_opentelemetry](https://pub.dev/packages/dartastic_opentelemetry) -- OpenTelemetry SDK for Dart
- [shelf](https://pub.dev/packages/shelf) -- HTTP server middleware
- [logging](https://pub.dev/packages/logging) -- Dart logging framework
