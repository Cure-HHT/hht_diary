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
          title: 'Sponsor Portal',
          subtitle: 'Administrator Dashboard',
          userName: 'Dr. Emily Parker',
          activeRole: 'Administrator',
          availableRoles: const ['Administrator', 'StudyCoordinator'],
          onRoleSelected: (_) {},
          onLogout: () {},
          onHelp: () {},
        ),
      );

      expect(find.text('Sponsor Portal'), findsOneWidget);
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
          title: 'Sponsor Portal',
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

    testWidgets(
      'role dropdown lists roles by display name, tags active as "Primary" '
      'with a check',
      (tester) async {
        String? picked;
        await _pumpBar(
          tester,
          PortalAppBar(
            title: 'Sponsor Portal',
            subtitle: 'Administrator Dashboard',
            userName: 'Dr. Emily Parker',
            activeRole: 'Administrator',
            availableRoles: const ['Administrator', 'StudyCoordinator'],
            onRoleSelected: (r) => picked = r,
            onLogout: () {},
          ),
        );

        await tester.tap(find.bySemanticsIdentifier('appbar-role-switcher'));
        await tester.pumpAndSettle();

        // System name "StudyCoordinator" renders as its catalog display name.
        expect(find.text('Study Coordinator'), findsOneWidget);
        // Active role carries the "Primary" tag + check; inactive does not.
        expect(find.text('Primary'), findsOneWidget);
        expect(find.byIcon(Icons.check), findsOneWidget);

        await tester.tap(find.text('Study Coordinator'));
        await tester.pumpAndSettle();
        expect(picked, 'StudyCoordinator');
      },
    );

    testWidgets('help icon renders only when onHelp is non-null', (
      tester,
    ) async {
      await _pumpBar(
        tester,
        PortalAppBar(
          title: 'Sponsor Portal',
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
          title: 'Sponsor Portal',
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
          title: 'Sponsor Portal',
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
          title: 'Sponsor Portal',
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
            title: 'Sponsor Portal',
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

  group('PortalAppBar — CUR-1483 header shape', () {
    PortalAppBar bar({Widget? logo, VoidCallback? onSettings}) => PortalAppBar(
      title: 'Sponsor Portal',
      subtitle: 'Administrator Dashboard',
      userName: 'Dr. Emily Parker',
      activeRole: 'Administrator',
      availableRoles: const ['Administrator', 'CRA'],
      onRoleSelected: (_) {},
      onLogout: () {},
      onHelp: () {},
      onSettings: onSettings,
      logo: logo,
    );

    testWidgets('logo slot renders left of the brand block when provided', (
      tester,
    ) async {
      const logoKey = Key('test-logo');
      await _pumpBar(
        tester,
        bar(logo: const SizedBox(key: logoKey, width: 40, height: 40)),
      );
      expect(find.byKey(logoKey), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(logoKey)).dx,
        lessThan(tester.getTopLeft(find.text('Sponsor Portal')).dx),
        reason: 'logo sits left of the title block',
      );
    });

    testWidgets('right cluster order: user name, role pill, Settings, Logout', (
      tester,
    ) async {
      await _pumpBar(tester, bar(onSettings: () {}));
      final nameX = tester.getTopLeft(find.text('Dr. Emily Parker')).dx;
      final roleX = tester.getTopLeft(find.text('Administrator')).dx;
      final settingsX = tester.getTopLeft(find.text('Settings')).dx;
      final logoutX = tester.getTopLeft(find.text('Logout')).dx;
      expect(nameX, lessThan(roleX), reason: 'name before role pill');
      expect(roleX, lessThan(settingsX), reason: 'role before Settings');
      expect(settingsX, lessThan(logoutX), reason: 'Settings before Logout');
    });

    testWidgets('Settings link fires its callback and carries its id', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pumpBar(tester, bar(onSettings: () => taps++));
      expect(find.bySemanticsIdentifier('appbar-settings'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('Settings link absent when onSettings is null', (tester) async {
      await _pumpBar(tester, bar());
      expect(find.text('Settings'), findsNothing);
    });
  });

  group('PortalAppBar — assertions', () {
    test('multi-role mode requires onRoleSelected', () {
      expect(
        () => PortalAppBar(
          title: 'Sponsor Portal',
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
