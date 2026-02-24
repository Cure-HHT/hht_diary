// IMPLEMENTS REQUIREMENTS:
//   REQ-p01070: NOSE HHT Questionnaire UI
//   REQ-p01071: QoL Questionnaire UI
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content

import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

import 'package:eq/src/widgets/category_header.dart';
import 'package:eq/src/widgets/question_progress_bar.dart';
import 'package:eq/src/widgets/response_scale_selector.dart';
import 'package:eq/src/widgets/rich_text_question.dart';

/// Displays a single question with its response scale.
///
/// Shows category header when entering a new category,
/// question text (with rich text for QoL), radio-style response options,
/// progress bar, and back/next navigation.
/// "Next" is disabled until the patient selects an answer.
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
    required this.showCategoryHeader,
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

  /// Called when the patient selects a response
  final ValueChanged<int> onAnswer;

  /// Called when the patient taps "Next"
  final VoidCallback onNext;

  /// Called when the patient taps "Back" (null on first question)
  final VoidCallback? onBack;

  /// Whether to show the category header (first question in category)
  final bool showCategoryHeader;

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
                if (showCategoryHeader) ...[
                  CategoryHeader(
                    categoryName: category.name,
                    stem: category.stem,
                  ),
                  const SizedBox(height: 24),
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
