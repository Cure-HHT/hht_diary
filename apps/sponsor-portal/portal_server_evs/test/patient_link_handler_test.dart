// Verifies: DIARY-DEV-participant-link-issuance/A+B+C+D — /link validates the
//   code, mints a participant JWT, and atomically consumes the code (single-use).
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_server_evs/src/patient_link_handler.dart';
import 'package:portal_server_evs/src/patient_token_validator.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Future<EventStore> _openStore(String dbName) async {
  final db = await newDatabaseFactoryMemory().openDatabase(dbName);
  return openPortalEventStore(backend: SembastBackend(database: db));
}

Request _post({required Map<String, Object?> body}) => Request(
      'POST',
      Uri.parse('http://localhost/api/v1/user/link'),
      body: jsonEncode(body),
    );

/// Seed a participant + site + an active linking code with the post-A3 wire
/// contract. [expiresAt] defaults to one hour in the future.
Future<void> _seed(
  EventStore store, {
  String code = 'CAABCDE123',
  String participantId = 'P-1',
  String siteId = 'S-1',
  String? expiresAt,
}) async {
  final expires = expiresAt ??
      DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();

  await store.append(
    entryType: 'site_synced_from_edc',
    aggregateType: 'site',
    aggregateId: siteId,
    eventType: 'site_synced_from_edc',
    data: <String, Object?>{
      'site_id': siteId,
      'site_name': 'Test Site',
      'site_number': '001',
      'is_active': true,
    },
    initiator: const AutomationInitiator(service: 'edc_sync'),
  );

  await store.append(
    entryType: 'participant_synced_from_edc',
    aggregateType: 'participant',
    aggregateId: participantId,
    eventType: 'participant_synced_from_edc',
    data: <String, Object?>{
      'participant_id': participantId,
      'site_id': siteId,
    },
    initiator: const AutomationInitiator(service: 'edc_sync'),
  );

  await store.append(
    entryType: 'participant_linking_code_issued',
    aggregateType: 'participant',
    aggregateId: participantId,
    eventType: 'participant_linking_code_issued',
    data: <String, Object?>{
      'linking_code': code,
      'participant_id': participantId,
      'site_id': siteId,
      'generated_by': 'coordinator-1',
      'expires_at': expires,
      'purpose': 'link',
      'status': 'active',
      'mobile_linking_status': 'linking_in_progress',
    },
    initiator: const AutomationInitiator(service: 'test'),
  );
}

void main() {
  test('valid active code -> 200; mints a verifiable JWT and consumes the code',
      () async {
    final store = await _openStore('link-ok');
    await _seed(store);
    final handler = patientLinkHandler(eventStore: store);

    final res = await handler(_post(body: {'code': 'CAABCDE123'}));
    expect(res.statusCode, 200);

    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['success'], isTrue);
    expect(body['participantId'], 'P-1');
    expect(body['userId'], 'P-1');
    expect(body['linkingCode'], 'CAABCDE123');
    expect(body['siteId'], 'S-1');
    expect(body['siteName'], 'Test Site');
    expect(body['siteNumber'], '001');
    expect(body['studyParticipantId'], 'P-1');

    final jwt = body['jwt'] as String?;
    expect(jwt, isNotNull);
    final payload = verifyPatientAuthHeader('Bearer $jwt');
    expect(payload, isNotNull);
    expect(payload!.userId, 'P-1');

    // The code is now consumed (atomic single-use).
    final rows = await store.backend.findViewRows('linking_codes');
    final row = rows.firstWhere((r) => r['linking_code'] == 'CAABCDE123');
    expect(row['status'], 'used');
  });

  test('code is normalized (dash + lowercase) before lookup', () async {
    final store = await _openStore('link-norm');
    await _seed(store);
    final handler = patientLinkHandler(eventStore: store);

    final res = await handler(_post(body: {'code': 'caab-cde1-23'}));
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['linkingCode'], 'CAABCDE123');
  });

  test('unknown code -> 400', () async {
    final store = await _openStore('link-unknown');
    await _seed(store);
    final handler = patientLinkHandler(eventStore: store);

    final res = await handler(_post(body: {'code': 'ZZZNOPE999'}));
    expect(res.statusCode, 400);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['error'], isA<String>());
  });

  test('missing/blank code -> 400', () async {
    final store = await _openStore('link-blank');
    final handler = patientLinkHandler(eventStore: store);

    final res = await handler(_post(body: {'code': '   '}));
    expect(res.statusCode, 400);
  });

  test('expired code -> 410', () async {
    final store = await _openStore('link-expired');
    await _seed(
      store,
      expiresAt: DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 1))
          .toIso8601String(),
    );
    final handler = patientLinkHandler(eventStore: store);

    final res = await handler(_post(body: {'code': 'CAABCDE123'}));
    expect(res.statusCode, 410);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['error'], isA<String>());
  });

  test('second redemption of the same code -> 409 (already used)', () async {
    final store = await _openStore('link-twice');
    await _seed(store);
    final handler = patientLinkHandler(eventStore: store);

    final first = await handler(_post(body: {'code': 'CAABCDE123'}));
    expect(first.statusCode, 200);

    final second = await handler(_post(body: {'code': 'CAABCDE123'}));
    expect(second.statusCode, 409);
    final body =
        jsonDecode(await second.readAsString()) as Map<String, dynamic>;
    expect(body['error'], isA<String>());
    // B1's "already used" 409 must NOT collide with B2's device-relink 409,
    // which the diary app distinguishes by the "already linked" substring.
    expect(
      (body['error'] as String).toLowerCase(),
      isNot(contains('already linked')),
    );
  });
}
