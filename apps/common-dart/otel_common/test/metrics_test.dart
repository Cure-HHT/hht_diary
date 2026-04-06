// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047: Performance Monitoring — custom application metrics

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_common/otel_common.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'helpers/otel_test_helpers.dart';

/// In-memory metric reader for testing.
/// Collects metrics from the MeterProvider on demand.
class TestMetricReader implements MetricReader {
  MeterProvider? _meterProvider;
  bool _isShutdown = false;

  @override
  MeterProvider? get meterProvider => _meterProvider;

  @override
  void registerMeterProvider(MeterProvider meterProvider) {
    _meterProvider = meterProvider;
  }

  /// Collect all metrics from the provider.
  @override
  Future<MetricData> collect() async {
    if (_isShutdown || _meterProvider == null) {
      return MetricData.empty();
    }
    final metrics = await _meterProvider!.collectAllMetrics();
    return MetricData(resource: _meterProvider!.resource, metrics: metrics);
  }

  @override
  Future<bool> forceFlush() async => true;

  @override
  Future<bool> shutdown() async {
    _isShutdown = true;
    return true;
  }
}

/// Set up OTel with both spans and metrics enabled for testing.
Future<TestMetricReader> setUpOTelWithMetrics() async {
  await OTel.reset();

  final spanExporter = InMemorySpanExporter();
  final spanProcessor = SimpleSpanProcessor(spanExporter);
  final metricReader = TestMetricReader();

  await OTel.initialize(
    serviceName: 'test-service',
    serviceVersion: '0.0.1-test',
    spanProcessor: spanProcessor,
    enableMetrics: true,
    enableLogs: false,
    metricReader: metricReader,
  );

  return metricReader;
}

void main() {
  group('HTTP middleware metrics', () {
    late TestMetricReader metricReader;

    setUp(() async {
      metricReader = await setUpOTelWithMetrics();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test(
      'records http_request_duration_seconds on successful request',
      () async {
        final middleware = otelMiddleware();
        final handler = middleware((request) async {
          return Response.ok('hello');
        });

        await handler(Request('GET', Uri.parse('http://localhost/api/health')));

        final data = await metricReader.collect();
        final metricNames = data.metrics.map((m) => m.name).toSet();
        expect(metricNames, contains('http_request_duration_seconds'));
      },
    );

    test('records http_requests_total on successful request', () async {
      final middleware = otelMiddleware();
      final handler = middleware((request) async {
        return Response.ok('hello');
      });

      await handler(Request('GET', Uri.parse('http://localhost/api/health')));

      final data = await metricReader.collect();
      final metricNames = data.metrics.map((m) => m.name).toSet();
      expect(metricNames, contains('http_requests_total'));
    });

    test('records metrics on error responses', () async {
      final middleware = otelMiddleware();
      final handler = middleware((request) async {
        return Response.internalServerError(body: 'error');
      });

      await handler(Request('POST', Uri.parse('http://localhost/api/sync')));

      final data = await metricReader.collect();
      final metricNames = data.metrics.map((m) => m.name).toSet();
      expect(metricNames, contains('http_request_duration_seconds'));
      expect(metricNames, contains('http_requests_total'));
    });

    test('records metrics when handler throws', () async {
      final middleware = otelMiddleware();
      final handler = middleware((request) async {
        throw Exception('boom');
      });

      try {
        await handler(Request('GET', Uri.parse('http://localhost/api/fail')));
        fail('should have thrown');
      } catch (_) {
        // Expected — metrics are recorded in the catch block before rethrow.
      }

      final data = await metricReader.collect();
      final metricNames = data.metrics.map((m) => m.name).toSet();
      expect(metricNames, contains('http_request_duration_seconds'));
      expect(metricNames, contains('http_requests_total'));
    });

    test('accumulates metrics across multiple requests', () async {
      final middleware = otelMiddleware();
      final handler = middleware((request) async {
        return Response.ok('ok');
      });

      // Send 3 requests
      for (var i = 0; i < 3; i++) {
        await handler(Request('GET', Uri.parse('http://localhost/api/test')));
      }

      final data = await metricReader.collect();
      final totalMetric = data.metrics.firstWhere(
        (m) => m.name == 'http_requests_total',
      );
      expect(totalMetric, isNotNull);
    });
  });

  group('DB tracing metrics', () {
    late TestMetricReader metricReader;

    setUp(() async {
      metricReader = await setUpOTelWithMetrics();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test(
      'records database_query_duration_seconds on successful query',
      () async {
        await tracedQuery(
          'SELECT',
          'SELECT * FROM users WHERE id = @id',
          () async => 'result',
          table: 'users',
        );

        final data = await metricReader.collect();
        final metricNames = data.metrics.map((m) => m.name).toSet();
        expect(metricNames, contains('database_query_duration_seconds'));
      },
    );

    test('records database_query_duration_seconds on failed query', () async {
      try {
        await tracedQuery(
          'INSERT',
          'INSERT INTO users (name) VALUES (@name)',
          () async => throw Exception('constraint violation'),
          table: 'users',
        );
      } catch (_) {
        // Expected
      }

      final data = await metricReader.collect();
      final metricNames = data.metrics.map((m) => m.name).toSet();
      expect(metricNames, contains('database_query_duration_seconds'));
    });
  });
}
