import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

WidgetbookComponent appBannerComponent() {
  return WidgetbookComponent(
    name: 'AppBanner',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — all severities × shapes',
        builder: (_) => const _AppBannerGallery(),
      ),
    ],
  );
}

class _AppBannerGallery extends StatelessWidget {
  const _AppBannerGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('AppBanner — Gallery', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Each row covers a severity. Columns show message-only, with title, '
          'with title + trailing action, and a long-text wrap test.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        ..._sections.map((e) => _SeveritySection(title: e.$1, severity: e.$2)),
      ],
    );
  }
}

const List<(String, AppBannerSeverity)> _sections = [
  ('Success / Approved', AppBannerSeverity.success),
  ('Warning / Pending', AppBannerSeverity.warning),
  ('Error / Critical', AppBannerSeverity.error),
  ('Info (placeholder, no Figma hex yet)', AppBannerSeverity.info),
];

class _SeveritySection extends StatelessWidget {
  final String title;
  final AppBannerSeverity severity;
  const _SeveritySection({required this.title, required this.severity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          AppBanner(
            severity: severity,
            message: 'A short ${severity.name} message.',
          ),
          const SizedBox(height: 12),
          AppBanner(
            severity: severity,
            title: 'Banner title',
            message: 'A short ${severity.name} message with a title above.',
          ),
          const SizedBox(height: 12),
          AppBanner(
            severity: severity,
            title: 'Action required',
            message: 'Banner with a trailing action button.',
            trailing: AppButton(
              variant: AppButtonVariant.tertiary,
              size: AppButtonSize.small,
              label: 'Retry',
              onPressed: _noop,
            ),
          ),
          const SizedBox(height: 12),
          AppBanner(
            severity: severity,
            title: 'Long content wrap',
            message:
                'This is a long banner message intended to wrap across multiple lines so we can verify the banner grows in height appropriately and keeps the icon top-aligned with the first line of the title.',
          ),
        ],
      ),
    );
  }
}
