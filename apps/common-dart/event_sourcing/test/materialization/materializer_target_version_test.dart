import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class _M extends Materializer {
  const _M();
  @override
  String get viewName => 'm_test';
  @override
  bool appliesTo(StoredEvent event) => true;
  @override
  EntryPromoter get promoter => identityPromoter;
  @override
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required Map<String, Object?> promotedData,
    required EntryTypeDefinition def,
    required List<StoredEvent> aggregateHistory,
  }) async => throw UnimplementedError();
}

Future<SembastBackend> _b() async => SembastBackend(
  database: await newDatabaseFactoryMemory().openDatabase(
    'm-target-${DateTime.now().microsecondsSinceEpoch}.db',
  ),
);

void main() {
  group('REQ-d00140-L: targetVersionFor default impl', () {
    test('returns stored value when present', () async {
      // Verifies: REQ-d00140-L — default impl reads view_target_versions.
      final b = await _b();
      await b.transaction((txn) async {
        await b.writeViewTargetVersionInTxn(txn, 'm_test', 'demo', 7);
        const m = _M();
        expect(await m.targetVersionFor(txn, b, 'demo'), 7);
      });
    });

    test('throws StateError when no entry registered', () async {
      // Verifies: REQ-d00140-L — missing entry throws StateError naming pair.
      final b = await _b();
      await b.transaction((txn) async {
        const m = _M();
        await expectLater(
          () => m.targetVersionFor(txn, b, 'unregistered'),
          throwsStateError,
        );
      });
    });
  });
}
