import 'package:event_sourcing_datastore/src/destinations/batch_envelope_metadata.dart';
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
import 'package:event_sourcing_datastore/src/storage/fifo_entry.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fifo_entry_helpers.dart';

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

void main() {
  group('SembastBackend.watchFifo', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('watch-fifo-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00150-A — snapshot-on-subscribe is empty for an
    // unknown destination.
    test(
      'REQ-d00150-A: watchFifo emits empty snapshot for unknown destination',
      () async {
        final stream = backend.watchFifo('unknown-dest');
        await expectLater(
          stream,
          emits(isA<List<FifoEntry>>().having((l) => l.length, 'length', 0)),
        );
      },
    );

    // Verifies: REQ-d00150-A — enqueue triggers a new snapshot emission.
    test('REQ-d00150-A: watchFifo emits a new snapshot on enqueue', () async {
      final stream = backend.watchFifo('dest');
      // Buffer emissions; then enqueue.
      final emissions = <List<FifoEntry>>[];
      final sub = stream.listen(emissions.add);

      await Future<void>.delayed(Duration.zero); // initial empty snapshot
      await enqueueSingle(backend, 'dest', eventId: 'e1', sequenceNumber: 1);
      // Two pumps: one to drain the broadcast notification microtask
      // (which schedules the snapshot fetch), one for the snapshot
      // controller.add to deliver to this subscriber.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.first, isEmpty);
      expect(emissions.last, hasLength(1));
      expect(emissions.last.first.eventIds, ['e1']);
    });

    // Verifies: REQ-d00150-A — markFinal triggers a re-emission.
    test('REQ-d00150-A: watchFifo emits a snapshot on markFinal', () async {
      final entry = await enqueueSingle(
        backend,
        'dest',
        eventId: 'e1',
        sequenceNumber: 1,
      );

      final stream = backend.watchFifo('dest');
      final emissions = <List<FifoEntry>>[];
      final sub = stream.listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      await backend.markFinal('dest', entry.entryId, FinalStatus.sent);
      // Two pumps: one to drain the broadcast notification microtask,
      // one for the snapshot fetch's controller.add to deliver.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.last.first.finalStatus, FinalStatus.sent);
    });

    // Verifies: REQ-d00150-C — cross-destination isolation.
    test(
      'REQ-d00150-C: watchFifo is per-destination (no cross-destination noise)',
      () async {
        final streamA = backend.watchFifo('dest-A');
        final emA = <List<FifoEntry>>[];
        final sa = streamA.listen(emA.add);
        await Future<void>.delayed(Duration.zero);
        emA.clear();

        await enqueueSingle(
          backend,
          'dest-B',
          eventId: 'b1',
          sequenceNumber: 1,
        );
        // Two pumps so a mistakenly-wired emission would have time to
        // surface on dest-A's collector before we assert isEmpty.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        await sa.cancel();
        // Mutating dest-B did not emit to dest-A.
        expect(emA, isEmpty);
      },
    );

    // Verifies: REQ-d00150-B + REQ-d00119-K — watchFifo snapshots include
    // envelopeMetadata for native (`esd/batch@1`) rows. Confirms the
    // Phase-4.12 stream-side FifoEntry path stays in sync with the
    // Phase-4.13 storage shape: the row-typed snapshot exposes the
    // envelope identity that drain reconstructs from, and wirePayload is
    // null on the emitted entry.
    test('REQ-d00150-B + REQ-d00119-K: watchFifo emits envelopeMetadata for '
        'native rows; wirePayload is null on the snapshot', () async {
      // Enqueue a native esd/batch@1 row via the public enqueueFifo
      // nativeEnvelope: path so the row's envelope_metadata column is
      // exercised end-to-end through the watchFifo snapshot pipeline.
      final event = storedEventFixture(eventId: 'e1', sequenceNumber: 1);
      final envelope = BatchEnvelopeMetadata(
        batchFormatVersion: '1',
        batchId: 'batch-watch-1',
        senderHop: 'mobile-1',
        senderIdentifier: 'device-watch',
        senderSoftwareVersion: 'diary@1.2.3',
        sentAt: DateTime.utc(2026, 4, 25, 12),
      );

      final stream = backend.watchFifo('dest');
      final emissions = <List<FifoEntry>>[];
      final sub = stream.listen(emissions.add);
      await Future<void>.delayed(Duration.zero); // initial empty snapshot

      await backend.enqueueFifo('dest', [event], nativeEnvelope: envelope);
      // Two pumps: one to drain the broadcast notification microtask,
      // one for the snapshot fetch's controller.add to deliver.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(emissions.length, greaterThanOrEqualTo(2));
      expect(emissions.first, isEmpty);
      final snap = emissions.last;
      expect(snap, hasLength(1));
      final entry = snap.first;
      expect(entry.eventIds, ['e1']);
      expect(entry.wireFormat, BatchEnvelope.wireFormat);
      expect(
        entry.wirePayload,
        isNull,
        reason:
            'native rows MUST surface a null wirePayload on the watchFifo '
            'snapshot (REQ-d00119-B)',
      );
      expect(entry.envelopeMetadata, isNotNull);
      expect(entry.envelopeMetadata!.batchId, 'batch-watch-1');
      expect(entry.envelopeMetadata!.senderHop, 'mobile-1');
      expect(entry.envelopeMetadata!.senderIdentifier, 'device-watch');
      expect(entry.envelopeMetadata!.batchFormatVersion, '1');
    });

    // Verifies: REQ-d00150-D — close() sends done; subsequent throws.
    test(
      'REQ-d00150-D: watchFifo closes on backend close, then throws',
      () async {
        final stream = backend.watchFifo('dest');
        final fut = expectLater(stream, emitsThrough(emitsDone));
        await backend.close();
        await fut;
        expect(() => backend.watchFifo('dest'), throwsStateError);
        backend = await _openBackend('watch-fifo-reopen-$dbCounter.db');
      },
    );
  });
}
