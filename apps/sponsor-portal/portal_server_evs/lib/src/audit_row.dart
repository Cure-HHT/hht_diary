// Implements: DIARY-DEV-audit-log-read/A — maps a StoredEvent to an audit-trail row
//   surfacing who (initiator), what (entry type), when (timestamp), details (payload + change reason).
// Implements: DIARY-DEV-audit-log-read/B — auditAccessAllowed gates on the audit-view permission.
import 'package:event_sourcing/event_sourcing.dart';

/// Permission name that gates read access to the audit trail.
const String auditViewPermission = 'portal.audit.view';

/// Whether the given permission set grants audit-trail read access.
bool auditAccessAllowed(Iterable<String> permissionNames) =>
    permissionNames.contains(auditViewPermission);

/// Resolves an audit event to the *Administrator* **Action** name shown in the
/// Action column, per the Action Inventory (ACT-USR-* / ACT-ADM-*). Returns
/// null for any event that is NOT an Administrator action — system/automation
/// events (sessions, OTP, EDC sync, the owner's own activation, the
/// session-revoke side-effect of a deactivation). The Administrator Audit Log
/// shows ONLY events with a non-null name here (see [auditEventIsAdminAction]).
///
/// `user_role_scope` covers role AND site assignment/revocation (they share the
/// aggregate + event type and are distinguished only by payload), so it maps to
/// a name that is honest for both rather than asserting one.
// Implements: DIARY-GUI-audit-log-common/F
String? adminActionName(String entryType, String eventType) =>
    switch (entryType) {
      'user_created' => 'Create User Account', // ACT-USR-001
      'user_profile_changed' => 'Edit User Account', // ACT-USR-002
      'user_email_change_requested' => 'Edit User Account', // ACT-USR-002
      'user_deactivated' => 'Deactivate User Account', // ACT-USR-003
      'user_reactivated' => 'Reactivate User Account', // ACT-USR-004
      'user_account_unlocked' => 'Unlock User Account', // ACT-USR-005
      'user_activation_code_issued' => 'Resend Activation Email', // ACT-USR-006
      'user_deleted' => 'Delete Pending User Account', // ACT-USR-009
      'user_role_scope' => switch (eventType) {
          'role_assigned' =>
            'Assign Role or Site to User Account', // ACT-USR-007/008
          'role_unassigned' =>
            'Revoke Role or Site from User Account', // ACT-USR-010/011
          _ => null,
        },
      _ => null,
    };

/// Whether [e] is an Administrator action (vs a system/automation event), used
/// to scope the Administrator Audit Log (`GET /audit?view=admin`) to the
/// Administrator's own actions: a **user-initiated** event ([UserInitiator])
/// whose entry type maps to an Action-Inventory name.
///
/// Requiring a [UserInitiator] is what keeps automation/anonymous events out of
/// the Administrator view even when they share a `user_*` entry type that maps
/// to an Action-Inventory name — e.g. the activation code an account-create
/// flow auto-issues (`user_activation_code_issued`), or the session-revoke
/// side-effect of a deactivation. Those are automation-initiated and would
/// otherwise render as "Automation" rows. Pure system events (sessions, OTP,
/// EDC sync) are already excluded because they have no mapping at all.
///
/// Same spec-gap anchoring as [auditEventMatchesQuery] / [auditEventMatchesSite]:
/// server-side scoping of the read is anchored to DIARY-DEV-audit-log-read
/// rather than minting a new REQ.
// Implements: DIARY-DEV-audit-log-read/A
bool auditEventIsAdminAction(StoredEvent e) =>
    e.initiator is UserInitiator &&
    adminActionName(e.entryType, e.eventType) != null;

/// Resolves the **Participant ID** an audit event pertains to, for the
/// Participant ID column in the *Study Coordinator* / *CRA* Audit Log Views.
///
/// - `participant` aggregate: the aggregate id IS the participant id.
/// - `questionnaire_instance` aggregate: the event's own `participant_id`
///   payload when it carries one (the send event does), else the
///   [participantByInstance] join (the `questionnaire_instance` view maps an
///   instance id -> participant id) so call-back / finalize / unlock events —
///   which key on the instance id and don't repeat the participant — still
///   resolve.
///
/// Returns null for any other aggregate (users, sessions, rave_sync, ...),
/// which have no participant association.
// Implements: DIARY-GUI-audit-log-study-coordinator/A
String? auditRowParticipantId(
  StoredEvent e, [
  Map<String, String> participantByInstance = const <String, String>{},
]) =>
    switch (e.aggregateType) {
      'participant' => e.aggregateId,
      'questionnaire_instance' =>
        (e.data['participant_id'] as String?) ??
            participantByInstance[e.aggregateId],
      _ => null,
    };

/// Maps a [StoredEvent] to a JSON-serialisable audit-trail row capturing
/// who (initiator), what (entry/event/aggregate), when (timestamp), and the
/// details (payload + change reason).
///
/// [nameByEmail] resolves a user's email (the initiator/aggregate identifier)
/// to their display name from `users_index`; the handler builds it once per
/// request. It populates the actor's `name` and, when the aggregate is a
/// `portal_user`, the affected account's `target_name` — so the Audit Log can
/// show names instead of emails (DIARY-GUI-audit-log-common/A).
/// `action_name` is the Action-Inventory name for the Action column (null for
/// non-admin events).
///
/// [participantByInstance] (questionnaire instance id -> participant id,
/// resolved once per request) lets the row carry a `participant_id` for
/// participant & questionnaire events, backing the Participant ID column of
/// the *Study Coordinator* view. Absent for aggregates with no participant.
// Implements: DIARY-GUI-audit-log-common/A+F
// Implements: DIARY-GUI-audit-log-study-coordinator/A
Map<String, Object?> auditRowJson(
  StoredEvent e, {
  Map<String, String> nameByEmail = const <String, String>{},
  Map<String, String> participantByInstance = const <String, String>{},
}) =>
    <String, Object?>{
      'event_id': e.eventId,
      'sequence': e.sequenceNumber,
      'timestamp': e.clientTimestamp.toUtc().toIso8601String(),
      'entry_type': e.entryType,
      'event_type': e.eventType,
      'action_name': adminActionName(e.entryType, e.eventType),
      'aggregate_type': e.aggregateType,
      'aggregate_id': e.aggregateId,
      if (auditRowParticipantId(e, participantByInstance) case final String pid)
        'participant_id': pid,
      if (e.aggregateType == 'portal_user' &&
          nameByEmail[e.aggregateId] != null)
        'target_name': nameByEmail[e.aggregateId],
      'initiator': _initiatorJson(e.initiator, nameByEmail),
      'flow_token': e.flowToken,
      'change_reason': e.metadata['change_reason'],
      'data': e.data,
    };

/// Case-insensitive substring filter backing `GET /audit`'s `q` param.
/// Matches who (the initiator label) and what (the entry type — both the raw
/// id and its space-separated form, so a query typed against the humanized
/// Action column, e.g. "Site Synced", still hits `site_synced_from_edc`).
///
/// NOTE: server-side filtering is a spec gap against DIARY-DEV-audit-log-read
/// (its assertions cover the reverse-chronological read and the permission
/// gate, not filtering); anchored to that REQ rather than minting a new one.
// Implements: DIARY-DEV-audit-log-read/A
bool auditEventMatchesQuery(StoredEvent e, String query) {
  final q = query.toLowerCase();
  final label = switch (e.initiator) {
    UserInitiator(:final userId) => userId,
    AutomationInitiator(:final service) => service,
    AnonymousInitiator() => 'anon',
  };
  return label.toLowerCase().contains(q) ||
      e.entryType.toLowerCase().contains(q) ||
      e.entryType.replaceAll('_', ' ').toLowerCase().contains(q);
}

/// Site filter backing `GET /audit`'s `site` param: an event belongs to a
/// site when the site itself is the aggregate, or when the aggregate is a
/// participant that [participantSite] (the participant_site_index view,
/// resolved once per request) maps to that site. Events on other aggregates
/// (users, sessions, rave_sync, ...) have no site association and never match.
///
/// Same spec-gap anchoring as [auditEventMatchesQuery]: filtering is anchored
/// to DIARY-DEV-audit-log-read rather than minting a new REQ.
// Implements: DIARY-DEV-audit-log-read/A
bool auditEventMatchesSite(
  StoredEvent e,
  String siteId,
  Map<String, String> participantSite,
) =>
    switch (e.aggregateType) {
      'site' => e.aggregateId == siteId,
      'participant' => participantSite[e.aggregateId] == siteId,
      _ => false,
    };

/// Own-activity predicate backing `GET /audit?view=mine` — the *Study
/// Coordinator* Audit Log View, which presents the Coordinator's OWN Actions.
/// A user-initiated event whose initiator is [userId], over the participant /
/// questionnaire / site aggregates a Coordinator acts on (so the row carries a
/// Participant ID and peers' / automation events stay out).
///
/// This enforces the separation-of-duties scope from the Overview/Rationale of
/// DIARY-GUI-audit-log-study-coordinator (which has no dedicated lettered
/// assertion for it): a Coordinator sees only their own audit trail. Like the
/// admin/site/query scoping, the server-side read scope is anchored to
/// DIARY-DEV-audit-log-read rather than minting a new REQ.
// Implements: DIARY-DEV-audit-log-read/A
bool auditEventIsOwnActivity(StoredEvent e, String userId) =>
    e.initiator is UserInitiator &&
    (e.initiator as UserInitiator).userId == userId &&
    const {'participant', 'questionnaire_instance', 'site'}
        .contains(e.aggregateType);

/// Participant filter backing `GET /audit`'s `participant` param — the
/// Participant ID search input of the *Study Coordinator* view. Case-
/// insensitive substring match on the row's participant id (see
/// [auditRowParticipantId]); events with no participant never match.
// Implements: DIARY-GUI-audit-log-study-coordinator/B
bool auditEventMatchesParticipant(
  StoredEvent e,
  String participantQuery,
  Map<String, String> participantByInstance,
) {
  final pid = auditRowParticipantId(e, participantByInstance);
  if (pid == null) return false;
  return pid.toLowerCase().contains(participantQuery.toLowerCase());
}

Map<String, Object?> _initiatorJson(
  Initiator i,
  Map<String, String> nameByEmail,
) =>
    switch (i) {
      // `label` keeps the email (stable identifier + search key); `name` is the
      // human display name when known, so the User column can show the name.
      UserInitiator(:final userId) => {
          'kind': 'user',
          'label': userId,
          if (nameByEmail[userId] != null) 'name': nameByEmail[userId],
        },
      AutomationInitiator(:final service) => {
          'kind': 'automation',
          'label': service,
        },
      AnonymousInitiator() => {'kind': 'anonymous', 'label': 'anon'},
    };
