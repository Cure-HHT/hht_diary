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

  /// Borderless 34-px pill used inside [AppSegmentedChoice] — white fill
  /// + `onSurface` label when [AppButton.selected] is false, primary-
  /// light fill + primary-light-soft label when selected. Ignores
  /// [AppButtonSize] (always 34-px); `size` is honoured for the other
  /// variants only.
  segment,
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

  /// Optional custom leading widget (e.g. a Figma-exported PNG via
  /// [Image.asset]). Takes precedence over [leadingIcon] when both are set
  /// — callers that need a sponsor-supplied glyph instead of a Material
  /// icon pass this. Sized to the variant's icon dimension automatically.
  final Widget? leadingWidget;

  /// Tap callback. When null AND [loading] is false, the button is disabled.
  final VoidCallback? onPressed;

  /// When true, the button shows a spinner in place of its content and disables
  /// the tap callback so duplicate submissions are impossible.
  final bool loading;

  /// When true, the button expands to fill its parent's width.
  final bool fullWidth;

  /// Accessibility label. **Required when the button renders in icon-only
  /// mode** (no [label]), so screen readers announce the action. Ignored
  /// when [label] is non-empty — the visible label is the announcement.
  /// Test-harness locator. When set, wraps the button in a
  /// `Semantics(identifier: ..., button: true, container: true, explicitChildNodes: true)`
  /// node so Playwright (or any harness) can target this button by
  /// `flt-semantics-identifier`.
  final String? semanticId;

  /// Optional screen-reader label override. Useful for icon-only buttons
  /// where [label] is null and the inner widgets have no readable text.
  final String? semanticLabel;

  /// Only meaningful for [AppButtonVariant.segment] — toggles the
  /// selected (primary-light fill) vs unselected (white fill) chrome.
  /// Ignored for every other variant.
  final bool selected;

  const AppButton({
    super.key,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.label,
    this.leadingIcon,
    this.leadingWidget,
    this.trailingIcon,
    this.onPressed,
    this.loading = false,
    this.fullWidth = false,
    this.selected = false,
    this.semanticLabel,
    this.semanticId,
  }) : assert(
         // Const-safe: catches the icon-only-with-no-label case
         // (label == null && leadingIcon != null) without using
         // `.isNotEmpty` / `.length`, neither of which evaluate in a
         // const constructor's assert. An empty-string label still
         // slips through here — the visual + screen-reader label is the
         // caller's responsibility to make non-empty.
         label != null || leadingIcon == null || semanticLabel != null,
         'AppButton in icon-only mode requires a semanticLabel for screen '
         'readers. Pass semanticLabel: "..." describing the action.',
       );

  bool get _isIconOnly =>
      (label == null || label!.isEmpty) && leadingIcon != null;

  bool get _isEnabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(context);
    final child = _buildChild(context);
    final effectiveOnPressed = _isEnabled ? onPressed : null;

    final Widget button = switch (variant) {
      AppButtonVariant.primary ||
      AppButtonVariant.destructive ||
      AppButtonVariant.segment => FilledButton(
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

    final sized = fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;

    if (semanticId == null && semanticLabel == null) return sized;

    return Semantics(
      identifier: semanticId,
      label: semanticLabel,
      button: true,
      container: true,
      explicitChildNodes: true,
      child: sized,
    );
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
        // Bind to AppButtonColors.primary.background so tertiary text matches
        // the primary button's fill exactly. Reading from cs.primary instead
        // drifts whenever a host app overrides the ColorScheme seed without
        // touching AppButtonColors (e.g. clinical_diary's teal seed paints
        // tertiary in a lighter green-teal than the dark Carina primary).
        final buttonColors = Theme.of(context).extension<AppButtonColors>()!;
        final tertiaryColor = buttonColors.primary.background;
        return TextButton.styleFrom(
          foregroundColor: tertiaryColor,
          padding: padding,
          shape: shape,
          minimumSize: minimumSize,
          // Inter Regular 14 / line-height 20 / letter-spacing -0.15.
          textStyle: TextStyle(
            fontWeight: FontWeight.w400,
            color: tertiaryColor,
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: -0.15,
          ),
        );

      case AppButtonVariant.segment:
        // Segment ignores `size` — always Figma 34-px pill with 12-px
        // horizontal padding. Background + foreground swap on
        // [selected]; no border in either state.
        final semantic = Theme.of(context).extension<AppSemanticColors>()!;
        final segBackground = selected ? semantic.primaryLight : cs.surface;
        final segForeground = selected
            ? semantic.primaryLightSoft
            : cs.onSurface;
        return FilledButton.styleFrom(
          backgroundColor: segBackground,
          foregroundColor: segForeground,
          disabledBackgroundColor: segBackground.withValues(alpha: 0.4),
          disabledForegroundColor: segForeground.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: shape,
          minimumSize: const Size(0, 34),
          // Inter Medium 14 / line-height 21.25 / letter-spacing -0.2233.
          textStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            height: 21.25 / 14,
            letterSpacing: -0.2233,
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

    final hasLeading = leadingWidget != null || leadingIcon != null;
    final hasTrailing = trailingIcon != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasLeading) ...[
          SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: leadingWidget ?? Icon(leadingIcon, size: _iconSize),
          ),
          SizedBox(width: SpacingTokens.sm),
        ],
        // Flexible + ellipsis so a label longer than the allocated
        // width (e.g. "Don't remember" inside an AppSegmentedChoice
        // column) truncates cleanly instead of overflowing the button
        // chrome. Flexible inside a `MainAxisSize.min` Row hugs by
        // default and only shrinks when the parent imposes a tighter
        // constraint — so this stays safe for free-floating buttons.
        Flexible(
          child: Text(
            label ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
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
        return buttonColors!.primary.background;
      case AppButtonVariant.segment:
        final semantic = Theme.of(context).extension<AppSemanticColors>()!;
        return selected ? semantic.primaryLightSoft : cs.onSurface;
    }
  }
}
