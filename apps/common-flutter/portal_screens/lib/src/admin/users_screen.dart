import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

import '../models/portal_user_view.dart';
import '../models/user_status_view.dart';
import '../widgets/role_pill.dart';
import 'user_row_actions.dart';

/// User Management screen — the admin's flat-table view of every portal
/// user, with search + status filter + pagination.
///
/// **Snapshot in, callbacks out.** The screen owns no data and never
/// reads transport/projection types. The wiring layer
/// (`portal_ui_evs`) runs `ViewBuilder<UserRow>` on `users_index`,
/// joins it with `user_role_scopes`, maps each row into a
/// [PortalUserView], and hands the whole list here on every emission.
///
/// The row kebab menu (Phase 7) renders when [rowActions] is provided;
/// without it the right-most column keeps the passive ellipsis
/// placeholder so previews/tests without wiring still lay out correctly.
class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.users,
    required this.isLoading,
    required this.canCreate,
    required this.onCreate,
    this.rowActions,
    this.pageSize = 8,
  });

  /// Snapshot of every user in the directory. Filter / sort / paginate
  /// happens locally; the wiring layer never pre-filters for us.
  final List<PortalUserView> users;

  /// True while the wiring layer hasn't received its first `EndOfReplay`
  /// from the projection. Renders an in-table spinner via
  /// `AppDataTable.isLoading`.
  final bool isLoading;

  /// True when the active role holds `portal.user.create`. Drives the
  /// visibility of the "Create User" CTA — `onCreate` must be non-null
  /// for the button to render.
  final bool canCreate;

  /// Fired when the user taps "Create User". The wiring layer opens
  /// the existing create-user dialog and dispatches the action via
  /// `ActionClient`.
  final VoidCallback onCreate;

  /// Row kebab wiring — capability flags + the action callback. Null
  /// renders the disabled placeholder ellipsis instead of a menu.
  final UserRowActionsConfig? rowActions;

  /// Rows per page. Defaults match the Figma's "Viewing 1-8 of N".
  final int pageSize;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

/// Status filter keyed by the AppTableTabs strip.
enum _StatusFilter {
  all('all', 'All users'),
  active('active', 'Active'),
  pending('pending', 'Pending'),
  inactive('inactive', 'Inactive');

  const _StatusFilter(this.key, this.label);
  final String key;
  final String label;

  static _StatusFilter fromKey(String key) =>
      values.firstWhere((f) => f.key == key, orElse: () => _StatusFilter.all);
}

class _UsersScreenState extends State<UsersScreen> {
  String _search = '';
  _StatusFilter _statusFilter = _StatusFilter.all;
  int _page = 1;
  late int _pageSize = widget.pageSize;

  // Single source of truth for the row kebab popovers. Each row owns its
  // own MenuController, but only one menu may be open at a time — opening
  // a second row's menu must close the first (two independent MenuAnchors
  // do not dismiss each other, so without this coordination their
  // popovers stack). No REQ assertion covers this popover behavior; it's
  // a pure presentation-layer interaction fix (CUR-1595).
  MenuController? _openRowMenu;

  /// Closes any previously-open row menu and records [controller] as the
  /// one now open. Purely imperative overlay bookkeeping — no rebuild is
  /// needed (MenuAnchor manages its own popover visibility).
  void _handleRowMenuOpened(MenuController controller) {
    final previous = _openRowMenu;
    if (previous != null && !identical(previous, controller) && previous.isOpen) {
      previous.close();
    }
    _openRowMenu = controller;
  }

  /// Clears the "currently open" reference when the row that closed is the
  /// one we were tracking (an item tap, an outside tap, or our own
  /// coordinator-driven close all route here).
  void _handleRowMenuClosed(MenuController controller) {
    if (identical(_openRowMenu, controller)) _openRowMenu = null;
  }

  @override
  void didUpdateWidget(covariant UsersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the user list shrinks (or we change filters), the current page
    // can fall off the end; clamp back into range on the next build.
    final maxPage = _maxPageFor(_filteredUsers().length);
    if (_page > maxPage) _page = maxPage;
  }

  // ---------------------------------------------------------------------------
  // Filtering / sorting / paging
  // ---------------------------------------------------------------------------

  /// Filters by [_search] (email substring, case-insensitive — Q14a) and
  /// [_statusFilter] (Q13 mapping). Always sorted by email so the table is
  /// stable across rebuilds.
  List<PortalUserView> _filteredUsers() {
    final q = _search.trim().toLowerCase();
    final out = <PortalUserView>[];
    for (final u in widget.users) {
      if (!_matchesFilter(u)) continue;
      if (q.isNotEmpty && !u.email.toLowerCase().contains(q)) continue;
      out.add(u);
    }
    out.sort((a, b) => a.email.compareTo(b.email));
    return out;
  }

  bool _matchesFilter(PortalUserView u) => switch (_statusFilter) {
    _StatusFilter.all => true,
    _StatusFilter.active => u.status == UserStatusView.active,
    _StatusFilter.pending => u.status == UserStatusView.pending,
    // Per Q13 (mirrors the legacy portal-ui): Inactive = revoked only.
    // Locked + unknown fall out of per-status tabs but still count
    // under "All users".
    _StatusFilter.inactive => u.status == UserStatusView.revoked,
  };

  int _maxPageFor(int total) {
    if (total == 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  List<PortalUserView> _pageSlice(List<PortalUserView> rows) {
    final start = (_page - 1) * _pageSize;
    if (start >= rows.length) return const <PortalUserView>[];
    final end = (start + _pageSize) > rows.length
        ? rows.length
        : start + _pageSize;
    return rows.sublist(start, end);
  }

  /// Count of rows matching a given status filter — used for the badge
  /// counts on the filter tabs. Search is intentionally excluded so the
  /// counts reflect the underlying data, not the current query.
  int _countFor(_StatusFilter f) {
    if (f == _StatusFilter.all) return widget.users.length;
    return widget.users.where((u) {
      return switch (f) {
        _StatusFilter.all => true,
        _StatusFilter.active => u.status == UserStatusView.active,
        _StatusFilter.pending => u.status == UserStatusView.pending,
        _StatusFilter.inactive => u.status == UserStatusView.revoked,
      };
    }).length;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredUsers();
    final pageRows = _pageSlice(filtered);

    return SingleChildScrollView(
      // Whole-page scroll, not table-internal scroll. At small page
      // sizes the content fits the viewport and no scrollbar appears;
      // at larger page sizes (e.g. 32 rows per page) the page scrolls
      // as a single unit so the header / search / pagination stay
      // visually attached to the rows they describe.
      padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(canCreate: widget.canCreate, onCreate: widget.onCreate),
          const SizedBox(height: 24),
          AppDataTable<PortalUserView>(
            columns: _columns(context),
            rows: pageRows,
            isLoading: widget.isLoading,
            searchField: SizedBox(
              width: 360,
              child: AppTextField.search(
                semanticId: 'users-search',
                hintText: 'Search by email',
                onChanged: (v) {
                  setState(() {
                    _search = v;
                    _page = 1; // reset to first page on every new query
                  });
                },
              ),
            ),
            paginationControls: AppTablePagination(
              semanticId: 'users-pagination',
              currentPage: _page,
              pageSize: _pageSize,
              totalCount: filtered.length,
              pageSizeOptions: const [8, 16, 32],
              onPageChanged: (p) => setState(() => _page = p),
              onPageSizeChanged: (size) {
                setState(() {
                  _pageSize = size;
                  _page = 1;
                });
              },
            ),
            tabs: AppTableTabs(
              semanticId: 'users-status-tabs',
              tabs: [
                for (final f in _StatusFilter.values)
                  AppTableTab(key: f.key, label: f.label, count: _countFor(f)),
              ],
              activeKey: _statusFilter.key,
              onTap: (k) => setState(() {
                _statusFilter = _StatusFilter.fromKey(k);
                _page = 1;
              }),
            ),
            isRowInactive: (u) => u.status == UserStatusView.revoked,
            emptyBuilder: (ctx) => Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Text(
                  _search.isNotEmpty
                      ? 'No users match "$_search".'
                      : 'No users in this view.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Columns
  // ---------------------------------------------------------------------------

  List<AppTableColumn<PortalUserView>> _columns(BuildContext context) {
    return [
      AppTableColumn<PortalUserView>(
        key: 'name',
        label: 'Name',
        textStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: -0.15,
        ),
        cellBuilder: (_, u) => Text(u.name),
      ),
      AppTableColumn<PortalUserView>(
        key: 'email',
        label: 'Email',
        cellBuilder: (_, u) => Text(u.email),
      ),
      AppTableColumn<PortalUserView>(
        key: 'roles',
        label: 'Roles',
        cellBuilder: (_, u) => _RolesCell(
          roles: u.distinctRoles,
          inactive: u.status == UserStatusView.revoked,
        ),
      ),
      AppTableColumn<PortalUserView>(
        key: 'sites',
        label: 'Sites',
        cellBuilder: (_, u) => _SitesCell(user: u),
      ),
      AppTableColumn<PortalUserView>(
        key: 'status',
        label: 'Status',
        cellBuilder: (_, u) {
          // Session-local invite acknowledgment (Figma: the freshly
          // re-invited row reads "Pending / Invite Sent").
          final inviteSent =
              u.status == UserStatusView.pending &&
              (widget.rowActions?.inviteSentFor(u) ?? false);
          return StatusBadge(
            kind: _statusBadgeKindFor(u.status),
            label: inviteSent ? 'Pending / Invite Sent' : null,
          );
        },
      ),
      AppTableColumn<PortalUserView>(
        key: 'actions',
        label: '',
        // AppDataTable wraps every cell in `Padding(horizontal: 24)`.
        // The IconButton (32 wide) sits at the left edge of that content
        // area by default — so the column width directly controls how
        // far in from the table's right edge the kebab ends up.
        //
        //   icon left = column_right − column_width + 24
        //   icon right = column_right − column_width + 24 + 32
        //
        // Bumping this value shifts the kebab further left. 128 ≈ flush
        // under the chevron glyph in the pagination strip; tune here.
        width: 128,
        cellBuilder: (ctx, u) {
          final config = widget.rowActions;
          if (config == null) {
            return IconButton(
              icon: const Icon(Icons.more_horiz, size: 18),
              tooltip: 'Row actions (coming soon)',
              onPressed: null,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(
                  ctx,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
            );
          }
          return UserRowMenu(
            user: u,
            config: config,
            onMenuOpened: _handleRowMenuOpened,
            onMenuClosed: _handleRowMenuClosed,
          );
        },
      ),
    ];
  }
}

/// Title + subtitle on the left, "Create User" CTA on the right.
class _Header extends StatelessWidget {
  const _Header({required this.canCreate, required this.onCreate});

  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Management',
                // Inter SemiBold 24 / line-height 32 / Black.
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                  height: 32 / 24,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage portal users, roles, site assignments, and '
                'account status.',
                // Inter Regular 14 / line-height 20 / -0.15 / Dark Grey.
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  height: 20 / 14,
                  letterSpacing: -0.15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (canCreate) ...[
          const SizedBox(width: 16),
          AppButton(
            label: 'Create User',
            leadingIcon: Icons.add,
            onPressed: onCreate,
            semanticId: 'users-create',
          ),
        ],
      ],
    );
  }
}

/// Roles column cell — one tinted `RolePill` per distinct role,
/// wrapping to the next line when the cell is narrow. Inactive rows
/// dim the whole cluster so the soft-fill colors visually match the
/// already-greyed row text.
class _RolesCell extends StatelessWidget {
  const _RolesCell({required this.roles, required this.inactive});

  final List<String> roles;

  /// True when the surrounding row is in the inactive lifecycle state
  /// (revoked). The cell wraps in an [Opacity] so every pill — across
  /// every tone — dims uniformly rather than the cell needing to know
  /// per-tone "disabled" colors.
  final bool inactive;

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) {
      return Text(
        '—',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    final pills = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final role in roles)
          // Tinted so the chips read as soft-filled (CRA → light-grey
          // fill + grey border + dark-grey text; Study Coordinator →
          // soft blue; Admin → soft pink), matching the Figma.
          RolePill(systemRole: role, variant: AppBadgeVariant.tinted),
      ],
    );
    return inactive ? Opacity(opacity: 0.5, child: pills) : pills;
  }
}

/// Sites column cell — "N sites assigned" / "All sites" / "No sites"
/// with a Tooltip showing the bound site IDs when applicable.
class _SitesCell extends StatelessWidget {
  const _SitesCell({required this.user});

  final PortalUserView user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (user.hasWildcardScope) {
      return Text('All sites', style: TextStyle(color: muted));
    }
    final sites = user.boundSites;
    if (sites.isEmpty) {
      return Text('No sites', style: TextStyle(color: muted));
    }
    final label = sites.length == 1
        ? '1 site assigned'
        : '${sites.length} sites assigned';
    // Tooltip lists site IDs verbatim (Q15a). When a sites_index
    // projection ever ships human names, the wiring layer can resolve
    // them and we widen the tooltip — for now the IDs are what's
    // available from the row.
    return Tooltip(message: sites.join(', '), child: Text(label));
  }
}

StatusBadgeKind _statusBadgeKindFor(UserStatusView s) => switch (s) {
  UserStatusView.active => StatusBadgeKind.active,
  UserStatusView.pending => StatusBadgeKind.pending,
  UserStatusView.revoked => StatusBadgeKind.inactive,
  // Locked is its own state — render with the at-risk badge so admins
  // can spot it at a glance. It doesn't fall under "Inactive" per Q13;
  // it just doesn't appear in any per-status filter tab.
  UserStatusView.locked => StatusBadgeKind.atRisk,
  UserStatusView.unknown => StatusBadgeKind.inactive,
};
