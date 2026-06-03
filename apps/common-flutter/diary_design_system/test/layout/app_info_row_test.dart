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
  group('AppInfoRow', () {
    testWidgets('renders the label and string value', (tester) async {
      await tester.pumpWidget(
        _harness(const AppInfoRow(label: 'Linking codes revoked', value: '3')),
      );
      expect(find.text('Linking codes revoked'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('renders the valueWidget when provided', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppInfoRow(
            label: 'Status',
            valueWidget: const StatusBadge(kind: StatusBadgeKind.active),
          ),
        ),
      );
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });
  });
}
