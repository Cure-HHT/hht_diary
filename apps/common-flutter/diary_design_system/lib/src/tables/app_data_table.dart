import 'package:flutter/material.dart';

import '../tokens/radius_tokens.dart';
import '../tokens/spacing_tokens.dart';
import 'app_table_tabs.dart';

/// Sort direction for [AppDataTable].
enum SortDirection { ascending, descending }

/// A column definition for [AppDataTable].
///
/// Cells are produced by [cellBuilder] — the table widget knows nothing about
/// the row type; consumers compose `StatusBadge`s, `AppButton.icon`s, avatars,
/// or any widget per column.
@immutable
class AppTableColumn<T> {
  /// Stable identifier — used as the sort-state key emitted by `onSort`.
  final String key;

  /// Header label.
  final String label;

  /// Fixed width in logical pixels. `null` lets the column flex.
  final double? width;

  /// Cell + header alignment. Default `topLeft` so when one column wraps to
  /// multiple lines, single-line cells stay flush with the row's top instead
  /// of being vertically centered (which leaves the row looking padded).
  final Alignment alignment;

  /// When true, the column header is tappable and acts as a sort target.
  final bool sortable;

  /// Optional widget rendered next to the header label (e.g., an info icon
  /// for a tooltip). Hidden when this column is currently sorted — the sort
  /// arrow takes precedence in that case.
  final Widget? headerTrailing;

  /// Optional column-level text style. Applied via `DefaultTextStyle.merge`
  /// around the cell builder's output, so plain `Text` widgets pick it up.
  ///
  /// Defaults to the row-level style (Medium 14 / 20 line-height / -0.15
  /// letter-spacing / Dark Grey). Override for columns that want different
  /// weight or color — e.g., the Name column wants `FontWeight.w500` + black,
  /// the Email column wants `FontWeight.w400` + black.
  final TextStyle? textStyle;

  /// Builds the cell widget for a given row.
  final Widget Function(BuildContext context, T row) cellBuilder;

  const AppTableColumn({
    required this.key,
    required this.label,
    required this.cellBuilder,
    this.width,
    this.alignment = Alignment.topLeft,
    this.sortable = false,
    this.headerTrailing,
    this.textStyle,
  });
}

/// The design system table.
///
/// **Structured header layout** matching Figma:
/// - Top row: [searchField] on the left + [paginationControls] on the right.
/// - Middle row: [tabs] (table-scoped filter strip).
/// - Then column headers + rows.
///
/// All three header slots are optional — pass only what you need.
///
/// **What it does NOT do:**
/// - No data fetching — caller hands in `rows: List<T>` for the current page.
/// - No filter / search logic — search is a widget slot the caller wires up.
/// - No client-side sorting — sort is a callback to the consumer.
/// - No selection by default.
// Implements: DIARY-DEV-test-instrumentation/A
class AppDataTable<T> extends StatelessWidget {
  final List<AppTableColumn<T>> columns;
  final List<T> rows;
  final String? sortColumnKey;
  final SortDirection? sortDirection;
  final ValueChanged<({String key, SortDirection direction})>? onSort;
  final WidgetBuilder? emptyBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final bool isLoading;
  final Object? error;

  /// Top-left header slot — typically [AppTextField.search].
  final Widget? searchField;

  /// Top-right header slot — typically [AppTablePagination].
  final Widget? paginationControls;

  /// Below-header slot — typically [AppTableTabs].
  final Widget? tabs;

  /// When this predicate returns `true` for a row, the entire row renders with
  /// grey text — used for inactive entries (e.g., deactivated users). Empty-
  /// data cells should be handled per-cell in the column's `cellBuilder`.
  final bool Function(T row)? isRowInactive;

  /// Stable per-row key derivation. When set, each `_DataRow` is keyed by
  /// `rowKey(row)` so Flutter recycles row state by row identity rather
  /// than by position — required for reactive views where the row list
  /// reorders on every `Delta` / sort / reconnect (gallery BUG-6).
  ///
  /// When null, rows are keyless (position-keyed), matching pre-existing
  /// behavior.
  // Implements: DIARY-DEV-test-instrumentation/C
  final Key Function(T row)? rowKey;

  /// Test-harness locator. When set, wraps the table card in a
  /// `Semantics(identifier: ..., container: true, explicitChildNodes: true)`
  /// node so Playwright can scope queries to the table subtree.
  final String? semanticId;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.sortColumnKey,
    this.sortDirection,
    this.onSort,
    this.emptyBuilder,
    this.errorBuilder,
    this.isLoading = false,
    this.error,
    this.searchField,
    this.paginationControls,
    this.tabs,
    this.isRowInactive,
    this.rowKey,
    this.semanticId,
  });

  bool get _hasTopRow => searchField != null || paginationControls != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Auto-align the tabs slot's first tab to the table's 24-px content edge
    // without requiring callers to know the padding constant.
    final Widget? alignedTabs = tabs is AppTableTabs
        ? AppTableTabs(
            tabs: (tabs as AppTableTabs).tabs,
            activeKey: (tabs as AppTableTabs).activeKey,
            onTap: (tabs as AppTableTabs).onTap,
            leadingPadding: SpacingTokens.xxl,
          )
        : tabs;

    // Container (not DecoratedBox) so the child is inset by the border
    // thickness and clipped to the rounded shape. Otherwise the data rows'
    // ColoredBox would paint over the card's left/right borders.
    final card = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Stretch every sibling — top row, tabs, headers, and body — to
        // the card's full inner width. Without this, rows would lay out at
        // their intrinsic widths and dividers would only extend as far as
        // the widest sibling.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasTopRow)
            _TopRow(
              searchField: searchField,
              paginationControls: paginationControls,
            ),
          ?alignedTabs,
          _HeaderRow<T>(
            columns: columns,
            sortColumnKey: sortColumnKey,
            sortDirection: sortDirection,
            onSort: onSort,
          ),
          _Body<T>(
            columns: columns,
            rows: rows,
            isLoading: isLoading,
            error: error,
            emptyBuilder: emptyBuilder,
            errorBuilder: errorBuilder,
            isRowInactive: isRowInactive,
            rowKey: rowKey,
          ),
        ],
      ),
    );

    if (semanticId == null) return card;

    return Semantics(
      identifier: semanticId,
      container: true,
      explicitChildNodes: true,
      child: card,
    );
  }
}

class _TopRow extends StatelessWidget {
  final Widget? searchField;
  final Widget? paginationControls;

  const _TopRow({required this.searchField, required this.paginationControls});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SpacingTokens.xxl,
        SpacingTokens.lg,
        SpacingTokens.xxl,
        SpacingTokens.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (searchField != null) Expanded(child: searchField!),
          if (searchField != null && paginationControls != null)
            SizedBox(width: SpacingTokens.xl),
          ?paginationControls,
        ],
      ),
    );
  }
}

class _HeaderRow<T> extends StatelessWidget {
  final List<AppTableColumn<T>> columns;
  final String? sortColumnKey;
  final SortDirection? sortDirection;
  final ValueChanged<({String key, SortDirection direction})>? onSort;

  const _HeaderRow({
    required this.columns,
    required this.sortColumnKey,
    required this.sortDirection,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final col in columns) _buildHeaderCell(context, theme, col),
          ],
        ),
        _IndentedDivider(theme: theme),
      ],
    );
  }

  Widget _buildHeaderCell(
    BuildContext context,
    ThemeData theme,
    AppTableColumn<T> col,
  ) {
    final isSorted = col.key == sortColumnKey;
    final cell = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SpacingTokens.xxl,
        vertical: SpacingTokens.md,
      ),
      child: Row(
        mainAxisAlignment: _toMainAxis(col.alignment),
        children: [
          Text(
            col.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          // Sort arrow only appears when this column is the active sort
          // target — no placeholder "unsorted" indicator (matches Figma).
          if (isSorted) ...[
            SizedBox(width: SpacingTokens.xs),
            Icon(
              sortDirection == SortDirection.ascending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          ] else if (col.headerTrailing != null) ...[
            SizedBox(width: SpacingTokens.xs),
            col.headerTrailing!,
          ],
        ],
      ),
    );

    final wrapped = col.sortable && onSort != null
        ? InkWell(
            onTap: () {
              final nextDir =
                  (isSorted && sortDirection == SortDirection.ascending)
                  ? SortDirection.descending
                  : SortDirection.ascending;
              onSort!((key: col.key, direction: nextDir));
            },
            child: cell,
          )
        : cell;

    return col.width != null
        ? SizedBox(width: col.width, child: wrapped)
        : Expanded(child: wrapped);
  }

  MainAxisAlignment _toMainAxis(Alignment a) {
    if (a == Alignment.centerRight) return MainAxisAlignment.end;
    if (a == Alignment.center) return MainAxisAlignment.center;
    return MainAxisAlignment.start;
  }
}

class _Body<T> extends StatelessWidget {
  final List<AppTableColumn<T>> columns;
  final List<T> rows;
  final bool isLoading;
  final Object? error;
  final WidgetBuilder? emptyBuilder;
  final Widget Function(BuildContext, Object)? errorBuilder;
  final bool Function(T row)? isRowInactive;
  final Key Function(T row)? rowKey;

  const _Body({
    required this.columns,
    required this.rows,
    required this.isLoading,
    required this.error,
    required this.emptyBuilder,
    required this.errorBuilder,
    required this.isRowInactive,
    required this.rowKey,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return errorBuilder?.call(context, error!) ?? _defaultError(context);
    }
    if (rows.isEmpty && !isLoading) {
      return emptyBuilder?.call(context) ?? _defaultEmpty(context);
    }
    // Force the rows column to fill the available width so dividers + the
    // outer card border align edge-to-edge regardless of intermediate
    // widgets' constraint behavior.
    final theme = Theme.of(context);
    final rowsColumn = SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _DataRow<T>(
              key: rowKey?.call(rows[i]),
              columns: columns,
              row: rows[i],
              inactive: isRowInactive?.call(rows[i]) ?? false,
            ),
            if (i < rows.length - 1) _IndentedDivider(theme: theme),
          ],
        ],
      ),
    );
    if (!isLoading) return rowsColumn;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        rowsColumn,
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black12,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }

  Widget _defaultEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: SpacingTokens.xxxl),
      child: Center(
        child: Text(
          'No results',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _defaultError(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: SpacingTokens.xxxl),
      child: Center(
        child: Text(
          error.toString(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}

class _IndentedDivider extends StatelessWidget {
  final ThemeData theme;
  const _IndentedDivider({required this.theme});

  @override
  Widget build(BuildContext context) {
    // 24-px inset on each side so dividers line up with the table's content
    // indent (search bar / first tab / cell content / row content).
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SpacingTokens.xxl),
      child: ColoredBox(
        color: theme.colorScheme.outlineVariant,
        child: const SizedBox(height: 1, width: double.infinity),
      ),
    );
  }
}

/// Default text style for data row cells.
///
/// Inter Medium 14 / line-height 20 / letter-spacing -0.15. Colors vary by
/// row state:
/// - Active (default): Dark Grey
/// - Inactive: Grey (overrides per-column textStyle's color)
const TextStyle _rowBaseStyle = TextStyle(
  fontWeight: FontWeight.w500,
  fontSize: 14,
  height: 20 / 14,
  letterSpacing: -0.15,
);

class _DataRow<T> extends StatefulWidget {
  final List<AppTableColumn<T>> columns;
  final T row;
  final bool inactive;

  const _DataRow({
    super.key,
    required this.columns,
    required this.row,
    required this.inactive,
  });

  @override
  State<_DataRow<T>> createState() => _DataRowState<T>();
}

class _DataRowState<T> extends State<_DataRow<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = _hovered
        ? theme.colorScheme.surfaceContainerLow
        : theme.colorScheme.surface;

    // Row-level text defaults: Dark Grey for active rows, Grey for inactive.
    // Per-column `textStyle` merges on top of this; for inactive rows the
    // row's color override wins via DefaultTextStyle's inheritance.
    final defaultColor = widget.inactive
        ? theme
              .colorScheme
              .outline // Grey (#A4B9C2)
        : theme.colorScheme.onSurfaceVariant; // Dark Grey (#54636A)

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ColoredBox(
        color: bg,
        child: DefaultTextStyle.merge(
          style: _rowBaseStyle.copyWith(color: defaultColor),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final col in widget.columns)
                _buildCell(context, col, defaultColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    AppTableColumn<T> col,
    Color rowDefaultColor,
  ) {
    Widget child = col.cellBuilder(context, widget.row);

    // Column-level text style overrides the row default (weight, color, etc.)
    // EXCEPT on inactive rows where the row-level grey wins.
    if (col.textStyle != null) {
      final effective = widget.inactive
          ? col.textStyle!.copyWith(color: rowDefaultColor)
          : col.textStyle!;
      child = DefaultTextStyle.merge(style: effective, child: child);
    }

    final cell = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SpacingTokens.xxl,
        vertical: SpacingTokens.md,
      ),
      child: child,
    );
    return col.width != null
        ? SizedBox(width: col.width, child: cell)
        : Expanded(child: cell);
  }
}
