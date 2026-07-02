# portal_actions

The portal's concrete `Action` catalog and `[home: portal]` private event types, built on
the `event_sourcing` Action framework (`Action`/`ActionDispatcher`/`Permission`/`EventDraft`).
Realizes `DIARY-PRD-action-inventory`. Cross-wire events the actions also emit come from
`diary_shared_model`; portal-only events live here in `portalPrivateEventTypes`.

## Contents — Phase 1 (full catalog)

### Infrastructure
- `portalPrivateEventTypes` — the `[home: portal]` private event entry types.
- `portalPermissionsByActId` — one `Permission` per action-inventory action (23 total).
- `buildPortalActionRegistry()` — builds and returns an `ActionRegistry` with all 23 actions.
- `FlowTokenMinter` / `SerialFlowTokenMinter` — audit-scannable serial tokens injected into
  state-changing actions; each token is unique per `execute` call and appears in emitted events.
  Per-aggregate stream prefixes: participant actions use `PAT`, questionnaire actions use `QST`,
  user-account actions use `USR` (e.g. `PAT000001`, `QST000001`, `USR000001`).

### Participant actions (7) — site-scoped, `lib/src/actions/participant/`

| ACT id      | Class                          | Events emitted                                                          |
|-------------|-------------------------------|-------------------------------------------------------------------------|
| ACT-PAT-001 | `LinkParticipantAction`        | `participant_linking_code_issued`                                       |
| ACT-PAT-002 | `StartTrialAction`             | `participant_trial_started`                                             |
| ACT-PAT-003 | `DisconnectParticipantAction`  | `participant_disconnected`                                              |
| ACT-PAT-004 | `ReconnectParticipantAction`   | `participant_linking_code_issued`, `participant_reconnected`            |
| ACT-PAT-005 | `MarkNotParticipatingAction`   | `participant_marked_not_participating`                                  |
| ACT-PAT-006 | `ReactivateParticipantAction`  | `participant_reactivated`, `participant_linking_code_issued`            |
| ACT-PAT-007 | `ViewParticipantAction`        | _(none — read gate)_                                                    |

### Questionnaire actions (4) — site-scoped, `lib/src/actions/questionnaire/`

| ACT id      | Class                           | Events emitted              |
|-------------|--------------------------------|-----------------------------|
| ACT-QST-001 | `SendQuestionnaireAction`       | `questionnaire_assigned`    |
| ACT-QST-002 | `CallBackQuestionnaireAction`   | `questionnaire_called_back` |
| ACT-QST-003 | `LockQuestionnaireAction`       | `questionnaire_locked`      |
| ACT-QST-004 | `UnlockQuestionnaireAction`     | `questionnaire_unlocked`    |

### User-account actions (11) — unscoped, `lib/src/actions/user_account/` (+ root)

| ACT id      | Class                           | Events emitted                                                              |
|-------------|--------------------------------|-----------------------------------------------------------------------------|
| ACT-USR-001 | `CreateUserAccountAction`       | `user_created`, `user_activation_code_issued`                               |
| ACT-USR-002 | `EditUserAccountAction`         | `user_profile_changed` and/or `user_email_change_requested`                 |
| ACT-USR-003 | `DeactivateUserAccountAction`   | `user_deactivated`, `user_sessions_revoked`                                 |
| ACT-USR-004 | `ReactivateUserAccountAction`   | `user_reactivated`, `user_activation_code_issued`                           |
| ACT-USR-005 | `UnlockUserAccountAction`       | `user_account_unlocked`                                                     |
| ACT-USR-006 | `ResendActivationEmailAction`   | `user_activation_code_issued`                                               |
| ACT-USR-007 | `AssignRoleAction`              | `role_assigned` (one (user, role, scope) tuple)                             |
| ACT-USR-008 | `AssignSiteAction`              | `role_assigned` (scope = `BoundScope('site', X)`)                           |
| ACT-USR-009 | `DeletePendingUserAction`       | `user_deleted`                                                              |
| ACT-USR-010 | `RevokeRoleAction`              | `role_unassigned` (one (user, role, scope) tuple)                          |
| ACT-USR-011 | `RevokeSiteAction`              | `role_unassigned` (scope = `BoundScope('site', X)`)                        |

### View actions (3) — unscoped, zero-event read gates, `lib/src/actions/views/`

| ACT id      | Class                       | Events emitted         |
|-------------|----------------------------|------------------------|
| ACT-SIT-001 | `ViewSitesAction`           | _(none — read gate)_   |
| ACT-AUD-001 | `ViewAuditLogAction`        | _(none — read gate)_   |
| ACT-ADM-001 | `ViewAdminSettingsAction`   | _(none — read gate)_   |

## Action pattern
Each action: a `*Input`/`*Result` pair + an `Action<TInput,TResult>` whose `execute` only
builds `EventDraft`s (the dispatcher persists them atomically + stamps `initiator` +
`action_invocation_id`). External side-effects (FCM/email/RAVE) are driven by subscribers on
the emitted events, never inside `execute`. Transition-guard validation that needs current
state is deferred until the read/projection layer (Phase 2).

## Phase 2 deferrals
- `notification_sent` / `email_sent` event subscribers (FCM + email side-effects).
- `auditor_export_recorded` — export variant of `ViewAuditLogAction`.
- Authoritative `before`-state reads in `validate` (requires read/projection layer).
- `TableBackedAuthorizationPolicy` + `ScopeClassRegistry` + `ActionDispatcher` wiring.
- Persistent-sequence `FlowTokenMinter` (replaces in-memory `SerialFlowTokenMinter`).

## Local development
`pubspec_overrides.yaml` (gitignored) points `event_sourcing` at the sibling clone;
`diary_shared_model` is a sibling path dependency.
