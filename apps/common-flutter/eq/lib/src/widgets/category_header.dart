// IMPLEMENTS REQUIREMENTS:
//   REQ-p01070: NOSE HHT Questionnaire UI

import 'package:flutter/material.dart';

/// Displays a category name and optional stem text.
///
/// Shown when the patient enters a new category section.
class CategoryHeader extends StatelessWidget {
  const CategoryHeader({required this.categoryName, this.stem, super.key});

  /// Category display name (e.g., "Physical", "Functional")
  final String categoryName;

  /// Stem text providing instructions for this category's questions
  final String? stem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            categoryName,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (stem != null) ...[
          const SizedBox(height: 12),
          Text(
            stem!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
