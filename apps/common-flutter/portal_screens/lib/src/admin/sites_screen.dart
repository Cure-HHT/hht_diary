import 'package:diary_design_system/diary_design_system.dart';
import 'package:flutter/material.dart';

/// One row of the Sites table.
@immutable
class SiteRowView {
  const SiteRowView({
    required this.number,
    required this.name,
    required this.id,
    this.active = true,
  });

  /// The study site number ("001") — the primary sort key.
  final String number;

  /// Human site name ("Memorial Hospital").
  final String name;

  /// The EDC site identifier (RAVE Location OID). Shown in place of the
  /// design's Location column: RAVE carries no address data anywhere in
  /// the pipeline, so the OID is the honest third column until it does.
  final String id;

  /// False renders the row greyed with an Inactive badge (a site
  /// deactivated by a later RAVE re-sync).
  final bool active;
}

/// Sites screen — the table of sites this viewer monitors (Figma:
/// "Assigned Sites", the CRA's audit entry point).
///
/// **Snapshot in, callbacks out.** The wiring layer (`portal_ui_evs`)
/// subscribes to `sites_index`, narrows the rows to the viewer's
/// assigned sites, and hands the list here. When [onSiteSelected] is
/// non-null every row is a click target (the row IS the action — it
/// opens that site's audit log); null renders a passive table for
/// viewers without audit access.
class SitesScreen extends StatelessWidget {
  const SitesScreen({
    super.key,
    required this.sites,
    required this.isLoading,
    this.onSiteSelected,
  });

  /// Snapshot of the viewer's sites. Sorting happens here (by site
  /// number) so the table is stable across reactive emissions.
  final List<SiteRowView> sites;

  /// True until the wiring layer's first projection emission.
  final bool isLoading;

  /// Fired when a row is tapped. Null = rows are not clickable.
  final void Function(SiteRowView site)? onSiteSelected;

  @override
  Widget build(BuildContext context) {
    final sorted = <SiteRowView>[...sites]
      ..sort((a, b) => a.number.compareTo(b.number));
    return Semantics(
      identifier: 'sites-screen',
      container: true,
      explicitChildNodes: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            const SizedBox(height: 24),
            AppDataTable<SiteRowView>(
              semanticId: 'sites-table',
              columns: _columns(context),
              rows: sorted,
              isLoading: isLoading,
              rowKey: (s) => ValueKey<String>(s.id),
              isRowInactive: (s) => !s.active,
              onRowTap: onSiteSelected,
              emptyBuilder: (ctx) => Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Text(
                    '(no sites synced yet)',
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

  List<AppTableColumn<SiteRowView>> _columns(BuildContext context) => [
    AppTableColumn<SiteRowView>(
      key: 'number',
      label: 'Site Number',
      width: 240,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: -0.15,
      ),
      cellBuilder: (_, s) => Text(s.number),
    ),
    AppTableColumn<SiteRowView>(
      key: 'name',
      label: 'Site Name',
      cellBuilder: (_, s) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(s.name)),
          if (!s.active) ...[
            const SizedBox(width: 8),
            const StatusBadge(kind: StatusBadgeKind.inactive),
          ],
        ],
      ),
    ),
    AppTableColumn<SiteRowView>(
      key: 'id',
      label: 'Site ID',
      cellBuilder: (_, s) => Text(s.id),
    ),
  ];
}

/// Leading icon + title, subtitle underneath (Figma: Assigned Sites).
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            Icons.domain_outlined,
            size: 24,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assigned Sites',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 24,
                  height: 32 / 24,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'View audit logs and monitor activity for your assigned '
                'sites.',
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
      ],
    );
  }
}
