// Verifies: DIARY-DEV-participant-link-issuance/A+B+C+D — coordinator issues a
//   code (real ACT-PAT-001 dispatch) -> participant redeems it at the real
//   /api/v1/user/link edge -> gets a participant-identity JWT and the code is
//   consumed.
// Verifies: DIARY-DEV-participant-ingest/D+E — the minted JWT carries the
//   participant identity (D); a device batch on the participant's own aggregate
//   ingests + materializes, and a cross-participant batch is rejected 403 (E).
import 'dart:async';
import 'dart:convert';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_actions/portal_actions.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Minimal native outbound Destination: ships diary finalized/tombstone events
/// as canonical esd/batch@1 bytes via the injected http client (copied from
/// patient_ingest_roundtrip_test.dart). [token] is the participant JWT minted by
/// /link — the /ingest ownership gate (assertion D) checks the aggregate prefix
/// against this token's userId.
class _NativeDest extends Destination {
  _NativeDest({required this.client, required this.token});
  final http.Client client;
  final String token;

  @override
  String get id => 'portal-ingest';
  @override
  SubscriptionFilter get filter => const SubscriptionFilter(
        aggregateTypes: {diaryEntryAggregateType},
        eventTypes: {'finalized', 'tombstone'},
      );
  @override
  String get wireFormat => BatchEnvelope.wireFormat;
  @override
  bool get serializesNatively => true;
  @override
  Duration get maxAccumulateTime => Duration.zero;
  @override
  bool canAddToBatch(List<StoredEvent> currentBatch, StoredEvent candidate) =>
      true;
  @override
  Future<WirePayload> transform(List<StoredEvent> batch) async {
    throw UnimplementedError(
      '_NativeDest is native (serializesNatively): transform() must not be called.',
    );
  }

  @override
  Future<SendResult> send(WirePayload payload) async {
    final res = await client.post(
      Uri.parse('http://localhost/ingest'),
      headers: {'authorization': 'Bearer $token'},
      body: payload.bytes,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return const SendOk();
    if (res.statusCode >= 400 && res.statusCode < 500) {
      return SendPermanent(error: '${res.statusCode}: ${res.body}');
    }
    return SendTransient(
        error: '${res.statusCode}', httpStatus: res.statusCode);
  }
}

/// Boot a device-side EventStore wired with [destination] and a SyncCycle
/// (copied from patient_ingest_roundtrip_test.dart).
Future<({EventStoreBundle bundle, SyncCycle syncCycle, SembastBackend backend})>
    _bootDevice({
  required Destination destination,
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'device-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  const source = Source(
      hopId: 'mobile-device', identifier: 'DEV-1', softwareVersion: 'test@0');

  SyncCycle? syncCycle;
  Future<void> triggerDrain() async => syncCycle?.call();

  final bundle = await bootstrapEventStore(
    backend: backend,
    source: source,
    entryTypes: [for (final t in diaryOriginatedEventTypes) t.definition],
    destinations: [destination],
    projections: ProjectionRegistry()..register(diaryEntriesProjection),
    syncCycleTrigger: triggerDrain,
  );

  syncCycle = SyncCycle(
    backend: backend,
    registry: bundle.destinations,
    source: source,
  );

  return (bundle: bundle, syncCycle: syncCycle, backend: backend);
}

void main() {
  test(
      'issue code -> /link -> participant JWT -> /ingest materializes; '
      'cross-participant batch is rejected 403', () async {
    // 1. Boot the real portal server (dispatcher, LinkingCodeLifecycleReactor,
    //    /link, /ingest all wired). DevSeedRaveClient keeps boot hermetic.
    final portalDb =
        await newDatabaseFactoryMemory().openDatabase('link-ingest-e2e.db');
    final portalBackend = SembastBackend(database: portalDb);
    final boot = await bootstrapPortalServer(
        backend: portalBackend, raveClient: DevSeedRaveClient());
    addTearDown(boot.dispose);

    // 2. Seed a participant synced from EDC so participant_record +
    //    participant_site_index exist for P-SELF at site S-1.
    await boot.eventStore.append(
      entryType: 'participant_synced_from_edc',
      aggregateType: 'participant',
      aggregateId: 'P-SELF',
      eventType: 'participant_synced_from_edc',
      data: const <String, Object?>{
        'participant_id': 'P-SELF',
        'site_id': 'S-1',
      },
      initiator: const AutomationInitiator(service: 'test-seed'),
    );

    // 3. Seed an authorized coordinator. StudyCoordinator grants
    //    portal.participant.link (scoped to `site`); the link permission is
    //    site-scoped, so a single StudyCoordinator @ S-1 assignment is the only
    //    gate (no tier/user-scope row needed — ACT-PAT-001 is read-free).
    await bootstrapRoleAssignments(
      eventStore: boot.eventStore,
      seed: const RoleAssignmentSeed(entries: <RoleAssignmentSeedEntry>[
        RoleAssignmentSeedEntry(
          userId: 'coord-e2e',
          role: 'StudyCoordinator',
          scope: BoundScope(class_: 'site', value: 'S-1'),
        ),
      ]),
    );

    final coordinator = Principal.user(
      userId: 'coord-e2e',
      roles: const {'StudyCoordinator'},
      activeRole: 'StudyCoordinator',
    );
    final ctx = ActionContext(
      principal: coordinator,
      security: const SecurityDetails(),
      // Use *now*, not a fixed past date: the issued code expires 72h after
      // requestStartedAt, so a hardcoded instant rots the test the moment wall
      // clock passes it (this previously broke after 2026-06-04T00:00Z).
      requestStartedAt: DateTime.now().toUtc(),
    );

    // 4. Dispatch the issue action (real action dispatch).
    final res = await boot.dispatcher.dispatch(
      const ActionSubmission(
        actionName: 'ACT-PAT-001',
        rawInput: <String, Object?>{
          'siteId': 'S-1',
          'participantId': 'P-SELF',
        },
        idempotencyKey: 'e2e-1',
      ),
      ctx,
    );
    expect(res, isA<DispatchSuccess<Object?>>(),
        reason: 'ACT-PAT-001 dispatch must succeed; got: $res');
    final result = (res as DispatchSuccess).result as LinkParticipantResult;
    final code = result.linkingCode;
    expect(code, isNotEmpty, reason: 'issue must return a non-empty code');

    // 5. Let the linking-code reactor settle (supersession/collision; a no-op
    //    for a first issue, but proves the reactor does not break the loop).
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // 6. Redeem the code at the REAL /link router.
    final linkReq = Request(
      'POST',
      Uri.parse('http://localhost/api/v1/user/link'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(<String, Object?>{'code': code, 'appUuid': 'DEVICE-1'}),
    );
    final linkRes = await boot.router.call(linkReq);
    expect(linkRes.statusCode, 200,
        reason: 'redeeming an active code must succeed');
    final linkBody =
        jsonDecode(await linkRes.readAsString()) as Map<String, dynamic>;
    expect(linkBody['jwt'], isNotNull, reason: '/link must mint a JWT');
    expect(linkBody['participantId'], 'P-SELF',
        reason: 'the JWT identity is the participant id');
    expect(linkBody['success'], true,
        reason: '/link must report success on a valid redemption');
    expect(linkBody['linkingCode'], code,
        reason: '/link response must echo back the normalized linking code');
    final jwt = linkBody['jwt'] as String;

    // 6b. The code is now consumed (single-use): its linking_codes row flips to
    //     status 'used'.
    final codeRows = await portalBackend.findViewRows('linking_codes');
    final consumed = codeRows.firstWhere(
      (r) => r['linking_code'] == code,
      orElse: () => <String, Object?>{},
    );
    expect(consumed['status'], 'used',
        reason: 'the redeemed code must be marked used');

    // 7. Use the minted JWT to sync a device batch to /ingest.
    final bridge = MockClient((req) async {
      final shelfReq = Request(
        req.method,
        req.url,
        headers: req.headers,
        body: req.bodyBytes,
      );
      final shelfRes = await boot.router.call(shelfReq);
      return http.Response(
        await shelfRes.readAsString(),
        shelfRes.statusCode,
        headers: {'content-type': 'application/json'},
      );
    });

    final device =
        await _bootDevice(destination: _NativeDest(client: bridge, token: jwt));
    addTearDown(() => device.bundle.eventStore.close());

    await device.bundle.destinations.setStartDate(
      'portal-ingest',
      DateTime.utc(2020),
      initiator: const AutomationInitiator(service: 'test-watermark'),
    );

    await device.bundle.eventStore.append(
      entryType: 'no_epistaxis_event',
      aggregateId: 'P-SELF:2025-10-15',
      aggregateType: diaryEntryAggregateType,
      eventType: 'finalized',
      data: const {'date': '2025-10-15'},
      initiator: const AutomationInitiator(service: 'device'),
    );

    await device.syncCycle.call();
    // The unawaited syncCycleTrigger from append() holds the reentrancy guard,
    // making the explicit call() a no-op; let the background drain settle.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final diaryRows = await portalBackend.findViewRows(diaryEntriesViewName);
    expect(
      diaryRows.map((r) => r['aggregateId']),
      contains('P-SELF:2025-10-15'),
      reason: 'the participant batch must materialize on the portal',
    );

    // 8. Cross-participant rejection: POST a batch for a DIFFERENT participant's
    //    aggregate directly to /ingest with the P-SELF JWT -> 403.
    final foreignBatch = BatchEnvelope(
      batchFormatVersion: '1',
      batchId: 'x',
      senderHop: 'mobile',
      senderIdentifier: 'DEV',
      senderSoftwareVersion: 't@0',
      sentAt: DateTime.utc(2026, 6, 1),
      events: [
        <String, Object?>{'aggregate_id': 'P-OTHER:2025-10-15'}
      ],
    ).encode();
    final foreignReq = Request(
      'POST',
      Uri.parse('http://localhost/ingest'),
      headers: {'authorization': 'Bearer $jwt'},
      body: foreignBatch,
    );
    final foreignRes = await boot.router.call(foreignReq);
    expect(foreignRes.statusCode, 403,
        reason: 'a cross-participant batch must be rejected');
  });
}
