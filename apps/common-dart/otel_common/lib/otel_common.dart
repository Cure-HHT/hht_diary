// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047: Performance Monitoring — OpenTelemetry integration
//   REQ-o00045: Error tracking

/// Shared OpenTelemetry instrumentation for HHT Diary platform servers.
///
/// Provides standardized OTel initialization, Shelf HTTP middleware,
/// database query tracing, trace-correlated logging, and Cloud Error
/// Reporting integration.
library otel_common;

export 'src/init.dart' show initializeOTel, shutdownOTel;
export 'src/middleware.dart' show otelMiddleware;
export 'src/db_tracing.dart' show tracedQuery, sanitizeSql;
export 'src/logging.dart' show configureTracedLogging, logWithTrace;
export 'src/error_reporting.dart'
    show reportError, reportAndRecordError, scrubPii;
