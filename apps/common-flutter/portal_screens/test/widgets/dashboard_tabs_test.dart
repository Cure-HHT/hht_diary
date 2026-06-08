import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_screens/portal_screens.dart';

Widget _harness(Widget child) => MaterialApp(
  theme: buildAppTheme(font: AppFontFamily.inter),
  home: Scaffold(body: Center(child: child)),
);

const _tabs = <DashboardTabItem>[
  DashboardTabItem(key: 'users', label: 'Users'),
  DashboardTabItem(key: 'audit', label: 'Audit Logs'),
  DashboardTabItem(key: 'sites', label: 'Sites'),
];

void main() {
  group('DashboardTabs', () {
    testWidgets('renders every tab label', (tester) async {
      await tester.pumpWidget(
        _harness(DashboardTabs(tabs: _tabs, activeKey: 'users', onTap: (_) {})),
      );
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Audit Logs'), findsOneWidget);
      expect(find.text('Sites'), findsOneWidget);
    });

    testWidgets('tapping a tab fires onTap with its key', (tester) async {
      String? lastTapped;
      await tester.pumpWidget(
        _harness(
          DashboardTabs(
            tabs: _tabs,
            activeKey: 'users',
            onTap: (k) => lastTapped = k,
          ),
        ),
      );
      await tester.tap(find.text('Audit Logs'));
      expect(lastTapped, equals('audit'));
    });

    testWidgets('strip paints primaryContainer + active pill paints surface, '
        'matching the Figma segmented-control shape', (tester) async {
      await tester.pumpWidget(
        _harness(DashboardTabs(tabs: _tabs, activeKey: 'audit', onTap: (_) {})),
      );
      final BuildContext ctx = tester.element(find.text('Audit Logs'));
      final scheme = Theme.of(ctx).colorScheme;

      // Outer capsule: a Container whose BoxDecoration colour is the
      // tinted "Primary Light Soft" backdrop — a softened version of
      // primaryContainer so the active white chip pops cleanly over
      // it.
      final outerContainer = tester.widget<Container>(
        find.byType(Container).first,
      );
      final decoration = outerContainer.decoration as BoxDecoration;
      expect(
        decoration.color,
        equals(scheme.primaryContainer.withValues(alpha: 0.4)),
      );

      // Active pill: the Material directly above the active text has
      // surface (white) as its colour; inactive pills stay transparent.
      final materials = tester
          .widgetList<Material>(find.byType(Material))
          .map((m) => m.color)
          .toList();
      expect(materials, contains(scheme.surface));
      expect(materials, contains(Colors.transparent));
    });

    testWidgets('inactive tab is tappable and switches selection on click', (
      tester,
    ) async {
      String? lastTapped;
      await tester.pumpWidget(
        _harness(
          DashboardTabs(
            tabs: _tabs,
            activeKey: 'users',
            onTap: (k) => lastTapped = k,
          ),
        ),
      );
      // The inactive Sites tab must still be hit-testable — its
      // background is transparent but the Material is still in the
      // tree with a clickable InkWell.
      await tester.tap(find.text('Sites'));
      expect(lastTapped, equals('sites'));
    });
  });
}
