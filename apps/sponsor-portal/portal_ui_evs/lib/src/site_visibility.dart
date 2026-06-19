import 'package:event_sourcing/event_sourcing.dart';
import 'package:portal_screens/portal_screens.dart';

/// Narrows the sites table to the viewer's ASSIGNED sites ("Assigned
/// Sites" means what it says): a site-class wildcard (Administrator /
/// SystemOperator) or a total wildcard sees every site; a site-bound
/// role (CRA / StudyCoordinator) sees exactly its bound sites; a role
/// with no site-class coverage at all has no assigned sites.
///
/// CLIENT-SIDE presentation filter only: `sites_index` is row-unscoped
/// at the read layer, so every `portal.site.view` holder still RECEIVES
/// all rows over the wire (server read-scope gap tracked by CUR-1461) —
/// this mirrors the `visibleUserRows` precedent.
List<SiteRowView> visibleSiteRows({
  required List<SiteRowView> sites,
  required List<ScopeAssignment> scopeAssignments,
}) {
  var wildcard = false;
  final bound = <String>{};
  for (final a in scopeAssignments) {
    switch (a.scope) {
      case TotalWildcardScope():
        wildcard = true;
      case ValueWildcardScope(:final class_):
        if (class_ == 'site') wildcard = true;
      case BoundScope(:final class_, :final value):
        if (class_ == 'site') bound.add(value);
    }
  }
  if (wildcard) return sites;
  return <SiteRowView>[
    for (final s in sites)
      if (bound.contains(s.id)) s,
  ];
}
