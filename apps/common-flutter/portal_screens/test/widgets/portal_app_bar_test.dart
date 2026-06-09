import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

/// Pumps a [PortalAppBar] in a Scaffold harness with a wide enough surface
/// that the right cluster doesn't overflow. The default test surface
/// (800x600 logical) is just barely enough for the canonical Admin variant;
/// pump it wider so a render-flex overflow is never the reason a test
/// fails.
Future<void> _pumpBar(WidgetTester tester, PortalAppBar bar) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(font: AppFontFamily.inter),
      home: Scaffold(appBar: bar, body: const SizedBox.shrink()),
    ),
  );
}

void main() {
  group('PortalAppBar — Admin canonical variant', () {
    testWidgets('renders title + subtitle + role pill + name + logout', (
      tester,
    ) async {
      await _pumpBar(
        tester,
        PortalAppBar(
          title: 'Clinical Trial Portal',
          subtitle: 'Administrator Dashboard',
          userName: 'Dr. Emily Parker',
          activeRole: 'Administrator',
          availableRoles: const ['Administrator', 'StudyCoordinator'],
          onRoleSelected: (_) {},
          onLogout: () {},
          onHelp: () {},
        ),
      );

      expect(find.text('Clinical Trial Portal'), findsOneWidget);
      expect(find.text('Administrator Dashboard'), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);
      expect(find.text('Dr. Emily Parker'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    testWidgets('multi-role variant shows "Role:" prefix + dropdown caret', (
      tester,
    ) async {
      await _pumpBar(
        tester,
        PortalAppBar(
          title: 'Clinical Trial Portal',
          subtitle: 'Administrator Dashboard',
          userName: 'Dr. Emily Parker',
          activeRole: 'Administrator',
          availableRoles: const ['Administrator', 'StudyCoordinator'],
          onRoleSelected: (_) {},
          onLogout: () {},
        ),
      );
      expect(find.text('Role:'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('help icon renders only when onHelp is non-null', (
      tester,
    ) async {
      await _pumpBar(
        tester,
        PortalAppBar(
          title: 'Clinical Trial Portal',
          subtitle: 'Administrator Dashboard',
          userName: 'Dr. Emily Parker',
          activeRole: 'Administrator',
          availableRoles: const ['Administrator', 'StudyCoordinator'],
          onRoleSelected: (_) {},
          onLogout: () {},
          // onHelp omitted
        ),
      );
      expect(find.byIcon(Icons.question_mark), findsNothing);
    });

    testWidgets('logout button fires its callback', (tester) async {
      var logouts = 0;
      await _pumpBar(
        tester,
        PortalAppBar(
          title: 'Clinical Trial Portal',
          subtitle: 'Administrator Dashboard',
          userName: 'Dr. Emily Parker',
          activeRole: 'Administrator',
          availableRoles: const ['Administrator', 'StudyCoordinator'],
          onRoleSelected: (_) {},
          onLogout: () => logouts++,
        ),
      );
      await tester.tap(find.text('Logout'));
      await tester.pump();
      expect(logouts, 1);
    });
  });

  group('PortalAppBar — single-role variant', () {
    testWidgets('drops the "Role:" prefix and the caret', (tester) async {
      await _pumpBar(
        tester,
        PortalAppBar(
          title: 'Clinical Trial Portal',
          subtitle: 'CRA Dashboard',
          userName: 'Jennifer Martinez',
          activeRole: 'CRA',
          availableRoles: const ['CRA'],
          onLogout: () {},
        ),
      );
      expect(find.text('Role:'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      // Pill itself still renders the role label.
      expect(find.text('CRA'), findsOneWidget);
    });

    testWidgets('no onRoleSelected required when availableRoles has 1 entry', (
      tester,
    ) async {
      // Constructs without the assert firing.
      await _pumpBar(
        tester,
        PortalAppBar(
          title: 'Clinical Trial Portal',
          subtitle: 'Study Coordinator Dashboard',
          userName: 'Dr. Sarah Johnson',
          activeRole: 'StudyCoordinator',
          availableRoles: const ['StudyCoordinator'],
          onLogout: () {},
        ),
      );
      expect(find.text('Study Coordinator Dashboard'), findsOneWidget);
    });
  });

  group('PortalAppBar — sponsor display name', () {
    testWidgets(
      'activeRoleDisplayName overrides the canonical label in the pill',
      (tester) async {
        await _pumpBar(
          tester,
          PortalAppBar(
            title: 'Clinical Trial Portal',
            subtitle: 'Site Study Coordinator Dashboard',
            userName: 'Dr. Sarah Johnson',
            activeRole: 'StudyCoordinator',
            activeRoleDisplayName: 'Site Study Coordinator',
            availableRoles: const ['StudyCoordinator'],
            onLogout: () {},
          ),
        );
        expect(find.text('Site Study Coordinator'), findsAtLeastNWidgets(1));
      },
    );
  });

  group('PortalAppBar — assertions', () {
    test('multi-role mode requires onRoleSelected', () {
      expect(
        () => PortalAppBar(
          title: 'Clinical Trial Portal',
          subtitle: 'Administrator Dashboard',
          userName: 'Dr. Emily Parker',
          activeRole: 'Administrator',
          availableRoles: const ['Administrator', 'StudyCoordinator'],
          onLogout: () {},
          // onRoleSelected intentionally missing
        ),
        throwsAssertionError,
      );
    });
  });
}
