import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent appExpansionTileComponent() {
  return WidgetbookComponent(
    name: 'AppExpansionTile',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — "Needs your attention"',
        builder: (_) => const _ExpansionTileGallery(),
      ),
    ],
  );
}

class _ExpansionTileGallery extends StatelessWidget {
  const _ExpansionTileGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'AppExpansionTile — Gallery',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'White disclosure tile with a Primary-Light border when there are '
          'items (else outline grey). Pair with AppAlertRow factories for '
          'the action rows — they are the Figma-exact "incomplete record" '
          'and "available questionnaire" variants.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Figma — "Needs your attention" (expanded, 2 items)',
          child: AppExpansionTile(
            title: 'Needs your attention',
            count: 2,
            initiallyExpanded: true,
            children: [
              AppAlertRow.incompleteRecord(count: 1, onTap: () {}),
              AppAlertRow.availableQuestionnaire(
                label: 'Complete Quality of Life Survey',
                onTap: () {},
              ),
            ],
          ),
        ),
        _Section(
          title: 'Collapsed — single item',
          child: AppExpansionTile(
            title: 'Needs your attention',
            count: 1,
            children: [AppAlertRow.incompleteRecord(count: 1, onTap: () {})],
          ),
        ),
        _Section(
          title: 'Plural incomplete records',
          child: AppExpansionTile(
            title: 'Needs your attention',
            count: 3,
            initiallyExpanded: true,
            children: [
              AppAlertRow.incompleteRecord(count: 3, onTap: () {}),
              AppAlertRow.availableQuestionnaire(
                label: 'Daily symptom check-in',
                onTap: () {},
              ),
            ],
          ),
        ),
        _Section(
          title: 'No count badge — empty (grey outline border)',
          child: const AppExpansionTile(
            title: 'Recent notifications',
            children: [],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: child,
          ),
        ],
      ),
    );
  }
}
