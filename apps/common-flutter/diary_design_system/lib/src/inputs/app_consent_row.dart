import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// A tappable consent box — the "I have read, understand, and consent to
/// the Privacy Policy for this clinical trial." pattern from the Figma
/// notifications / alerts screens.
///
/// The row chrome (Primary-Light-Soft fill, 6px radius, no border) and
/// the body text colour are constant across all states; only the
/// checkbox itself communicates state:
///   - **default** — white fill, Primary-Light border.
///   - **error** — white fill, critical border. Text + bg do **not**
///     turn red; only the checkbox does (per Figma).
///   - **checked** — primary fill, primary border, white check.
///
/// To compose richer text (links, bold), pass a [bodyBuilder] instead of
/// [text]; the builder receives the resolved foreground colour so spans
/// can pick it up.
class AppConsentRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? text;
  final Widget Function(BuildContext, Color foreground)? bodyBuilder;
  final bool hasError;
  final bool enabled;

  /// Test-harness locator. When set, wraps the row in a
  /// `Semantics(identifier: ..., checked: value, container: true, explicitChildNodes: true)`
  /// node so Playwright can target it by `flt-semantics-identifier`.
  final String? semanticId;

  const AppConsentRow({
    super.key,
    required this.value,
    this.onChanged,
    this.text,
    this.bodyBuilder,
    this.hasError = false,
    this.enabled = true,
    this.semanticId,
  }) : assert(
         text != null || bodyBuilder != null,
         'AppConsentRow requires either text or bodyBuilder.',
       );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final cs = theme.colorScheme;

    final foreground = enabled
        ? cs.onSurface
        : cs.onSurface.withValues(alpha: 0.4);

    final body = bodyBuilder != null
        ? bodyBuilder!(context, foreground)
        : Text(
            text!,
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          );

    final radius = BorderRadius.circular(RadiusTokens.md);
    final effectiveOnTap = enabled && onChanged != null
        ? () => onChanged!(!value)
        : null;

    final row = Material(
      color: semantic.primaryLightSoft,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.all(SpacingTokens.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConsentCheckbox(
                value: value,
                hasError: hasError,
                enabled: enabled,
              ),
              SizedBox(width: SpacingTokens.md),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );

    if (semanticId == null) return row;

    return Semantics(
      identifier: semanticId,
      checked: value,
      container: true,
      explicitChildNodes: true,
      child: row,
    );
  }
}

/// 22×22 checkbox glyph drawn to match the Figma consent-row spec
/// exactly (5px radius, 2px border, white fill when unchecked, primary
/// fill + white check when checked). Kept private to this file because
/// Material's [Checkbox] can't be coerced to these exact dimensions
/// without per-state overrides for every property — and these consent
/// rows are the only place the design uses this glyph.
class _ConsentCheckbox extends StatelessWidget {
  final bool value;
  final bool hasError;
  final bool enabled;

  const _ConsentCheckbox({
    required this.value,
    required this.hasError,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;

    final Color borderColor;
    final Color fillColor;
    if (!enabled) {
      borderColor = cs.outline;
      fillColor = cs.surface;
    } else if (value) {
      borderColor = cs.primary;
      fillColor = cs.primary;
    } else if (hasError) {
      borderColor = cs.error;
      fillColor = cs.surface;
    } else {
      borderColor = semantic.primaryLight;
      fillColor = cs.surface;
    }

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: value ? Icon(Icons.check, size: 14, color: cs.onPrimary) : null,
    );
  }
}
