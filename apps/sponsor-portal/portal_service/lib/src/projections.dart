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

// Implements: DIARY-DEV-operator-tier-authz/A — user_tier_index maps user_id ->
//   tier (operator|staff) by folding user_tier_changed events (emitted by the
//   user_tier_reactor in a later task). Upsert by user_id. Backs the
//   user-contained-in-tier containment the policy reads.
final TableProjectionSpec userTierIndexSpec = TableProjectionSpec(
  viewName: 'user_tier_index',
  interest: const SubscriptionFilter(
    eventTypes: {'user_tier_changed'},
    aggregateTypes: {'portal_user'},
  ),
  insertEventTypes: const {'user_tier_changed'},
  removeEventTypes: const {},
  rowKey: const CompositeKey(['data.user_id']),
  rowData: const SelectedFields(['user_id', 'tier']),
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

// Implements: DIARY-DEV-linking-code-lifecycle/C — linking_codes folds the
//   linking-code lifecycle (issued->active, used, revoked) into one row per
//   normalized code (the /link lookup + reactor read this). Status is carried
//   on each event's data; TableFold overwrites so the latest event's status wins.
final TableProjectionSpec linkingCodesSpec = TableProjectionSpec(
  viewName: 'linking_codes',
  interest: const SubscriptionFilter(
    eventTypes: {
      'participant_linking_code_issued',
      'participant_linking_code_used',
      'participant_linking_code_revoked',
    },
    aggregateTypes: {'participant'},
  ),
  insertEventTypes: const {
    'participant_linking_code_issued',
    'participant_linking_code_used',
    'participant_linking_code_revoked',
  },
  removeEventTypes: const {},
  rowKey: const CompositeKey(['data.linking_code']),
  rowData: const WholePayload(),
);

// Implements: DIARY-DEV-participant-status-projection/A+B — participant_record folds the
//   participant linking-lifecycle events (excluding enrollment) into one row per
//   participant; the fold stamps the latest event's entryType, from which the client
//   derives linking status. pending->connected requires a diary participant_linked.
// Implements: DIARY-DEV-participant-link-issuance/C — also folds the
//   participant_linking_code_used event (the redemption that transitions the
//   participant to connected), key-wise merging mobile_linking_status and
//   app_uuid forward so the relink gate can read them off the per-participant
//   row. A superseded code's revocation is intentionally NOT folded here: the
//   revoke event carries the old code, so merging it would clobber the
//   participant's current active code. Per-code status lives in the linking_codes
//   view (DIARY-DEV-linking-code-lifecycle/C).
final AggregateProjectionSpec participantRecordSpec = AggregateProjectionSpec(
  viewName: 'participant_record',
  interest: const SubscriptionFilter(
    aggregateTypes: {'participant'},
    eventTypes: {
      'participant_synced_from_edc',
      'participant_linking_code_issued',
      'participant_linking_code_used',
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

// Implements: DIARY-DEV-portal-activation-code-lifecycle/D+E — activation_codes
//   folds the activation-code hash lifecycle into one row per email (the row key
//   is the email, so a fresh mint OVERWRITES the prior row — supersession by
//   fold). Rows carry only the keyed code hash; the ActivationCodeStore
//   validates/consumes against this view, so pending codes survive restarts.
//   Deliberately NOT in portalViewPermissionNamer's map: the fail-closed
//   `view:activation_codes` sentinel keeps it server-internal.
final TableProjectionSpec activationCodesSpec = TableProjectionSpec(
  viewName: 'activation_codes',
  interest: const SubscriptionFilter(
    eventTypes: {'activation_code_minted', 'activation_code_consumed'},
    aggregateTypes: {'portal_user'},
  ),
  insertEventTypes: const {
    'activation_code_minted',
    'activation_code_consumed',
  },
  removeEventTypes: const {},
  rowKey: const CompositeKey(['data.email']),
  rowData: const WholePayload(),
);

// Implements: DIARY-PRD-questionnaire-system/B — questionnaire_instance projects
//   Completion Status per instance. The latest event's entryType is the status
//   driver; lifecycle events fold into the row. One row per instance aggregate.
// Implements: DIARY-BASE-questionnaire-coordinator-workflow/G — a participant
//   submission folds in via questionnaire_submission_received (emitted by the
//   QuestionnaireSubmissionReactor when a diary <id>_survey finalized event
//   arrives for this instance), moving the latest entryType to that value so the
//   derived status becomes Ready to Review.
// Implements: DIARY-BASE-questionnaire-coordinator-workflow/D — Call Back is the
//   spec-authoritative retract: questionnaire_called_back TOMBSTONES the row so
//   the coordinator card resets to Not Sent by absence of an active instance.
//   Call Back is not a separate delete action — it acts directly as a tombstone.
// Implements: DIARY-BASE-questionnaire-finalization/D+E — the finalize event's
//   `cycle` and `end_event` data keys fold onto the row via the AggregateProjectionSpec
//   key-wise merge (no spec change needed). `end_event` distinguishes a terminal
//   Closed (End of Treatment / End of Study) from an after-finalize (Not Sent /
//   Start-Next-Cycle) row; the card reads it to render the combined Closed badge.
// Implements: DIARY-GUI-participant-task-list/J — questionnaire_unlocked folds
//   into the row so the diary sees status='unlocked' and re-presents the task
//   for re-submission.
final AggregateProjectionSpec questionnaireInstanceSpec =
    AggregateProjectionSpec(
      viewName: 'questionnaire_instance',
      interest: const SubscriptionFilter(
        aggregateTypes: {'questionnaire_instance'},
        eventTypes: {
          'questionnaire_assigned',
          'questionnaire_submission_received',
          'questionnaire_locked',
          // CUR-1539: frozen legacy alias of questionnaire_locked — folds
          // identically so pre-rename event logs still project.
          'questionnaire_finalized',
          'questionnaire_unlocked',
          'questionnaire_called_back',
        },
      ),
      tombstoneEventTypes: const {'questionnaire_called_back'},
    );

// Implements: DIARY-DEV-outgoing-intent-correlation/B
//   Participant-facing recall backstop: one row per (participant, instance),
//   inserted by RecallReactor's questionnaire_recall_notice, removed by the
//   device ack (eventType 'finalized' on the same recall aggregate).
final TableProjectionSpec questionnaireRecallNoticeSpec = TableProjectionSpec(
  viewName: 'questionnaire_recall_notice',
  interest: const SubscriptionFilter(
    aggregateTypes: {'questionnaire_recall_notice'},
    eventTypes: {'questionnaire_recall_notice', 'finalized'},
  ),
  insertEventTypes: const {'questionnaire_recall_notice'},
  removeEventTypes: const {'finalized'},
  rowKey: const AggregateIdKey(),
  rowData: const SelectedFields([
    'participant_id',
    'instance_id',
    'study_event',
    'recalled_at',
  ]),
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

// Implements: DIARY-DEV-portal-settings-store/B — one row per setting key; the
//   latest portal_setting_changed event per key overwrites (TableFold), so the
//   current value wins. aggregateId == key; data carries {key, value}.
final TableProjectionSpec portalSettingsSpec = TableProjectionSpec(
  viewName: 'portal_settings',
  interest: const SubscriptionFilter(
    eventTypes: {'portal_setting_changed'},
    aggregateTypes: {'portal_setting'},
  ),
  insertEventTypes: const {'portal_setting_changed'},
  removeEventTypes: const {},
  rowKey: const CompositeKey(['data.key']),
  rowData: const SelectedFields(['key', 'value']),
);

// Implements: DIARY-DEV-sponsor-branding-source/A — sponsor_branding materializes
//   the latest sponsor_branding_configured event per sponsor (metadata + asset
//   manifest). Upsert by sponsorId; the latest configuration overwrites.
final TableProjectionSpec sponsorBrandingSpec = TableProjectionSpec(
  viewName: 'sponsor_branding',
  interest: const SubscriptionFilter(
    eventTypes: {'sponsor_branding_configured'},
    aggregateTypes: {'sponsor_branding'},
  ),
  insertEventTypes: const {'sponsor_branding_configured'},
  removeEventTypes: const {},
  rowKey: const CompositeKey(['data.sponsorId']),
  rowData: const SelectedFields(['sponsorId', 'title', 'assets']),
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
