import 'dart:async';

import 'package:eq/eq.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trial_data_types/trial_data_types.dart';

import 'test_helpers.dart';

// Verifies: DIARY-GUI-questionnaire-portal-sent-workflow/A+B+C+I+P+Q
// Verifies: DIARY-PRD-questionnaire-session-timeout/C
// Verifies: DIARY-GUI-questionnaire-session-expiry/B+D+E+G
// Verifies: DIARY-BASE-questionnaire-coordinator-workflow/D
// Verifies: DIARY-DEV-inbound-event-on-receipt/C
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
    void Function(QuestionnaireSubmission)? onCheckpoint,
    List<QuestionResponse>? initialResponses,
    Future<bool> Function()? onSessionExpired,
  }) {
    return MaterialApp(
      home: QuestionnaireFlowScreen(
        definition: definition ?? qolDef,
        instanceId: 'test-instance-id',
        onSubmit: onSubmit ?? (_) async => const SubmitResult(success: true),
        onComplete: onComplete ?? () {},
        onDefer: onDefer,
        onCheckpoint: onCheckpoint,
        initialResponses: initialResponses,
        onSessionExpired: onSessionExpired,
      ),
    );
  }

  /// Build a QuestionResponse for the QoL "Sometimes" (value=2) option.
  QuestionResponse qolResponse(String questionId, {int value = 2}) {
    const labels = {
      0: 'Never',
      1: 'Rarely',
      2: 'Sometimes',
      3: 'Often',
      4: 'Always',
    };
    return QuestionResponse(
      questionId: questionId,
      value: value,
      displayLabel: labels[value]!,
      normalizedLabel: value.toString(),
    );
  }

  /// Build a launcher that shows the entry-point screen the participant came
  /// from, so we can assert that pressing Home pops back to it.
  Widget buildHomeLauncher({
    void Function(QuestionnaireSubmission)? onCheckpoint,
    Future<SubmitResult> Function(QuestionnaireSubmission)? onSubmit,
    void Function()? onComplete,
    void Function()? onDefer,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => QuestionnaireFlowScreen(
                    definition: qolDef,
                    instanceId: 'test-instance-id',
                    onSubmit:
                        onSubmit ??
                        (_) async => const SubmitResult(success: true),
                    onComplete: onComplete ?? () {},
                    onDefer: onDefer,
                    onCheckpoint: onCheckpoint,
                  ),
                ),
              ),
              child: const Text('open-flow'),
            ),
          ),
        ),
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

  group('Edit mode — return to review (CUR-1119)', () {
    testWidgets(
      'tapping Edit on question 2 then Next returns to review screen',
      (tester) async {
        setUpTestScreen(tester);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(buildFlow());

        await passReadinessAndPreamble(tester, qolDef);
        await answerAllQuestions(tester, 4);

        // On review screen — tap the second review card (question 2, index 1)
        expect(find.text('Review Your Answers'), findsOneWidget);
        await tester.tap(find.byType(Card).at(1));
        await tester.pumpAndSettle();

        // Should be on question 2 (index 1 → "Question 2 of 4")
        expect(find.text('Question 2 of 4'), findsOneWidget);

        // Change answer and tap Next
        await tester.tap(find.text('Never'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // Should return directly to review — NOT question 3
        expect(find.text('Review Your Answers'), findsOneWidget);
        expect(find.text('Question 3 of 4'), findsNothing);
      },
    );

    testWidgets(
      'tapping Edit, pressing Back, then Next still returns to review',
      (tester) async {
        setUpTestScreen(tester);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(buildFlow());

        await passReadinessAndPreamble(tester, qolDef);
        await answerAllQuestions(tester, 4);

        // Tap the third review card (question 3, index 2)
        expect(find.text('Review Your Answers'), findsOneWidget);
        await tester.tap(find.byType(Card).at(2));
        await tester.pumpAndSettle();

        expect(find.text('Question 3 of 4'), findsOneWidget);

        // Press Back (goes to question 2) — still in edit mode
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Question 2 of 4'), findsOneWidget);

        // Press Next — should go to review, not question 3
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        expect(find.text('Review Your Answers'), findsOneWidget);
        expect(find.text('Question 3 of 4'), findsNothing);
      },
    );

    testWidgets(
      'normal forward flow (no edit) still advances question by question',
      (tester) async {
        setUpTestScreen(tester);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        await tester.pumpWidget(buildFlow());

        await passReadinessAndPreamble(tester, qolDef);

        // Answer question 1, tap Next → should go to question 2 (not review)
        await tester.tap(find.text('Sometimes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        expect(find.text('Question 2 of 4'), findsOneWidget);
        expect(find.text('Review Your Answers'), findsNothing);
      },
    );
  });

  // Verifies: DIARY-GUI-questionnaire-session-expiry/G — a resumed
  //   (not-expired) session restores the participant to the question after
  //   the last one they answered, with the in-progress answers intact — NOT
  //   back to the Preamble / question 1.
  group('Resume from initialResponses (CUR-1292)', () {
    testWidgets(
      'seeds responses and advances cursor past last answered question',
      (tester) async {
        setUpTestScreen(tester);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Two of four answered — flow should land on question 3 with no
        // readiness gate or preamble in the way.
        await tester.pumpWidget(
          buildFlow(
            initialResponses: [qolResponse('qol_q1'), qolResponse('qol_q2')],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("I'm ready"), findsNothing);
        expect(find.text('Continue'), findsNothing);
        expect(find.text('Question 3 of 4'), findsOneWidget);
      },
    );

    testWidgets('jumps to review when every question already has a response', (
      tester,
    ) async {
      setUpTestScreen(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildFlow(
          initialResponses: [
            qolResponse('qol_q1'),
            qolResponse('qol_q2'),
            qolResponse('qol_q3'),
            qolResponse('qol_q4'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review Your Answers'), findsOneWidget);
      expect(find.textContaining('Question'), findsNothing);
    });
  });

  group('onCheckpoint after each answer (CUR-1292)', () {
    testWidgets('fires after every answer with the in-memory response state', (
      tester,
    ) async {
      setUpTestScreen(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final captured = <QuestionnaireSubmission>[];
      await tester.pumpWidget(buildFlow(onCheckpoint: captured.add));

      await passReadinessAndPreamble(tester, qolDef);

      // Answer question 1 — checkpoint should carry exactly one response.
      await tester.tap(find.text('Sometimes'));
      await tester.pumpAndSettle();
      expect(captured, hasLength(1));
      expect(captured.last.responses, hasLength(1));
      expect(captured.last.responses.first.questionId, 'qol_q1');
      expect(captured.last.responses.first.value, 2);
      expect(captured.last.instanceId, 'test-instance-id');
      expect(captured.last.questionnaireType, 'qol');

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Answer question 2 — checkpoint must reflect both responses.
      await tester.tap(find.text('Often'));
      await tester.pumpAndSettle();
      expect(captured, hasLength(2));
      expect(captured.last.responses, hasLength(2));
      expect(captured.last.responses.map((r) => r.questionId).toSet(), {
        'qol_q1',
        'qol_q2',
      });
      expect(
        captured.last.responses
            .firstWhere((r) => r.questionId == 'qol_q2')
            .value,
        3,
      );
    });
  });

  group('Home AppBar action (CUR-1292)', () {
    testWidgets('tapping Home from the question screen pops the route without '
        'submitting or deferring', (tester) async {
      setUpTestScreen(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var submitted = false;
      var completed = false;
      var deferred = false;
      await tester.pumpWidget(
        buildHomeLauncher(
          onSubmit: (_) async {
            submitted = true;
            return const SubmitResult(success: true);
          },
          onComplete: () => completed = true,
          onDefer: () => deferred = true,
        ),
      );

      await tester.tap(find.text('open-flow'));
      await tester.pumpAndSettle();

      await passReadinessAndPreamble(tester, qolDef);
      expect(find.text('Question 1 of 4'), findsOneWidget);

      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();

      // Back on the launcher screen — flow has been popped.
      expect(find.text('open-flow'), findsOneWidget);
      expect(find.text('Question 1 of 4'), findsNothing);
      expect(submitted, isFalse);
      expect(completed, isFalse);
      expect(deferred, isFalse);
    });
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

  group('In-flow session expiry (CUR-1543)', () {
    /// The QoL definition with a ZERO-minute session timeout, so the in-flow
    /// inactivity check trips immediately on the next lifecycle resume
    /// without manipulating the clock.
    QuestionnaireDefinition zeroTimeoutDef() => QuestionnaireDefinition(
      id: qolDef.id,
      name: qolDef.name,
      version: qolDef.version,
      recallPeriod: qolDef.recallPeriod,
      totalQuestions: qolDef.totalQuestions,
      preamble: qolDef.preamble,
      categories: qolDef.categories,
      sessionConfig: const SessionConfig(
        readinessCheck: true,
        readinessMessage: 'ready?',
        estimatedMinutes: '1',
        sessionTimeoutMinutes: 0,
        timeoutWarningMinutes: null,
      ),
    );

    /// Simulate the app returning to the foreground, which drives the
    /// in-flow session timeout check.
    Future<void> resumeApp(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    // Verifies: DIARY-GUI-questionnaire-session-expiry/B — expiry surfaces
    //   through the host callback (which renders the Session Expiry Dialog),
    //   NOT through the legacy SnackBar.
    // Verifies: DIARY-PRD-questionnaire-session-timeout/C — the in-memory
    //   answers are discarded on expiry.
    testWidgets(
      'expiry fires onSessionExpired (no SnackBar) and discards answers',
      (tester) async {
        setUpTestScreen(tester);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        var expiredCalls = 0;
        final def = zeroTimeoutDef();
        await tester.pumpWidget(
          buildFlow(
            definition: def,
            onSessionExpired: () async {
              expiredCalls++;
              return true; // Start Again
            },
          ),
        );

        await passReadinessAndPreamble(tester, def);
        await tester.tap(find.text('Sometimes'));
        await tester.pumpAndSettle();

        await resumeApp(tester);

        expect(expiredCalls, 1);
        // The legacy SnackBar path is gone (replaced by the host dialog).
        expect(
          find.text('Your session has expired. Please start again.'),
          findsNothing,
        );
        // Start Again → the flow has reset to the readiness gate ("Preamble"
        // surface) with the prior answer discarded.
        expect(find.text("I'm ready"), findsOneWidget);
      },
    );

    // Verifies: DIARY-GUI-questionnaire-session-expiry/D — Start Again
    //   presents the flow fresh from the beginning (readiness/Preamble).
    testWidgets('Start Again restarts fresh without exiting the flow', (
      tester,
    ) async {
      setUpTestScreen(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var completed = false;
      final def = zeroTimeoutDef();
      await tester.pumpWidget(
        buildFlow(
          definition: def,
          onComplete: () => completed = true,
          onSessionExpired: () async => true,
        ),
      );

      await passReadinessAndPreamble(tester, def);
      await resumeApp(tester);

      expect(completed, isFalse);
      expect(find.text("I'm ready"), findsOneWidget);

      // The reset flow is fully usable again: pass readiness + preamble and
      // land on a fresh question 1.
      await passReadinessAndPreamble(tester, def);
      expect(find.text('Question 1 of 4'), findsOneWidget);
    });

    // Verifies: DIARY-GUI-questionnaire-session-expiry/E — Not Now exits the
    //   flow (the host pops back to the home screen via onComplete).
    testWidgets('Not Now calls onComplete so the host returns home', (
      tester,
    ) async {
      setUpTestScreen(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var completed = false;
      final def = zeroTimeoutDef();
      await tester.pumpWidget(
        buildFlow(
          definition: def,
          onComplete: () => completed = true,
          onSessionExpired: () async => false,
        ),
      );

      await passReadinessAndPreamble(tester, def);
      await resumeApp(tester);

      expect(completed, isTrue);
    });

    // Verifies: DIARY-GUI-questionnaire-session-expiry/G — a resume within
    //   the (default 30-min) timeout does NOT expire the session: the
    //   participant stays on the question they were on with answers intact.
    testWidgets('a not-yet-expired session survives an app resume intact', (
      tester,
    ) async {
      setUpTestScreen(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      var expiredCalls = 0;
      await tester.pumpWidget(
        buildFlow(
          onSessionExpired: () async {
            expiredCalls++;
            return true;
          },
        ),
      );

      await passReadinessAndPreamble(tester, qolDef);
      await tester.tap(find.text('Sometimes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await resumeApp(tester);

      expect(expiredCalls, 0);
      expect(find.text('Question 2 of 4'), findsOneWidget);
    });
  });

  // Verifies: DIARY-DEV-inbound-event-on-receipt/C (mid-cycle interrupt)
  testWidgets('an active flow is interrupted when its recall signal fires', (
    tester,
  ) async {
    setUpTestScreen(tester);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final ctrl = StreamController<bool>();
    var onRecalledCalled = false;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: QuestionnaireFlowScreen(
          definition: qolDef,
          instanceId: 'QI-9',
          onSubmit: (_) async => const SubmitResult(success: true),
          onComplete: () => completed = true,
          recallSignal: ctrl.stream,
          onRecalled: () async {
            onRecalledCalled = true;
          },
        ),
      ),
    );

    // Advance past readiness into the flow.
    await tester.tap(find.text("I'm ready"));
    await tester.pumpAndSettle();

    // Fire the recall signal.
    ctrl.add(true);
    await tester.pumpAndSettle();

    // onRecalled should have been invoked AND the flow should have called onComplete.
    expect(onRecalledCalled, isTrue);
    expect(completed, isTrue);

    await ctrl.close();
  });
}
