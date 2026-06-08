// Implements: DIARY-DEV-portal-reaction-server/C — row-level read scope for the
//   reaction server's live subscriptions. Registers the view-to-scope bindings
//   the subscription handler consults to narrow each subscription to the
//   requesting Principal's permitted scope, so a site-bound Study Coordinator
//   receives only the participants at their own Site (not cross-site rows).
import 'package:event_sourcing/event_sourcing.dart';
import 'package:reaction/reaction.dart';

/// The portal's view-to-scope bindings for the reaction server's per-subscription
/// row-level narrowing. Returned to `ReactionHandlers(viewScopeRegistry: ...)`.
///
/// A view registered here is row-scoped: the subscription handler resolves the
/// Principal's scope assignments (via the scope-class registry's containment
/// graph — `buildPortalScopeRegistry`) into the covered aggregate IDs and
/// delivers only those rows. A view NOT registered here stays unscoped at the
/// row level (admin/global views), gated only by its view-level permission.
///
/// `participant_record` is keyed by the participant aggregate id, so its scope
/// class is `participant`. A site-bound assignment (`BoundScope('site', S)`) is
/// an ancestor scope and is expanded to that site's participants through the
/// `participant_site_index` containment; a direct `BoundScope('participant', P)`
/// resolves to `P` itself.
ViewScopeRegistry buildPortalViewScopeRegistry() => ViewScopeRegistry()
  ..register(
    viewName: 'participant_record',
    scopeClass: 'participant',
    aggregateIdResolver: (scope) => scope is BoundScope ? scope.value : null,
  );

// `questionnaire_instance` is deliberately NOT registered here, so it stays
// row-unscoped (gated only by its Action permission portal.questionnaire.view_status
// via portalViewPermissionNamer), like the clinical `diary_entries` view granted
// to the StudyCoordinator.
//
// Why it cannot be participant/site-scoped through this registry: the reaction
// server's row-level narrowing (subscription_handler `_expandAssignments`)
// resolves a Principal's scope assignments into a set of *aggregate IDs* and
// filters view rows by `aggregateId`. `questionnaire_instance` rows are keyed by
// *instanceId* (aggregateId == instanceId), NOT by participant. A `participant`-
// class binding would resolve a site-bound SC's scope into participant aggregate
// IDs, which never match any instanceId-keyed row — so the allowed-set would be
// empty and a site-bound StudyCoordinator would receive ZERO questionnaire rows.
//
// FOLLOW-UP: true per-site row scoping for instanceId-keyed views would require
// a library enhancement to narrow by a non-aggregateId key column (e.g. a row's
// `participant_id`) rather than by aggregateId. Out of scope here.
//
// Implements: DIARY-DEV-portal-reaction-server/C
