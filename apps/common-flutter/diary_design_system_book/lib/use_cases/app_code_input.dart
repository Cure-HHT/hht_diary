import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent appCodeInputComponent() {
  return WidgetbookComponent(
    name: 'AppCodeInput',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — Figma variants',
        builder: (_) => const _AppCodeInputGallery(),
      ),
    ],
  );
}

class _AppCodeInputGallery extends StatefulWidget {
  const _AppCodeInputGallery();

  @override
  State<_AppCodeInputGallery> createState() => _AppCodeInputGalleryState();
}

class _AppCodeInputGalleryState extends State<_AppCodeInputGallery> {
  final _interactive = TextEditingController();

  @override
  void dispose() {
    _interactive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('AppCodeInput — Gallery', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Two-segment linking code field (XXXXX – XXXXX). Auto-advances on '
          'a full segment; backspace on an empty segment jumps back and '
          'deletes the previous char. A single helper or error message '
          'renders once below the row.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Figma — Empty / idle',
          subtitle: 'node 452:9452 · light outline, grey hint glyphs',
          child: const AppCodeInput(
            helperText: 'Code format: XXXXX-XXXXX, letters and numbers',
          ),
        ),
        _Section(
          title: 'Figma — Focus / partial entry',
          subtitle:
              'node 452:9461 · focused segment picks up '
              'primary-light 2px border',
          child: const _AutoFocusedCodeInput(),
        ),
        _Section(
          title: 'Figma — Valid (approved)',
          subtitle: 'node 452:9470 · success border + success-coloured glyphs',
          child: const AppCodeInput(
            initialValue: '3RTWH140KQML',
            state: AppCodeInputState.valid,
            helperText: 'Code format: XXXXX-XXXXX, letters and numbers',
          ),
        ),
        _Section(
          title: 'Figma — Invalid (error)',
          subtitle:
              'node 452:9479 · critical border + glyphs, error '
              'message replaces helper',
          child: const AppCodeInput(
            initialValue: '3RTWH3RTWH',
            errorText:
                'Invalid linking code. Please check the code and try '
                'again.',
          ),
        ),
        const SizedBox(height: 8),
        _Section(
          title: 'Interactive (type to see auto-advance + back-delete)',
          child: AppCodeInput(
            controller: _interactive,
            helperText: 'Tab between fields or type 5 chars to advance',
          ),
        ),
        _Section(
          title: 'Disabled',
          child: const AppCodeInput(initialValue: 'KJWF8ALS57', enabled: false),
        ),
      ],
    );
  }
}

/// Auto-focuses the first segment so the gallery card visually shows
/// the Figma "focus / partial" variant (primary-light 2px border on the
/// active segment) without the user having to click into it.
class _AutoFocusedCodeInput extends StatefulWidget {
  const _AutoFocusedCodeInput();

  @override
  State<_AutoFocusedCodeInput> createState() => _AutoFocusedCodeInputState();
}

class _AutoFocusedCodeInputState extends State<_AutoFocusedCodeInput> {
  @override
  Widget build(BuildContext context) {
    // Initial value seeds the first segment with two characters so the
    // partial-entry shape from Figma is visible.
    return const AppCodeInput(
      initialValue: '3H',
      helperText: 'Code format: XXXXX-XXXXX, letters and numbers',
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
