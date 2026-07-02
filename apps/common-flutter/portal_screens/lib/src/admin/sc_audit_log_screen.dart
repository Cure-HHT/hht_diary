import 'dart:convert';

import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

import '../models/audit_entry_view.dart';

/// Study Coordinator Audit Log View — the Coordinator's OWN
/// participant/questionnaire activity, reached from the portal's "Audit Log"
/// nav section when the active role is Study Coordinator.
///
/// Reuses the polished CRA site-audit design (the
/// `Timestamp | User | Participant ID | Action` table with a Participant-ID
/// search), but scoped to a SINGLE actor — the logged-in Coordinator — so the
/// CRA screen's Study-Coordinator selector is not meaningful here and is
/// omitted. The wiring layer hands the full (own-actions, bounded) set; this
/// screen filters (Participant-ID search) and paginates LOCALLY.
///
/// **Snapshot in, callbacks out.**
//
// Implements: DIARY-GUI-audit-log-study-coordinator/A+B
class ScAuditLogScreen extends StatefulWidget {
  const ScAuditLogScreen({
    super.key,
    required this.entries,
    required this.isLoading,
    this.title = 'Audit Logs',
    this.subtitle = 'View system activity and changes.',
    this.siteChips = const <String>[],
    this.errorMessage,
    this.onRefresh,
    this.onRowTap,
    this.pageSize = 8,
  });

  /// Header title.
  final String title;

  /// Header subtitle.
  final String subtitle;

  /// Pre-formatted "001 - Memorial Hospital" labels for the "My Sites" strip
  /// (the Coordinator's assigned sites, resolved upstream). Empty hides it.
  final List<String> siteChips;

  /// Full set of the Coordinator's own activity, reverse-chronological.
  final List<AuditEntryView> entries;

  /// True until the first fetch returns.
  final bool isLoading;

  /// Non-null when the most recent fetch failed.
  final String? errorMessage;

  /// Refetch (the error state's Retry).
  final VoidCallback? onRefresh;

  /// Optional row tap (opens the entry's raw detail). Null keeps rows passive.
  final void Function(AuditEntryView entry)? onRowTap;

  /// Rows per page (Figma default 8).
  final int pageSize;

  @override
  State<ScAuditLogScreen> createState() => _ScAuditLogScreenState();
}

class _ScAuditLogScreenState extends State<ScAuditLogScreen> {
  String _search = '';
  int _page = 1;
  late int _pageSize = widget.pageSize;

  @override
  void didUpdateWidget(covariant ScAuditLogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxPage = _maxPageFor(_filtered().length);
    if (_page > maxPage) _page = maxPage;
  }

  /// Participant id for the row. Prefers the binding-mapped
  /// [AuditEntryView.participantId] (the server stamps `participant_id` on
  /// every row it can attribute to a participant — including questionnaire
  /// events, whose `aggregate_id` is the questionnaire instance, not the
  /// participant). Falls back to the raw payload for safety.
  // Implements: DIARY-GUI-audit-log-study-coordinator/A
  static String participantIdOf(AuditEntryView e) {
    if (e.participantId.isNotEmpty) return e.participantId;
    final pid = e.raw['participant_id'];
    if (pid is String && pid.isNotEmpty) return pid;
    return e.raw['aggregate_type'] == 'participant'
        ? (e.raw['aggregate_id']?.toString() ?? '')
        : '';
  }

  /// Filters the own-actions set by the Participant-ID search box.
  // Implements: DIARY-GUI-audit-log-study-coordinator/B
  List<AuditEntryView> _filtered() {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return widget.entries;
    return <AuditEntryView>[
      for (final e in widget.entries)
        if (participantIdOf(e).toLowerCase().contains(q)) e,
    ];
  }

  int _maxPageFor(int total) => total == 0 ? 1 : ((total - 1) ~/ _pageSize) + 1;

  List<AuditEntryView> _pageSlice(List<AuditEntryView> rows) {
    final start = (_page - 1) * _pageSize;
    if (start >= rows.length) return const <AuditEntryView>[];
    final end = (start + _pageSize).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final pageRows = _pageSlice(filtered);
    return Semantics(
      identifier: 'sc-audit-screen',
      container: true,
      explicitChildNodes: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(title: widget.title, subtitle: widget.subtitle),
            const SizedBox(height: 24),
            // My Sites strip: the Coordinator's assigned sites (Figma), shown
            // above the table. Resolved upstream; hidden when empty.
            // Implements: DIARY-GUI-audit-log-study-coordinator/A
            if (widget.siteChips.isNotEmpty) ...[
              _MySites(chips: widget.siteChips),
              const SizedBox(height: 24),
            ],
            AppDataTable<AuditEntryView>(
              semanticId: 'sc-audit-table',
              rows: pageRows,
              isLoading: widget.isLoading,
              error: widget.errorMessage,
              rowKey: (e) => ValueKey<String>(e.id),
              onRowTap: (e) {
                widget.onRowTap?.call(e);
                _showDetails(context, e);
              },
              searchField: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AppTextField.search(
                  hintText: 'Search by Participant ID...',
                  semanticId: 'sc-audit-search',
                  onChanged: (q) => setState(() {
                    _search = q;
                    _page = 1;
                  }),
                ),
              ),
              paginationControls: AppTablePagination(
                currentPage: _page,
                pageSize: _pageSize,
                totalCount: filtered.length,
                onPageChanged: (p) => setState(() => _page = p),
                onPageSizeChanged: (s) => setState(() {
                  _pageSize = s;
                  _page = 1;
                }),
              ),
              columns: _columns(context),
              errorBuilder: (ctx, _) => _ErrorBlock(onRetry: widget.onRefresh),
              emptyBuilder: (ctx) => Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Text(
                    _search.isNotEmpty
                        ? 'No activity matches your search.'
                        : 'No activity recorded yet.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AppTableColumn<AuditEntryView>> _columns(BuildContext context) {
    final theme = Theme.of(context);
    return [
      AppTableColumn<AuditEntryView>(
        key: 'timestamp',
        label: 'Timestamp',
        width: 200,
        cellBuilder: (_, e) => Text(_formatTimestamp(e.timestamp)),
      ),
      AppTableColumn<AuditEntryView>(
        key: 'user',
        label: 'User',
        cellBuilder: (ctx, e) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e.actorName.isEmpty ? '—' : e.actorName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: -0.3,
              ),
            ),
            if (e.actorEmail.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                e.actorEmail,
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  height: 16 / 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      // Implements: DIARY-GUI-audit-log-study-coordinator/A
      AppTableColumn<AuditEntryView>(
        key: 'participant',
        label: 'Participant ID',
        width: 250,
        cellBuilder: (_, e) {
          final pid = participantIdOf(e);
          return Text(pid.isEmpty ? '—' : pid);
        },
      ),
      AppTableColumn<AuditEntryView>(
        key: 'action',
        label: 'Action',
        cellBuilder: (_, e) => Text(e.activityLabel),
      ),
      AppTableColumn<AuditEntryView>(
        key: 'chevron',
        label: '',
        width: 56,
        alignment: Alignment.center,
        cellBuilder: (ctx, _) => Align(
          alignment: Alignment.centerRight,
          child: Icon(
            Icons.chevron_right,
            size: 20,
            color: Theme.of(ctx).colorScheme.outline,
          ),
        ),
      ),
    ];
  }

  /// Row tap opens the entry's full details (like the audit log's "More
  /// details"): the key fields plus the raw event JSON.
  // Implements: DIARY-GUI-audit-log-common/H
  void _showDetails(BuildContext context, AuditEntryView e) {
    final theme = Theme.of(context);
    final jsonText = const JsonEncoder.withIndent('  ').convert(e.raw);
    final pid = participantIdOf(e);
    showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        size: AppDialogSize.large,
        semanticId: 'sc-audit-details',
        title: e.activityLabel,
        subtitle: _formatTimestamp(e.timestamp),
        body: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow(
                  theme,
                  'User',
                  e.actorName.isEmpty ? '—' : e.actorName,
                ),
                if (e.actorEmail.isNotEmpty)
                  _detailRow(theme, 'Email', e.actorEmail),
                _detailRow(theme, 'Participant ID', pid.isEmpty ? '—' : pid),
                _detailRow(theme, 'Action', e.activityLabel),
                const SizedBox(height: 16),
                Text(
                  'Raw event',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    jsonText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 16 / 12,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.medium,
            label: 'Close',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
          ),
        ),
      ],
    ),
  );
}

/// Figma timestamp format: "Oct 7, 2024, 7:30 AM". Formatted from the stored
/// (UTC) instant directly so the render is deterministic across machines.
String _formatTimestamp(DateTime ts) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final t = ts.toUtc();
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  final mm = t.minute.toString().padLeft(2, '0');
  return '${months[t.month - 1]} ${t.day}, ${t.year}, $hour12:$mm $ampm';
}

/// Title (32 SemiBold) + subtitle (16 Regular, muted).
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          // Figma: Inter SemiBold 32 / line-height 48 / tracking 0.0938.
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 32,
            height: 48 / 32,
            letterSpacing: 0.0938,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          // Figma: Inter Regular 16 / line-height 24 / tracking -0.4629.
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 16,
            height: 24 / 16,
            letterSpacing: -0.4629,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// "My Sites" strip: passive labels of the Coordinator's assigned sites.
/// (Mirrors the Participants screen's My Sites bar so the two render
/// identically.)
class _MySites extends StatelessWidget {
  const _MySites({required this.chips});

  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Sites',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 20 / 14,
              letterSpacing: -0.15,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in chips)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 18 / 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load audit entries.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              AppButton(
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                label: 'Retry',
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
