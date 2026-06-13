// Verifies: DIARY-PRD-questionnaire-system/C+E — the "Send EQ" dialog confirms,
//   dispatches ACT-PAT-002 (the coordinator Trial-Start trigger), and renders
//   the success state; the action is gated to the connected ("awaiting start")
//   status.
import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/participant_status.dart';
import 'package:portal_ui_evs/src/start_trial_dialog.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

/// pumpReactionWidget wraps a bare MaterialApp (no kit theme); kit
/// components null-assert the theme extensions.
Widget _kitThemed(Widget child) => Theme(
  data: buildAppTheme(font: AppFontFamily.inter),
  child: child,
);

void main() {
  testWidgets('Send EQ: confirm -> dispatch ACT-PAT-002 -> success', (
    tester,
  ) async {
    final fake = FakeReaction();
    fake.queueDispatchResult(
      const DispatchSuccess<Object?>(
        <String, Object?>{'participantId': 'P-1'},
        <String>['evt-1'],
      ),
    );

    await pumpReactionWidget(
      tester,
      fake: fake,
      child: _kitThemed(
        const Scaffold(
          body: StartTrialDialog(participantId: 'P-1', siteId: 'S-1'),
        ),
      ),
    );

    // Confirm state (Figma): title + the Diary Data Synchronization copy +
    // the sponsor-requested Send EQ action.
    expect(find.text('Start Trial'), findsOneWidget);
    expect(find.textContaining('P-1'), findsWidgets);
    expect(find.textContaining('Diary Data Synchronization'), findsOneWidget);
    expect(find.text('Send EQ'), findsOneWidget);

    // Confirm -> dispatch ACT-PAT-002.
    await tester.tap(find.text('Send EQ'));
    await tester.pumpAndSettle();

    // Success state.
    expect(find.text('Trial Started'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await fake.dispose();
  });

  test('startTrial ("Send EQ") is enabled only for the connected status', () {
    expect(
      enabledActions(ParticipantStatus.connected),
      contains(ParticipantAction.startTrial),
      reason: 'Send EQ is offered once the diary is connected (awaiting start)',
    );
    expect(
      enabledActions(ParticipantStatus.trialActive),
      isNot(contains(ParticipantAction.startTrial)),
      reason: 'Send EQ is gone once the trial is active',
    );
    expect(
      enabledActions(ParticipantStatus.notConnected),
      isNot(contains(ParticipantAction.startTrial)),
    );
  });
}
