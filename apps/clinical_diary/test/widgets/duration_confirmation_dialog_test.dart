// IMPLEMENTS REQUIREMENTS:
//   REQ-CAL-p00002: Short Duration Nosebleed Confirmation
//   REQ-CAL-p00003: Long Duration Nosebleed Confirmation

import 'package:clinical_diary/l10n/app_localizations.dart';
import 'package:clinical_diary/widgets/duration_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DurationConfirmationType', () {
    test('has short type', () {
      expect(DurationConfirmationType.short, isNotNull);
    });

    test('has long type', () {
      expect(DurationConfirmationType.long, isNotNull);
    });

    test('values contains both types', () {
      expect(DurationConfirmationType.values, hasLength(2));
      expect(
        DurationConfirmationType.values,
        containsAll([
          DurationConfirmationType.short,
          DurationConfirmationType.long,
        ]),
      );
    });
  });

  group('DurationConfirmationDialog', () {
    /// Helper to build a test app that shows the dialog directly
    Widget buildDialogTestApp({
      required DurationConfirmationType type,
      required int durationMinutes,
      int? thresholdMinutes,
    }) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: DurationConfirmationDialog(
            type: type,
            durationMinutes: durationMinutes,
            thresholdMinutes: thresholdMinutes,
          ),
        ),
      );
    }

    group('short duration type', () {
      testWidgets('displays short duration title', (tester) async {
        await tester.pumpWidget(
          buildDialogTestApp(
            type: DurationConfirmationType.short,
            durationMinutes: 1,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Short Duration'), findsOneWidget);
      });

      testWidgets('displays short duration message', (tester) async {
        await tester.pumpWidget(
          buildDialogTestApp(
            type: DurationConfirmationType.short,
            durationMinutes: 1,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('under 1 minute'), findsOneWidget);
      });

      testWidgets('displays formatted duration for 0 minutes', (tester) async {
        await tester.pumpWidget(
          buildDialogTestApp(
            type: DurationConfirmationType.short,
            durationMinutes: 0,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0m'), findsOneWidget);
      });

      testWidgets('displays formatted duration for 1 minute', (tester) async {
        await tester.pumpWidget(
          buildDialogTestApp(
            type: DurationConfirmationType.short,
            durationMinutes: 1,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1m'), findsOneWidget);
      });

      testWidgets('displays formatted duration for 30 minutes', (tester) async {
        await tester.pumpWidget(
          buildDialogTestApp(
            type: DurationConfirmationType.short,
            durationMinutes: 30,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('30m'), findsOneWidget);
      });
    });

    group('long duration type', () {
      testWidgets('displays long duration title', (tester) async {
        await tester.pumpWidget(
          buildDialogTestApp(
            type: DurationConfirmationType.long,
            durationMinutes: 120,
            thresholdMinutes: 60,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Long Duration'), findsOneWidget);
      });

      testWidgets('displays formatted duration in hours', (tester) async {
        await tester.pumpWidget(
          buildDialogTestApp(
            type: DurationConfirmationType.long,
            durationMinutes: 120,
            thresholdMinutes: 60,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2h'), findsOneWidget);
      });

      testWidgets('displays formatted duration with hours and minutes', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildDialogTestApp(
            type: DurationConfirmationType.long,
            durationMinutes: 90,
            thresholdMinutes: 60,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1h 30m'), findsOneWidget);
      });

      testWidgets('uses default threshold of 60 when not specified', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildDialogTestApp(
            type: DurationConfirmationType.long,
            durationMinutes: 90,
            // No thresholdMinutes specified
          ),
        );
        await tester.pumpAndSettle();

        // Message should mention the default 1h threshold
        expect(find.textContaining('1h'), findsWidgets);
      });
    });

    group('dialog buttons', () {
      testWidgets('displays Yes and No buttons', (tester) async {
        await tester.pumpWidget(
          buildDialogTestApp(
            type: DurationConfirmationType.short,
            durationMinutes: 1,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Yes'), findsOneWidget);
        expect(find.text('No'), findsOneWidget);
      });

      testWidgets('tapping Yes returns true', (tester) async {
        bool? dialogResult;

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
                    dialogResult = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => const DurationConfirmationDialog(
                        type: DurationConfirmationType.short,
                        durationMinutes: 1,
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

        await tester.tap(find.text('Yes'));
        await tester.pumpAndSettle();

        expect(dialogResult, true);
      });

      testWidgets('tapping No returns false', (tester) async {
        bool? dialogResult;

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
                    dialogResult = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => const DurationConfirmationDialog(
                        type: DurationConfirmationType.short,
                        durationMinutes: 1,
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

        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();

        expect(dialogResult, false);
      });
    });

    group('static show method', () {
      testWidgets('returns true when user taps Yes', (tester) async {
        bool? result;

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
                    result = await DurationConfirmationDialog.show(
                      context: context,
                      type: DurationConfirmationType.short,
                      durationMinutes: 1,
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

        await tester.tap(find.text('Yes'));
        await tester.pumpAndSettle();

        expect(result, true);
      });

      testWidgets('returns false when user taps No', (tester) async {
        bool? result;

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
                    result = await DurationConfirmationDialog.show(
                      context: context,
                      type: DurationConfirmationType.long,
                      durationMinutes: 120,
                      thresholdMinutes: 60,
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

        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();

        expect(result, false);
      });
    });

    group('UI elements', () {
      testWidgets('displays timer icon', (tester) async {
        await tester.pumpWidget(
          buildDialogTestApp(
            type: DurationConfirmationType.short,
            durationMinutes: 1,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      });
    });
  });
}
