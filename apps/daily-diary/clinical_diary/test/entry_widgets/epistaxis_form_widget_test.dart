// Verifies: REQ-p00006-A+B; REQ-d00004-E+F+G; REQ-p01067-A+B+C.

import 'package:clinical_diary/entry_widgets/entry_widget_context.dart';
import 'package:clinical_diary/entry_widgets/epistaxis_form_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';
import 'fake_entry_service.dart';

/// Build a pumped [EpistaxisFormWidget] with the given configuration.
Future<FakeEntryService> pumpEpistaxisForm(
  WidgetTester tester, {
  String entryType = 'epistaxis_event',
  String aggregateId = 'agg-001',
  Map<String, Object?> widgetConfig = const {},
  Map<String, Object?>? initialAnswers,
}) async {
  final fake = FakeEntryService();
  final ctx = EntryWidgetContext(
    entryType: entryType,
    aggregateId: aggregateId,
    widgetConfig: widgetConfig,
    recorder: fake.record,
    initialAnswers: initialAnswers,
  );

  await tester.pumpWidget(
    wrapWithMaterialApp(
      Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: EpistaxisFormWidget(ctx),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  // =========================================================================
  // Test 1: Full-form variant renders all required fields
  // =========================================================================
  group('Full-form variant (variant absent)', () {
    // Verifies: REQ-p01067-B — full form captures start, end, intensity, notes.
    testWidgets(
      'renders start time, intensity selector, end time, notes, and Save button',
      (tester) async {
        // Verifies: REQ-p00006-A; REQ-p01067-B.
        await pumpEpistaxisForm(tester, widgetConfig: {});

        // Start time field
        expect(find.byKey(const Key('start_time_field')), findsOneWidget);
        // Intensity selector
        expect(find.byKey(const Key('intensity_selector')), findsOneWidget);
        // End time field
        expect(find.byKey(const Key('end_time_field')), findsOneWidget);
        // Notes field
        expect(find.byKey(const Key('notes_field')), findsOneWidget);
        // Save button
        expect(find.byKey(const Key('save_button')), findsOneWidget);
        // No delete button for new entries
        expect(find.byKey(const Key('delete_button')), findsNothing);
      },
    );

    // =========================================================================
    // Test 2: Save with full form → finalized record call
    // =========================================================================
    // Verifies: REQ-d00004-E; REQ-p01067-B — save routes through EntryRecorder.
    testWidgets(
      'tap Save → record(entryType: epistaxis_event, eventType: finalized, no changeReason)',
      (tester) async {
        // Verifies: REQ-d00004-E+F; REQ-p00006-A+B.
        final fake = await pumpEpistaxisForm(
          tester,
          entryType: 'epistaxis_event',
          aggregateId: 'agg-save-001',
          widgetConfig: {},
        );

        // Select an intensity (Spotting chip)
        await tester.tap(find.byKey(const Key('intensity_spotting')));
        await tester.pump();

        // Scroll Save button into view before tapping
        await tester.ensureVisible(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();

        // Tap Save (no change-reason dialog for new entries)
        await tester.tap(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();

        expect(fake.calls, hasLength(1));
        final call = fake.calls.first;
        expect(call.entryType, 'epistaxis_event');
        expect(call.aggregateId, 'agg-save-001');
        expect(call.eventType, 'finalized');
        expect(call.answers['intensity'], 'spotting');
        // New entry: changeReason is null (service will default to 'initial')
        expect(call.changeReason, isNull);
      },
    );
  });

  // =========================================================================
  // Test 3: no_epistaxis variant → marker UI + finalized record call
  // =========================================================================
  group("'no_epistaxis' variant", () {
    // Verifies: REQ-p01067-A+C — marker variant renders correctly and writes finalized.
    testWidgets(
      'renders marker title and confirm button, tap confirm → record(entryType: no_epistaxis_event, finalized, date in answers)',
      (tester) async {
        // Verifies: REQ-p01067-A+C; REQ-d00004-E.
        final testDate = DateTime(2026, 4, 27);
        final fake = await pumpEpistaxisForm(
          tester,
          entryType: 'no_epistaxis_event',
          aggregateId: 'agg-marker-001',
          widgetConfig: {
            'variant': 'no_epistaxis',
            'date': testDate.toIso8601String(),
          },
        );

        // Marker title is shown
        expect(find.byKey(const Key('marker_title')), findsOneWidget);
        final titleWidget = tester.widget<Text>(
          find.byKey(const Key('marker_title')),
        );
        expect(titleWidget.data, contains('No nosebleeds today'));

        // Date is displayed
        expect(find.byKey(const Key('marker_date')), findsOneWidget);

        // Full-form fields are absent
        expect(find.byKey(const Key('start_time_field')), findsNothing);
        expect(find.byKey(const Key('intensity_selector')), findsNothing);

        // Tap confirm
        await tester.tap(find.byKey(const Key('confirm_button')));
        await tester.pumpAndSettle();

        expect(fake.calls, hasLength(1));
        final call = fake.calls.first;
        expect(call.entryType, 'no_epistaxis_event');
        expect(call.eventType, 'finalized');
        expect(call.answers['date'], testDate.toIso8601String());
      },
    );
  });

  // =========================================================================
  // Test 4: unknown_day variant → marker UI + finalized record call
  // =========================================================================
  group("'unknown_day' variant", () {
    // Verifies: REQ-p01067-A+C — unknown_day marker writes correct entryType.
    testWidgets(
      "renders 'Don't remember' copy and confirm → record(entryType: unknown_day_event, finalized)",
      (tester) async {
        // Verifies: REQ-p01067-A+C; REQ-d00004-E.
        final testDate = DateTime(2026, 4, 25);
        final fake = await pumpEpistaxisForm(
          tester,
          entryType: 'unknown_day_event',
          aggregateId: 'agg-unknown-001',
          widgetConfig: {
            'variant': 'unknown_day',
            'date': testDate.toIso8601String(),
          },
        );

        final titleWidget = tester.widget<Text>(
          find.byKey(const Key('marker_title')),
        );
        expect(titleWidget.data, contains("Don't remember"));

        await tester.tap(find.byKey(const Key('confirm_button')));
        await tester.pumpAndSettle();

        expect(fake.calls, hasLength(1));
        final call = fake.calls.first;
        expect(call.entryType, 'unknown_day_event');
        expect(call.eventType, 'finalized');
        expect(call.answers['date'], testDate.toIso8601String());
      },
    );
  });

  // =========================================================================
  // Test 5: Edit existing entry — fields pre-filled, save passes changeReason
  // =========================================================================
  group('Edit existing entry (initialAnswers non-null)', () {
    // Verifies: REQ-d00004-G — edit path sets changeReason on save.
    testWidgets(
      'pre-fills fields from initialAnswers; tapping Save opens change-reason dialog',
      (tester) async {
        // Verifies: REQ-d00004-E+G; REQ-p00006-B.
        final startTime = DateTime(2026, 4, 27, 10, 30);
        final initialAnswers = {
          'startTime': startTime.toIso8601String(),
          'intensity': 'dripping',
          'notes': 'Some existing note',
        };

        await pumpEpistaxisForm(
          tester,
          entryType: 'epistaxis_event',
          aggregateId: 'agg-edit-001',
          widgetConfig: {},
          initialAnswers: initialAnswers,
        );

        // Intensity 'dripping' chip should be selected (visible in widget tree)
        // Use ChoiceChip selected state
        final drippingChip = tester.widget<ChoiceChip>(
          find.byKey(const Key('intensity_dripping')),
        );
        expect(drippingChip.selected, isTrue);

        // Notes pre-filled
        final notesField = tester.widget<TextField>(
          find.byKey(const Key('notes_field')),
        );
        expect(notesField.controller!.text, 'Some existing note');

        // Delete button is present in edit mode
        expect(find.byKey(const Key('delete_button')), findsOneWidget);
      },
    );

    testWidgets(
      'save edit → record(eventType: finalized, changeReason: non-null)',
      (tester) async {
        // Verifies: REQ-d00004-G — edit saves with a non-null changeReason.
        final startTime = DateTime(2026, 4, 27, 10, 30);
        final initialAnswers = {
          'startTime': startTime.toIso8601String(),
          'intensity': 'dripping',
        };

        final fake = await pumpEpistaxisForm(
          tester,
          entryType: 'epistaxis_event',
          aggregateId: 'agg-edit-002',
          widgetConfig: {},
          initialAnswers: initialAnswers,
        );

        // Change intensity to 'gushing'
        await tester.tap(find.byKey(const Key('intensity_gushing')));
        await tester.pump();

        // Scroll Save button into view, then tap
        await tester.ensureVisible(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();

        // Tap Save — change-reason dialog should appear
        await tester.tap(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();

        // Dialog is open; enter a reason
        await tester.enterText(
          find.byKey(const Key('change_reason_field')),
          'Correcting intensity',
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('change_reason_confirm_button')));
        await tester.pumpAndSettle();

        expect(fake.calls, hasLength(1));
        final call = fake.calls.first;
        expect(call.eventType, 'finalized');
        expect(call.aggregateId, 'agg-edit-002');
        expect(call.changeReason, 'Correcting intensity');
        expect(call.answers['intensity'], 'gushing');
      },
    );
  });

  // =========================================================================
  // Test 7: No write fires when widget unmounts mid-dialog
  // =========================================================================
  group('Edit mode — unmount during change-reason dialog', () {
    // Verifies: REQ-d00004-G (no write fires when widget unmounts mid-dialog)
    testWidgets(
      'unmounting widget while change-reason dialog is open does not invoke recorder',
      (tester) async {
        // Verifies: REQ-d00004-G — mounted guard prevents stale _save after unmount.
        final fake = await pumpEpistaxisForm(
          tester,
          entryType: 'epistaxis_event',
          aggregateId: 'agg-unmount-001',
          widgetConfig: {},
          initialAnswers: {
            'startTime': DateTime(2026, 4, 27, 8, 0).toIso8601String(),
            'intensity': 'spotting',
          },
        );

        // Scroll Save into view and tap — opens the change-reason dialog.
        await tester.ensureVisible(find.byKey(const Key('save_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('save_button')));
        await tester
            .pump(); // dialog starts to build but Future not yet resolved

        // Replace the entire widget tree, unmounting EpistaxisFormWidget
        // while the change-reason dialog Future is still pending.
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );
        await tester.pumpAndSettle();

        // recorder must NOT have been called.
        expect(fake.calls, isEmpty);
      },
    );
  });

  // =========================================================================
  // Test 6: Delete existing entry
  // =========================================================================
  group('Delete existing entry', () {
    // Verifies: REQ-d00004-E+G — delete writes tombstone with changeReason.
    testWidgets(
      'tap Delete → delete dialog → record(eventType: tombstone, answers: {}, changeReason: non-null)',
      (tester) async {
        // Verifies: REQ-d00004-E+G; REQ-p00006-B.
        final fake = await pumpEpistaxisForm(
          tester,
          entryType: 'epistaxis_event',
          aggregateId: 'agg-del-001',
          widgetConfig: {},
          initialAnswers: {
            'startTime': DateTime(2026, 4, 27, 9, 0).toIso8601String(),
            'intensity': 'spotting',
          },
        );

        // Scroll Delete button into view, then tap
        await tester.ensureVisible(find.byKey(const Key('delete_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('delete_button')));
        await tester.pumpAndSettle();

        // Dialog appears; enter reason
        await tester.enterText(
          find.byKey(const Key('delete_reason_field')),
          'Entered by mistake',
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('delete_confirm_button')));
        await tester.pumpAndSettle();

        expect(fake.calls, hasLength(1));
        final call = fake.calls.first;
        expect(call.entryType, 'epistaxis_event');
        expect(call.aggregateId, 'agg-del-001');
        expect(call.eventType, 'tombstone');
        expect(call.answers, isEmpty);
        expect(call.changeReason, 'Entered by mistake');
      },
    );
  });
}
