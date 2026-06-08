import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookFolder feedbackLayoutFolder() {
  return WidgetbookFolder(
    name: 'Feedback + Layout',
    children: [
      WidgetbookComponent(
        name: 'StatusBadge',
        useCases: [
          WidgetbookUseCase(
            name: 'Gallery — all kinds',
            builder: (_) => const _StatusBadgeGallery(),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'AppBadge',
        useCases: [
          WidgetbookUseCase(
            name: 'Gallery — outlined × filled × tones',
            builder: (_) => const _AppBadgeGallery(),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'AppCard',
        useCases: [
          WidgetbookUseCase(
            name: 'Gallery — default + with title',
            builder: (_) => const _AppCardGallery(),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'AppSectionHeader',
        useCases: [
          WidgetbookUseCase(
            name: 'Gallery — title × count × trailing',
            builder: (_) => const _SectionHeaderGallery(),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'AppInfoRow',
        useCases: [
          WidgetbookUseCase(
            name: 'Gallery — string + widget value',
            builder: (_) => const _InfoRowGallery(),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'Composed — User Details dialog',
        useCases: [
          WidgetbookUseCase(
            name: 'User Details (inline render)',
            builder: (_) => const _UserDetailsMock(),
          ),
        ],
      ),
    ],
  );
}

class _StatusBadgeGallery extends StatelessWidget {
  const _StatusBadgeGallery();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          StatusBadge(kind: StatusBadgeKind.active),
          SizedBox(height: 12),
          StatusBadge(kind: StatusBadgeKind.pending),
          SizedBox(height: 12),
          StatusBadge(kind: StatusBadgeKind.atRisk),
          SizedBox(height: 12),
          StatusBadge(kind: StatusBadgeKind.inactive),
          SizedBox(height: 24),
          StatusBadge(kind: StatusBadgeKind.atRisk, label: 'Disconnected'),
        ],
      ),
    );
  }
}

class _AppBadgeGallery extends StatelessWidget {
  const _AppBadgeGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Outlined', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              AppBadge(label: 'Neutral'),
              AppBadge(label: 'Primary', tone: AppBadgeTone.primary),
              AppBadge(label: 'Admin', tone: AppBadgeTone.danger),
              AppBadge(label: 'Warning', tone: AppBadgeTone.warning),
              AppBadge(label: 'Success', tone: AppBadgeTone.success),
            ],
          ),
          const SizedBox(height: 24),
          Text('Filled', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              AppBadge(label: 'Neutral', variant: AppBadgeVariant.filled),
              AppBadge(
                label: 'Primary',
                variant: AppBadgeVariant.filled,
                tone: AppBadgeTone.primary,
              ),
              AppBadge(
                label: 'Admin',
                variant: AppBadgeVariant.filled,
                tone: AppBadgeTone.danger,
              ),
              AppBadge(
                label: 'Warning',
                variant: AppBadgeVariant.filled,
                tone: AppBadgeTone.warning,
              ),
              AppBadge(
                label: 'Success',
                variant: AppBadgeVariant.filled,
                tone: AppBadgeTone.success,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Roles (User Details pattern)',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              AppBadge(label: 'Admin', tone: AppBadgeTone.danger),
              AppBadge(
                label: 'Site Study Coordinator',
                tone: AppBadgeTone.primary,
              ),
              AppBadge(label: 'CRA'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppCardGallery extends StatelessWidget {
  const _AppCardGallery();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const AppCard(child: Text('A simple bordered group of content.')),
          const SizedBox(height: 16),
          const AppCard(
            title: 'User info',
            child: Text('Card with an optional title.'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeaderGallery extends StatelessWidget {
  const _SectionHeaderGallery();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const AppSectionHeader(title: 'Actions'),
          const SizedBox(height: 16),
          const AppSectionHeader(title: 'Assigned Sites', count: 2),
          const SizedBox(height: 16),
          AppSectionHeader(
            title: 'Recent Activity',
            trailing: AppButton(
              variant: AppButtonVariant.tertiary,
              size: AppButtonSize.small,
              label: 'See all',
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRowGallery extends StatelessWidget {
  const _InfoRowGallery();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          AppInfoRow(label: 'Reason', value: 'Device Issues'),
          SizedBox(height: 8),
          AppInfoRow(label: 'Linking codes revoked', value: '3'),
          SizedBox(height: 8),
          AppInfoRow(
            label: 'Status',
            valueWidget: StatusBadge(kind: StatusBadgeKind.active),
          ),
        ],
      ),
    );
  }
}

class _UserDetailsMock extends StatelessWidget {
  const _UserDetailsMock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppDialog(
        size: AppDialogSize.medium,
        title: 'User Details',
        subtitle: 'View and manage user details, roles, and assigned sites.',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // User info card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StatusBadge(kind: StatusBadgeKind.active),
                  const SizedBox(height: 8),
                  Text(
                    'Dr. Emily Parker',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'eparker@clinicaltrial.com',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      AppBadge(label: 'Admin', tone: AppBadgeTone.danger),
                      AppBadge(
                        label: 'Site Study Coordinator',
                        tone: AppBadgeTone.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Assigned Sites section
            const AppSectionHeader(title: 'Assigned Sites', count: 2),
            const SizedBox(height: 8),
            Text(
              '001 - Memorial Hospital',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'New York, NY',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '002 - Stanford Medical Center',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Palo Alto, CA',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Actions section
            const AppSectionHeader(title: 'Actions'),
            const SizedBox(height: 8),
            AppButton(
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              label: 'Edit User',
              leadingIcon: Icons.edit_outlined,
              onPressed: () {},
            ),
            const SizedBox(height: 8),
            AppButton(
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              label: 'Deactivate User',
              leadingIcon: Icons.block_outlined,
              onPressed: () {},
            ),
          ],
        ),
        actions: [AppButton(label: 'Close', onPressed: () {})],
      ),
    );
  }
}
