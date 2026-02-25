// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content
//   REQ-p01070: NOSE HHT Questionnaire UI
//   REQ-p01071: QoL Questionnaire UI
//   REQ-p01073: Session Management
//   REQ-d00113: Deleted Questionnaire Submission Handling

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
/// Per REQ-p01073: tracks session start time and handles timeout.
class QuestionnaireFlowScreen extends StatefulWidget {
  const QuestionnaireFlowScreen({
    required this.definition,
    required this.instanceId,
    required this.onSubmit,
    required this.onComplete,
    this.onDefer,
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

  /// Called when the patient taps "Not now" at readiness gate
  final VoidCallback? onDefer;

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
  DateTime? _sessionStartTime;

  /// Responses keyed by question ID
  final Map<String, QuestionResponse> _responses = {};

  late final List<QuestionDefinition> _allQuestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _allQuestions = widget.definition.allQuestions;
    // Skip readiness if no session config or readiness check disabled
    if (widget.definition.sessionConfig?.readinessCheck != true) {
      _state = widget.definition.preamble.isNotEmpty
          ? _FlowState.preamble
          : _FlowState.questions;
      _sessionStartTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _sessionStartTime != null) {
      _checkSessionTimeout();
    }
  }

  void _checkSessionTimeout() {
    final timeout = widget.definition.sessionConfig?.sessionTimeoutMinutes;
    if (timeout == null || _sessionStartTime == null) return;

    final elapsed = DateTime.now().difference(_sessionStartTime!);
    if (elapsed.inMinutes >= timeout) {
      // Session expired — discard responses and show message
      setState(() {
        _responses.clear();
        _questionIndex = 0;
        _preambleIndex = 0;
        _state = _FlowState.readiness;
        _sessionStartTime = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your session has expired. Please start again.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

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

  void _handleAnswer(int value) {
    final question = _allQuestions[_questionIndex];
    final category = widget.definition.categoryForQuestion(question.id)!;
    final option = category.responseScale.firstWhere((o) => o.value == value);
    setState(() {
      _responses[question.id] = QuestionResponse(
        questionId: question.id,
        value: value,
        displayLabel: option.label,
        normalizedLabel: value.toString(),
      );
    });
  }

  void _handleNext() {
    setState(() {
      if (_questionIndex < _allQuestions.length - 1) {
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

  void _handleEditQuestion(int index) {
    setState(() {
      _questionIndex = index;
      _state = _FlowState.questions;
    });
  }

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
      // REQ-d00113: Questionnaire was deleted while patient was completing it
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

  /// Whether to show the category header for the current question
  bool get _showCategoryHeader {
    if (_questionIndex == 0) return true;
    final currentQ = _allQuestions[_questionIndex];
    final prevQ = _allQuestions[_questionIndex - 1];
    final currentCat = widget.definition.categoryForQuestion(currentQ.id);
    final prevCat = widget.definition.categoryForQuestion(prevQ.id);
    return currentCat?.id != prevCat?.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _state != _FlowState.confirmation
          ? AppBar(
              title: Text(widget.definition.name),
              automaticallyImplyLeading: _state == _FlowState.readiness,
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
      showCategoryHeader: _showCategoryHeader,
    );
  }
}
