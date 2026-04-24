import 'package:event_sourcing_datastore/src/storage/diary_entry.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  group('SembastBackend diary_entries', () {
    late SembastBackend backend;
    var pathCounter = 0;

    setUp(() async {
      pathCounter += 1;
      final db = await newDatabaseFactoryMemory().openDatabase(
        'entries-$pathCounter.db',
      );
      backend = SembastBackend(database: db);
    });

    tearDown(() async {
      await backend.close();
    });

    DiaryEntry make({
      String entryId = 'e1',
      String entryType = 'epistaxis_event',
      DateTime? effectiveDate,
      Map<String, Object?> currentAnswers = const <String, Object?>{},
      bool isComplete = false,
      bool isDeleted = false,
      String latestEventId = 'ev-1',
      DateTime? updatedAt,
    }) {
      return DiaryEntry(
        entryId: entryId,
        entryType: entryType,
        effectiveDate: effectiveDate,
        currentAnswers: currentAnswers,
        isComplete: isComplete,
        isDeleted: isDeleted,
        latestEventId: latestEventId,
        updatedAt: updatedAt ?? DateTime.utc(2026, 4, 22, 12),
      );
    }

    test(
      'upsertEntry persists a new entry; findEntries reads it back',
      () async {
        final e = make();
        await backend.transaction((txn) async {
          await backend.upsertEntry(txn, e);
        });
        final found = await backend.findEntries();
        expect(found.length, 1);
        expect(found.single, equals(e));
      },
    );

    // Verifies: REQ-d00117-D — whole-row replace, not partial merge. A
    // second upsert with a different shape replaces the first one; fields
    // present only in the first write SHALL NOT survive.
    test('REQ-d00117-D: upsertEntry is whole-row replace', () async {
      final first = make(
        currentAnswers: <String, Object?>{'intensity': 'mild', 'notes': 'n1'},
        isComplete: false,
      );
      final second = make(
        currentAnswers: <String, Object?>{'intensity': 'severe'},
        isComplete: true,
      );
      await backend.transaction((txn) async {
        await backend.upsertEntry(txn, first);
      });
      await backend.transaction((txn) async {
        await backend.upsertEntry(txn, second);
      });

      final rows = await backend.findEntries();
      expect(rows.length, 1);
      final row = rows.single;
      expect(row.currentAnswers['intensity'], 'severe');
      // The old 'notes' key from the first write must NOT leak through.
      expect(row.currentAnswers.containsKey('notes'), isFalse);
      expect(row.isComplete, isTrue);
    });

    test('findEntries(entryType) filters by type', () async {
      await backend.transaction((txn) async {
        await backend.upsertEntry(
          txn,
          make(entryId: 'a', entryType: 'epistaxis_event'),
        );
        await backend.upsertEntry(
          txn,
          make(entryId: 'b', entryType: 'nose_hht_survey'),
        );
        await backend.upsertEntry(
          txn,
          make(entryId: 'c', entryType: 'hht_qol_survey'),
        );
      });

      final epistaxis = await backend.findEntries(entryType: 'epistaxis_event');
      expect(epistaxis.map((e) => e.entryId).toSet(), {'a'});
      final hht = await backend.findEntries(entryType: 'nose_hht_survey');
      expect(hht.map((e) => e.entryId).toSet(), {'b'});
    });

    test('findEntries(isComplete) and findEntries(isDeleted) filter', () async {
      await backend.transaction((txn) async {
        await backend.upsertEntry(
          txn,
          make(entryId: 'a', isComplete: false, isDeleted: false),
        );
        await backend.upsertEntry(
          txn,
          make(entryId: 'b', isComplete: true, isDeleted: false),
        );
        await backend.upsertEntry(
          txn,
          make(entryId: 'c', isComplete: false, isDeleted: true),
        );
      });

      expect(
        (await backend.findEntries(
          isComplete: true,
        )).map((e) => e.entryId).toSet(),
        {'b'},
      );
      expect(
        (await backend.findEntries(
          isComplete: false,
        )).map((e) => e.entryId).toSet(),
        {'a', 'c'},
      );
      expect(
        (await backend.findEntries(
          isDeleted: true,
        )).map((e) => e.entryId).toSet(),
        {'c'},
      );
      expect(
        (await backend.findEntries(
          isDeleted: false,
        )).map((e) => e.entryId).toSet(),
        {'a', 'b'},
      );
    });

    test('findEntries(dateFrom, dateTo) filters by effective_date', () async {
      final jan = DateTime.utc(2026, 1, 15);
      final mar = DateTime.utc(2026, 3, 15);
      final may = DateTime.utc(2026, 5, 15);

      await backend.transaction((txn) async {
        await backend.upsertEntry(
          txn,
          make(entryId: 'jan', effectiveDate: jan),
        );
        await backend.upsertEntry(
          txn,
          make(entryId: 'mar', effectiveDate: mar),
        );
        await backend.upsertEntry(
          txn,
          make(entryId: 'may', effectiveDate: may),
        );
        await backend.upsertEntry(
          txn,
          make(entryId: 'nul', effectiveDate: null),
        );
      });

      // dateFrom-only
      expect(
        (await backend.findEntries(
          dateFrom: DateTime.utc(2026, 2, 1),
        )).map((e) => e.entryId).toSet(),
        {'mar', 'may'},
      );
      // dateTo-only: null effective_date excluded here too.
      final dateToResult = await backend.findEntries(
        dateTo: DateTime.utc(2026, 4, 1),
      );
      expect(dateToResult.map((e) => e.entryId).toSet(), {'jan', 'mar'});
      expect(dateToResult.map((e) => e.entryId).contains('nul'), isFalse);
      // both
      expect(
        (await backend.findEntries(
          dateFrom: DateTime.utc(2026, 2, 1),
          dateTo: DateTime.utc(2026, 4, 1),
        )).map((e) => e.entryId).toSet(),
        {'mar'},
      );
      // null effective_date is excluded from date-range queries
      expect(
        (await backend.findEntries(
          dateFrom: DateTime.utc(1970, 1, 1),
        )).map((e) => e.entryId).contains('nul'),
        isFalse,
      );
    });

    test('findEntries filters combine with logical AND', () async {
      await backend.transaction((txn) async {
        await backend.upsertEntry(
          txn,
          make(
            entryId: 'epi-complete',
            entryType: 'epistaxis_event',
            isComplete: true,
          ),
        );
        await backend.upsertEntry(
          txn,
          make(
            entryId: 'epi-incomplete',
            entryType: 'epistaxis_event',
            isComplete: false,
          ),
        );
        await backend.upsertEntry(
          txn,
          make(
            entryId: 'survey-complete',
            entryType: 'nose_hht_survey',
            isComplete: true,
          ),
        );
      });

      final result = await backend.findEntries(
        entryType: 'epistaxis_event',
        isComplete: true,
      );
      expect(result.map((e) => e.entryId).toSet(), {'epi-complete'});
    });
  });
}
