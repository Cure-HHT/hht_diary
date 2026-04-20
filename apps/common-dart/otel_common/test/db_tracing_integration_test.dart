// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047G: Database query tracing
//   REQ-o00045Q: PII/PHI scrubbing in trace data

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

  group('tracedQuery integration', () {
    test('creates a span for a successful query', () async {
      final result = await tracedQuery<int>(
        'SELECT',
        'SELECT * FROM users WHERE id = @id',
        () async => 42,
      );

      expect(result, equals(42));
      expect(exporter.spans, hasLength(1));
      expect(exporter.spans.first.name, equals('db.SELECT'));
    });

    test('uses table name in span name when provided', () async {
      await tracedQuery<List<String>>(
        'SELECT',
        'SELECT * FROM users',
        () async => ['alice', 'bob'],
        table: 'users',
      );

      expect(exporter.spans.first.name, equals('SELECT users'));
    });

    test('sets DB semantic convention attributes', () async {
      await tracedQuery<void>(
        'INSERT',
        'INSERT INTO tasks (title) VALUES (@title)',
        () async {},
        table: 'tasks',
      );

      final span = exporter.spans.first;
      expect(span.attributes.getString('db.system'), equals('postgresql'));
      expect(span.attributes.getString('db.operation'), equals('INSERT'));
      expect(span.attributes.getString('db.sql.table'), equals('tasks'));
    });

    test('sanitizes SQL in span attributes to prevent PII leakage', () async {
      await tracedQuery<void>(
        'SELECT',
        "SELECT * FROM users WHERE email = 'john@test.com' AND age > 25",
        () async {},
      );

      final statement = exporter.spans.first.attributes.getString(
        'db.statement',
      );
      expect(statement, isNotNull);
      // Literal values should be sanitized
      expect(statement, isNot(contains('john@test.com')));
      expect(statement, isNot(contains('25')));
      expect(statement, contains("'?'"));
      expect(statement, contains('?'));
    });

    test('preserves named parameters in sanitized SQL', () async {
      await tracedQuery<void>(
        'SELECT',
        'SELECT * FROM users WHERE id = @userId AND site = @siteId',
        () async {},
      );

      final statement = exporter.spans.first.attributes.getString(
        'db.statement',
      );
      expect(statement, contains('@userId'));
      expect(statement, contains('@siteId'));
    });

    test('sets span kind as client', () async {
      await tracedQuery<void>('SELECT', 'SELECT 1', () async {});

      expect(exporter.spans.first.kind, equals(SpanKind.client));
    });

    test('sets OK status on successful query', () async {
      await tracedQuery<void>('SELECT', 'SELECT 1', () async {});

      expect(exporter.spans.first.status, equals(SpanStatusCode.Ok));
    });

    test('records exception and sets Error status on failure', () async {
      await expectLater(
        () => tracedQuery<void>(
          'INSERT',
          'INSERT INTO users (email) VALUES (@email)',
          () async => throw Exception('unique constraint violation'),
        ),
        throwsA(isA<Exception>()),
      );

      expect(exporter.spans, hasLength(1));
      final span = exporter.spans.first;
      expect(span.status, equals(SpanStatusCode.Error));
      expect(span.statusDescription, contains('unique constraint violation'));
    });

    test('rethrows the original exception', () async {
      final original = StateError('connection closed');

      try {
        await tracedQuery<void>(
          'SELECT',
          'SELECT 1',
          () async => throw original,
        );
        fail('Should have thrown');
      } catch (e) {
        expect(identical(e, original), isTrue);
      }
    });

    test('returns the exact value from the execute callback', () async {
      final expected = {'id': 1, 'name': 'Alice'};

      final result = await tracedQuery<Map<String, dynamic>>(
        'SELECT',
        'SELECT * FROM users WHERE id = @id',
        () async => expected,
      );

      expect(identical(result, expected), isTrue);
    });

    test('uses custom tracer name when provided', () async {
      await tracedQuery<void>(
        'SELECT',
        'SELECT 1',
        () async {},
        tracerName: 'custom.db',
      );

      // Span should still be created
      expect(exporter.spans, hasLength(1));
    });
  });
}
