import 'package:flutter/material.dart';
import 'package:trial_data_types/trial_data_types.dart';

/// Review screen showing all answers before submission.
///
/// Displays a scrollable list of all Q&A pairs.
/// Items are tappable to jump back and edit.
///
/// CUR-1292: When [isReadOnly] is true the screen renders the same
/// list layout but suppresses the Submit button and the per-item edit
/// affordance. This is the surface a participant sees after the portal
/// coordinator has finalized the submission — answers are immutable;
/// the participant just verifies what was submitted.
// Implements: DIARY-GUI-questionnaire-portal-sent-workflow/K+L+M+N+S
// Implements: DIARY-PRD-questionnaire-nose-hht/E
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({
    required this.definition,
    required this.responses,
    required this.onEdit,
    required this.onSubmit,
    this.isSubmitting = false,
    this.isReadOnly = false,
    super.key,
  });

  /// The questionnaire definition
  final QuestionnaireDefinition definition;

  /// Map of questionId -> QuestionResponse
  final Map<String, QuestionResponse> responses;

  /// Called when participant taps a question to edit it. Ignored when
  /// [isReadOnly] is true.
  final ValueChanged<int> onEdit;

  /// Called when participant taps "Submit". Ignored when [isReadOnly] is
  /// true (the Submit button is not rendered).
  final VoidCallback onSubmit;

  /// Whether submission is in progress
  final bool isSubmitting;

  /// CUR-1292: render the screen in view-only mode. Removes the Submit
  /// button and disables per-question edit taps.
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allQuestions = definition.allQuestions;
    // CUR-1292: Group review items by category so the participant can see
    // each section's prompt (the `stem`) alongside the answers below
    // it. NOSE HHT puts the actual question on the category — without
    // the stem, items like "Travel (e.g. by plane) — No difficulty"
    // are review-screen labels with no question context.
    final sections = <Widget>[];
    var flatIndex = 0;
    for (final category in definition.categories) {
      if (category.stem != null && category.stem!.isNotEmpty) {
        sections.add(
          Padding(
            padding: EdgeInsets.only(top: sections.isEmpty ? 0 : 16, bottom: 8),
            child: Text(
              category.stem!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      for (final question in category.questions) {
        final reviewIndex = flatIndex;
        sections.add(
          _ReviewItem(
            question: question,
            response: responses[question.id],
            onTap: isReadOnly ? null : () => onEdit(reviewIndex),
          ),
        );
        flatIndex++;
      }
    }
    assert(flatIndex == allQuestions.length);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            isReadOnly ? 'Submitted Answers' : 'Review Your Answers',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: sections,
          ),
        ),
        if (!isReadOnly)
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

  /// `null` when the screen is in read-only mode.
  final VoidCallback? onTap;

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
              if (onTap != null)
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
