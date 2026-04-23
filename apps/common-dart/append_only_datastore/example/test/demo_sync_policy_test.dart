import 'package:append_only_datastore/append_only_datastore.dart';
import 'package:append_only_datastore_demo/demo_sync_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('demoDefaultSyncPolicy (REQ-d00126 + design §7.7)', () {
    // Verifies: REQ-d00126 — SyncPolicy is a value object; demo defaults
    //   per design §7.7 (short backoff so retry behavior is observable
    //   live without waiting minutes).
    test('initialBackoff is 1 second', () {
      expect(demoDefaultSyncPolicy.initialBackoff, const Duration(seconds: 1));
    });
    test('backoffMultiplier is 1.0 (flat curve)', () {
      expect(demoDefaultSyncPolicy.backoffMultiplier, 1.0);
    });
    test('maxBackoff is 10 seconds', () {
      expect(demoDefaultSyncPolicy.maxBackoff, const Duration(seconds: 10));
    });
    test('jitterFraction is 0.0 (no jitter, deterministic demo)', () {
      expect(demoDefaultSyncPolicy.jitterFraction, 0.0);
    });
    test('maxAttempts is 1_000_000 (effectively unbounded for demo)', () {
      expect(demoDefaultSyncPolicy.maxAttempts, 1000000);
    });
  });

  group('demoPolicyNotifier (REQ-d00126 injection)', () {
    // Verifies: REQ-d00126 — the policy is injectable; the demo exposes
    //   a process-wide ValueNotifier so the slider bar at Task 12 can
    //   hot-swap it.
    test('initial value equals demoDefaultSyncPolicy', () {
      final n = demoPolicyNotifier;
      expect(n.value, demoDefaultSyncPolicy);
    });
    test('is a ValueNotifier<SyncPolicy>', () {
      expect(demoPolicyNotifier, isA<ValueNotifier<SyncPolicy>>());
    });
    test('mutating .value notifies listeners', () {
      // Use a fresh local notifier so this test does not leak to others.
      final local = ValueNotifier<SyncPolicy>(demoDefaultSyncPolicy);
      var calls = 0;
      void listener() => calls++;
      local.addListener(listener);
      addTearDown(() => local.removeListener(listener));
      local.value = const SyncPolicy(
        initialBackoff: Duration(milliseconds: 500),
        backoffMultiplier: 2.0,
        maxBackoff: Duration(seconds: 5),
        jitterFraction: 0.1,
        maxAttempts: 3,
        periodicInterval: Duration(seconds: 5),
      );
      expect(calls, 1);
    });
  });
}
