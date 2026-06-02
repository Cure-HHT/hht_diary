import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

const _reasons = [
  AppDropdownItem(value: 'device', label: 'Device Issues'),
  AppDropdownItem(value: 'tech', label: 'Technical Issues'),
  AppDropdownItem(value: 'other', label: 'Other'),
];

WidgetbookComponent appDropdownComponent() {
  return WidgetbookComponent(
    name: 'AppDropdown',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — variants × states',
        builder: (_) => const _AppDropdownGallery(),
      ),
    ],
  );
}

class _AppDropdownGallery extends StatelessWidget {
  const _AppDropdownGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('AppDropdown — Gallery', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 24),
        const AppDropdown<String>(
          label: 'Reason',
          required: true,
          hintText: 'Select a reason',
          items: _reasons,
        ),
        const SizedBox(height: 16),
        const AppDropdown<String>(
          label: 'With error',
          errorText: 'Please select a reason',
          items: _reasons,
        ),
        const SizedBox(height: 16),
        const AppDropdown<String>(
          label: 'Disabled',
          enabled: false,
          items: _reasons,
        ),
      ],
    );
  }
}
