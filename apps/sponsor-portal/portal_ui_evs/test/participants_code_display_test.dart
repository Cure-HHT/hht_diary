// Verifies: DIARY-GUI-show-linking-code/A
import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/activation_code_display.dart';
import 'package:portal_ui_evs/src/participants_screen_binding.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

/// pumpReactionWidget wraps a bare MaterialApp (no kit theme); kit
/// components null-assert the theme extensions.
Widget _kitThemed(Widget child) => Theme(
  data: buildAppTheme(font: AppFontFamily.inter),
  child: child,
);

void main() {
  // ---- ActivationCodeDisplay widget ----

  testWidgets('ActivationCodeDisplay renders the code with a copy button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActivationCodeDisplay(code: 'ABCD1234', label: 'Linking code'),
        ),
      ),
    );

    // Displayed in dash-grouped halves (Figma "KJWF8-ALS57"); the copy
    // button still copies the raw, un-dashed code.
    expect(find.text('ABCD-1234'), findsOneWidget);
    expect(find.text('Linking code'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
  });

  testWidgets(
    'ActivationCodeDisplay copy button copies the code to clipboard',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivationCodeDisplay(code: 'COPYME99')),
        ),
      );

      await tester.tap(find.byIcon(Icons.copy_outlined));
      await tester.pump();

      expect(copied, 'COPYME99');

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    },
  );

  testWidgets('ActivationCodeDisplay shows an expiry subtitle when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActivationCodeDisplay(
            code: 'XYZ',
            expiresAt: '2026-06-06T12:00:00.000Z',
          ),
        ),
      ),
    );

    expect(find.textContaining('Expires'), findsOneWidget);
  });

  // ---- expires-in label (Figma "Expires in 3 days, 0 hours") ----

  test('expiresInLabel floors to days + hours and flags expiry', () {
    final now = DateTime.utc(2026, 6, 1, 12);
    expect(
      expiresInLabel('2026-06-04T12:30:00.000Z', now),
      'Expires in 3 days, 0 hours',
    );
    expect(
      expiresInLabel('2026-06-01T18:00:00.000Z', now),
      'Expires in 0 days, 6 hours',
    );
    expect(expiresInLabel('2026-06-01T11:00:00.000Z', now), 'Expired');
    expect(expiresInLabel(null, now), '');
  });

  // ---- KEY spec test: linking surfaces the SERVER code, and the
  // submission carries ONLY identity (the client never supplies the
  // code or expiry) ----

  testWidgets('Link Participant confirm dispatches identity-only and '
      'surfaces the SERVER-returned linking code', (tester) async {
    final fake = FakeReaction();
    fake.queueDispatchResult(
      const DispatchSuccess<Object?>(
        <String, Object?>{
          'participantId': 'P-1',
          'linkingCode': 'CASERVER1',
          'expiresAt': '2026-06-06T12:00:00.000Z',
        },
        <String>['evt-1'],
      ),
    );

    await pumpReactionWidget(
      tester,
      fake: fake,
      child: _kitThemed(
        const Scaffold(
          body: LinkParticipantDialog(participantId: 'P-1', siteId: 'S-1'),
        ),
      ),
    );

    // Confirm step first; no client-generated code anywhere.
    expect(find.text('CASERVER1'), findsNothing);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // The SERVER code is surfaced (Figma: Mobile Linking Code dialog),
    // displayed in dash-grouped halves.
    expect(find.text('CASE-RVER1'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    expect(find.textContaining('Expire'), findsWidgets);

    // The submission carried ONLY identity keys.
    final sub = fake.submittedActions.single;
    expect(sub.actionName, 'ACT-PAT-001');
    expect(sub.rawInput.keys.toSet(), <String>{'siteId', 'participantId'});

    await fake.dispose();
  });

  testWidgets('the code surfaces on an idempotency-hit replay too', (
    tester,
  ) async {
    final fake = FakeReaction();
    fake.queueDispatchResult(
      const DispatchIdempotencyHit<Object?>(
        <String, Object?>{
          'participantId': 'P-1',
          'linkingCode': 'CACACHED1',
          'expiresAt': '2026-06-06T12:00:00.000Z',
        },
        <String>['evt-1'],
      ),
    );

    await pumpReactionWidget(
      tester,
      fake: fake,
      child: _kitThemed(
        const Scaffold(
          body: LinkParticipantDialog(participantId: 'P-1', siteId: 'S-1'),
        ),
      ),
    );

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('CACA-CHED1'), findsOneWidget);

    await fake.dispose();
  });
}
