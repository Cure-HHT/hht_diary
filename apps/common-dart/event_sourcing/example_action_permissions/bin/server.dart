// bin/server.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00167 (Bootstrap) — process entry composes everything.

import 'dart:io';

import 'package:action_permissions_demo/server/bootstrap.dart';
import 'package:action_permissions_demo/server/demo_routes.dart';
import 'package:action_permissions_demo/server/demo_state_projection.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', defaultsTo: '8080', help: 'TCP port to bind on')
    ..addFlag(
      'ephemeral',
      defaultsTo: false,
      help: 'Run with an in-memory database (state lost on shutdown)',
    )
    ..addOption(
      'data-dir',
      help:
          'Directory for the persistent DB; defaults to '
          '\$XDG_DATA_HOME/action_permissions_demo (or ~/.local/share/...)',
    )
    ..addOption(
      'permissions-yaml',
      defaultsTo: 'tool/permissions.yaml',
      help: 'Path to the permissions seed YAML',
    )
    ..addOption(
      'users-yaml',
      defaultsTo: 'tool/users.yaml',
      help: 'Path to the user-directory seed YAML',
    )
    ..addOption(
      'install-id',
      help:
          'Stable per-install identifier (UUIDv4). When omitted, a fresh '
          'one is generated on each boot — appropriate for ephemeral runs '
          'only.',
    );

  final ArgResults parsed;
  try {
    parsed = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('error: ${e.message}\n\n${parser.usage}');
    exitCode = 64; // EX_USAGE
    return;
  }

  final port = int.parse(parsed['port'] as String);
  final ephemeral = parsed['ephemeral'] as bool;
  final permissionsYamlPath = parsed['permissions-yaml'] as String;
  final usersYamlPath = parsed['users-yaml'] as String;

  final dataDir = ephemeral
      ? Directory.systemTemp.createTempSync('action_permissions_demo_')
      : _resolveDataDir(parsed['data-dir'] as String?);
  await Directory(dataDir.path).create(recursive: true);
  final dbPath = p.join(dataDir.path, 'demo.db');

  final permissionsYaml = await File(permissionsYamlPath).readAsString();
  final usersYaml = await File(usersYamlPath).readAsString();

  // For non-ephemeral runs the install identifier should persist across
  // boots so events from the same install share an originator identity.
  // For demo simplicity: read/write a one-line file in the data dir.
  final installId =
      (parsed['install-id'] as String?) ??
      await _resolveInstallId(dataDir, ephemeral: ephemeral);

  final components = await bootstrapDemoServer(
    dbPath: dbPath,
    ephemeral: ephemeral,
    permissionsYaml: permissionsYaml,
    usersYaml: usersYaml,
    installIdentifier: installId,
  );

  if (components.policyErrors.isNotEmpty) {
    stderr.writeln(
      'WARN: policy seed validation produced errors. Server will run with '
      'FailSafeAuthorizationPolicy (every dispatch denied):',
    );
    for (final err in components.policyErrors) {
      stderr.writeln('  - $err');
    }
  }

  final routes = DemoRoutes(
    components: components,
    projection: PollingDemoStateProjection(
      components: components,
      lastTraceProvider: () => null,
    ),
  );

  final server = await shelf_io.serve(routes.handler, 'localhost', port);
  stdout.writeln(
    'demo server listening on http://${server.address.host}:${server.port}',
  );
  stdout.writeln('  data dir: ${dataDir.path}');
  stdout.writeln('  install id: $installId');
  stdout.writeln('  ephemeral: $ephemeral');
}

Directory _resolveDataDir(String? overridePath) {
  if (overridePath != null) return Directory(overridePath);
  // XDG Base Directory: $XDG_DATA_HOME or ~/.local/share.
  final xdg = Platform.environment['XDG_DATA_HOME'];
  final base = (xdg != null && xdg.isNotEmpty)
      ? xdg
      : p.join(
          Platform.environment['HOME'] ?? Directory.current.path,
          '.local',
          'share',
        );
  return Directory(p.join(base, 'action_permissions_demo'));
}

Future<String> _resolveInstallId(
  Directory dataDir, {
  required bool ephemeral,
}) async {
  if (ephemeral) {
    // No persistence: generate per boot. Documented in --install-id help.
    return _newInstallId();
  }
  final file = File(p.join(dataDir.path, 'install_id'));
  if (await file.exists()) {
    final existing = (await file.readAsString()).trim();
    if (existing.isNotEmpty) return existing;
  }
  final fresh = _newInstallId();
  await file.writeAsString(fresh);
  return fresh;
}

String _newInstallId() {
  // Cheap UUIDv4-shaped string for the demo. For production, use
  // package:uuid. We avoid pulling that dep into bin/ to keep the entry
  // point small; the dispatcher uses it internally for invocation ids.
  final r = DateTime.now().microsecondsSinceEpoch
      .toRadixString(16)
      .padLeft(16, '0');
  return '00000000-0000-4000-8000-${r.substring(r.length - 12).padLeft(12, '0')}';
}
