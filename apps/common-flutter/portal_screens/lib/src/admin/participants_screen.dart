import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

import '../models/participant_row_view.dart';

/// Participants screen — the coordinator's "Participant Summary" table
/// (Figma: SC dashboard) with the My Sites strip above it.
///
/// **Snapshot in, callbacks out.** The wiring layer joins the reactive
/// views into [ParticipantRowView]s; this screen filters (status tabs +
/// participant-id search), sorts, paginates locally, and surfaces every
/// intent as a callback: [onPrimaryAction] for the row's single
/// context-dependent Action button, [onMenuAction] for the overflow
/// lifecycle menu.
class ParticipantsScreen extends StatefulWidget {
  const ParticipantsScreen({
    super.key,
    required this.participants,
    required this.siteChips,
    required this.isLoading,
    required this.onPrimaryAction,
    required this.onMenuAction,
    this.onRowTap,
    this.pageSize = 8,
  });

  /// Snapshot of every participant visible to the viewer.
  final List<ParticipantRowView> participants;

  /// Pre-formatted "001 - Memorial Hospital" labels for the My Sites
  /// strip (the viewer's assigned sites, resolved upstream).
  final List<String> siteChips;

  /// True until the wiring layer's first projection emission.
  final bool isLoading;

  /// The Action-column button was tapped ([primaryActionFor] the row's
  /// status says which action that is).
  final void Function(ParticipantRowView row) onPrimaryAction;

  /// An overflow-menu lifecycle action was chosen.
  final void Function(ParticipantRowView row, ParticipantMenuAction action)
  onMenuAction;

  /// A table row was tapped. The wiring layer decides what (if anything) a
  /// tap does per status — e.g. a linked participant opens the Mobile Linking
  /// Code dialog. Null disables row taps entirely.
  final void Function(ParticipantRowView row)? onRowTap;

  /// Rows per page (Figma default 8).
  final int pageSize;

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  String _search = '';
  ParticipantStatusFilter _filter = ParticipantStatusFilter.all;
  int _page = 1;
  late int _pageSize = widget.pageSize;

  @override
  void didUpdateWidget(covariant ParticipantsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final maxPage = _maxPageFor(_filtered().length);
    if (_page > maxPage) _page = maxPage;
  }

  List<ParticipantRowView> _filtered() {
    final q = _search.trim().toLowerCase();
    final out = <ParticipantRowView>[
      for (final p in widget.participants)
        if (statusMatchesFilter(p.status, _filter) &&
            (q.isEmpty || p.id.toLowerCase().contains(q)))
          p,
    ];
    out.sort((a, b) => a.id.compareTo(b.id));
    return out;
  }

  int _countFor(ParticipantStatusFilter f) =>
      widget.participants.where((p) => statusMatchesFilter(p.status, f)).length;

  int _maxPageFor(int total) => total == 0 ? 1 : ((total - 1) ~/ _pageSize) + 1;

  List<ParticipantRowView> _pageSlice(List<ParticipantRowView> rows) {
    final start = (_page - 1) * _pageSize;
    if (start >= rows.length) return const <ParticipantRowView>[];
    final end = (start + _pageSize).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered();
    return Semantics(
      identifier: 'participants-screen',
      container: true,
      explicitChildNodes: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.siteChips.isNotEmpty) ...[
              _MySites(chips: widget.siteChips),
              const SizedBox(height: 24),
            ],
            Text(
              'Participant Summary',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 24,
                height: 32 / 24,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Overview of participants at your sites',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: -0.15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            AppDataTable<ParticipantRowView>(
              semanticId: 'participants-table',
              columns: _columns(context),
              rows: _pageSlice(filtered),
              isLoading: widget.isLoading,
              rowKey: (p) => ValueKey<String>(p.id),
              onRowTap: widget.onRowTap,
              searchField: SizedBox(
                width: 360,
                child: AppTextField.search(
                  semanticId: 'participants-search',
                  hintText: 'Search by Participant ID...',
                  onChanged: (v) => setState(() {
                    _search = v;
                    _page = 1;
                  }),
                ),
              ),
              paginationControls: AppTablePagination(
                semanticId: 'participants-pagination',
                currentPage: _page,
                pageSize: _pageSize,
                totalCount: filtered.length,
                pageSizeOptions: const [8, 16, 32],
                onPageChanged: (p) => setState(() => _page = p),
                onPageSizeChanged: (size) => setState(() {
                  _pageSize = size;
                  _page = 1;
                }),
              ),
              tabs: AppTableTabs(
                semanticId: 'participants-status-tabs',
                tabs: [
                  for (final f in ParticipantStatusFilter.values)
                    AppTableTab(
                      key: f.key,
                      label: f.label,
                      count: _countFor(f),
                    ),
                ],
                activeKey: _filter.key,
                onTap: (k) => setState(() {
                  _filter = ParticipantStatusFilter.fromKey(k);
                  _page = 1;
                }),
              ),
              isRowInactive: (p) =>
                  p.status == ParticipantRowStatus.disconnected ||
                  p.status == ParticipantRowStatus.notParticipating,
              emptyBuilder: (ctx) => Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Text(
                    _search.isNotEmpty
                        ? 'No participants match "$_search".'
                        : 'No participants in this view.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

  List<AppTableColumn<ParticipantRowView>> _columns(BuildContext context) {
    final theme = Theme.of(context);
    Widget headerInfo(String message) => Tooltip(
      message: message,
      child: Icon(
        Icons.info_outline,
        size: 14,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return [
      AppTableColumn<ParticipantRowView>(
        key: 'participant',
        label: 'Participant',
        width: 220,
        cellBuilder: (ctx, p) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                p.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            if (p.status == ParticipantRowStatus.trialActive) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).extension<AppSemanticColors>()!.statusActive,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            if (p.hasReadyToReview) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Questionnaire ready to review',
                child: Semantics(
                  identifier: 'participant-${p.id}-review-bell',
                  child: Icon(
                    Icons.notifications_active_outlined,
                    size: 16,
                    color: Theme.of(
                      ctx,
                    ).extension<AppSemanticColors>()!.statusAttention,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      AppTableColumn<ParticipantRowView>(
        key: 'site',
        label: 'Site',
        cellBuilder: (_, p) => Text(p.siteName),
      ),
      AppTableColumn<ParticipantRowView>(
        key: 'status',
        label: 'Status',
        headerTrailing: headerInfo(
          'Linking-lifecycle status derived from the participant\'s '
          'event history.',
        ),
        cellBuilder: (_, p) => StatusBadge(
          kind: _badgeKindFor(p.status),
          label: p.status.label,
          semanticId: 'participant-${p.id}-status',
        ),
      ),
      AppTableColumn<ParticipantRowView>(
        key: 'action',
        label: 'Action',
        headerTrailing: headerInfo(
          'The next step for this participant; more lifecycle actions '
          'are in the row menu.',
        ),
        cellBuilder: (ctx, p) =>
            _ActionCell(row: p, onPrimaryAction: widget.onPrimaryAction),
      ),
    ];
  }
}

StatusBadgeKind _badgeKindFor(ParticipantRowStatus s) => switch (s) {
  ParticipantRowStatus.trialActive => StatusBadgeKind.active,
  ParticipantRowStatus.linkedAwaitingStart ||
  ParticipantRowStatus.codePending ||
  ParticipantRowStatus.expired => StatusBadgeKind.pending,
  ParticipantRowStatus.notConnected ||
  ParticipantRowStatus.disconnected ||
  ParticipantRowStatus.notParticipating ||
  ParticipantRowStatus.unknown => StatusBadgeKind.inactive,
};

/// "My Sites" strip: passive labels of the viewer's assigned sites.
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

/// The Action column: one status-driven button + the overflow lifecycle
/// menu (rendered only when the row has menu actions).
class _ActionCell extends StatelessWidget {
  const _ActionCell({required this.row, required this.onPrimaryAction});

  final ParticipantRowView row;
  final void Function(ParticipantRowView) onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final primary = primaryActionFor(row.status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (primary != ParticipantPrimaryAction.none)
          AppButton(
            label: primary.label,
            variant: _isOutline(primary)
                ? AppButtonVariant.secondary
                : AppButtonVariant.primary,
            leadingIcon: _iconFor(primary),
            onPressed: () => onPrimaryAction(row),
            semanticId: 'participant-${row.id}-action',
          ),
      ],
    );
  }

  static bool _isOutline(ParticipantPrimaryAction a) =>
      a == ParticipantPrimaryAction.showLinkingCode ||
      a == ParticipantPrimaryAction.manageQuestionnaires;

  static IconData _iconFor(ParticipantPrimaryAction a) => switch (a) {
    ParticipantPrimaryAction.linkParticipant => Icons.link,
    ParticipantPrimaryAction.showLinkingCode => Icons.visibility_outlined,
    ParticipantPrimaryAction.regenerateCode => Icons.refresh,
    ParticipantPrimaryAction.startTrial => Icons.send_outlined,
    ParticipantPrimaryAction.manageQuestionnaires => Icons.description_outlined,
    ParticipantPrimaryAction.none => Icons.circle,
  };
}
