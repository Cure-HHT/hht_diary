// Verifies: DIARY-DEV-participant-ingest/A+B+E — public ingest edge; auth gate
//   before ingest; participant-ownership rejection of foreign-prefixed aggregates.
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
      Uri.parse('http://localhost/api/v1/ingest/batch'),
      headers: {if (auth != null) 'authorization': auth},
      body: Uint8List.fromList(body),
    );

/// A minimal valid `esd/batch@1` envelope carrying a single event whose only
/// meaningful field is [aggregateId]. The ownership loop reads only
/// `aggregate_id`, so the rest of the event map can stay empty.
Uint8List _batchWith(String aggregateId) => BatchEnvelope(
      batchFormatVersion: '1',
      batchId: 'b1',
      senderHop: 'mobile',
      senderIdentifier: 'DEV-1',
      senderSoftwareVersion: 'test@0',
      sentAt: DateTime.utc(2026, 6, 1),
      events: [
        <String, Object?>{'aggregate_id': aggregateId}
      ],
    ).encode();

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

  test('batch with a foreign {pid}: aggregate -> 403', () async {
    final token = createPatientJwt(authCode: 'ac', userId: 'P-SELF');
    final handler = patientIngestHandler(eventStore: await _openStore());
    final res = await handler(_post(
      auth: 'Bearer $token',
      body: _batchWith('P-OTHER:2025-10-15'),
    ));
    expect(res.statusCode, 403);
  });

  test('owned {pid}: aggregate passes the ownership gate (not 403)', () async {
    final token = createPatientJwt(authCode: 'ac', userId: 'P-SELF');
    final handler = patientIngestHandler(eventStore: await _openStore());
    final res = await handler(_post(
      auth: 'Bearer $token',
      body: _batchWith('P-SELF:2025-10-15'),
    ));
    // The minimal event is not hash-valid, so ingestBatch rejects it with a
    // 4xx/422 — but the ownership gate let an OWNED aggregate through (not 403).
    expect(res.statusCode, isNot(403));
  });

  test('non-prefixed aggregate passes the ownership gate (not 403)', () async {
    final token = createPatientJwt(authCode: 'ac', userId: 'P-SELF');
    final handler = patientIngestHandler(eventStore: await _openStore());
    final res = await handler(_post(
      auth: 'Bearer $token',
      body: _batchWith('some-uuid-no-colon'),
    ));
    // isNot(403) proves the ownership gate allowed it through (downstream
    // ingest may still 4xx the minimal, non-hash-valid event).
    expect(res.statusCode, isNot(403));
  });

  test('leading-colon aggregate is treated as non-prefixed (not 403)',
      () async {
    final token = createPatientJwt(authCode: 'ac', userId: 'P-SELF');
    final handler = patientIngestHandler(eventStore: await _openStore());
    final res = await handler(_post(
      auth: 'Bearer $token',
      body: _batchWith(':uuid'),
    ));
    // A leading colon yields an empty prefix (no participant id), so it must be
    // treated as non-prefixed and pass the gate — isNot(403) proves it did.
    expect(res.statusCode, isNot(403));
  });
}
