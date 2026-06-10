import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent eventListItemComponent() {
  return WidgetbookComponent(
    name: 'EventListItem',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — Figma variants',
        builder: (_) => const _EventListItemGallery(),
      ),
    ],
  );
}

class _EventListItemGallery extends StatelessWidget {
  const _EventListItemGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('EventListItem — Gallery', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Single timestamped row used in event feeds and under the "Needs '
          'your attention" tile. Tone drives bg, optional border, and the '
          'secondary-text colour together; .empty() handles the "No records" '
          'state.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Figma — "No records" (empty state)',
          subtitle: 'node 452:9305 · muted text on subtle surface',
          child: const EventListItem.empty('No records'),
        ),
        _Section(
          title: 'Figma — Time + duration, critical tone',
          subtitle:
              'node 452:9323 · critical-tinted border, critical secondary',
          child: const EventListItem(
            leading: '01:10 PM',
            icon: Icons.water_drop_outlined,
            secondary: '6 min',
            tone: EventListItemTone.critical,
          ),
        ),
        _Section(
          title: 'Figma — Ongoing + "Incomplete" trailing pill, warning tone',
          subtitle: 'node 452:9329 · pending-amber bg + trailing badge',
          child: EventListItem(
            leading: '01:10 PM',
            icon: Icons.water_drop_outlined,
            secondary: 'Ongoing',
            tone: EventListItemTone.warning,
            trailing: const _IncompletePill(),
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Stacked rows (all three variants)',
          subtitle: 'Tappable — chevrons + ripples',
          child: Column(
            children: [
              const EventListItem.empty('No records'),
              const SizedBox(height: 8),
              EventListItem(
                leading: '01:10 PM',
                icon: Icons.water_drop_outlined,
                secondary: '6 min',
                tone: EventListItemTone.critical,
                onTap: () {},
              ),
              const SizedBox(height: 8),
              EventListItem(
                leading: '01:10 PM',
                icon: Icons.water_drop_outlined,
                secondary: 'Ongoing',
                tone: EventListItemTone.warning,
                trailing: const _IncompletePill(),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Trailing "Incomplete" pill from Figma node 452:9329 — small info
/// icon + label in Pending Dark. Kept local to the gallery because it's
/// a one-off composition; an app would build its own via AppBadge or a
/// bespoke widget if it wanted to reuse the recipe.
class _IncompletePill extends StatelessWidget {
  const _IncompletePill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info_outlined, size: 14, color: semantic.warning),
        const SizedBox(width: 4),
        Text(
          'Incomplete',
          style: TextStyle(
            color: semantic.warning,
            fontSize: 12.75,
            height: 17 / 12.75,
            fontWeight: FontWeight.w400,
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
      padding: const EdgeInsets.only(bottom: 24),
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
            constraints: const BoxConstraints(maxWidth: 398),
            child: child,
          ),
        ],
      ),
    );
  }
}
