// Shared e2e harness for the portal_server_evs link/ingest loop tests
// (relink_loops, ingest_idempotency, diary_event_types). NOT a test suite
// itself (no `_test` suffix) — it is imported by the *_e2e_test.dart files.
//
// Boots the REAL portal server (dispatcher + LinkingCodeLifecycleReactor +
// /link + /ingest routers) over an in-memory Sembast backend, plus a device-side
// EventStore that ships diary events to /ingest as canonical esd/batch@1 bytes.
// This mirrors link_then_ingest_e2e_test.dart; the scaffolding is centralised
// here so the three Tier-A specs stay focused on assertions.
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

/// A booted portal server together with the backend it writes through, so tests
/// can both drive the public HTTP surface and read the projected views.
class PortalHarness {
  PortalHarness({required this.boot, required this.backend});
  final PortalServerBoot boot;
  final SembastBackend backend;

  EventStore get eventStore => boot.eventStore;
  ActionDispatcher get dispatcher => boot.dispatcher;

  Future<void> dispose() => boot.dispose();
}

/// Boot the real portal server over a fresh in-memory store. [DevSeedRaveClient]
/// keeps boot hermetic (no live RAVE creds).
Future<PortalHarness> bootPortal({String dbName = 'link-ingest-e2e'}) async {
  final db = await newDatabaseFactoryMemory()
      .openDatabase('$dbName-${DateTime.now().microsecondsSinceEpoch}.db');
  final backend = SembastBackend(database: db);
  final boot = await bootstrapPortalServer(
    backend: backend,
    raveClient: DevSeedRaveClient(),
  );
  return PortalHarness(boot: boot, backend: backend);
}

/// Seed a site + a participant synced from EDC, so participant_record +
/// participant_site_index + sites_index exist for [participantId] at [siteId].
Future<void> seedParticipant(
  EventStore es, {
  required String participantId,
  String siteId = 'S-1',
}) async {
  await es.append(
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
  await es.append(
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
}

/// Seed an authorized StudyCoordinator @ [siteId]. StudyCoordinator grants every
/// participant permission (link/disconnect/reconnect/mark_not_participating/
/// reactivate), so a single site-scoped assignment authorizes the whole loop.
Future<void> seedCoordinator(
  EventStore es, {
  String userId = 'coord-e2e',
  String siteId = 'S-1',
}) async {
  await bootstrapRoleAssignments(
    eventStore: es,
    seed: RoleAssignmentSeed(
      entries: <RoleAssignmentSeedEntry>[
        RoleAssignmentSeedEntry(
          userId: userId,
          role: 'StudyCoordinator',
          scope: BoundScope(class_: 'site', value: siteId),
        ),
      ],
    ),
  );
}

/// Build the coordinator's ActionContext. [at] sets requestStartedAt; it
/// defaults to *now* so the issued code's 72h expiry is always in the future.
/// (A hardcoded past date rots: the code expires 72h after that fixed instant.)
ActionContext coordinatorCtx({
  String userId = 'coord-e2e',
  DateTime? at,
}) =>
    ActionContext(
      principal: Principal.user(
        userId: userId,
        roles: const {'StudyCoordinator'},
        activeRole: 'StudyCoordinator',
      ),
      security: const SecurityDetails(),
      requestStartedAt: at ?? DateTime.now().toUtc(),
    );

/// Dispatch a coordinator action and return the typed result, asserting success.
Future<R> dispatchOk<R>(
  PortalHarness h,
  String actionName,
  Map<String, Object?> rawInput, {
  required String idempotencyKey,
  ActionContext? ctx,
}) async {
  final res = await h.dispatcher.dispatch(
    ActionSubmission(
      actionName: actionName,
      rawInput: rawInput,
      idempotencyKey: idempotencyKey,
    ),
    ctx ?? coordinatorCtx(),
  );
  if (res is! DispatchSuccess) {
    throw StateError('$actionName dispatch must succeed; got: $res');
  }
  return res.result as R;
}

/// Let the async LinkingCodeLifecycleReactor (supersession/collision self-heal)
/// settle after an issue/re-issue dispatch.
Future<void> settleReactor() =>
    Future<void>.delayed(const Duration(milliseconds: 80));

/// POST a code redemption to the REAL /link router.
Future<({int status, Map<String, dynamic> body})> redeemCode(
  PortalHarness h,
  String code, {
  String? appUuid,
}) async {
  final req = Request(
    'POST',
    Uri.parse('http://localhost/api/v1/user/link'),
    headers: const {'content-type': 'application/json'},
    body: jsonEncode(<String, Object?>{
      'code': code,
      if (appUuid != null) 'appUuid': appUuid,
    }),
  );
  final res = await h.boot.router.call(req);
  final text = await res.readAsString();
  Map<String, dynamic> body;
  try {
    body = jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    body = <String, dynamic>{'raw': text};
  }
  return (status: res.statusCode, body: body);
}

/// Issue a code (real ACT-PAT-001) and redeem it at /link, returning the minted
/// participant JWT. Throws if redemption does not succeed.
Future<String> linkDevice(
  PortalHarness h, {
  required String participantId,
  required String idempotencyKey,
  String siteId = 'S-1',
  String appUuid = 'DEVICE-1',
}) async {
  final issued = await dispatchOk<LinkParticipantResult>(
    h,
    'ACT-PAT-001',
    {'siteId': siteId, 'participantId': participantId},
    idempotencyKey: idempotencyKey,
  );
  await settleReactor();
  final link = await redeemCode(h, issued.linkingCode, appUuid: appUuid);
  if (link.status != 200) {
    throw StateError('link failed: ${link.status} ${link.body}');
  }
  return link.body['jwt'] as String;
}

/// Append a diary entry event on the [device] store (finalized by default), so
/// it will ship to /ingest on the next drain.
Future<void> appendDiaryEntry(
  DeviceBundle device, {
  required String entryType,
  required String aggregateId,
  required Map<String, Object?> data,
  String eventType = 'finalized',
}) =>
    device.eventStore.append(
      entryType: entryType,
      aggregateId: aggregateId,
      aggregateType: diaryEntryAggregateType,
      eventType: eventType,
      data: data,
      initiator: const AutomationInitiator(service: 'device'),
    );

/// POST raw esd/batch@1 bytes straight to the REAL /ingest router with [jwt],
/// returning the status + decoded `{batchId, ingested, duplicate}` body. Used to
/// re-deliver a captured batch verbatim (idempotency) and to drive ownership.
Future<({int status, Map<String, dynamic> body})> postIngest(
  PortalHarness h,
  List<int> bytes,
  String jwt,
) async {
  final req = Request(
    'POST',
    Uri.parse('http://localhost/api/v1/ingest/batch'),
    headers: {'authorization': 'Bearer $jwt'},
    body: bytes,
  );
  final res = await h.boot.router.call(req);
  final text = await res.readAsString();
  Map<String, dynamic> body;
  try {
    body = jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    body = <String, dynamic>{'raw': text};
  }
  return (status: res.statusCode, body: body);
}

/// GET the participant state (trial-start watermark + linking status) with [jwt].
Future<({int status, Map<String, dynamic> body})> getState(
  PortalHarness h,
  String jwt,
) async {
  final req = Request(
    'GET',
    Uri.parse('http://localhost/api/v1/user/state'),
    headers: {'authorization': 'Bearer $jwt'},
  );
  final res = await h.boot.router.call(req);
  final text = await res.readAsString();
  Map<String, dynamic> body;
  try {
    body = jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    body = <String, dynamic>{'raw': text};
  }
  return (status: res.statusCode, body: body);
}

/// All diary_entries view rows currently materialized on the portal.
Future<List<Map<String, Object?>>> diaryRows(PortalHarness h) =>
    h.backend.findViewRows(diaryEntriesViewName);

/// The participant_record row for [participantId] (or empty map if absent).
Future<Map<String, Object?>> participantRecord(
  PortalHarness h,
  String participantId,
) async {
  final rows = await h.backend.findViewRows('participant_record');
  return rows.firstWhere(
    (r) =>
        r['participant_id'] == participantId ||
        r['participantId'] == participantId,
    orElse: () => <String, Object?>{},
  );
}

/// A native outbound Destination that ships diary finalized/tombstone events as
/// canonical esd/batch@1 bytes via [client], recording every wire payload it
/// sends in [sentPayloads] so a test can re-deliver the exact bytes.
class CapturingDest extends Destination {
  CapturingDest({required this.client, required this.token});
  final http.Client client;
  final String token;

  /// The raw wire bytes of every batch shipped, in send order.
  final List<List<int>> sentPayloads = <List<int>>[];

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
      'CapturingDest is native (serializesNatively): transform() must not be called.',
    );
  }

  @override
  Future<SendResult> send(WirePayload payload) async {
    sentPayloads.add(payload.bytes);
    final res = await client.post(
      Uri.parse('http://localhost/api/v1/ingest/batch'),
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

/// A device-side EventStore wired to ship diary events through [destination].
class DeviceBundle {
  DeviceBundle({
    required this.bundle,
    required this.syncCycle,
    required this.backend,
  });
  final EventStoreBundle bundle;
  final SyncCycle syncCycle;
  final SembastBackend backend;

  EventStore get eventStore => bundle.eventStore;
  Future<void> close() => bundle.eventStore.close();
}

/// Boot a device EventStore wired with [destination] + a SyncCycle, with the
/// destination watermark opened to 2020 so seeded events drain immediately.
/// [extraEntryTypes] registers entry types beyond the static diary catalog —
/// e.g. a dynamically-registered `<id>_survey` type the diary app would add from
/// its questionnaires.json asset.
Future<DeviceBundle> bootDevice({
  required Destination destination,
  List<EntryTypeDefinition> extraEntryTypes = const <EntryTypeDefinition>[],
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'device-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  const source = Source(
    hopId: 'mobile-device',
    identifier: 'DEV-1',
    softwareVersion: 'test@0',
  );

  SyncCycle? syncCycle;
  Future<void> triggerDrain() async => syncCycle?.call();

  final bundle = await bootstrapEventStore(
    backend: backend,
    source: source,
    entryTypes: [
      for (final t in diaryOriginatedEventTypes) t.definition,
      ...extraEntryTypes,
    ],
    destinations: [destination],
    projections: ProjectionRegistry()..register(diaryEntriesProjection),
    syncCycleTrigger: triggerDrain,
  );

  syncCycle = SyncCycle(
    backend: backend,
    registry: bundle.destinations,
    source: source,
  );

  await bundle.destinations.setStartDate(
    'portal-ingest',
    DateTime.utc(2020),
    initiator: const AutomationInitiator(service: 'test-watermark'),
  );

  return DeviceBundle(bundle: bundle, syncCycle: syncCycle, backend: backend);
}

/// Build a dynamically-registered survey entry type id (`<id>_survey`), mirroring
/// what the diary app registers from its questionnaires.json asset.
EntryTypeDefinition surveyEntryType(String id) =>
    EntryTypeDefinition(id: id, registeredVersion: 1, name: id);

/// An http.Client that bridges device outbound posts into the portal [boot]'s
/// shelf router (so /ingest runs in-process).
http.Client portalBridge(PortalServerBoot boot) => MockClient((req) async {
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
        headers: const {'content-type': 'application/json'},
      );
    });

/// Drain the device's pending events to /ingest and let the background trigger
/// settle (the unawaited syncCycleTrigger from append() holds the reentrancy
/// guard, so the explicit call() may be a no-op).
Future<void> drainDevice(DeviceBundle device) async {
  await device.syncCycle.call();
  await Future<void>.delayed(const Duration(milliseconds: 50));
}
