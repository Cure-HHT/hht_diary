// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content

import 'package:eq/eq.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

import 'test_helpers.dart';

void main() {
  late QuestionnaireDefinition def;
  late Map<String, QuestionResponse> responses;

  setUp(() {
    def = qolDefinition(); // Use QoL (4 questions) for simpler tests
    responses = {
      'qol_q1': const QuestionResponse(
        questionId: 'qol_q1',
        value: 2,
        displayLabel: 'Sometimes',
        normalizedLabel: '2',
      ),
      'qol_q2': const QuestionResponse(
        questionId: 'qol_q2',
        value: 1,
        displayLabel: 'Rarely',
        normalizedLabel: '1',
      ),
      'qol_q3': const QuestionResponse(
        questionId: 'qol_q3',
        value: 0,
        displayLabel: 'Never',
        normalizedLabel: '0',
      ),
      'qol_q4': const QuestionResponse(
        questionId: 'qol_q4',
        value: 3,
        displayLabel: 'Often',
        normalizedLabel: '3',
      ),
    };
  });

  testWidgets('shows "Review Your Answers" title', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ReviewScreen(
          definition: def,
          responses: responses,
          onEdit: (_) {},
          onSubmit: () {},
        ),
      ),
    );

    expect(find.text('Review Your Answers'), findsOneWidget);
  });

  testWidgets('shows all questions with answers', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ReviewScreen(
          definition: def,
          responses: responses,
          onEdit: (_) {},
          onSubmit: () {},
        ),
      ),
    );

    expect(find.text('Sometimes'), findsOneWidget);
    expect(find.text('Rarely'), findsOneWidget);
    expect(find.text('Never'), findsOneWidget);
    expect(find.text('Often'), findsOneWidget);
  });

  testWidgets('shows Submit button', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ReviewScreen(
          definition: def,
          responses: responses,
          onEdit: (_) {},
          onSubmit: () {},
        ),
      ),
    );

    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets('calls onEdit when question tapped', (tester) async {
    int? editedIndex;
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ReviewScreen(
          definition: def,
          responses: responses,
          onEdit: (i) => editedIndex = i,
          onSubmit: () {},
        ),
      ),
    );

    // Tap the first question's card area
    await tester.tap(find.text('Sometimes'));
    expect(editedIndex, 0);
  });

  testWidgets('shows Submitting... when isSubmitting is true', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ReviewScreen(
          definition: def,
          responses: responses,
          onEdit: (_) {},
          onSubmit: () {},
          isSubmitting: true,
        ),
      ),
    );

    expect(find.text('Submitting...'), findsOneWidget);
    // Should show a spinner
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows "Not answered" for missing responses', (tester) async {
    await tester.pumpWidget(
      wrapWithMaterialApp(
        ReviewScreen(
          definition: def,
          responses: const {}, // No responses
          onEdit: (_) {},
          onSubmit: () {},
        ),
      ),
    );

    expect(find.text('Not answered'), findsNWidgets(4));
  });
}
