// IMPLEMENTS REQUIREMENTS:
//   REQ-p01067: NOSE HHT Questionnaire Content
//   REQ-p01068: HHT Quality of Life Questionnaire Content

import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Review screen showing all answers before submission.
///
/// Displays a scrollable list of all Q&A pairs.
/// Items are tappable to jump back and edit.
/// Per REQ-p01067-E / REQ-p01068-E.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({
    required this.definition,
    required this.responses,
    required this.onEdit,
    required this.onSubmit,
    this.isSubmitting = false,
    super.key,
  });

  /// The questionnaire definition
  final QuestionnaireDefinition definition;

  /// Map of questionId -> QuestionResponse
  final Map<String, QuestionResponse> responses;

  /// Called when patient taps a question to edit it
  final ValueChanged<int> onEdit;

  /// Called when patient taps "Submit"
  final VoidCallback onSubmit;

  /// Whether submission is in progress
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allQuestions = definition.allQuestions;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Review Your Answers',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allQuestions.length,
            itemBuilder: (context, index) {
              final question = allQuestions[index];
              final response = responses[question.id];
              return _ReviewItem(
                question: question,
                response: response,
                onTap: () => onEdit(index),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSubmitting ? null : onSubmit,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(isSubmitting ? 'Submitting...' : 'Submit'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.question,
    required this.response,
    required this.onTap,
  });

  final QuestionDefinition question;
  final QuestionResponse? response;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${question.number}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question.text, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      response?.displayLabel ?? 'Not answered',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: response != null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
