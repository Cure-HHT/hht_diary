import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(font: AppFontFamily.inter),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  group('AppCard', () {
    testWidgets('renders the child', (tester) async {
      await tester.pumpWidget(
        _harness(const AppCard(child: Text('Inside the card'))),
      );
      expect(find.text('Inside the card'), findsOneWidget);
    });

    testWidgets('renders the title above the child when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const AppCard(title: 'User info', child: Text('Body text'))),
      );
      expect(find.text('User info'), findsOneWidget);
      expect(find.text('Body text'), findsOneWidget);
    });
  });
}
