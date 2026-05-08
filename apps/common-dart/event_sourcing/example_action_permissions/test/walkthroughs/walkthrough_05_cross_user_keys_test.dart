// test/walkthroughs/walkthrough_05_cross_user_keys_test.dart
//
// Verifies: REQ-d00170-D — idempotency cache key includes principalId,
// so two different principals can use the same idempotency key without
// collision.

import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support/demo_server_harness.dart';

void main() {
  late DemoServerHarness harness;

  setUp(() async {
    harness = await DemoServerHarness.start();
  });

  tearDown(() async {
    await harness.stop();
  });

  group('Walkthrough 5: Cross-user idempotency-store independence', () {
    test(
      'same idempotency key from two different principals -> two distinct successes',
      () async {
        const sharedKey = 'shared-key-12345';

        final r1 = await harness.dispatch(
          actionName: 'PressRedAlarmAction',
          rawInput: <String, Object?>{'reason': 'first'},
          idempotencyKey: sharedKey,
          userId: 'green-user-1',
        );
        final r2 = await harness.dispatch(
          actionName: 'PressRedAlarmAction',
          rawInput: <String, Object?>{'reason': 'second'},
          idempotencyKey: sharedKey,
          userId: 'green-user-2',
        );

        expect(r1, isA<DispatchResponseSuccess>());
        expect(r2, isA<DispatchResponseSuccess>());
        final s1 = r1 as DispatchResponseSuccess;
        final s2 = r2 as DispatchResponseSuccess;
        // Distinct emittedEventIds — neither dispatch hit the other's cache.
        expect(s1.emittedEventIds, isNot(equals(s2.emittedEventIds)));

        final snap = await harness.inspect();

        // Two red_alarm_pressed events in the log.
        final alarms = snap.events
            .where((e) => e.eventType == 'red_alarm_pressed')
            .toList();
        expect(alarms, hasLength(2));

        // Two idempotency cache entries — same key, different principalUserId.
        final idem = snap.idempotency
            .where(
              (e) =>
                  e.actionName == 'PressRedAlarmAction' &&
                  e.idempotencyKey == sharedKey,
            )
            .toList();
        expect(idem, hasLength(2));
        expect(idem.map((e) => e.principalUserId).toSet(), <String>{
          'green-user-1',
          'green-user-2',
        });
      },
    );

    test(
      'one principal replays its own key -> idempotencyHit; the other principal still gets fresh success',
      () async {
        const sharedKey = 'shared-key-67890';

        final r1a = await harness.dispatch(
          actionName: 'PressRedAlarmAction',
          rawInput: <String, Object?>{'reason': 'g1-first'},
          idempotencyKey: sharedKey,
          userId: 'green-user-1',
        );
        final r1b = await harness.dispatch(
          // green-user-1 replays — should hit cache.
          actionName: 'PressRedAlarmAction',
          rawInput: <String, Object?>{'reason': 'g1-replay'},
          idempotencyKey: sharedKey,
          userId: 'green-user-1',
        );
        final r2 = await harness.dispatch(
          // green-user-2 first dispatch — should NOT hit g1's cache.
          actionName: 'PressRedAlarmAction',
          rawInput: <String, Object?>{'reason': 'g2-first'},
          idempotencyKey: sharedKey,
          userId: 'green-user-2',
        );

        expect(r1a, isA<DispatchResponseSuccess>());
        expect(r1b, isA<DispatchResponseIdempotencyHit>());
        expect(r2, isA<DispatchResponseSuccess>());

        // Two red_alarm_pressed events: r1a and r2 (r1b was a cache hit).
        final alarms = (await harness.inspect()).events
            .where((e) => e.eventType == 'red_alarm_pressed')
            .toList();
        expect(alarms, hasLength(2));
      },
    );
  });
}
