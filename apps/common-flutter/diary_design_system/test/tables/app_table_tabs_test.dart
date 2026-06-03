import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(font: AppFontFamily.inter),
    home: Scaffold(body: child),
  );
}

void main() {
  group('AppTableTabs', () {
    const tabs = [
      AppTableTab(key: 'all', label: 'All Users', count: 124),
      AppTableTab(key: 'active', label: 'Active', count: 98),
      AppTableTab(key: 'pending', label: 'Pending'),
    ];

    testWidgets('renders each tab label', (tester) async {
      await tester.pumpWidget(
        _harness(AppTableTabs(tabs: tabs, activeKey: 'all', onTap: (_) {})),
      );
      expect(find.text('All Users'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('shows count badges only when count is non-null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(AppTableTabs(tabs: tabs, activeKey: 'all', onTap: (_) {})),
      );
      expect(find.text('124'), findsOneWidget);
      expect(find.text('98'), findsOneWidget);
      // Pending has no count — no '0' or '—' should appear.
    });

    testWidgets('onTap fires with the tapped tab key', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        _harness(
          AppTableTabs(
            tabs: tabs,
            activeKey: 'all',
            onTap: (key) => tapped = key,
          ),
        ),
      );
      await tester.tap(find.text('Active'));
      await tester.pump();
      expect(tapped, equals('active'));
    });
  });
}
