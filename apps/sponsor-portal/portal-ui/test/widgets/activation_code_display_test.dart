// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00029: Create User Account
//   REQ-CAL-p00033: Resend Activation Email
//
// Widget tests for ActivationCodeDisplay and ActivationCodeChip

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponsor_portal_ui/widgets/activation_code_display.dart';

void main() {
  group('ActivationCodeDisplay', () {
    testWidgets('renders code text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivationCodeDisplay(code: 'ABCDE-12345')),
        ),
      );

      expect(find.text('ABCDE-12345'), findsOneWidget);
    });

    testWidgets('shows label when provided and showLabel is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActivationCodeDisplay(
              code: 'CODE-1',
              label: 'Activation Code',
            ),
          ),
        ),
      );

      expect(find.text('Activation Code'), findsOneWidget);
      expect(find.text('CODE-1'), findsOneWidget);
    });

    testWidgets('hides label when showLabel is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActivationCodeDisplay(
              code: 'CODE-2',
              label: 'Hidden Label',
              showLabel: false,
            ),
          ),
        ),
      );

      expect(find.text('Hidden Label'), findsNothing);
      expect(find.text('CODE-2'), findsOneWidget);
    });

    testWidgets('shows copy icon button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivationCodeDisplay(code: 'COPY-ME')),
        ),
      );

      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    });

    testWidgets('copy button shows snackbar on tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivationCodeDisplay(code: 'SNAP-123')),
        ),
      );

      await tester.tap(find.byIcon(Icons.copy_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Code copied: SNAP-123'), findsOneWidget);
    });

    testWidgets('applies custom fontSize', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActivationCodeDisplay(code: 'BIG', fontSize: 24),
          ),
        ),
      );

      final selectableText = tester.widget<SelectableText>(
        find.byType(SelectableText).first,
      );
      expect(selectableText.style?.fontSize, 24);
    });
  });

  group('ActivationCodeChip', () {
    testWidgets('renders code in compact form', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivationCodeChip(code: 'CHIP-99')),
        ),
      );

      expect(find.text('CHIP-99'), findsOneWidget);
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    });

    testWidgets('uses monospace font', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivationCodeChip(code: 'MONO')),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('MONO'));
      expect(textWidget.style?.fontFamily, 'monospace');
    });
  });
}
