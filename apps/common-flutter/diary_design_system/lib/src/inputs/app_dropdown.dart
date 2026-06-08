import 'package:flutter/material.dart';

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

  /// When true, the trigger renders at the compact ~32-px height (tighter
  /// vertical padding + smaller chevron). Used by inline composers like
  /// the table page-size selector.
  final bool dense;

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
    this.dense = false,
    this.semanticId,
  });

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>>
    with WidgetsBindingObserver {
  final LayerLink _link = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlay;

  // Subscriptions held while the overlay is open so we can dismiss on the
  // edge cases plain tap-outside doesn't cover (route changes, ancestor
  // scroll, viewport rotation).
  ModalRoute<dynamic>? _route;
  LocalHistoryEntry? _historyEntry;
  ScrollPosition? _ancestorScroll;
  bool _disposed = false;

  bool get _isOpen => _overlay != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Flip _disposed before detaching listeners so the LocalHistoryEntry's
    // onRemove (which fires synchronously inside removeLocalHistoryEntry)
    // sees we're tearing down and skips the setState() that would assert
    // on a defunct Element.
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _detachOverlayListeners();
    _overlay?.remove();
    _overlay = null;
    super.dispose();
  }

  /// MediaQuery size change (rotation, browser resize, on-screen keyboard
  /// raise). The followed field shifts; the cleanest UX is to close so
  /// the user re-opens against the new layout.
  @override
  void didChangeMetrics() {
    if (_isOpen) _closeOverlay();
  }

  void _toggle() {
    if (_isOpen) {
      _closeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _closeOverlay() {
    // Snapshot _overlay then null it FIRST. _detachOverlayListeners ends
    // up popping the local-history entry, which fires _onHistoryEntryRemoved
    // and re-enters _closeOverlay; nulling up front makes the re-entry a
    // no-op rather than a double-remove.
    final entry = _overlay;
    if (entry == null) return;
    _overlay = null;
    _detachOverlayListeners();
    entry.remove();
    if (mounted) setState(() {});
  }

  /// Attach the listeners that auto-dismiss the overlay when the user
  /// navigates away, scrolls a parent, or otherwise moves the field out
  /// from under the popup.
  void _attachOverlayListeners() {
    // Push a no-op history entry on the current route. A system back-press
    // (or programmatic pop) consumes this entry first, firing onRemove —
    // which closes the overlay without popping the actual route. This is
    // the canonical pattern for transient surfaces (menus, sheets).
    _route = ModalRoute.of(context);
    if (_route != null) {
      _historyEntry = LocalHistoryEntry(onRemove: _onHistoryEntryRemoved);
      _route!.addLocalHistoryEntry(_historyEntry!);
    }
    // Closest scrollable ancestor — if the field is on a scrolling page
    // and the user scrolls, the popup would float over stale content.
    _ancestorScroll = Scrollable.maybeOf(context)?.position;
    _ancestorScroll?.addListener(_onAncestorScroll);
  }

  void _detachOverlayListeners() {
    final entry = _historyEntry;
    _historyEntry = null;
    if (entry != null && _route?.willHandlePopInternally == true) {
      // Entry is still on the route's local history — pop it ourselves
      // so we don't leak it (e.g. user tapped outside or selected a value
      // rather than back-pressing).
      _route!.removeLocalHistoryEntry(entry);
    }
    _route = null;
    _ancestorScroll?.removeListener(_onAncestorScroll);
    _ancestorScroll = null;
  }

  /// Fired when the system / Navigator removes our local-history entry
  /// (back-press, parent route pop, programmatic Navigator.pop). Also
  /// fires synchronously from inside dispose() when we pop the entry
  /// ourselves during teardown — _disposed gates that path so we don't
  /// touch the defunct Element.
  void _onHistoryEntryRemoved() {
    _historyEntry = null;
    if (_disposed) return;
    if (_isOpen) _closeOverlay();
  }

  void _onAncestorScroll() {
    if (_isOpen) _closeOverlay();
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
    _attachOverlayListeners();
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
              // 4 px in dense mode keeps the trigger at ~32 px tall so it
              // lines up with sibling 32 × 32 IconButtons; 12 px otherwise
              // matches the form-field rhythm used by AppTextField.
              vertical: widget.dense ? SpacingTokens.xs : SpacingTokens.md,
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
                  size: widget.dense ? 18 : 20,
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
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
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
