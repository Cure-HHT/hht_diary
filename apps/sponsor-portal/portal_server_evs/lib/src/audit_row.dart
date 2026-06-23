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
          'role_assigned' => 'Assign Role or Site to User Account', // ACT-USR-007/008
          'role_unassigned' =>
            'Revoke Role or Site from User Account', // ACT-USR-010/011
          _ => null,
        },
      _ => null,
    };

/// Whether [e] is an Administrator action (vs a system/automation event), used
/// to scope the Administrator Audit Log (`GET /audit?view=admin`) to the
/// Administrator's own actions — events whose entry type maps to an
/// Action-Inventory name. System/automation events (sessions, OTP, EDC sync)
/// have no mapping and are excluded.
///
/// Same spec-gap anchoring as [auditEventMatchesQuery] / [auditEventMatchesSite]:
/// server-side scoping of the read is anchored to DIARY-DEV-audit-log-read
/// rather than minting a new REQ.
// Implements: DIARY-DEV-audit-log-read/A
bool auditEventIsAdminAction(StoredEvent e) =>
    adminActionName(e.entryType, e.eventType) != null;

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
// Implements: DIARY-GUI-audit-log-common/A+F
Map<String, Object?> auditRowJson(
  StoredEvent e, {
  Map<String, String> nameByEmail = const <String, String>{},
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
