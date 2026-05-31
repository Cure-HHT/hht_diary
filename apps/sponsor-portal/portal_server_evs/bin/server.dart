// Implements: DIARY-DEV-portal-reaction-server/A
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> args) async {
  final port = int.parse(Platform.environment['PORT'] ?? '8084');
  final db =
      await newDatabaseFactoryMemory().openDatabase('portal-skeleton.db');
  final boot =
      await bootstrapPortalServer(backend: SembastBackend(database: db));

  final server = await shelf_io.serve(
    boot.router.call,
    InternetAddress.anyIPv4,
    port,
  );
  stdout.writeln(
      'portal_server_evs listening on http://localhost:${server.port}');
  stdout.writeln(
      '  seeded: admin-1 (Administrator), sc-1 (StudyCoordinator @ site-1)');

  Future<void> shutdown() async {
    await server.close(force: true);
    await boot.dispose();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => shutdown());
  ProcessSignal.sigterm.watch().listen((_) => shutdown());
}
