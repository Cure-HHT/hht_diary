import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

void _noop() {}

WidgetbookComponent appButtonComponent() {
  return WidgetbookComponent(
    name: 'AppButton',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — all variants × states',
        builder: (_) => const _AppButtonGallery(),
      ),
    ],
  );
}

class _AppButtonGallery extends StatelessWidget {
  const _AppButtonGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('AppButton — Gallery', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Hover or click any button to see hover / pressed states. '
          'Default, disabled, and loading are rendered statically below.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        const _VariantSection(
          title: 'Primary',
          variant: AppButtonVariant.primary,
        ),
        const _VariantSection(
          title: 'Secondary',
          variant: AppButtonVariant.secondary,
        ),
        const _VariantSection(
          title: 'Tertiary',
          variant: AppButtonVariant.tertiary,
        ),
        const _VariantSection(
          title: 'Destructive',
          variant: AppButtonVariant.destructive,
        ),
      ],
    );
  }
}

class _VariantSection extends StatelessWidget {
  final String title;
  final AppButtonVariant variant;
  const _VariantSection({required this.title, required this.variant});

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
          _Row(
            label: 'Sizes',
            children: [
              AppButton(
                variant: variant,
                size: AppButtonSize.small,
                label: 'Small',
                onPressed: _noop,
              ),
              AppButton(
                variant: variant,
                size: AppButtonSize.medium,
                label: 'Medium',
                onPressed: _noop,
              ),
              AppButton(
                variant: variant,
                size: AppButtonSize.large,
                label: 'Large',
                onPressed: _noop,
              ),
            ],
          ),
          _Row(
            label: 'States',
            children: [
              AppButton(variant: variant, label: 'Default', onPressed: _noop),
              AppButton(variant: variant, label: 'Disabled'),
              AppButton(
                variant: variant,
                label: 'Loading',
                loading: true,
                onPressed: _noop,
              ),
            ],
          ),
          _Row(
            label: 'Icons',
            children: [
              AppButton(
                variant: variant,
                label: 'Leading',
                leadingIcon: Icons.save_outlined,
                onPressed: _noop,
              ),
              AppButton(
                variant: variant,
                label: 'Trailing',
                trailingIcon: Icons.arrow_forward,
                onPressed: _noop,
              ),
              AppButton(
                variant: variant,
                leadingIcon: Icons.add,
                semanticLabel: 'Add',
                onPressed: _noop,
              ),
            ],
          ),
          _Row(
            label: 'Full width',
            children: [
              SizedBox(
                width: 320,
                child: AppButton(
                  variant: variant,
                  label: 'Continue',
                  fullWidth: true,
                  onPressed: _noop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _Row({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
