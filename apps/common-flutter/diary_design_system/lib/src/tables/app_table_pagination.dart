import 'package:flutter/material.dart';

import '../inputs/app_dropdown.dart';
import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';

/// Compact inline pagination row, designed for the top-right slot of
/// [AppDataTable]. Layout:
///
/// > Viewing N–M of Total · {pageSize ▼} · ‹ · 1 2 3 … · ›
///
/// **Controlled component.** The caller owns the current page and reacts to
/// callbacks — this widget just renders.
class AppTablePagination extends StatelessWidget {
  /// 1-indexed current page.
  final int currentPage;
  final int pageSize;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  /// Optional page-size selector. When non-null, the widget renders a small
  /// inline dropdown left of the prev/next controls.
  final List<int>? pageSizeOptions;
  final ValueChanged<int>? onPageSizeChanged;

  /// Maximum numbered page buttons to show. When [_totalPages] exceeds this,
  /// ellipsis appears between the first/last and the window around the
  /// current page.
  final int maxNumberedPages;

  const AppTablePagination({
    super.key,
    required this.currentPage,
    required this.pageSize,
    required this.totalCount,
    required this.onPageChanged,
    this.pageSizeOptions,
    this.onPageSizeChanged,
    this.maxNumberedPages = 5,
  });

  int get _totalPages =>
      totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;

  int get _rangeStart =>
      totalCount == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;

  int get _rangeEnd {
    final upper = currentPage * pageSize;
    return upper > totalCount ? totalCount : upper;
  }

  bool get _canPrev => currentPage > 1;
  bool get _canNext => currentPage < _totalPages;

  /// Builds the list of "page buttons" to render. `null` entries represent
  /// ellipses between non-contiguous page ranges.
  List<int?> _pageButtons() {
    final total = _totalPages;
    if (total <= maxNumberedPages) {
      return [for (var i = 1; i <= total; i++) i];
    }
    // Always include first + last; window around current.
    final pages = <int?>{1, total};
    final half = (maxNumberedPages - 2) ~/ 2;
    for (var i = currentPage - half; i <= currentPage + half; i++) {
      if (i > 1 && i < total) pages.add(i);
    }
    final sorted = pages.whereType<int>().toList()..sort();
    final result = <int?>[];
    for (var i = 0; i < sorted.length; i++) {
      result.add(sorted[i]);
      if (i + 1 < sorted.length && sorted[i + 1] != sorted[i] + 1) {
        result.add(null); // ellipsis
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Viewing $_rangeStart-$_rangeEnd of $totalCount',
          // Inter Regular 12 / line-height 16.
          style: TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (pageSizeOptions != null && onPageSizeChanged != null) ...[
          SizedBox(width: SpacingTokens.md),
          _PageSizeSelector(
            pageSize: pageSize,
            options: pageSizeOptions!,
            onChanged: onPageSizeChanged!,
          ),
        ],
        SizedBox(width: SpacingTokens.md),
        _NavButton(
          icon: Icons.chevron_left,
          tooltip: 'Previous page',
          onPressed: _canPrev ? () => onPageChanged(currentPage - 1) : null,
        ),
        for (final entry in _pageButtons()) ...[
          const SizedBox(width: 4),
          if (entry == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            _PageNumberButton(
              page: entry,
              isActive: entry == currentPage,
              onTap: () => onPageChanged(entry),
            ),
        ],
        const SizedBox(width: 4),
        _NavButton(
          icon: Icons.chevron_right,
          tooltip: 'Next page',
          onPressed: _canNext ? () => onPageChanged(currentPage + 1) : null,
        ),
      ],
    );
  }
}

class _PageSizeSelector extends StatelessWidget {
  final int pageSize;
  final List<int> options;
  final ValueChanged<int> onChanged;

  const _PageSizeSelector({
    required this.pageSize,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // SizedBox constrains the trigger (and its anchored popup) to a
    // narrow inline footprint — the value is always a small integer, so
    // a full-width AppDropdown would dwarf the rest of the pagination
    // row. `dense: true` shrinks the trigger to ~32 px tall so it aligns
    // with the prev/next chevron buttons on either side.
    return SizedBox(
      width: 72,
      child: AppDropdown<int>(
        dense: true,
        value: pageSize,
        items: [
          for (final n in options) AppDropdownItem<int>(value: n, label: '$n'),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        minimumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _PageNumberButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;

  const _PageNumberButton({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RadiusTokens.full),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Primary Light Soft tint for the active page — Figma uses
          // colorScheme.primaryContainer so sponsor brand overrides apply.
          color: isActive
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(
          page.toString(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
