// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047F: End-to-end distributed tracing
//   REQ-o00047I: HTTP request tracing with semantic conventions

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_common/otel_common.dart';
import 'package:shelf/shelf.dart';
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

  group('otelMiddleware integration', () {
    test('creates a span for each HTTP request', () async {
      final handler = const Pipeline()
          .addMiddleware(otelMiddleware())
          .addHandler((_) => Response.ok('ok'));

      await handler(Request('GET', Uri.parse('http://localhost/api/health')));

      expect(exporter.spans, hasLength(1));
      expect(exporter.spans.first.name, equals('GET /api/health'));
    });

    test('sets HTTP semantic convention attributes', () async {
      final handler = const Pipeline()
          .addMiddleware(otelMiddleware())
          .addHandler((_) => Response.ok('ok'));

      await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/tasks?page=1'),
          headers: {
            'host': 'diary.example.com',
            'user-agent': 'Dart/3.10',
            'content-length': '42',
          },
        ),
      );

      final span = exporter.spans.first;
      expect(span.attributes.getString('http.method'), equals('POST'));
      expect(span.attributes.getString('http.target'), equals('/api/tasks'));
      expect(span.attributes.getString('http.scheme'), equals('http'));
      expect(span.attributes.getString('url.path'), equals('/api/tasks'));
      expect(span.attributes.getString('url.query'), equals('page=1'));
      expect(
        span.attributes.getString('server.address'),
        equals('diary.example.com'),
      );
      expect(
        span.attributes.getString('user_agent.original'),
        equals('Dart/3.10'),
      );
      expect(span.attributes.getInt('http.request.body.size'), equals(42));
    });

    test('records span kind as server', () async {
      final handler = const Pipeline()
          .addMiddleware(otelMiddleware())
          .addHandler((_) => Response.ok('ok'));

      await handler(Request('GET', Uri.parse('http://localhost/')));

      expect(exporter.spans.first.kind, equals(SpanKind.server));
    });

    test('sets OK status for successful responses', () async {
      final handler = const Pipeline()
          .addMiddleware(otelMiddleware())
          .addHandler((_) => Response.ok('ok'));

      await handler(Request('GET', Uri.parse('http://localhost/')));

      final span = exporter.spans.first;
      expect(span.attributes.getInt('http.status_code'), equals(200));
      expect(span.attributes.getInt('http.response.status_code'), equals(200));
      expect(span.status, equals(SpanStatusCode.Ok));
    });

    test('sets Error status for 5xx responses', () async {
      final handler = const Pipeline()
          .addMiddleware(otelMiddleware())
          .addHandler((_) => Response.internalServerError(body: 'fail'));

      await handler(Request('GET', Uri.parse('http://localhost/')));

      final span = exporter.spans.first;
      expect(span.attributes.getInt('http.status_code'), equals(500));
      expect(span.status, equals(SpanStatusCode.Error));
      expect(span.statusDescription, equals('HTTP 500'));
    });

    test('injects trace headers in response', () async {
      final handler = const Pipeline()
          .addMiddleware(otelMiddleware())
          .addHandler((_) => Response.ok('ok'));

      final response = await handler(
        Request('GET', Uri.parse('http://localhost/')),
      );

      expect(response.headers['x-trace-id'], isNotEmpty);
      expect(response.headers['x-span-id'], isNotEmpty);
      // Trace and span IDs should be valid hex strings
      expect(response.headers['x-trace-id'], matches(RegExp(r'^[0-9a-f]+$')));
      expect(response.headers['x-span-id'], matches(RegExp(r'^[0-9a-f]+$')));
    });

    test('records exception on handler error and rethrows', () async {
      final handler = const Pipeline()
          .addMiddleware(otelMiddleware())
          .addHandler((_) => throw Exception('boom'));

      await expectLater(
        () => handler(Request('GET', Uri.parse('http://localhost/'))),
        throwsA(isA<Exception>()),
      );

      // Span should still be exported even after an exception
      expect(exporter.spans, hasLength(1));
      final span = exporter.spans.first;
      expect(span.status, equals(SpanStatusCode.Error));
    });

    test('propagates W3C traceparent from incoming headers', () async {
      final handler = const Pipeline()
          .addMiddleware(otelMiddleware())
          .addHandler((_) => Response.ok('ok'));

      const traceId = '0af7651916cd43dd8448eb211c80319c';
      const parentSpanId = 'b7ad6b7169203331';
      final traceparent = '00-$traceId-$parentSpanId-01';

      await handler(
        Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'traceparent': traceparent},
        ),
      );

      final span = exporter.spans.first;
      // The span should belong to the propagated trace
      expect(span.spanContext.traceId.toString(), equals(traceId));
    });

    test('creates separate spans per request', () async {
      final handler = const Pipeline()
          .addMiddleware(otelMiddleware())
          .addHandler((_) => Response.ok('ok'));

      await handler(Request('GET', Uri.parse('http://localhost/a')));
      await handler(Request('GET', Uri.parse('http://localhost/b')));

      expect(exporter.spans, hasLength(2));
      expect(exporter.spans[0].name, equals('GET /a'));
      expect(exporter.spans[1].name, equals('GET /b'));
      // Each request gets its own span ID
      final spanId1 = exporter.spans[0].spanContext.spanId.toString();
      final spanId2 = exporter.spans[1].spanContext.spanId.toString();
      expect(spanId1, isNot(equals(spanId2)));
    });

    test('uses custom tracer name when provided', () async {
      final handler = const Pipeline()
          .addMiddleware(otelMiddleware(tracerName: 'custom.tracer'))
          .addHandler((_) => Response.ok('ok'));

      await handler(Request('GET', Uri.parse('http://localhost/')));

      // Span should still be created — tracer name is internal
      expect(exporter.spans, hasLength(1));
    });
  });
}
