// Implements: DIARY-PRD-action-inventory/C — site-scoped permissions resolve
//   through a participant->site containment hierarchy so a site-bound role
//   assignment covers participants synced to that site.
import 'package:event_sourcing/event_sourcing.dart';

/// Descriptor for the `participant_site_index` projection the containment
/// resolver reads to answer "what site is participant P at?". The registry
/// only needs the column set to validate the containment reference; the row
/// contents are produced by the production materializer (a later sub-project).
class _ParticipantSiteIndexDescriptor implements ScopeProjectionDescriptor {
  const _ParticipantSiteIndexDescriptor();

  @override
  Set<String> get columns => const <String>{'participant_id', 'site_id'};
}

/// Descriptor for the `user_tier_index` projection the containment resolver
/// reads to answer "what tier is user U assigned to?". The registry only needs
/// the column set to validate the containment reference; the row contents are
/// produced by the production materializer.
// Implements: DIARY-DEV-operator-tier-authz/B
class _UserTierIndexDescriptor implements ScopeProjectionDescriptor {
  const _UserTierIndexDescriptor();

  @override
  Set<String> get columns => const <String>{'user_id', 'tier'};
}

/// The portal's scope-class registry: a top-level `site` class plus a
/// `participant` class contained in `site` via the `participant_site_index`
/// projection. A site-bound role assignment therefore covers participant-
/// scoped permissions for every participant the index maps to that site.
/// Also registers a top-level `tier` class and a `user` class contained in
/// `tier` via the `user_tier_index` projection, enabling operator-tier authz.
ScopeClassRegistry buildPortalScopeRegistry() {
  return ScopeClassRegistry(
    classes: const <ScopeClassSpec>[
      ScopeClassSpec(name: 'site'),
      ScopeClassSpec(
        name: 'participant',
        containedIn: ContainmentReference(
          parentClass: 'site',
          projection: 'participant_site_index',
          keyColumn: 'participant_id',
          parentColumn: 'site_id',
        ),
      ),
      // Implements: DIARY-DEV-operator-tier-authz/B
      ScopeClassSpec(name: 'tier'),
      ScopeClassSpec(
        name: 'user',
        containedIn: ContainmentReference(
          parentClass: 'tier',
          projection: 'user_tier_index',
          keyColumn: 'user_id',
          parentColumn: 'tier',
        ),
      ),
    ],
    projectionLookup: (name) => switch (name) {
      'participant_site_index' => const _ParticipantSiteIndexDescriptor(),
      'user_tier_index' => const _UserTierIndexDescriptor(),
      _ => null,
    },
  );
}
