// Verifies: DIARY-BASE-questionnaire-manage-modal/A+B+C+D+E+F+G+H — the Manage
//   Questionnaires modal: header shows the participant id (A); one card per
//   enabled type (B); a close action dismisses (C); type name + status + paired
//   cycle info (D); the per-status action matrix renders exactly the right
//   buttons, with Finalize disabled until Phase 4 (E). The Call Back reason
//   dialog requires a non-empty reason (F), dispatches ACT-QST-002 on Confirm so
//   the row tombstones (G), and Cancel makes no change (H).
// Verifies: DIARY-BASE-questionnaire-coordinator-workflow/D+E — Call Back
//   dispatches the retraction action through the reaction scope.
import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:portal_ui_evs/src/manage_questionnaires_dialog.dart';
import 'package:portal_ui_evs/src/questionnaire_instance.dart';
import 'package:portal_ui_evs/src/questionnaire_types.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

EffectiveAuthorization _authWith(Set<String> permissions) =>
    EffectiveAuthorization(
      activeRole: 'role',
      rolePermissions: {for (final name in permissions) Permission(name)},
      scopeAssignments: const <ScopeAssignment>[],
    );

QuestionnaireInstance _inst({
  required String instanceId,
  required QuestionnaireInstanceStatus status,
  String type = 'nose_hht',
  String? studyEvent,
  String participantId = 'P-1',
  String? endEvent,
  DateTime? lockedAt,
}) => QuestionnaireInstance(
  instanceId: instanceId,
  participantId: participantId,
  type: type,
  studyEvent: studyEvent,
  status: status,
  endEvent: endEvent,
  lockedAt: lockedAt,
);

/// Pumps a single [_QuestionnaireCard] (via the test harness) for one type over
/// an injected row set, recording callback invocations.
Future<
  ({
    List<String> sends,
    List<String> nextCycles,
    List<QuestionnaireInstance> callBacks,
    List<QuestionnaireInstance> finalizes,
  })
>
_pumpCard(
  WidgetTester tester, {
  required QuestionnaireType type,
  required List<QuestionnaireInstance> rows,
}) async {
  final sends = <String>[];
  final nextCycles = <String>[];
  final callBacks = <QuestionnaireInstance>[];
  final finalizes = <QuestionnaireInstance>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(font: AppFontFamily.inter),
      home: Scaffold(
        body: ManageQuestionnairesCardHarness(
          participantId: 'P-1',
          type: type,
          rowsForType: rows,
          onSendNow: sends.add,
          onStartNextCycle: nextCycles.add,
          onCallBack: callBacks.add,
          onFinalize: finalizes.add,
        ),
      ),
    ),
  );
  return (
    sends: sends,
    nextCycles: nextCycles,
    callBacks: callBacks,
    finalizes: finalizes,
  );
}

/// pumpReactionWidget wraps a bare MaterialApp (no kit theme); kit
/// components null-assert the theme extensions, so harness children are
/// wrapped in the app theme. showDialog captures InheritedTheme from the
/// launching context, so dialogs inherit it too.
Widget _kitThemed(Widget child) => Theme(
  data: buildAppTheme(font: AppFontFamily.inter),
  child: child,
);

void main() {
  const noseHht = QuestionnaireType(id: 'nose_hht', displayName: 'NOSE HHT');

  group('_QuestionnaireCard per-status actions (assertion E)', () {
    testWidgets('never-sent card shows Send Now only', (tester) async {
      final cb = await _pumpCard(
        tester,
        type: noseHht,
        rows: const <QuestionnaireInstance>[],
      );

      expect(find.text('NOSE HHT'), findsOneWidget); // assertion D (type name)
      expect(find.text('Not Sent'), findsOneWidget); // status
      expect(find.text('Send'), findsOneWidget); // Figma: "Send"
      expect(find.byTooltip('Call Back'), findsNothing);
      expect(find.text('Start Next Cycle'), findsNothing);
      expect(find.text('Finalize'), findsNothing);

      await tester.tap(find.text('Send'));
      expect(cb.sends, <String>['nose_hht']);
    });

    testWidgets('sent card shows Call Back only + Current Cycle', (
      tester,
    ) async {
      final cb = await _pumpCard(
        tester,
        type: noseHht,
        rows: <QuestionnaireInstance>[
          _inst(
            instanceId: 'inst-1',
            status: QuestionnaireInstanceStatus.sent,
            studyEvent: 'Cycle 1 Day 1',
          ),
        ],
      );

      expect(find.text('Sent'), findsOneWidget);
      expect(find.textContaining('Current:'), findsOneWidget);
      expect(find.textContaining('Cycle 1 Day 1'), findsOneWidget);
      expect(find.byTooltip('Call Back'), findsOneWidget);
      expect(find.text('Send'), findsNothing);
      expect(find.text('Start Next Cycle'), findsNothing);

      await tester.tap(find.byTooltip('Call Back'));
      expect(cb.callBacks.length, 1);
      expect(cb.callBacks.single.instanceId, 'inst-1');
    });

    testWidgets(
      'finalized card shows Start Next Cycle + Last (with finalized date) + Next',
      (tester) async {
        // Verifies: DIARY-BASE-questionnaire-finalization/D — after finalization the "Last:" line
        //   shows the finalization date and time, and a "Next: Cycle N+1 Day 1"
        //   line appears with a Not Sent status.
        final cb = await _pumpCard(
          tester,
          type: noseHht,
          rows: <QuestionnaireInstance>[
            _inst(
              instanceId: 'inst-1',
              status: QuestionnaireInstanceStatus.closed,
              studyEvent: 'Cycle 2 Day 1',
              // 2024-10-13 17:00 local -> "Oct 13, 2024, 5:00 PM".
              lockedAt: DateTime(2024, 10, 13, 17),
            ),
          ],
        );

        expect(find.text('Not Sent'), findsOneWidget);
        // Figma after-finalize body: "Last: <cycle> • <finalized date/time>".
        expect(find.textContaining('Last:'), findsOneWidget);
        expect(find.textContaining('Cycle 2 Day 1'), findsOneWidget);
        // Assertion T: the finalization date and time are shown.
        expect(find.textContaining('Oct 13, 2024, 5:00 PM'), findsOneWidget);
        // The "Next: Cycle 3 Day 1" line (Figma).
        expect(find.textContaining('Next:'), findsOneWidget);
        expect(find.textContaining('Cycle 3 Day 1'), findsOneWidget);
        expect(find.text('Start Next Cycle'), findsOneWidget);
        expect(find.text('Send'), findsNothing);
        expect(find.byTooltip('Call Back'), findsNothing);

        await tester.tap(find.text('Start Next Cycle'));
        expect(cb.nextCycles, <String>['nose_hht']);
      },
    );

    testWidgets('ready-to-review card shows Finalize (enabled) + Call Back', (
      tester,
    ) async {
      final cb = await _pumpCard(
        tester,
        type: noseHht,
        rows: <QuestionnaireInstance>[
          _inst(
            instanceId: 'inst-1',
            status: QuestionnaireInstanceStatus.readyToReview,
            studyEvent: 'Cycle 1 Day 1',
          ),
        ],
      );

      expect(find.text('Ready to Review'), findsOneWidget);
      expect(find.text('Finalize'), findsOneWidget);
      expect(find.byTooltip('Call Back'), findsOneWidget);

      // Finalize is now wired: it targets the open instance. Match the
      // common ButtonStyleButton superclass, not the exact FilledButton
      // type: the Figma-green Finalize button is a FilledButton.icon, which
      // resolves to a private _FilledButtonWithIcon subclass on some Flutter
      // versions (find.byType is exact-type, so it would miss it).
      final finalize = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Finalize'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(finalize.onPressed, isNotNull);

      await tester.tap(find.text('Finalize'));
      expect(cb.finalizes.length, 1);
      expect(cb.finalizes.single.instanceId, 'inst-1');
      expect(cb.finalizes.single.studyEvent, 'Cycle 1 Day 1');
    });

    // Verifies: DIARY-BASE-questionnaire-finalization/E — a terminal Closed card
    //   shows the combined "Closed · <terminal>" badge and offers NO actions.
    testWidgets('terminal Closed card shows combined badge + no actions', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        type: noseHht,
        rows: <QuestionnaireInstance>[
          _inst(
            instanceId: 'inst-1',
            status: QuestionnaireInstanceStatus.closed,
            studyEvent: 'Cycle 3 Day 1',
            endEvent: 'end_of_study',
          ),
        ],
      );

      // Combined badge (assertion E) — Figma sentence-case noun.
      expect(find.text('Closed · End of study'), findsOneWidget);
      // No actions are offered on a terminally-closed card.
      expect(find.text('Finalize'), findsNothing);
      expect(find.byTooltip('Call Back'), findsNothing);
      expect(find.text('Send Now'), findsNothing);
      expect(find.text('Start Next Cycle'), findsNothing);
    });
  });

  group('ManageQuestionnairesDialog (live ViewBuilder)', () {
    testWidgets(
      'header shows participant id (A); one card per enabled type (B); '
      'close dismisses (C)',
      (tester) async {
        final fake = FakeReaction();
        fake.drivePermission(_authWith({'portal.questionnaire.view_status'}));

        await pumpReactionWidget(
          tester,
          fake: fake,
          child: _kitThemed(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => ManageQuestionnairesDialog.show(
                      context: context,
                      participantId: 'P-1',
                      siteId: 'S-1',
                      serverUrl: 'http://test.local',
                      identityCredential: 'cred',
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump();

        // Drive the view to Ready with one sent NOSE HHT instance.
        fake.emitViewUpdate<QuestionnaireInstance>(
          'questionnaire_instance',
          Snapshot<QuestionnaireInstance>(
            value: _inst(
              instanceId: 'inst-1',
              status: QuestionnaireInstanceStatus.sent,
              studyEvent: 'Cycle 1 Day 1',
            ),
            sequence: 1,
          ),
        );
        fake.emitViewUpdate<QuestionnaireInstance>(
          'questionnaire_instance',
          const EndOfReplay<QuestionnaireInstance>(sequence: 1),
        );
        await tester.pump();
        await tester.pump();

        // Assertion A: header shows the participant id.
        expect(find.textContaining('P-1'), findsWidgets);
        expect(find.text('Manage Questionnaires'), findsOneWidget);

        // Assertion B: one card per enabled type (NOSE HHT + HHT-QoL).
        for (final t in kEnabledQuestionnaireTypes) {
          expect(find.text(t.displayName), findsOneWidget);
        }

        // The NOSE HHT card (which has the sent instance) offers Call Back; the
        // never-sent HHT-QoL card offers Send.
        expect(find.byTooltip('Call Back'), findsOneWidget);
        expect(find.text('Send'), findsOneWidget);

        // Assertion C: the close action dismisses the dialog with no change.
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Manage Questionnaires'), findsNothing);

        await fake.dispose();
      },
    );

    // Verifies: DIARY-BASE-questionnaire-manage-modal/I+J+K+L — the full Send
    //   Now multi-step path: Send Now -> server 422 needs_initial_cycle_selection
    //   -> the Select Starting Cycle dialog -> choose a cycle -> Confirm and Send
    //   re-POSTs with an explicit `studyEvent: 'Cycle <N> Day 1'`.
    testWidgets(
      'Send Now 422 -> cycle picker -> re-POST carries studyEvent (I/J/K/L)',
      (tester) async {
        // Mock client: first POST (no studyEvent) -> 422; second POST (with the
        // chosen studyEvent) -> 200. Capture every request body.
        final bodies = <Map<String, Object?>>[];
        final client = MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, Object?>;
          bodies.add(body);
          if (!body.containsKey('studyEvent')) {
            return http.Response(
              jsonEncode(<String, Object?>{
                'error': 'needs_initial_cycle_selection',
              }),
              422,
              headers: const {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(<String, Object?>{
              'instanceId': 'inst-9',
              'studyEvent': body['studyEvent'],
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        });

        final fake = FakeReaction();
        fake.drivePermission(_authWith({'portal.questionnaire.view_status'}));

        await pumpReactionWidget(
          tester,
          fake: fake,
          child: _kitThemed(
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => ManageQuestionnairesDialog.show(
                      context: context,
                      participantId: 'P-1',
                      siteId: 'S-1',
                      serverUrl: 'http://test.local',
                      identityCredential: 'cred',
                      httpClient: client,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump();

        // Drive the view to Ready with NO rows for this participant, so every
        // enabled type resolves to never-sent -> each card offers Send Now.
        fake.emitViewUpdate<QuestionnaireInstance>(
          'questionnaire_instance',
          const EndOfReplay<QuestionnaireInstance>(sequence: 1),
        );
        await tester.pump();
        await tester.pump();

        // Tap the first Send (the never-sent NOSE HHT card).
        expect(find.text('Send'), findsWidgets);
        await tester.tap(find.text('Send').first);
        await tester.pumpAndSettle();

        // The 422 routed to the Select Starting Cycle dialog.
        expect(find.text('Select Starting Cycle'), findsOneWidget);

        // Choose Cycle 3 from the dropdown.
        await tester.tap(find.byType(AppDropdown<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cycle 3 Day 1').last);
        await tester.pumpAndSettle();

        // Confirm -> re-POST with the explicit studyEvent.
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        // Two POSTs landed: the first without studyEvent (got 422), the second
        // carrying the chosen cycle's studyEvent.
        expect(bodies.length, 2);
        expect(bodies.first.containsKey('studyEvent'), isFalse);
        expect(bodies.last['studyEvent'], 'Cycle 3 Day 1');
        expect(bodies.last['questionnaireType'], isNotNull);

        await fake.dispose();
      },
    );
  });

  group('Call Back reason dialog (F/G/H)', () {
    testWidgets('Confirm is disabled until a non-empty reason is entered (F)', (
      tester,
    ) async {
      final fake = FakeReaction();
      await pumpReactionWidget(
        tester,
        fake: fake,
        child: _kitThemed(
          const Scaffold(
            body: CallBackDialogHarness(
              participantId: 'P-1',
              siteId: 'S-1',
              instanceId: 'inst-1',
            ),
          ),
        ),
      );

      final confirm = find.byWidgetPredicate(
        (w) => w is AppButton && w.label == 'Confirm',
      );
      expect(confirm, findsOneWidget);
      // Empty reason -> disabled.
      expect(tester.widget<AppButton>(confirm).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'duplicate send');
      await tester.pump();
      // Non-empty reason -> enabled.
      expect(tester.widget<AppButton>(confirm).onPressed, isNotNull);

      await fake.dispose();
    });

    testWidgets('Confirm dispatches ACT-QST-002 with the reason (G)', (
      tester,
    ) async {
      final fake = FakeReaction();
      fake.queueDispatchResult(
        const DispatchSuccess<Object?>(
          <String, Object?>{'instanceId': 'inst-1'},
          <String>['evt-1'],
        ),
      );
      await pumpReactionWidget(
        tester,
        fake: fake,
        child: _kitThemed(
          const Scaffold(
            body: CallBackDialogHarness(
              participantId: 'P-1',
              siteId: 'S-1',
              instanceId: 'inst-1',
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'wrong cycle');
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // The dispatch landed (success surface rendered before auto-close).
      expect(fake.submittedActions.length, 1);
      final sub = fake.submittedActions.single;
      expect(sub.actionName, 'ACT-QST-002');
      expect(sub.rawInput['siteId'], 'S-1');
      expect(sub.rawInput['instanceId'], 'inst-1');
      expect(sub.rawInput['reason'], 'wrong cycle');

      await fake.dispose();
    });
  });

  // Verifies: DIARY-BASE-questionnaire-finalization/A+B+C+D+E+F+G — the
  //   Finalization Dialog: a Cycle dropdown over the current cycle + the two
  //   terminal options (A/B); a Finalize Questionnaire button + Cancel (C);
  //   a cycle choice dispatches ACT-QST-003 {cycle} directly (D); a terminal
  //   choice opens the Terminal Cycle Warning, whose confirm dispatches
  //   {endEvent} (E); cancelling the warning returns to the Finalization Dialog
  //   without dispatching (G); cancelling the Finalization Dialog dispatches
  //   nothing (F).
  group('Finalization Dialog (A/B/C/D/E/F/G)', () {
    Future<FakeReaction> pumpFinalize(
      WidgetTester tester, {
      String? currentStudyEvent = 'Cycle 2 Day 1',
    }) async {
      final fake = FakeReaction();
      fake.queueDispatchResult(
        const DispatchSuccess<Object?>(
          <String, Object?>{'instanceId': 'inst-1'},
          <String>['evt-1'],
        ),
      );
      await pumpReactionWidget(
        tester,
        fake: fake,
        child: _kitThemed(
          Scaffold(
            body: FinalizationDialogHarness(
              participantId: 'P-1',
              siteId: 'S-1',
              instanceId: 'inst-1',
              currentStudyEvent: currentStudyEvent,
            ),
          ),
        ),
      );
      return fake;
    }

    testWidgets('shows the cycle dropdown + Finalize/Cancel (A/B/C)', (
      tester,
    ) async {
      final fake = await pumpFinalize(tester);

      expect(find.text('Confirm'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);

      // Default selection = the current cycle (shown in the dropdown).
      expect(find.text('Cycle 2 Day 1'), findsOneWidget);

      // The dropdown offers the current cycle + both terminal options (B).
      await tester.tap(find.byType(AppDropdown<String>));
      await tester.pumpAndSettle();
      expect(find.text('End of Treatment'), findsWidgets);
      expect(find.text('End of Study'), findsWidgets);
      expect(find.text('Cycle 2 Day 1'), findsWidgets);

      await fake.dispose();
    });

    testWidgets('cycle option + Finalize dispatches {cycle}, no endEvent (D)', (
      tester,
    ) async {
      final fake = await pumpFinalize(tester);

      // Default selection is the current cycle. Finalize directly (no warning).
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(fake.submittedActions.length, 1);
      final sub = fake.submittedActions.single;
      expect(sub.actionName, 'ACT-QST-003');
      expect(sub.rawInput['siteId'], 'S-1');
      expect(sub.rawInput['instanceId'], 'inst-1');
      expect(sub.rawInput['cycle'], 'Cycle 2 Day 1');
      expect(sub.rawInput.containsKey('endEvent'), isFalse);

      await fake.dispose();
    });

    testWidgets('terminal option + Finalize -> warning -> confirm dispatches '
        '{endEvent} (E)', (tester) async {
      final fake = await pumpFinalize(tester);

      // Select End of Treatment.
      await tester.tap(find.byType(AppDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End of Treatment').last);
      await tester.pumpAndSettle();

      // Finalize -> the Terminal Cycle Warning opens (no dispatch yet). Its
      // confirm verb "End treatment" is unique to the warning (the dialog
      // title and the dropdown trigger both read "End of Treatment").
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('End treatment'), findsOneWidget);
      expect(fake.submittedActions, isEmpty);

      // Confirm the warning -> dispatch {endEvent}.
      await tester.tap(find.text('End treatment'));
      await tester.pumpAndSettle();

      expect(fake.submittedActions.length, 1);
      final sub = fake.submittedActions.single;
      expect(sub.actionName, 'ACT-QST-003');
      expect(sub.rawInput['instanceId'], 'inst-1');
      expect(sub.rawInput['endEvent'], 'end_of_treatment');
      expect(sub.rawInput.containsKey('cycle'), isFalse);

      await fake.dispose();
    });

    testWidgets(
      'cancelling the Terminal Warning returns to Finalization, no dispatch (G)',
      (tester) async {
        final fake = await pumpFinalize(tester);

        await tester.tap(find.byType(AppDropdown<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('End of Study').last);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(find.text('End study'), findsOneWidget);

        // Cancel the warning (the topmost Cancel; the Finalization Dialog
        // behind it also has a Cancel).
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();

        // Back on the Finalization Dialog, nothing dispatched (G).
        expect(find.text('End study'), findsNothing);
        expect(find.text('Confirm'), findsWidgets);
        expect(fake.submittedActions, isEmpty);

        await fake.dispose();
      },
    );

    testWidgets('cancelling the Finalization Dialog dispatches nothing (F)', (
      tester,
    ) async {
      final fake = await pumpFinalize(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fake.submittedActions, isEmpty);

      await fake.dispose();
    });

    testWidgets(
      'null currentStudyEvent -> dropdown offers only the terminal options',
      (tester) async {
        final fake = await pumpFinalize(tester, currentStudyEvent: null);

        // No cycle option; default selection is a terminal (End of Treatment).
        await tester.tap(find.byType(AppDropdown<String>));
        await tester.pumpAndSettle();
        expect(find.text('End of Treatment'), findsWidgets);
        expect(find.text('End of Study'), findsWidgets);
        // No "Cycle N Day 1" cycle option is offered (only the dropdown's
        // "Cycle" label text exists).
        expect(find.textContaining(RegExp(r'Cycle \d')), findsNothing);

        await fake.dispose();
      },
    );
  });
}
