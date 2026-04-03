// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047G: Database query tracing
//   REQ-o00047: Performance Monitoring — custom application metrics
//   REQ-o00045Q: PII/PHI scrubbing in trace data

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

// IMPLEMENTS: REQ-o00047
// Cached per-MeterProvider to survive OTel.reset() in tests while
// remaining efficient in production (created once, reused).
MeterProvider? _lastMeterProvider;
dynamic _dbQueryDuration;

dynamic _getDbQueryDuration() {
  final current = OTel.meterProvider();
  if (!identical(current, _lastMeterProvider)) {
    _lastMeterProvider = current;
    _dbQueryDuration = OTel.meter('db').createHistogram<double>(
      name: 'database_query_duration_seconds',
      unit: 's',
      description: 'Database query latency distribution',
    );
  }
  return _dbQueryDuration;
}

/// Wraps a database query with an OTel span following DB semantic conventions,
/// and records query duration as a metric.
///
/// The SQL statement is sanitized to strip literal values before being set
/// as a span attribute, preventing PII/PHI leakage into traces.
///
/// Example:
/// ```dart
/// final result = await tracedQuery(
///   'SELECT',
///   'SELECT * FROM users WHERE id = @id',
///   () => pool.execute(Sql.named(query), parameters: {'id': userId}),
/// );
/// ```
Future<T> tracedQuery<T>(
  String operation,
  String sql,
  Future<T> Function() execute, {
  String? table,
  String tracerName = 'db',
}) async {
  final tracer = OTel.tracerProvider().getTracer(tracerName);
  final spanName = table != null ? '$operation $table' : 'db.$operation';
  final span = tracer.startSpan(spanName, kind: SpanKind.client);
  final stopwatch = Stopwatch()..start();

  span.setStringAttribute('db.system', 'postgresql');
  span.setStringAttribute('db.operation', operation);
  span.setStringAttribute('db.statement', sanitizeSql(sql));
  if (table != null) {
    span.setStringAttribute('db.sql.table', table);
  }

  try {
    final result = await execute();
    span.setStatus(SpanStatusCode.Ok);
    return result;
  } catch (e, st) {
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
    stopwatch.stop();
    _getDbQueryDuration().recordWithMap(stopwatch.elapsedMicroseconds / 1e6, {
      'db.operation': operation,
      if (table != null) 'db.sql.table': table,
    });
  }
}

/// Sanitize SQL by replacing literal values with placeholders.
///
/// This prevents PII/PHI from leaking into trace spans (REQ-o00045Q).
/// - Replaces quoted strings ('...') with '?'
/// - Replaces numeric literals with ?
/// - Preserves named parameters (@name) as-is since they don't contain values
String sanitizeSql(String sql) {
  // Replace single-quoted string literals with '?'
  var sanitized = sql.replaceAll(RegExp(r"'[^']*'"), "'?'");

  // Replace standalone numeric literals (not part of identifiers or parameters)
  sanitized = sanitized.replaceAll(
    RegExp(r'(?<=\s|=|<|>|,|\()(\d+\.?\d*)(?=\s|,|\)|$|;)'),
    '?',
  );

  return sanitized;
}
