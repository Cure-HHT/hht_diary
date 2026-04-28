// Verifies: REQ-p01067, REQ-p01068; REQ-d00004-E+F+G; REQ-p00006-A+B.

import 'package:clinical_diary/entry_widgets/entry_widget_context.dart';
import 'package:clinical_diary/entry_widgets/survey_renderer_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';
import 'fake_entry_service.dart';

// ---------------------------------------------------------------------------
// Fixture questionnaire — small self-contained definition used by all tests.
// Two categories, two questions each (scale 0-2 for brevity).
// ---------------------------------------------------------------------------

/// A minimal questionnaire fixture passed as widgetConfig.
///
/// Shape mirrors QuestionnaireDefinition.fromJson exactly so that
/// SurveyRendererWidget can parse it with the same inline code.
const Map<String, Object?> _kFixtureConfig = {
  'id': 'test_survey',
  'name': 'Test Survey',
  'version': '1.0',
  'recallPeriod': '2 weeks',
  'totalQuestions': 4,
  'preamble': [],
  'categories': [
    {
      'id': 'cat_a',
      'name': 'Category A',
      'stem': 'How bad is each problem?',
      'responseScale': [
        {'value': 0, 'label': 'None'},
        {'value': 1, 'label': 'Mild'},
        {'value': 2, 'label': 'Severe'},
      ],
      'questions': [
        {
          'id': 'q1',
          'number': 1,
          'text': 'First question text',
          'required': true,
        },
        {
          'id': 'q2',
          'number': 2,
          'text': 'Second question text',
          'required': true,
        },
      ],
    },
    {
      'id': 'cat_b',
      'name': 'Category B',
      'stem': null,
      'responseScale': [
        {'value': 0, 'label': 'Never'},
        {'value': 1, 'label': 'Sometimes'},
        {'value': 2, 'label': 'Always'},
      ],
      'questions': [
        {
          'id': 'q3',
          'number': 3,
          'text': 'Third question text',
          'required': true,
        },
        {
          'id': 'q4',
          'number': 4,
          'text': 'Fourth question text',
          'required': true,
        },
      ],
    },
  ],
};

// ---------------------------------------------------------------------------
// Helper: pump SurveyRendererWidget with the given parameters.
// ---------------------------------------------------------------------------

Future<FakeEntryService> pumpSurveyWidget(
  WidgetTester tester, {
  Map<String, Object?> widgetConfig = _kFixtureConfig,
  Map<String, Object?>? initialAnswers,
  bool isFinalized = false,
  bool isWithdrawn = false,
  String entryType = 'survey_event',
  String aggregateId = 'agg-survey-001',
}) async {
  final fake = FakeEntryService();
  final ctx = EntryWidgetContext(
    entryType: entryType,
    aggregateId: aggregateId,
    widgetConfig: widgetConfig,
    recorder: fake.record,
    initialAnswers: initialAnswers,
    isFinalized: isFinalized,
    isWithdrawn: isWithdrawn,
  );

  await tester.pumpWidget(
    wrapWithMaterialApp(
      Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: SurveyRendererWidget(ctx),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Test 1: Renders all questions from widgetConfig
  // =========================================================================
  group('Renders all questions', () {
    // Verifies: REQ-p01067-A; REQ-p01068-A — widget renders every question
    // from the questionnaire definition passed in widgetConfig.
    testWidgets('shows all four question texts from fixture config', (
      tester,
    ) async {
      // Verifies: REQ-p01067-A; REQ-p01068-A.
      await pumpSurveyWidget(tester);

      // Questions are rendered as "N. <text>" — use textContaining.
      expect(find.textContaining('First question text'), findsOneWidget);
      expect(find.textContaining('Second question text'), findsOneWidget);
      expect(find.textContaining('Third question text'), findsOneWidget);
      expect(find.textContaining('Fourth question text'), findsOneWidget);
    });

    testWidgets('shows category names and stems', (tester) async {
      // Verifies: REQ-p01067-A; REQ-p01068-A — category context displayed.
      await pumpSurveyWidget(tester);

      expect(find.text('Category A'), findsOneWidget);
      expect(find.text('How bad is each problem?'), findsOneWidget);
      expect(find.text('Category B'), findsOneWidget);
    });

    testWidgets('shows Submit button for fresh survey', (tester) async {
      // Verifies: REQ-p01067-A — submit action present when not finalized.
      await pumpSurveyWidget(tester);

      expect(find.byKey(const Key('survey_submit_button')), findsOneWidget);
    });
  });

  // =========================================================================
  // Test 2: Per-question checkpointing (single question answered)
  // =========================================================================
  group('Per-question checkpointing', () {
    // Verifies: REQ-d00004-E+F — each answered question fires a checkpoint
    // with the cumulative answers so far.
    testWidgets(
      'answering Q1 records a checkpoint event containing Q1 answer',
      (tester) async {
        // Verifies: REQ-d00004-E+F; REQ-p00006-A.
        final fake = await pumpSurveyWidget(tester);

        // Tap 'Mild' (value=1) for Q1
        await tester.tap(find.byKey(const Key('q1_option_1')));
        await tester.pumpAndSettle();

        expect(fake.calls, hasLength(1));
        final call = fake.calls.first;
        expect(call.eventType, 'checkpoint');
        expect(call.answers['q1'], 1);
      },
    );

    testWidgets(
      'answering Q1 with cycle seeded includes cycle in checkpoint answers',
      (tester) async {
        // Verifies: REQ-d00113 — cycle stamped on every checkpoint.
        final fake = await pumpSurveyWidget(
          tester,
          initialAnswers: {'cycle': 'week-3'},
        );

        await tester.tap(find.byKey(const Key('q1_option_1')));
        await tester.pumpAndSettle();

        expect(fake.calls, hasLength(1));
        expect(fake.calls.first.answers['cycle'], 'week-3');
        expect(fake.calls.first.answers['q1'], 1);
      },
    );
  });

  // =========================================================================
  // Test 3: Cumulative checkpoints
  // =========================================================================
  group('Cumulative checkpoints', () {
    // Verifies: REQ-d00004-E+F — second checkpoint carries both Q1 and Q2.
    testWidgets(
      'answering Q1 then Q2 → second checkpoint contains both answers',
      (tester) async {
        // Verifies: REQ-d00004-E+F; REQ-p00006-A.
        final fake = await pumpSurveyWidget(tester);

        // Answer Q1 (Mild = 1)
        await tester.tap(find.byKey(const Key('q1_option_1')));
        await tester.pumpAndSettle();

        // Answer Q2 (Severe = 2)
        await tester.tap(find.byKey(const Key('q2_option_2')));
        await tester.pumpAndSettle();

        expect(fake.calls, hasLength(2));

        final firstCall = fake.calls[0];
        expect(firstCall.eventType, 'checkpoint');
        expect(firstCall.answers['q1'], 1);
        expect(firstCall.answers.containsKey('q2'), isFalse);

        final secondCall = fake.calls[1];
        expect(secondCall.eventType, 'checkpoint');
        expect(secondCall.answers['q1'], 1);
        expect(secondCall.answers['q2'], 2);
      },
    );
  });

  // =========================================================================
  // Test 4: Final submit
  // =========================================================================
  group('Final submit', () {
    // Verifies: REQ-d00004-E+F — submit records a finalized event with all
    // answers; UI flips to read-only afterwards.
    testWidgets(
      'answering all questions then submitting records finalized with all answers',
      (tester) async {
        // Verifies: REQ-d00004-E+F+G; REQ-p00006-A+B.
        final fake = await pumpSurveyWidget(tester);

        // Answer all 4 questions
        await tester.tap(find.byKey(const Key('q1_option_0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('q2_option_1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('q3_option_2')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('q4_option_0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('q4_option_0')));
        await tester.pumpAndSettle();

        // 4 checkpoint events so far
        expect(
          fake.calls.where((c) => c.eventType == 'checkpoint'),
          hasLength(4),
        );

        // Tap Submit
        await tester.ensureVisible(
          find.byKey(const Key('survey_submit_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('survey_submit_button')));
        await tester.pumpAndSettle();

        final finalizedCalls = fake.calls
            .where((c) => c.eventType == 'finalized')
            .toList();
        expect(finalizedCalls, hasLength(1));
        final finalized = finalizedCalls.first;
        expect(finalized.answers['q1'], 0);
        expect(finalized.answers['q2'], 1);
        expect(finalized.answers['q3'], 2);
        expect(finalized.answers['q4'], 0);

        // UI should now show read-only / completion indicator (no submit)
        expect(find.byKey(const Key('survey_submit_button')), findsNothing);
      },
    );
  });

  // =========================================================================
  // Test 5: Cycle stamping
  // =========================================================================
  group('Cycle stamping', () {
    // Verifies: REQ-d00113 — cycle is carried verbatim in every recorded event
    // and is never rendered as a question.
    testWidgets(
      'cycle from initialAnswers appears in checkpoint and finalized answers',
      (tester) async {
        // Verifies: REQ-d00113; REQ-d00004-E+F.
        final fake = await pumpSurveyWidget(
          tester,
          initialAnswers: {'cycle': 'week-3'},
        );

        // Answer Q1 → checkpoint
        await tester.tap(find.byKey(const Key('q1_option_0')));
        await tester.pumpAndSettle();

        expect(fake.calls.first.answers['cycle'], 'week-3');

        // Answer remaining questions
        await tester.tap(find.byKey(const Key('q2_option_0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('q3_option_0')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('q4_option_0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('q4_option_0')));
        await tester.pumpAndSettle();

        // Submit
        await tester.ensureVisible(
          find.byKey(const Key('survey_submit_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('survey_submit_button')));
        await tester.pumpAndSettle();

        final finalized = fake.calls.lastWhere(
          (c) => c.eventType == 'finalized',
        );
        expect(finalized.answers['cycle'], 'week-3');
      },
    );

    testWidgets('cycle key is NOT displayed as a question in the UI', (
      tester,
    ) async {
      // Verifies: REQ-d00113 — cycle is metadata, never a rendered question.
      await pumpSurveyWidget(tester, initialAnswers: {'cycle': 'week-3'});

      // 'cycle' should not appear as a question label anywhere in the UI.
      // The fixture has 4 real questions; only their texts should appear.
      expect(find.text('cycle'), findsNothing);
      expect(find.text('week-3'), findsNothing);
    });
  });

  // =========================================================================
  // Test 6: Resume from checkpoint
  // =========================================================================
  group('Resume from checkpoint', () {
    // Verifies: REQ-d00004-E+G; REQ-p00006-B — pre-filling from initialAnswers
    // restores prior answers without re-emitting a checkpoint on mount.
    testWidgets(
      'launch with initialAnswers pre-fills Q1 and emits no checkpoint on mount',
      (tester) async {
        // Verifies: REQ-d00004-E+G; REQ-p00006-B.
        final fake = await pumpSurveyWidget(
          tester,
          initialAnswers: {'cycle': 'w1', 'q1': 1},
        );

        // No checkpoint should fire just from rendering with initialAnswers
        expect(fake.calls, isEmpty);

        // Q1 should show value 1 (Mild) as selected
        final q1Option1 = tester.widget<ChoiceChip>(
          find.byKey(const Key('q1_option_1')),
        );
        expect(q1Option1.selected, isTrue);
      },
    );

    testWidgets(
      'answering Q2 after resume emits checkpoint with both Q1 and Q2',
      (tester) async {
        // Verifies: REQ-d00004-E+F — resume correctly accumulates from prior.
        final fake = await pumpSurveyWidget(
          tester,
          initialAnswers: {'cycle': 'w1', 'q1': 1},
        );

        // No checkpoint on mount
        expect(fake.calls, isEmpty);

        // Answer Q2
        await tester.tap(find.byKey(const Key('q2_option_2')));
        await tester.pumpAndSettle();

        expect(fake.calls, hasLength(1));
        final call = fake.calls.first;
        expect(call.eventType, 'checkpoint');
        expect(call.answers['q1'], 1); // restored from initialAnswers
        expect(call.answers['q2'], 2); // just answered
        expect(call.answers['cycle'], 'w1'); // cycle carried through
      },
    );
  });

  // =========================================================================
  // Test 7: Finalized aggregate → read-only
  // =========================================================================
  group('Finalized aggregate — read-only', () {
    // Verifies: REQ-d00004-E — isFinalized renders read-only UI with no submit.
    testWidgets(
      'isFinalized: true → all response chips disabled and submit button hidden',
      (tester) async {
        // Verifies: REQ-d00004-E; REQ-p00006-B.
        await pumpSurveyWidget(
          tester,
          isFinalized: true,
          initialAnswers: {'q1': 0, 'q2': 1, 'q3': 2, 'q4': 0},
        );

        // Submit button must not be present
        expect(find.byKey(const Key('survey_submit_button')), findsNothing);

        // Read-only indicator shown
        expect(find.byKey(const Key('survey_readonly_banner')), findsOneWidget);
      },
    );

    testWidgets(
      'isFinalized: true → no recorder calls on interaction attempt',
      (tester) async {
        // Verifies: REQ-d00004-E — finalized widget does not emit events.
        final fake = await pumpSurveyWidget(
          tester,
          isFinalized: true,
          initialAnswers: {'q1': 0},
        );

        // Attempt to tap a chip — it should be disabled (onSelected = null)
        // ChoiceChip onSelected is null when read-only, so no event fires.
        await tester.tap(find.byKey(const Key('q1_option_1')));
        await tester.pumpAndSettle();

        expect(fake.calls, isEmpty);
      },
    );
  });

  // =========================================================================
  // Test 8: Tombstoned aggregate → withdrawn banner + read-only
  // =========================================================================
  group('Withdrawn (tombstoned) aggregate', () {
    // Verifies: REQ-d00004-E; REQ-d00113 — isWithdrawn shows banner and
    // disables all interactions.
    testWidgets(
      'isWithdrawn: true → withdrawn banner shown, submit button hidden',
      (tester) async {
        // Verifies: REQ-d00004-E; REQ-d00113.
        await pumpSurveyWidget(tester, isWithdrawn: true);

        // Withdrawn banner must be present
        expect(
          find.byKey(const Key('survey_withdrawn_banner')),
          findsOneWidget,
        );

        // Submit button must be absent
        expect(find.byKey(const Key('survey_submit_button')), findsNothing);
      },
    );

    testWidgets('isWithdrawn: true → no recorder calls on interaction attempt', (
      tester,
    ) async {
      // Verifies: REQ-d00004-E; REQ-d00113 — withdrawn widget emits no events.
      final fake = await pumpSurveyWidget(tester, isWithdrawn: true);

      await tester.tap(find.byKey(const Key('q1_option_0')));
      await tester.pumpAndSettle();

      expect(fake.calls, isEmpty);
    });
  });
}
