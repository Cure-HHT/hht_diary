import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

import '../models/audit_entry_view.dart';
import 'audit_log_row.dart';

/// Audit Logs screen — read-only table of system activity, expandable
/// per row to surface the raw audit JSON.
///
/// **Snapshot in, callbacks out.** The wiring layer (`portal_ui_evs`)
/// owns the HTTP fetch against `/audit`, the cred/role-claim handling,
/// and the `PermissionGate` for `portal.audit.view`; here we render a
/// pre-parsed list of [AuditEntryView]s and emit [onRefresh] when the
/// user asks for fresh data.
///
/// The visual chrome (search + pagination + column headers in a
/// rounded card) mirrors `AppDataTable`'s chrome but isn't built on
/// `AppDataTable` itself — the design-system widget doesn't support
/// inline per-row expansion, and the audit log's "open the JSON
/// underneath the row" affordance is core to the Figma. If audit logs
/// ends up being one of several screens that need expansion, we'll
/// promote the pattern to the design system; for now it lives here.
class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({
    super.key,
    required this.entries,
    required this.isLoading,
    required this.onRefresh,
    this.errorMessage,
    this.pageSize = 8,
  });

  /// Snapshot of every audit entry the wiring layer has fetched, in
  /// reverse-chronological order. The screen never re-sorts — it trusts
  /// the wiring layer.
  final List<AuditEntryView> entries;

  /// True while the most recent fetch hasn't returned yet. Drives the
  /// in-table spinner.
  final bool isLoading;

  /// Fired when the user asks for a refresh. Today the only trigger is
  /// the keyboard shortcut / wiring layer's auto-refresh — the Figma
  /// does not show an explicit Refresh button on this screen. Kept on
  /// the API so the wiring layer can wire it up later without a screen
  /// change.
  final VoidCallback onRefresh;

  /// Non-null when the most recent fetch failed. The screen swaps the
  /// row body for an inline error block + Retry button.
  final String? errorMessage;

  /// Rows per page. Defaults match the Figma's "Viewing 1-8 of N".
  final int pageSize;

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  String _search = '';
  int _page = 1;
  late int _pageSize = widget.pageSize;

  @override
  void didUpdateWidget(covariant AuditLogsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxPage = _maxPageFor(_filtered().length);
    if (_page > maxPage) _page = maxPage;
  }

  // ---------------------------------------------------------------------------
  // Filter / page
  // ---------------------------------------------------------------------------

  /// Email-substring filter against the initiator label (the `raw`
  /// payload's `initiator.label`, which is the email-like identifier
  /// the wiring layer stores). Falls back to the formatted actor name +
  /// activity label so the filter behaves intuitively when the row's
  /// initiator is automation (no email).
  List<AuditEntryView> _filtered() {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return widget.entries;
    return widget.entries.where((e) {
      final initiator = e.raw['initiator'];
      final initiatorLabel = initiator is Map
          ? (initiator['label']?.toString() ?? '')
          : '';
      return initiatorLabel.toLowerCase().contains(q) ||
          e.actorName.toLowerCase().contains(q) ||
          e.activityLabel.toLowerCase().contains(q);
    }).toList();
  }

  int _maxPageFor(int total) {
    if (total == 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  List<AuditEntryView> _pageSlice(List<AuditEntryView> rows) {
    final start = (_page - 1) * _pageSize;
    if (start >= rows.length) return const <AuditEntryView>[];
    final end = (start + _pageSize) > rows.length
        ? rows.length
        : start + _pageSize;
    return rows.sublist(start, end);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final pageRows = _pageSlice(filtered);

    // Same column widths used by the header row and every body row so
    // the cells stay vertically aligned. Activity is the only flex
    // column — it consumes the remainder.
    // Chevron column width = 128 to match UsersScreen's actions column,
    // so the chevron glyph and the user-row kebab glyph land at the same
    // x-offset from the table's right edge — keeps the visual rhythm
    // consistent across the two admin tabs.
    const columnWidths = AuditColumnWidths(
      timestamp: 240,
      user: 240,
      chevron: 64,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          const SizedBox(height: 24),
          _AuditTable(
            rows: pageRows,
            isLoading: widget.isLoading,
            errorMessage: widget.errorMessage,
            onRetry: widget.onRefresh,
            columnWidths: columnWidths,
            search: _search,
            onSearchChanged: (v) => setState(() {
              _search = v;
              _page = 1;
            }),
            page: _page,
            pageSize: _pageSize,
            totalCount: filtered.length,
            onPageChanged: (p) => setState(() => _page = p),
            onPageSizeChanged: (size) => setState(() {
              _pageSize = size;
              _page = 1;
            }),
          ),
        ],
      ),
    );
  }
}

/// Title (32 SemiBold) + subtitle (14 Regular, muted) with a trailing
/// `(i)` info icon. The icon is a passive tooltip — the Figma shows no
/// affordance for opening anything from it.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Audit Logs',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 32,
            height: 40 / 32,
            letterSpacing: -0.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View system activity and changes.',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: -0.15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message:
                  'Entries come from the system\'s tamper-evident audit '
                  'log. Reverse chronological — most recent first.',
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The audit table card — same chrome as [AppDataTable] (rounded
/// outlined surface, top row, column headers) but with expandable rows
/// in the body.
class _AuditTable extends StatelessWidget {
  const _AuditTable({
    required this.rows,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.columnWidths,
    required this.search,
    required this.onSearchChanged,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  final List<AuditEntryView> rows;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final AuditColumnWidths columnWidths;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final int page;
  final int pageSize;
  final int totalCount;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopRow(
            search: search,
            onSearchChanged: onSearchChanged,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount,
            onPageChanged: onPageChanged,
            onPageSizeChanged: onPageSizeChanged,
          ),
          _HeaderRow(columnWidths: columnWidths),
          _Divider(theme: theme),
          _Body(
            rows: rows,
            isLoading: isLoading,
            errorMessage: errorMessage,
            onRetry: onRetry,
            search: search,
            columnWidths: columnWidths,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.search,
    required this.onSearchChanged,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  final String search;
  final ValueChanged<String> onSearchChanged;
  final int page;
  final int pageSize;
  final int totalCount;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SizedBox(
              width: 360,
              child: AppTextField.search(
                hintText: 'Search by email',
                onChanged: onSearchChanged,
              ),
            ),
          ),
          SizedBox(width: 20),
          AppTablePagination(
            currentPage: page,
            pageSize: pageSize,
            totalCount: totalCount,
            pageSizeOptions: const [8, 16, 32],
            onPageChanged: onPageChanged,
            onPageSizeChanged: onPageSizeChanged,
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columnWidths});

  final AuditColumnWidths columnWidths;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cellPad = EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    // Inter Medium 14 / 20 / -0.15 / Dark Grey — same header rhythm as
    // AppDataTable (see the design-system polish commit on CUR-1426).
    final labelStyle = TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: -0.15,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        SizedBox(
          width: columnWidths.timestamp,
          child: Padding(
            padding: cellPad,
            child: Text('Timestamp', style: labelStyle),
          ),
        ),
        SizedBox(
          width: columnWidths.user,
          child: Padding(
            padding: cellPad,
            child: Text('User', style: labelStyle),
          ),
        ),
        Expanded(
          child: Padding(
            padding: cellPad,
            child: Text('Activity', style: labelStyle),
          ),
        ),
        SizedBox(
          width: columnWidths.chevron,
          child: Padding(padding: cellPad, child: const SizedBox.shrink()),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.rows,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.search,
    required this.columnWidths,
    required this.theme,
  });

  final List<AuditEntryView> rows;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final String search;
  final AuditColumnWidths columnWidths;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return _ErrorState(
        message: errorMessage!,
        onRetry: onRetry,
        theme: theme,
      );
    }
    if (rows.isEmpty && !isLoading) {
      return _EmptyState(search: search, theme: theme);
    }

    final list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          AuditLogRow(entry: rows[i], columnWidths: columnWidths),
          if (i < rows.length - 1) _Divider(theme: theme),
        ],
      ],
    );

    if (!isLoading) return list;
    // Loading overlay over current rows so the layout doesn't pop when
    // a manual refresh fires against an already-populated list.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        list,
        const Positioned.fill(
          child: ColoredBox(
            color: Colors.black12,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.theme,
  });

  final String message;
  final VoidCallback onRetry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Couldn't load audit entries.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Retry',
            variant: AppButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.search, required this.theme});

  final String search;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Text(
          search.isNotEmpty
              ? 'No audit entries match "$search".'
              : 'No audit entries yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 1-px divider, inset 24 px on each side to match AppDataTable's
/// `_IndentedDivider`. The inset keeps the divider visually anchored to
/// the cell content above/below (which is also 24 px in from the card
/// border) rather than butting against the card's rounded outline.
class _Divider extends StatelessWidget {
  const _Divider({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ColoredBox(
        color: theme.colorScheme.outlineVariant,
        child: const SizedBox(height: 1, width: double.infinity),
      ),
    );
  }
}
