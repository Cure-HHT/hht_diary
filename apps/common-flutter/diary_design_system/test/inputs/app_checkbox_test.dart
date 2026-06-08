import 'dart:ui' show CheckedState;

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(font: AppFontFamily.inter),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}

void main() {
  group('AppCheckbox', () {
    testWidgets('renders the inline label when provided', (tester) async {
      await tester.pumpWidget(
        _harness(const AppCheckbox(value: false, label: 'Send updates')),
      );
      expect(find.text('Send updates'), findsOneWidget);
    });

    testWidgets('toggles via tap on the label row', (tester) async {
      bool? observed;
      await tester.pumpWidget(
        _harness(
          AppCheckbox(
            value: false,
            label: 'Subscribe',
            onChanged: (v) => observed = v,
          ),
        ),
      );
      await tester.tap(find.text('Subscribe'));
      expect(observed, isTrue);
    });

    testWidgets('disabled state ignores taps', (tester) async {
      bool? observed;
      await tester.pumpWidget(
        _harness(
          AppCheckbox(
            value: false,
            label: 'Locked',
            enabled: false,
            onChanged: (v) => observed = v,
          ),
        ),
      );
      await tester.tap(find.text('Locked'));
      expect(observed, isNull);
    });

    testWidgets('semanticId emits Semantics identifier + checked state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AppCheckbox(
            value: true,
            label: 'Send updates',
            semanticId: 'prefs.send-updates',
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(AppCheckbox));
      expect(node.identifier, equals('prefs.send-updates'));
      expect(node.flagsCollection.isChecked, equals(CheckedState.isTrue));
    });
  });
}
