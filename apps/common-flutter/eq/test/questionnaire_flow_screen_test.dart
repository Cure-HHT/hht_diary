// IMPLEMENTS REQUIREMENTS:
//   REQ-p01070: NOSE HHT Questionnaire UI
//   REQ-p01071: QoL Questionnaire UI
//   REQ-p01073: Session Management

import 'package:eq/eq.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

import 'test_helpers.dart';

void main() {
  late QuestionnaireDefinition qolDef;

  setUp(() {
    qolDef = qolDefinition(); // Use QoL (4 questions) for quicker flow tests
  });

  Widget buildFlow({
    QuestionnaireDefinition? definition,
    Future<SubmitResult> Function(QuestionnaireSubmission)? onSubmit,
    VoidCallback? onComplete,
    VoidCallback? onDefer,
  }) {
    return MaterialApp(
      home: QuestionnaireFlowScreen(
        definition: definition ?? qolDef,
        instanceId: 'test-instance-id',
        onSubmit: onSubmit ?? (_) async => const SubmitResult(success: true),
        onComplete: onComplete ?? () {},
        onDefer: onDefer,
      ),
    );
  }

  /// Set up a large enough screen for testing
  void setUpTestScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
  }

  /// Navigate from readiness through all preamble pages
  Future<void> passReadinessAndPreamble(
    WidgetTester tester,
    QuestionnaireDefinition def,
  ) async {
    await tester.tap(find.text("I'm ready"));
    await tester.pumpAndSettle();
    for (var i = 0; i < def.preamble.length; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
  }

  /// Answer all questions with "Sometimes" and navigate to review
  Future<void> answerAllQuestions(
    WidgetTester tester,
    int questionCount,
  ) async {
    for (var i = 0; i < questionCount; i++) {
      await tester.tap(find.text('Sometimes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('starts at readiness screen', (tester) async {
    setUpTestScreen(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(buildFlow());

    expect(find.text("I'm ready"), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('navigates to preamble after "I\'m ready"', (tester) async {
    setUpTestScreen(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(buildFlow());

    await tester.tap(find.text("I'm ready"));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('navigates through all preamble pages', (tester) async {
    setUpTestScreen(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(buildFlow());

    await passReadinessAndPreamble(tester, qolDef);

    expect(find.text('Question 1 of 4'), findsOneWidget);
  });

  testWidgets('can answer question and advance', (tester) async {
    setUpTestScreen(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(buildFlow());

    await passReadinessAndPreamble(tester, qolDef);

    // Select an answer
    await tester.tap(find.text('Sometimes'));
    await tester.pumpAndSettle();

    // Next should now be enabled — tap it
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2 of 4'), findsOneWidget);
  });

  testWidgets('calls onDefer when "Not now" tapped', (tester) async {
    setUpTestScreen(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var deferCalled = false;
    await tester.pumpWidget(buildFlow(onDefer: () => deferCalled = true));

    await tester.tap(find.text('Not now'));
    expect(deferCalled, isTrue);
  });

  testWidgets(
    'full flow: readiness -> preamble -> questions -> review -> submit -> confirmation',
    (tester) async {
      setUpTestScreen(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      QuestionnaireSubmission? capturedSubmission;
      var completeCalled = false;

      await tester.pumpWidget(
        buildFlow(
          onSubmit: (s) async {
            capturedSubmission = s;
            return const SubmitResult(success: true);
          },
          onComplete: () => completeCalled = true,
        ),
      );

      // 1. Readiness + Preamble
      await passReadinessAndPreamble(tester, qolDef);

      // 2. Answer all 4 questions
      await answerAllQuestions(tester, 4);

      // 3. Should be on Review screen
      expect(find.text('Review Your Answers'), findsOneWidget);

      // 4. Submit
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // 5. Should be on confirmation
      expect(find.text('Submitted for Review'), findsOneWidget);
      expect(capturedSubmission, isNotNull);
      expect(capturedSubmission!.responses, hasLength(4));
      expect(capturedSubmission!.instanceId, 'test-instance-id');

      // 6. Done
      await tester.tap(find.text('Done'));
      expect(completeCalled, isTrue);
    },
  );

  testWidgets('handles deleted questionnaire error', (tester) async {
    setUpTestScreen(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var completeCalled = false;
    await tester.pumpWidget(
      buildFlow(
        onSubmit: (_) async =>
            const SubmitResult(success: false, isDeleted: true),
        onComplete: () => completeCalled = true,
      ),
    );

    await passReadinessAndPreamble(tester, qolDef);
    await answerAllQuestions(tester, 4);

    // Submit — should trigger deleted handling
    await tester.tap(find.text('Submit'));
    // Use pump() instead of pumpAndSettle() because the snackbar animation
    // prevents settling
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(completeCalled, isTrue);
  });

  testWidgets('handles generic submit error', (tester) async {
    setUpTestScreen(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      buildFlow(
        onSubmit: (_) async =>
            const SubmitResult(success: false, error: 'Server error'),
      ),
    );

    await passReadinessAndPreamble(tester, qolDef);
    await answerAllQuestions(tester, 4);

    // Submit — should show error and stay on review
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Review Your Answers'), findsOneWidget);
    expect(find.text('Server error'), findsOneWidget);
  });
}
