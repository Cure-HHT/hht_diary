import 'package:event_sourcing_datastore/src/entry_type_definition.dart';
import 'package:event_sourcing_datastore/src/materialization/diary_entries_materializer.dart';
import 'package:event_sourcing_datastore/src/materialization/materializer.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<SembastBackend> _openBackend() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'dem-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return SembastBackend(database: db);
}

StoredEvent _event(
  String aggregateId, {
  String eventType = 'finalized',
  String aggregateType = 'DiaryEntry',
  Map<String, Object?>? answers,
}) => StoredEvent.synthetic(
  eventId: 'e-$aggregateId',
  aggregateId: aggregateId,
  aggregateType: aggregateType,
  entryType: 'epistaxis_event',
  eventType: eventType,
  initiator: const UserInitiator('u'),
  clientTimestamp: DateTime.utc(2026, 4, 22),
  eventHash: 'hash-$aggregateId',
  data: {
    'answers': answers ?? {'x': 1},
  },
);

EntryTypeDefinition _def(String id) => EntryTypeDefinition(
  id: id,
  version: '1',
  name: id,
  widgetId: 'w',
  widgetConfig: const <String, Object?>{},
);

void main() {
  group('DiaryEntriesMaterializer Phase 4.4', () {
    // Verifies: REQ-d00140-A — viewName exposes 'diary_entries'.
    test("REQ-d00140-A: viewName is 'diary_entries'", () {
      const m = DiaryEntriesMaterializer();
      expect(m.viewName, 'diary_entries');
    });

    // Verifies: REQ-d00140-A — appliesTo gates fold on aggregateType.
    test(
      'REQ-d00140-A: appliesTo returns true for DiaryEntry; false otherwise',
      () {
        const m = DiaryEntriesMaterializer();
        expect(m.appliesTo(_event('a')), isTrue);
        expect(
          m.appliesTo(_event('b', aggregateType: 'security_context')),
          isFalse,
        );
      },
    );

    // Verifies: REQ-d00140-A — Materializer is abstract; DiaryEntriesMaterializer
    // is a concrete subclass.
    test('DiaryEntriesMaterializer extends Materializer', () {
      expect(const DiaryEntriesMaterializer(), isA<Materializer>());
    });

    // Verifies: REQ-d00140-A — applyInTxn reads prior row via the generic
    // view API and upserts the next row into the same view.
    test(
      'applyInTxn writes diary_entries view row reflecting event fold',
      () async {
        final backend = await _openBackend();
        const m = DiaryEntriesMaterializer();
        final event = _event('agg-1', answers: const {'intensity': 'severe'});
        await backend.transaction((txn) async {
          await m.applyInTxn(
            txn,
            backend,
            event: event,
            def: _def('epistaxis_event'),
            aggregateHistory: const <StoredEvent>[],
          );
        });
        final row = await backend.transaction(
          (txn) async =>
              backend.readViewRowInTxn(txn, 'diary_entries', 'agg-1'),
        );
        expect(row, isNotNull);
        expect(
          (row!['current_answers'] as Map<String, Object?>)['intensity'],
          'severe',
        );
        expect(row['is_complete'], isTrue);
        expect(row['latest_event_id'], 'e-agg-1');
        await backend.close();
      },
    );
  });
}
