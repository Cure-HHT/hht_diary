// test/walkthroughs/walkthrough_10_reset_test.dart
//
// Verifies: reset semantics — a fresh ephemeral harness starts with the
// seed state only (4 directory entries, 9 matrix grants, no user-emitted
// events). The actual /_demo/reset HTTP endpoint requires lib-level
// support for in-process wipe-and-reseed and is deferred — for this
// walkthrough, harness restart serves the same purpose.

import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'test_support/demo_server_harness.dart';

void main() {
  group('Walkthrough 10: Reset all', () {
    test(
      'fresh ephemeral harness has seed state only (no carry-over from prior process)',
      () async {
        // Round 1: dispatch a few actions, accumulate events.
        final h1 = await DemoServerHarness.start();
        try {
          await h1.dispatch(
            actionName: 'PressGreenButtonAction',
            rawInput: const <String, Object?>{},
            userId: 'green-user-1',
          );
          await h1.dispatch(
            actionName: 'PressGreenButtonAction',
            rawInput: const <String, Object?>{},
            userId: 'green-user-1',
          );
          await h1.dispatch(
            actionName: 'PressRedAlarmAction',
            rawInput: <String, Object?>{'reason': 'fire'},
            idempotencyKey: const Uuid().v4(),
            userId: 'green-user-1',
          );

          final s1 = await h1.inspect();
          expect(
            s1.events.where((e) => e.eventType == 'green_button_pressed'),
            hasLength(2),
          );
          expect(
            s1.events.where((e) => e.eventType == 'red_alarm_pressed'),
            hasLength(1),
          );
          // Idempotency cache has at least one entry.
          expect(s1.idempotency, isNotEmpty);
        } finally {
          await h1.stop();
        }

        // Round 2: fresh harness.
        final h2 = await DemoServerHarness.start();
        try {
          final s2 = await h2.inspect();
          // No carry-over events from h1.
          expect(
            s2.events.where((e) => e.eventType == 'green_button_pressed'),
            isEmpty,
          );
          expect(
            s2.events.where((e) => e.eventType == 'red_alarm_pressed'),
            isEmpty,
          );
          // Seed events ARE present: matrix grants + user provisioned + system bootstrap.
          expect(s2.matrixGrants, hasLength(9));
          expect(s2.directory, hasLength(4));
          // Idempotency cache empty.
          expect(s2.idempotency, isEmpty);
          // Seed-emitted user_provisioned events are present.
          expect(
            s2.events.where((e) => e.eventType == 'user_provisioned'),
            hasLength(4),
          );
        } finally {
          await h2.stop();
        }
      },
    );

    test(
      '/_demo/reset endpoint returns 501 (in-process reset deferred)',
      () async {
        final harness = await DemoServerHarness.start();
        try {
          final r = await harness.client.post(
            Uri.parse('${harness.baseUrl}/_demo/reset'),
            headers: const <String, String>{'content-type': 'application/json'},
            body: '{}',
          );
          expect(r.statusCode, 501);
          expect(r.body, contains('restart with --ephemeral'));
        } finally {
          await harness.stop();
        }
      },
    );
  });
}
