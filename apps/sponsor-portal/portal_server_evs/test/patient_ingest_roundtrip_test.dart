// Verifies: DIARY-DEV-patient-ingest/A+C+D — device batch ingests through the
//   real portal /ingest; receiver hop appended; participantId rides the aggregate
//   id; redelivery is idempotent.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_server_evs/portal_server_evs.dart';
import 'package:portal_server_evs/src/patient_token_validator.dart';
import 'package:portal_service/portal_service.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Minimal native outbound Destination: ships diary finalized/tombstone events
/// as canonical esd/batch@1 bytes via the injected http client.
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

/// Boot a device-side EventStore wired with [destination] and a SyncCycle.
/// Returns a record of (bundle, syncCycle, deviceBackend).
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

  // Forward-declare syncCycle so the trigger closure can capture it; this
  // mirrors the pattern in diary_scope_bootstrap.dart.
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
  test('device finalized event ingests through portal /ingest and materializes',
      () async {
    // 1. Boot the real portal server.
    final portalDb =
        await newDatabaseFactoryMemory().openDatabase('portal-rt.db');
    final portalBackend = SembastBackend(database: portalDb);
    final boot = await bootstrapPortalServer(
        backend: portalBackend, raveClient: DevSeedRaveClient());
    addTearDown(boot.dispose);

    // 2. Bridge: device POST -> shelf Request -> portal router.
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
    final token = createPatientJwt(authCode: 'ac', userId: 'u');

    // 3. Boot device with the native destination.
    final dest = _NativeDest(client: bridge, token: token);
    final device = await _bootDevice(destination: dest);
    addTearDown(() => device.bundle.eventStore.close());

    // 4. Activate the destination (past watermark -> historical replay picks up
    //    already-appended events; post-append trigger fires for new ones).
    await device.bundle.destinations.setStartDate(
      'portal-ingest',
      DateTime.utc(2020),
      initiator: const AutomationInitiator(service: 'test-watermark'),
    );

    // 5. Append a finalized diary entry on the device side.
    await device.bundle.eventStore.append(
      entryType: 'no_epistaxis_event',
      aggregateId: 'P-test:2025-10-15',
      aggregateType: diaryEntryAggregateType,
      eventType: 'finalized',
      data: const {'date': '2025-10-15'},
      initiator: const AutomationInitiator(service: 'device'),
    );

    // 6. Drive the sync cycle and let fire-and-forget settle.
    await device.syncCycle.call();
    // EventStore.append() fires an unawaited syncCycleTrigger that races ahead
    // and sets the SyncCycle's reentrancy guard, making the explicit call()
    // above a no-op.  The real drain completes in that background Future; this
    // delay lets it settle before we query the portal store.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // 7a. The diary_entries row materializes on the PORTAL store.
    final rows = await portalBackend.findViewRows(diaryEntriesViewName);
    expect(
      rows.map((r) => r['aggregateId']),
      contains('P-test:2025-10-15'),
      reason: 'diary_entries row must materialize on the portal after /ingest',
    );

    // 7b. The ingested event's provenance chain: mobile-device -> portal-server.
    final events = await portalBackend.readEventsReverse().toList();
    final finalized = events.firstWhere((e) =>
        e.eventType == 'finalized' &&
        e.aggregateType == diaryEntryAggregateType);
    final provenanceList = finalized.metadata['provenance'] as List;
    final hops =
        provenanceList.map((h) => (h as Map)['hop'] as String).toList();
    expect(
      hops,
      ['mobile-device', 'portal-server'],
      reason: 'provenance chain must be [originator, receiver]',
    );
  });

  test('redelivery of the same batch is idempotent (ingested:0, duplicate:1)',
      () async {
    // 1. Boot portal server.
    final portalDb =
        await newDatabaseFactoryMemory().openDatabase('portal-idem.db');
    final portalBackend = SembastBackend(database: portalDb);
    final boot = await bootstrapPortalServer(
        backend: portalBackend, raveClient: DevSeedRaveClient());
    addTearDown(boot.dispose);

    // 2. Capturing bridge: records the raw batch bytes.
    final captured = <Uint8List>[];
    final bridge = MockClient((req) async {
      captured.add(req.bodyBytes);
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
    final token = createPatientJwt(authCode: 'ac2', userId: 'u2');

    // 3. Device + destination.
    final dest = _NativeDest(client: bridge, token: token);
    final device = await _bootDevice(destination: dest);
    addTearDown(() => device.bundle.eventStore.close());

    await device.bundle.destinations.setStartDate(
      'portal-ingest',
      DateTime.utc(2020),
      initiator: const AutomationInitiator(service: 'test-watermark'),
    );

    // 4. Append + drain once.
    await device.bundle.eventStore.append(
      entryType: 'no_epistaxis_event',
      aggregateId: 'P-test:2025-10-20',
      aggregateType: diaryEntryAggregateType,
      eventType: 'finalized',
      data: const {'date': '2025-10-20'},
      initiator: const AutomationInitiator(service: 'device'),
    );
    await device.syncCycle.call();
    // Same race as above: the unawaited trigger from append() holds the
    // reentrancy guard, so the explicit call() is a no-op; wait for the
    // background drain to complete before asserting.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final rowsOnce = await portalBackend.findViewRows(diaryEntriesViewName);
    expect(rowsOnce, hasLength(1));
    expect(captured, isNotEmpty);

    // 5. Re-POST the SAME captured batch bytes directly to /ingest.
    final firstBytes = captured.first;
    final replayShelfReq = Request(
      'POST',
      Uri.parse('http://localhost/ingest'),
      headers: {'authorization': 'Bearer $token'},
      body: firstBytes,
    );
    final replayRes = await boot.router.call(replayShelfReq);
    expect(replayRes.statusCode, 200);
    final replayBody =
        jsonDecode(await replayRes.readAsString()) as Map<String, dynamic>;
    expect(replayBody['ingested'], 0, reason: 'redelivery: ingested must be 0');
    expect(replayBody['duplicate'], 1,
        reason: 'redelivery: duplicate must be 1');

    // 6. Row count is unchanged after redelivery.
    final rowsTwice = await portalBackend.findViewRows(diaryEntriesViewName);
    expect(rowsTwice, hasLength(1),
        reason: 'redelivery must not duplicate the row');
  });
}
