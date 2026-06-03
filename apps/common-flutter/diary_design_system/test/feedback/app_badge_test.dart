import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(font: AppFontFamily.inter),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('AppBadge', () {
    testWidgets('renders the label', (tester) async {
      await tester.pumpWidget(_harness(const AppBadge(label: 'Admin')));
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('outlined variant has a transparent background', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AppBadge(
            label: 'CRA',
            variant: AppBadgeVariant.outlined,
            tone: AppBadgeTone.neutral,
          ),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(Colors.transparent));
    });

    testWidgets('filled variant has a non-transparent background', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AppBadge(
            label: 'Admin',
            variant: AppBadgeVariant.filled,
            tone: AppBadgeTone.danger,
          ),
        ),
      );
      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNot(equals(Colors.transparent)));
    });
  });
}
