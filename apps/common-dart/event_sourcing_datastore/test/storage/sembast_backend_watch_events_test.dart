import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<SembastBackend> _openBackend(String path) async {
  final db = await newDatabaseFactoryMemory().openDatabase(path);
  return SembastBackend(database: db);
}

Future<StoredEvent> _appendEvent(
  SembastBackend backend, {
  required String eventId,
  String aggregateId = 'agg-1',
}) {
  return backend.transaction((txn) async {
    final seq = await backend.nextSequenceNumber(txn);
    final event = StoredEvent(
      key: 0,
      eventId: eventId,
      aggregateId: aggregateId,
      aggregateType: 'DiaryEntry',
      entryType: 'epistaxis_event',
      entryTypeVersion: 1,
      libFormatVersion: 1,
      eventType: 'finalized',
      sequenceNumber: seq,
      data: const <String, dynamic>{},
      metadata: const <String, dynamic>{},
      initiator: const UserInitiator('u'),
      clientTimestamp: DateTime.utc(2026, 4, 22, 10),
      eventHash: 'hash-$eventId',
    );
    await backend.appendEvent(txn, event);
    return event;
  });
}

void main() {
  group('SembastBackend.watchEvents', () {
    late SembastBackend backend;
    var dbCounter = 0;

    setUp(() async {
      dbCounter += 1;
      backend = await _openBackend('watch-events-$dbCounter.db');
    });

    tearDown(() async {
      await backend.close();
    });

    // Verifies: REQ-d00149-A — replay-then-live: pre-existing events
    // emit on subscribe, then a live append produces the next emission.
    test(
      'REQ-d00149-A: watchEvents replays then transitions to live',
      () async {
        await _appendEvent(backend, eventId: 'e1');
        await _appendEvent(backend, eventId: 'e2');

        final stream = backend.watchEvents();
        // First two replayed; then live append surfaces.
        final fut = expectLater(
          stream,
          emitsInOrder([
            predicate<StoredEvent>((e) => e.eventId == 'e1'),
            predicate<StoredEvent>((e) => e.eventId == 'e2'),
            predicate<StoredEvent>((e) => e.eventId == 'e3'),
          ]),
        );
        // Give the replay tick to flush, then append live.
        await Future<void>.delayed(Duration.zero);
        await _appendEvent(backend, eventId: 'e3');
        await fut;
      },
    );

    // Verifies: REQ-d00149-A — afterSequence filters replay.
    test(
      'REQ-d00149-A: watchEvents skips replay events at or below afterSequence',
      () async {
        final e1 = await _appendEvent(backend, eventId: 'e1');
        await _appendEvent(backend, eventId: 'e2');

        final stream = backend.watchEvents(afterSequence: e1.sequenceNumber);
        await expectLater(
          stream,
          emitsThrough(predicate<StoredEvent>((e) => e.eventId == 'e2')),
        );
      },
    );

    // Verifies: REQ-d00149-C — broadcast: two subscribers see identical
    // sequences.
    test(
      'REQ-d00149-C: watchEvents is broadcast (multiple subscribers)',
      () async {
        final stream = backend.watchEvents();
        final sub1 = <String>[];
        final sub2 = <String>[];
        final s1 = stream.listen((e) => sub1.add(e.eventId));
        final s2 = stream.listen((e) => sub2.add(e.eventId));

        await _appendEvent(backend, eventId: 'e1');
        await _appendEvent(backend, eventId: 'e2');
        await Future<void>.delayed(Duration.zero);

        await s1.cancel();
        await s2.cancel();
        expect(sub1, ['e1', 'e2']);
        expect(sub2, ['e1', 'e2']);
      },
    );

    // Verifies: REQ-d00149-D — close() sends done to active subscribers
    // and subsequent watchEvents throws StateError.
    test(
      'REQ-d00149-D: watchEvents closes on backend close, then throws',
      () async {
        final stream = backend.watchEvents();
        final completer = expectLater(stream, emitsDone);
        await backend.close();
        await completer;
        expect(() => backend.watchEvents(), throwsStateError);
        // Re-open a fresh backend so tearDown's close doesn't double-close.
        backend = await _openBackend('watch-events-reopen-$dbCounter.db');
      },
    );

    // Verifies: REQ-d00149-A — ingested events surface on watchEvents.
    // Under the unified event store, ingest routes through appendEvent
    // and shares the broadcast controller with origin appends, so a
    // single watchEvents subscription sees both write paths.
    test(
      'REQ-d00149-A: watchEvents emits ingested events (unified store)',
      () async {
        const destSource = Source(
          hopId: 'portal-server',
          identifier: 'portal-1',
          softwareVersion: 'portal@0.1.0',
        );
        final registry = EntryTypeRegistry()
          ..register(
            const EntryTypeDefinition(
              id: 'epistaxis_event',
              registeredVersion: 1,
              name: 'Epistaxis Event',
              widgetId: 'w',
              widgetConfig: <String, Object?>{},
            ),
          );
        final secCtx = SembastSecurityContextStore(backend: backend);
        final destStore = EventStore(
          backend: backend,
          entryTypes: registry,
          source: destSource,
          securityContexts: secCtx,
        );

        // Originate a single event in a separate originator backend.
        final origDb = await newDatabaseFactoryMemory().openDatabase(
          'watch-events-orig-$dbCounter.db',
        );
        final origBackend = SembastBackend(database: origDb);
        final origSecCtx = SembastSecurityContextStore(backend: origBackend);
        final origStore = EventStore(
          backend: origBackend,
          entryTypes: registry,
          source: const Source(
            hopId: 'mobile-device',
            identifier: 'device-1',
            softwareVersion: 'clinical_diary@1.0.0',
          ),
          securityContexts: origSecCtx,
        );
        try {
          final origEvent = await origStore.append(
            entryType: 'epistaxis_event',
            entryTypeVersion: 1,
            aggregateId: 'agg-watch-1',
            aggregateType: 'DiaryEntry',
            eventType: 'finalized',
            data: const <String, Object?>{
              'answers': {'q': 'a'},
            },
            initiator: const UserInitiator('u1'),
          );
          expect(origEvent, isNotNull);

          final stream = backend.watchEvents();
          final received = <String>[];
          final sub = stream.listen((e) => received.add(e.eventId));
          await Future<void>.delayed(Duration.zero);

          // Ingest the originated event into dest. The receiver-hop event
          // routes through appendEvent under unification, so it must
          // surface on the stream.
          await destStore.ingestEvent(origEvent!);
          await Future<void>.delayed(Duration.zero);

          await sub.cancel();
          expect(received, contains(origEvent.eventId));
        } finally {
          await origBackend.close();
        }
      },
    );
  });
}
