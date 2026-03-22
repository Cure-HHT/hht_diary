// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047G: Database query tracing
//   REQ-o00045Q: PII/PHI scrubbing in trace data

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Wraps a database query with an OTel span following DB semantic conventions.
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
