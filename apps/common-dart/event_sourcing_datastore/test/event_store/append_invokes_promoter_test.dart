import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

/// Materializer that records every promoter invocation. Used to verify
/// REQ-d00140-G (promoter invoked once per applicable event with the
/// caller-supplied entryTypeVersion / target as fromVersion / toVersion).
// Implements: REQ-d00140-G+H — fixture for assertions on promoter
// invocation arguments and rollback-on-throw semantics.
class _RecordingMaterializer implements Materializer {
  _RecordingMaterializer();
  final List<({int from, int to, Map<String, Object?> data})> calls =
      <({int from, int to, Map<String, Object?> data})>[];
  bool throwNext = false;

  @override
  String get viewName => 'recording';

  @override
  bool appliesTo(StoredEvent event) => event.entryType == 'demo_note';

  @override
  EntryPromoter get promoter =>
      ({
        required entryType,
        required fromVersion,
        required toVersion,
        required data,
      }) {
        calls.add((from: fromVersion, to: toVersion, data: data));
        if (throwNext) throw StateError('promoter explosion');
        return data;
      };

  @override
  Future<int> targetVersionFor(
    Txn txn,
    StorageBackend backend,
    String entryType,
  ) async => 7;

  @override
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required Map<String, Object?> promotedData,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  }) async {
    // No-op — we only care about promoter call recording for these tests.
  }
}

void main() {
  group('REQ-d00140-G: append invokes promoter per matching materializer', () {
    test(
      'promoter called once per applicable event with correct args',
      () async {
        // Verifies: REQ-d00140-G — append invokes promoter with
        //   event.entryTypeVersion as fromVersion and the materializer's
        //   targetVersionFor as toVersion.
        final m = _RecordingMaterializer();
        final db = await newDatabaseFactoryMemory().openDatabase(
          'aip-1-${DateTime.now().microsecondsSinceEpoch}.db',
        );
        final ds = await bootstrapAppendOnlyDatastore(
          backend: SembastBackend(database: db),
          source: const Source(
            hopId: 'mobile',
            identifier: 'd',
            softwareVersion: 't',
          ),
          entryTypes: <EntryTypeDefinition>[
            const EntryTypeDefinition(
              id: 'demo_note',
              registeredVersion: 7,
              name: 'demo',
              widgetId: 'w',
              widgetConfig: <String, Object?>{},
            ),
          ],
          destinations: const <Destination>[],
          materializers: <Materializer>[m],
          initialViewTargetVersions: const <String, Map<String, int>>{
            'recording': <String, int>{'demo_note': 7},
          },
        );
        await ds.eventStore.append(
          entryType: 'demo_note',
          entryTypeVersion: 3,
          aggregateId: 'a',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const <String, Object?>{
            'answers': <String, Object?>{'k': 'v'},
          },
          initiator: const UserInitiator('u'),
        );
        expect(m.calls.length, 1);
        expect(m.calls.single.from, 3);
        expect(m.calls.single.to, 7);
        expect(m.calls.single.data, <String, Object?>{
          'answers': <String, Object?>{'k': 'v'},
        });
      },
    );

    test('REQ-d00140-H: promoter throw rolls back transaction', () async {
      // Verifies: REQ-d00140-H — promoter throw rolls back the txn; no
      //   event lands in the log.
      final m = _RecordingMaterializer()..throwNext = true;
      final backend = SembastBackend(
        database: await newDatabaseFactoryMemory().openDatabase(
          'aip-2-${DateTime.now().microsecondsSinceEpoch}.db',
        ),
      );
      final ds = await bootstrapAppendOnlyDatastore(
        backend: backend,
        source: const Source(
          hopId: 'mobile',
          identifier: 'd',
          softwareVersion: 't',
        ),
        entryTypes: <EntryTypeDefinition>[
          const EntryTypeDefinition(
            id: 'demo_note',
            registeredVersion: 1,
            name: 'demo',
            widgetId: 'w',
            widgetConfig: <String, Object?>{},
          ),
        ],
        destinations: const <Destination>[],
        materializers: <Materializer>[m],
        initialViewTargetVersions: const <String, Map<String, int>>{
          'recording': <String, int>{'demo_note': 1},
        },
      );
      await expectLater(
        ds.eventStore.append(
          entryType: 'demo_note',
          entryTypeVersion: 1,
          aggregateId: 'a',
          aggregateType: 'DiaryEntry',
          eventType: 'finalized',
          data: const <String, Object?>{'answers': <String, Object?>{}},
          initiator: const UserInitiator('u'),
        ),
        throwsStateError,
      );
      // Filter out bootstrap-audit rows so the assertion remains about
      // user-facing events: the failed promoter MUST roll back the user
      // append, but the bootstrap registry-initialized audit landed
      // before the append was attempted.
      // Verifies: REQ-d00134-E — bootstrap audit is unrelated to the
      //   user append rollback.
      final events = await backend.findAllEvents();
      final userEvents = events
          .where((e) => !kReservedSystemEntryTypeIds.contains(e.entryType))
          .toList();
      expect(userEvents, isEmpty);
    });
  });
}
