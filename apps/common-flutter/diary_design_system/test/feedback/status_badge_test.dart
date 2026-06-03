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
  group('StatusBadge', () {
    testWidgets('uses the default label for each kind', (tester) async {
      const kinds = {
        StatusBadgeKind.active: 'Active',
        StatusBadgeKind.pending: 'Pending',
        StatusBadgeKind.atRisk: 'At risk',
        StatusBadgeKind.inactive: 'Inactive',
      };
      for (final entry in kinds.entries) {
        await tester.pumpWidget(_harness(StatusBadge(kind: entry.key)));
        expect(find.text(entry.value), findsOneWidget);
      }
    });

    testWidgets('label override replaces the default', (tester) async {
      await tester.pumpWidget(
        _harness(
          const StatusBadge(
            kind: StatusBadgeKind.atRisk,
            label: 'Disconnected',
          ),
        ),
      );
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('At risk'), findsNothing);
    });
  });
}
