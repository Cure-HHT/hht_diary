# portal_actions

The portal's concrete `Action` catalog and `[home: portal]` private event types, built on
the `event_sourcing` Action framework (`Action`/`ActionDispatcher`/`Permission`/`EventDraft`).
Realizes `DIARY-PRD-action-inventory`. Cross-wire events the actions also emit come from
`diary_shared_model`; portal-only events live here in `portalPrivateEventTypes`.

## Contents (this foundation)
- `portalPrivateEventTypes` — the `[home: portal]` private event entry types.
- `portalPermissionsByActId` — one `Permission` per action-inventory action.
- `DeactivateUserAccountAction` (ACT-USR-003) — the worked template.
- `buildPortalActionRegistry()` — registers the concrete actions.

## Pattern for the remaining actions (follow-on)
Each action: a `*Input`/`*Result` pair + an `Action<TInput,TResult>` whose `execute` only
builds `EventDraft`s (the dispatcher persists them atomically + stamps `initiator` +
`action_invocation_id`). External side-effects (FCM/email/RAVE) are driven by subscribers on
the emitted events, never inside `execute`. Transition-guard validation that needs current
state is deferred until the read/projection layer (Phase 2).

## Local development
`pubspec_overrides.yaml` (gitignored) points `event_sourcing` at the sibling clone;
`diary_shared_model` is a sibling path dependency.
