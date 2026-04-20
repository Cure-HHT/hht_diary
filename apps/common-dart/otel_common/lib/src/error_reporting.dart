// IMPLEMENTS REQUIREMENTS:
//   REQ-o00045: Error tracking with Cloud Error Reporting
//   REQ-o00045Q: PII scrubbing in error messages

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Report an error in Cloud Error Reporting format with trace linkage.
///
/// Cloud Error Reporting requires a specific JSON structure with `@type`
/// to auto-detect error reports from Cloud Logging.
///
/// Error messages are scrubbed to prevent PII/PHI leakage.
void reportError(
  Object error, {
  StackTrace? stackTrace,
  String? serviceName,
  String? serviceVersion,
  Map<String, dynamic>? context,
}) {
  final tracerProvider = OTel.tracerProvider();
  final tracer = tracerProvider.getTracer('error-reporting');
  final currentSpan = tracer.currentSpan;

  final entry = <String, dynamic>{
    'severity': 'ERROR',
    'message': scrubPii(error.toString()),
    '@type':
        'type.googleapis.com/google.devtools.clouderrorreporting.v1beta1.ReportedErrorEvent',
    'serviceContext': {
      'service':
          serviceName ?? Platform.environment['OTEL_SERVICE_NAME'] ?? 'unknown',
      'version':
          serviceVersion ?? Platform.environment['K_REVISION'] ?? 'unknown',
    },
    'time': DateTime.now().toUtc().toIso8601String(),
  };

  if (stackTrace != null) {
    entry['stack_trace'] = stackTrace.toString();
  }

  if (currentSpan != null) {
    try {
      final spanContext = (currentSpan as dynamic).spanContext;
      entry['logging.googleapis.com/trace'] = spanContext.traceId.toString();
      entry['logging.googleapis.com/spanId'] = spanContext.spanId.toString();
    } catch (_) {
      // No active span context; skip trace linkage.
    }
  }

  if (context != null) {
    entry['context'] = context;
  }

  stderr.writeln(jsonEncode(entry));
}

/// Record the error on the current OTel span (if one exists) and report it.
void reportAndRecordError(
  Object error, {
  StackTrace? stackTrace,
  String? serviceName,
  String? serviceVersion,
}) {
  // Record on active span for trace correlation.
  final tracerProvider = OTel.tracerProvider();
  final tracer = tracerProvider.getTracer('error-reporting');
  final currentSpan = tracer.currentSpan;
  if (currentSpan != null) {
    try {
      (currentSpan as dynamic).recordException(error, stackTrace: stackTrace);
      (currentSpan as dynamic).setStatus(
        SpanStatusCode.Error,
        scrubPii(error.toString()),
      );
    } catch (_) {
      // Best-effort span recording.
    }
  }

  // Also emit as structured error log for Cloud Error Reporting.
  reportError(
    error,
    stackTrace: stackTrace,
    serviceName: serviceName,
    serviceVersion: serviceVersion,
  );
}

/// Scrub common PII patterns from error messages.
///
/// Removes email addresses, JWTs, and potential phone numbers.
/// This is a best-effort safety net — errors should not contain PII
/// in the first place (REQ-o00045Q).
String scrubPii(String message) {
  var scrubbed = message;

  // Email addresses
  scrubbed = scrubbed.replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), '[EMAIL]');

  // JWT tokens (three base64 segments separated by dots)
  scrubbed = scrubbed.replaceAll(
    RegExp(r'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
    '[JWT]',
  );

  // Phone numbers (US format)
  scrubbed = scrubbed.replaceAll(
    RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'),
    '[PHONE]',
  );

  return scrubbed;
}
