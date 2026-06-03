// Verifies: DIARY-DEV-patient-ingest/A+B — /ingest is mounted public and gated.
import 'dart:typed_data';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('POST /ingest with no auth -> 401', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('ir.db');
    final boot = await bootstrapPortalServer(
        backend: SembastBackend(database: db), raveClient: DevSeedRaveClient());
    addTearDown(boot.dispose);

    final res = await boot.router.call(Request(
      'POST',
      Uri.parse('http://localhost/ingest'),
      body: Uint8List.fromList(const [1, 2, 3]),
    ));
    expect(res.statusCode, 401);
  });
}
