// Implements: REQ-p01067, REQ-p01068 (survey questionnaires);
//   REQ-d00004-E+F+G (local-first writes); REQ-p00006-A+B (offline-first).
//   Each answered question → checkpoint with cumulative answers; final
//   submit → finalized. Resume reads initialAnswers from view. cycle is
//   carried verbatim from initialAnswers into every recorded event.

import 'package:clinical_diary/entry_widgets/entry_widget_context.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Inline data types — mirrors the shape of QuestionnaireDefinition without
// importing the service layer. Parsed once from ctx.widgetConfig in initState.
// ---------------------------------------------------------------------------

class _ScaleOption {
  const _ScaleOption({required this.value, required this.label});
  final int value;
  final String label;
}

class _QuestionDef {
  const _QuestionDef({
    required this.id,
    required this.number,
    required this.text,
  });
  final String id;
  final int number;
  final String text;
}

class _CategoryDef {
  const _CategoryDef({
    required this.id,
    required this.name,
    required this.stem,
    required this.scale,
    required this.questions,
  });
  final String id;
  final String name;
  final String? stem;
  final List<_ScaleOption> scale;
  final List<_QuestionDef> questions;
}

class _SurveyDef {
  const _SurveyDef({required this.name, required this.categories});
  final String name;
  final List<_CategoryDef> categories;

  List<_QuestionDef> get allQuestions =>
      categories.expand((c) => c.questions).toList();

  _CategoryDef? categoryFor(String questionId) {
    for (final cat in categories) {
      if (cat.questions.any((q) => q.id == questionId)) return cat;
    }
    return null;
  }
}

/// Parse a [_SurveyDef] from the raw widgetConfig map.
///
/// The config shape mirrors QuestionnaireDefinition.fromJson exactly so that
/// this widget can be driven by the same JSON loaded by Task 4's entry-type
/// loader.
_SurveyDef _parseSurveyDef(Map<String, Object?> config) {
  final name = config['name'] as String? ?? '';
  final categoriesRaw = config['categories'] as List<dynamic>? ?? [];

  final categories = categoriesRaw.map((cRaw) {
    final c = cRaw as Map<String, Object?>;
    final id = c['id'] as String;
    final catName = c['name'] as String;
    final stem = c['stem'] as String?;

    final scaleRaw = c['responseScale'] as List<dynamic>? ?? [];
    final scale = scaleRaw.map((sRaw) {
      final s = sRaw as Map<String, Object?>;
      return _ScaleOption(
        value: s['value'] as int,
        label: s['label'] as String,
      );
    }).toList();

    final questionsRaw = c['questions'] as List<dynamic>? ?? [];
    final questions = questionsRaw.map((qRaw) {
      final q = qRaw as Map<String, Object?>;
      return _QuestionDef(
        id: q['id'] as String,
        number: q['number'] as int,
        text: q['text'] as String,
      );
    }).toList();

    return _CategoryDef(
      id: id,
      name: catName,
      stem: stem,
      scale: scale,
      questions: questions,
    );
  }).toList();

  return _SurveyDef(name: name, categories: categories);
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Renders a questionnaire survey driven entirely by [EntryWidgetContext].
///
/// ## Cycle stamping (REQ-d00113)
/// The `cycle` key in [EntryWidgetContext.initialAnswers] is treated as
/// immutable seed metadata:
/// - It is never displayed as a UI question.
/// - Every `record(...)` call (checkpoints AND finalized) carries `cycle`
///   in `answers`.
///
/// ## Per-question checkpointing
/// On each answer selection the widget records a `checkpoint` event with the
/// CUMULATIVE answer map so far (all prior answers + the new one). This lets
/// the server reconstruct exact in-progress state without re-rendering logic.
///
/// ## Resume
/// When [EntryWidgetContext.initialAnswers] is non-null it is treated as the
/// latest checkpoint restore map. Questions with existing values are
/// pre-filled and no checkpoint is emitted on mount.
///
/// ## Read-only states
/// - [EntryWidgetContext.isFinalized] → render all responses as read-only,
///   hide the Submit button, show a completion banner.
/// - [EntryWidgetContext.isWithdrawn] → additionally show a "withdrawn" banner.
// Implements: REQ-p01067-A+B — survey UI driven by widgetConfig questionnaire.
// Implements: REQ-p01068-A+B — same rendering path handles QoL questionnaire.
// Implements: REQ-d00004-E — checkpoint/finalized written through EntryRecorder.
// Implements: REQ-d00004-F — single write path via ctx.recorder.
// Implements: REQ-d00004-G — resume from initialAnswers without re-emitting.
// Implements: REQ-p00006-A+B — offline-first; no network calls here.
class SurveyRendererWidget extends StatefulWidget {
  const SurveyRendererWidget(this.ctx, {super.key});

  final EntryWidgetContext ctx;

  @override
  State<SurveyRendererWidget> createState() => _SurveyRendererWidgetState();
}

class _SurveyRendererWidgetState extends State<SurveyRendererWidget> {
  late final _SurveyDef _def;

  /// Cumulative answer map. Includes `cycle` when seeded.
  /// Keys are question IDs; values are the integer scale option values.
  late final Map<String, Object?> _answers;

  /// True once a `finalized` event has been emitted in this session.
  bool _locallyFinalized = false;

  bool _isSaving = false;

  // ---------------------------------------------------------------------------
  // Derived state
  // ---------------------------------------------------------------------------

  bool get _isReadOnly =>
      widget.ctx.isFinalized || widget.ctx.isWithdrawn || _locallyFinalized;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _def = _parseSurveyDef(widget.ctx.widgetConfig);

    // Seed _answers from initialAnswers (checkpoint restore).
    // `cycle` and all prior question answers are included verbatim.
    // No checkpoint is emitted on mount — only new selections fire events.
    final ia = widget.ctx.initialAnswers;
    if (ia != null) {
      _answers = Map<String, Object?>.of(ia);
    } else {
      _answers = {};
    }
  }

  // ---------------------------------------------------------------------------
  // Answer selection handler
  // ---------------------------------------------------------------------------

  // Implements: REQ-d00004-E — per-question checkpoint written immediately.
  Future<void> _onAnswerSelected(String questionId, int value) async {
    if (_isReadOnly || _isSaving) return;

    setState(() {
      _answers[questionId] = value;
    });

    // Record checkpoint with CUMULATIVE answers
    await widget.ctx.recorder(
      entryType: widget.ctx.entryType,
      aggregateId: widget.ctx.aggregateId,
      eventType: 'checkpoint',
      answers: Map<String, Object?>.of(_answers),
      checkpointReason: 'question_answered',
    );
  }

  // ---------------------------------------------------------------------------
  // Submit handler
  // ---------------------------------------------------------------------------

  // Implements: REQ-d00004-E+F — finalized event on submit.
  Future<void> _onSubmit() async {
    if (_isReadOnly || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.ctx.recorder(
        entryType: widget.ctx.entryType,
        aggregateId: widget.ctx.aggregateId,
        eventType: 'finalized',
        answers: Map<String, Object?>.of(_answers),
      );
      if (mounted) setState(() => _locallyFinalized = true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Withdrawn banner (isWithdrawn takes priority over isFinalized)
          if (widget.ctx.isWithdrawn)
            _WithdrawnBanner()
          else if (widget.ctx.isFinalized || _locallyFinalized)
            _ReadOnlyBanner(),

          // Categories and questions
          for (final category in _def.categories) ...[
            _CategoryHeader(category: category),
            for (final question in category.questions)
              _QuestionRow(
                question: question,
                category: category,
                selectedValue: _answers[question.id] as int?,
                readOnly: _isReadOnly,
                onSelected: (v) => _onAnswerSelected(question.id, v),
              ),
            const SizedBox(height: 16),
          ],

          // Submit button (hidden when read-only)
          if (!_isReadOnly) ...[
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('survey_submit_button'),
              onPressed: _isSaving ? null : _onSubmit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _WithdrawnBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('survey_withdrawn_banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.block,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This questionnaire has been withdrawn by your investigator.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('survey_readonly_banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Questionnaire completed. Your responses are read-only.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});
  final _CategoryDef category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (category.stem != null) ...[
            const SizedBox(height: 4),
            Text(
              category.stem!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const Divider(),
        ],
      ),
    );
  }
}

/// Renders a single question with its category's response scale.
///
/// Each option is a [ChoiceChip] keyed as `${questionId}_option_${value}`.
/// When [readOnly] is true, `onSelected` is null on every chip (disabled).
class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.question,
    required this.category,
    required this.selectedValue,
    required this.readOnly,
    required this.onSelected,
  });

  final _QuestionDef question;
  final _CategoryDef category;
  final int? selectedValue;
  final bool readOnly;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text
          Text(
            '${question.number}. ${question.text}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          // Response scale chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in category.scale)
                ChoiceChip(
                  key: Key('${question.id}_option_${option.value}'),
                  label: Text(option.label),
                  selected: selectedValue == option.value,
                  // Passing null disables the chip (read-only)
                  onSelected: readOnly ? null : (_) => onSelected(option.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
