// IMPLEMENTS REQUIREMENTS:
//   REQ-p01070: NOSE HHT Questionnaire UI

import 'package:eq/eq.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

import 'test_helpers.dart';

void main() {
  late QuestionnaireDefinition def;
  late QuestionCategory physicalCat;
  late QuestionDefinition firstQuestion;

  setUp(() {
    def = noseHhtDefinition();
    physicalCat = def.categories[0]; // Physical
    firstQuestion = physicalCat.questions[0]; // nose_physical_1
  });

  void setUpScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
  }

  void tearDownScreen(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets('displays question text', (tester) async {
    setUpScreen(tester);
    addTearDown(() => tearDownScreen(tester));
    await tester.pumpWidget(
      wrapWithMaterialApp(
        QuestionScreen(
          question: firstQuestion,
          category: physicalCat,
          currentQuestionNumber: 1,
          totalQuestions: 29,
          selectedValue: null,
          onAnswer: (_) {},
          onNext: () {},
          onBack: null,
          showCategoryHeader: true,
        ),
      ),
    );

    expect(
      find.text('Blood running down the back of your throat'),
      findsOneWidget,
    );
  });

  testWidgets('shows progress bar', (tester) async {
    setUpScreen(tester);
    addTearDown(() => tearDownScreen(tester));
    await tester.pumpWidget(
      wrapWithMaterialApp(
        QuestionScreen(
          question: firstQuestion,
          category: physicalCat,
          currentQuestionNumber: 5,
          totalQuestions: 29,
          selectedValue: null,
          onAnswer: (_) {},
          onNext: () {},
          onBack: () {},
          showCategoryHeader: false,
        ),
      ),
    );

    expect(find.text('Question 5 of 29'), findsOneWidget);
  });

  testWidgets('shows category header when showCategoryHeader is true', (
    tester,
  ) async {
    setUpScreen(tester);
    addTearDown(() => tearDownScreen(tester));
    await tester.pumpWidget(
      wrapWithMaterialApp(
        QuestionScreen(
          question: firstQuestion,
          category: physicalCat,
          currentQuestionNumber: 1,
          totalQuestions: 29,
          selectedValue: null,
          onAnswer: (_) {},
          onNext: () {},
          onBack: null,
          showCategoryHeader: true,
        ),
      ),
    );

    expect(find.text('Physical'), findsOneWidget);
  });

  testWidgets('hides category header when showCategoryHeader is false', (
    tester,
  ) async {
    setUpScreen(tester);
    addTearDown(() => tearDownScreen(tester));
    await tester.pumpWidget(
      wrapWithMaterialApp(
        QuestionScreen(
          question: firstQuestion,
          category: physicalCat,
          currentQuestionNumber: 2,
          totalQuestions: 29,
          selectedValue: null,
          onAnswer: (_) {},
          onNext: () {},
          onBack: () {},
          showCategoryHeader: false,
        ),
      ),
    );

    expect(find.text('Physical'), findsNothing);
  });

  testWidgets('Next button disabled when no answer selected', (tester) async {
    setUpScreen(tester);
    addTearDown(() => tearDownScreen(tester));
    await tester.pumpWidget(
      wrapWithMaterialApp(
        QuestionScreen(
          question: firstQuestion,
          category: physicalCat,
          currentQuestionNumber: 1,
          totalQuestions: 29,
          selectedValue: null,
          onAnswer: (_) {},
          onNext: () {},
          onBack: null,
          showCategoryHeader: false,
        ),
      ),
    );

    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('Next button enabled when answer selected', (tester) async {
    setUpScreen(tester);
    addTearDown(() => tearDownScreen(tester));
    await tester.pumpWidget(
      wrapWithMaterialApp(
        QuestionScreen(
          question: firstQuestion,
          category: physicalCat,
          currentQuestionNumber: 1,
          totalQuestions: 29,
          selectedValue: 2,
          onAnswer: (_) {},
          onNext: () {},
          onBack: null,
          showCategoryHeader: false,
        ),
      ),
    );

    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(nextButton.onPressed, isNotNull);
  });

  testWidgets('Back button not shown on first question', (tester) async {
    setUpScreen(tester);
    addTearDown(() => tearDownScreen(tester));
    await tester.pumpWidget(
      wrapWithMaterialApp(
        QuestionScreen(
          question: firstQuestion,
          category: physicalCat,
          currentQuestionNumber: 1,
          totalQuestions: 29,
          selectedValue: null,
          onAnswer: (_) {},
          onNext: () {},
          onBack: null,
          showCategoryHeader: false,
        ),
      ),
    );

    expect(find.text('Back'), findsNothing);
  });

  testWidgets('Back button shown on non-first question', (tester) async {
    setUpScreen(tester);
    addTearDown(() => tearDownScreen(tester));
    await tester.pumpWidget(
      wrapWithMaterialApp(
        QuestionScreen(
          question: firstQuestion,
          category: physicalCat,
          currentQuestionNumber: 2,
          totalQuestions: 29,
          selectedValue: null,
          onAnswer: (_) {},
          onNext: () {},
          onBack: () {},
          showCategoryHeader: false,
        ),
      ),
    );

    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('calls onAnswer when option selected', (tester) async {
    setUpScreen(tester);
    addTearDown(() => tearDownScreen(tester));
    int? selected;
    await tester.pumpWidget(
      wrapWithMaterialApp(
        QuestionScreen(
          question: firstQuestion,
          category: physicalCat,
          currentQuestionNumber: 1,
          totalQuestions: 29,
          selectedValue: null,
          onAnswer: (v) => selected = v,
          onNext: () {},
          onBack: null,
          showCategoryHeader: false,
        ),
      ),
    );

    await tester.tap(find.text('Moderate problem'));
    expect(selected, 2);
  });
}
