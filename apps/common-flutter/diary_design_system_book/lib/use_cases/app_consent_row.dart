import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent appConsentRowComponent() {
  return WidgetbookComponent(
    name: 'AppConsentRow',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — Figma variants (default / error / checked)',
        builder: (_) => const _ConsentRowGallery(),
      ),
    ],
  );
}

class _ConsentRowGallery extends StatefulWidget {
  const _ConsentRowGallery();

  @override
  State<_ConsentRowGallery> createState() => _ConsentRowGalleryState();
}

class _ConsentRowGalleryState extends State<_ConsentRowGallery> {
  bool _interactive = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('AppConsentRow — Gallery', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Primary-Light-Soft tile with a 22×22 consent checkbox. Row chrome '
          'and body text are constant across states; only the checkbox '
          'changes (Primary-Light border by default, Critical border in '
          'error, filled Primary with white check when checked).',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Figma — Default (unchecked)',
          subtitle: 'node 452:9489 · Primary-Light bordered checkbox',
          child: AppConsentRow(
            value: false,
            onChanged: (_) {},
            bodyBuilder: (context, fg) => _ConsentText(foreground: fg),
          ),
        ),
        _Section(
          title: 'Figma — Error (unchecked, invalid)',
          subtitle: 'node 452:9543 · only the checkbox border turns critical',
          child: AppConsentRow(
            value: false,
            onChanged: (_) {},
            hasError: true,
            bodyBuilder: (context, fg) => _ConsentText(foreground: fg),
          ),
        ),
        _Section(
          title: 'Figma — Checked',
          subtitle: 'node 452:9536 · primary fill + white check',
          child: AppConsentRow(
            value: true,
            onChanged: (_) {},
            bodyBuilder: (context, fg) => _ConsentText(foreground: fg),
          ),
        ),
        const SizedBox(height: 8),
        _Section(
          title: 'Interactive (tap anywhere on the row)',
          child: AppConsentRow(
            value: _interactive,
            onChanged: (v) => setState(() => _interactive = v),
            bodyBuilder: (context, fg) => _ConsentText(foreground: fg),
          ),
        ),
        _Section(
          title: 'Plain text variant (no inline link)',
          child: AppConsentRow(
            value: false,
            onChanged: (_) {},
            text:
                'I have read, understand, and consent to the Privacy Policy '
                'for this clinical trial.',
          ),
        ),
        _Section(
          title: 'Disabled',
          child: AppConsentRow(
            value: false,
            enabled: false,
            bodyBuilder: (context, fg) => _ConsentText(foreground: fg),
          ),
        ),
      ],
    );
  }
}

/// "I have read, understand, and consent to the Privacy Policy for this
/// clinical trial." with "Privacy Policy" rendered as an underlined link
/// in `colorScheme.primary` — matches the Figma rich-text spec exactly.
class _ConsentText extends StatelessWidget {
  final Color foreground;
  const _ConsentText({required this.foreground});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium?.copyWith(
      color: foreground,
      fontSize: 15,
      height: 22.5 / 15,
      letterSpacing: -0.2,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'I have read, understand, and consent to the '),
          TextSpan(
            text: 'Privacy Policy',
            style: base?.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w500,
            ),
          ),
          const TextSpan(text: ' for this clinical trial.'),
        ],
      ),
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
            constraints: const BoxConstraints(maxWidth: 427),
            child: child,
          ),
        ],
      ),
    );
  }
}
