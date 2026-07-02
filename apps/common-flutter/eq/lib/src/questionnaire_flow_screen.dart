import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

import 'package:eq/src/confirmation_screen.dart';
import 'package:eq/src/preamble_screen.dart';
import 'package:eq/src/question_screen.dart';
import 'package:eq/src/readiness_screen.dart';
import 'package:eq/src/review_screen.dart';

/// Flow states for the questionnaire
enum _FlowState {
  readiness,
  preamble,
  questions,
  review,
  submitting,
  confirmation,
}

/// Result type for onSubmit callback
class SubmitResult {
  const SubmitResult({
    required this.success,
    this.error,
    this.isDeleted = false,
  });

  final bool success;
  final String? error;
  final bool isDeleted;
}

/// Main orchestrator widget for the full questionnaire flow.
///
/// Manages the state machine:
/// readiness → preamble → questions → review → submitting → confirmation
///
/// Tracks session start time and handles timeout.
// Implements: DIARY-GUI-questionnaire-portal-sent-workflow/I+K+S
class QuestionnaireFlowScreen extends StatefulWidget {
  const QuestionnaireFlowScreen({
    required this.definition,
    required this.instanceId,
    required this.onSubmit,
    required this.onComplete,
    this.onDefer,
    this.onCheckpoint,
    this.initialResponses,
    this.isReadOnly = false,
    this.recallSignal,
    this.onRecalled,
    this.onSessionExpired,
    super.key,
  });

  /// The questionnaire definition
  final QuestionnaireDefinition definition;

  /// The questionnaire instance ID
  final String instanceId;

  /// Called to submit responses. Returns a SubmitResult.
  final Future<SubmitResult> Function(QuestionnaireSubmission submission)
  onSubmit;

  /// Called when the flow is fully complete (after confirmation "Done")
  final VoidCallback onComplete;

  /// Called when the participant taps "Not now" at readiness gate
  final VoidCallback? onDefer;

  /// Fires after every answer with a partial [QuestionnaireSubmission]
  /// reflecting the current in-memory response state. Producers persist
  /// this as a `checkpoint` event so the flow can resume after the app
  /// is killed mid-questionnaire.
  final void Function(QuestionnaireSubmission partial)? onCheckpoint;

  /// Prior responses to seed the flow on resume. When non-empty the flow
  /// skips readiness + preamble, advances the cursor past the last
  /// answered question, and lands directly on the review screen if every
  /// question already has a response.
  final List<QuestionResponse>? initialResponses;

  /// CUR-1292: when true the flow opens directly on the review screen
  /// in view-only mode — no Submit button, no per-item edit affordances.
  /// Used to surface the answers of a portal-finalized submission so
  /// the participant can verify what was sent.
  ///
  /// CUR-1523: read-only is enforced regardless of whether
  /// [initialResponses] is supplied. A finalized questionnaire with no
  /// device-local copy still opens the immutable "Submitted Answers" surface
  /// (questions shown as "Not answered") rather than the editable flow, so a
  /// participant can never re-fill/re-submit a finalized questionnaire.
  final bool isReadOnly;

  /// CUR-1522: Optional stream that emits `true` when the portal has recalled
  /// THIS open instance. The host (home screen) owns the view subscription and
  /// passes a pre-filtered stream so the `eq` package stays dependency-free.
  ///
  /// On a `true` event the flow invokes [onRecalled] (if supplied) and then
  /// calls [onComplete] to exit. No dialog is shown inside the `eq` package —
  /// the host is responsible for any user-facing acknowledgement.
  // Implements: DIARY-DEV-inbound-event-on-receipt/C
  final Stream<bool>? recallSignal;

  /// CUR-1522: Async callback invoked when [recallSignal] fires `true`. The
  /// host shows the recall acknowledgement dialog (and persists the ack event)
  /// before this future resolves. When null the flow exits silently.
  // Implements: DIARY-DEV-inbound-event-on-receipt/C
  final Future<void> Function()? onRecalled;

  /// CUR-1543: Async callback invoked when the in-flow inactivity timer
  /// crosses the configured session timeout while the flow is open. The HOST
  /// owns the persisted draft and all user-facing UI: its handler discards the
  /// `checkpoint` draft and shows the Session Expiry Dialog, resolving `true`
  /// for "Start Again" and `false` for "Not Now". The flow has already reset
  /// itself to the beginning (answers discarded) before the handler is
  /// awaited, so "Start Again" simply reveals the fresh flow; on `false` the
  /// flow calls [onComplete] so the host navigates back to the home screen.
  /// When null the flow resets silently — the `eq` package renders no dialog
  /// of its own (it is store- and l10n-free).
  // Implements: DIARY-GUI-questionnaire-session-expiry/B+D+E
  final Future<bool> Function()? onSessionExpired;

  @override
  State<QuestionnaireFlowScreen> createState() =>
      _QuestionnaireFlowScreenState();
}

class _QuestionnaireFlowScreenState extends State<QuestionnaireFlowScreen>
    with WidgetsBindingObserver {
  _FlowState _state = _FlowState.readiness;
  int _preambleIndex = 0;
  int _questionIndex = 0;
  bool _isSubmitting = false;
  bool _editMode = false;
  DateTime? _sessionStartTime;

  /// Responses keyed by question ID
  final Map<String, QuestionResponse> _responses = {};

  late final List<QuestionDefinition> _allQuestions;

  // CUR-1522: subscription to the host-supplied per-instance recall signal.
  StreamSubscription<bool>? _recallSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _allQuestions = widget.definition.allQuestions;

    // CUR-1523: a read-only flow ALWAYS opens on the (view-only) review
    // screen — even with no seed. A portal-finalized questionnaire that has no
    // device-local copy (e.g. after a diary-reset/reinstall + re-link) must
    // render its immutable "Submitted Answers" surface, never the editable
    // flow. Honoring isReadOnly only when a seed is present would let a
    // participant re-fill and re-submit a finalized questionnaire.
    if (widget.isReadOnly) {
      final seed = widget.initialResponses;
      if (seed != null) {
        final knownIds = {for (final q in _allQuestions) q.id};
        for (final response in seed) {
          if (knownIds.contains(response.questionId)) {
            _responses[response.questionId] = response;
          }
        }
      }
      _state = _FlowState.review;
      _sessionStartTime = DateTime.now();
      return;
    }

    final seed = widget.initialResponses;
    if (seed != null && seed.isNotEmpty) {
      // Resume path: ignore readiness/preamble — the participant already
      // committed to taking this questionnaire on a prior session, and
      // every recorded response is proof of that consent. The cursor lands on
      // the question AFTER the last answered one (their answers intact), so a
      // not-yet-expired session restores where the participant left off.
      // Implements: DIARY-GUI-questionnaire-session-expiry/G
      // Implements: DIARY-PRD-questionnaire-session-timeout/G+H
      final knownIds = {for (final q in _allQuestions) q.id};
      for (final response in seed) {
        if (knownIds.contains(response.questionId)) {
          _responses[response.questionId] = response;
        }
      }
      final allAnswered = _allQuestions.every(
        (q) => _responses.containsKey(q.id),
      );
      // (Read-only is handled above and returns early; here the flow is
      // always editable.) Land on review when every question is answered.
      if (allAnswered) {
        _state = _FlowState.review;
      } else {
        var lastAnsweredIndex = -1;
        for (var i = 0; i < _allQuestions.length; i++) {
          if (_responses.containsKey(_allQuestions[i].id)) {
            lastAnsweredIndex = i;
          }
        }
        _questionIndex = lastAnsweredIndex + 1;
        _state = _FlowState.questions;
      }
      _sessionStartTime = DateTime.now();
      return;
    }

    // Skip readiness if no session config or readiness check disabled
    if (widget.definition.sessionConfig?.readinessCheck != true) {
      _state = widget.definition.preamble.isNotEmpty
          ? _FlowState.preamble
          : _FlowState.questions;
      _sessionStartTime = DateTime.now();
    }

    // CUR-1522: subscribe to the host-supplied per-instance recall signal.
    // On a true event: await the host's onRecalled callback (which shows the
    // dialog + persists the ack), then call onComplete to exit the flow.
    // The eq package shows no dialog — the host owns all user-facing ack UI.
    // Note: a recall deliberately races and WINS over an in-flight submit;
    // if the submit completes concurrently its DispatchResult is discarded —
    // this is intentional (the portal-side recall supersedes any local answer).
    // Implements: DIARY-DEV-inbound-event-on-receipt/C
    _recallSub = widget.recallSignal?.listen((recalled) async {
      if (!recalled || !mounted) return;
      await widget.onRecalled?.call();
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    unawaited(_recallSub?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _sessionStartTime != null) {
      unawaited(_checkSessionTimeout());
    }
  }

  /// In-flow session expiry: when the inactivity timer crosses the configured
  /// timeout, the in-memory answers are discarded and the flow resets to the
  /// beginning; the HOST is notified via [QuestionnaireFlowScreen.onSessionExpired]
  /// so it can discard the persisted `checkpoint` draft and present the
  /// Session Expiry Dialog (CUR-1543 — replaces the former SnackBar).
  // Implements: DIARY-PRD-questionnaire-session-timeout/A+B+C+D
  // Implements: DIARY-GUI-questionnaire-session-expiry/B+D+E
  Future<void> _checkSessionTimeout() async {
    // A read-only view has no session to expire; a submitting/confirmed flow
    // already ended its session normally.
    if (widget.isReadOnly ||
        _state == _FlowState.submitting ||
        _state == _FlowState.confirmation) {
      return;
    }
    final timeout = widget.definition.sessionConfig?.sessionTimeoutMinutes;
    if (timeout == null || _sessionStartTime == null) return;

    final elapsed = DateTime.now().difference(_sessionStartTime!);
    if (elapsed.inMinutes < timeout) return;

    // Session expired — discard the in-memory answers and reset to the start
    // (timeout/C+D) BEFORE handing off to the host, so "Start Again" simply
    // reveals the fresh flow behind the dismissed dialog.
    setState(_resetToStart);
    final handler = widget.onSessionExpired;
    if (handler == null) return;
    final startAgain = await handler();
    if (!mounted) return;
    if (!startAgain) {
      // Not Now → the host navigates back to the home screen (expiry/E).
      widget.onComplete();
    }
  }

  /// Resets the flow to its entry state (mirrors [initState]'s fresh-flow
  /// branch): readiness gate when configured, else Preamble / first question.
  // Implements: DIARY-PRD-questionnaire-session-timeout/D
  // Implements: DIARY-GUI-questionnaire-session-expiry/D
  void _resetToStart() {
    _responses.clear();
    _questionIndex = 0;
    _preambleIndex = 0;
    _editMode = false;
    if (widget.definition.sessionConfig?.readinessCheck == true) {
      _state = _FlowState.readiness;
      _sessionStartTime = null;
    } else {
      _state = widget.definition.preamble.isNotEmpty
          ? _FlowState.preamble
          : _FlowState.questions;
      _sessionStartTime = DateTime.now();
    }
  }

  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/C
  void _handleReady() {
    setState(() {
      _sessionStartTime = DateTime.now();
      if (widget.definition.preamble.isNotEmpty) {
        _state = _FlowState.preamble;
      } else {
        _state = _FlowState.questions;
      }
    });
  }

  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/B
  void _handleDefer() {
    if (widget.onDefer != null) {
      widget.onDefer!();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handlePreambleContinue() {
    setState(() {
      if (_preambleIndex < widget.definition.preamble.length - 1) {
        _preambleIndex++;
      } else {
        _state = _FlowState.questions;
      }
    });
  }

  // Implements: DIARY-PRD-questionnaire-session-timeout/A — the inactivity
  //   timer is anchored at the participant's MOST RECENT interaction, so each
  //   answer re-arms the in-flow timeout (consistent with the host's
  //   checkpoint-anchored draft expiry, which re-anchors per checkpoint).
  void _handleAnswer(int value) {
    final question = _allQuestions[_questionIndex];
    final category = widget.definition.categoryForQuestion(question.id)!;
    final option = category.responseScale.firstWhere((o) => o.value == value);
    setState(() {
      _sessionStartTime = DateTime.now();
      _responses[question.id] = QuestionResponse(
        questionId: question.id,
        value: value,
        displayLabel: option.label,
        normalizedLabel: value.toString(),
      );
    });
    widget.onCheckpoint?.call(_buildPartialSubmission());
  }

  QuestionnaireSubmission _buildPartialSubmission() {
    return QuestionnaireSubmission(
      instanceId: widget.instanceId,
      questionnaireType: widget.definition.id,
      version: widget.definition.version,
      responses: _responses.values.toList(),
      completedAt: DateTime.now(),
    );
  }

  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/I+P
  void _handleNext() {
    setState(() {
      // CUR-1119: If editing from review screen, return directly to review
      if (_editMode) {
        _editMode = false;
        _state = _FlowState.review;
      } else if (_questionIndex < _allQuestions.length - 1) {
        _questionIndex++;
      } else {
        _state = _FlowState.review;
      }
    });
  }

  void _handleBack() {
    setState(() {
      if (_questionIndex > 0) {
        _questionIndex--;
      }
    });
  }

  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/M
  void _handleEditQuestion(int index) {
    setState(() {
      _questionIndex = index;
      _state = _FlowState.questions;
      _editMode = true;
    });
  }

  // Implements: DIARY-GUI-questionnaire-portal-sent-workflow/N+Q
  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _state = _FlowState.submitting;
    });

    final submission = QuestionnaireSubmission(
      instanceId: widget.instanceId,
      questionnaireType: widget.definition.id,
      version: widget.definition.version,
      responses: _responses.values.toList(),
      completedAt: DateTime.now(),
    );

    final result = await widget.onSubmit(submission);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isSubmitting = false;
        _state = _FlowState.confirmation;
      });
    } else if (result.isDeleted) {
      // Questionnaire was withdrawn while participant was completing it
      // Implements: DIARY-BASE-questionnaire-coordinator-workflow/D
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This questionnaire has been withdrawn by your investigator.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      widget.onComplete();
    } else {
      setState(() {
        _isSubmitting = false;
        _state = _FlowState.review;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Submission failed. Please try again.'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _state != _FlowState.confirmation
          ? AppBar(
              title: Text(widget.definition.name),
              automaticallyImplyLeading: _state == _FlowState.readiness,
              actions: _state == _FlowState.submitting
                  ? null
                  : [
                      IconButton(
                        icon: const Icon(Icons.home),
                        tooltip: 'Home',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
            )
          : null,
      body: SafeArea(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    return switch (_state) {
      _FlowState.readiness => ReadinessScreen(
        definition: widget.definition,
        onReady: _handleReady,
        onDefer: _handleDefer,
      ),
      _FlowState.preamble => PreambleScreen(
        preamble: widget.definition.preamble[_preambleIndex],
        currentIndex: _preambleIndex,
        totalCount: widget.definition.preamble.length,
        onContinue: _handlePreambleContinue,
      ),
      _FlowState.questions => _buildQuestionScreen(),
      _FlowState.review || _FlowState.submitting => ReviewScreen(
        definition: widget.definition,
        responses: _responses,
        onEdit: _handleEditQuestion,
        onSubmit: _handleSubmit,
        isSubmitting: _isSubmitting,
        isReadOnly: widget.isReadOnly,
      ),
      _FlowState.confirmation => ConfirmationScreen(
        questionnaireName: widget.definition.name,
        onDone: widget.onComplete,
      ),
    };
  }

  Widget _buildQuestionScreen() {
    final question = _allQuestions[_questionIndex];
    final category = widget.definition.categoryForQuestion(question.id)!;
    return QuestionScreen(
      question: question,
      category: category,
      currentQuestionNumber: _questionIndex + 1,
      totalQuestions: _allQuestions.length,
      selectedValue: _responses[question.id]?.value,
      onAnswer: _handleAnswer,
      onNext: _handleNext,
      onBack: _questionIndex > 0 ? _handleBack : null,
    );
  }
}
