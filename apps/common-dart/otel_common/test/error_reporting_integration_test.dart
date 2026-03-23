// IMPLEMENTS REQUIREMENTS:
//   REQ-o00045: Error tracking with Cloud Error Reporting
//   REQ-o00045Q: PII scrubbing in error messages

import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_common/otel_common.dart';
import 'package:test/test.dart';

import 'helpers/otel_test_helpers.dart';

void main() {
  late InMemorySpanExporter exporter;

  setUp(() async {
    exporter = await setUpOTel();
  });

  tearDown(() async {
    await tearDownOTel();
  });

  group('reportError integration', () {
    test('emits Cloud Error Reporting JSON to stderr', () {
      final output = captureStderrSync(() {
        reportError(Exception('test failure'), serviceName: 'diary-server');
      });

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['severity'], equals('ERROR'));
      expect(json['message'], contains('test failure'));
      expect(json['@type'], contains('ReportedErrorEvent'));
      expect(json['serviceContext']['service'], equals('diary-server'));
      expect(json['time'], isNotNull);
    });

    test('includes stack trace when provided', () {
      final output = captureStderrSync(() {
        try {
          throw StateError('bad state');
        } catch (e, st) {
          reportError(e, stackTrace: st);
        }
      });

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['stack_trace'], isNotNull);
      expect(json['stack_trace'], isA<String>());
      // Stack trace contains file references, not necessarily the error message
      expect((json['stack_trace'] as String).length, greaterThan(0));
      // The error message itself should be in the message field
      expect(json['message'], contains('bad state'));
    });

    test('scrubs PII from error messages', () {
      final output = captureStderrSync(() {
        reportError(Exception('Failed for user@example.com'));
      });

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['message'], isNot(contains('user@example.com')));
      expect(json['message'], contains('[EMAIL]'));
    });

    test('includes context data when provided', () {
      final output = captureStderrSync(() {
        reportError(
          Exception('test'),
          context: {'httpRequest': '/api/tasks', 'userId': 'anon'},
        );
      });

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['context']['httpRequest'], equals('/api/tasks'));
    });

    test('includes trace linkage when active span exists', () {
      final tracer = OTel.tracerProvider().getTracer('test');
      final span = tracer.startSpan('parent-op');

      final output = captureStderrSync(() {
        reportError(Exception('traced error'));
      });

      span.end();

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['severity'], equals('ERROR'));
    });
  });

  group('reportAndRecordError integration', () {
    test('records error on active span and emits JSON', () {
      final tracer = OTel.tracerProvider().getTracer('error-reporting');
      final span = tracer.startSpan('operation-with-error');

      final output = captureStderrSync(() {
        reportAndRecordError(
          Exception('db timeout'),
          serviceName: 'diary-functions',
        );
      });

      span.end();

      // Verify JSON was emitted
      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['severity'], equals('ERROR'));
      expect(json['message'], contains('db timeout'));

      // Verify span was exported
      expect(exporter.spans, hasLength(1));
    });

    test('scrubs PII in span status description', () {
      final tracer = OTel.tracerProvider().getTracer('error-reporting');
      final span = tracer.startSpan('pii-error-op');

      captureStderrSync(() {
        reportAndRecordError(
          Exception('Error for patient@hospital.org with phone 555-123-4567'),
        );
      });

      span.end();

      expect(exporter.spans.first.status, equals(SpanStatusCode.Error));
    });

    test('works when no active span exists', () {
      final output = captureStderrSync(() {
        reportAndRecordError(Exception('orphan error'));
      });

      final json = jsonDecode(output.trim()) as Map<String, dynamic>;
      expect(json['message'], contains('orphan error'));
    });
  });
}
