import 'package:append_only_datastore/src/materialization/materializer.dart';
import 'package:append_only_datastore/src/storage/diary_entry.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

void main() {
  EntryTypeDefinition defFor(String id, {String? effectiveDatePath}) =>
      EntryTypeDefinition(
        id: id,
        version: '1',
        name: id,
        widgetId: 'epistaxis_form_v1',
        widgetConfig: const <String, Object?>{},
        effectiveDatePath: effectiveDatePath,
      );

  StoredEvent makeEvent({
    String eventId = 'event-1',
    String aggregateId = 'aggregate-1',
    String entryType = 'epistaxis_event',
    String eventType = 'finalized',
    int sequenceNumber = 1,
    Map<String, dynamic>? data,
    DateTime? clientTimestamp,
  }) {
    return StoredEvent(
      key: sequenceNumber,
      eventId: eventId,
      aggregateId: aggregateId,
      aggregateType: 'DiaryEntry',
      entryType: entryType,
      eventType: eventType,
      sequenceNumber: sequenceNumber,
      data: data ?? <String, dynamic>{'answers': <String, Object?>{}},
      metadata: const <String, dynamic>{},
      userId: 'user-1',
      deviceId: 'device-1',
      clientTimestamp:
          clientTimestamp ?? DateTime.parse('2026-04-22T10:00:00Z'),
      eventHash: 'hash-$eventId',
    );
  }

  final firstTs = DateTime.parse('2026-04-22T10:00:00Z');

  group('Materializer.apply finalized event', () {
    // Verifies: REQ-d00121-B+E — finalized sets is_complete=true, whole-
    // replaces current_answers, stamps latest_event_id and updated_at.
    test(
      'REQ-d00121-B+E: finalized-from-scratch produces a complete, non-deleted '
      'row with event-sourced fields',
      () {
        final event = makeEvent(
          eventId: 'e1',
          eventType: 'finalized',
          data: <String, dynamic>{
            'answers': <String, Object?>{
              'startTime': '2026-04-22T10:00:00Z',
              'intensity': 'moderate',
            },
          },
        );
        final def = defFor('epistaxis_event');

        final entry = Materializer.apply(
          previous: null,
          event: event,
          def: def,
          firstEventTimestamp: firstTs,
        );

        expect(entry.entryId, 'aggregate-1');
        expect(entry.entryType, 'epistaxis_event');
        expect(entry.isComplete, isTrue);
        expect(entry.isDeleted, isFalse);
        expect(entry.currentAnswers, {
          'startTime': '2026-04-22T10:00:00Z',
          'intensity': 'moderate',
        });
        expect(entry.latestEventId, 'e1');
        expect(entry.updatedAt, event.clientTimestamp);
      },
    );

    // Verifies: REQ-d00121-B — finalized whole-replaces current_answers;
    // fields present in previous row but absent from event are dropped.
    test(
      'REQ-d00121-B: finalized-over-existing whole-replaces current_answers; '
      'fields in previous but absent in event are dropped',
      () {
        final previous = DiaryEntry(
          entryId: 'aggregate-1',
          entryType: 'epistaxis_event',
          effectiveDate: DateTime.parse('2026-04-20T00:00:00Z'),
          currentAnswers: const <String, Object?>{
            'startTime': '2026-04-20T10:00:00Z',
            'intensity': 'mild',
            'notes': 'earlier note',
          },
          isComplete: true,
          isDeleted: false,
          latestEventId: 'e-prev',
          updatedAt: DateTime.parse('2026-04-20T10:00:00Z'),
        );
        final event = makeEvent(
          eventId: 'e-new',
          eventType: 'finalized',
          clientTimestamp: DateTime.parse('2026-04-22T11:00:00Z'),
          data: <String, dynamic>{
            'answers': <String, Object?>{
              'startTime': '2026-04-22T11:00:00Z',
              'intensity': 'moderate',
            },
          },
        );

        final entry = Materializer.apply(
          previous: previous,
          event: event,
          def: defFor('epistaxis_event'),
          firstEventTimestamp: firstTs,
        );

        expect(entry.currentAnswers, {
          'startTime': '2026-04-22T11:00:00Z',
          'intensity': 'moderate',
        });
        expect(entry.currentAnswers.containsKey('notes'), isFalse);
        expect(entry.isComplete, isTrue);
        expect(entry.updatedAt, event.clientTimestamp);
        expect(entry.latestEventId, 'e-new');
      },
    );
  });

  group('Materializer.apply checkpoint event', () {
    // Verifies: REQ-d00121-C — checkpoint sets is_complete=false and whole-
    // replaces current_answers with event.data.answers.
    test(
      'REQ-d00121-C: checkpoint-from-scratch produces is_complete=false with '
      'event answers',
      () {
        final event = makeEvent(
          eventId: 'e1',
          eventType: 'checkpoint',
          data: <String, dynamic>{
            'answers': <String, Object?>{'startTime': '2026-04-22T10:00:00Z'},
          },
        );

        final entry = Materializer.apply(
          previous: null,
          event: event,
          def: defFor('epistaxis_event'),
          firstEventTimestamp: firstTs,
        );

        expect(entry.isComplete, isFalse);
        expect(entry.isDeleted, isFalse);
        expect(entry.currentAnswers, {'startTime': '2026-04-22T10:00:00Z'});
        expect(entry.latestEventId, 'e1');
      },
    );
  });

  group('Materializer.apply tombstone event', () {
    // Verifies: REQ-d00121-D+E — tombstone flips is_deleted=true, carries
    // over current_answers and is_complete, stamps latest_event_id/updated_at.
    test(
      'REQ-d00121-D: tombstone-over-existing flips is_deleted, preserves other '
      'fields',
      () {
        final previous = DiaryEntry(
          entryId: 'aggregate-1',
          entryType: 'epistaxis_event',
          effectiveDate: DateTime.parse('2026-04-20T00:00:00Z'),
          currentAnswers: const <String, Object?>{
            'startTime': '2026-04-20T10:00:00Z',
            'intensity': 'moderate',
          },
          isComplete: true,
          isDeleted: false,
          latestEventId: 'e-prev',
          updatedAt: DateTime.parse('2026-04-20T10:00:00Z'),
        );
        final event = makeEvent(
          eventId: 'e-tomb',
          eventType: 'tombstone',
          clientTimestamp: DateTime.parse('2026-04-22T12:00:00Z'),
          data: <String, dynamic>{'answers': <String, Object?>{}},
        );

        final entry = Materializer.apply(
          previous: previous,
          event: event,
          def: defFor('epistaxis_event'),
          firstEventTimestamp: firstTs,
        );

        expect(entry.isDeleted, isTrue);
        expect(entry.isComplete, isTrue, reason: 'carried over from previous');
        expect(entry.currentAnswers, previous.currentAnswers);
        expect(
          entry.effectiveDate,
          previous.effectiveDate,
          reason: 'preserved',
        );
        expect(entry.latestEventId, 'e-tomb', reason: 'REQ-d00121-E');
        expect(entry.updatedAt, event.clientTimestamp, reason: 'REQ-d00121-E');
      },
    );

    // Verifies: REQ-d00121-D — tombstone with no previous row yields an
    // empty is_deleted=true row rather than rejecting the event.
    test(
      'REQ-d00121-D: tombstone-from-scratch is accepted and produces an empty '
      'deleted row',
      () {
        final event = makeEvent(
          eventId: 'e-tomb',
          eventType: 'tombstone',
          data: <String, dynamic>{'answers': <String, Object?>{}},
        );

        final entry = Materializer.apply(
          previous: null,
          event: event,
          def: defFor('epistaxis_event'),
          firstEventTimestamp: firstTs,
        );

        expect(entry.isDeleted, isTrue);
        expect(entry.isComplete, isFalse);
        expect(entry.currentAnswers, isEmpty);
        expect(entry.latestEventId, 'e-tomb');
      },
    );
  });

  group('Materializer.apply effective_date resolution', () {
    // Verifies: REQ-d00121-F — single-segment effective_date_path resolves
    // into current_answers and parses the value as a full DateTime.
    test(
      'REQ-d00121-F: def.effective_date_path resolves single-segment path in '
      'answers',
      () {
        final event = makeEvent(
          data: <String, dynamic>{
            'answers': <String, Object?>{
              'startTime': '2026-04-22T10:15:00Z',
              'intensity': 'moderate',
            },
          },
        );

        final entry = Materializer.apply(
          previous: null,
          event: event,
          def: defFor('epistaxis_event', effectiveDatePath: 'startTime'),
          firstEventTimestamp: firstTs,
        );

        expect(entry.effectiveDate, DateTime.parse('2026-04-22T10:15:00Z'));
      },
    );

    // Verifies: REQ-d00121-F — dotted-path effective_date_path traverses
    // nested current_answers maps.
    test(
      'REQ-d00121-F: def.effective_date_path resolves nested dotted path',
      () {
        final event = makeEvent(
          data: <String, dynamic>{
            'answers': <String, Object?>{
              'answers': <String, Object?>{'date': '2026-04-22'},
            },
          },
        );

        final entry = Materializer.apply(
          previous: null,
          event: event,
          def: defFor('nose_hht_survey', effectiveDatePath: 'answers.date'),
          firstEventTimestamp: firstTs,
        );

        expect(entry.effectiveDate, DateTime.parse('2026-04-22'));
      },
    );

    // Verifies: REQ-d00121-F — unresolved path falls back to
    // firstEventTimestamp rather than failing.
    test('REQ-d00121-F: falls back to firstEventTimestamp when path does not '
        'resolve in answers', () {
      final event = makeEvent(
        data: <String, dynamic>{'answers': <String, Object?>{}},
      );

      final entry = Materializer.apply(
        previous: null,
        event: event,
        def: defFor('epistaxis_event', effectiveDatePath: 'startTime'),
        firstEventTimestamp: DateTime.parse('2026-04-22T08:00:00Z'),
      );

      expect(entry.effectiveDate, DateTime.parse('2026-04-22T08:00:00Z'));
    });

    // Verifies: REQ-d00121-F — null effective_date_path falls back to
    // firstEventTimestamp.
    test('REQ-d00121-F: falls back to firstEventTimestamp when '
        'effective_date_path is null', () {
      final event = makeEvent(
        data: <String, dynamic>{
          'answers': <String, Object?>{'startTime': '2026-04-22T10:00:00Z'},
        },
      );

      final entry = Materializer.apply(
        previous: null,
        event: event,
        def: defFor('epistaxis_event'),
        firstEventTimestamp: DateTime.parse('2026-04-22T08:00:00Z'),
      );

      expect(entry.effectiveDate, DateTime.parse('2026-04-22T08:00:00Z'));
    });

    // Verifies: REQ-d00121-F — path resolves but value is not parseable as
    // DateTime; falls back to firstEventTimestamp.
    test(
      'REQ-d00121-F: falls back when resolved value is not parseable as a date',
      () {
        final event = makeEvent(
          data: <String, dynamic>{
            'answers': <String, Object?>{'startTime': 'not-a-date'},
          },
        );

        final entry = Materializer.apply(
          previous: null,
          event: event,
          def: defFor('epistaxis_event', effectiveDatePath: 'startTime'),
          firstEventTimestamp: DateTime.parse('2026-04-22T08:00:00Z'),
        );

        expect(entry.effectiveDate, DateTime.parse('2026-04-22T08:00:00Z'));
      },
    );
  });

  group('Materializer.apply purity', () {
    // Verifies: REQ-d00121-A — Materializer.apply is pure; identical inputs
    // always produce identical (deep-equal) outputs.
    test('REQ-d00121-A: identical inputs produce identical outputs (deep '
        'equality, repeated call)', () {
      final event = makeEvent(
        eventType: 'finalized',
        data: <String, dynamic>{
          'answers': <String, Object?>{'intensity': 'moderate'},
        },
      );
      final def = defFor('epistaxis_event', effectiveDatePath: 'startTime');

      final first = Materializer.apply(
        previous: null,
        event: event,
        def: def,
        firstEventTimestamp: firstTs,
      );
      final second = Materializer.apply(
        previous: null,
        event: event,
        def: def,
        firstEventTimestamp: firstTs,
      );

      expect(first, equals(second));
    });
  });
}
