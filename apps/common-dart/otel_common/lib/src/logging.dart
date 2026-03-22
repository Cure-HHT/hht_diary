// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047F: End-to-end distributed tracing (log-trace correlation)
//   REQ-o00045: Error tracking with structured logging

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:logging/logging.dart';

/// Configure the root logger to output Cloud Logging structured JSON
/// with OpenTelemetry trace correlation.
///
/// Call this once at server startup, after [initializeOTel].
///
/// Cloud Logging uses `logging.googleapis.com/trace` and
/// `logging.googleapis.com/spanId` to link log entries to traces.
void configureTracedLogging({
  Level level = Level.INFO,
  String? gcpProjectId,
}) {
  Logger.root.level = level;
  Logger.root.onRecord.listen((record) {
    final entry = _buildLogEntry(record, gcpProjectId: gcpProjectId);
    // Use stderr for Cloud Run — stdout is for application output.
    stderr.writeln(jsonEncode(entry));
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
}

Map<String, dynamic> _buildLogEntry(
  LogRecord record, {
  String? gcpProjectId,
}) {
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
