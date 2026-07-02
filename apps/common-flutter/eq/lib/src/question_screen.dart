import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

import 'package:eq/src/widgets/question_progress_bar.dart';
import 'package:eq/src/widgets/response_scale_selector.dart';
import 'package:eq/src/widgets/rich_text_question.dart';

/// Displays a single question with its response scale.
///
/// Renders the category stem (when present) above the question text so
/// the actual prompt is visible on every page within a category. NOSE
/// HHT puts the prompt on the category — "How difficult is it to
/// perform the following tasks due to your nosebleeds?" — and per-item
/// labels in `question.text`; QoL puts the full question in
/// `question.text` with `category.stem == null`.
// Implements: DIARY-GUI-questionnaire-portal-sent-workflow/D+F+G+H+J
// Implements: DIARY-PRD-questionnaire-nose-hht/E
// Implements: DIARY-PRD-questionnaire-hht-qol/E
class QuestionScreen extends StatelessWidget {
  const QuestionScreen({
    required this.question,
    required this.category,
    required this.currentQuestionNumber,
    required this.totalQuestions,
    required this.selectedValue,
    required this.onAnswer,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  /// The question being displayed
  final QuestionDefinition question;

  /// The category this question belongs to
  final QuestionCategory category;

  /// Current question number (1-based)
  final int currentQuestionNumber;

  /// Total questions across all categories
  final int totalQuestions;

  /// Currently selected value (null if unanswered)
  final int? selectedValue;

  /// Called when the participant selects a response
  final ValueChanged<int> onAnswer;

  /// Called when the participant taps "Next"
  final VoidCallback onNext;

  /// Called when the participant taps "Back" (null on first question)
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        QuestionProgressBar(
          current: currentQuestionNumber,
          total: totalQuestions,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CUR-1292: render the category stem above the question on
                // every page within the category. For NOSE HHT the stem
                // ("How difficult is it to perform the following tasks due
                // to your nosebleeds?") is the actual prompt; the
                // per-question text is the activity label
                // ("Travel (e.g. by plane)"). Without the stem in view,
                // the participant sees no question — just an item with
                // response options.
                if (category.stem != null && category.stem!.isNotEmpty) ...[
                  Text(
                    category.stem!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (question.hasSegments)
                  RichTextQuestion(
                    segments: question.segments!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    question.text,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 24),
                ResponseScaleSelector(
                  options: category.responseScale,
                  selectedValue: selectedValue,
                  onSelected: onAnswer,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (onBack != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onBack,
                    child: const Text('Back'),
                  ),
                ),
              if (onBack != null) const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: selectedValue != null ? onNext : null,
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
