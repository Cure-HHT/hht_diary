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
    // Verifies: CAL-GUI-participant-dashboard-configuration/F
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
        ParticipantPrimaryAction.reconnect,
      );
      expect(
        primaryActionFor(ParticipantRowStatus.notParticipating),
        ParticipantPrimaryAction.reactivate,
      );
      expect(
        primaryActionFor(ParticipantRowStatus.unknown),
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

  testWidgets('ready-to-review bell renders only on flagged rows', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
  });

  // Verifies: CAL-GUI-participant-dashboard-configuration/F
  testWidgets(
    'Disconnected renders Reconnect and Not Participating renders Reactivate',
    (tester) async {
      const inactiveRows = <ParticipantRowView>[
        ParticipantRowView(
          id: '003-1040001',
          siteName: 'Memorial Hospital',
          status: ParticipantRowStatus.disconnected,
          menuActions: [ParticipantMenuAction.reconnect],
        ),
        ParticipantRowView(
          id: '003-1040002',
          siteName: 'Memorial Hospital',
          status: ParticipantRowStatus.notParticipating,
          menuActions: [ParticipantMenuAction.reactivate],
        ),
      ];
      await pump(tester, participants: inactiveRows);
      // Inactive tab holds Disconnected + Not Participating rows.
      await tester.tap(find.text('Inactive'));
      await tester.pump();
      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.text('Reactivate'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.drive_file_move_outline), findsOneWidget);
    },
  );

  // Verifies: CAL-GUI-participant-dashboard-configuration/F
  testWidgets('primary Reconnect action fires with the row', (tester) async {
    ParticipantRowView? fired;
    const inactiveRows = <ParticipantRowView>[
      ParticipantRowView(
        id: '003-1040001',
        siteName: 'Memorial Hospital',
        status: ParticipantRowStatus.disconnected,
        menuActions: [ParticipantMenuAction.reconnect],
      ),
    ];
    await pump(tester, participants: inactiveRows, onPrimary: (r) => fired = r);
    await tester.tap(find.text('Inactive'));
    await tester.pump();
    await tester.tap(find.text('Reconnect'));
    expect(fired?.id, '003-1040001');
  });
}
