import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent appCheckboxComponent() {
  return WidgetbookComponent(
    name: 'AppCheckbox',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — checked × unchecked × tristate × disabled',
        builder: (_) => const _AppCheckboxGallery(),
      ),
    ],
  );
}

class _AppCheckboxGallery extends StatefulWidget {
  const _AppCheckboxGallery();

  @override
  State<_AppCheckboxGallery> createState() => _AppCheckboxGalleryState();
}

class _AppCheckboxGalleryState extends State<_AppCheckboxGallery> {
  bool _admin = true;
  bool _ssc = true;
  bool _cra = false;
  bool? _parent = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('AppCheckbox — Gallery', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 24),
        Text('Roles (no label)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            AppCheckbox(value: true, onChanged: (_) {}),
            const SizedBox(width: 16),
            AppCheckbox(value: false, onChanged: (_) {}),
            const SizedBox(width: 16),
            const AppCheckbox(value: true), // disabled (no onChanged)
          ],
        ),
        const SizedBox(height: 24),
        Text('Roles (with labels)', style: theme.textTheme.titleSmall),
        AppCheckbox(
          value: _admin,
          label: 'Admin',
          onChanged: (v) => setState(() => _admin = v ?? false),
        ),
        AppCheckbox(
          value: _ssc,
          label: 'Site Study Coordinator',
          onChanged: (v) => setState(() => _ssc = v ?? false),
        ),
        AppCheckbox(
          value: _cra,
          label: 'CRA',
          onChanged: (v) => setState(() => _cra = v ?? false),
        ),
        const AppCheckbox(value: false, label: 'Disabled', enabled: false),
        const SizedBox(height: 24),
        Text(
          'Tristate (parent of a checkbox group)',
          style: theme.textTheme.titleSmall,
        ),
        AppCheckbox(
          value: _parent,
          label: 'Select all',
          tristate: true,
          onChanged: (v) => setState(() => _parent = v),
        ),
      ],
    );
  }
}
