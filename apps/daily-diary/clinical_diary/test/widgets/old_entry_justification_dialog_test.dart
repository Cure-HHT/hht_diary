// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00001: Old Entry Modification Justification

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/widgets/old_entry_justification_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OldEntryJustification', () {
    test('has enteredFromPaperRecords type', () {
      expect(OldEntryJustification.enteredFromPaperRecords, isNotNull);
    });

    test('has rememberedSpecificEvent type', () {
      expect(OldEntryJustification.rememberedSpecificEvent, isNotNull);
    });

    test('has estimatedEvent type', () {
      expect(OldEntryJustification.estimatedEvent, isNotNull);
    });

    test('has other type', () {
      expect(OldEntryJustification.other, isNotNull);
    });

    test('values contains all types', () {
      expect(OldEntryJustification.values, hasLength(4));
      expect(
        OldEntryJustification.values,
        containsAll([
          OldEntryJustification.enteredFromPaperRecords,
          OldEntryJustification.rememberedSpecificEvent,
          OldEntryJustification.estimatedEvent,
          OldEntryJustification.other,
        ]),
      );
    });
  });

  group('OldEntryJustificationDialog', () {
    /// Helper to build a test app that shows the dialog directly
    Widget buildDialogTestApp({
      required void Function(OldEntryJustification) onConfirm,
    }) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(body: OldEntryJustificationDialog(onConfirm: onConfirm)),
      );
    }

    group('dialog content', () {
      testWidgets('displays dialog title', (tester) async {
        await tester.pumpWidget(buildDialogTestApp(onConfirm: (_) {}));
        await tester.pumpAndSettle();

        // Should show the title
        expect(find.text('Old Entry Modification'), findsOneWidget);
      });

      testWidgets('displays prompt text', (tester) async {
        await tester.pumpWidget(buildDialogTestApp(onConfirm: (_) {}));
        await tester.pumpAndSettle();

        // Should show the prompt
        expect(find.textContaining('Please explain why'), findsOneWidget);
      });

      testWidgets('displays all justification options', (tester) async {
        await tester.pumpWidget(buildDialogTestApp(onConfirm: (_) {}));
        await tester.pumpAndSettle();

        // Should show all 4 radio options
        expect(find.byType(Radio<OldEntryJustification>), findsNWidgets(4));
      });

      testWidgets('displays Cancel and Confirm buttons', (tester) async {
        await tester.pumpWidget(buildDialogTestApp(onConfirm: (_) {}));
        await tester.pumpAndSettle();

        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Confirm'), findsOneWidget);
      });
    });

    group('radio selection', () {
      testWidgets('Confirm button is disabled when nothing selected', (
        tester,
      ) async {
        await tester.pumpWidget(buildDialogTestApp(onConfirm: (_) {}));
        await tester.pumpAndSettle();

        // Find the Confirm button and verify it's disabled
        final confirmButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirm'),
        );
        expect(confirmButton.onPressed, isNull);
      });

      testWidgets('selecting a radio option enables Confirm button', (
        tester,
      ) async {
        await tester.pumpWidget(buildDialogTestApp(onConfirm: (_) {}));
        await tester.pumpAndSettle();

        // Tap on the first radio option
        await tester.tap(find.byType(Radio<OldEntryJustification>).first);
        await tester.pumpAndSettle();

        // Find the Confirm button and verify it's now enabled
        final confirmButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirm'),
        );
        expect(confirmButton.onPressed, isNotNull);
      });

      testWidgets('tapping radio text also selects the option', (tester) async {
        await tester.pumpWidget(buildDialogTestApp(onConfirm: (_) {}));
        await tester.pumpAndSettle();

        // Tap on the "Other" option text
        await tester.tap(find.text('Other'));
        await tester.pumpAndSettle();

        // Confirm button should now be enabled
        final confirmButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirm'),
        );
        expect(confirmButton.onPressed, isNotNull);
      });
    });

    group('dialog buttons', () {
      testWidgets('tapping Cancel closes dialog without calling onConfirm', (
        tester,
      ) async {
        var onConfirmCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog<OldEntryJustification>(
                      context: context,
                      builder: (ctx) => OldEntryJustificationDialog(
                        onConfirm: (_) {
                          onConfirmCalled = true;
                        },
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(onConfirmCalled, false);
      });

      testWidgets(
        'tapping Confirm calls onConfirm with selected justification',
        (tester) async {
          OldEntryJustification? confirmedJustification;

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en')],
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      showDialog<OldEntryJustification>(
                        context: context,
                        builder: (ctx) => OldEntryJustificationDialog(
                          onConfirm: (justification) {
                            confirmedJustification = justification;
                            Navigator.pop(ctx, justification);
                          },
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();

          // Select a justification option
          await tester.tap(find.text('Other'));
          await tester.pumpAndSettle();

          // Tap Confirm
          await tester.tap(find.text('Confirm'));
          await tester.pumpAndSettle();

          expect(confirmedJustification, OldEntryJustification.other);
        },
      );
    });

    group('static show method', () {
      testWidgets('returns null when cancelled', (tester) async {
        OldEntryJustification? result;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await OldEntryJustificationDialog.show(
                      context: context,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(result, isNull);
      });

      testWidgets('returns selected justification when confirmed', (
        tester,
      ) async {
        OldEntryJustification? result;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await OldEntryJustificationDialog.show(
                      context: context,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Select "Other" option
        await tester.tap(find.text('Other'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        expect(result, OldEntryJustification.other);
      });
    });
  });
}
