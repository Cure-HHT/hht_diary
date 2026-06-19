import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent brandedStatusCardComponent() {
  return WidgetbookComponent(
    name: 'BrandedStatusCard',
    useCases: [
      WidgetbookUseCase(
        name: 'Gallery — Figma variants',
        builder: (_) => const _BrandedStatusCardGallery(),
      ),
    ],
  );
}

class _BrandedStatusCardGallery extends StatelessWidget {
  const _BrandedStatusCardGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'BrandedStatusCard — Gallery',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'White 45-px header strip (sponsor logo) sitting on top of a tone-'
          'tinted body. The body text inherits the tone foreground via '
          'DefaultTextStyle so callers compose multi-line metadata cheaply; '
          'individual lines can override the colour (Connected\'s "Linking '
          'code" line is rendered in Dark Grey).',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        _Section(
          title: 'Figma — Connected (success)',
          subtitle: 'node 486:1801 · Approved bg + Approved-Dark text',
          card: const BrandedStatusCard(
            tone: BrandedStatusTone.success,
            header: _SponsorLogo(),
            icon: Icons.how_to_reg_outlined,
            title: 'Connected',
            body: _MetadataBody(
              lines: [
                _MetadataLine('Joined: 6/2/2026 at 5:11 PM'),
                _MetadataLine('Linking code: 24524-52345', muted: true),
              ],
            ),
          ),
        ),
        _Section(
          title: 'Figma — Study Participation Ended (neutral)',
          subtitle: 'node 486:1812 · Light Gray bg + Dark Grey text',
          card: const BrandedStatusCard(
            tone: BrandedStatusTone.neutral,
            header: _SponsorLogo(),
            icon: Icons.folder_outlined,
            title: 'Study Participation Ended',
            body: _MetadataBody(
              lines: [
                _MetadataLine('Joined: 6/2/2026 at 5:11 PM'),
                _MetadataLine('Ended: 6/2/2026 at 5:13 PM'),
                _MetadataLine.gap,
                _MetadataLine('Linking code: 24524-52345'),
              ],
            ),
          ),
        ),
        _Section(
          title: 'Figma — Disconnected (error) with action',
          subtitle: 'node 486:2575 · Critical bg + critical-outlined button',
          card: BrandedStatusCard(
            tone: BrandedStatusTone.error,
            header: const _SponsorLogo(),
            icon: Icons.link_off_outlined,
            title: 'Disconnected',
            body: const _MetadataBody(
              lines: [
                _MetadataLine('Joined: 6/2/2026 at 5:11 PM'),
                _MetadataLine('Linking code: 24524-52345'),
              ],
            ),
            action: _TonedOutlineButton(
              label: 'Enter New Linking Code',
              tone: BrandedStatusTone.error,
              onTap: _noop,
            ),
          ),
        ),
      ],
    );
  }
}

void _noop() {}

/// One line in a [_MetadataBody]. `muted: true` renders in
/// `colorScheme.onSurfaceVariant` instead of the card's default tone
/// colour — used for the "Linking code" row on the Connected card.
/// `_MetadataLine.gap` is a vertical-spacer sentinel.
class _MetadataLine {
  final String? text;
  final bool muted;
  final bool isGap;

  const _MetadataLine(this.text, {this.muted = false}) : isGap = false;
  const _MetadataLine._gap() : text = null, muted = false, isGap = true;

  static const _MetadataLine gap = _MetadataLine._gap();
}

/// Stacks [_MetadataLine]s with the Figma 30-px line-height between
/// rows. Lives in the gallery so the card itself stays composition-
/// agnostic — production callers slot whatever Widget makes sense for
/// their metadata.
class _MetadataBody extends StatelessWidget {
  final List<_MetadataLine> lines;
  const _MetadataBody({required this.lines});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          if (line.isGap)
            const SizedBox(height: 8)
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                line.text!,
                style: line.muted
                    ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
                    : null,
              ),
            ),
      ],
    );
  }
}

/// Outlined button matching a [BrandedStatusTone] — white fill with the
/// tone's accent for both border and label. Used as the
/// "Enter New Linking Code" action on the Disconnected card. Lives in
/// the gallery (not the design system) because it's the only place that
/// pairs the tone-resolution logic with a one-off button shape.
class _TonedOutlineButton extends StatelessWidget {
  final String label;
  final BrandedStatusTone tone;
  final VoidCallback onTap;

  const _TonedOutlineButton({
    required this.label,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final cs = theme.colorScheme;
    final accent = switch (tone) {
      BrandedStatusTone.success => semantic.onSuccessContainer,
      BrandedStatusTone.neutral => cs.onSurfaceVariant,
      BrandedStatusTone.error => cs.onErrorContainer,
    };

    final radius = BorderRadius.circular(6);
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: Material(
        color: cs.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: accent),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  letterSpacing: -0.4459,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget card;
  const _Section({required this.title, required this.card, this.subtitle});

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
            child: card,
          ),
        ],
      ),
    );
  }
}

/// Placeholder sponsor logo for the gallery — production callers pass
/// the real sponsor's logo image into [BrandedStatusCard.header].
class _SponsorLogo extends StatelessWidget {
  const _SponsorLogo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.water_drop_outlined,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 6),
        Text(
          'SPONSOR',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
