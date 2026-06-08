// Verifies: DIARY-DEV-native-outbound-sync/A — diary events ship as canonical
//   esd/batch@1 batches through a native Destination.
// Verifies: DIARY-DEV-native-outbound-sync/B — a redelivery of the same batch
//   is idempotent on the receiver (no duplicate materialization).
// Verifies: DIARY-DEV-native-outbound-sync/C — the trial-start watermark
//   (setStartDate) activates the destination; only events at/after it ship.
// Verifies: DIARY-DEV-native-outbound-sync/D — the device source identity rides
//   the batch as provenance; the server materializes the canonical rows.
//
// The headline in-process native round-trip: a DEVICE scope's
// DiaryServerDestination POSTs canonical bytes into a MockClient that feeds them
// straight into a SECOND ("server") EventStore.ingestBatch — proving the real
// native sync end-to-end with NO HTTP server and NO legacy wire translation.

import 'package:clinical_diary/destinations/diary_server_destination.dart';
import 'package:clinical_diary/scope/diary_scope_bootstrap.dart';
import 'package:diary_shared_model/diary_shared_model.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

/// A standalone "server" node: an EventStore wired with the same diary entry
/// types + canonical projection, exposing a direct `ingestBatch` handle and a
/// reader over its `diary_entries` view.
class _ServerNode {
  _ServerNode({required this.bundle, required this.backend});

  final EventStoreBundle bundle;
  final SembastBackend backend;

  static Future<_ServerNode> open() async {
    final db = await newDatabaseFactoryMemory().openDatabase(
      'server-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final backend = SembastBackend(database: db);
    final bundle = await bootstrapEventStore(
      backend: backend,
      source: const Source(
        hopId: 'diary-server',
        identifier: 'server-1',
        softwareVersion: 'diary_server@0.0.0-test',
      ),
      entryTypes: [for (final t in diaryOriginatedEventTypes) t.definition],
      destinations: const [],
      projections: ProjectionRegistry()..register(diaryEntriesProjection),
    );
    return _ServerNode(bundle: bundle, backend: backend);
  }

  Future<IngestBatchResult> ingest(http.Request request) => bundle.eventStore
      .ingestBatch(request.bodyBytes, wireFormat: BatchEnvelope.wireFormat);

  Future<List<Map<String, dynamic>>> entryRows() =>
      backend.findViewRows(diaryEntriesViewName);

  Future<void> close() => bundle.eventStore.close();
}

/// Boots a DEVICE scope wired with a DiaryServerDestination whose MockClient
/// feeds POST bodies straight into `server.ingest`. Activates the destination
/// at a past watermark so events flow.
Future<DiaryScopeRuntime> _bootDevice(
  _ServerNode server, {
  required DateTime watermark,
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'device-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final client = MockClient((request) async {
    final result = await server.ingest(request);
    // 200 on success; the lib treats 2xx as SendOk.
    return http.Response('{"batchId":"${result.batchId}"}', 200);
  });

  final rt = await bootstrapDiaryScope(
    backend: SembastBackend(database: db),
    deviceId: 'DEV-1',
    softwareVersion: 'clinical_diary@0.0.0-test',
    localUserId: 'P-test',
    outboundDestinations: [
      DiaryServerDestination(
        client: client,
        resolveIngestUrl: () async =>
            Uri.parse('https://diary.example.com/ingest'),
        authToken: () async => 'jwt-token',
      ),
    ],
  );

  // Watermark: activate the destination. Past date -> historical replay picks
  // up already-appended events; live events ship via the post-append trigger.
  await rt.bundle.destinations.setStartDate(
    DiaryServerDestination.destinationId,
    watermark,
    initiator: const AutomationInitiator(service: 'test-watermark'),
  );
  return rt;
}

Future<void> _drain(DiaryScopeRuntime rt) async {
  await rt.syncCycle!.call();
  // Let post-append fire-and-forget triggers settle.
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

void main() {
  test(
    'native round-trip: device finalized/tombstone events materialize on server',
    () async {
      final server = await _ServerNode.open();
      final rt = await _bootDevice(server, watermark: DateTime.utc(2020, 1, 1));

      // 1. record_no_epistaxis_day (finalized day marker).
      expect(
        await rt.scope.actionSubmitter.submit(
          const ActionSubmission(
            actionName: 'record_no_epistaxis_day',
            rawInput: {'date': '2025-10-15'},
          ),
        ),
        isA<DispatchSuccess<Object?>>(),
      );

      // 2. record_epistaxis_event (finalized) — capture aggregate id to delete.
      final epistaxis = await rt.scope.actionSubmitter.submit(
        const ActionSubmission(
          actionName: 'record_epistaxis_event',
          rawInput: {
            'startTime': '2025-10-16T08:30:00.000-05:00',
            'startTimeZone': 'America/New_York',
            'startTimeUtcOffset': '-05:00',
            'intensity': 'mild',
          },
        ),
      );
      expect(epistaxis, isA<DispatchSuccess<Object?>>());
      final epistaxisId =
          (epistaxis as DispatchSuccess<Object?>).result! as String;

      await _drain(rt);

      // Both finalized aggregates materialized on the server.
      var rows = await server.entryRows();
      final ids = rows.map((r) => r['aggregateId']).toSet();
      expect(ids, contains('P-test:2025-10-15'));
      expect(ids, contains(epistaxisId));
      expect(rows.length, 2);

      // 3. delete_entry (tombstone) — removes the epistaxis row on the server.
      expect(
        await rt.scope.actionSubmitter.submit(
          ActionSubmission(
            actionName: 'delete_entry',
            rawInput: {
              'aggregateId': epistaxisId,
              'entryType': 'epistaxis_event',
              'changeReason': 'entered-in-error',
            },
          ),
        ),
        isA<DispatchSuccess<Object?>>(),
      );
      await _drain(rt);

      rows = await server.entryRows();
      final idsAfter = rows.map((r) => r['aggregateId']).toSet();
      expect(idsAfter, contains('P-test:2025-10-15'));
      expect(idsAfter, isNot(contains(epistaxisId)));

      await rt.dispose();
      await server.close();
    },
  );

  test(
    'redelivery is idempotent on the server (no duplicate materialization)',
    () async {
      final server = await _ServerNode.open();

      // Capture the canonical batch bytes the device sends, then ingest twice.
      final captured = <http.Request>[];
      final db = await newDatabaseFactoryMemory().openDatabase(
        'device-idem-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final client = MockClient((request) async {
        captured.add(request);
        final result = await server.ingest(request);
        return http.Response('{"batchId":"${result.batchId}"}', 200);
      });
      final rt = await bootstrapDiaryScope(
        backend: SembastBackend(database: db),
        deviceId: 'DEV-1',
        softwareVersion: 'clinical_diary@0.0.0-test',
        localUserId: 'P-test',
        outboundDestinations: [
          DiaryServerDestination(
            client: client,
            resolveIngestUrl: () async => Uri.parse('https://x/ingest'),
            authToken: () async => 'jwt',
          ),
        ],
      );
      await rt.bundle.destinations.setStartDate(
        DiaryServerDestination.destinationId,
        DateTime.utc(2020),
        initiator: const AutomationInitiator(service: 'test-watermark'),
      );

      expect(
        await rt.scope.actionSubmitter.submit(
          const ActionSubmission(
            actionName: 'record_no_epistaxis_day',
            rawInput: {'date': '2025-10-20'},
          ),
        ),
        isA<DispatchSuccess<Object?>>(),
      );
      await _drain(rt);

      final rowsOnce = await server.entryRows();
      expect(rowsOnce.length, 1);
      expect(captured, isNotEmpty);

      // Re-ingest the SAME captured batch bytes directly: idempotent.
      final firstBytes = captured.first.bodyBytes;
      final replay = await server.bundle.eventStore.ingestBatch(
        firstBytes,
        wireFormat: BatchEnvelope.wireFormat,
      );
      expect(
        replay.events.every((e) => e.outcome == IngestOutcome.duplicate),
        isTrue,
      );
      final rowsTwice = await server.entryRows();
      expect(
        rowsTwice.length,
        1,
        reason: 'redelivery must not duplicate the row',
      );

      await rt.dispose();
      await server.close();
    },
  );
}
