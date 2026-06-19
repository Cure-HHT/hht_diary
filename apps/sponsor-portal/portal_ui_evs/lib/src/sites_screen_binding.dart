import 'dart:async';

import 'package:event_sourcing/event_sourcing.dart';
import 'package:flutter/material.dart' hide ViewBuilder;
import 'package:portal_screens/portal_screens.dart';
import 'package:reaction_widgets/reaction_widgets.dart';

import 'audit_log_screen_binding.dart';
import 'site_visibility.dart';

/// Thin reactive wrapper that feeds [SitesScreen] the viewer's sites
/// and routes a row tap to that site's audit log.
///
/// Subscribes to `sites_index` (self-gated on `portal.site.view`),
/// narrows rows to the viewer's assigned sites via [visibleSiteRows],
/// and — when the viewer also holds `portal.audit.view` — makes each
/// row a drill-in that swaps the body for a site-scoped
/// [AuditLogScreenBinding] with a "Back to Sites" header. Viewers
/// without audit access get a passive table.
class SitesScreenBinding extends StatefulWidget {
  const SitesScreenBinding({
    super.key,
    required this.identityCredential,
    required this.serverUrl,
  });

  /// Forwarded to the site-scoped audit binding (it owns the HTTP
  /// fetch against `GET /audit?site=`).
  final String identityCredential;

  /// Portal server base URL, resolved at runtime by the app shell.
  final String serverUrl;

  /// Permission a role must hold to see the Sites tab + table at all.
  static const String viewSitesPermission = 'portal.site.view';

  /// Permission required for the row drill-in (the site audit log).
  static const String viewAuditPermission = 'portal.audit.view';

  @override
  State<SitesScreenBinding> createState() => _SitesScreenBindingState();
}

class _SitesScreenBindingState extends State<SitesScreenBinding> {
  /// Non-null while the site-scoped audit drill-in is showing.
  SiteRowView? _selected;

  StreamSubscription<EffectiveAuthorization?>? _authSub;
  EffectiveAuthorization? _auth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One subscription to the permission snapshot (same source
    // PermissionGate listens to) — drives both the assigned-sites
    // narrowing (scopeAssignments) and the drill-in capability flag.
    if (_authSub != null) return;
    final scope = ReActionScope.of(context);
    _auth = scope.permissionSource.current;
    _authSub = scope.permissionSource.stream.listen((auth) {
      if (!mounted) return;
      setState(() {
        _auth = auth;
        // A role switch can revoke the drill-in target's visibility;
        // fall back to the list rather than showing a stale site.
        _selected = null;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  bool get _canViewAudit =>
      _auth?.rolePermissions.any(
        (p) => p.name == SitesScreenBinding.viewAuditPermission,
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    if (selected != null) {
      return AuditLogScreenBinding(
        identityCredential: widget.identityCredential,
        serverUrl: widget.serverUrl,
        siteId: selected.id,
        title: 'Audit Logs - ${selected.number} ${selected.name}',
        subtitle: 'View all activity for this site',
        backLabel: 'Back to Sites',
        onBack: () => setState(() => _selected = null),
      );
    }
    return PermissionGate(
      permission: SitesScreenBinding.viewSitesPermission,
      fallback: const Center(
        child: Text("You don't have permission to view sites."),
      ),
      child: ViewBuilder<SiteRowView>(
        viewName: 'sites_index',
        mapper: _siteFromRow,
        aggregateIdOf: (s) => s.id,
        builder: (context, state) {
          final rows = switch (state) {
            Loading<SiteRowView>() => const <SiteRowView>[],
            Ready<SiteRowView>(:final rows) => rows,
            Stale<SiteRowView>(:final lastRows) => lastRows,
          };
          final visible = visibleSiteRows(
            sites: rows,
            scopeAssignments: _auth?.scopeAssignments ?? const [],
          );
          return SitesScreen(
            sites: visible,
            isLoading: state is Loading<SiteRowView>,
            onSiteSelected: _canViewAudit
                ? (site) => setState(() => _selected = site)
                : null,
          );
        },
      ),
    );
  }
}

/// One sites_index row (columns: site_id/site_name/site_number/is_active).
SiteRowView _siteFromRow(Map<String, Object?> r) => SiteRowView(
  id: (r['site_id'] as String?) ?? '?',
  name: (r['site_name'] as String?) ?? '?',
  number: (r['site_number'] as String?) ?? '?',
  active: (r['is_active'] as bool?) ?? true,
);
