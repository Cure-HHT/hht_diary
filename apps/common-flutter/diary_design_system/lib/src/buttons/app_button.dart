import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

enum AppButtonVariant {
  /// Filled with theme primary. The default emphasis level.
  primary,

  /// Outlined with theme primary stroke + foreground.
  secondary,

  /// Text-only (no fill, no border).
  tertiary,

  /// Filled with theme error. For Disconnect / Delete / irreversible actions.
  destructive,
}

enum AppButtonSize { small, medium, large }

/// The design system button. One widget, all variants and sizes.
///
/// **Icon-only mode** triggers automatically when [label] is null/empty and
/// [leadingIcon] is set — the button renders as a square with just the icon
/// and compact padding. No separate `AppIconButton` widget exists.
///
/// **States** (default, hover, pressed, focused, disabled) are resolved via
/// Material 3's `WidgetStateProperty` underneath the chosen Material widget
/// (`FilledButton`/`OutlinedButton`/`TextButton`), so hover events fire only on
/// desktop, touch ripple replaces hover on mobile, and focus rings appear on
/// keyboard nav — all without platform checks.
///
/// **Touch target** is at least 48dp on every size; the visual height of
/// [AppButtonSize.small] is 32dp but the hit area is padded out to 48dp.
class AppButton extends StatelessWidget {
  final AppButtonVariant variant;
  final AppButtonSize size;

  /// The button label. When null or empty and [leadingIcon] is set, the button
  /// renders in icon-only mode.
  final String? label;

  final IconData? leadingIcon;
  final IconData? trailingIcon;

  /// Tap callback. When null AND [loading] is false, the button is disabled.
  final VoidCallback? onPressed;

  /// When true, the button shows a spinner in place of its content and disables
  /// the tap callback so duplicate submissions are impossible.
  final bool loading;

  /// When true, the button expands to fill its parent's width.
  final bool fullWidth;

  const AppButton({
    super.key,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.label,
    this.leadingIcon,
    this.trailingIcon,
    this.onPressed,
    this.loading = false,
    this.fullWidth = false,
  });

  bool get _isIconOnly =>
      (label == null || label!.isEmpty) && leadingIcon != null;

  bool get _isEnabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(context);
    final child = _buildChild(context);
    final effectiveOnPressed = _isEnabled ? onPressed : null;

    final Widget button = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.destructive => FilledButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
      AppButtonVariant.tertiary => TextButton(
        onPressed: effectiveOnPressed,
        style: style,
        child: child,
      ),
    };

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  ButtonStyle _styleFor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (hPad, vPad, minH) = _sizeMetrics;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RadiusTokens.md),
    );
    final padding = _isIconOnly
        ? EdgeInsets.all(vPad)
        : EdgeInsets.symmetric(horizontal: hPad, vertical: vPad);
    final minimumSize = Size(_isIconOnly ? minH : 0, minH);

    switch (variant) {
      case AppButtonVariant.primary:
        // Primary uses explicit per-state hexes from AppButtonColors so the
        // hover / pressed / disabled shades come from Figma directly, not
        // Material 3's auto state-layer overlay. overlayColor is forced
        // transparent so Material doesn't darken the explicit backgrounds.
        final buttonColors = Theme.of(context).extension<AppButtonColors>()!;
        final states = buttonColors.primary;
        return ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) {
              return states.backgroundDisabled;
            }
            if (s.contains(WidgetState.pressed)) {
              return states.backgroundPressed;
            }
            if (s.contains(WidgetState.hovered)) {
              return states.backgroundHover;
            }
            return states.background;
          }),
          foregroundColor: WidgetStateProperty.all(states.foreground),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          padding: WidgetStateProperty.all(padding),
          shape: WidgetStateProperty.all(shape),
          minimumSize: WidgetStateProperty.all(minimumSize),
          elevation: WidgetStateProperty.all(0),
        );

      case AppButtonVariant.destructive:
        // TODO(CUR-1426): wire to AppButtonColors.destructive once Figma per-
        // state hexes are confirmed. Until then, colorScheme.error with
        // Material's auto state layers.
        return FilledButton.styleFrom(
          backgroundColor: cs.error,
          foregroundColor: cs.onError,
          padding: padding,
          shape: shape,
          minimumSize: minimumSize,
        );

      case AppButtonVariant.secondary:
        // Secondary uses explicit per-state foreground + border from
        // AppButtonColors. Background stays transparent; overlay forced
        // transparent so Material doesn't tint the explicit colors.
        final buttonColors = Theme.of(context).extension<AppButtonColors>()!;
        final s = buttonColors.secondary;
        return ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return s.foregroundDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return s.foregroundPressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return s.foregroundHover;
            }
            return s.foreground;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: s.borderDisabled);
            }
            if (states.contains(WidgetState.pressed)) {
              return BorderSide(color: s.borderPressed);
            }
            if (states.contains(WidgetState.hovered)) {
              return BorderSide(color: s.borderHover);
            }
            return BorderSide(color: s.border);
          }),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          padding: WidgetStateProperty.all(padding),
          shape: WidgetStateProperty.all(shape),
          minimumSize: WidgetStateProperty.all(minimumSize),
        );

      case AppButtonVariant.tertiary:
        return TextButton.styleFrom(
          foregroundColor: cs.primary,
          padding: padding,
          shape: shape,
          minimumSize: minimumSize,
          // Inter Regular 14 / line-height 20 / letter-spacing -0.15.
          textStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.15,
          ),
        );
    }
  }

  (double hPad, double vPad, double minH) get _sizeMetrics => switch (size) {
    AppButtonSize.small => (SpacingTokens.md, SpacingTokens.xs, 32),
    AppButtonSize.medium => (SpacingTokens.lg, SpacingTokens.sm, 47),
    AppButtonSize.large => (SpacingTokens.xl, SpacingTokens.md, 56),
  };

  double get _iconSize => switch (size) {
    AppButtonSize.small => 14,
    AppButtonSize.medium => 16,
    AppButtonSize.large => 18,
  };

  Widget _buildChild(BuildContext context) {
    if (loading) {
      final dim = _iconSize + 2;
      return SizedBox(
        width: dim,
        height: dim,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          // Inherits foreground color from ButtonStyle.
          color: _resolvedForeground(context),
        ),
      );
    }

    if (_isIconOnly) {
      return Icon(leadingIcon, size: _iconSize);
    }

    final hasLeading = leadingIcon != null;
    final hasTrailing = trailingIcon != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasLeading) ...[
          Icon(leadingIcon, size: _iconSize),
          SizedBox(width: SpacingTokens.sm),
        ],
        Text(label ?? ''),
        if (hasTrailing) ...[
          SizedBox(width: SpacingTokens.sm),
          Icon(trailingIcon, size: _iconSize),
        ],
      ],
    );
  }

  Color _resolvedForeground(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final buttonColors = Theme.of(context).extension<AppButtonColors>();
    switch (variant) {
      case AppButtonVariant.primary:
        return buttonColors!.primary.foreground;
      case AppButtonVariant.secondary:
        return buttonColors!.secondary.foreground;
      case AppButtonVariant.destructive:
        return cs.onError;
      case AppButtonVariant.tertiary:
        return cs.primary;
    }
  }
}
