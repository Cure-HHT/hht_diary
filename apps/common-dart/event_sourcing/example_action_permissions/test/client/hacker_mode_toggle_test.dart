// test/client/hacker_mode_toggle_test.dart
import 'package:action_permissions_demo/client/hacker_mode_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HackerMode', () {
    test('starts disabled', () {
      expect(HackerMode().enabled, isFalse);
    });

    test('set(true) notifies once; set(true) again is a no-op', () {
      final mode = HackerMode();
      var notified = 0;
      mode.addListener(() => notified++);
      mode.set(true);
      mode.set(true);
      expect(mode.enabled, isTrue);
      expect(notified, 1);
    });

    test('toggle flips and notifies', () {
      final mode = HackerMode();
      var notified = 0;
      mode.addListener(() => notified++);
      mode.toggle();
      mode.toggle();
      expect(mode.enabled, isFalse);
      expect(notified, 2);
    });
  });

  group('HackerModeToggle widget', () {
    testWidgets('shows Switch reflecting current state; tapping flips', (
      tester,
    ) async {
      final mode = HackerMode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HackerModeToggle(mode: mode)),
        ),
      );
      expect(find.text('Hacker mode'), findsOneWidget);
      expect(find.text('(client gating bypassed)'), findsNothing);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(mode.enabled, isTrue);
      expect(find.text('(client gating bypassed)'), findsOneWidget);
    });
  });
}
