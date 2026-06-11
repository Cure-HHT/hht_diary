import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

import '../models/audit_entry_view.dart';
import 'audit_log_row.dart';

/// Audit Logs screen — read-only table of system activity, expandable
/// per row to surface the raw audit JSON.
///
/// **Snapshot in, callbacks out — server-paged.** The wiring layer
/// (`portal_ui_evs`) owns the HTTP fetch against `/audit`, the
/// cred/role-claim handling, and the `PermissionGate` for
/// `portal.audit.view`; here we render the CURRENT PAGE of pre-parsed
/// [AuditEntryView]s and surface every navigation intent as a callback:
/// [onPageChanged] / [onPageSizeChanged] when the user flips pages,
/// [onSearchChanged] when the search text settles, [onRefresh] for a
/// refetch. The screen holds no paging or filtering state of its own —
/// [page], [pageSize], [totalCount] and [searchQuery] are inputs, so
/// the pagination header reflects the full server-side log, not just
/// the rows in hand. Search is evaluated server-side over the whole
/// log; the screen merely reports the query.
///
/// The visual chrome (search + pagination + column headers in a
/// rounded card) mirrors `AppDataTable`'s chrome but isn't built on
/// `AppDataTable` itself — the design-system widget doesn't support
/// inline per-row expansion, and the audit log's "open the JSON
/// underneath the row" affordance is core to the Figma. If audit logs
/// ends up being one of several screens that need expansion, we'll
/// promote the pattern to the design system; for now it lives here.
class AuditLogsScreen extends StatelessWidget {
  const AuditLogsScreen({
    super.key,
    required this.entries,
    required this.isLoading,
    required this.onRefresh,
    this.errorMessage,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.searchQuery = '',
    required this.onSearchChanged,
    this.title = 'Audit Logs',
    this.subtitle = 'View system activity and changes.',
    this.onBack,
    this.backLabel = 'Back to Sites',
  });

  /// The current page of audit entries, in reverse-chronological
  /// order. The screen never re-sorts or re-slices — it trusts the
  /// wiring layer.
  final List<AuditEntryView> entries;

  /// True while the most recent fetch hasn't returned yet. Drives the
  /// in-table spinner.
  final bool isLoading;

  /// Fired when the user asks for a refetch of the current page (e.g.
  /// the error state's Retry button).
  final VoidCallback onRefresh;

  /// Non-null when the most recent fetch failed. The screen swaps the
  /// row body for an inline error block + Retry button.
  final String? errorMessage;

  /// 1-based page the wiring layer most recently fetched.
  final int page;

  /// Rows per page. The Figma's default is 8.
  final int pageSize;

  /// True size of the audit log on the server (or of the server-side
  /// match set while [searchQuery] is non-empty) — NOT the length of
  /// [entries]. Drives the honest "Viewing X-Y of N" header.
  final int totalCount;

  /// User flipped to a different (1-based) page.
  final ValueChanged<int> onPageChanged;

  /// User picked a different rows-per-page size.
  final ValueChanged<int> onPageSizeChanged;

  /// The search query the current [entries] were fetched under. Only
  /// used for the empty-state copy; the text field manages its own
  /// edit state.
  final String searchQuery;

  /// Search text settled (the field debounces internally). The wiring
  /// layer re-fetches page 1 under the new query.
  final ValueChanged<String> onSearchChanged;

  /// Header title. The default is the top-level Audit Logs tab; a
  /// scoped instance (the Sites drill-in) overrides it, e.g.
  /// "Audit Logs - 001 Memorial Hospital".
  final String title;

  /// Header subtitle. The info tooltip renders only with the default
  /// subtitle (the scoped drill-in has no tooltip in the design).
  final String subtitle;

  /// When non-null, a back link ([backLabel], leading arrow) renders
  /// before the header block and fires this on tap.
  final VoidCallback? onBack;

  /// Label for the [onBack] link.
  final String backLabel;

  @override
  Widget build(BuildContext context) {
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
          _Header(
            title: title,
            subtitle: subtitle,
            onBack: onBack,
            backLabel: backLabel,
          ),
          const SizedBox(height: 24),
          _AuditTable(
            rows: entries,
            isLoading: isLoading,
            errorMessage: errorMessage,
            onRetry: onRefresh,
            columnWidths: columnWidths,
            search: searchQuery,
            onSearchChanged: onSearchChanged,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount,
            onPageChanged: onPageChanged,
            onPageSizeChanged: onPageSizeChanged,
          ),
        ],
      ),
    );
  }
}

/// Title (32 SemiBold) + subtitle (14 Regular, muted) with a trailing
/// `(i)` info icon. The icon is a passive tooltip — the Figma shows no
/// affordance for opening anything from it. With [onBack] set (the
/// Sites drill-in), a back link leads the block and the tooltip is
/// omitted.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.backLabel,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
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
            Flexible(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onBack == null) ...[
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
          ],
        ),
      ],
    );
    if (onBack == null) return headerBlock;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          identifier: 'audit-back',
          button: true,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(backLabel),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 40,
            child: VerticalDivider(
              width: 1,
              color: theme.colorScheme.outlineVariant,
            ),
          ),
        ),
        Expanded(child: headerBlock),
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
                semanticId: 'audit-search',
                // Server-side search over the ENTIRE audit log (initiator
                // email / action name), not just the loaded page.
                hintText: 'Search by email or action',
                onChanged: onSearchChanged,
              ),
            ),
          ),
          SizedBox(width: 20),
          AppTablePagination(
            semanticId: 'audit-pagination',
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
