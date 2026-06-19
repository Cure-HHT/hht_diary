import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent appSegmentedChoiceComponent() {
  return WidgetbookComponent(
    name: 'AppSegmentedChoice',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — Figma variants',
        builder: (_) => const _SegmentedChoiceGallery(),
      ),
    ],
  );
}

enum _Answer { yes, no, dontRemember }

const _options = [
  AppChoiceOption<_Answer>(value: _Answer.yes, label: 'Yes'),
  AppChoiceOption<_Answer>(value: _Answer.no, label: 'No'),
  AppChoiceOption<_Answer>(
    value: _Answer.dontRemember,
    label: "Don't remember",
  ),
];

class _SegmentedChoiceGallery extends StatefulWidget {
  const _SegmentedChoiceGallery();

  @override
  State<_SegmentedChoiceGallery> createState() =>
      _SegmentedChoiceGalleryState();
}

class _SegmentedChoiceGalleryState extends State<_SegmentedChoiceGallery> {
  _Answer? _interactive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'AppSegmentedChoice — Gallery',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Single-select choice group built on AppButton(variant: segment). '
          'Used by the symptom-confirmation prompt in the notifications '
          'screens — shown here inside its Primary-Light-Soft prompt card '
          'so the typography stack reads in context.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        _Prompt(
          title: 'Figma — Default (no selection)',
          subtitle: 'node 452:9342 · all buttons white',
          child: AppSegmentedChoice<_Answer>(
            options: _options,
            value: null,
            onChanged: (_) {},
          ),
        ),
        _Prompt(
          title: 'Figma — "Yes" selected',
          subtitle: 'node 452:9548 · Yes button primary-light filled',
          child: AppSegmentedChoice<_Answer>(
            options: _options,
            value: _Answer.yes,
            onChanged: (_) {},
          ),
        ),
        _Prompt(
          title: 'Interactive (tap to change)',
          child: AppSegmentedChoice<_Answer>(
            options: _options,
            value: _interactive,
            onChanged: (v) => setState(() => _interactive = v),
          ),
        ),
        _Prompt(
          title: 'Disabled',
          child: AppSegmentedChoice<_Answer>(
            options: _options,
            value: _Answer.no,
            onChanged: null,
            enabled: false,
          ),
        ),
      ],
    );
  }
}

/// Wraps a choice row in the Figma's Primary-Light-Soft prompt card —
/// title + question stacked above the buttons. Kept inside the gallery
/// because the card itself is a composition pattern, not a design-
/// system primitive (callers in production wire their own headers).
class _Prompt extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Prompt({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

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
            constraints: const BoxConstraints(maxWidth: 398),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: semantic.primaryLightSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Confirm Yesterday, May 21',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 25.5 / 14,
                      letterSpacing: -0.4316,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Did you have nosebleeds?',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 25.5 / 14,
                      letterSpacing: -0.4316,
                    ),
                  ),
                  const SizedBox(height: 15),
                  child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
