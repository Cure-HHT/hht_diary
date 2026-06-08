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
  group('AppButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        _harness(AppButton(label: 'Submit', onPressed: () {})),
      );
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('renders leading icon alongside label', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppButton(label: 'Save', leadingIcon: Icons.save, onPressed: () {}),
        ),
      );
      expect(find.text('Save'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('icon-only mode triggers when label is null and icon is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(AppButton(leadingIcon: Icons.close, onPressed: () {})),
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
      // No label widget should be present in icon-only mode.
      expect(find.byType(Row), findsNothing);
    });

    testWidgets('loading state swaps content for a progress indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(AppButton(label: 'Submit', loading: true, onPressed: () {})),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('loading disables the tap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _harness(
          AppButton(
            label: 'Submit',
            loading: true,
            onPressed: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      expect(tapped, isFalse);
    });

    testWidgets('disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(_harness(const AppButton(label: 'Submit')));
      final filled = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(filled.onPressed, isNull);
    });

    testWidgets('secondary variant renders an OutlinedButton', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppButton(
            variant: AppButtonVariant.secondary,
            label: 'Cancel',
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('tertiary variant renders a TextButton', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppButton(
            variant: AppButtonVariant.tertiary,
            label: 'Learn more',
            onPressed: () {},
          ),
        ),
      );
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('fullWidth expands to parent width', (tester) async {
      await tester.pumpWidget(
        _harness(
          SizedBox(
            width: 400,
            child: AppButton(
              label: 'Submit',
              fullWidth: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      final box = tester.getSize(find.byType(FilledButton));
      expect(box.width, equals(400));
    });

    testWidgets('semanticId emits a Semantics identifier with button role', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          AppButton(
            label: 'Sign in',
            semanticId: 'login.submit',
            onPressed: () {},
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(AppButton));
      expect(node.identifier, equals('login.submit'));
      expect(node.flagsCollection.isButton, isTrue);
    });

    testWidgets('semanticLabel populates the Semantics label', (tester) async {
      await tester.pumpWidget(
        _harness(
          AppButton(
            leadingIcon: Icons.close,
            semanticId: 'dialog.close',
            semanticLabel: 'Close dialog',
            onPressed: () {},
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(AppButton));
      expect(node.identifier, equals('dialog.close'));
      expect(node.label, equals('Close dialog'));
    });

    testWidgets('no Semantics wrapper when semanticId is null', (tester) async {
      await tester.pumpWidget(
        _harness(AppButton(label: 'Submit', onPressed: () {})),
      );
      // The wrapper Semantics is only emitted when semanticId or
      // semanticLabel is set — otherwise the inner button's semantics
      // bubble up unchanged.
      final node = tester.getSemantics(find.byType(AppButton));
      expect(node.identifier, isEmpty);
    });
  });
}
