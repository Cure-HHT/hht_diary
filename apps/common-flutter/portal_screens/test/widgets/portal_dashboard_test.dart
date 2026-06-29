import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

/// Renders a dashboard wide enough for the AppBar's right-hand cluster
/// to fit without overflow. The default test surface (800x600) is
/// narrower than the canonical Admin layout, so we pump bigger and
/// drop devicePixelRatio to 1.
Future<void> _pumpDashboard(WidgetTester tester, Widget dashboard) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(font: AppFontFamily.inter),
      home: dashboard,
    ),
  );
}

PortalAppBar _stubAppBar() => PortalAppBar(
  title: 'Sponsor Portal',
  subtitle: 'Administrator Dashboard',
  userName: 'Dr. Emily Parker',
  activeRole: 'Administrator',
  availableRoles: const ['Administrator'],
  onLogout: () {},
);

List<DashboardDestination> _stubDestinations() => [
  DashboardDestination(
    key: 'users',
    label: 'Users',
    body: (_) => const Text('users-body'),
  ),
  DashboardDestination(
    key: 'audit',
    label: 'Audit Logs',
    body: (_) => const Text('audit-body'),
  ),
  DashboardDestination(
    key: 'sites',
    label: 'Sites',
    body: (_) => const Text('sites-body'),
  ),
];

void main() {
  group('PortalDashboard', () {
    testWidgets('renders the appBar + tab strip + first destination body', (
      tester,
    ) async {
      await _pumpDashboard(
        tester,
        PortalDashboard(
          appBar: _stubAppBar(),
          destinations: _stubDestinations(),
        ),
      );

      expect(find.text('Sponsor Portal'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget); // tab label
      expect(find.text('users-body'), findsOneWidget); // active body
      expect(find.text('audit-body'), findsNothing);
    });

    testWidgets('tapping a tab swaps the body to that destination', (
      tester,
    ) async {
      await _pumpDashboard(
        tester,
        PortalDashboard(
          appBar: _stubAppBar(),
          destinations: _stubDestinations(),
        ),
      );

      await tester.tap(find.text('Audit Logs'));
      await tester.pumpAndSettle();

      expect(find.text('users-body'), findsNothing);
      expect(find.text('audit-body'), findsOneWidget);
    });

    testWidgets('initialKey selects a non-first destination', (tester) async {
      await _pumpDashboard(
        tester,
        PortalDashboard(
          appBar: _stubAppBar(),
          destinations: _stubDestinations(),
          initialKey: 'sites',
        ),
      );

      expect(find.text('sites-body'), findsOneWidget);
      expect(find.text('users-body'), findsNothing);
    });

    testWidgets(
      'unknown initialKey gracefully falls back to the first destination',
      (tester) async {
        await _pumpDashboard(
          tester,
          PortalDashboard(
            appBar: _stubAppBar(),
            destinations: _stubDestinations(),
            initialKey: 'nonexistent-key',
          ),
        );
        // First destination is Users, so users-body must show.
        expect(find.text('users-body'), findsOneWidget);
      },
    );

    testWidgets('onDestinationChanged fires with the new key on tap', (
      tester,
    ) async {
      final changes = <String>[];
      await _pumpDashboard(
        tester,
        PortalDashboard(
          appBar: _stubAppBar(),
          destinations: _stubDestinations(),
          onDestinationChanged: changes.add,
        ),
      );

      await tester.tap(find.text('Audit Logs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sites'));
      await tester.pumpAndSettle();

      expect(changes, equals(['audit', 'sites']));
    });

    testWidgets('tapping the already-active tab does NOT re-fire '
        'onDestinationChanged', (tester) async {
      final changes = <String>[];
      await _pumpDashboard(
        tester,
        PortalDashboard(
          appBar: _stubAppBar(),
          destinations: _stubDestinations(),
          onDestinationChanged: changes.add,
        ),
      );
      await tester.tap(find.text('Users')); // already active
      await tester.pumpAndSettle();
      expect(
        changes,
        isEmpty,
        reason:
            'Selecting the active tab should be a no-op so consumers '
            'that route on changes do not see spurious events.',
      );
    });

    testWidgets(
      'if the destinations list mutates so the active key disappears, '
      'the dashboard falls back to the first destination',
      (tester) async {
        await _pumpDashboard(
          tester,
          PortalDashboard(
            appBar: _stubAppBar(),
            destinations: _stubDestinations(),
            initialKey: 'sites',
          ),
        );
        expect(find.text('sites-body'), findsOneWidget);

        // Rebuild with a destinations list that no longer contains 'sites'.
        await _pumpDashboard(
          tester,
          PortalDashboard(
            appBar: _stubAppBar(),
            destinations: [
              DashboardDestination(
                key: 'users',
                label: 'Users',
                body: (_) => const Text('users-body'),
              ),
              DashboardDestination(
                key: 'audit',
                label: 'Audit Logs',
                body: (_) => const Text('audit-body'),
              ),
            ],
          ),
        );

        expect(find.text('sites-body'), findsNothing);
        expect(find.text('users-body'), findsOneWidget);
      },
    );
  });

  group('PortalDashboard — bodyOverride', () {
    testWidgets('override renders instead of the active body; tapping the '
        'active tab fires onDestinationChanged to dismiss it', (tester) async {
      final changes = <String>[];
      await _pumpDashboard(
        tester,
        PortalDashboard(
          appBar: _stubAppBar(),
          destinations: _stubDestinations(),
          bodyOverride: const Text('settings-body'),
          onDestinationChanged: changes.add,
        ),
      );
      expect(find.text('settings-body'), findsOneWidget);
      expect(find.text('users-body'), findsNothing);

      // Re-tapping the (already-active) first tab must fire the callback
      // so the owner can clear the override — the normal same-key
      // short-circuit doesn't apply while an override shows.
      await tester.tap(find.text('Users'));
      await tester.pump();
      expect(changes, ['users']);
    });
  });
}
