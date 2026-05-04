import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

void main() {
  group('SembastBackend.watchView', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('watch-view-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00153-A — snapshot-on-subscribe is empty for an
    // unknown view.
    test(
      'REQ-d00153-A: watchView emits empty snapshot for unknown view',
      () async {
        final stream = backend.watchView('never-written');
        await expectLater(
          stream,
          emits(
            isA<List<Map<String, Object?>>>().having(
              (l) => l.length,
              'length',
              0,
            ),
          ),
        );
      },
    );

    // Verifies: REQ-d00153-A — upsert triggers a new snapshot emission.
    test('REQ-d00153-A: watchView emits a new snapshot on upsert', () async {
      final stream = backend.watchView('lights');
      final emissions = <List<Map<String, Object?>>>[];
      final sub = stream.listen(emissions.add);
      await Future<void>.delayed(Duration.zero); // initial empty snapshot

      await backend.transaction((txn) async {
        await backend.upsertViewRowInTxn(
          txn,
          'lights',
          'red',
          <String, Object?>{'color': 'red', 'is_on': true},
        );
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(
        Duration.zero,
      ); // emitSnapshot's two-microtask chain

      await sub.cancel();
      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.first, isEmpty);
      expect(emissions.last, hasLength(1));
      expect(emissions.last.first['color'], 'red');
      expect(emissions.last.first['is_on'], true);
    });

    // Verifies: REQ-d00153-A — delete triggers a new snapshot emission.
    test('REQ-d00153-A: watchView emits a new snapshot on delete', () async {
      await backend.transaction((txn) async {
        await backend.upsertViewRowInTxn(
          txn,
          'lights',
          'red',
          <String, Object?>{'color': 'red'},
        );
      });

      final stream = backend.watchView('lights');
      final emissions = <List<Map<String, Object?>>>[];
      final sub = stream.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      await backend.transaction((txn) async {
        await backend.deleteViewRowInTxn(txn, 'lights', 'red');
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.last, isEmpty);
    });

    // Verifies: REQ-d00153-A — clear triggers a new snapshot emission.
    test('REQ-d00153-A: watchView emits a new snapshot on clear', () async {
      await backend.transaction((txn) async {
        await backend.upsertViewRowInTxn(
          txn,
          'lights',
          'red',
          <String, Object?>{'color': 'red'},
        );
        await backend.upsertViewRowInTxn(
          txn,
          'lights',
          'green',
          <String, Object?>{'color': 'green'},
        );
      });

      final stream = backend.watchView('lights');
      final emissions = <List<Map<String, Object?>>>[];
      final sub = stream.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await backend.transaction((txn) async {
        await backend.clearViewInTxn(txn, 'lights');
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.first, hasLength(2));
      expect(emissions.last, isEmpty);
    });

    // Verifies: REQ-d00153-C — cross-view isolation (mutating B does not
    // emit to a watchView(A) subscriber).
    test('REQ-d00153-C: watchView is per-view (no cross-view noise)', () async {
      final streamA = backend.watchView('view-A');
      final emA = <List<Map<String, Object?>>>[];
      final sa = streamA.listen(emA.add);
      await Future<void>.delayed(Duration.zero);
      emA.clear();

      await backend.transaction((txn) async {
        await backend.upsertViewRowInTxn(txn, 'view-B', 'k1', <String, Object?>{
          'value': 1,
        });
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await sa.cancel();
      // Mutating view-B did not emit to view-A.
      expect(emA, isEmpty);
    });

    // Verifies: REQ-d00153-D — close() sends done; subsequent throws.
    test(
      'REQ-d00153-D: watchView closes on backend close, then throws',
      () async {
        final stream = backend.watchView('lights');
        final fut = expectLater(stream, emitsThrough(emitsDone));
        await backend.close();
        await fut;
        expect(() => backend.watchView('lights'), throwsStateError);
        backend = await _openBackend('watch-view-reopen-$dbCounter.db');
      },
    );
  });
}
