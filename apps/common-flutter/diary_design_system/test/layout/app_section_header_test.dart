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
  group('AppSectionHeader', () {
    testWidgets('renders the title', (tester) async {
      await tester.pumpWidget(
        _harness(const AppSectionHeader(title: 'Assigned Sites')),
      );
      expect(find.text('Assigned Sites'), findsOneWidget);
    });

    testWidgets('renders the count badge when count is non-null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const AppSectionHeader(title: 'Assigned Sites', count: 2)),
      );
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('renders the trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppSectionHeader(
            title: 'Recent Activity',
            trailing: TextButton(
              onPressed: () {},
              child: const Text('See all'),
            ),
          ),
        ),
      );
      expect(find.text('See all'), findsOneWidget);
    });
  });
}
