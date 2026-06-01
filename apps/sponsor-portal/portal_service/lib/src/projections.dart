// Implements: DIARY-DEV-participant-site-index/A — the portal materializes the
//   participant -> site map from RAVE-sourced participant_synced_from_edc events
//   to back the participant-contained-in-site containment resolution. Upsert by
//   participant_id: a re-sync with a new site_id overwrites the row.
import 'package:event_sourcing/event_sourcing.dart';

/// `participant_site_index`: one row per participant carrying its current
/// RAVE-assigned site. Read by the ContainmentResolver when a participant-scoped
/// permission is evaluated. RAVE is authoritative; the portal never writes it
/// except by folding the edge event.
final TableProjectionSpec participantSiteIndexSpec = TableProjectionSpec(
  viewName: 'participant_site_index',
  interest: const SubscriptionFilter(
    eventTypes: {'participant_synced_from_edc'},
    aggregateTypes: {'participant'},
  ),
  insertEventTypes: const {'participant_synced_from_edc'},
  removeEventTypes: const {},
  rowKey: const CompositeKey(['data.participant_id']),
  rowData: const SelectedFields(['participant_id', 'site_id']),
);

// Implements: DIARY-DEV-rave-edc-ingest/A — sites_index materializes the portal's
//   site list from RAVE-sourced site_synced_from_edc events. Re-sync upserts by
//   site_id; deactivation is is_active=false via re-sync (no row removal).
final TableProjectionSpec sitesIndexSpec = TableProjectionSpec(
  viewName: 'sites_index',
  interest: const SubscriptionFilter(
    eventTypes: {'site_synced_from_edc'},
    aggregateTypes: {'site'},
  ),
  insertEventTypes: const {'site_synced_from_edc'},
  removeEventTypes: const {},
  rowKey: const CompositeKey(['data.site_id']),
  rowData: const SelectedFields([
    'site_id',
    'site_name',
    'site_number',
    'is_active',
  ]),
);

// Implements: DIARY-DEV-participant-status-projection/A+B — participant_record folds the
//   participant linking-lifecycle events (excluding enrollment) into one row per
//   participant; the fold stamps the latest event's entryType, from which the client
//   derives linking status. pending->connected requires a diary participant_linked.
final AggregateProjectionSpec participantRecordSpec = AggregateProjectionSpec(
  viewName: 'participant_record',
  interest: const SubscriptionFilter(
    aggregateTypes: {'participant'},
    eventTypes: {
      'participant_synced_from_edc',
      'participant_linking_code_issued',
      'participant_linked',
      'participant_trial_started',
      'participant_disconnected',
      'participant_reconnected',
      'participant_marked_not_participating',
      'participant_reactivated',
    },
  ),
  tombstoneEventTypes: const {},
);

// Implements: DIARY-DEV-user-account-projection/A+B — users_index materializes per-user
//   identity + an explicit account status from the portal_user lifecycle events. Status is
//   carried on status-transition events and preserved across non-status events (key-wise
//   merge only overwrites keys present in the event data); user_deleted tombstones the row.
final AggregateProjectionSpec usersIndexSpec = AggregateProjectionSpec(
  viewName: 'users_index',
  interest: const SubscriptionFilter(
    aggregateTypes: {'portal_user'},
    eventTypes: {
      'user_created',
      'user_profile_changed',
      'user_email_change_requested',
      'user_email_changed',
      'user_deactivated',
      'user_reactivated',
      'user_activated',
      'user_account_unlocked',
      'user_deleted',
    },
  ),
  tombstoneEventTypes: const {'user_deleted'},
);

// Implements: DIARY-DEV-portal-session-token/A+B — sessions_index folds the
//   session lifecycle into one row per session (keyed by the session id).
//   session_started seeds {user_id, started_at} for liveness/cascade lookup;
//   session_terminated tombstones the row so the validator sees only live
//   sessions. The active role is no longer stored here — it is resolved
//   per-request from the credential claim (see SessionTokenValidator).
final AggregateProjectionSpec sessionsIndexSpec = AggregateProjectionSpec(
  viewName: 'sessions_index',
  interest: const SubscriptionFilter(
    aggregateTypes: {'session'},
    eventTypes: {'session_started', 'session_terminated'},
  ),
  tombstoneEventTypes: const {'session_terminated'},
);

// Implements: DIARY-DEV-rave-edc-ingest/C — rave_sync_status folds the rave_sync
//   lockout events into one row; counter-affecting events carry the authoritative
//   consecutive_auth_failures so the merge yields a correct running counter.
final AggregateProjectionSpec raveSyncStatusSpec = AggregateProjectionSpec(
  viewName: 'rave_sync_status',
  interest: const SubscriptionFilter(
    aggregateTypes: {'rave_sync'},
    eventTypes: {
      'edc_sync_succeeded',
      'edc_sync_failed',
      'rave_auth_failed',
      'rave_hard_lockout_triggered',
      'rave_unwedged',
    },
  ),
  tombstoneEventTypes: const {},
);
