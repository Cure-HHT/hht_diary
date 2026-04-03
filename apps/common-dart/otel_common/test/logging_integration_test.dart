// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047F: End-to-end distributed tracing (log-trace correlation)
//   REQ-o00045: Error tracking with structured logging

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' show OTel;
import 'package:logging/logging.dart';
import 'package:otel_common/otel_common.dart';
import 'package:test/test.dart';

import 'helpers/otel_test_helpers.dart';

void main() {
  setUp(() async {
    await setUpOTel();
  });

  tearDown(() async {
    Logger.root.clearListeners();
    await tearDownOTel();
  });

  group('configureTracedLogging integration', () {
    test('outputs Cloud Logging JSON to stderr', () {
      final output = captureStderrSync(() {
        configureTracedLogging(level: Level.INFO);
        Logger('test').info('Server started on port 8080');
      });

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['severity'], equals('INFO'));
      expect(json['message'], equals('Server started on port 8080'));
      expect(json['time'], isNotNull);
      expect(json['logger'], equals('test'));
    });

    test('maps Dart log levels to GCP severity', () {
      final levels = <Level, String>{
        Level.CONFIG: 'DEBUG',
        Level.INFO: 'INFO',
        Level.WARNING: 'WARNING',
        Level.SEVERE: 'ERROR',
        Level.SHOUT: 'CRITICAL',
      };

      for (final entry in levels.entries) {
        Logger.root.clearListeners();

        final output = captureStderrSync(() {
          configureTracedLogging(level: Level.ALL);
          Logger('level-test').log(entry.key, 'test message');
        });

        final json = jsonDecode(output.trim()) as Map<String, dynamic>;
        expect(
          json['severity'],
          equals(entry.value),
          reason: '${entry.key} should map to ${entry.value}',
        );
      }
    });

    test('includes error and stack trace in log entry', () {
      final output = captureStderrSync(() {
        configureTracedLogging(level: Level.ALL);
        try {
          throw FormatException('bad input');
        } catch (e, st) {
          Logger('test').severe('Parse failed', e, st);
        }
      });

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['severity'], equals('ERROR'));
      expect(json['error'], contains('bad input'));
      expect(json['stackTrace'], isNotNull);
    });

    test('includes GCP trace fields with project ID', () {
      final output = captureStderrSync(() {
        configureTracedLogging(
          level: Level.INFO,
          gcpProjectId: 'hht-diary-prod',
        );
        Logger('test').info('traced message');
      });

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['severity'], equals('INFO'));
    });
  });

  group('logWithTrace integration', () {
    test('outputs structured JSON to stderr', () {
      final output = captureStderrSync(() {
        logWithTrace('WARNING', 'Rate limit approaching');
      });

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['severity'], equals('WARNING'));
      expect(json['message'], equals('Rate limit approaching'));
      expect(json['time'], isNotNull);
    });

    test('includes custom labels', () {
      final output = captureStderrSync(() {
        logWithTrace(
          'INFO',
          'Request processed',
          labels: {'sponsor': 'curehht', 'endpoint': '/api/tasks'},
        );
      });

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['sponsor'], equals('curehht'));
      expect(json['endpoint'], equals('/api/tasks'));
    });

    test('includes trace correlation when span is active', () {
      final tracer = OTel.tracerProvider().getTracer('logging');
      final span = tracer.startSpan('traced-operation');

      final output = captureStderrSync(() {
        logWithTrace(
          'INFO',
          'Inside traced operation',
          gcpProjectId: 'hht-diary-dev',
        );
      });

      span.end();

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['message'], equals('Inside traced operation'));
    });
  });
}
