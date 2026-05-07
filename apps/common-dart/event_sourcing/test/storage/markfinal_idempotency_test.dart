// IMPLEMENTS REQUIREMENTS:
//   REQ-d00119-D: one-way final_status transition (null -> terminal)
//   REQ-d00127-A: markFinal no-op on missing row / missing FIFO store

import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fifo_entry_helpers.dart';

void main() {
  group('markFinal idempotency', () {
    late SembastBackend backend;
    var pathCounter = 0;

    setUp(() async {
      pathCounter += 1;
      final db = await newDatabaseFactoryMemory().openDatabase(
        'markfinal-idempotency-$pathCounter.db',
      );
      backend = SembastBackend(database: db);
    });

    tearDown(() async {
      await backend.close();
    });

    // Case 1 — regression: happy-path (pending -> sent) still works.
    test(
      'markFinal sent on a pending row succeeds and row becomes sent',
      () async {
        final e1 = await enqueueSingle(
          backend,
          'primary',
          eventId: 'e1',
          sequenceNumber: 1,
        );
        await backend.markFinal('primary', e1.entryId, FinalStatus.sent);
        // After markFinal the pending queue is empty (sent rows are skipped
        // by readFifoHead). Verify directly via listFifoEntries.
        final all = await backend.listFifoEntries('primary');
        expect(all, hasLength(1));
        expect(all.single.finalStatus, FinalStatus.sent);
      },
    );

    // Case 2 — idempotency: calling markFinal(sent) twice is a no-op on
    // the second call when the requested status matches the already-final
    // status. The drain() contract is at-least-once; concurrent drainers
    // can both reach markFinal after the first completes.
    test('markFinal sent twice on the same row returns cleanly '
        '(no throw, row stays sent)', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);
      // Second call with the same status must NOT throw.
      await expectLater(
        backend.markFinal('primary', e1.entryId, FinalStatus.sent),
        completes,
      );
      // Row remains in sent state.
      final all = await backend.listFifoEntries('primary');
      expect(all, hasLength(1));
      expect(all.single.finalStatus, FinalStatus.sent);
    });

    // Case 3 — status mismatch is still an error: already-sent, asked to
    // mark failed (wedged) → StateError with both statuses in the message.
    test('markFinal sent then markFinal wedged throws StateError '
        'naming both statuses', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);
      await expectLater(
        () async =>
            backend.markFinal('primary', e1.entryId, FinalStatus.wedged),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('sent'), contains('wedged')),
          ),
        ),
      );
    });
  });
}
