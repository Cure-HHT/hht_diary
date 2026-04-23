import 'package:append_only_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<SembastBackend> _backend(String tag) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'views-$tag-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  return SembastBackend(database: db);
}

void main() {
  group('REQ-d00140-F: generic view storage on StorageBackend', () {
    test('readViewRowInTxn on missing key returns null', () async {
      final b = await _backend('missing');
      final row = await b.transaction(
        (txn) async => b.readViewRowInTxn(txn, 'test_view', 'missing'),
      );
      expect(row, isNull);
      await b.close();
    });

    test('upsert then read round-trips', () async {
      final b = await _backend('upsert');
      await b.transaction((txn) async {
        await b.upsertViewRowInTxn(txn, 'test_view', 'k1', {'a': 1, 'b': 's'});
      });
      final row = await b.transaction(
        (txn) async => b.readViewRowInTxn(txn, 'test_view', 'k1'),
      );
      expect(row, {'a': 1, 'b': 's'});
      await b.close();
    });

    test('delete removes the row; read-after-delete returns null', () async {
      final b = await _backend('delete');
      await b.transaction((txn) async {
        await b.upsertViewRowInTxn(txn, 'test_view', 'k', {'x': 1});
        await b.deleteViewRowInTxn(txn, 'test_view', 'k');
      });
      final row = await b.transaction(
        (txn) async => b.readViewRowInTxn(txn, 'test_view', 'k'),
      );
      expect(row, isNull);
      await b.close();
    });

    test('findViewRows iterates with limit and offset', () async {
      final b = await _backend('find');
      await b.transaction((txn) async {
        for (var i = 0; i < 5; i++) {
          await b.upsertViewRowInTxn(txn, 'v', 'k$i', {'i': i});
        }
      });
      final all = await b.findViewRows('v');
      expect(all, hasLength(5));
      final two = await b.findViewRows('v', limit: 2);
      expect(two, hasLength(2));
      final skip2 = await b.findViewRows('v', limit: 100, offset: 2);
      expect(skip2, hasLength(3));
      await b.close();
    });

    test('clearViewInTxn empties one view without touching others', () async {
      final b = await _backend('clear');
      await b.transaction((txn) async {
        await b.upsertViewRowInTxn(txn, 'a', 'k', {'x': 1});
        await b.upsertViewRowInTxn(txn, 'b', 'k', {'y': 2});
        await b.clearViewInTxn(txn, 'a');
      });
      expect(await b.findViewRows('a'), isEmpty);
      expect(await b.findViewRows('b'), hasLength(1));
      await b.close();
    });

    test('viewName isolation: writing to "a" never affects "b"', () async {
      final b = await _backend('isolation');
      await b.transaction((txn) async {
        await b.upsertViewRowInTxn(txn, 'a', 'k', {'src': 'a'});
        await b.upsertViewRowInTxn(txn, 'b', 'k', {'src': 'b'});
      });
      final a = await b.transaction(
        (txn) async => b.readViewRowInTxn(txn, 'a', 'k'),
      );
      final bb = await b.transaction(
        (txn) async => b.readViewRowInTxn(txn, 'b', 'k'),
      );
      expect(a, {'src': 'a'});
      expect(bb, {'src': 'b'});
      await b.close();
    });
  });
}
