import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

void main() {
  const rows = <ParticipantRowView>[
    ParticipantRowView(
      id: '001-1002567',
      siteName: 'Memorial Hospital',
      status: ParticipantRowStatus.trialActive,
      hasReadyToReview: true,
      menuActions: [
        ParticipantMenuAction.disconnect,
        ParticipantMenuAction.showCode,
      ],
    ),
    ParticipantRowView(
      id: '001-1001234',
      siteName: 'Memorial Hospital',
      status: ParticipantRowStatus.linkedAwaitingStart,
    ),
    ParticipantRowView(
      id: '001-1029012',
      siteName: 'Memorial Hospital',
      status: ParticipantRowStatus.notConnected,
    ),
    ParticipantRowView(
      id: '001-1005678',
      siteName: 'Memorial Hospital',
      status: ParticipantRowStatus.expired,
    ),
    ParticipantRowView(
      id: '001-1028901',
      siteName: 'Memorial Hospital',
      status: ParticipantRowStatus.codePending,
    ),
    ParticipantRowView(
      id: '002-1031234',
      siteName: 'Stanford Medical Center',
      status: ParticipantRowStatus.notParticipating,
      menuActions: [ParticipantMenuAction.reactivate],
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    List<ParticipantRowView> participants = rows,
    List<String> siteChips = const ['001 - Memorial Hospital'],
    void Function(ParticipantRowView)? onPrimary,
    void Function(ParticipantRowView, ParticipantMenuAction)? onMenu,
  }) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(font: AppFontFamily.inter),
        home: Scaffold(
          body: ParticipantsScreen(
            participants: participants,
            siteChips: siteChips,
            isLoading: false,
            onPrimaryAction: onPrimary ?? (_) {},
            onMenuAction: onMenu ?? (_, _) {},
          ),
        ),
      ),
    );
  }

  group('primaryActionFor', () {
    test('maps every status to its Figma action', () {
      expect(
        primaryActionFor(ParticipantRowStatus.notConnected),
        ParticipantPrimaryAction.linkParticipant,
      );
      expect(
        primaryActionFor(ParticipantRowStatus.codePending),
        ParticipantPrimaryAction.showLinkingCode,
      );
      expect(
        primaryActionFor(ParticipantRowStatus.expired),
        ParticipantPrimaryAction.regenerateCode,
      );
      expect(
        primaryActionFor(ParticipantRowStatus.linkedAwaitingStart),
        ParticipantPrimaryAction.startTrial,
      );
      expect(
        primaryActionFor(ParticipantRowStatus.trialActive),
        ParticipantPrimaryAction.manageQuestionnaires,
      );
      expect(
        primaryActionFor(ParticipantRowStatus.disconnected),
        ParticipantPrimaryAction.none,
      );
      expect(
        primaryActionFor(ParticipantRowStatus.notParticipating),
        ParticipantPrimaryAction.none,
      );
    });
  });

  group('statusMatchesFilter', () {
    test('tab buckets match the Figma grouping', () {
      const f = statusMatchesFilter;
      expect(
        f(ParticipantRowStatus.expired, ParticipantStatusFilter.notConnected),
        isTrue,
      );
      expect(
        f(
          ParticipantRowStatus.codePending,
          ParticipantStatusFilter.notConnected,
        ),
        isTrue,
      );
      expect(
        f(
          ParticipantRowStatus.linkedAwaitingStart,
          ParticipantStatusFilter.active,
        ),
        isTrue,
      );
      expect(
        f(ParticipantRowStatus.trialActive, ParticipantStatusFilter.active),
        isTrue,
      );
      expect(
        f(
          ParticipantRowStatus.notParticipating,
          ParticipantStatusFilter.inactive,
        ),
        isTrue,
      );
      expect(
        f(ParticipantRowStatus.trialActive, ParticipantStatusFilter.inactive),
        isFalse,
      );
      expect(
        f(ParticipantRowStatus.unknown, ParticipantStatusFilter.all),
        isTrue,
      );
    });
  });

  testWidgets('renders site chips, statuses, and per-status action buttons', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('My Sites'), findsOneWidget);
    expect(find.text('001 - Memorial Hospital'), findsOneWidget);
    expect(find.text('Participant Summary'), findsOneWidget);
    expect(find.text('Trial Active'), findsOneWidget);
    expect(find.text('Manage Questionnaires'), findsOneWidget);
    expect(find.text('Start Trial'), findsOneWidget);
    expect(find.text('Link Participant'), findsOneWidget);
    expect(find.text('Regenerate Code'), findsOneWidget);
    expect(find.text('Show Linking Code'), findsOneWidget);
  });

  testWidgets('tab counts reflect the Figma grouping', (tester) async {
    await pump(tester);
    // All 6 / Not connected 3 / Active 2 / Inactive 1.
    expect(find.text('All users'), findsOneWidget);
    expect(find.text('6'), findsWidgets);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('status tab filters the rows', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Inactive'));
    await tester.pump();
    expect(find.text('002-1031234'), findsOneWidget);
    expect(find.text('001-1002567'), findsNothing);
  });

  testWidgets('search narrows by participant id', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, '1028901');
    // AppTextField.search debounces its onChanged.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('001-1028901'), findsOneWidget);
    expect(find.text('001-1002567'), findsNothing);
  });

  testWidgets('primary action fires with the row', (tester) async {
    ParticipantRowView? fired;
    await pump(tester, onPrimary: (r) => fired = r);
    await tester.tap(find.text('Start Trial'));
    expect(fired?.id, '001-1001234');
  });

  testWidgets('ready-to-review green dot renders only on flagged rows', (
    tester,
  ) async {
    await pump(tester);
    // Exactly one fixture row (001-1002567) is flagged ready-to-review.
    expect(
      find.byKey(const ValueKey('participant-001-1002567-review-indicator')),
      findsOneWidget,
    );
  });

  // Verifies: REQ-CAL-p00023/O — the ready-to-review indicator is a green dot
  // that ONLY appears when a questionnaire is ready for review. A Trial Active
  // row that is not flagged must show no indicator (regression: the old code
  // drew an unconditional green dot next to every Trial Active participant id).
  testWidgets('Trial Active row without ready-to-review shows no indicator', (
    tester,
  ) async {
    await pump(
      tester,
      participants: const [
        ParticipantRowView(
          id: '001-2000001',
          siteName: 'Memorial Hospital',
          status: ParticipantRowStatus.trialActive,
          hasReadyToReview: false,
          menuActions: [ParticipantMenuAction.disconnect],
        ),
      ],
    );
    // Row is present...
    expect(find.text('001-2000001'), findsOneWidget);
    expect(find.text('Trial Active'), findsOneWidget);
    // ...but carries no ready-to-review dot.
    expect(
      find.byKey(const ValueKey('participant-001-2000001-review-indicator')),
      findsNothing,
    );
  });

  testWidgets('Trial Active row with ready-to-review shows the green dot', (
    tester,
  ) async {
    await pump(
      tester,
      participants: const [
        ParticipantRowView(
          id: '001-2000002',
          siteName: 'Memorial Hospital',
          status: ParticipantRowStatus.trialActive,
          hasReadyToReview: true,
          menuActions: [ParticipantMenuAction.disconnect],
        ),
      ],
    );
    expect(
      find.byKey(const ValueKey('participant-001-2000002-review-indicator')),
      findsOneWidget,
    );
  });
}
