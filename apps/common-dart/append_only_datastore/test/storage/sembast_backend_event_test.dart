import 'package:append_only_datastore/src/storage/initiator.dart';
import 'package:append_only_datastore/src/storage/sembast_backend.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:append_only_datastore/src/storage/txn.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  group('SembastBackend events', () {
    late SembastBackend backend;
    var pathCounter = 0;

    setUp(() async {
      // Fresh in-memory database per test for isolation.
      pathCounter += 1;
      final db = await newDatabaseFactoryMemory().openDatabase(
        'test-$pathCounter.db',
      );
      backend = SembastBackend(database: db);
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00117-A — two writes inside a single transaction both
    // land on commit.
    test(
      'REQ-d00117-A: two appendEvents in one transaction both land',
      () async {
        await backend.transaction((txn) async {
          final seq1 = await backend.nextSequenceNumber(txn);
          await backend.appendEvent(txn, _event('ev-1', seq1));
          final seq2 = await backend.nextSequenceNumber(txn);
          await backend.appendEvent(txn, _event('ev-2', seq2));
        });

        final stored = await backend.findAllEvents();
        expect(stored.map((e) => e.eventId), ['ev-1', 'ev-2']);
      },
    );

    // Verifies: REQ-d00117-A — throw inside transaction body rolls back both
    // the event and the sequence counter.
    test('REQ-d00117-A: thrown body rolls back both writes', () async {
      await expectLater(
        backend.transaction((txn) async {
          final seq = await backend.nextSequenceNumber(txn);
          await backend.appendEvent(txn, _event('ev-rollback', seq));
          throw StateError('simulated failure');
        }),
        throwsStateError,
      );

      // Event did not land.
      expect(await backend.findAllEvents(), isEmpty);
      // Sequence counter was not advanced.
      await backend.transaction((txn) async {
        expect(await backend.nextSequenceNumber(txn), 1);
      });
    });

    // Verifies: REQ-d00117-C — appendEvent advances the sequence counter via
    // backend_state store so nextSequenceNumber() in the next transaction
    // returns the next monotonic value.
    test('REQ-d00117-C: appendEvent advances sequence counter', () async {
      await backend.transaction((txn) async {
        final seq = await backend.nextSequenceNumber(txn);
        await backend.appendEvent(txn, _event('ev-1', seq));
      });

      // A second transaction sees the advanced counter.
      await backend.transaction((txn) async {
        expect(await backend.nextSequenceNumber(txn), 2);
      });
    });

    test(
      'REQ-d00117-C: nextSequenceNumber is monotonic across transactions',
      () async {
        final seen = <int>[];
        for (var i = 0; i < 5; i++) {
          await backend.transaction((txn) async {
            final seq = await backend.nextSequenceNumber(txn);
            seen.add(seq);
            await backend.appendEvent(txn, _event('ev-$i', seq));
          });
        }
        expect(seen, [1, 2, 3, 4, 5]);
      },
    );

    test(
      'findEventsForAggregate returns events sorted by sequence_number',
      () async {
        // Append three events across two aggregates, interleaved.
        await backend.transaction((txn) async {
          final s1 = await backend.nextSequenceNumber(txn);
          await backend.appendEvent(txn, _event('a1', s1, aggregateId: 'A'));
        });
        await backend.transaction((txn) async {
          final s2 = await backend.nextSequenceNumber(txn);
          await backend.appendEvent(txn, _event('b1', s2, aggregateId: 'B'));
        });
        await backend.transaction((txn) async {
          final s3 = await backend.nextSequenceNumber(txn);
          await backend.appendEvent(txn, _event('a2', s3, aggregateId: 'A'));
        });

        final aEvents = await backend.findEventsForAggregate('A');
        expect(aEvents.map((e) => e.eventId), ['a1', 'a2']);
        final bEvents = await backend.findEventsForAggregate('B');
        expect(bEvents.map((e) => e.eventId), ['b1']);
      },
    );

    test(
      'findAllEvents(afterSequence, limit) slices correctly and keeps order',
      () async {
        for (var i = 0; i < 5; i++) {
          await backend.transaction((txn) async {
            final s = await backend.nextSequenceNumber(txn);
            await backend.appendEvent(txn, _event('ev-$i', s));
          });
        }

        final all = await backend.findAllEvents();
        expect(all.map((e) => e.sequenceNumber), [1, 2, 3, 4, 5]);

        final afterTwo = await backend.findAllEvents(afterSequence: 2);
        expect(afterTwo.map((e) => e.sequenceNumber), [3, 4, 5]);

        final limited = await backend.findAllEvents(limit: 2);
        expect(limited.map((e) => e.sequenceNumber), [1, 2]);

        final both = await backend.findAllEvents(afterSequence: 2, limit: 2);
        expect(both.map((e) => e.sequenceNumber), [3, 4]);
      },
    );

    // Verifies: REQ-d00117-F — schema_version lives in backend_state,
    // and MUST NOT collide with the event-level metadata field.
    test(
      'REQ-d00117-F: schema_version round-trips via backend_state',
      () async {
        expect(await backend.readSchemaVersion(), 0); // never written
        await backend.transaction((txn) async {
          await backend.writeSchemaVersion(txn, 7);
        });
        expect(await backend.readSchemaVersion(), 7);
      },
    );

    // Verifies: REQ-d00117-F — the Sembast store named `metadata` is NOT
    // used for backend bookkeeping. An empty `metadata` store is proof that
    // bookkeeping landed in `backend_state` instead.
    test('REQ-d00117-F: no writes go to a `metadata` store', () async {
      await backend.transaction((txn) async {
        final s = await backend.nextSequenceNumber(txn);
        await backend.appendEvent(txn, _event('ev-1', s));
        await backend.writeSchemaVersion(txn, 1);
      });

      // Inspect the raw database.
      final db = backend.debugDatabase();
      final metadataStore = StoreRef<String, Object?>('metadata');
      final rows = await metadataStore.find(db);
      expect(rows, isEmpty);
    });

    // Verifies: REQ-d00117-B — SembastBackend's concrete Txn subclass is
    // invalidated when the transaction body returns; a later use throws
    // StateError rather than writing against a closed Sembast transaction.
    test(
      'REQ-d00117-B: SembastBackend Txn cannot be used after body returns',
      () async {
        late Txn escaped;
        await backend.transaction((txn) async {
          escaped = txn;
        });

        await expectLater(
          backend.appendEvent(escaped, _event('ev-late', 1)),
          throwsStateError,
        );
      },
    );

    // Verifies the guard against handing one backend's Txn to another
    // backend. Gives defense in depth so a foreign Txn can't be mis-typed
    // into this one's internal state.
    test('foreign Txn (from a different backend) is rejected', () async {
      final otherDb = await newDatabaseFactoryMemory().openDatabase(
        'foreign.db',
      );
      final other = SembastBackend(database: otherDb);
      late Txn foreignTxn;
      await other.transaction((txn) async {
        foreignTxn = txn;
      });
      await other.close();

      // The foreign Txn is already invalidated, so _requireValidTxn's
      // _isValid check fires first. Even if it were still valid, the
      // is!-based type check would catch it.
      await expectLater(
        backend.appendEvent(foreignTxn, _event('ev', 1)),
        throwsStateError,
      );
    });

    // Verifies REQ-d00117-C — counter is correctly 2 after a successful
    // two-appends-in-one-transaction commit, so the next nextSequenceNumber
    // call returns 3.
    test(
      'REQ-d00117-C: counter equals total appends after multi-append txn',
      () async {
        await backend.transaction((txn) async {
          final s1 = await backend.nextSequenceNumber(txn);
          await backend.appendEvent(txn, _event('ev-1', s1));
          final s2 = await backend.nextSequenceNumber(txn);
          await backend.appendEvent(txn, _event('ev-2', s2));
        });
        await backend.transaction((txn) async {
          expect(await backend.nextSequenceNumber(txn), 3);
        });
      },
    );

    // Verifies appendEvent rejects a mismatched sequence number,
    // preventing silent counter regression if a caller forgets to pair
    // nextSequenceNumber with appendEvent.
    //
    // Phase-2 Prereq B, Option 1: the counter is advanced by
    // nextSequenceNumber, so appendEvent's check is "event.sequenceNumber
    // == current counter value", not "current + 1".
    test('appendEvent throws when sequenceNumber does not match the reserved '
        'counter value (Prereq B, Option 1)', () async {
      await expectLater(
        backend.transaction((txn) async {
          // Skip nextSequenceNumber; pass a wrong value.
          await backend.appendEvent(txn, _event('ev-bad', 42));
        }),
        throwsStateError,
      );
      // Nothing landed.
      expect(await backend.findAllEvents(), isEmpty);
    });

    // Verifies: REQ-d00117-C — nextSequenceNumber reserves-and-increments,
    // so two calls in the same transaction advance the counter twice.
    // Locks Phase-2 Prereq B, Option 1.
    test('REQ-d00117-C: two nextSequenceNumber calls in one txn return '
        'current+1 and current+2 (reserve-and-increment)', () async {
      await backend.transaction((txn) async {
        expect(await backend.nextSequenceNumber(txn), 1);
        expect(await backend.nextSequenceNumber(txn), 2);
      });
      // The transaction committed, so the counter is at 2.
      await backend.transaction((txn) async {
        expect(await backend.nextSequenceNumber(txn), 3);
      });
    });

    // Verifies: REQ-d00117-C — appendEvent does NOT re-advance the counter.
    // The counter after `nextSeq -> appendEvent` equals the reserved value.
    test('REQ-d00117-C: appendEvent consumes the reservation without '
        're-advancing the counter (Prereq B, Option 1)', () async {
      await backend.transaction((txn) async {
        final seq = await backend.nextSequenceNumber(txn);
        expect(seq, 1);
        await backend.appendEvent(txn, _event('ev-1', seq));
      });
      // Counter is at 1 after the append. If appendEvent had re-advanced,
      // the next nextSequenceNumber would return 3.
      await backend.transaction((txn) async {
        expect(await backend.nextSequenceNumber(txn), 2);
      });
    });

    // Verifies: readLatestEventHash is transactional — the value reflects
    // writes staged in the same transaction body so a caller can build the
    // next event's previous_event_hash atomically with the append that uses
    // it.
    test('readLatestEventHash returns null on an empty log', () async {
      await backend.transaction((txn) async {
        expect(await backend.readLatestEventHash(txn), isNull);
      });
    });

    test('readLatestEventHash returns hash of highest-seq event', () async {
      await backend.transaction((txn) async {
        final s1 = await backend.nextSequenceNumber(txn);
        await backend.appendEvent(txn, _event('ev-1', s1));
      });
      await backend.transaction((txn) async {
        final s2 = await backend.nextSequenceNumber(txn);
        await backend.appendEvent(txn, _event('ev-2', s2));
      });
      await backend.transaction((txn) async {
        expect(await backend.readLatestEventHash(txn), 'hash-ev-2');
      });
    });

    test('readLatestEventHash sees writes staged in the same txn', () async {
      await backend.transaction((txn) async {
        // Empty at start of body.
        expect(await backend.readLatestEventHash(txn), isNull);
        final s = await backend.nextSequenceNumber(txn);
        await backend.appendEvent(txn, _event('ev-in-tx', s));
        // Sees the just-appended event's hash without leaving the txn.
        expect(await backend.readLatestEventHash(txn), 'hash-ev-in-tx');
      });
    });

    test('readLatestEventHash rejects use outside its transaction', () async {
      late Txn escaped;
      await backend.transaction((txn) async {
        escaped = txn;
      });
      await expectLater(backend.readLatestEventHash(escaped), throwsStateError);
    });

    test('findAllEventsInTxn returns events ordered by sequence_number '
        'including txn-staged ones', () async {
      await backend.transaction((txn) async {
        final s1 = await backend.nextSequenceNumber(txn);
        await backend.appendEvent(txn, _event('ev-1', s1));
      });

      // Inside a second transaction, append one more event and read all
      // events — the staged event must be visible.
      await backend.transaction((txn) async {
        final s2 = await backend.nextSequenceNumber(txn);
        await backend.appendEvent(txn, _event('ev-2', s2));
        final all = await backend.findAllEventsInTxn(txn);
        expect(all.map((e) => e.eventId), ['ev-1', 'ev-2']);
        expect(all.map((e) => e.sequenceNumber), [1, 2]);
      });
    });

    test('findAllEventsInTxn returns empty list when log is empty', () async {
      await backend.transaction((txn) async {
        expect(await backend.findAllEventsInTxn(txn), isEmpty);
      });
    });

    test('findAllEventsInTxn rejects use outside its transaction', () async {
      late Txn escaped;
      await backend.transaction((txn) async {
        escaped = txn;
      });
      await expectLater(backend.findAllEventsInTxn(escaped), throwsStateError);
    });

    test('findAllEventsInTxn paginates via afterSequence and limit — the full '
        'log can be walked without ever holding more than `limit` events at '
        'once', () async {
      // Seed 7 events so we can exercise partial + final chunks.
      for (var i = 1; i <= 7; i++) {
        await backend.transaction((txn) async {
          final s = await backend.nextSequenceNumber(txn);
          await backend.appendEvent(txn, _event('ev-$i', s));
        });
      }

      await backend.transaction((txn) async {
        final chunk1 = await backend.findAllEventsInTxn(txn, limit: 3);
        expect(chunk1.map((e) => e.sequenceNumber), [1, 2, 3]);

        final chunk2 = await backend.findAllEventsInTxn(
          txn,
          afterSequence: chunk1.last.sequenceNumber,
          limit: 3,
        );
        expect(chunk2.map((e) => e.sequenceNumber), [4, 5, 6]);

        final chunk3 = await backend.findAllEventsInTxn(
          txn,
          afterSequence: chunk2.last.sequenceNumber,
          limit: 3,
        );
        // Partial trailing chunk — fewer than `limit`, signals exhaustion.
        expect(chunk3.map((e) => e.sequenceNumber), [7]);

        final chunk4 = await backend.findAllEventsInTxn(
          txn,
          afterSequence: chunk3.last.sequenceNumber,
          limit: 3,
        );
        expect(chunk4, isEmpty);
      });
    });

    test('close() closes the underlying database', () async {
      await backend.transaction((txn) async {
        final s = await backend.nextSequenceNumber(txn);
        await backend.appendEvent(txn, _event('ev-1', s));
      });
      await backend.close();
      // After close(), operations on the backend fail because the
      // underlying Sembast database has been closed. The caller owns the
      // Database lifecycle; if reads were desired post-close the caller
      // would construct a new SembastBackend over a re-opened Database.
      await expectLater(backend.findAllEvents(), throwsA(isA<Exception>()));
    });
  });
}

StoredEvent _event(
  String eventId,
  int sequenceNumber, {
  String aggregateId = 'agg-1',
}) {
  return StoredEvent(
    key: 0,
    eventId: eventId,
    aggregateId: aggregateId,
    aggregateType: 'DiaryEntry',
    entryType: 'epistaxis_event',
    eventType: 'Event',
    sequenceNumber: sequenceNumber,
    data: const <String, dynamic>{},
    metadata: const <String, dynamic>{},
    initiator: const UserInitiator('u'),
    clientTimestamp: DateTime.utc(2026, 4, 22),
    eventHash: 'hash-$eventId',
  );
}
