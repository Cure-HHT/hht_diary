// Verifies: DIARY-DEV-participant-ingest/A+B — public ingest edge; auth gate before ingest.
import 'dart:typed_data';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/patient_ingest_handler.dart';
import 'package:portal_server_evs/src/patient_token_validator.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Future<EventStore> _openStore() async {
  final db = await newDatabaseFactoryMemory().openDatabase('ingest-h.db');
  return openPortalEventStore(backend: SembastBackend(database: db));
}

Request _post({String? auth, required List<int> body}) => Request(
      'POST',
      Uri.parse('http://localhost/ingest'),
      headers: {if (auth != null) 'authorization': auth},
      body: Uint8List.fromList(body),
    );

void main() {
  test('missing auth -> 401', () async {
    final handler = patientIngestHandler(eventStore: await _openStore());
    final res = await handler(_post(body: const [1, 2, 3]));
    expect(res.statusCode, 401);
  });

  test('invalid token -> 401', () async {
    final handler = patientIngestHandler(eventStore: await _openStore());
    final res =
        await handler(_post(auth: 'Bearer not-a-jwt', body: const [1, 2, 3]));
    expect(res.statusCode, 401);
  });

  test('valid token but malformed batch bytes -> 400', () async {
    final token = createPatientJwt(authCode: 'ac', userId: 'u');
    final handler = patientIngestHandler(eventStore: await _openStore());
    final res =
        await handler(_post(auth: 'Bearer $token', body: const [0, 1, 2, 3]));
    expect(res.statusCode, 400);
  });
}
