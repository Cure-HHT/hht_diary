// IMPLEMENTS REQUIREMENTS:
//   REQ-o00047: Performance Monitoring — OpenTelemetry integration (test infra)

import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// In-memory span exporter for integration tests.
///
/// Captures all exported spans in a list for assertions without
/// requiring an external OTel Collector.
class InMemorySpanExporter implements SpanExporter {
  final List<Span> _spans = [];
  bool _isShutdown = false;

  /// All exported spans (unmodifiable).
  List<Span> get spans => List.unmodifiable(_spans);

  /// Clear all captured spans.
  void clear() => _spans.clear();

  /// Find a span by exact name, or null if not found.
  Span? findSpanByName(String name) {
    for (final span in _spans) {
      if (span.name == name) return span;
    }
    return null;
  }

  /// Whether any captured span has the given name.
  bool hasSpanWithName(String name) => _spans.any((s) => s.name == name);

  /// All span names — useful for debugging test failures.
  List<String> get spanNames => _spans.map((s) => s.name).toList();

  @override
  Future<void> export(List<Span> spans) async {
    if (_isShutdown) return;
    _spans.addAll(spans);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
  }
}

/// Shared OTel test setup — initializes OTel with an in-memory exporter.
///
/// Returns the exporter so tests can inspect captured spans.
/// Call [tearDownOTel] in tearDown().
Future<InMemorySpanExporter> setUpOTel() async {
  await OTel.reset();

  final exporter = InMemorySpanExporter();
  final processor = SimpleSpanProcessor(exporter);

  await OTel.initialize(
    serviceName: 'test-service',
    serviceVersion: '0.0.1-test',
    spanProcessor: processor,
    enableMetrics: false,
  );

  return exporter;
}

/// Shared OTel test teardown — shuts down and resets global state.
Future<void> tearDownOTel() async {
  await OTel.shutdown();
  await OTel.reset();
}

/// Captures stderr output during a synchronous callback.
String captureStderrSync(void Function() fn) {
  final buffer = StringBuffer();
  IOOverrides.runZoned(
    fn,
    stderr: () => _BufferedStderr(buffer),
  );
  return buffer.toString();
}

/// Captures stderr output during an async callback.
Future<String> captureStderr(Future<void> Function() fn) async {
  final buffer = StringBuffer();
  await IOOverrides.runZoned(
    () async => await fn(),
    stderr: () => _BufferedStderr(buffer),
  );
  return buffer.toString();
}

/// A Stdout implementation that captures writes to a StringBuffer.
///
/// Uses [noSuchMethod] for members not needed by our tests, avoiding
/// breakage when the Dart SDK adds new Stdout members.
class _BufferedStderr implements Stdout {
  final StringBuffer _buffer;
  _BufferedStderr(this._buffer);

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeAll(Iterable objects, [String sep = '']) =>
      _buffer.writeAll(objects, sep);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  // Use noSuchMethod for all other Stdout members we don't need in tests.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
