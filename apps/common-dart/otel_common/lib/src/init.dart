// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047: Performance Monitoring — OpenTelemetry integration
//   REQ-o00047F: End-to-end distributed tracing

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Initialize OpenTelemetry for a Cloud Run Dart server.
///
/// Endpoint and protocol are handled by dartastic_opentelemetry defaults
/// and standard OTEL_* environment variables.
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

  await OTel.initialize(
    serviceName: serviceName,
    serviceVersion: serviceVersion,
    resourceAttributes: resourceAttrs,
    sampler: sampler,
    enableMetrics: true,
    enableLogs: true,
  );
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
