import 'package:event_sourcing_datastore/src/destinations/batch_envelope_metadata.dart';
import 'package:event_sourcing_datastore/src/ingest/batch_envelope.dart';
import 'package:event_sourcing_datastore/src/storage/attempt_result.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import '../test_support/fifo_entry_helpers.dart';

/// Test-only: set the final_status of the FIFO row at [sequenceInQueue]
/// directly in the backing Sembast store. Used to stage a `tombstoned`
/// row in tests that pre-date Phase-4.7 Task 6's `tombstoneAndRefill`
/// API — once Task 6 lands, tests can stage via the public API.
Future<void> _rawSetFinalStatus(
  SembastBackend backend,
  String destinationId, {
  required int sequenceInQueue,
  required FinalStatus status,
}) async {
  final db = backend.databaseForTesting;
  final store = StoreRef<int, Map<String, Object?>>('fifo_$destinationId');
  final current = await store.record(sequenceInQueue).get(db);
  if (current == null) {
    throw StateError(
      '_rawSetFinalStatus: no row at sequence_in_queue=$sequenceInQueue '
      'in fifo_$destinationId',
    );
  }
  final updated = Map<String, Object?>.from(current);
  updated['final_status'] = status.toJson();
  await store.record(sequenceInQueue).put(db, updated);
}

void main() {
  group('SembastBackend FIFO', () {
    late SembastBackend backend;
    var pathCounter = 0;

    setUp(() async {
      pathCounter += 1;
      final db = await newDatabaseFactoryMemory().openDatabase(
        'fifo-$pathCounter.db',
      );
      backend = SembastBackend(database: db);
    });

    tearDown(() async {
      await backend.close();
    });

    // Phase-4.7 Task 6.5 shifted `entry_id` from a derivation of the
    // event log (`batch.first.eventId`) to a freshly-minted v4 UUID at
    // enqueue time. So a single-event test like "enqueue eventId=ev-1
    // at seq=1" still produces event_ids == ['ev-1'], but the row's
    // entry_id is an opaque UUID unrelated to 'ev-1'. Tests that need
    // to look a row up later capture the returned `FifoEntry.entryId`.

    // -------- enqueueFifo + validation --------

    test('enqueueFifo + readFifoHead round-trip', () async {
      final enqueued = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      final head = await backend.readFifoHead('primary');
      expect(head, isNotNull);
      expect(head!.entryId, enqueued.entryId);
      // entry_id is a v4 UUID, not the event id.
      expect(head.entryId, isNot('e1'));
      expect(head.entryId, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(head.eventIds, ['e1']);
      expect(head.eventIdRange, (firstSeq: 1, lastSeq: 1));
      expect(head.finalStatus, isNull);
      expect(head.attempts, isEmpty);
      expect(head.sentAt, isNull);
      expect(head.sequenceInQueue, enqueued.sequenceInQueue);
    });

    // Verifies: REQ-d00128-A — an empty batch is rejected at enqueueFifo
    // rather than silently producing a zero-event row.
    test(
      'REQ-d00128-A: enqueueFifo rejects an empty batch with ArgumentError',
      () async {
        await expectLater(
          backend.enqueueFifo(
            'primary',
            const [],
            wirePayload: wirePayloadJson(const {'k': 'v'}),
          ),
          throwsArgumentError,
        );
      },
    );

    // Verifies: Task 6.5 — two enqueues with the same eventId succeed and
    // produce rows with distinct v4-UUID entry_ids. The backend mints a
    // fresh UUID per row, so there is no collision to reject.
    test('enqueueFifo assigns distinct UUID entry_ids even when the same '
        'event id is enqueued twice', () async {
      final first = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      final second = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 2,
      );
      expect(first.entryId, isNot(second.entryId));
      expect(first.eventIds, ['e1']);
      expect(second.eventIds, ['e1']);
    });

    test('two FIFOs produce independent UUID entry_ids even with the same '
        'event id', () async {
      final a = await enqueueSingle(
        backend,
        'A',
        eventId: 'shared',
        sequenceNumber: 1,
      );
      final b = await enqueueSingle(
        backend,
        'B',
        eventId: 'shared',
        sequenceNumber: 1,
      );
      expect(a.entryId, isNot(b.entryId));
      expect((await backend.readFifoHead('A'))?.entryId, a.entryId);
      expect((await backend.readFifoHead('B'))?.entryId, b.entryId);
    });

    // -------- enqueueFifoTxn — native vs 3rd-party wire-format branch --------

    // Verifies: REQ-d00119-B+K + REQ-d00152-B+E — when nativeEnvelope is
    // supplied, the row is persisted with envelope_metadata set,
    // wire_payload null, and wire_format = BatchEnvelope.wireFormat.
    test('REQ-d00119-B+K: enqueueFifo with nativeEnvelope persists '
        'envelope_metadata and nulls wire_payload', () async {
      final event = storedEventFixture(eventId: 'e1', sequenceNumber: 1);
      final envelope = BatchEnvelopeMetadata(
        batchFormatVersion: '1',
        batchId: 'batch-x',
        senderHop: 'mobile-1',
        senderIdentifier: 'device-uuid',
        senderSoftwareVersion: 'diary@1.2.3',
        sentAt: DateTime.utc(2026, 4, 25, 12),
      );
      await backend.enqueueFifo('dest', [event], nativeEnvelope: envelope);
      final head = await backend.readFifoHead('dest');
      expect(head, isNotNull);
      expect(
        head!.wirePayload,
        isNull,
        reason: 'native enqueue MUST null wire_payload (REQ-d00119-B)',
      );
      expect(head.envelopeMetadata, isNotNull);
      expect(head.envelopeMetadata!.batchId, 'batch-x');
      expect(head.envelopeMetadata!.senderHop, 'mobile-1');
      expect(head.envelopeMetadata!.senderIdentifier, 'device-uuid');
      expect(head.envelopeMetadata!.senderSoftwareVersion, 'diary@1.2.3');
      expect(head.envelopeMetadata!.batchFormatVersion, '1');
      expect(head.wireFormat, BatchEnvelope.wireFormat);
      expect(
        head.transformVersion,
        isNull,
        reason: 'native rows carry no transform_version (REQ-d00152-E)',
      );
    });

    // Verifies: REQ-d00119-B + REQ-d00152-B+E — when wirePayload is
    // supplied, the bytes are decoded into a JSON-Map wirePayload
    // (verbatim hand-back to Destination.send) and envelopeMetadata is
    // null.
    test('REQ-d00119-B: enqueueFifo with wirePayload stores '
        'wire_payload, envelope_metadata is null', () async {
      final event = storedEventFixture(eventId: 'e1', sequenceNumber: 1);
      // 3rd-party shape: a JSON Map payload encoded to UTF-8 bytes.
      final payload = wirePayloadJson(
        const <String, Object?>{'kind': 'csv-row', 'value': 42},
        contentType: 'application/json',
        transformVersion: 'json-v1',
      );
      await backend.enqueueFifo('dest', [event], wirePayload: payload);
      final head = await backend.readFifoHead('dest');
      expect(head, isNotNull);
      expect(head!.wirePayload, isNotNull);
      expect(head.wirePayload, <String, Object?>{
        'kind': 'csv-row',
        'value': 42,
      });
      expect(
        head.envelopeMetadata,
        isNull,
        reason:
            '3rd-party rows MUST NOT carry envelope_metadata (REQ-d00119-K)',
      );
      expect(head.wireFormat, 'application/json');
    });

    // Verifies: REQ-d00152-B+E — supplying both payload shapes
    // (wirePayload AND nativeEnvelope) is rejected with ArgumentError.
    test('REQ-d00152-B+E: enqueueFifo rejects supplying both wirePayload '
        'and nativeEnvelope', () async {
      final event = storedEventFixture(eventId: 'e1', sequenceNumber: 1);
      await expectLater(
        backend.enqueueFifo(
          'dest',
          [event],
          wirePayload: wirePayloadJson(const {'k': 'v'}),
          nativeEnvelope: BatchEnvelopeMetadata(
            batchFormatVersion: '1',
            batchId: 'batch-x',
            senderHop: 'mobile-1',
            senderIdentifier: 'device-uuid',
            senderSoftwareVersion: 'diary@1.2.3',
            sentAt: DateTime.utc(2026, 4, 25, 12),
          ),
        ),
        throwsArgumentError,
      );
    });

    // Verifies: REQ-d00152-B+E — supplying neither payload shape is
    // rejected with ArgumentError; the FIFO row demands one (and only
    // one) payload column to be set.
    test('REQ-d00152-B+E: enqueueFifo rejects supplying neither wirePayload '
        'nor nativeEnvelope', () async {
      final event = storedEventFixture(eventId: 'e1', sequenceNumber: 1);
      await expectLater(
        backend.enqueueFifo('dest', [event]),
        throwsArgumentError,
      );
    });

    // -------- FIFO ordering --------

    // Verifies: REQ-d00119-A — insertion order is preserved; readFifoHead
    // returns the oldest pending entry each time.
    test('REQ-d00119-A: multiple enqueues preserve insertion order', () async {
      final first = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);
      await enqueueSingle(backend, 'primary', eventId: 'e3', sequenceNumber: 3);

      final head = await backend.readFifoHead('primary');
      expect(head?.entryId, first.entryId);
      expect(head?.eventIds, ['e1']);
    });

    test('per-destination isolation', () async {
      final a = await enqueueSingle(
        backend,
        'A',
        eventId: 'a-only',
        sequenceNumber: 1,
      );
      final b = await enqueueSingle(
        backend,
        'B',
        eventId: 'b-only',
        sequenceNumber: 1,
      );

      expect((await backend.readFifoHead('A'))?.entryId, a.entryId);
      expect((await backend.readFifoHead('A'))?.eventIds, ['a-only']);
      expect((await backend.readFifoHead('B'))?.entryId, b.entryId);
      expect((await backend.readFifoHead('B'))?.eventIds, ['b-only']);
    });

    // -------- appendAttempt --------

    test('appendAttempt appends without changing final_status', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );

      final attempt = AttemptResult(
        attemptedAt: DateTime.utc(2026, 4, 22, 11),
        outcome: 'transient',
        errorMessage: 'timeout',
        httpStatus: 503,
      );
      await backend.appendAttempt('primary', e1.entryId, attempt);

      final head = await backend.readFifoHead('primary');
      expect(head?.attempts, [attempt]);
      expect(head?.finalStatus, isNull);

      // Second attempt also appends, preserving order.
      final attempt2 = AttemptResult(
        attemptedAt: DateTime.utc(2026, 4, 22, 12),
        outcome: 'transient',
        errorMessage: 'timeout',
        httpStatus: 503,
      );
      await backend.appendAttempt('primary', e1.entryId, attempt2);
      final head2 = await backend.readFifoHead('primary');
      expect(head2?.attempts, [attempt, attempt2]);
    });

    // Verifies: REQ-d00127-B — appendAttempt on a missing row is a no-op,
    // does NOT throw. Closes the drain/unjam + drain/delete race (design
    // §6.6): drain awaits send() outside a transaction, so a concurrent
    // user op may remove the target row before drain's subsequent
    // appendAttempt transaction runs.
    test(
      'REQ-d00127-B: appendAttempt no-ops when entry does not exist',
      () async {
        final e1 = await enqueueSingle(
          backend,
          'primary',
          eventId: 'e1',
          sequenceNumber: 1,
        );
        // Must not throw.
        await backend.appendAttempt(
          'primary',
          'nonexistent',
          AttemptResult(attemptedAt: DateTime.utc(2026, 4, 22), outcome: 'ok'),
        );
        // The FIFO is otherwise untouched: e1 is still pending with no
        // attempts.
        final head = await backend.readFifoHead('primary');
        expect(head?.entryId, e1.entryId);
        expect(head?.attempts, isEmpty);
      },
    );

    // Verifies: REQ-d00127-B — appendAttempt against a FIFO store that
    // was never registered (destination that never existed, or whose
    // store was destroyed) is a no-op. In Sembast a never-written store
    // has zero records, so the records.isEmpty path covers both.
    test(
      'REQ-d00127-B: appendAttempt no-ops when FIFO store does not exist',
      () async {
        // 'ghost-dest' was never enqueued to.
        await backend.appendAttempt(
          'ghost-dest',
          'any-entry',
          AttemptResult(attemptedAt: DateTime.utc(2026, 4, 22), outcome: 'ok'),
        );
        // Nothing materialized in the unknown store.
        expect(await backend.readFifoHead('ghost-dest'), isNull);
      },
    );

    // -------- markFinal --------

    // Verifies: REQ-d00119-D — markFinal does NOT delete the entry; it
    // flips final_status and, for sent, stamps sent_at. The entry lives
    // on as a send-log record.
    test('REQ-d00119-D: markFinal sent retains the entry', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);

      // After marking sent, readFifoHead moves past it to the next pending.
      expect(await backend.readFifoHead('primary'), isNull);

      // The entry persists: a follow-up appendAttempt on a different entry
      // works while e1 stays parked. We verify by querying the raw FIFO
      // via a second enqueue + head read.
      final e2 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e2',
        sequenceNumber: 2,
      );
      final nextHead = await backend.readFifoHead('primary');
      expect(nextHead?.entryId, e2.entryId);
    });

    test('markFinal sent sets sent_at', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      final before = DateTime.now().toUtc();
      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);
      final after = DateTime.now().toUtc();

      final e2 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e2',
        sequenceNumber: 2,
      );
      await backend.markFinal('primary', e2.entryId, FinalStatus.sent);

      // We can't easily query non-pending entries through readFifoHead, so
      // inspect the second e2 entry - it should have sent_at set between
      // before/after.
      final e3 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e3',
        sequenceNumber: 3,
      );
      final head = await backend.readFifoHead('primary');
      expect(head?.entryId, e3.entryId);
      // e1 and e2 are retained but not visible at head. The sent_at check
      // is validated indirectly: markFinal would have thrown if sent_at
      // wasn't being assigned, and the retain test above proves markFinal
      // preserves the entry. Direct inspection via the raw sembast
      // database (test-only accessor). The raw store name must match
      // SembastBackend._fifoStore(destinationId), which is
      // 'fifo_$destinationId'.
      final db = backend.databaseForTesting;
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      final e1Raw = raw.firstWhere((r) => r.value['entry_id'] == e1.entryId);
      final e1SentAt = DateTime.parse(e1Raw.value['sent_at']! as String);
      expect(e1SentAt.isAfter(before) || e1SentAt == before, isTrue);
      expect(e1SentAt.isBefore(after) || e1SentAt == after, isTrue);
    });

    test('markFinal exhausted does NOT set sent_at', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      await backend.markFinal('primary', e1.entryId, FinalStatus.wedged);

      // Raw store name must match SembastBackend._fifoStore(destinationId).
      final db = backend.databaseForTesting;
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      expect(raw.single.value['sent_at'], isNull);
    });

    test('after markFinal sent, readFifoHead returns next pending', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      final e2 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e2',
        sequenceNumber: 2,
      );

      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);

      final head = await backend.readFifoHead('primary');
      expect(head?.entryId, e2.entryId);
    });

    // Verifies: REQ-d00124-A — readFifoHead returns the first row in
    // sequence_in_queue order whose final_status is null (pre-terminal;
    // drain may attempt) or wedged (blocking terminal; drain halts).
    // Rows whose final_status is sent or tombstoned are terminal-passable
    // and SHALL be skipped.
    test('REQ-d00124-A: readFifoHead returns first row with finalStatus in '
        '{null, wedged} — wedged row is returned, not skipped', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      final e2 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e2',
        sequenceNumber: 2,
      );
      await enqueueSingle(backend, 'primary', eventId: 'e3', sequenceNumber: 3);

      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);
      await backend.markFinal('primary', e2.entryId, FinalStatus.wedged);
      // e3 is left pending.

      final head = await backend.readFifoHead('primary');
      expect(head, isNotNull);
      // e1 (sent) is skipped; e2 (wedged) is the first row in
      // sequence_in_queue order whose final_status is in {null, wedged}.
      expect(head!.entryId, e2.entryId);
      expect(head.finalStatus, FinalStatus.wedged);
    });

    // Verifies: REQ-d00124-A — tombstoned rows are terminal-passable and
    // SHALL be skipped. A tombstoned row at sequence_in_queue position 1
    // followed by a pending row at position 2 returns the pending row.
    test('REQ-d00124-A: readFifoHead skips tombstoned rows', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      final e2 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e2',
        sequenceNumber: 2,
      );
      // Set final_status to "tombstoned" via a direct backend mutation
      // so this test focuses on the readFifoHead skip-past contract
      // independently of tombstoneAndRefill's side effects.
      await _rawSetFinalStatus(
        backend,
        'primary',
        sequenceInQueue: 1,
        status: FinalStatus.tombstoned,
      );

      final head = await backend.readFifoHead('primary');
      expect(head, isNotNull);
      expect(head!.entryId, e2.entryId);
      expect(head.finalStatus, isNull);
    });

    // Verifies: REQ-d00124-A — when every row's final_status is a
    // terminal-passable value ({sent, tombstoned}), readFifoHead returns
    // null. This is the "FIFO has no more drain-candidates and no wedge"
    // signal; drain returns on null, and tombstoneAndRefill is not
    // applicable (no head to act on).
    test('REQ-d00124-A: readFifoHead returns null when only terminal-passable '
        'rows exist (sent and tombstoned)', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);
      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);
      await _rawSetFinalStatus(
        backend,
        'primary',
        sequenceInQueue: 2,
        status: FinalStatus.tombstoned,
      );

      expect(await backend.readFifoHead('primary'), isNull);
    });

    // Verifies: REQ-d00127-A — markFinal on a missing row is a no-op, does
    // NOT throw. Closes the drain/unjam + drain/delete race (design §6.6):
    // drain awaits send() outside a transaction, so a concurrent user op
    // may remove the target row before drain's subsequent markFinal
    // transaction runs.
    test('REQ-d00127-A: markFinal no-ops when entry does not exist', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      // Must not throw.
      await backend.markFinal('primary', 'ghost', FinalStatus.sent);
      // e1 still at head, still pending.
      final head = await backend.readFifoHead('primary');
      expect(head?.entryId, e1.entryId);
      expect(head?.finalStatus, isNull);
    });

    // Verifies: REQ-d00127-A — markFinal against a FIFO store that was
    // never registered is a no-op. In Sembast a never-written store has
    // zero records, so the records.isEmpty path covers this case too.
    test(
      'REQ-d00127-A: markFinal no-ops when FIFO store does not exist',
      () async {
        await backend.markFinal('ghost-dest', 'any-entry', FinalStatus.sent);
        expect(await backend.readFifoHead('ghost-dest'), isNull);
      },
    );

    // Verifies: drain() at-least-once semantics — a second markFinal with
    // the SAME status is a no-op (idempotent); it must NOT throw.
    // Concurrent drainers can both reach markFinal after the first one
    // succeeds; the second should observe the already-correct state and
    // return cleanly. Re-stamping of sent_at is prevented because the
    // idempotent branch returns before any write.
    test('markFinal is idempotent when called twice with the same status '
        '(pending -> sent -> sent no-op)', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);
      await expectLater(
        backend.markFinal('primary', e1.entryId, FinalStatus.sent),
        completes,
      );
    });

    test('markFinal rejects sent -> exhausted transition', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);
      await expectLater(
        backend.markFinal('primary', e1.entryId, FinalStatus.wedged),
        throwsStateError,
      );
    });

    // -------- anyFifoWedged + wedgedFifos --------

    test('anyFifoWedged true iff any FIFO is wedged', () async {
      final a1 = await enqueueSingle(
        backend,
        'A',
        eventId: 'a1',
        sequenceNumber: 1,
      );
      await enqueueSingle(backend, 'B', eventId: 'b1', sequenceNumber: 1);

      expect(await backend.anyFifoWedged(), isFalse);

      await backend.markFinal('A', a1.entryId, FinalStatus.wedged);
      expect(await backend.anyFifoWedged(), isTrue);
    });

    test('wedgedFifos returns one summary per wedged FIFO', () async {
      final a1 = await enqueueSingle(
        backend,
        'A',
        eventId: 'a1',
        sequenceNumber: 1,
      );
      await enqueueSingle(backend, 'B', eventId: 'b1', sequenceNumber: 1);
      final c1 = await enqueueSingle(
        backend,
        'C',
        eventId: 'c1',
        sequenceNumber: 1,
      );

      // Record an attempt on A's head so the summary has a lastError.
      await backend.appendAttempt(
        'A',
        a1.entryId,
        AttemptResult(
          attemptedAt: DateTime.utc(2026, 4, 22, 12, 30),
          outcome: 'permanent',
          errorMessage: 'HTTP 400: bad request',
          httpStatus: 400,
        ),
      );
      await backend.markFinal('A', a1.entryId, FinalStatus.wedged);
      await backend.markFinal('C', c1.entryId, FinalStatus.wedged);

      final summaries = await backend.wedgedFifos();
      final byDest = {for (final s in summaries) s.destinationId: s};
      expect(byDest.keys.toSet(), {'A', 'C'});
      // The summary reports the row's UUID entry_id (opaque) and the
      // first event_id of the batch; under Task 6.5 these are distinct
      // — the event_id reflects what was enqueued, the entry_id is a
      // freshly-minted UUID.
      expect(byDest['A']!.headEntryId, a1.entryId);
      expect(byDest['A']!.headEventId, 'a1');
      expect(byDest['A']!.lastError, 'HTTP 400: bad request');
      expect(byDest['A']!.wedgedAt, DateTime.utc(2026, 4, 22, 12, 30));
    });

    test('wedgedFifos returns empty when nothing is wedged', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      expect(await backend.wedgedFifos(), isEmpty);
    });

    test('wedgedFifos reports sensible fallbacks when wedged with no '
        'attempts', () async {
      final bare = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e-bare',
        sequenceNumber: 1,
      );
      await backend.markFinal('primary', bare.entryId, FinalStatus.wedged);

      final summary = (await backend.wedgedFifos()).single;
      expect(summary.destinationId, 'primary');
      expect(summary.headEntryId, bare.entryId);
      expect(summary.headEventId, 'e-bare');
      expect(summary.lastError, contains('no attempts'));
    });

    test('a FIFO with only sent entries is NOT wedged', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);
      expect(await backend.anyFifoWedged(), isFalse);
      expect(await backend.wedgedFifos(), isEmpty);
    });

    // -------- Phase-2 Prereq A, Option 1: backend-owned sequence_in_queue --

    // Verifies that the backend assigns sequence_in_queue monotonically
    // starting at 1, regardless of any caller-side sequencing concerns.
    // Task-6's new signature no longer accepts a caller-supplied
    // sequence_in_queue at all (the backend constructs the FifoEntry), so
    // this test collapses from "caller supplies nonsense; backend
    // overwrites" to "backend assigns 1, 2, 3 monotonically".
    test('enqueueFifo assigns its own monotonic sequence_in_queue '
        '(Prereq A, Option 1)', () async {
      final r1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      final r2 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e2',
        sequenceNumber: 2,
      );
      final r3 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e3',
        sequenceNumber: 3,
      );

      // Inspect the raw store to verify the stored sequence_in_queue
      // values are 1, 2, 3.
      final db = backend.databaseForTesting;
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      expect(raw.map((r) => r.value['sequence_in_queue']).toList(), [1, 2, 3]);
      // entry_ids are the freshly-minted UUIDs from enqueueFifo, and the
      // event_ids are the caller's event log identifiers.
      expect(raw.map((r) => r.value['entry_id']).toList(), [
        r1.entryId,
        r2.entryId,
        r3.entryId,
      ]);
      expect(raw.map((r) => r.value['event_ids']).toList(), [
        ['e1'],
        ['e2'],
        ['e3'],
      ]);
    });

    // Verifies that sequence_in_queue continues to grow past surviving
    // sent/exhausted entries — the backend's max-key+1 algorithm must not
    // re-use a slot vacated by a terminal-state entry (entries are
    // retained forever per REQ-d00119-D).
    test('sequence_in_queue advances across sent/exhausted entries '
        '(Prereq A, Option 1)', () async {
      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);
      final e2 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e2',
        sequenceNumber: 2,
      );
      // e2 should get sequence 2, not 1.
      final db = backend.databaseForTesting;
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      final e2Raw = raw.firstWhere((r) => r.value['entry_id'] == e2.entryId);
      expect(e2Raw.value['sequence_in_queue'], 2);
      expect(e2Raw.key, 2);
    });

    // Verifies that the Sembast int key equals the payload's
    // sequence_in_queue (they are in lockstep by design).
    test('sequence_in_queue equals the Sembast store key (lockstep)', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);

      final db = backend.databaseForTesting;
      final raw = await StoreRef<int, Map<String, Object?>>(
        'fifo_primary',
      ).find(db);
      for (final record in raw) {
        expect(record.value['sequence_in_queue'], record.key);
      }
    });

    // Verifies: REQ-d00119-E — sequence_in_queue is monotonic per
    // destination and NEVER reused. Even when a row is deleted from the
    // underlying Sembast store (as the REQ-d00144-C trail sweep will
    // do), a subsequent enqueue must NOT re-use the deleted row's
    // sequence_in_queue value. This test performs a raw `store.delete`
    // bypassing the backend API to simulate the deletion path, then
    // verifies the next enqueue picks up the next never-seen value
    // rather than refilling the vacated slot.
    test('REQ-d00119-E: sequence_in_queue is monotonic per destination, '
        'never reused', () async {
      await enqueueSingle(backend, 'primary', eventId: 'e1', sequenceNumber: 1);
      await enqueueSingle(backend, 'primary', eventId: 'e2', sequenceNumber: 2);
      await enqueueSingle(backend, 'primary', eventId: 'e3', sequenceNumber: 3);

      final db = backend.databaseForTesting;
      final store = StoreRef<int, Map<String, Object?>>('fifo_primary');
      final before = await store.find(db);
      expect(before.map((r) => r.value['sequence_in_queue']).toList(), [
        1,
        2,
        3,
      ]);

      // Raw delete of row whose sequence_in_queue is 2 (the e2 row).
      // This simulates the REQ-d00144-C trail-sweep deletion path
      // without depending on that API (which is introduced in Task 6).
      await store.record(2).delete(db);

      final afterDelete = await store.find(db);
      expect(afterDelete.map((r) => r.value['sequence_in_queue']).toList(), [
        1,
        3,
      ]);

      // Fourth enqueue MUST get sequence_in_queue 4 — NOT 2 (the
      // deleted slot) and NOT 3 (max-key after delete + 1 under the
      // old derivation would also be 4, but only because 3 already
      // exists; the defining test is the next-next one below).
      final e4 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e4',
        sequenceNumber: 4,
      );
      final afterFirstEnqueue = await store.find(db);
      final e4Record = afterFirstEnqueue.firstWhere(
        (r) => r.value['entry_id'] == e4.entryId,
      );
      expect(e4Record.value['sequence_in_queue'], 4);
      expect(e4Record.key, 4);

      // Now delete row 4 (the row we just inserted, currently the
      // max-key row). Under a buggy "max(existing key) + 1"
      // derivation, the next enqueue would assign 4 again — reusing
      // the slot. The persisted counter prevents that: the next
      // enqueue must get 5.
      await store.record(4).delete(db);
      final e5 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e5',
        sequenceNumber: 5,
      );
      final afterSecondEnqueue = await store.find(db);
      final e5Record = afterSecondEnqueue.firstWhere(
        (r) => r.value['entry_id'] == e5.entryId,
      );
      expect(e5Record.value['sequence_in_queue'], 5);
      expect(e5Record.key, 5);
    });

    // -------- REQ-d00127-C: warning log on missing-row no-op --------

    // Verifies: REQ-d00127-C — both markFinal and appendAttempt emit a
    // warning-level diagnostic that names the method, the entry id, and
    // the destination id when they no-op due to a missing target. Tests
    // install a capture closure via debugLogSink so the assertion doesn't
    // depend on any global logger.
    test('REQ-d00127-C: markFinal emits a warning that names method, '
        'entry id, and destination id when it no-ops', () async {
      final logs = <String>[];
      backend.debugLogSink = logs.add;

      await backend.markFinal('primary', 'ghost', FinalStatus.sent);

      expect(logs, hasLength(1));
      final line = logs.single;
      expect(line, contains('markFinal'));
      expect(line, contains('ghost'));
      expect(line, contains('primary'));
      expect(line, contains('drain/unjam'));
      expect(line, contains('drain/delete'));
    });

    test('REQ-d00127-C: appendAttempt emits a warning that names method, '
        'entry id, and destination id when it no-ops', () async {
      final logs = <String>[];
      backend.debugLogSink = logs.add;

      await backend.appendAttempt(
        'primary',
        'ghost',
        AttemptResult(attemptedAt: DateTime.utc(2026, 4, 22), outcome: 'ok'),
      );

      expect(logs, hasLength(1));
      final line = logs.single;
      expect(line, contains('appendAttempt'));
      expect(line, contains('ghost'));
      expect(line, contains('primary'));
      expect(line, contains('drain/unjam'));
      expect(line, contains('drain/delete'));
    });

    // Verifies: REQ-d00127-C — the warning is NOT emitted on a successful
    // happy-path call. Prevents a future regression where a code change
    // flipped the no-op branch in both directions.
    test('REQ-d00127-C: no warning is emitted on a happy-path markFinal / '
        'appendAttempt', () async {
      final logs = <String>[];
      backend.debugLogSink = logs.add;

      final e1 = await enqueueSingle(
        backend,
        'primary',
        eventId: 'e1',
        sequenceNumber: 1,
      );
      await backend.appendAttempt(
        'primary',
        e1.entryId,
        AttemptResult(attemptedAt: DateTime.utc(2026, 4, 22), outcome: 'ok'),
      );
      await backend.markFinal('primary', e1.entryId, FinalStatus.sent);

      expect(logs, isEmpty);
    });

    // -------- fill_cursor (REQ-d00128-G) --------

    // Verifies: REQ-d00128-G — readFillCursor returns -1 when no cursor has
    // ever been written for the destination, signalling "no row has yet been
    // enqueued into this FIFO".
    test('REQ-d00128-G: readFillCursor returns -1 when unset', () async {
      expect(await backend.readFillCursor('primary'), -1);
    });

    // Verifies: REQ-d00128-G — writeFillCursor persists the value under
    // backend_state/fill_cursor_<destId>; readFillCursor observes it.
    test(
      'REQ-d00128-G: writeFillCursor then readFillCursor round-trips',
      () async {
        await backend.writeFillCursor('primary', 42);
        expect(await backend.readFillCursor('primary'), 42);

        // A second write replaces the prior value (monotonic advance is
        // caller policy; the backend contract just stores what it's given).
        await backend.writeFillCursor('primary', 100);
        expect(await backend.readFillCursor('primary'), 100);
      },
    );

    // Verifies: REQ-d00128-G — the transactional writeFillCursorTxn variant
    // participates in the surrounding transaction's atomicity. If the
    // transaction body throws, the cursor write rolls back with everything
    // else and readFillCursor still returns the pre-transaction value.
    test('REQ-d00128-G: writeFillCursor inside a transaction participates in '
        'atomicity (rollback confirms cursor was NOT advanced)', () async {
      // Pre-transaction baseline.
      await backend.writeFillCursor('primary', 7);
      expect(await backend.readFillCursor('primary'), 7);

      await expectLater(
        backend.transaction((txn) async {
          await backend.writeFillCursorTxn(txn, 'primary', 99);
          throw StateError('simulated failure');
        }),
        throwsStateError,
      );

      // Rollback: cursor is still the pre-transaction value (7), NOT 99.
      expect(await backend.readFillCursor('primary'), 7);

      // And on commit, the value IS advanced.
      await backend.transaction((txn) async {
        await backend.writeFillCursorTxn(txn, 'primary', 55);
      });
      expect(await backend.readFillCursor('primary'), 55);
    });

    // Verifies: REQ-d00128-G — the fill_cursor is per-destination; writes to
    // one destination's cursor do NOT change another destination's cursor.
    test('REQ-d00128-G: fill_cursor is per-destination (two destinations have '
        'independent cursors)', () async {
      expect(await backend.readFillCursor('primary'), -1);
      expect(await backend.readFillCursor('secondary'), -1);

      await backend.writeFillCursor('primary', 10);
      expect(await backend.readFillCursor('primary'), 10);
      // secondary is untouched.
      expect(await backend.readFillCursor('secondary'), -1);

      await backend.writeFillCursor('secondary', 22);
      expect(await backend.readFillCursor('secondary'), 22);
      // primary is unchanged.
      expect(await backend.readFillCursor('primary'), 10);
    });

    // Verifies: REQ-d00128-G — writeFillCursor rejects negative values
    // smaller than the -1 sentinel so a bogus caller cannot store a value
    // outside the fill_cursor's legal domain of [-1, infinity).
    test('REQ-d00128-G: writeFillCursor rejects sequenceNumber < -1', () async {
      await expectLater(
        backend.writeFillCursor('primary', -2),
        throwsArgumentError,
      );
      // The failed write left the cursor unchanged.
      expect(await backend.readFillCursor('primary'), -1);
    });
  });

  group('listFifoEntries', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      final db = await newDatabaseFactoryMemory().openDatabase(
        'list-fifo-$dbCounter.db',
      );
      backend = SembastBackend(database: db);
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00148-A — empty FIFO returns an empty list (no throw).
    test(
      'REQ-d00148-A: listFifoEntries on unknown destination returns empty list',
      () async {
        final result = await backend.listFifoEntries('never-registered');
        expect(result, isEmpty);
      },
    );

    // Verifies: REQ-d00148-A+C — entries returned in sequence_in_queue order
    // with all FifoEntry fields populated (entryId, eventIds, sequenceInQueue
    // — populated by enqueueSingle through the existing enqueueFifo path).
    test(
      'REQ-d00148-A+C: listFifoEntries returns entries ordered by sequence_in_queue',
      () async {
        final r1 = await enqueueSingle(
          backend,
          'dest',
          eventId: 'e1',
          sequenceNumber: 1,
        );
        final r2 = await enqueueSingle(
          backend,
          'dest',
          eventId: 'e2',
          sequenceNumber: 2,
        );
        final r3 = await enqueueSingle(
          backend,
          'dest',
          eventId: 'e3',
          sequenceNumber: 3,
        );
        final result = await backend.listFifoEntries('dest');
        expect(result, hasLength(3));
        // Ordered ascending by sequence_in_queue.
        expect(result[0].sequenceInQueue < result[1].sequenceInQueue, isTrue);
        expect(result[1].sequenceInQueue < result[2].sequenceInQueue, isTrue);
        // Each row carries the event_ids it was enqueued with.
        expect(result[0].eventIds, ['e1']);
        expect(result[1].eventIds, ['e2']);
        expect(result[2].eventIds, ['e3']);
        // Each row carries the entry_id minted at enqueue.
        expect(result[0].entryId, r1.entryId);
        expect(result[1].entryId, r2.entryId);
        expect(result[2].entryId, r3.entryId);
      },
    );

    // Verifies: REQ-d00148-B — afterSequenceInQueue is exclusive.
    test(
      'REQ-d00148-B: listFifoEntries afterSequenceInQueue is exclusive',
      () async {
        for (var i = 1; i <= 4; i++) {
          await enqueueSingle(
            backend,
            'dest',
            eventId: 'e$i',
            sequenceNumber: i,
          );
        }
        final all = await backend.listFifoEntries('dest');
        expect(all, hasLength(4));
        final secondRow = all[1];
        final after = await backend.listFifoEntries(
          'dest',
          afterSequenceInQueue: secondRow.sequenceInQueue,
        );
        // Exclusive: rows 3 and 4 only.
        expect(after, hasLength(2));
        expect(after.first.sequenceInQueue > secondRow.sequenceInQueue, isTrue);
      },
    );

    // Verifies: REQ-d00148-B — limit caps the returned list size, taken
    // from the start of the ordered range.
    test('REQ-d00148-B: listFifoEntries limit caps result size', () async {
      for (var i = 1; i <= 5; i++) {
        await enqueueSingle(backend, 'dest', eventId: 'e$i', sequenceNumber: i);
      }
      final two = await backend.listFifoEntries('dest', limit: 2);
      expect(two, hasLength(2));
      // Limit is taken from the start of the ordered range.
      expect(two[0].eventIds, ['e1']);
      expect(two[1].eventIds, ['e2']);
    });
  });
}
