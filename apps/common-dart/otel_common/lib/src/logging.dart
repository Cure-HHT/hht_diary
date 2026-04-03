// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047F: End-to-end distributed tracing (log-trace correlation)
//   REQ-o00045: Error tracking with structured logging

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart'
    show OTel, Severity;
import 'package:logging/logging.dart';

/// Configure the root logger to output Cloud Logging structured JSON
/// with OpenTelemetry trace correlation, and bridge log records to
/// the OTel Logs pipeline for OTLP export.
///
/// Call this once at server startup, after [initializeOTel].
///
/// Cloud Logging uses `logging.googleapis.com/trace` and
/// `logging.googleapis.com/spanId` to link log entries to traces.
void configureTracedLogging({Level level = Level.INFO, String? gcpProjectId}) {
  Logger.root.level = level;

  // OTel Logger for emitting log records via OTLP.
  // Captured in the closure so we create it once.
  final otelLogger = OTel.logger('dart.logging');

  Logger.root.onRecord.listen((record) {
    // Structured JSON to stderr for Cloud Run / Cloud Logging
    final entry = _buildLogEntry(record, gcpProjectId: gcpProjectId);
    stderr.writeln(jsonEncode(entry));

    // OTel Log Record for OTLP export to collector
    _emitOTelLogRecord(otelLogger, record);
  });
}

/// Write a structured log entry with trace correlation.
///
/// Use this for ad-hoc logging outside the [Logger] framework.
void logWithTrace(
  String severity,
  String message, {
  Map<String, dynamic>? labels,
  String? gcpProjectId,
}) {
  final tracerProvider = OTel.tracerProvider();
  final tracer = tracerProvider.getTracer('logging');
  final currentSpan = tracer.currentSpan;

  final logEntry = <String, dynamic>{
    'severity': severity,
    'message': message,
    'time': DateTime.now().toUtc().toIso8601String(),
  };

  _addTraceFields(logEntry, currentSpan, gcpProjectId);

  if (labels != null) {
    logEntry.addAll(labels);
  }

  stderr.writeln(jsonEncode(logEntry));

  // Also emit as OTel Log Record
  try {
    final otelLogger = OTel.logger('dart.logging');
    otelLogger.emit(
      severityNumber: _severityFromString(severity),
      severityText: severity,
      body: message,
      timeStamp: DateTime.now(),
      attributes: labels != null
          ? OTel.attributesFromMap(
              labels.map((k, v) => MapEntry(k, v.toString())),
            )
          : null,
    );
  } catch (_) {
    // Best-effort: don't break logging if OTel Logs fails
  }
}

/// Emit a Dart [LogRecord] as an OTel Log Record via the Logs pipeline.
void _emitOTelLogRecord(dynamic otelLogger, LogRecord record) {
  try {
    final attrs = <String, Object>{'logger.name': record.loggerName};
    if (record.error != null) {
      attrs['exception.message'] = record.error.toString();
    }
    if (record.stackTrace != null) {
      attrs['exception.stacktrace'] = record.stackTrace.toString();
    }

    otelLogger.emit(
      severityNumber: _mapLevelToSeverity(record.level),
      severityText: _mapLevel(record.level),
      body: record.message,
      timeStamp: record.time,
      attributes: OTel.attributesFromMap(attrs),
    );
  } catch (_) {
    // Best-effort: don't break logging if OTel Logs pipeline fails
  }
}

Map<String, dynamic> _buildLogEntry(LogRecord record, {String? gcpProjectId}) {
  final tracerProvider = OTel.tracerProvider();
  final tracer = tracerProvider.getTracer('logging');
  final currentSpan = tracer.currentSpan;

  final entry = <String, dynamic>{
    'severity': _mapLevel(record.level),
    'message': record.message,
    'time': record.time.toUtc().toIso8601String(),
    'logger': record.loggerName,
  };

  _addTraceFields(entry, currentSpan, gcpProjectId);

  if (record.error != null) {
    entry['error'] = record.error.toString();
  }
  if (record.stackTrace != null) {
    entry['stackTrace'] = record.stackTrace.toString();
  }

  return entry;
}

void _addTraceFields(
  Map<String, dynamic> entry,
  dynamic currentSpan,
  String? gcpProjectId,
) {
  if (currentSpan == null) return;

  try {
    final spanContext = (currentSpan as dynamic).spanContext;
    final traceId = spanContext.traceId.toString();
    final spanId = spanContext.spanId.toString();
    final traceFlags = spanContext.traceFlags;

    if (gcpProjectId != null) {
      entry['logging.googleapis.com/trace'] =
          'projects/$gcpProjectId/traces/$traceId';
    } else {
      entry['logging.googleapis.com/trace'] = traceId;
    }
    entry['logging.googleapis.com/spanId'] = spanId;
    entry['logging.googleapis.com/trace_sampled'] = traceFlags.isSampled;
  } catch (_) {
    // Span may not have context available; skip trace correlation.
  }
}

/// Map Dart [Level] to GCP Cloud Logging severity strings.
String _mapLevel(Level level) {
  if (level >= Level.SHOUT) return 'CRITICAL';
  if (level >= Level.SEVERE) return 'ERROR';
  if (level >= Level.WARNING) return 'WARNING';
  if (level >= Level.INFO) return 'INFO';
  if (level >= Level.CONFIG) return 'DEBUG';
  return 'DEBUG';
}

/// Map Dart [Level] to OTel [Severity] for the Logs signal.
Severity _mapLevelToSeverity(Level level) {
  if (level >= Level.SHOUT) return Severity.FATAL;
  if (level >= Level.SEVERE) return Severity.ERROR;
  if (level >= Level.WARNING) return Severity.WARN;
  if (level >= Level.INFO) return Severity.INFO;
  if (level >= Level.CONFIG) return Severity.DEBUG2;
  if (level >= Level.FINE) return Severity.DEBUG;
  return Severity.TRACE;
}

/// Map a GCP severity string to OTel [Severity].
Severity _severityFromString(String severity) {
  switch (severity.toUpperCase()) {
    case 'CRITICAL':
      return Severity.FATAL;
    case 'ERROR':
      return Severity.ERROR;
    case 'WARNING':
      return Severity.WARN;
    case 'INFO':
      return Severity.INFO;
    case 'DEBUG':
      return Severity.DEBUG;
    default:
      return Severity.INFO;
  }
}
