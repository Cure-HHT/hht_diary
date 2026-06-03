// Implements: DIARY-DEV-portal-reaction-server/A
import 'dart:io';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> args) async {
  final env = Platform.environment;
  final port = int.parse(env['PORT'] ?? '8084');

  // Implements: DIARY-DEV-portal-durable-event-store/A — durable Postgres store
  //   (+ matching idempotency store) when DB config is present; in-memory
  //   otherwise (tests/local), selected by environment without a code change.
  final StorageBackend backend;
  final IdempotencyStore idempotency;
  final dbHost = env['DB_HOST'];
  if (dbHost != null && dbHost.isNotEmpty) {
    final user = Uri.encodeComponent(env['DB_USER'] ?? 'app_user');
    final pass = Uri.encodeComponent(env['DB_PASSWORD'] ?? '');
    final dbPort = env['DB_PORT'] ?? '5432';
    final dbName = env['DB_NAME'] ?? 'hht_diary';
    final url = 'postgres://$user:$pass@$dbHost:$dbPort/$dbName';
    final sslMode =
        env['DB_SSL'] == 'false' ? SslMode.disable : SslMode.require;
    final pg = await PostgresBackend.open(url: url, sslMode: sslMode);
    backend = pg;
    idempotency = PostgresIdempotencyStore.over(pg.pool);
    stdout.writeln(
        'portal_server_evs: durable Postgres backend ($dbHost:$dbPort/$dbName, ssl=${sslMode.name})');
  } else {
    final db =
        await newDatabaseFactoryMemory().openDatabase('portal-skeleton.db');
    backend = SembastBackend(database: db);
    idempotency = InMemoryIdempotencyStore();
    stdout.writeln('portal_server_evs: in-memory backend (no DB_HOST)');
  }

  final boot = await bootstrapPortalServer(
    backend: backend,
    idempotency: idempotency,
  );

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
