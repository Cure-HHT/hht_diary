import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/fifo_entry.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 4.3 Task 6 — FifoEntry batch-per-row shape.
///
/// Verifies the three REQ-d00128 assertions on the new FifoEntry shape:
///
/// - REQ-d00128-A — `eventIds` is a non-empty `List<String>`.
/// - REQ-d00128-B — `eventIdRange` is a (firstSeq, lastSeq) record drawn from
///   the sequence_numbers of the contained events.
/// - REQ-d00128-C — `wirePayload` is one payload covering the whole batch;
///   no per-event wire payload is stored.
///
/// These tests run in addition to (not in place of) `value_types_test.dart`'s
/// `FifoEntry` group, which now also exercises the new shape.
void main() {
  final enqueuedAt = DateTime.utc(2026, 4, 22, 9);

  FifoEntry makeBatch({
    List<String>? eventIds,
    EventIdRange? eventIdRange,
    Map<String, Object?>? wirePayload,
  }) {
    return FifoEntry(
      entryId: 'entry-1',
      eventIds: eventIds ?? const ['ev-1', 'ev-2', 'ev-3'],
      eventIdRange: eventIdRange ?? (firstSeq: 10, lastSeq: 12),
      sequenceInQueue: 1,
      wirePayload: wirePayload ?? const <String, Object?>{'batch': 'ok'},
      wireFormat: 'json-v1',
      transformVersion: 'transform-v1',
      enqueuedAt: enqueuedAt,
      attempts: const <AttemptResult>[],
      finalStatus: FinalStatus.pending,
      sentAt: null,
    );
  }

  group('FifoEntry batch shape (Phase 4.3 Task 6)', () {
    // Verifies: REQ-d00128-A — eventIds is a non-empty List<String>
    // identifying every event in the batch.
    test('REQ-d00128-A: eventIds is a non-empty List<String> with every batch '
        'event id', () {
      final entry = makeBatch(eventIds: const ['ev-a', 'ev-b', 'ev-c']);
      expect(entry.eventIds, isA<List<String>>());
      expect(entry.eventIds, ['ev-a', 'ev-b', 'ev-c']);
      expect(entry.eventIds, isNotEmpty);
    });

    // Verifies: REQ-d00128-A — an empty eventIds list is rejected at
    // construction so a batch row can never be persisted with zero events.
    test('REQ-d00128-A: constructing FifoEntry with empty eventIds throws', () {
      expect(
        () => FifoEntry(
          entryId: 'entry-1',
          eventIds: const <String>[],
          eventIdRange: (firstSeq: 0, lastSeq: 0),
          sequenceInQueue: 1,
          wirePayload: const <String, Object?>{},
          wireFormat: 'json-v1',
          transformVersion: null,
          enqueuedAt: enqueuedAt,
          attempts: const <AttemptResult>[],
          finalStatus: FinalStatus.pending,
          sentAt: null,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    // Verifies: REQ-d00128-A — fromJson rejects an absent, wrong-typed, or
    // empty event_ids field with a FormatException.
    test('REQ-d00128-A: fromJson rejects missing, non-List, and empty '
        'event_ids', () {
      final base = makeBatch().toJson();

      final missing = Map<String, Object?>.from(base)..remove('event_ids');
      expect(() => FifoEntry.fromJson(missing), throwsFormatException);

      final wrongType = Map<String, Object?>.from(base)
        ..['event_ids'] = 'not-a-list';
      expect(() => FifoEntry.fromJson(wrongType), throwsFormatException);

      final empty = Map<String, Object?>.from(base)..['event_ids'] = <String>[];
      expect(() => FifoEntry.fromJson(empty), throwsFormatException);
    });

    // Verifies: REQ-d00128-B — eventIdRange is a (firstSeq, lastSeq) record
    // drawn from the sequence_number values of the contained events; the
    // pair is typed as EventIdRange (Dart 3 record typedef), not a class.
    test('REQ-d00128-B: eventIdRange is an (firstSeq, lastSeq) record', () {
      final entry = makeBatch(eventIdRange: (firstSeq: 100, lastSeq: 104));
      expect(entry.eventIdRange.firstSeq, 100);
      expect(entry.eventIdRange.lastSeq, 104);
      expect(entry.eventIdRange, isA<EventIdRange>());
      // Record equality is structural.
      expect(entry.eventIdRange, (firstSeq: 100, lastSeq: 104));
    });

    // Verifies: REQ-d00128-B — event_id_range round-trips as
    // {"first_seq": int, "last_seq": int} in JSON.
    test('REQ-d00128-B: event_id_range persists as first_seq/last_seq Map', () {
      final entry = makeBatch(eventIdRange: (firstSeq: 7, lastSeq: 9));
      final json = entry.toJson();
      expect(
        json['event_id_range'],
        equals(<String, Object?>{'first_seq': 7, 'last_seq': 9}),
      );
      final decoded = FifoEntry.fromJson(json);
      expect(decoded.eventIdRange, (firstSeq: 7, lastSeq: 9));
    });

    // Verifies: REQ-d00128-B — fromJson rejects a missing or malformed
    // event_id_range field.
    test(
      'REQ-d00128-B: fromJson rejects missing or malformed event_id_range',
      () {
        final base = makeBatch().toJson();

        final missing = Map<String, Object?>.from(base)
          ..remove('event_id_range');
        expect(() => FifoEntry.fromJson(missing), throwsFormatException);

        final wrongType = Map<String, Object?>.from(base)
          ..['event_id_range'] = 'oops';
        expect(() => FifoEntry.fromJson(wrongType), throwsFormatException);

        final missingFirst = Map<String, Object?>.from(base)
          ..['event_id_range'] = <String, Object?>{'last_seq': 5};
        expect(() => FifoEntry.fromJson(missingFirst), throwsFormatException);

        final missingLast = Map<String, Object?>.from(base)
          ..['event_id_range'] = <String, Object?>{'first_seq': 5};
        expect(() => FifoEntry.fromJson(missingLast), throwsFormatException);

        final nonIntSeq = Map<String, Object?>.from(base)
          ..['event_id_range'] = <String, Object?>{
            'first_seq': 1,
            'last_seq': '2',
          };
        expect(() => FifoEntry.fromJson(nonIntSeq), throwsFormatException);
      },
    );

    // Verifies: REQ-d00128-C — wirePayload is one payload for the entire
    // batch; no per-event payload is stored.
    test(
      'REQ-d00128-C: wirePayload is a single map covering the whole batch',
      () {
        final entry = makeBatch(
          eventIds: const ['ev-a', 'ev-b'],
          wirePayload: const <String, Object?>{
            'events': [
              <String, Object?>{'id': 'ev-a'},
              <String, Object?>{'id': 'ev-b'},
            ],
          },
        );
        expect(entry.wirePayload, isA<Map<String, Object?>>());
        expect(entry.wirePayload['events'], isA<List<Object?>>());
        expect((entry.wirePayload['events']! as List).length, 2);
      },
    );

    // Verifies: REQ-d00128-A+B+C — the new shape round-trips cleanly
    // through toJson/fromJson without losing any of the three new/changed
    // fields, and the legacy single-event 'event_id' scalar key is NOT
    // emitted (no backward-compat shim).
    test('REQ-d00128-A+B+C: JSON round-trip preserves new shape and does not '
        'emit legacy event_id scalar', () {
      final entry = makeBatch(
        eventIds: const ['ev-a', 'ev-b'],
        eventIdRange: (firstSeq: 20, lastSeq: 21),
      );
      final json = entry.toJson();
      expect(json.containsKey('event_id'), isFalse);
      expect(json['event_ids'], ['ev-a', 'ev-b']);
      expect(json['event_id_range'], <String, Object?>{
        'first_seq': 20,
        'last_seq': 21,
      });
      final decoded = FifoEntry.fromJson(json);
      expect(decoded.eventIds, ['ev-a', 'ev-b']);
      expect(decoded.eventIdRange, (firstSeq: 20, lastSeq: 21));
      expect(decoded, equals(entry));
    });

    // Verifies: equality still covers the new eventIds and eventIdRange
    // fields; two entries that differ only in eventIds are NOT equal.
    test('equality distinguishes entries differing only in eventIds', () {
      final a = makeBatch(eventIds: const ['ev-x']);
      final b = makeBatch(eventIds: const ['ev-y']);
      expect(a, isNot(equals(b)));
    });

    test('equality distinguishes entries differing only in eventIdRange', () {
      final a = makeBatch(eventIdRange: (firstSeq: 1, lastSeq: 1));
      final b = makeBatch(eventIdRange: (firstSeq: 2, lastSeq: 2));
      expect(a, isNot(equals(b)));
    });

    test('parsed eventIds list is unmodifiable', () {
      final decoded = FifoEntry.fromJson(makeBatch().toJson());
      expect(() => decoded.eventIds.add('x'), throwsUnsupportedError);
    });
  });
}
