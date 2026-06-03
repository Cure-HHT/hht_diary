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

  // --- B2 relink/device gate -------------------------------------------------
  // Verifies: DIARY-DEV-relink-device-gate/A+B+C

  /// Seed the participant as already `connected` to [appUuid] by appending a
  /// `participant_linking_code_used` event (what a prior successful /link would
  /// have produced). This merges mobile_linking_status:'connected' + the device
  /// uuid onto participant_record. Then re-issue a FRESH active code for the
  /// same participant (a coordinator re-issue).
  Future<void> seedConnectedThenReissue(
    EventStore store, {
    required String participantId,
    required String connectedAppUuid,
    required String freshCode,
    String siteId = 'S-1',
  }) async {
    // A prior successful link: participant_record now connected to the device.
    await store.append(
      entryType: 'participant_linking_code_used',
      aggregateType: 'participant',
      aggregateId: participantId,
      eventType: 'participant_linking_code_used',
      data: <String, Object?>{
        'linking_code': 'CAOLDCODE0',
        'participant_id': participantId,
        'app_uuid': connectedAppUuid,
        'status': 'used',
        'mobile_linking_status': 'connected',
      },
      initiator: const AutomationInitiator(service: 'test'),
    );

    // Coordinator re-issues a fresh active code for the same participant.
    final expires =
        DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();
    await store.append(
      entryType: 'participant_linking_code_issued',
      aggregateType: 'participant',
      aggregateId: participantId,
      eventType: 'participant_linking_code_issued',
      data: <String, Object?>{
        'linking_code': freshCode,
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

  test(
      'relink to a DIFFERENT device -> 409 "already linked"; fresh code '
      'is NOT consumed', () async {
    final store = await _openStore('link-relink-diff');
    await _seed(store); // site + participant + an (unused) issued code.
    await seedConnectedThenReissue(
      store,
      participantId: 'P-1',
      connectedAppUuid: 'DEVICE-A',
      freshCode: 'CAFRESH001',
    );
    final handler = patientLinkHandler(eventStore: store);

    final res = await handler(
      _post(body: {'code': 'CAFRESH001', 'appUuid': 'DEVICE-B'}),
    );
    expect(res.statusCode, 409);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(
      (body['error'] as String).toLowerCase(),
      contains('already linked'),
    );

    // The rejected relink must NOT consume the fresh code.
    final rows = await store.backend.findViewRows('linking_codes');
    final row = rows.firstWhere((r) => r['linking_code'] == 'CAFRESH001');
    expect(row['status'], 'active');
  });

  test(
      'relink with the SAME device uuid -> 200 (same-device continuity); '
      'fresh code is consumed', () async {
    final store = await _openStore('link-relink-same');
    await _seed(store);
    await seedConnectedThenReissue(
      store,
      participantId: 'P-1',
      connectedAppUuid: 'DEVICE-A',
      freshCode: 'CAFRESH001',
    );
    final handler = patientLinkHandler(eventStore: store);

    final res = await handler(
      _post(body: {'code': 'CAFRESH001', 'appUuid': 'DEVICE-A'}),
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['jwt'], isNotNull);

    final rows = await store.backend.findViewRows('linking_codes');
    final row = rows.firstWhere((r) => r['linking_code'] == 'CAFRESH001');
    expect(row['status'], 'used');
  });

  test(
      'device-bound participant + code submitted with NO appUuid -> 200 '
      '(intentional back-compat allow); fresh code is consumed', () async {
    // Locks the documented "no appUuid submitted -> gate allows" path: app
    // versions that don't send appUuid are not blocked by the relink gate.
    final store = await _openStore('link-relink-no-appuuid');
    await _seed(store);
    await seedConnectedThenReissue(
      store,
      participantId: 'P-1',
      connectedAppUuid: 'DEVICE-A',
      freshCode: 'CAFRESH001',
    );
    final handler = patientLinkHandler(eventStore: store);

    // Body carries the fresh valid code but NO appUuid field.
    final res = await handler(_post(body: {'code': 'CAFRESH001'}));
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['jwt'], isNotNull);

    final rows = await store.backend.findViewRows('linking_codes');
    final row = rows.firstWhere((r) => r['linking_code'] == 'CAFRESH001');
    expect(row['status'], 'used');
  });

  test(
      'relink to a different device AFTER disconnect -> 200 (reconnect '
      'allowed)', () async {
    final store = await _openStore('link-relink-disc');
    await _seed(store);
    await seedConnectedThenReissue(
      store,
      participantId: 'P-1',
      connectedAppUuid: 'DEVICE-A',
      freshCode: 'CAFRESH001',
    );
    // Disconnect the participant so participant_record.mobile_linking_status
    // becomes 'disconnected'. (Appended directly here, mirroring what
    // DisconnectParticipantAction now emits.)
    await store.append(
      entryType: 'participant_disconnected',
      aggregateType: 'participant',
      aggregateId: 'P-1',
      eventType: 'participant_disconnected',
      data: <String, Object?>{'mobile_linking_status': 'disconnected'},
      initiator: const AutomationInitiator(service: 'test'),
    );
    final handler = patientLinkHandler(eventStore: store);

    final res = await handler(
      _post(body: {'code': 'CAFRESH001', 'appUuid': 'DEVICE-B'}),
    );
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['jwt'], isNotNull);
  });
}
