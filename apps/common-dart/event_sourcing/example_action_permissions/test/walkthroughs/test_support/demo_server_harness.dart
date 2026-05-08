// test/walkthroughs/test_support/demo_server_harness.dart
//
// Spawns bin/server.dart as a subprocess on a fresh ephemeral port,
// waits for /healthz, and exposes typed wire-shape helpers. Used by the
// walkthrough_*_test.dart walkthrough tests.
//
// The walkthroughs live under test/ (not integration_test/) so plain
// `flutter test` runs them as standalone Dart VM tests — i.e. without
// activating the Flutter desktop binding. That keeps Platform.executable
// pointing at the bundled `dart` VM, which is what we need to spawn
// `dart run bin/server.dart` as a subprocess. See _resolveDartExecutable
// below for the defensive fallback.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class DemoServerHarness {
  DemoServerHarness._({
    required this.port,
    required this.process,
    required this.client,
    required this.workingDirectory,
  });

  final int port;
  final Process process;
  final http.Client client;
  final String workingDirectory;

  String get baseUrl => 'http://localhost:$port';

  /// Start a fresh demo server on a free localhost port.
  ///
  /// [packageRoot] is the path to the example_action_permissions package
  /// (where bin/server.dart and tool/*.yaml live). When omitted, the
  /// harness walks up from the current directory looking for a pubspec
  /// containing `name: action_permissions_demo`.
  static Future<DemoServerHarness> start({
    String? packageRoot,
    Duration healthTimeout = const Duration(seconds: 60),
  }) async {
    final root = packageRoot ?? _findPackageRoot();
    final port = await _pickFreePort();

    final dartExe = _resolveDartExecutable();
    final process = await Process.start(
      dartExe,
      <String>[
        'run',
        'bin/server.dart',
        '--ephemeral',
        '--port=$port',
        '--permissions-yaml=${p.join('tool', 'permissions.yaml')}',
        '--users-yaml=${p.join('tool', 'users.yaml')}',
      ],
      workingDirectory: root,
      mode: ProcessStartMode.normal,
    );

    // Pipe child stdout/stderr to the test runner so failures are
    // diagnosable. Drain in the background; do not await.
    unawaited(process.stdout.transform(utf8.decoder).forEach(stdout.write));
    unawaited(process.stderr.transform(utf8.decoder).forEach(stderr.write));

    final client = http.Client();
    final harness = DemoServerHarness._(
      port: port,
      process: process,
      client: client,
      workingDirectory: root,
    );
    try {
      await harness._waitForHealth(healthTimeout);
    } on Object {
      // If the server failed to come up, kill the process and surface.
      process.kill();
      client.close();
      rethrow;
    }
    return harness;
  }

  Future<void> _waitForHealth(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final r = await client
            .get(Uri.parse('$baseUrl/healthz'))
            .timeout(const Duration(seconds: 2));
        if (r.statusCode == 200) return;
        lastError = StateError('healthz returned ${r.statusCode}');
      } on Object catch (e) {
        // Connection refused while server is still starting.
        lastError = e;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw StateError(
      'demo server failed to come up within ${timeout.inSeconds}s '
      '(last error: $lastError)',
    );
  }

  Future<SessionStartResponse> sessionStart({String? userId}) async {
    final body = jsonEncode(SessionStartRequest(userId: userId).toJson());
    final r = await client.post(
      Uri.parse('$baseUrl/session/start'),
      body: body,
      headers: const <String, String>{'content-type': 'application/json'},
    );
    if (r.statusCode != 200) {
      throw StateError('session/start ${r.statusCode}: ${r.body}');
    }
    return SessionStartResponse.fromJson(
      jsonDecode(r.body) as Map<String, Object?>,
    );
  }

  Future<DispatchResponse> dispatch({
    required String actionName,
    required Map<String, Object?> rawInput,
    String? idempotencyKey,
    String? userId,
  }) async {
    final body = jsonEncode(
      DispatchRequest(
        actionName: actionName,
        rawInput: rawInput,
        idempotencyKey: idempotencyKey,
        userId: userId,
      ).toJson(),
    );
    final r = await client.post(
      Uri.parse('$baseUrl/dispatch'),
      body: body,
      headers: const <String, String>{'content-type': 'application/json'},
    );
    if (r.statusCode != 200) {
      throw StateError('dispatch ${r.statusCode}: ${r.body}');
    }
    return DispatchResponse.fromJson(
      jsonDecode(r.body) as Map<String, Object?>,
    );
  }

  Future<InspectSnapshot> inspect() async {
    final r = await client.get(Uri.parse('$baseUrl/_demo/inspect'));
    if (r.statusCode != 200) {
      throw StateError('inspect ${r.statusCode}: ${r.body}');
    }
    return InspectSnapshot.fromJson(jsonDecode(r.body) as Map<String, Object?>);
  }

  /// Send raw JSON to /dispatch (for malformed-request walkthroughs that
  /// can't go through the typed helper).
  Future<http.Response> rawDispatch(String rawJson) {
    return client.post(
      Uri.parse('$baseUrl/dispatch'),
      body: rawJson,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }

  /// Stop the server and release resources. Idempotent — safe to call
  /// from teardown even if start() failed mid-way.
  Future<void> stop() async {
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
    client.close();
  }

  // --- internals ---

  static Future<int> _pickFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  static String _findPackageRoot() {
    Directory dir = Directory.current;
    for (var i = 0; i < 8; i++) {
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        final text = pubspec.readAsStringSync();
        if (text.contains('name: action_permissions_demo')) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    throw StateError(
      'DemoServerHarness: cannot find action_permissions_demo package '
      'root (looked at ${Directory.current.path} and 7 parents). Pass '
      'packageRoot: explicitly to start().',
    );
  }

  static String _resolveDartExecutable() {
    // Under `flutter test`, Platform.executable is the dart VM bundled
    // with the Flutter SDK — that works directly. Under `flutter test
    // integration_test/...` it would be the Flutter desktop runner, which
    // does NOT accept `dart run` args; in that case we fall back to `dart`
    // on PATH (assumes `flutter` SDK's dart-sdk/bin is in PATH).
    final exe = Platform.executable;
    final lower = exe.toLowerCase();
    if (lower.endsWith('dart') || lower.endsWith('dart.exe')) {
      return exe;
    }
    return 'dart';
  }
}
