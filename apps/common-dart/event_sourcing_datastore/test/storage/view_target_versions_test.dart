import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<SembastBackend> _backend() async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'view-target-versions-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return SembastBackend(database: db);
}

void main() {
  group('REQ-d00140-I: view_target_versions storage', () {
    test('round-trip read/write', () async {
      // Verifies: REQ-d00140-I — write then read returns the same int.
      final b = await _backend();
      await b.transaction((txn) async {
        await b.writeViewTargetVersionInTxn(
          txn,
          'diary_entries',
          'demo_note',
          3,
        );
      });
      await b.transaction((txn) async {
        expect(
          await b.readViewTargetVersionInTxn(txn, 'diary_entries', 'demo_note'),
          3,
        );
      });
      await b.close();
    });

    test('returns null for unknown (view, entry_type)', () async {
      // Verifies: REQ-d00140-I — read of unregistered key returns null
      //   (not StateError; the StateError lives in Materializer.targetVersionFor
      //   per REQ-d00140-L).
      final b = await _backend();
      await b.transaction((txn) async {
        expect(
          await b.readViewTargetVersionInTxn(txn, 'diary_entries', 'unknown'),
          isNull,
        );
      });
      await b.close();
    });

    test('readAll returns full map for one view', () async {
      // Verifies: REQ-d00140-I — readAll scopes correctly to viewName.
      final b = await _backend();
      await b.transaction((txn) async {
        await b.writeViewTargetVersionInTxn(
          txn,
          'diary_entries',
          'demo_note',
          2,
        );
        await b.writeViewTargetVersionInTxn(
          txn,
          'diary_entries',
          'epistaxis',
          5,
        );
        await b.writeViewTargetVersionInTxn(txn, 'other_view', 'demo_note', 1);
      });
      await b.transaction((txn) async {
        final map = await b.readAllViewTargetVersionsInTxn(
          txn,
          'diary_entries',
        );
        expect(map, <String, int>{'demo_note': 2, 'epistaxis': 5});
      });
      await b.close();
    });

    test('clear removes only the named view', () async {
      // Verifies: REQ-d00140-I — clear is scoped to viewName.
      final b = await _backend();
      await b.transaction((txn) async {
        await b.writeViewTargetVersionInTxn(txn, 'view_a', 'x', 1);
        await b.writeViewTargetVersionInTxn(txn, 'view_b', 'x', 2);
      });
      await b.transaction((txn) async {
        await b.clearViewTargetVersionsInTxn(txn, 'view_a');
      });
      await b.transaction((txn) async {
        expect(await b.readViewTargetVersionInTxn(txn, 'view_a', 'x'), isNull);
        expect(await b.readViewTargetVersionInTxn(txn, 'view_b', 'x'), 2);
      });
      await b.close();
    });

    test('idempotent overwrite', () async {
      // Verifies: REQ-d00140-I — repeat writes overwrite cleanly.
      final b = await _backend();
      await b.transaction((txn) async {
        await b.writeViewTargetVersionInTxn(txn, 'v', 'e', 1);
        await b.writeViewTargetVersionInTxn(txn, 'v', 'e', 1);
        await b.writeViewTargetVersionInTxn(txn, 'v', 'e', 2);
        expect(await b.readViewTargetVersionInTxn(txn, 'v', 'e'), 2);
      });
      await b.close();
    });
  });
}
