import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// OTel signals that have an independent OTLP push exporter, mapped to their
/// signal-specific endpoint env var (per the OpenTelemetry spec).
const _signalEndpointVars = <String, String>{
  'metrics': 'OTEL_EXPORTER_OTLP_METRICS_ENDPOINT',
  'logs': 'OTEL_EXPORTER_OTLP_LOGS_ENDPOINT',
  'traces': 'OTEL_EXPORTER_OTLP_TRACES_ENDPOINT',
};

/// Whether OTLP export should be enabled for the given process [env].
///
/// Without this gate the SDK falls back to the spec default endpoint
/// (`http://localhost:4318`); on a Cloud Run service with no collector sidecar
/// the periodic metric reader then logs a Connection-refused stack trace every
/// 15s (CUR-1322). A configured, non-blank endpoint is the opt-in signal.
///
/// The decision is made **per signal** so a partial configuration can't
/// reintroduce the noise: enabling, say, only traces export must not leave the
/// metrics/logs exporters pointing at the localhost default. With [signal] one
/// of `metrics` | `logs` | `traces`, returns whether that signal's exporter
/// should run — true when its signal-specific
/// `OTEL_EXPORTER_OTLP_<SIGNAL>_ENDPOINT` or the general
/// `OTEL_EXPORTER_OTLP_ENDPOINT` is set to a non-blank value. With [signal]
/// null (the default), returns whether *any* signal would export.
/// `OTEL_SDK_DISABLED` (the standard OTel kill-switch) force-disables every
/// signal regardless of endpoint.
// Implements: DIARY-PRD-platform-operations-monitoring/B
bool otelExportEnabled(Map<String, String> env, {String? signal}) {
  if (_isTruthy(env['OTEL_SDK_DISABLED'])) return false;
  if (signal == null) {
    return _signalEndpointVars.keys.any(
      (s) => otelExportEnabled(env, signal: s),
    );
  }
  final signalVar = _signalEndpointVars[signal];
  assert(signalVar != null, 'unknown OTel signal: $signal');
  return _firstNonBlank([
        if (signalVar != null) env[signalVar],
        env['OTEL_EXPORTER_OTLP_ENDPOINT'],
      ]) !=
      null;
}

/// First value that is non-null and not blank after trimming, else null.
String? _firstNonBlank(Iterable<String?> values) {
  for (final value in values) {
    if (value != null && value.trim().isNotEmpty) return value;
  }
  return null;
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
/// Each OTLP signal is gated independently (see [otelExportEnabled]): a signal
/// exports only when its own endpoint (or the general endpoint) is configured.
/// A signal with no configured endpoint is initialized so the OTel API stays
/// available to instrumentation (the Shelf middleware, db tracing) but never
/// reaches the network — metrics/logs exporters are disabled and traces use a
/// no-op span processor — so an unconfigured signal can't fall back to the
/// localhost default and reintroduce the Connection-refused noise.
// Implements: DIARY-PRD-platform-operations-monitoring/B
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
  final env = Platform.environment;
  final metricsEnabled = otelExportEnabled(env, signal: 'metrics');
  final logsEnabled = otelExportEnabled(env, signal: 'logs');
  final tracesEnabled = otelExportEnabled(env, signal: 'traces');

  await OTel.initialize(
    serviceName: serviceName,
    serviceVersion: serviceVersion,
    resourceAttributes: resourceAttrs,
    sampler: sampler,
    enableMetrics: metricsEnabled,
    enableLogs: logsEnabled,
    // Passing a span processor suppresses the default OTLP span exporter, so
    // when traces export is disabled spans are dropped locally instead of
    // being pushed to an unreachable collector.
    spanProcessor: tracesEnabled
        ? null
        : SimpleSpanProcessor(_NoopSpanExporter()),
  );

  if (!metricsEnabled || !logsEnabled || !tracesEnabled) {
    final disabled = <String>[
      if (!metricsEnabled) 'metrics',
      if (!logsEnabled) 'logs',
      if (!tracesEnabled) 'traces',
    ].join(', ');
    stdout.writeln(
      'otel_common: OTLP export disabled for [$disabled] (no matching '
      'OTEL_EXPORTER_OTLP*_ENDPOINT configured or OTEL_SDK_DISABLED set); '
      'those signals are collected but not exported.',
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
// Implements: DIARY-PRD-platform-operations-monitoring/B
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
