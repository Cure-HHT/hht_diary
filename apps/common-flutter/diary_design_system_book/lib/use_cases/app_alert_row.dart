import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent appAlertRowComponent() {
  return WidgetbookComponent(
    name: 'AppAlertRow',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — tones + named factories',
        builder: (_) => const _AlertRowGallery(),
      ),
    ],
  );
}

class _AlertRowGallery extends StatelessWidget {
  const _AlertRowGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('AppAlertRow — Gallery', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Tone-tinted clickable row used inside AppExpansionTile and any '
          'inline action prompt. The two named factories match the Figma '
          '"Notifications / Alerts" rows exactly; the generic constructor '
          'covers the other tones.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Named factories (Figma-exact)',
          subtitle:
              'AppAlertRow.incompleteRecord(count: …) · '
              'AppAlertRow.availableQuestionnaire(label: …)',
          child: Column(
            children: [
              AppAlertRow.incompleteRecord(count: 1, onTap: () {}),
              const SizedBox(height: 12),
              AppAlertRow.incompleteRecord(count: 4, onTap: () {}),
              const SizedBox(height: 12),
              AppAlertRow.availableQuestionnaire(
                label: 'Complete Quality of Life Survey',
                onTap: () {},
              ),
            ],
          ),
        ),
        _Section(
          title: 'All tones (generic constructor)',
          subtitle: 'primary · warning · error · success',
          child: Column(
            children: [
              AppAlertRow(
                tone: AppAlertRowTone.primary,
                icon: Icons.assignment_turned_in_outlined,
                label: 'Routine prompt (primary)',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              AppAlertRow(
                tone: AppAlertRowTone.warning,
                icon: Icons.info_outlined,
                label: 'Needs attention (warning)',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              AppAlertRow(
                tone: AppAlertRowTone.error,
                icon: Icons.error_outline,
                label: 'Blocking error (error)',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              AppAlertRow(
                tone: AppAlertRowTone.success,
                icon: Icons.check_circle_outline,
                label: 'Acknowledged (success)',
                onTap: () {},
              ),
            ],
          ),
        ),
        _Section(
          title: 'Non-tappable (no chevron)',
          subtitle: 'omit onTap when the row is informational only',
          child: const AppAlertRow(
            tone: AppAlertRowTone.warning,
            icon: Icons.info_outlined,
            label: 'Read-only status — no chevron',
          ),
        ),
        _Section(
          title: 'Long label — ellipsis behaviour',
          child: AppAlertRow(
            tone: AppAlertRowTone.primary,
            icon: Icons.assignment_turned_in_outlined,
            label:
                'A questionnaire title that is much longer than the row width '
                'and should ellipsise on the right side.',
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Section({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 427),
            child: child,
          ),
        ],
      ),
    );
  }
}
