import 'dart:math';

/// Retry-curve and timing constants for the per-destination FIFO drain.
///
/// These values are static module-level constants because changing them at
/// runtime would produce a user experience where one entry's retry
/// schedule mixes two curves. Curve changes require a spec amendment and
/// a coordinated app release (REQ-d00123 rationale).
///
/// Curve shape: `initialBackoff * backoffMultiplier^attemptCount`, capped
/// at `maxBackoff`, shaken by `±jitterFraction` multiplicative jitter to
/// avoid synchronized retry storms.
// Implements: REQ-d00123-A..F — constants and backoff curve.
class SyncPolicy {
  SyncPolicy._();

  /// First retry backoff: 60 seconds.
  // Implements: REQ-d00123-A.
  static const Duration initialBackoff = Duration(seconds: 60);

  /// Per-attempt multiplier: 5.0.
  // Implements: REQ-d00123-B.
  static const double backoffMultiplier = 5.0;

  /// Cap on the computed backoff: 2 hours.
  // Implements: REQ-d00123-C.
  static const Duration maxBackoff = Duration(hours: 2);

  /// Fraction of the base backoff applied as uniform ±jitter: 0.1 (±10%).
  // Implements: REQ-d00123-D.
  static const double jitterFraction = 0.1;

  /// Per-entry lifetime attempt cap: 20 attempts (~1 week at cap).
  // Implements: REQ-d00123-E.
  static const int maxAttempts = 20;

  /// Foreground sync-cycle cadence: 15 minutes.
  // Implements: REQ-d00123-F.
  static const Duration periodicInterval = Duration(minutes: 15);

  /// Returns the backoff for the [attemptCount]-th attempt (0-based).
  ///
  /// Formula: `baseline = min(initialBackoff * multiplier^n, maxBackoff)`,
  /// then apply `±jitterFraction` multiplicative jitter:
  ///
  ///     backoff = baseline * (1 + uniform(-jitterFraction, jitterFraction))
  ///
  /// Pass a [random] for deterministic jitter in tests; production passes
  /// `null` (a process-wide default `Random` is used).
  // Implements: REQ-d00123-A+B+C+D — curve shape, cap, and jitter.
  static Duration backoffFor(int attemptCount, {Random? random}) {
    if (attemptCount < 0) {
      throw ArgumentError.value(
        attemptCount,
        'attemptCount',
        'attemptCount must be non-negative',
      );
    }
    final baselineMs =
        initialBackoff.inMilliseconds * pow(backoffMultiplier, attemptCount);
    final capMs = maxBackoff.inMilliseconds.toDouble();
    final clampedMs = baselineMs > capMs ? capMs : baselineMs;
    final r = random ?? _defaultRandom;
    // uniform in (-jitterFraction, +jitterFraction)
    final jitter = (r.nextDouble() * 2 - 1) * jitterFraction;
    final ms = (clampedMs * (1 + jitter)).round();
    return Duration(milliseconds: ms);
  }

  static final Random _defaultRandom = Random();
}
