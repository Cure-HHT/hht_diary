// Verifies: DIARY-BASE-questionnaire-manage-modal/A+B+C+D+E — the Manage
//   Questionnaires modal: header shows the participant id (A); one card per
//   enabled type (B); a close action dismisses (C); type name + status + paired
//   cycle info (D); the per-status action matrix renders exactly the right
//   buttons, with Finalize disabled until Phase 4 (E).
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}) => QuestionnaireInstance(
  instanceId: instanceId,
  participantId: participantId,
  type: type,
  studyEvent: studyEvent,
  status: status,
);

/// Pumps a single [_QuestionnaireCard] (via the test harness) for one type over
/// an injected row set, recording callback invocations.
Future<
  ({
    List<String> sends,
    List<String> nextCycles,
    List<QuestionnaireInstance> callBacks,
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
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ManageQuestionnairesCardHarness(
          participantId: 'P-1',
          type: type,
          rowsForType: rows,
          onSendNow: sends.add,
          onStartNextCycle: nextCycles.add,
          onCallBack: callBacks.add,
        ),
      ),
    ),
  );
  return (sends: sends, nextCycles: nextCycles, callBacks: callBacks);
}

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
      expect(find.text('Send Now'), findsOneWidget);
      expect(find.text('Call Back'), findsNothing);
      expect(find.text('Start Next Cycle'), findsNothing);
      expect(find.text('Finalize'), findsNothing);

      await tester.tap(find.text('Send Now'));
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
      expect(find.textContaining('Current Cycle'), findsOneWidget);
      expect(find.textContaining('Cycle 1 Day 1'), findsOneWidget);
      expect(find.text('Call Back'), findsOneWidget);
      expect(find.text('Send Now'), findsNothing);
      expect(find.text('Start Next Cycle'), findsNothing);

      await tester.tap(find.text('Call Back'));
      expect(cb.callBacks.length, 1);
      expect(cb.callBacks.single.instanceId, 'inst-1');
    });

    testWidgets(
      'finalized card shows Start Next Cycle only + Finalized Cycle',
      (tester) async {
        final cb = await _pumpCard(
          tester,
          type: noseHht,
          rows: <QuestionnaireInstance>[
            _inst(
              instanceId: 'inst-1',
              status: QuestionnaireInstanceStatus.closed,
              studyEvent: 'Cycle 2 Day 1',
            ),
          ],
        );

        expect(find.text('Not Sent'), findsOneWidget);
        expect(find.textContaining('Finalized Cycle'), findsOneWidget);
        expect(find.text('Next Cycle'), findsOneWidget);
        expect(find.text('Start Next Cycle'), findsOneWidget);
        expect(find.text('Send Now'), findsNothing);
        expect(find.text('Call Back'), findsNothing);

        await tester.tap(find.text('Start Next Cycle'));
        expect(cb.nextCycles, <String>['nose_hht']);
      },
    );

    testWidgets('ready-to-review card shows Finalize (disabled) + Call Back', (
      tester,
    ) async {
      await _pumpCard(
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
      expect(find.text('Call Back'), findsOneWidget);

      // Finalize is disabled until Phase 4.
      final finalize = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Finalize'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(finalize.onPressed, isNull);
    });
  });

  group('ManageQuestionnairesDialog (live ViewBuilder)', () {
    testWidgets(
      'header shows participant id (A); one card per enabled type (B); '
      'close dismisses (C)',
      (tester) async {
        final fake = FakeReaction();
        fake.drivePermission(_authWith({'view:questionnaire_instance'}));

        await pumpReactionWidget(
          tester,
          fake: fake,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ManageQuestionnairesDialog.show(
                    context: context,
                    participantId: 'P-1',
                    siteId: 'S-1',
                    onSendNow: (_) {},
                    onStartNextCycle: (_) {},
                    onCallBack: (_) {},
                  ),
                  child: const Text('open'),
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
        // never-sent HHT-QoL card offers Send Now.
        expect(find.text('Call Back'), findsOneWidget);
        expect(find.text('Send Now'), findsOneWidget);

        // Assertion C: the close action dismisses the dialog with no change.
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Manage Questionnaires'), findsNothing);

        await fake.dispose();
      },
    );
  });
}
