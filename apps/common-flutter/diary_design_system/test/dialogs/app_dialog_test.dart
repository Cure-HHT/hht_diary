import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _hostHarness(Future<void> Function(BuildContext) onPressed) {
  return MaterialApp(
    theme: buildAppTheme(font: AppFontFamily.inter),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => onPressed(context),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AppDialog', () {
    testWidgets('renders title, body, and actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(font: AppFontFamily.inter),
          home: Scaffold(
            body: AppDialog(
              title: 'Dialog title',
              body: const Text('Dialog body'),
              actions: [AppButton(label: 'Action', onPressed: () {})],
            ),
          ),
        ),
      );
      expect(find.text('Dialog title'), findsOneWidget);
      expect(find.text('Dialog body'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
    });

    testWidgets('renders the close button (Figma: always present)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(font: AppFontFamily.inter),
          home: Scaffold(
            body: AppDialog(
              title: 'Dialog',
              body: const SizedBox.shrink(),
              dismissible: true,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('still renders the close button when dismissible is false', (
      tester,
    ) async {
      // Per the Figma UI Kit the close (X) affordance is unconditional; the
      // `dismissible` flag is retained for API compatibility only.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(font: AppFontFamily.inter),
          home: Scaffold(
            body: AppDialog(
              title: 'Dialog',
              body: const SizedBox.shrink(),
              dismissible: false,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('semanticId emits a Semantics identifier on the dialog root', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(font: AppFontFamily.inter),
          home: Scaffold(
            body: AppDialog(
              title: 'Dialog',
              body: const SizedBox.shrink(),
              semanticId: 'disconnect.dialog',
            ),
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(AppDialog));
      expect(node.identifier, equals('disconnect.dialog'));
    });

    group('.confirmation', () {
      testWidgets('returns true when confirmed', (tester) async {
        bool? result;
        await tester.pumpWidget(
          _hostHarness((ctx) async {
            result = await AppDialog.confirmation(
              context: ctx,
              title: 'Confirm?',
              message: 'Are you sure?',
            );
          }),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AppButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(result, isTrue);
      });

      testWidgets('returns false when cancelled', (tester) async {
        bool? result;
        await tester.pumpWidget(
          _hostHarness((ctx) async {
            result = await AppDialog.confirmation(
              context: ctx,
              title: 'Confirm?',
              message: 'Are you sure?',
            );
          }),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
      });
    });

    group('.destructive', () {
      testWidgets('shows an AppBanner with the warning message', (
        tester,
      ) async {
        await tester.pumpWidget(
          _hostHarness((ctx) async {
            await AppDialog.destructive(
              context: ctx,
              title: 'Delete?',
              message: 'You are about to delete this item.',
              warningMessage:
                  'This action cannot be undone and will revoke access.',
            );
          }),
        );
        await tester.tap(find.text('Open'));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(AppBanner), findsOneWidget);
        expect(
          find.text('This action cannot be undone and will revoke access.'),
          findsOneWidget,
        );
      });
    });

    group('.reason', () {
      testWidgets('free-text variant: returns the trimmed input', (
        tester,
      ) async {
        String? result;
        await tester.pumpWidget(
          _hostHarness((ctx) async {
            result = await AppDialog.reason(context: ctx, title: 'Why?');
          }),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        // Submit is disabled until the field is non-empty.
        final submit = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Submit'),
        );
        expect(submit.onPressed, isNull);
        await tester.enterText(find.byType(TextFormField), '  device issues  ');
        await tester.pump();
        await tester.tap(find.widgetWithText(AppButton, 'Submit'));
        await tester.pumpAndSettle();
        expect(result, equals('device issues'));
      });

      testWidgets('dropdown variant: returns the selected value', (
        tester,
      ) async {
        String? result;
        await tester.pumpWidget(
          _hostHarness((ctx) async {
            result = await AppDialog.reason(
              context: ctx,
              title: 'Why?',
              hintText: 'Pick a reason',
              reasons: const [
                AppDropdownItem(value: 'a', label: 'Reason A'),
                AppDropdownItem(value: 'b', label: 'Reason B'),
              ],
            );
          }),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        // Trigger field shows the hint text — tap it to open the popup.
        await tester.tap(find.text('Pick a reason'));
        await tester.pumpAndSettle();
        // Both options visible in the popup.
        await tester.tap(find.text('Reason B'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AppButton, 'Submit'));
        await tester.pumpAndSettle();
        expect(result, equals('b'));
      });
    });

    group('.acknowledgment', () {
      testWidgets('completes when OK is tapped', (tester) async {
        var completed = false;
        await tester.pumpWidget(
          _hostHarness((ctx) async {
            await AppDialog.acknowledgment(
              context: ctx,
              title: 'Notice',
              message: 'Read this.',
            );
            completed = true;
          }),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(AppButton, 'OK'));
        await tester.pumpAndSettle();
        expect(completed, isTrue);
      });
    });
  });
}
