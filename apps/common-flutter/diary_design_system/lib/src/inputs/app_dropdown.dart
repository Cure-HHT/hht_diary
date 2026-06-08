import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// A single item in an [AppDropdown].
///
/// The optional [description] is reserved for future tooltip / accessibility
/// use; the current popup renders the label only (matches Figma).
@immutable
class AppDropdownItem<T> {
  final T value;
  final String label;
  final String? description;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.description,
  });
}

/// The design system single-select dropdown.
///
/// Custom popup (not Material's `DropdownButton`): rounded card anchored
/// below the trigger, same width, with full-width item rows. The currently
/// selected item gets a light primary tint + trailing checkmark — matches
/// Figma.
// Implements: DIARY-DEV-test-instrumentation/A
class AppDropdown<T> extends StatefulWidget {
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final T? value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool required;
  final bool enabled;

  /// Test-harness locator. When set, wraps the trigger in a
  /// `Semantics(identifier: ..., button: true, value: <selectedLabel>, container: true, explicitChildNodes: true)`
  /// so Playwright can locate it via `flt-semantics-identifier` and read
  /// the selected option through `readSemanticValue`.
  final String? semanticId;

  const AppDropdown({
    super.key,
    required this.items,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.value,
    this.onChanged,
    this.required = false,
    this.enabled = true,
    this.semanticId,
  });

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  final LayerLink _link = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlay;

  bool get _isOpen => _overlay != null;

  @override
  void dispose() {
    // Defer removal until after the build phase if dispose was triggered
    // during one. Don't touch state — we're being torn down.
    _overlay?.remove();
    _overlay = null;
    super.dispose();
  }

  void _toggle() {
    if (_isOpen) {
      _closeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _closeOverlay() {
    if (_overlay == null) return;
    _overlay!.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  void _showOverlay() {
    final renderBox = _fieldKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (overlayContext) {
        final theme = Theme.of(context);
        return Stack(
          children: [
            // Tap-outside dismiss layer.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeOverlay,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + SpacingTokens.xs),
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: size.width,
                  child: _PopupMenu<T>(
                    items: widget.items,
                    selectedValue: widget.value,
                    onSelect: (value) {
                      widget.onChanged?.call(value);
                      _closeOverlay();
                    },
                    theme: theme,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  String? get _selectedLabel {
    if (widget.value == null) return null;
    for (final item in widget.items) {
      if (item.value == widget.value) return item.label;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorText != null;

    final selectedLabel = _selectedLabel;
    final borderColor = hasError
        ? theme.colorScheme.error
        : (_isOpen ? theme.colorScheme.primary : theme.colorScheme.outline);

    final field = CompositedTransformTarget(
      link: _link,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: _fieldKey,
          onTap: widget.enabled ? _toggle : null,
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RadiusTokens.md),
              border: Border.all(color: borderColor, width: _isOpen ? 2 : 1),
              color: widget.enabled
                  ? theme.colorScheme.surface
                  : theme.colorScheme.surfaceContainerLow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedLabel ?? widget.hintText ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selectedLabel == null
                          ? theme.colorScheme.onSurfaceVariant
                          : (widget.enabled
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: widget.enabled
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final fieldWithHelpers = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        if (widget.errorText != null) ...[
          SizedBox(height: SpacingTokens.xs),
          Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ] else if (widget.helperText != null) ...[
          SizedBox(height: SpacingTokens.xs),
          Text(
            widget.helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    final laidOut = widget.label == null
        ? fieldWithHelpers
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _LabelRow(label: widget.label!, required: widget.required),
              SizedBox(height: SpacingTokens.xs),
              fieldWithHelpers,
            ],
          );

    if (widget.semanticId == null) return laidOut;

    return Semantics(
      identifier: widget.semanticId,
      button: true,
      value: selectedLabel ?? '',
      container: true,
      explicitChildNodes: true,
      child: laidOut,
    );
  }
}

class _PopupMenu<T> extends StatelessWidget {
  final List<AppDropdownItem<T>> items;
  final T? selectedValue;
  final ValueChanged<T> onSelect;
  final ThemeData theme;

  const _PopupMenu({
    required this.items,
    required this.selectedValue,
    required this.onSelect,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: const [
          // Same Figma drop shadow language as AppDialog, scaled down.
          BoxShadow(
            color: Color(0x1A364153),
            offset: Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              _PopupMenuItem<T>(
                item: item,
                isSelected: item.value == selectedValue,
                onTap: () => onSelect(item.value),
                theme: theme,
              ),
          ],
        ),
      ),
    );
  }
}

class _PopupMenuItem<T> extends StatelessWidget {
  final AppDropdownItem<T> item;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _PopupMenuItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? ColorTokens.primaryDisabled : null,
        padding: EdgeInsets.symmetric(
          horizontal: SpacingTokens.md,
          vertical: SpacingTokens.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(item.label, style: theme.textTheme.bodyMedium),
            ),
            if (isSelected)
              Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final bool required;
  const _LabelRow({required this.label, required this.required});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        if (required) ...[
          const SizedBox(width: 2),
          Text(
            '*',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
