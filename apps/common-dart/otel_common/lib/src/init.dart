// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047: Performance Monitoring — OpenTelemetry integration
//   REQ-o00047F: End-to-end distributed tracing

import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Initialize OpenTelemetry for a Cloud Run Dart server.
///
/// Reads configuration from environment variables (OTEL_*) with sensible
/// defaults for local development. In production, the OTel Collector sidecar
/// receives OTLP on localhost:4318.
Future<void> initializeOTel({
  required String serviceName,
  required String serviceVersion,
  Map<String, String>? additionalAttributes,
}) async {
  final environment = Platform.environment['ENVIRONMENT'] ?? 'development';
  final revision = Platform.environment['K_REVISION'] ?? 'unknown';
  final endpoint =
      Platform.environment['OTEL_EXPORTER_OTLP_ENDPOINT'] ??
      'http://localhost:4317';
  final secure = endpoint.startsWith('https');

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
    endpoint: endpoint,
    secure: secure,
    resourceAttributes: resourceAttrs,
    sampler: sampler,
    enableMetrics: true,
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

/// Gracefully shut down OTel — flushes pending spans and metrics.
///
/// Call this in your SIGTERM/SIGINT handler before exiting.
Future<void> shutdownOTel() async {
  await OTel.shutdown();
}
