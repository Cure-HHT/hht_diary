// Verifies: DIARY-GUI-show-linking-code/A
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/activation_code_display.dart';
import 'package:portal_ui_evs/src/participant_status.dart';
import 'package:portal_ui_evs/src/participants_screen.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

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

    expect(find.text('ABCD1234'), findsOneWidget);
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

  // ---- Submission shape: issuing actions carry ONLY identity ----

  test('issue/reconnect/reactivate submissions carry no client code', () {
    for (final action in <ParticipantAction>[
      ParticipantAction.issueLinkingCode,
      ParticipantAction.reconnect,
    ]) {
      final sub = submissionForTest(
        action,
        siteId: 'S-1',
        participantId: 'P-1',
      )!;
      expect(sub.input.keys.toSet(), <String>{
        'siteId',
        'participantId',
      }, reason: '$action must submit only identity keys');
      expect(sub.input.containsKey('linkingCode'), isFalse);
      expect(sub.input.containsKey('expiresAt'), isFalse);
    }

    // reactivate keeps reason, but still no linkingCode/expiresAt.
    final reactivate = submissionForTest(
      ParticipantAction.reactivate,
      siteId: 'S-1',
      participantId: 'P-1',
    )!;
    expect(reactivate.input.keys.toSet(), <String>{
      'siteId',
      'participantId',
      'reason',
    });
    expect(reactivate.input.containsKey('linkingCode'), isFalse);
    expect(reactivate.input.containsKey('expiresAt'), isFalse);
  });

  // ---- KEY spec test: issuing surfaces the SERVER code ----

  testWidgets('issuing surfaces the SERVER-returned linking code', (
    tester,
  ) async {
    final fake = FakeReaction();
    // The server (not the client) generates the code; queue it as the
    // action result the dispatcher returns on submit.
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

    // A notConnected participant: issueLinkingCode is the enabled action.
    await pumpReactionWidget(
      tester,
      fake: fake,
      child: const Scaffold(
        body: ActionBuilderHarness(siteId: 'S-1', participantId: 'P-1'),
      ),
    );

    // The plain button is shown initially (no client-generated code).
    expect(find.text('CASERVER1'), findsNothing);

    await tester.tap(find.text(ParticipantAction.issueLinkingCode.label));
    await tester.pumpAndSettle();

    // After success, the SERVER code is surfaced inline.
    expect(find.text('CASERVER1'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);

    await fake.dispose();
  });
}
