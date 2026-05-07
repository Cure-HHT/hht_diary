import 'dart:async';

import 'package:event_sourcing_datastore/src/destinations/batch_envelope_metadata.dart';
import 'package:event_sourcing_datastore/src/destinations/destination_schedule.dart';
import 'package:event_sourcing_datastore/src/destinations/wire_payload.dart';
import 'package:event_sourcing_datastore/src/entry_service.dart';
import 'package:event_sourcing_datastore/src/entry_type_definition.dart';
import 'package:event_sourcing_datastore/src/entry_type_registry.dart';
import 'package:event_sourcing_datastore/src/security/security_context_store.dart';
import 'package:event_sourcing_datastore/src/storage/append_result.dart';
import 'package:event_sourcing_datastore/src/storage/attempt_result.dart';
import 'package:event_sourcing_datastore/src/storage/diary_entry.dart';
import 'package:event_sourcing_datastore/src/storage/fifo_entry.dart';
import 'package:event_sourcing_datastore/src/storage/final_status.dart';
import 'package:event_sourcing_datastore/src/storage/initiator.dart';
import 'package:event_sourcing_datastore/src/storage/sembast_backend.dart';
import 'package:event_sourcing_datastore/src/storage/storage_backend.dart';
import 'package:event_sourcing_datastore/src/storage/stored_event.dart';
import 'package:event_sourcing_datastore/src/storage/txn.dart';
import 'package:event_sourcing_datastore/src/storage/wedged_fifo_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

/// Fixture bundling the collaborators `EntryService.record` needs plus
/// a `syncCalls` list the test's sync trigger appends to on every
/// invocation (backs REQ-d00133-G's fire-and-forget assertions).
class _Fixture {
  _Fixture({
    required this.service,
    required this.backend,
    required this.entryTypes,
    required this.syncCalls,
  });

  final EntryService service;
  final SembastBackend backend;
  final EntryTypeRegistry entryTypes;
  final List<DateTime> syncCalls;
}

EntryTypeDefinition _defFor(String id, {String? effectiveDatePath}) =>
    EntryTypeDefinition(
      id: id,
      registeredVersion: 1,
      name: id,
      widgetId: 'widget-$id',
      widgetConfig: const <String, Object?>{},
      effectiveDatePath: effectiveDatePath,
    );

Future<_Fixture> _setupFixture({
  List<EntryTypeDefinition>? definitions,
  DateTime? now,
}) async {
  final db = await newDatabaseFactoryMemory().openDatabase(
    'entry-service-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final backend = SembastBackend(database: db);
  final registry = EntryTypeRegistry();
  for (final def in definitions ?? [_defFor('epistaxis_event')]) {
    registry.register(def);
  }
  final syncCalls = <DateTime>[];
  final service = EntryService(
    backend: backend,
    entryTypes: registry,
    syncCycleTrigger: () async {
      syncCalls.add(DateTime.now());
    },
    deviceInfo: const DeviceInfo(
      deviceId: 'device-1',
      softwareVersion: 'clinical_diary@1.2.3+4',
      userId: 'user-1',
    ),
    clock: now == null ? null : () => now,
  );
  return _Fixture(
    service: service,
    backend: backend,
    entryTypes: registry,
    syncCalls: syncCalls,
  );
}

void main() {
  group('EntryService.record', () {
    // Verifies: REQ-d00133-C — unknown eventType rejected with
    // ArgumentError before any I/O. The event log and diary_entries
    // both remain empty; no sync trigger fires.
    test(
      'REQ-d00133-C: unknown eventType rejected with ArgumentError before I/O',
      () async {
        final fx = await _setupFixture();
        await expectLater(
          fx.service.record(
            entryType: 'epistaxis_event',
            aggregateId: 'agg-1',
            eventType: 'NosebleedRecorded', // legacy shape, now illegal
            answers: const <String, Object?>{'severity': 'mild'},
          ),
          throwsArgumentError,
        );
        final events = await fx.backend.findAllEvents();
        expect(events, isEmpty);
        final entries = await fx.backend.findEntries();
        expect(entries, isEmpty);
        expect(fx.syncCalls, isEmpty);
        await fx.backend.close();
      },
    );

    // Verifies: REQ-d00133-H — unregistered entryType rejected with
    // ArgumentError before any I/O.
    test('REQ-d00133-H: unregistered entryType rejected with ArgumentError '
        'before I/O', () async {
      final fx = await _setupFixture(definitions: [_defFor('epistaxis_event')]);
      await expectLater(
        fx.service.record(
          entryType: 'weather_report', // not registered
          aggregateId: 'agg-1',
          eventType: 'finalized',
          answers: const <String, Object?>{'intensity': 'severe'},
        ),
        throwsArgumentError,
      );
      final events = await fx.backend.findAllEvents();
      expect(events, isEmpty);
      expect(fx.syncCalls, isEmpty);
      await fx.backend.close();
    });

    // Verifies: REQ-d00133-B — record assigns event_id, sequence_number,
    // previous_event_hash, event_hash, and the first ProvenanceEntry
    // atomically. Empty log -> seq=1 and previous_event_hash=null; a
    // second append chains forward via previous_event_hash==first.eventHash.
    test('REQ-d00133-B: record assigns event_id, sequence_number, hashes, and '
        'first ProvenanceEntry atomically', () async {
      final fx = await _setupFixture();
      final first = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'finalized',
        answers: const <String, Object?>{'severity': 'mild'},
      );
      expect(first, isNotNull);
      expect(first!.eventId, isNotEmpty);
      expect(first.sequenceNumber, 1);
      expect(first.previousEventHash, isNull);
      expect(first.eventHash, isNotEmpty);
      final prov0 =
          (first.metadata['provenance'] as List)[0] as Map<String, Object?>;
      expect(prov0['hop'], 'mobile-device');
      expect(prov0['identifier'], 'device-1');
      expect(prov0['software_version'], 'clinical_diary@1.2.3+4');

      final second = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-2',
        eventType: 'finalized',
        answers: const <String, Object?>{'severity': 'severe'},
      );
      expect(second, isNotNull);
      expect(second!.sequenceNumber, 2);
      expect(second.previousEventHash, first.eventHash);
      expect(second.eventId, isNot(first.eventId));
      await fx.backend.close();
    });

    // Verifies: REQ-d00133-D (revised) — record() does NOT write to any
    // destination FIFO. Phase 4.3 fan-out runs in fillBatch on the next
    // syncCycle tick. Asserted via a decorator that counts FIFO-write
    // calls and throws on any attempt.
    test('REQ-d00133-D (revised): record does NOT write to any FIFO; fan-out '
        'deferred to fillBatch', () async {
      final db = await newDatabaseFactoryMemory().openDatabase(
        'entry-service-no-fifo.db',
      );
      final sembast = SembastBackend(database: db);
      final spy = _FifoPanicBackend(sembast);
      final registry = EntryTypeRegistry()
        ..register(_defFor('epistaxis_event'));
      final service = EntryService(
        backend: spy,
        entryTypes: registry,
        syncCycleTrigger: () async {},
        deviceInfo: const DeviceInfo(
          deviceId: 'device-1',
          softwareVersion: 'clinical_diary@1.0.0',
          userId: 'user-1',
        ),
      );

      final stored = await service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'finalized',
        answers: const <String, Object?>{'severity': 'moderate'},
      );

      expect(stored, isNotNull);
      expect(spy.fifoWrites, 0);
      await sembast.close();
    });

    // Verifies: REQ-d00133-F — identical duplicate call is a no-op.
    // Second call hashes to the same content and returns without
    // advancing the sequence counter or writing a second event.
    test('REQ-d00133-F: identical duplicate call is a no-op — returns without '
        'writing a second event', () async {
      final fx = await _setupFixture();
      final first = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'finalized',
        answers: const <String, Object?>{'severity': 'moderate'},
      );
      expect(first, isNotNull);
      final seqBefore = await fx.backend.readSequenceCounter();

      final second = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'finalized',
        answers: const <String, Object?>{'severity': 'moderate'},
      );
      expect(second, isNull);
      expect(await fx.backend.readSequenceCounter(), seqBefore);
      final events = await fx.backend.findEventsForAggregate('agg-1');
      expect(events, hasLength(1));
      await fx.backend.close();
    });

    // Verifies: REQ-d00133-F (granular) — only the tuple (event_type,
    // answers, checkpoint_reason, change_reason) participates in the
    // hash. A checkpoint followed by a finalized event with identical
    // answers has a DIFFERENT event_type, so both SHALL be recorded.
    test('REQ-d00133-F: checkpoint then finalized with same answers — both '
        'events recorded (event_type differs)', () async {
      final fx = await _setupFixture();
      final first = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'checkpoint',
        answers: const <String, Object?>{'severity': 'moderate'},
      );
      final second = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'finalized',
        answers: const <String, Object?>{'severity': 'moderate'},
      );
      expect(first, isNotNull);
      expect(second, isNotNull);

      final events = await fx.backend.findEventsForAggregate('agg-1');
      expect(events.map((e) => e.eventType), ['checkpoint', 'finalized']);
      await fx.backend.close();
    });

    // Verifies: REQ-d00133-G — record completes without awaiting
    // syncCycle. The trigger runs under unawaited(), so a slow sync
    // (here: blocked-forever) does NOT delay the record() return.
    test('REQ-d00133-G: record completes without awaiting syncCycle — '
        'fire-and-forget', () async {
      final db = await newDatabaseFactoryMemory().openDatabase(
        'entry-service-g.db',
      );
      final backend = SembastBackend(database: db);
      final registry = EntryTypeRegistry()
        ..register(_defFor('epistaxis_event'));
      final triggerStarted = Completer<void>();
      final triggerBlocker = Completer<void>();
      final service = EntryService(
        backend: backend,
        entryTypes: registry,
        syncCycleTrigger: () async {
          triggerStarted.complete();
          await triggerBlocker.future;
        },
        deviceInfo: const DeviceInfo(
          deviceId: 'device-1',
          softwareVersion: 'clinical_diary@1.0.0',
          userId: 'user-1',
        ),
      );

      // If record() awaited the trigger, this Future would never
      // complete. A timeout guards the assertion.
      final stored = await service
          .record(
            entryType: 'epistaxis_event',
            aggregateId: 'agg-1',
            eventType: 'finalized',
            answers: const <String, Object?>{'severity': 'mild'},
          )
          .timeout(const Duration(seconds: 5));
      expect(stored, isNotNull);
      // Pump the microtask queue so the fire-and-forget trigger
      // actually starts running before we assert on it.
      await Future<void>.delayed(Duration.zero);
      expect(triggerStarted.isCompleted, isTrue);

      // Release the blocked trigger so the test cleanup does not
      // leak a dangling Future.
      triggerBlocker.complete();
      await backend.close();
    });

    // Verifies: REQ-d00133-E — a storage failure inside the write
    // transaction aborts the whole write. No event appended, no
    // sequence-counter advance visible, no diary_entries row written.
    // Driven through `_ThrowingUpsertBackend` whose `upsertEntry`
    // throws — which runs AFTER appendEvent inside the same
    // transaction, so the throw must roll appendEvent back too.
    test('REQ-d00133-E: storage failure inside the write transaction aborts '
        'the whole write — no event appended', () async {
      final db = await newDatabaseFactoryMemory().openDatabase(
        'entry-service-e.db',
      );
      final sembast = SembastBackend(database: db);
      final backend = _ThrowingUpsertBackend(sembast);
      final registry = EntryTypeRegistry()
        ..register(_defFor('epistaxis_event'));
      final service = EntryService(
        backend: backend,
        entryTypes: registry,
        syncCycleTrigger: () async {},
        deviceInfo: const DeviceInfo(
          deviceId: 'device-1',
          softwareVersion: 'clinical_diary@1.0.0',
          userId: 'user-1',
        ),
      );

      await expectLater(
        service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'finalized',
          answers: const <String, Object?>{'severity': 'severe'},
        ),
        throwsStateError,
      );

      // No event in the log.
      final events = await sembast.findAllEvents();
      expect(events, isEmpty);
      // No materialized row.
      final entries = await sembast.findEntries();
      expect(entries, isEmpty);
      // Sequence counter NOT advanced past 0.
      expect(await sembast.readSequenceCounter(), 0);
      await sembast.close();
    });

    // Verifies: REQ-d00133-I — top-level migration-bridge fields
    // (client_timestamp, device_id, software_version) equal the
    // corresponding fields on metadata.provenance[0].
    test(
      'REQ-d00133-I: top-level client_timestamp, device_id, software_version '
      'equal provenance[0] values',
      () async {
        final now = DateTime.parse('2026-04-22T12:00:00Z');
        final fx = await _setupFixture(now: now);
        final stored = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'finalized',
          answers: const <String, Object?>{'severity': 'severe'},
        );
        expect(stored, isNotNull);
        final prov0 =
            (stored!.metadata['provenance'] as List)[0] as Map<String, Object?>;
        expect(stored.clientTimestamp, now);
        expect(prov0['received_at'], stored.clientTimestamp.toIso8601String());
        // Phase 4.4: deviceId / softwareVersion live in provenance[0], not as
        // top-level fields on StoredEvent.
        expect(prov0['identifier'], 'device-1');
        expect(prov0['software_version'], 'clinical_diary@1.2.3+4');
        await fx.backend.close();
      },
    );
  });

  group('EntryService.record — merge-aware no-op detection (REQ-d00133-F)', () {
    // Verifies: REQ-d00133-F (merge-aware) — a checkpoint whose delta is
    // empty and whose lifecycle/reason fields match the prior event
    // merges to an unchanged current_answers and SHALL return null
    // without advancing the sequence counter or appending an event.
    test(
      'REQ-d00133-F: checkpoint with empty delta over matching prior is a no-op',
      () async {
        final fx = await _setupFixture();
        final first = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'checkpoint',
          answers: const <String, Object?>{'a': 1},
        );
        expect(first, isNotNull);
        final seqBefore = await fx.backend.readSequenceCounter();

        final second = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'checkpoint',
          answers: const <String, Object?>{},
        );
        expect(second, isNull);
        expect(await fx.backend.readSequenceCounter(), seqBefore);
        final events = await fx.backend.findEventsForAggregate('agg-1');
        expect(events, hasLength(1));
        await fx.backend.close();
      },
    );

    // Verifies: REQ-d00133-F (merge-aware) — a checkpoint whose delta
    // values all match what is already present in the prior current_answers
    // merges to an unchanged state and SHALL be a no-op.
    test(
      'REQ-d00133-F: checkpoint with delta values all matching prior is a no-op',
      () async {
        final fx = await _setupFixture();
        final first = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'checkpoint',
          answers: const <String, Object?>{'a': 1, 'b': 2},
        );
        expect(first, isNotNull);
        final seqBefore = await fx.backend.readSequenceCounter();

        final second = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'checkpoint',
          answers: const <String, Object?>{'a': 1},
        );
        expect(second, isNull);
        expect(await fx.backend.readSequenceCounter(), seqBefore);
        final events = await fx.backend.findEventsForAggregate('agg-1');
        expect(events, hasLength(1));
        await fx.backend.close();
      },
    );

    // Verifies: REQ-d00133-F (merge-aware) — a checkpoint whose delta
    // changes a field's value merges to a different current_answers and
    // SHALL NOT be a no-op — the event is appended.
    test(
      'REQ-d00133-F: checkpoint with delta changing a field is NOT a no-op',
      () async {
        final fx = await _setupFixture();
        final first = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'checkpoint',
          answers: const <String, Object?>{'a': 1},
        );
        expect(first, isNotNull);

        final second = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'checkpoint',
          answers: const <String, Object?>{'a': 2},
        );
        expect(second, isNotNull);
        final events = await fx.backend.findEventsForAggregate('agg-1');
        expect(events, hasLength(2));
        await fx.backend.close();
      },
    );

    // Verifies: REQ-d00133-F (merge-aware) + REQ-d00121-J — a delta
    // containing an explicit-null for a prior-present key clears that
    // key's value under merge (present→null), which is a visible change;
    // the event SHALL be appended.
    test(
      'REQ-d00133-F: checkpoint with explicit-null over prior-present is NOT '
      'a no-op',
      () async {
        final fx = await _setupFixture();
        final first = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'checkpoint',
          answers: const <String, Object?>{'a': 1, 'b': 2},
        );
        expect(first, isNotNull);

        final second = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'checkpoint',
          answers: const <String, Object?>{'b': null},
        );
        expect(second, isNotNull);
        final events = await fx.backend.findEventsForAggregate('agg-1');
        expect(events, hasLength(2));
        // View: b is present, null after the merge.
        final entries = await fx.backend.findEntries();
        expect(entries, hasLength(1));
        final row = entries.single;
        expect(row.currentAnswers.containsKey('b'), isTrue);
        expect(row.currentAnswers['b'], isNull);
        expect(row.currentAnswers['a'], 1);
        await fx.backend.close();
      },
    );

    // Verifies: REQ-d00133-F (merge-aware) — a finalized event following
    // a checkpoint with merge-unchanged answers flips is_complete
    // (false → true); the lifecycle transition means this is NOT a
    // no-op even though the merged answers are unchanged.
    test(
      'REQ-d00133-F: finalized after checkpoint with merge-unchanged answers '
      'IS a new event (is_complete flips)',
      () async {
        final fx = await _setupFixture();
        final first = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'checkpoint',
          answers: const <String, Object?>{'a': 1},
        );
        expect(first, isNotNull);

        final second = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'finalized',
          answers: const <String, Object?>{'a': 1},
        );
        expect(second, isNotNull);
        final entries = await fx.backend.findEntries();
        expect(entries, hasLength(1));
        expect(entries.single.isComplete, isTrue);
        await fx.backend.close();
      },
    );

    // Verifies: REQ-d00133-F (merge-aware) — finalized following
    // finalized with merge-unchanged answers and matching lifecycle/
    // reason fields IS a no-op; the second call returns null.
    test('REQ-d00133-F: finalized after finalized with merge-unchanged answers '
        'IS a no-op', () async {
      final fx = await _setupFixture();
      final first = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'finalized',
        answers: const <String, Object?>{'a': 1},
      );
      expect(first, isNotNull);
      final seqBefore = await fx.backend.readSequenceCounter();

      final second = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'finalized',
        answers: const <String, Object?>{'a': 1},
      );
      expect(second, isNull);
      expect(await fx.backend.readSequenceCounter(), seqBefore);
      final events = await fx.backend.findEventsForAggregate('agg-1');
      expect(events, hasLength(1));
      await fx.backend.close();
    });

    // Verifies: REQ-d00133-F (merge-aware) — a change_reason mismatch
    // SHALL prevent no-op elision even when the merge produces an
    // unchanged current_answers; reason is part of the regulated record.
    test('REQ-d00133-F: change_reason mismatch prevents no-op even if merge '
        'unchanged', () async {
      final fx = await _setupFixture();
      final first = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'checkpoint',
        answers: const <String, Object?>{'a': 1},
        // defaulted change_reason = 'initial'
      );
      expect(first, isNotNull);

      final second = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'checkpoint',
        answers: const <String, Object?>{},
        changeReason: 'user_edit',
      );
      expect(second, isNotNull);
      final events = await fx.backend.findEventsForAggregate('agg-1');
      expect(events, hasLength(2));
      await fx.backend.close();
    });

    // Verifies: REQ-d00133-F (merge-aware) — a checkpoint_reason mismatch
    // SHALL prevent no-op elision even when the merge is unchanged.
    test('REQ-d00133-F: checkpoint_reason mismatch prevents no-op', () async {
      final fx = await _setupFixture();
      final first = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'checkpoint',
        answers: const <String, Object?>{'a': 1},
        checkpointReason: 'auto',
      );
      expect(first, isNotNull);

      final second = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'checkpoint',
        answers: const <String, Object?>{'a': 1},
        checkpointReason: 'manual',
      );
      expect(second, isNotNull);
      final events = await fx.backend.findEventsForAggregate('agg-1');
      expect(events, hasLength(2));
      await fx.backend.close();
    });

    // Verifies: REQ-d00133-F (merge-aware) — a tombstone over an
    // already-tombstoned aggregate with the same change_reason is a
    // no-op; the view stays deleted and no event is appended.
    test('REQ-d00133-F: tombstone over already-deleted is a no-op (same '
        'change_reason)', () async {
      final fx = await _setupFixture();
      final first = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'tombstone',
        answers: const <String, Object?>{},
      );
      expect(first, isNotNull);
      final seqBefore = await fx.backend.readSequenceCounter();

      final second = await fx.service.record(
        entryType: 'epistaxis_event',
        aggregateId: 'agg-1',
        eventType: 'tombstone',
        answers: const <String, Object?>{},
      );
      expect(second, isNull);
      expect(await fx.backend.readSequenceCounter(), seqBefore);
      final events = await fx.backend.findEventsForAggregate('agg-1');
      expect(events, hasLength(1));
      await fx.backend.close();
    });

    // Verifies: REQ-d00133-F (merge-aware) — a tombstone on a
    // non-deleted aggregate flips is_deleted (false → true) and SHALL
    // be appended, not elided.
    test(
      'REQ-d00133-F: tombstone over non-deleted aggregate is NOT a no-op',
      () async {
        final fx = await _setupFixture();
        final first = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'checkpoint',
          answers: const <String, Object?>{'a': 1},
        );
        expect(first, isNotNull);

        final second = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'tombstone',
          answers: const <String, Object?>{},
        );
        expect(second, isNotNull);
        final entries = await fx.backend.findEntries();
        expect(entries, hasLength(1));
        expect(entries.single.isDeleted, isTrue);
        await fx.backend.close();
      },
    );

    // Verifies: REQ-d00133-F (merge-aware) — the first event on an
    // aggregate is never a no-op; the no-op check only runs when prior
    // history exists. An empty delta still creates the first event.
    test(
      'REQ-d00133-F: first event on an aggregate is never a no-op',
      () async {
        final fx = await _setupFixture();
        final stored = await fx.service.record(
          entryType: 'epistaxis_event',
          aggregateId: 'agg-1',
          eventType: 'checkpoint',
          answers: const <String, Object?>{},
        );
        expect(stored, isNotNull);
        final events = await fx.backend.findEventsForAggregate('agg-1');
        expect(events, hasLength(1));
        await fx.backend.close();
      },
    );
  });
}

/// Backend decorator that counts every FIFO-row write and delegates all
/// other calls to the underlying backend. Used by REQ-d00133-D to prove
/// the local transaction does NOT fan out to destinations.
class _FifoPanicBackend extends _DelegatingBackend {
  _FifoPanicBackend(super.inner);

  int fifoWrites = 0;

  @override
  Future<FifoEntry> enqueueFifo(
    String destinationId,
    List<StoredEvent> batch, {
    WirePayload? wirePayload,
    BatchEnvelopeMetadata? nativeEnvelope,
  }) {
    fifoWrites += 1;
    throw StateError('record() must not write to a FIFO (REQ-d00133-D)');
  }

  @override
  Future<FifoEntry> enqueueFifoTxn(
    Txn txn,
    String destinationId,
    List<StoredEvent> batch, {
    WirePayload? wirePayload,
    BatchEnvelopeMetadata? nativeEnvelope,
  }) {
    fifoWrites += 1;
    throw StateError('record() must not write to a FIFO (REQ-d00133-D)');
  }
}

/// Backend decorator whose `upsertEntry` throws. Used by REQ-d00133-E
/// to exercise the atomicity guarantee: the transaction rolls back,
/// leaving no event in the log and no row in diary_entries.
class _ThrowingUpsertBackend extends _DelegatingBackend {
  _ThrowingUpsertBackend(super.inner);

  @override
  Future<void> upsertEntry(Txn txn, DiaryEntry entry) {
    throw StateError('simulated materializer/upsert failure');
  }
}

/// Forwarding decorator that delegates every [StorageBackend] method to
/// an inner backend. Concrete tests override just the methods they
/// want to intercept.
class _DelegatingBackend extends StorageBackend {
  _DelegatingBackend(this._inner);

  final StorageBackend _inner;

  @override
  Future<T> transaction<T>(Future<T> Function(Txn txn) body) =>
      _inner.transaction(body);

  @override
  Future<AppendResult> appendEvent(Txn txn, StoredEvent event) =>
      _inner.appendEvent(txn, event);

  @override
  Future<List<StoredEvent>> findEventsForAggregate(String aggregateId) =>
      _inner.findEventsForAggregate(aggregateId);

  @override
  Future<List<StoredEvent>> findEventsForAggregateInTxn(
    Txn txn,
    String aggregateId,
  ) => _inner.findEventsForAggregateInTxn(txn, aggregateId);

  @override
  Future<List<StoredEvent>> findAllEvents({
    int? afterSequence,
    int? limit,
    String? originatorHopId,
    String? originatorIdentifier,
  }) => _inner.findAllEvents(
    afterSequence: afterSequence,
    limit: limit,
    originatorHopId: originatorHopId,
    originatorIdentifier: originatorIdentifier,
  );

  @override
  Future<String?> readLatestEventHash(Txn txn) =>
      _inner.readLatestEventHash(txn);

  @override
  Future<List<StoredEvent>> findAllEventsInTxn(
    Txn txn, {
    int? afterSequence,
    int? limit,
  }) => _inner.findAllEventsInTxn(
    txn,
    afterSequence: afterSequence,
    limit: limit,
  );

  @override
  Future<int> nextSequenceNumber(Txn txn) => _inner.nextSequenceNumber(txn);

  @override
  Future<int> readSequenceCounter() => _inner.readSequenceCounter();

  @override
  Future<void> upsertEntry(Txn txn, DiaryEntry entry) =>
      _inner.upsertEntry(txn, entry);

  @override
  Future<void> clearEntries(Txn txn) => _inner.clearEntries(txn);

  @override
  Future<List<DiaryEntry>> findEntries({
    String? entryType,
    bool? isComplete,
    bool? isDeleted,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) => _inner.findEntries(
    entryType: entryType,
    isComplete: isComplete,
    isDeleted: isDeleted,
    dateFrom: dateFrom,
    dateTo: dateTo,
  );

  @override
  Future<DiaryEntry?> readEntryInTxn(Txn txn, String entryId) =>
      _inner.readEntryInTxn(txn, entryId);

  @override
  Future<Map<String, dynamic>?> readViewRowInTxn(
    Txn txn,
    String viewName,
    String key,
  ) => _inner.readViewRowInTxn(txn, viewName, key);

  @override
  Future<void> upsertViewRowInTxn(
    Txn txn,
    String viewName,
    String key,
    Map<String, dynamic> row,
  ) => _inner.upsertViewRowInTxn(txn, viewName, key, row);

  @override
  Future<void> deleteViewRowInTxn(Txn txn, String viewName, String key) =>
      _inner.deleteViewRowInTxn(txn, viewName, key);

  @override
  Future<List<Map<String, dynamic>>> findViewRows(
    String viewName, {
    int? limit,
    int? offset,
  }) => _inner.findViewRows(viewName, limit: limit, offset: offset);

  @override
  Future<void> clearViewInTxn(Txn txn, String viewName) =>
      _inner.clearViewInTxn(txn, viewName);

  @override
  Future<int?> readViewTargetVersionInTxn(
    Txn txn,
    String viewName,
    String entryType,
  ) => _inner.readViewTargetVersionInTxn(txn, viewName, entryType);

  @override
  Future<void> writeViewTargetVersionInTxn(
    Txn txn,
    String viewName,
    String entryType,
    int targetVersion,
  ) => _inner.writeViewTargetVersionInTxn(
    txn,
    viewName,
    entryType,
    targetVersion,
  );

  @override
  Future<Map<String, int>> readAllViewTargetVersionsInTxn(
    Txn txn,
    String viewName,
  ) => _inner.readAllViewTargetVersionsInTxn(txn, viewName);

  @override
  Future<void> clearViewTargetVersionsInTxn(Txn txn, String viewName) =>
      _inner.clearViewTargetVersionsInTxn(txn, viewName);

  @override
  Future<FifoEntry> enqueueFifo(
    String destinationId,
    List<StoredEvent> batch, {
    WirePayload? wirePayload,
    BatchEnvelopeMetadata? nativeEnvelope,
  }) => _inner.enqueueFifo(
    destinationId,
    batch,
    wirePayload: wirePayload,
    nativeEnvelope: nativeEnvelope,
  );

  @override
  Future<FifoEntry> enqueueFifoTxn(
    Txn txn,
    String destinationId,
    List<StoredEvent> batch, {
    WirePayload? wirePayload,
    BatchEnvelopeMetadata? nativeEnvelope,
  }) => _inner.enqueueFifoTxn(
    txn,
    destinationId,
    batch,
    wirePayload: wirePayload,
    nativeEnvelope: nativeEnvelope,
  );

  @override
  Future<FifoEntry?> readFifoHead(String destinationId) =>
      _inner.readFifoHead(destinationId);

  @override
  Future<List<FifoEntry>> listFifoEntries(
    String destinationId, {
    int? afterSequenceInQueue,
    int? limit,
  }) => _inner.listFifoEntries(
    destinationId,
    afterSequenceInQueue: afterSequenceInQueue,
    limit: limit,
  );

  @override
  Future<void> appendAttempt(
    String destinationId,
    String entryId,
    AttemptResult attempt,
  ) => _inner.appendAttempt(destinationId, entryId, attempt);

  @override
  Future<void> markFinal(
    String destinationId,
    String entryId,
    FinalStatus status,
  ) => _inner.markFinal(destinationId, entryId, status);

  @override
  Future<bool> anyFifoWedged() => _inner.anyFifoWedged();

  @override
  Future<List<WedgedFifoSummary>> wedgedFifos() => _inner.wedgedFifos();

  @override
  Future<int> readSchemaVersion() => _inner.readSchemaVersion();

  @override
  Future<void> writeSchemaVersion(Txn txn, int version) =>
      _inner.writeSchemaVersion(txn, version);

  @override
  Future<int> readFillCursor(String destinationId) =>
      _inner.readFillCursor(destinationId);

  @override
  Future<void> writeFillCursor(String destinationId, int sequenceNumber) =>
      _inner.writeFillCursor(destinationId, sequenceNumber);

  @override
  Future<void> writeFillCursorTxn(
    Txn txn,
    String destinationId,
    int sequenceNumber,
  ) => _inner.writeFillCursorTxn(txn, destinationId, sequenceNumber);

  @override
  Future<DestinationSchedule?> readSchedule(String destinationId) =>
      _inner.readSchedule(destinationId);

  @override
  Future<void> writeSchedule(
    String destinationId,
    DestinationSchedule schedule,
  ) => _inner.writeSchedule(destinationId, schedule);

  @override
  Future<void> writeScheduleTxn(
    Txn txn,
    String destinationId,
    DestinationSchedule schedule,
  ) => _inner.writeScheduleTxn(txn, destinationId, schedule);

  @override
  Future<void> deleteScheduleTxn(Txn txn, String destinationId) =>
      _inner.deleteScheduleTxn(txn, destinationId);

  @override
  Future<void> deleteFifoStoreTxn(Txn txn, String destinationId) =>
      _inner.deleteFifoStoreTxn(txn, destinationId);

  @override
  Future<FifoEntry?> readFifoRow(String destinationId, String entryId) =>
      _inner.readFifoRow(destinationId, entryId);

  @override
  Future<void> setFinalStatusTxn(
    Txn txn,
    String destinationId,
    String entryId,
    FinalStatus? status,
  ) => _inner.setFinalStatusTxn(txn, destinationId, entryId, status);

  @override
  Future<int> deleteNullRowsAfterSequenceInQueueTxn(
    Txn txn,
    String destinationId,
    int afterSequenceInQueue,
  ) => _inner.deleteNullRowsAfterSequenceInQueueTxn(
    txn,
    destinationId,
    afterSequenceInQueue,
  );
  @override
  Future<StoredEvent?> findEventByIdInTxn(Txn txn, String eventId) =>
      _inner.findEventByIdInTxn(txn, eventId);
  @override
  Future<StoredEvent?> findEventById(String eventId) =>
      _inner.findEventById(eventId);
  @override
  Stream<StoredEvent> watchEvents({int? afterSequence}) =>
      _inner.watchEvents(afterSequence: afterSequence);
  @override
  Stream<List<FifoEntry>> watchFifo(String destinationId) =>
      _inner.watchFifo(destinationId);
  @override
  Stream<List<Map<String, Object?>>> watchView(String viewName) =>
      _inner.watchView(viewName);
  @override
  Future<PagedAudit> queryAudit({
    Initiator? initiator,
    String? flowToken,
    String? ipAddress,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    String? cursor,
  }) => _inner.queryAudit(
    initiator: initiator,
    flowToken: flowToken,
    ipAddress: ipAddress,
    from: from,
    to: to,
    limit: limit,
    cursor: cursor,
  );
}
