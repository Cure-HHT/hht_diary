// Demo server that exercises all otel_common APIs.
//
// Run with: dart run example/demo_server.dart
// Then open http://localhost:3000 (Grafana) to view traces.
//
// Endpoints:
//   GET  /health        — health check (fast, always 200)
//   GET  /api/patients  — simulated DB query with tracing
//   GET  /api/error     — triggers error reporting
//   GET  /api/slow      — simulated slow endpoint (~500ms)

import 'dart:async';
import 'dart:io';

import 'package:otel_common/otel_common.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  // 1. Initialize OpenTelemetry — exports to localhost:4317 by default.
  await initializeOTel(
    serviceName: 'otel-demo-server',
    serviceVersion: '0.0.1',
    additionalAttributes: {'demo': 'true'},
  );

  // 2. Configure trace-correlated structured logging.
  configureTracedLogging(gcpProjectId: 'hht-diary-local');

  // 3. Build the Shelf pipeline with OTel middleware.
  final handler = const Pipeline()
      .addMiddleware(otelMiddleware())
      .addMiddleware(logRequests())
      .addHandler(_router);

  // 4. Start the server.
  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Demo server listening on http://localhost:${server.port}');
  print('');
  print('Try these endpoints:');
  print('  curl http://localhost:8080/health');
  print('  curl http://localhost:8080/api/patients');
  print('  curl http://localhost:8080/api/error');
  print('  curl http://localhost:8080/api/slow');
  print('');
  print('View traces: http://localhost:3000/explore');
  print('  → Select "Tempo" datasource → Search → Run query');
  print('');
  print('Press Ctrl+C to stop.');

  // Graceful shutdown on SIGINT/SIGTERM.
  final signals = [ProcessSignal.sigint, ProcessSignal.sigterm];
  for (final sig in signals) {
    sig.watch().listen((_) async {
      print('\nShutting down...');
      await server.close(force: true);
      await shutdownOTel();
      exit(0);
    });
  }
}

/// Simple request router.
Future<Response> _router(Request request) async {
  final path = request.requestedUri.path;

  switch (path) {
    case '/health':
      return Response.ok('OK');

    case '/api/patients':
      return _handlePatients(request);

    case '/api/error':
      return _handleError(request);

    case '/api/slow':
      return _handleSlow(request);

    default:
      return Response.notFound('Not found: $path');
  }
}

/// Simulates a DB query using tracedQuery.
Future<Response> _handlePatients(Request request) async {
  // tracedQuery wraps the "DB call" with an OTel span.
  final result = await tracedQuery<String>(
    'SELECT',
    "SELECT id, name FROM participants WHERE trial_id = 'trial-001'",
    () async {
      // Simulate query latency.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return '{"patients": [{"id": "p-001", "name": "Demo Patient"}]}';
    },
    table: 'participants',
  );

  logWithTrace('INFO', 'Returned patient list', labels: {'count': '1'});
  return Response.ok(result, headers: {'content-type': 'application/json'});
}

/// Triggers error reporting.
Future<Response> _handleError(Request request) async {
  try {
    throw FormatException('Invalid input from user@example.com: bad payload');
  } catch (e, st) {
    // reportAndRecordError scrubs PII and records on the active span.
    reportAndRecordError(e, stackTrace: st);
    return Response.internalServerError(
      body: '{"error": "Something went wrong"}',
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Simulates a slow endpoint (~500ms).
Future<Response> _handleSlow(Request request) async {
  await tracedQuery<void>(
    'SELECT',
    "SELECT * FROM large_table WHERE created_at > '2024-01-01'",
    () async {
      await Future<void>.delayed(const Duration(milliseconds: 450));
    },
    table: 'large_table',
  );
  return Response.ok(
    '{"status": "done"}',
    headers: {'content-type': 'application/json'},
  );
}
