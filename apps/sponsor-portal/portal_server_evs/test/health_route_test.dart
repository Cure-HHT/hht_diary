// Verifies: portal exposes /health for the container readiness gate.
import 'dart:convert';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('GET /health returns ok JSON without auth', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('h.db');
    final boot = await bootstrapPortalServer(
        backend: SembastBackend(database: db), raveClient: DevSeedRaveClient());
    addTearDown(boot.dispose);

    final res = await boot.router
        .call(Request('GET', Uri.parse('http://localhost/health')));
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, Object?>;
    expect(body['status'], 'ok');
    expect(body['service'], 'portal_server_evs');
  });
}
