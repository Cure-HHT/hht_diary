import 'package:append_only_datastore/src/storage/append_result.dart';
import 'package:append_only_datastore/src/storage/attempt_result.dart';
import 'package:append_only_datastore/src/storage/diary_entry.dart';
import 'package:append_only_datastore/src/storage/exhausted_fifo_summary.dart';
import 'package:append_only_datastore/src/storage/fifo_entry.dart';
import 'package:append_only_datastore/src/storage/final_status.dart';
import 'package:append_only_datastore/src/storage/send_result.dart';
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
    // Verifies: REQ-d00119-C — exactly three legal values: pending, sent,
    // exhausted.
    test('REQ-d00119-C: FinalStatus has exactly three values', () {
      expect(FinalStatus.values.length, 3);
    });

    // Verifies: REQ-d00119-C — value names match the wire-format strings.
    test('REQ-d00119-C: value names are pending|sent|exhausted', () {
      expect(FinalStatus.pending.name, 'pending');
      expect(FinalStatus.sent.name, 'sent');
      expect(FinalStatus.exhausted.name, 'exhausted');
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
        eventId: 'event-1',
        sequenceInQueue: 1,
        wirePayload: const <String, Object?>{'k': 'v'},
        wireFormat: 'json-v1',
        transformVersion: 'transform-v1',
        enqueuedAt: enqueuedAt,
        attempts: attempts ?? const <AttemptResult>[],
        finalStatus: status ?? FinalStatus.pending,
        sentAt: sentAt,
      );
    }

    // Verifies: REQ-d00119-B — all ten documented columns are present and
    // preserved across a JSON round-trip.
    test('REQ-d00119-B: round-trip preserves all ten fields', () {
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
      expect(decoded.eventId, 'event-1');
      expect(decoded.sequenceInQueue, 1);
      expect(decoded.wirePayload, {'k': 'v'});
      expect(decoded.wireFormat, 'json-v1');
      expect(decoded.transformVersion, 'transform-v1');
      expect(decoded.enqueuedAt, enqueuedAt);
      expect(decoded.attempts.length, 1);
      expect(decoded.finalStatus, FinalStatus.sent);
      expect(decoded.sentAt, attemptedAt);
    });

    // Verifies: REQ-d00119-C — final_status is the FinalStatus enum, not a raw
    // string; this prevents unchecked strings from sneaking past the type.
    test('REQ-d00119-C: final_status is typed as FinalStatus', () {
      final e = makeSample();
      expect(e.finalStatus, isA<FinalStatus>());
    });

    test('transform_version optional and round-trips as null', () {
      final e = FifoEntry(
        entryId: 'e',
        eventId: 'ev',
        sequenceInQueue: 0,
        wirePayload: const <String, Object?>{},
        wireFormat: 'json-v1',
        transformVersion: null,
        enqueuedAt: enqueuedAt,
        attempts: const <AttemptResult>[],
        finalStatus: FinalStatus.pending,
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
