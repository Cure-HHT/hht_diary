// Verifies: REQ-d00121-K, REQ-d00145-N, REQ-d00154-D — receivers project
//   ingested events into materialized views identically to local-appended
//   events. The materializer loop on the ingest path is symmetric with
//   the loop on the append path (same gates, same atomicity, same
//   throw-rolls-back semantics). Closes Phase 4.9 design spec §398.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

var _dbCounter = 0;

class _Fixture {
  _Fixture({required this.datastore, required this.backend});
  final AppendOnlyDatastore datastore;
  final SembastBackend backend;
  Future<void> close() => backend.close();
}

const EntryTypeDefinition _demoNoteDef = EntryTypeDefinition(
  id: 'demo_note',
  registeredVersion: 1,
  name: 'Demo Note',
  widgetId: 'w',
  widgetConfig: <String, Object?>{},
);

Future<_Fixture> _openDatastore({
  String hopId = 'mobile-device',
  String identifier = 'device-1',
  String softwareVersion = 'clinical_diary@1.0.0',
  List<Materializer> materializers = const <Materializer>[
    DiaryEntriesMaterializer(promoter: identityPromoter),
  ],
  Map<String, Map<String, int>> initialViewTargetVersions =
      const <String, Map<String, int>>{
        'diary_entries': <String, int>{'demo_note': 1},
      },
}) async {
  _dbCounter += 1;
  final db = await newDatabaseFactoryMemory().openDatabase(
    'ingest-mat-$_dbCounter.db',
  );
  final backend = SembastBackend(database: db);
  final datastore = await bootstrapAppendOnlyDatastore(
    backend: backend,
    source: Source(
      hopId: hopId,
      identifier: identifier,
      softwareVersion: softwareVersion,
    ),
    entryTypes: const <EntryTypeDefinition>[_demoNoteDef],
    destinations: const <Destination>[],
    materializers: materializers,
    initialViewTargetVersions: initialViewTargetVersions,
  );
  return _Fixture(datastore: datastore, backend: backend);
}

BatchEnvelope _buildEnvelope(
  List<StoredEvent> events, {
  required String senderHop,
  required String senderIdentifier,
  required String senderSoftwareVersion,
}) {
  return BatchEnvelope(
    batchFormatVersion: '1',
    batchId: const Uuid().v4(),
    senderHop: senderHop,
    senderIdentifier: senderIdentifier,
    senderSoftwareVersion: senderSoftwareVersion,
    sentAt: DateTime.now().toUtc(),
    events: events.map((e) => Map<String, Object?>.from(e.toMap())).toList(),
  );
}

/// Recording materializer over `aggregateType == 'DiaryEntry'` that captures
/// every `applyInTxn` invocation. Used to assert the materializer is invoked
/// (or not invoked) on the ingest path.
class _RecordingMaterializer implements Materializer {
  _RecordingMaterializer();
  final List<StoredEvent> applied = <StoredEvent>[];

  @override
  String get viewName => 'recording_view';

  @override
  bool appliesTo(StoredEvent event) => event.aggregateType == 'DiaryEntry';

  @override
  EntryPromoter get promoter => identityPromoter;

  @override
  Future<int> targetVersionFor(
    Txn txn,
    StorageBackend backend,
    String entryType,
  ) async => 1;

  @override
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required Map<String, Object?> promotedData,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  }) async {
    applied.add(event);
  }
}

/// Materializer that throws on the Nth invocation. Used to verify that a
/// materializer throw on the ingest path rolls back the entire batch.
class _ThrowingTestMaterializer implements Materializer {
  _ThrowingTestMaterializer({required this.throwOnCall});
  final int throwOnCall; // 1-indexed call number that triggers the throw
  int callCount = 0;
  final List<StoredEvent> applied = <StoredEvent>[];

  @override
  String get viewName => 'throwing_view';

  @override
  bool appliesTo(StoredEvent event) => event.aggregateType == 'DiaryEntry';

  @override
  EntryPromoter get promoter => identityPromoter;

  @override
  Future<int> targetVersionFor(
    Txn txn,
    StorageBackend backend,
    String entryType,
  ) async => 1;

  @override
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required Map<String, Object?> promotedData,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  }) async {
    callCount += 1;
    if (callCount == throwOnCall) {
      throw StateError(
        '_ThrowingTestMaterializer: explosion on call $callCount',
      );
    }
    applied.add(event);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group(
    'EventStore ingest path materializer loop (REQ-d00121-K, REQ-d00145-N)',
    () {
      // Verifies: REQ-d00121-K, REQ-d00145-N — ingestEvent fires materializers
      //   per-event with the same gates as local-append.
      test('REQ-d00121-K + REQ-d00145-N: ingestEvent populates diary_entries '
          'view from a freshly-ingested user event', () async {
        final orig = await _openDatastore(
          hopId: 'mobile-device',
          identifier: 'device-1',
        );
        final dest = await _openDatastore(
          hopId: 'portal-server',
          identifier: 'portal-1',
          softwareVersion: 'portal@0.1.0',
        );

        try {
          // Originate an event on the sender; it materializes locally.
          final original = await orig.datastore.eventStore.append(
            entryType: 'demo_note',
            entryTypeVersion: 1,
            aggregateId: 'agg-ingest-1',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{
              'answers': <String, Object?>{'title': 'hello', 'body': 'world'},
            },
            initiator: const UserInitiator('u-orig'),
          );
          expect(original, isNotNull);

          // Pre-ingest: receiver has no diary_entries rows.
          final preRows = await dest.backend.findEntries(
            entryType: 'demo_note',
          );
          expect(preRows, isEmpty);

          // Ingest the originator's event at the receiver.
          final outcome = await dest.datastore.eventStore.ingestEvent(
            original!,
          );
          expect(outcome.outcome, equals(IngestOutcome.ingested));

          // Post-ingest: receiver has one row in diary_entries reflecting
          // the ingested event's answers.
          final postRows = await dest.backend.findEntries(
            entryType: 'demo_note',
          );
          expect(postRows, hasLength(1));
          expect(postRows.first.entryId, equals('agg-ingest-1'));
          expect(postRows.first.currentAnswers, <String, Object?>{
            'title': 'hello',
            'body': 'world',
          });
          expect(postRows.first.isComplete, isTrue);
          expect(postRows.first.isDeleted, isFalse);
          expect(postRows.first.latestEventId, equals(original.eventId));
        } finally {
          await orig.close();
          await dest.close();
        }
      });

      // Verifies: REQ-d00121-K — ingestBatch projects each event in the batch
      //   into the diary_entries view atomically with the event log write.
      test('REQ-d00121-K: ingestBatch projects each event in batch into '
          'diary_entries view', () async {
        final orig = await _openDatastore(
          hopId: 'mobile-device',
          identifier: 'device-1',
        );
        final dest = await _openDatastore(
          hopId: 'portal-server',
          identifier: 'portal-1',
          softwareVersion: 'portal@0.1.0',
        );

        try {
          // Originate three distinct demo_note finalized events.
          final e1 = await orig.datastore.eventStore.append(
            entryType: 'demo_note',
            entryTypeVersion: 1,
            aggregateId: 'agg-batch-A',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{
              'answers': <String, Object?>{'idx': 'a'},
            },
            initiator: const UserInitiator('u'),
          );
          final e2 = await orig.datastore.eventStore.append(
            entryType: 'demo_note',
            entryTypeVersion: 1,
            aggregateId: 'agg-batch-B',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{
              'answers': <String, Object?>{'idx': 'b'},
            },
            initiator: const UserInitiator('u'),
          );
          final e3 = await orig.datastore.eventStore.append(
            entryType: 'demo_note',
            entryTypeVersion: 1,
            aggregateId: 'agg-batch-C',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{
              'answers': <String, Object?>{'idx': 'c'},
            },
            initiator: const UserInitiator('u'),
          );
          expect(e1, isNotNull);
          expect(e2, isNotNull);
          expect(e3, isNotNull);

          final envelope = _buildEnvelope(
            <StoredEvent>[e1!, e2!, e3!],
            senderHop: 'mobile-device',
            senderIdentifier: 'device-1',
            senderSoftwareVersion: 'clinical_diary@1.0.0',
          );

          final result = await dest.datastore.eventStore.ingestBatch(
            envelope.encode(),
            wireFormat: BatchEnvelope.wireFormat,
          );
          expect(result.events, hasLength(3));
          for (final outcome in result.events) {
            expect(outcome.outcome, equals(IngestOutcome.ingested));
          }

          final rows = await dest.backend.findEntries(entryType: 'demo_note');
          expect(rows, hasLength(3));
          final byId = <String, DiaryEntry>{for (final r in rows) r.entryId: r};
          expect(byId['agg-batch-A']!.currentAnswers['idx'], equals('a'));
          expect(byId['agg-batch-B']!.currentAnswers['idx'], equals('b'));
          expect(byId['agg-batch-C']!.currentAnswers['idx'], equals('c'));
        } finally {
          await orig.close();
          await dest.close();
        }
      });

      // Verifies: REQ-d00145-A + REQ-d00121-K — a materializer throw rolls
      //   back the entire batch (event log AND view writes).
      test('REQ-d00145-A + REQ-d00121-K: materializer throw rolls back entire '
          'ingestBatch (no events landed, no view rows)', () async {
        final orig = await _openDatastore(
          hopId: 'mobile-device',
          identifier: 'device-1',
        );
        final throwing = _ThrowingTestMaterializer(throwOnCall: 2);
        final dest = await _openDatastore(
          hopId: 'portal-server',
          identifier: 'portal-1',
          softwareVersion: 'portal@0.1.0',
          materializers: <Materializer>[throwing],
          initialViewTargetVersions: const <String, Map<String, int>>{
            'throwing_view': <String, int>{'demo_note': 1},
          },
        );

        try {
          // Originate three events on a non-throwing sender pane.
          final e1 = await orig.datastore.eventStore.append(
            entryType: 'demo_note',
            entryTypeVersion: 1,
            aggregateId: 'agg-rb-1',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{'answers': <String, Object?>{}},
            initiator: const UserInitiator('u'),
          );
          final e2 = await orig.datastore.eventStore.append(
            entryType: 'demo_note',
            entryTypeVersion: 1,
            aggregateId: 'agg-rb-2',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{'answers': <String, Object?>{}},
            initiator: const UserInitiator('u'),
          );
          final e3 = await orig.datastore.eventStore.append(
            entryType: 'demo_note',
            entryTypeVersion: 1,
            aggregateId: 'agg-rb-3',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{'answers': <String, Object?>{}},
            initiator: const UserInitiator('u'),
          );

          final envelope = _buildEnvelope(
            <StoredEvent>[e1!, e2!, e3!],
            senderHop: 'mobile-device',
            senderIdentifier: 'device-1',
            senderSoftwareVersion: 'clinical_diary@1.0.0',
          );

          // Snapshot the receiver's user-event log before the failed batch
          // (the bootstrap audit events live under the system aggregate;
          // exclude them so the rollback assertion targets user payload).
          final preEvents = (await dest.backend.findAllEvents())
              .where((e) => !kReservedSystemEntryTypeIds.contains(e.entryType))
              .toList();
          expect(preEvents, isEmpty);

          // Ingest the batch; the throwing materializer fires on the
          // second event and rolls back the whole transaction.
          await expectLater(
            dest.datastore.eventStore.ingestBatch(
              envelope.encode(),
              wireFormat: BatchEnvelope.wireFormat,
            ),
            throwsA(isA<StateError>()),
          );

          // No user events landed.
          final postEvents = (await dest.backend.findAllEvents())
              .where((e) => !kReservedSystemEntryTypeIds.contains(e.entryType))
              .toList();
          expect(postEvents, isEmpty);

          // No materializer side-effects either: no diary_entries rows
          // (the throwing materializer is over a different view, but
          // the rollback applies to every store touched inside the txn).
          final rows = await dest.backend.findEntries(entryType: 'demo_note');
          expect(rows, isEmpty);
        } finally {
          await orig.close();
          await dest.close();
        }
      });

      // Verifies: REQ-d00154-D — ingested system events do NOT fire
      //   materializers because their EntryTypeDefinitions ship
      //   `materialize: false`. The outer gate (`def.materialize`)
      //   short-circuits before the inner `appliesTo` check is reached.
      test('REQ-d00154-D: ingested system events do NOT fire materializers '
          '(def.materialize:false short-circuits the outer gate)', () async {
        // Recording materializer on the receiver. We never expect it to
        // fire because the synthetic batch carries only a system event
        // whose EntryTypeDefinition has `materialize: false`.
        final recording = _RecordingMaterializer();
        final dest = await _openDatastore(
          hopId: 'portal-server',
          identifier: 'portal-1',
          softwareVersion: 'portal@0.1.0',
          materializers: <Materializer>[recording],
          initialViewTargetVersions: const <String, Map<String, int>>{
            'recording_view': <String, int>{'demo_note': 1},
          },
        );

        // Bootstrap a sender pane — its bootstrap step already emits a
        // `system.entry_type_registry_initialized` event under the
        // sender's source.identifier aggregate (REQ-d00134-E,
        // REQ-d00154-D). Read that event off the sender's log and ship
        // it to the receiver via ingestBatch.
        final sender = await _openDatastore(
          hopId: 'mobile-device',
          identifier: 'sender-id-1',
        );
        final senderEvents = await sender.backend.findAllEvents();
        final senderSystemEvent = senderEvents.firstWhere(
          (e) => e.entryType == kEntryTypeRegistryInitializedEntryType,
        );
        expect(
          kReservedSystemEntryTypeIds.contains(senderSystemEvent.entryType),
          isTrue,
          reason: 'precondition: sender system event must be a reserved id',
        );

        final initialApplied = recording.applied.length;

        try {
          final envelope = _buildEnvelope(
            <StoredEvent>[senderSystemEvent],
            senderHop: 'mobile-device',
            senderIdentifier: 'sender-id-1',
            senderSoftwareVersion: 'clinical_diary@1.0.0',
          );

          final result = await dest.datastore.eventStore.ingestBatch(
            envelope.encode(),
            wireFormat: BatchEnvelope.wireFormat,
          );
          // The system event was admitted into the event log on the
          // receiver — the lib's gate is materializer-only, not ingest-
          // wide. (See REQ-d00154-E receiver-stays-passive — write-side
          // ingest is independent of registry mutation.)
          expect(result.events, hasLength(1));
          expect(
            result.events.first.outcome,
            anyOf(
              equals(IngestOutcome.ingested),
              equals(IngestOutcome.duplicate),
            ),
          );

          // Materializer was NOT fired for the system event.
          expect(
            recording.applied.length,
            equals(initialApplied),
            reason:
                'system entry type ships materialize:false; outer gate '
                'must short-circuit the materializer loop on ingest.',
          );
        } finally {
          await sender.close();
          await dest.close();
        }
      });
    },
  );
}
