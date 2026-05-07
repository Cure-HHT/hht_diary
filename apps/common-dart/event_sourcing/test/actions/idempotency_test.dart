import 'package:event_sourcing/src/actions/idempotency.dart';
import 'package:test/test.dart';

void main() {
  group('Idempotency enum', () {
    test('REQ-d00170-A,B,C: has three variants', () {
      expect(Idempotency.values, hasLength(3));
      expect(Idempotency.values, contains(Idempotency.none));
      expect(Idempotency.values, contains(Idempotency.optional));
      expect(Idempotency.values, contains(Idempotency.required));
    });
  });

  group('IdempotencyEntry', () {
    test('round-trips fields', () {
      final entry = IdempotencyEntry(
        resultJson: const {'ok': true, 'id': 'abc'},
        emittedEventIds: const ['evt-1', 'evt-2'],
        recordedAt: DateTime.parse('2026-04-22T10:00:00Z'),
        expiresAt: DateTime.parse('2026-04-23T10:00:00Z'),
      );
      expect(entry.resultJson['ok'], isTrue);
      expect(entry.emittedEventIds, hasLength(2));
      expect(
        entry.expiresAt.difference(entry.recordedAt),
        const Duration(hours: 24),
      );
    });

    test('isExpired returns true when expiresAt < now', () {
      final entry = IdempotencyEntry(
        resultJson: const {},
        emittedEventIds: const [],
        recordedAt: DateTime.parse('2026-01-01T00:00:00Z'),
        expiresAt: DateTime.parse('2026-01-02T00:00:00Z'),
      );
      expect(
        entry.isExpired(now: DateTime.parse('2026-01-03T00:00:00Z')),
        isTrue,
      );
    });

    test('isExpired returns false when expiresAt > now', () {
      final entry = IdempotencyEntry(
        resultJson: const {},
        emittedEventIds: const [],
        recordedAt: DateTime.parse('2026-01-01T00:00:00Z'),
        expiresAt: DateTime.parse('2026-01-10T00:00:00Z'),
      );
      expect(
        entry.isExpired(now: DateTime.parse('2026-01-05T00:00:00Z')),
        isFalse,
      );
    });
  });

  group('defaultIdempotencyTtl', () {
    test('REQ-d00170-F: defaults to 24 hours', () {
      expect(defaultIdempotencyTtl, const Duration(hours: 24));
    });
  });
}
