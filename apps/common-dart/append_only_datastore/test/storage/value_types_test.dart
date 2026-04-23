import 'package:append_only_datastore/src/storage/append_result.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/diary_entry.dart';
import 'package:append_only_datastore/src/storage/exhausted_fifo_summary.dart';
import 'package:append_only_datastore/src/storage/fifo_entry.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/send_result.dart';
import 'package:append_only_datastore/src/storage/stored_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppendResult', () {
    // Verifies: REQ-d00117-C — the result of appendEvent identifies the
    // sequence number that was advanced and the event_hash that was stamped.
    test('round-trip preserves sequence_number and event_hash', () {
      const a = AppendResult(sequenceNumber: 42, eventHash: 'abc123');
      final decoded = AppendResult.fromJson(a.toJson());
      expect(decoded, equals(a));
      expect(decoded.sequenceNumber, 42);
      expect(decoded.eventHash, 'abc123');
    });

    test('equals-by-value', () {
      const a = AppendResult(sequenceNumber: 1, eventHash: 'h');
      const b = AppendResult(sequenceNumber: 1, eventHash: 'h');
      const c = AppendResult(sequenceNumber: 2, eventHash: 'h');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('fromJson rejects missing sequence_number', () {
      expect(
        () => AppendResult.fromJson(const <String, Object?>{'event_hash': 'h'}),
        throwsFormatException,
      );
    });

    test('fromJson rejects non-string event_hash', () {
      expect(
        () => AppendResult.fromJson(const <String, Object?>{
          'sequence_number': 1,
          'event_hash': 42,
        }),
        throwsFormatException,
      );
    });
  });

  group('FinalStatus', () {
    // Verifies: REQ-d00119-C — exactly three legal non-null values:
    // sent, wedged, tombstoned. `null` (pre-terminal) is handled at
    // the FifoEntry.finalStatus level, not as an enum value here.
    test('REQ-d00119-C: FinalStatus has exactly three values', () {
      expect(FinalStatus.values.length, 3);
    });

    // Verifies: REQ-d00119-C — value names match the wire-format strings.
    test('REQ-d00119-C: value names are sent|wedged|tombstoned', () {
      expect(FinalStatus.sent.name, 'sent');
      expect(FinalStatus.wedged.name, 'wedged');
      expect(FinalStatus.tombstoned.name, 'tombstoned');
    });

    test('JSON round-trip via name', () {
      for (final v in FinalStatus.values) {
        expect(FinalStatus.fromJson(v.toJson()), equals(v));
      }
    });

    test('fromJson rejects unknown value', () {
      expect(() => FinalStatus.fromJson('failed'), throwsFormatException);
    });
  });

  group('AttemptResult', () {
    final sampleTime = DateTime.utc(2026, 4, 21, 15, 30, 45);

    test('round-trip preserves all four fields', () {
      final a = AttemptResult(
        attemptedAt: sampleTime,
        outcome: 'transient',
        errorMessage: 'socket timeout',
        httpStatus: 503,
      );
      final decoded = AttemptResult.fromJson(a.toJson());
      expect(decoded, equals(a));
      expect(decoded.attemptedAt, sampleTime);
      expect(decoded.outcome, 'transient');
      expect(decoded.errorMessage, 'socket timeout');
      expect(decoded.httpStatus, 503);
    });

    test('optional fields default to null', () {
      final a = AttemptResult(attemptedAt: sampleTime, outcome: 'ok');
      expect(a.errorMessage, isNull);
      expect(a.httpStatus, isNull);
    });

    test('toJson emits explicit nulls for optional fields', () {
      final a = AttemptResult(attemptedAt: sampleTime, outcome: 'ok');
      final json = a.toJson();
      expect(json.containsKey('error_message'), isTrue);
      expect(json['error_message'], isNull);
      expect(json.containsKey('http_status'), isTrue);
      expect(json['http_status'], isNull);
    });

    test('equals-by-value', () {
      final a = AttemptResult(attemptedAt: sampleTime, outcome: 'ok');
      final b = AttemptResult(attemptedAt: sampleTime, outcome: 'ok');
      final c = AttemptResult(attemptedAt: sampleTime, outcome: 'transient');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('fromJson rejects missing attempted_at', () {
      expect(
        () => AttemptResult.fromJson(const <String, Object?>{'outcome': 'ok'}),
        throwsFormatException,
      );
    });

    test('fromJson rejects missing outcome', () {
      expect(
        () => AttemptResult.fromJson(<String, Object?>{
          'attempted_at': sampleTime.toIso8601String(),
        }),
        throwsFormatException,
      );
    });
  });

  group('DiaryEntry', () {
    final sampleDate = DateTime.utc(2026, 4, 15);
    final sampleUpdated = DateTime.utc(2026, 4, 21, 10, 0, 0);

    DiaryEntry makeSample({
      Map<String, Object?>? answers,
      DateTime? effective,
      bool? deleted,
    }) {
      return DiaryEntry(
        entryId: 'entry-1',
        entryType: 'epistaxis_event',
        effectiveDate: effective ?? sampleDate,
        currentAnswers: answers ?? const <String, Object?>{'intensity': 'mild'},
        isComplete: true,
        isDeleted: deleted ?? false,
        latestEventId: 'event-42',
        updatedAt: sampleUpdated,
      );
    }

    test('round-trip preserves all eight fields', () {
      final e = makeSample();
      final decoded = DiaryEntry.fromJson(e.toJson());
      expect(decoded, equals(e));
      expect(decoded.entryId, 'entry-1');
      expect(decoded.entryType, 'epistaxis_event');
      expect(decoded.effectiveDate, sampleDate);
      expect(decoded.isComplete, isTrue);
      expect(decoded.isDeleted, isFalse);
      expect(decoded.latestEventId, 'event-42');
      expect(decoded.updatedAt, sampleUpdated);
    });

    test('effectiveDate may be null and round-trips as null', () {
      final e = DiaryEntry(
        entryId: 'entry-1',
        entryType: 'epistaxis_event',
        effectiveDate: null,
        currentAnswers: const <String, Object?>{'intensity': 'mild'},
        isComplete: true,
        isDeleted: false,
        latestEventId: 'event-42',
        updatedAt: sampleUpdated,
      );
      final decoded = DiaryEntry.fromJson(e.toJson());
      expect(decoded.effectiveDate, isNull);
      expect(decoded, equals(e));
    });

    test('deep-equality on currentAnswers', () {
      final a = makeSample(
        answers: <String, Object?>{
          'answers': <String, Object?>{'q1': 'yes', 'q2': 42},
        },
      );
      final b = makeSample(
        answers: <String, Object?>{
          'answers': <String, Object?>{'q1': 'yes', 'q2': 42},
        },
      );
      final c = makeSample(
        answers: <String, Object?>{
          'answers': <String, Object?>{'q1': 'yes', 'q2': 43},
        },
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('parsed currentAnswers is unmodifiable', () {
      final e = DiaryEntry.fromJson(makeSample().toJson());
      expect(() => e.currentAnswers['x'] = 1, throwsUnsupportedError);
    });

    test('fromJson rejects missing entry_id', () {
      final json = makeSample().toJson()..remove('entry_id');
      expect(() => DiaryEntry.fromJson(json), throwsFormatException);
    });

    test('fromJson rejects non-bool is_complete', () {
      final json = makeSample().toJson()..['is_complete'] = 'true';
      expect(() => DiaryEntry.fromJson(json), throwsFormatException);
    });
  });

  group('FifoEntry', () {
    final enqueuedAt = DateTime.utc(2026, 4, 21, 9);
    final attemptedAt = DateTime.utc(2026, 4, 21, 9, 1);

    FifoEntry makeSample({
      List<AttemptResult>? attempts,
      FinalStatus? status,
      DateTime? sentAt,
    }) {
      return FifoEntry(
        entryId: 'entry-1',
        // Phase-4.3 Task 6: batch shape — REQ-d00128-A + B.
        eventIds: const ['event-1'],
        eventIdRange: (firstSeq: 1, lastSeq: 1),
        sequenceInQueue: 1,
        wirePayload: const <String, Object?>{'k': 'v'},
        wireFormat: 'json-v1',
        transformVersion: 'transform-v1',
        enqueuedAt: enqueuedAt,
        attempts: attempts ?? const <AttemptResult>[],
        // Phase-4.7 Task 3: finalStatus is nullable; null means
        // pre-terminal. Pass `status: ...` to override to a terminal.
        finalStatus: status,
        sentAt: sentAt,
      );
    }

    // Verifies: REQ-d00119-B + REQ-d00128-A+B+C — the documented columns
    // are present and preserved across a JSON round-trip under the batch
    // shape: event_ids replaces event_id, event_id_range is persisted as
    // a first_seq/last_seq Map, and wire_payload covers the batch.
    test('REQ-d00119-B + REQ-d00128-A+B+C: round-trip preserves all columns '
        'under batch shape', () {
      final e = makeSample(
        attempts: [
          AttemptResult(
            attemptedAt: attemptedAt,
            outcome: 'transient',
            errorMessage: 'timeout',
            httpStatus: 503,
          ),
        ],
        status: FinalStatus.sent,
        sentAt: attemptedAt,
      );
      final decoded = FifoEntry.fromJson(e.toJson());
      expect(decoded, equals(e));
      expect(decoded.entryId, 'entry-1');
      expect(decoded.eventIds, ['event-1']);
      expect(decoded.eventIdRange, (firstSeq: 1, lastSeq: 1));
      expect(decoded.sequenceInQueue, 1);
      expect(decoded.wirePayload, {'k': 'v'});
      expect(decoded.wireFormat, 'json-v1');
      expect(decoded.transformVersion, 'transform-v1');
      expect(decoded.enqueuedAt, enqueuedAt);
      expect(decoded.attempts.length, 1);
      expect(decoded.finalStatus, FinalStatus.sent);
      expect(decoded.sentAt, attemptedAt);
    });

    // Verifies: REQ-d00119-C — final_status is typed as FinalStatus?
    // (nullable); a non-null value is an enum instance. Pre-terminal
    // rows carry null; a terminal row carries one of the three enum
    // values.
    test('REQ-d00119-C: final_status is typed as FinalStatus?', () {
      final pre = makeSample();
      expect(pre.finalStatus, isNull);
      final terminal = makeSample(status: FinalStatus.sent, sentAt: enqueuedAt);
      expect(terminal.finalStatus, isA<FinalStatus>());
    });

    test('transform_version optional and round-trips as null', () {
      final e = FifoEntry(
        entryId: 'e',
        eventIds: const ['ev'],
        eventIdRange: (firstSeq: 0, lastSeq: 0),
        sequenceInQueue: 0,
        wirePayload: const <String, Object?>{},
        wireFormat: 'json-v1',
        transformVersion: null,
        enqueuedAt: enqueuedAt,
        attempts: const <AttemptResult>[],
        finalStatus: null,
        sentAt: null,
      );
      final decoded = FifoEntry.fromJson(e.toJson());
      expect(decoded.transformVersion, isNull);
      expect(decoded.sentAt, isNull);
      expect(decoded, equals(e));
    });

    test('equals-by-value with nested wirePayload', () {
      final a = makeSample(
        attempts: [AttemptResult(attemptedAt: attemptedAt, outcome: 'ok')],
      );
      final b = makeSample(
        attempts: [AttemptResult(attemptedAt: attemptedAt, outcome: 'ok')],
      );
      final c = makeSample(
        attempts: [
          AttemptResult(attemptedAt: attemptedAt, outcome: 'transient'),
        ],
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('parsed wirePayload is unmodifiable', () {
      final e = FifoEntry.fromJson(makeSample().toJson());
      expect(() => e.wirePayload['x'] = 1, throwsUnsupportedError);
    });

    test('parsed attempts list is unmodifiable', () {
      final e = FifoEntry.fromJson(
        makeSample(
          attempts: [AttemptResult(attemptedAt: attemptedAt, outcome: 'ok')],
        ).toJson(),
      );
      expect(
        () => e.attempts.add(
          AttemptResult(attemptedAt: attemptedAt, outcome: 'ok'),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('SendResult', () {
    test('SendOk equals SendOk', () {
      expect(const SendOk(), equals(const SendOk()));
      expect(const SendOk().hashCode, const SendOk().hashCode);
    });

    test('SendTransient equals by error and httpStatus', () {
      const a = SendTransient(error: 'x', httpStatus: 503);
      const b = SendTransient(error: 'x', httpStatus: 503);
      const c = SendTransient(error: 'x', httpStatus: 504);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('SendPermanent equals by error', () {
      const a = SendPermanent(error: 'x');
      const b = SendPermanent(error: 'x');
      const c = SendPermanent(error: 'y');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('sealed exhaustiveness: switch without default compiles', () {
      // Canary test: the local `describe` switch below has no default arm,
      // so adding a fourth `SendResult` subclass causes this test file to
      // fail to compile. It is NOT a guarantee that every production switch
      // on SendResult stays exhaustive — those call sites must be audited
      // separately when a new subclass is added.
      String describe(SendResult r) => switch (r) {
        SendOk() => 'ok',
        SendTransient(error: final e) => 'transient:$e',
        SendPermanent(error: final e) => 'permanent:$e',
      };
      expect(describe(const SendOk()), 'ok');
      expect(describe(const SendTransient(error: 't')), 'transient:t');
      expect(describe(const SendPermanent(error: 'p')), 'permanent:p');
    });
  });

  group('StoredEvent.fromMap validation', () {
    final sampleMap = <String, Object?>{
      'event_id': 'ev-1',
      'aggregate_id': 'agg-1',
      'aggregate_type': 'DiaryEntry',
      'entry_type': 'epistaxis_event',
      'event_type': 'finalized',
      'sequence_number': 1,
      'data': <String, Object?>{'k': 'v'},
      'metadata': <String, Object?>{},
      'initiator': <String, Object?>{'type': 'user', 'user_id': 'u'},
      'flow_token': null,
      'client_timestamp': '2026-04-22T10:00:00Z',
      'event_hash': 'hash-1',
      'previous_event_hash': null,
      'synced_at': null,
    };

    test('happy-path round-trip through fromMap + toMap', () {
      final event = StoredEvent.fromMap(sampleMap, 42);
      expect(event.key, 42);
      expect(event.eventId, 'ev-1');
      expect(event.sequenceNumber, 1);
      expect(event.clientTimestamp, DateTime.utc(2026, 4, 22, 10));
      expect(event.previousEventHash, isNull);
      expect(event.syncedAt, isNull);
    });

    test('fromMap rejects missing event_id', () {
      final bad = Map<String, Object?>.from(sampleMap)..remove('event_id');
      expect(() => StoredEvent.fromMap(bad, 0), throwsFormatException);
    });

    test('fromMap rejects non-string aggregate_type', () {
      final bad = Map<String, Object?>.from(sampleMap)..['aggregate_type'] = 42;
      expect(() => StoredEvent.fromMap(bad, 0), throwsFormatException);
    });

    test('fromMap rejects non-int sequence_number', () {
      final bad = Map<String, Object?>.from(sampleMap)
        ..['sequence_number'] = '1';
      expect(() => StoredEvent.fromMap(bad, 0), throwsFormatException);
    });

    test('fromMap rejects missing data', () {
      final bad = Map<String, Object?>.from(sampleMap)..remove('data');
      expect(() => StoredEvent.fromMap(bad, 0), throwsFormatException);
    });

    test('fromMap rejects non-map data', () {
      final bad = Map<String, Object?>.from(sampleMap)..['data'] = 'not-a-map';
      expect(() => StoredEvent.fromMap(bad, 0), throwsFormatException);
    });

    test('fromMap accepts absent metadata and defaults to empty map', () {
      final noMetadata = Map<String, Object?>.from(sampleMap)
        ..remove('metadata');
      final event = StoredEvent.fromMap(noMetadata, 0);
      expect(event.metadata, isEmpty);
    });

    test('fromMap rejects non-map metadata', () {
      final bad = Map<String, Object?>.from(sampleMap)..['metadata'] = 7;
      expect(() => StoredEvent.fromMap(bad, 0), throwsFormatException);
    });

    test('fromMap rejects malformed client_timestamp', () {
      final bad = Map<String, Object?>.from(sampleMap)
        ..['client_timestamp'] = 'not-a-date';
      expect(() => StoredEvent.fromMap(bad, 0), throwsFormatException);
    });

    test('fromMap rejects non-string client_timestamp', () {
      final bad = Map<String, Object?>.from(sampleMap)
        ..['client_timestamp'] = 1234567890;
      expect(() => StoredEvent.fromMap(bad, 0), throwsFormatException);
    });

    test('fromMap rejects non-string previous_event_hash when present', () {
      final bad = Map<String, Object?>.from(sampleMap)
        ..['previous_event_hash'] = 123;
      expect(() => StoredEvent.fromMap(bad, 0), throwsFormatException);
    });

    test('fromMap rejects non-string synced_at when present', () {
      final bad = Map<String, Object?>.from(sampleMap)..['synced_at'] = 123;
      expect(() => StoredEvent.fromMap(bad, 0), throwsFormatException);
    });

    test('fromMap rejects malformed synced_at', () {
      final bad = Map<String, Object?>.from(sampleMap)..['synced_at'] = 'nope';
      expect(() => StoredEvent.fromMap(bad, 0), throwsFormatException);
    });
  });

  group('ExhaustedFifoSummary', () {
    final exhaustedAt = DateTime.utc(2026, 4, 21, 12);

    test('round-trip preserves all five fields', () {
      final s = ExhaustedFifoSummary(
        destinationId: 'primary',
        headEntryId: 'entry-99',
        headEventId: 'event-100',
        exhaustedAt: exhaustedAt,
        lastError: 'HTTP 400: bad request',
      );
      final decoded = ExhaustedFifoSummary.fromJson(s.toJson());
      expect(decoded, equals(s));
      expect(decoded.destinationId, 'primary');
      expect(decoded.headEntryId, 'entry-99');
      expect(decoded.headEventId, 'event-100');
      expect(decoded.exhaustedAt, exhaustedAt);
      expect(decoded.lastError, 'HTTP 400: bad request');
    });

    test('equals-by-value', () {
      final a = ExhaustedFifoSummary(
        destinationId: 'd',
        headEntryId: 'e',
        headEventId: 'ev',
        exhaustedAt: exhaustedAt,
        lastError: 'err',
      );
      final b = ExhaustedFifoSummary(
        destinationId: 'd',
        headEntryId: 'e',
        headEventId: 'ev',
        exhaustedAt: exhaustedAt,
        lastError: 'err',
      );
      final c = ExhaustedFifoSummary(
        destinationId: 'd2',
        headEntryId: 'e',
        headEventId: 'ev',
        exhaustedAt: exhaustedAt,
        lastError: 'err',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });
}
