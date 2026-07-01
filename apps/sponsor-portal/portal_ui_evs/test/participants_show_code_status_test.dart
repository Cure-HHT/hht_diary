// Verifies: DIARY-GUI-show-linking-code/A+C
// Verifies: DIARY-PRD-linking-code-lifecycle/H
//
// Show Linking Code surfaces two Mobile Linking Code dialog variants: the
// active "Share this code" code (Pending only), and the reference-only
// "This code cannot be used to establish a new connection" variant (every
// other status). CUR-1591: a Disconnected / Not Participating participant was
// wrongly shown the active variant. These tests drive the real binding end to
// end — row tap -> Participant Actions sheet -> Show Linking Code -> dialog —
// so the status -> variant decision in `_showCodeDialog` is exercised.
import 'package:diary_design_system/diary_design_system.dart';
import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_ui_evs/src/participant_status.dart';
import 'package:portal_ui_evs/src/participants_screen_binding.dart';
import 'package:reaction/reaction.dart';
import 'package:reaction_widgets/reaction_widgets.dart';
import 'package:reaction_widgets_testing/reaction_widgets_testing.dart';

/// A viewer that can see the participants table but not sites/questionnaires,
/// so only the `participant_record` ViewBuilder subscribes.
FakeReaction _participantViewer() => FakeReaction(
  initialAuthStatus: Authenticated(
    principal: Principal.user(
      userId: 'coord-1',
      roles: const {'Study Coordinator'},
      activeRole: 'Study Coordinator',
    ),
  ),
  initialPermission: EffectiveAuthorization(
    activeRole: 'Study Coordinator',
    rolePermissions: {Permission('portal.participant.view')},
    scopeAssignments: const <ScopeAssignment>[],
  ),
);

/// Fixed clock so the Pending expiry split is deterministic.
DateTime _fixedNow() => DateTime.utc(2026, 6, 1, 12);

Future<void> _pumpBinding(
  WidgetTester tester, {
  required FakeReaction fake,
  required ParticipantRecordRow record,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ReActionScope(
      scope: fake,
      child: MaterialApp(
        theme: buildAppTheme(font: AppFontFamily.inter),
        home: Scaffold(
          body: ParticipantsScreenBinding(
            identityCredential: 'cred-123',
            serverUrl: 'http://portal.test',
            now: _fixedNow,
          ),
        ),
      ),
    ),
  );
  // The ViewBuilder subscribes in didChangeDependencies; emit rows AFTER the
  // first frame so the broadcast controller has a listener.
  await tester.pump();
  fake.emitViewUpdate<ParticipantRecordRow>(
    'participant_record',
    Snapshot<ParticipantRecordRow>(value: record, sequence: 1),
  );
  fake.emitViewUpdate<ParticipantRecordRow>(
    'participant_record',
    const EndOfReplay<ParticipantRecordRow>(sequence: 1),
  );
  await tester.pumpAndSettle();
}

/// Opens the row's Participant Actions sheet and taps Show Linking Code.
Future<void> _openShowLinkingCode(
  WidgetTester tester, {
  required String participantId,
}) async {
  await tester.tap(find.text(participantId));
  await tester.pumpAndSettle();
  expect(find.text('Participant Actions'), findsOneWidget);
  // A Pending row's primary Action button is also labelled "Show Linking
  // Code"; the sheet's action card is the last match in the tree.
  await tester.tap(find.text('Show Linking Code').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a Pending participant shows the active "Share this code" variant '
    'with Confirm/Cancel',
    (tester) async {
      final fake = _participantViewer();
      addTearDown(fake.dispose);

      await _pumpBinding(
        tester,
        fake: fake,
        record: const ParticipantRecordRow(
          id: '001-1000001',
          siteId: 'S-1',
          status: ParticipantStatus.pending,
          linkingCode: 'ABCD1234',
          expiresAtRaw: '2026-06-10T12:00:00.000Z',
        ),
      );

      await _openShowLinkingCode(tester, participantId: '001-1000001');

      // Active variant: "Share this code…" + Confirm/Cancel, no reference note.
      expect(find.textContaining('Share this code'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(
        find.textContaining('cannot be used to establish a new connection'),
        findsNothing,
      );
      expect(find.widgetWithText(AppButton, 'OK'), findsNothing);
    },
  );

  testWidgets(
    'a Disconnected participant shows the reference-only variant with OK',
    (tester) async {
      final fake = _participantViewer();
      addTearDown(fake.dispose);

      await _pumpBinding(
        tester,
        fake: fake,
        record: const ParticipantRecordRow(
          id: '001-1000002',
          siteId: 'S-1',
          status: ParticipantStatus.disconnected,
          linkingCode: 'WXYZ5678',
          usedAtRaw: '2026-04-20T12:54:00.000Z',
        ),
      );

      await _openShowLinkingCode(tester, participantId: '001-1000002');

      // Reference-only variant: cannot be reused + single OK, no Confirm.
      expect(
        find.textContaining('cannot be used to establish a new connection'),
        findsOneWidget,
      );
      expect(find.textContaining('Reference only'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
      expect(find.textContaining('Share this code'), findsNothing);
    },
  );

  testWidgets(
    'a Not Participating participant shows the reference-only variant with OK',
    (tester) async {
      final fake = _participantViewer();
      addTearDown(fake.dispose);

      await _pumpBinding(
        tester,
        fake: fake,
        record: const ParticipantRecordRow(
          id: '001-1000003',
          siteId: 'S-1',
          status: ParticipantStatus.notParticipating,
          linkingCode: 'LMNO9012',
        ),
      );

      await _openShowLinkingCode(tester, participantId: '001-1000003');

      expect(
        find.textContaining('cannot be used to establish a new connection'),
        findsOneWidget,
      );
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
    },
  );
}
