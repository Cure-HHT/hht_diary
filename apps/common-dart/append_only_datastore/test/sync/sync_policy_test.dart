import 'dart:math';

import 'package:append_only_datastore/src/sync/sync_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncPolicy.defaults constants', () {
    // Verifies: REQ-d00123-A — initialBackoff is 60 seconds.
    test('REQ-d00123-A: defaults.initialBackoff == Duration(seconds: 60)', () {
      expect(SyncPolicy.defaults.initialBackoff, const Duration(seconds: 60));
    });

    // Verifies: REQ-d00123-B — backoffMultiplier is 5.0.
    test('REQ-d00123-B: defaults.backoffMultiplier == 5.0', () {
      expect(SyncPolicy.defaults.backoffMultiplier, 5.0);
    });

    // Verifies: REQ-d00123-C — maxBackoff is 2 hours.
    test('REQ-d00123-C: defaults.maxBackoff == Duration(hours: 2)', () {
      expect(SyncPolicy.defaults.maxBackoff, const Duration(hours: 2));
    });

    // Verifies: REQ-d00123-D — jitterFraction is 0.1.
    test('REQ-d00123-D: defaults.jitterFraction == 0.1', () {
      expect(SyncPolicy.defaults.jitterFraction, 0.1);
    });

    // Verifies: REQ-d00123-E — maxAttempts is 20.
    test('REQ-d00123-E: defaults.maxAttempts == 20', () {
      expect(SyncPolicy.defaults.maxAttempts, 20);
    });

    // Verifies: REQ-d00123-F — periodicInterval is 15 minutes.
    test(
      'REQ-d00123-F: defaults.periodicInterval == Duration(minutes: 15)',
      () {
        expect(
          SyncPolicy.defaults.periodicInterval,
          const Duration(minutes: 15),
        );
      },
    );
  });

  group('REQ-d00126-A: SyncPolicy is a value class', () {
    // Verifies: REQ-d00126-A — SyncPolicy has a const constructor and can be
    // instantiated with custom field values.
    test(
      'REQ-d00126-A: const constructor accepts all fields and exposes them',
      () {
        const custom = SyncPolicy(
          initialBackoff: Duration(seconds: 10),
          backoffMultiplier: 2.0,
          maxBackoff: Duration(minutes: 30),
          jitterFraction: 0.2,
          maxAttempts: 7,
          periodicInterval: Duration(minutes: 5),
        );
        expect(custom.initialBackoff, const Duration(seconds: 10));
        expect(custom.backoffMultiplier, 2.0);
        expect(custom.maxBackoff, const Duration(minutes: 30));
        expect(custom.jitterFraction, 0.2);
        expect(custom.maxAttempts, 7);
        expect(custom.periodicInterval, const Duration(minutes: 5));
      },
    );

    // Verifies: REQ-d00126-A — SyncPolicy.defaults is a static const instance.
    test('REQ-d00126-A: SyncPolicy.defaults is a static const instance', () {
      const ref = SyncPolicy.defaults;
      expect(ref, isA<SyncPolicy>());
      // Identity is preserved for a static const — same reference each access.
      expect(identical(SyncPolicy.defaults, ref), isTrue);
    });

    // Verifies: REQ-d00126-A — defaults values equal the REQ-d00123 constants.
    test(
      'REQ-d00126-A: defaults field values equal the REQ-d00123 constants',
      () {
        expect(SyncPolicy.defaults.initialBackoff, const Duration(seconds: 60));
        expect(SyncPolicy.defaults.backoffMultiplier, 5.0);
        expect(SyncPolicy.defaults.maxBackoff, const Duration(hours: 2));
        expect(SyncPolicy.defaults.jitterFraction, 0.1);
        expect(SyncPolicy.defaults.maxAttempts, 20);
        expect(
          SyncPolicy.defaults.periodicInterval,
          const Duration(minutes: 15),
        );
      },
    );
  });

  group('SyncPolicy.backoffFor (instance method)', () {
    // Deterministic fixed-seed Random produces reproducible jitter.
    Random seeded() => Random(42);

    Duration within10Percent(Duration base) =>
        Duration(milliseconds: (base.inMilliseconds * 0.1).round());

    void expectWithinJitter(
      Duration actual,
      Duration expectedBase, {
      String? reason,
    }) {
      final tolerance = within10Percent(expectedBase);
      final low = expectedBase - tolerance;
      final high = expectedBase + tolerance;
      expect(
        actual >= low && actual <= high,
        isTrue,
        reason:
            reason ??
            'expected $actual in [$low, $high] (±10% of $expectedBase)',
      );
    }

    // backoffFor(0) ≈ 60s ± 10%.
    test('backoffFor(0) ≈ 60s ± 10% jitter', () {
      final d = SyncPolicy.defaults.backoffFor(0, random: seeded());
      expectWithinJitter(d, const Duration(seconds: 60));
    });

    // backoffFor(1) ≈ 300s (60*5) ± 10%.
    test('backoffFor(1) ≈ 300s (60*5) ± 10%', () {
      final d = SyncPolicy.defaults.backoffFor(1, random: seeded());
      expectWithinJitter(d, const Duration(seconds: 300));
    });

    // backoffFor(2) ≈ 1500s (5m*5 = 25m) ± 10%.
    test('backoffFor(2) ≈ 1500s (60*5*5) ± 10%', () {
      final d = SyncPolicy.defaults.backoffFor(2, random: seeded());
      expectWithinJitter(d, const Duration(seconds: 1500));
    });

    // backoffFor(3) caps at 2h (raw would be 7500s > 7200s cap).
    test('backoffFor(3) ≈ capped at 7200s (2h) ± 10%', () {
      final d = SyncPolicy.defaults.backoffFor(3, random: seeded());
      expectWithinJitter(d, const Duration(hours: 2));
    });

    // backoffFor(n) for large n stays at the cap (± 10%).
    test('backoffFor(n) stays at cap for large n', () {
      for (final n in [3, 5, 10, 19, 20]) {
        final d = SyncPolicy.defaults.backoffFor(n, random: seeded());
        expectWithinJitter(
          d,
          const Duration(hours: 2),
          reason: 'backoffFor($n) should be at the 2h cap ± 10%; got $d',
        );
      }
    });

    // Jitter is deterministic when a seed is supplied.
    test('same seed produces the same jitter', () {
      final a = SyncPolicy.defaults.backoffFor(2, random: Random(7));
      final b = SyncPolicy.defaults.backoffFor(2, random: Random(7));
      expect(a, b);
    });

    // Jitter is actually applied (not identically zero). With 200 draws,
    // at least some should differ from the base by a non-trivial amount.
    test('jitter is actually applied (values vary across random seeds)', () {
      final values = <int>{};
      for (var i = 0; i < 200; i++) {
        final d = SyncPolicy.defaults.backoffFor(0, random: Random(i));
        values.add(d.inMilliseconds);
      }
      // If jitter were zero, every seed would produce the same value.
      expect(values.length, greaterThan(1));
    });

    // Jitter stays within ±10% — no draw exceeds those bounds, across many
    // seeds.
    test('jitter draws stay within ±jitterFraction bound', () {
      for (var i = 0; i < 500; i++) {
        final d = SyncPolicy.defaults.backoffFor(1, random: Random(i));
        expectWithinJitter(
          d,
          const Duration(seconds: 300),
          reason: 'seed=$i, got $d',
        );
      }
    });

    // Default (no seed) still returns a plausible value.
    test(
      'backoffFor without a seed returns a value within the jitter range',
      () {
        final d = SyncPolicy.defaults.backoffFor(0);
        expectWithinJitter(d, const Duration(seconds: 60));
      },
    );

    // Negative attemptCount is a caller bug; reject it rather than return
    // a degenerate near-zero backoff.
    test('backoffFor rejects negative attemptCount', () {
      expect(
        () => SyncPolicy.defaults.backoffFor(-1, random: seeded()),
        throwsArgumentError,
      );
    });

    // Verifies: REQ-d00126-A — a custom SyncPolicy instance reads the
    // curve from its own instance fields, not from the defaults.
    test('REQ-d00126-A: custom policy uses its own fields for backoffFor', () {
      const fast = SyncPolicy(
        initialBackoff: Duration(seconds: 1),
        backoffMultiplier: 2.0,
        maxBackoff: Duration(seconds: 10),
        jitterFraction: 0.0, // disable jitter for a deterministic check
        maxAttempts: 5,
        periodicInterval: Duration(minutes: 1),
      );
      expect(fast.backoffFor(0), const Duration(seconds: 1));
      expect(fast.backoffFor(1), const Duration(seconds: 2));
      expect(fast.backoffFor(2), const Duration(seconds: 4));
      expect(fast.backoffFor(3), const Duration(seconds: 8));
      // Capped:
      expect(fast.backoffFor(4), const Duration(seconds: 10));
      expect(fast.backoffFor(10), const Duration(seconds: 10));
    });
  });
}
