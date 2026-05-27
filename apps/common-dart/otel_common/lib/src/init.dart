// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047: Performance Monitoring — OpenTelemetry integration
//   REQ-o00047F: End-to-end distributed tracing

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Whether OTLP export should be enabled for the given process [env].
///
/// Export is enabled only when an OTLP collector endpoint is configured and
/// the SDK is not explicitly disabled. Without this gate the SDK falls back to
/// the spec default endpoint (`http://localhost:4318`); on a Cloud Run service
/// with no collector sidecar the periodic metric reader then logs a
/// Connection-refused stack trace every 15s (CUR-1322). A configured endpoint
/// is the opt-in signal: any of the general or signal-specific
/// `OTEL_EXPORTER_OTLP*_ENDPOINT` vars. `OTEL_SDK_DISABLED` (the standard OTel
/// kill-switch) force-disables export regardless of endpoint.
bool otelExportEnabled(Map<String, String> env) {
  if (_isTruthy(env['OTEL_SDK_DISABLED'])) return false;
  final endpoint =
      env['OTEL_EXPORTER_OTLP_ENDPOINT'] ??
      env['OTEL_EXPORTER_OTLP_METRICS_ENDPOINT'] ??
      env['OTEL_EXPORTER_OTLP_TRACES_ENDPOINT'] ??
      env['OTEL_EXPORTER_OTLP_LOGS_ENDPOINT'];
  return endpoint != null && endpoint.trim().isNotEmpty;
}

bool _isTruthy(String? value) {
  if (value == null) return false;
  return const {'1', 'true', 'yes', 'on'}.contains(value.trim().toLowerCase());
}

/// Initialize OpenTelemetry for a Cloud Run Dart server.
///
/// Endpoint and protocol are handled by dartastic_opentelemetry defaults
/// and standard OTEL_* environment variables.
///
/// When no OTLP collector endpoint is configured (see [otelExportEnabled]),
/// the SDK is initialized with all network exporters disabled — metrics and
/// logs are turned off and traces use a no-op span processor — so the OTel API
/// stays available to instrumentation (the Shelf middleware, db tracing) while
/// nothing attempts to reach a non-existent collector.
Future<void> initializeOTel({
  required String serviceName,
  required String serviceVersion,
  Map<String, String>? additionalAttributes,
}) async {
  final environment = Platform.environment['ENVIRONMENT'] ?? 'development';
  final revision = Platform.environment['K_REVISION'] ?? 'unknown';

  final resourceAttrs = OTel.attributesFromMap({
    'deployment.environment': environment,
    'service.namespace': 'hht-diary',
    'cloud.provider': 'gcp',
    'cloud.platform': 'gcp_cloud_run',
    'service.instance.id': revision,
    if (additionalAttributes != null) ...additionalAttributes,
  });

  final sampler = _buildSampler(environment);
  final exportEnabled = otelExportEnabled(Platform.environment);

  await OTel.initialize(
    serviceName: serviceName,
    serviceVersion: serviceVersion,
    resourceAttributes: resourceAttrs,
    sampler: sampler,
    enableMetrics: exportEnabled,
    enableLogs: exportEnabled,
    // Passing a span processor suppresses the default OTLP span exporter, so
    // when export is disabled traces are dropped locally instead of being
    // pushed to an unreachable collector.
    spanProcessor: exportEnabled
        ? null
        : SimpleSpanProcessor(_NoopSpanExporter()),
  );

  if (!exportEnabled) {
    stdout.writeln(
      'otel_common: OTLP export disabled (no OTEL_EXPORTER_OTLP*_ENDPOINT '
      'configured or OTEL_SDK_DISABLED set); telemetry is collected but not '
      'exported.',
    );
  }
}

/// Span exporter that discards spans. Used when no OTLP collector is
/// configured so the SDK never opens a connection to export traces.
class _NoopSpanExporter implements SpanExporter {
  @override
  Future<void> export(List<Span> spans) async {}

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

/// Build a sampler based on environment.
///
/// Production: parent-based with 10% ratio for root spans.
/// Development: always-on for full visibility.
Sampler _buildSampler(String environment) {
  if (environment == 'production' || environment == 'prod') {
    final ratioStr = Platform.environment['OTEL_TRACES_SAMPLER_ARG'] ?? '0.1';
    final ratio = double.tryParse(ratioStr) ?? 0.1;
    return ParentBasedSampler(TraceIdRatioSampler(ratio));
  }
  return const AlwaysOnSampler();
}

/// Gracefully shut down OTel — flushes pending spans, metrics, and logs.
///
/// Call this in your SIGTERM/SIGINT handler before exiting.
Future<void> shutdownOTel() async {
  // OTel.shutdown() flushes traces and metrics but not logs in 1.0.0-alpha.
  // Flush the LoggerProvider explicitly to ensure all log records are exported.
  try {
    await OTel.loggerProvider().shutdown();
  } catch (_) {
    // Best-effort: loggerProvider may not be initialized
  }
  await OTel.shutdown();
}
