import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent appTextFieldComponent() {
  return WidgetbookComponent(
    name: 'AppTextField',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — variants × states',
        builder: (_) => const _AppTextFieldGallery(),
      ),
    ],
  );
}

class _AppTextFieldGallery extends StatelessWidget {
  const _AppTextFieldGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('AppTextField — Gallery', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Default + .search factory. Focus the field to see focused state; '
          'enter text in .search to surface the clear button.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),

        _Section(
          title: 'Default',
          children: [
            const AppTextField(label: 'Name', hintText: 'Dr. Emily Parker'),
            const AppTextField(
              label: 'Email',
              required: true,
              hintText: 'eparker@clinicaltrial.com',
            ),
            const AppTextField(
              label: 'Notes',
              hintText: 'Optional context',
              maxLines: 3,
              minLines: 3,
            ),
            const AppTextField(
              label: 'Disabled',
              hintText: 'Read-only',
              enabled: false,
            ),
            const AppTextField(
              label: 'With error',
              errorText: 'This field is required',
            ),
            const AppTextField(
              label: 'With helper text',
              helperText: 'We use this for sign-in only',
            ),
          ],
        ),

        _Section(
          title: '.search',
          children: [
            AppTextField.search(),
            AppTextField.search(hintText: 'Search participants…'),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

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
          for (final c in children) ...[c, const SizedBox(height: 16)],
        ],
      ),
    );
  }
}
