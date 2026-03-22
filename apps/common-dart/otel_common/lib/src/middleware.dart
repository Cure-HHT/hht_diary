// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047F: End-to-end distributed tracing
//   REQ-o00047I: HTTP request tracing with semantic conventions

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:shelf/shelf.dart';

/// Shelf middleware that creates a span per HTTP request.
///
/// Propagates W3C TraceContext from incoming headers, sets HTTP semantic
/// convention attributes, and records exceptions.
Middleware otelMiddleware({String tracerName = 'http.server'}) {
  return (Handler innerHandler) {
    return (Request request) async {
      final tracer = OTel.tracerProvider().getTracer(tracerName);

      // Extract parent context from incoming W3C traceparent header.
      final parentContext = _extractContext(request);

      final span = tracer.startSpan(
        '${request.method} ${request.requestedUri.path}',
        kind: SpanKind.server,
        context: parentContext,
      );

      // Set HTTP semantic convention attributes.
      span.setStringAttribute('http.method', request.method);
      span.setStringAttribute('http.target', request.requestedUri.path);
      span.setStringAttribute('http.scheme', request.requestedUri.scheme);
      span.setStringAttribute('url.path', request.requestedUri.path);
      if (request.requestedUri.hasQuery) {
        span.setStringAttribute('url.query', request.requestedUri.query);
      }
      final host = request.headers['host'];
      if (host != null) {
        span.setStringAttribute('server.address', host);
      }
      final userAgent = request.headers['user-agent'];
      if (userAgent != null) {
        span.setStringAttribute('user_agent.original', userAgent);
      }
      final contentLength = request.headers['content-length'];
      if (contentLength != null) {
        span.setIntAttribute(
          'http.request.body.size',
          int.tryParse(contentLength) ?? 0,
        );
      }

      try {
        final response = await innerHandler(request);

        span.setIntAttribute('http.status_code', response.statusCode);
        span.setIntAttribute('http.response.status_code', response.statusCode);

        if (response.statusCode >= 500) {
          span.setStatus(SpanStatusCode.Error, 'HTTP ${response.statusCode}');
        } else {
          span.setStatus(SpanStatusCode.Ok);
        }

        // Inject trace context into response headers for downstream correlation.
        final traceId = span.spanContext.traceId.toString();
        final spanId = span.spanContext.spanId.toString();

        return response.change(
          headers: {'x-trace-id': traceId, 'x-span-id': spanId},
        );
      } catch (e, st) {
        span.recordException(e, stackTrace: st);
        span.setStatus(SpanStatusCode.Error, e.toString());
        rethrow;
      } finally {
        span.end();
      }
    };
  };
}

/// Extract W3C TraceContext from request headers.
Context? _extractContext(Request request) {
  final traceparent = request.headers['traceparent'];
  if (traceparent == null) return null;

  final carrier = <String, String>{'traceparent': traceparent};
  final tracestate = request.headers['tracestate'];
  if (tracestate != null) {
    carrier['tracestate'] = tracestate;
  }

  final propagator = W3CTraceContextPropagator();
  final getter = _MapGetter(carrier);
  return propagator.extract(OTel.context(), carrier, getter);
}

/// Getter that reads from a carrier map by key.
class _MapGetter implements TextMapGetter<String> {
  final Map<String, String> _map;
  _MapGetter(this._map);

  @override
  String? get(String key) => _map[key];

  @override
  Iterable<String> keys() => _map.keys;
}
