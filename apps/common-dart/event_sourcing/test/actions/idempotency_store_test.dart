import 'package:event_sourcing/src/actions/idempotency_store.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryIdempotencyStore', () {
    late InMemoryIdempotencyStore store;

    setUp(() {
      store = InMemoryIdempotencyStore();
    });

    test('lookup miss returns null', () async {
      final entry = await store.lookup('a', 'p', 'k');
      expect(entry, isNull);
    });

    test('REQ-d00170-D: record then lookup returns cached entry', () async {
      await store.record(
        actionName: 'a',
        principalId: 'p',
        key: 'k',
        resultJson: const {'x': 1},
        emittedEventIds: const ['evt-1'],
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      final entry = await store.lookup('a', 'p', 'k');
      expect(entry, isNotNull);
      expect(entry!.resultJson['x'], 1);
      expect(entry.emittedEventIds, ['evt-1']);
    });

    test('lookup with different key misses', () async {
      await store.record(
        actionName: 'a',
        principalId: 'p',
        key: 'k',
        resultJson: const {},
        emittedEventIds: const [],
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      expect(await store.lookup('a', 'p', 'other'), isNull);
    });

    test('lookup with different principal misses', () async {
      await store.record(
        actionName: 'a',
        principalId: 'p1',
        key: 'k',
        resultJson: const {},
        emittedEventIds: const [],
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      expect(await store.lookup('a', 'p2', 'k'), isNull);
    });

    test('lookup with different action misses', () async {
      await store.record(
        actionName: 'a',
        principalId: 'p',
        key: 'k',
        resultJson: const {},
        emittedEventIds: const [],
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      expect(await store.lookup('b', 'p', 'k'), isNull);
    });

    test('REQ-d00170-E: sweepExpired removes past entries', () async {
      await store.record(
        actionName: 'a',
        principalId: 'p',
        key: 'old',
        resultJson: const {},
        emittedEventIds: const [],
        expiresAt: DateTime.parse('2026-01-01T00:00:00Z'),
      );
      await store.record(
        actionName: 'a',
        principalId: 'p',
        key: 'fresh',
        resultJson: const {},
        emittedEventIds: const [],
        expiresAt: DateTime.parse('2099-01-01T00:00:00Z'),
      );
      final swept = await store.sweepExpired(
        before: DateTime.parse('2026-06-01T00:00:00Z'),
      );
      expect(swept, 1);
      expect(await store.lookup('a', 'p', 'old'), isNull);
      expect(await store.lookup('a', 'p', 'fresh'), isNotNull);
    });

    test('expired lookup returns null even before sweep', () async {
      await store.record(
        actionName: 'a',
        principalId: 'p',
        key: 'k',
        resultJson: const {},
        emittedEventIds: const [],
        expiresAt: DateTime.parse('2026-01-01T00:00:00Z'),
      );
      final entry = await store.lookup(
        'a',
        'p',
        'k',
        now: DateTime.parse('2026-06-01T00:00:00Z'),
      );
      expect(entry, isNull);
    });
  });
}
