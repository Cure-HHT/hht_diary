# DIARY-DEV-view-action-permissions: Read-model subscriptions gate on Action permissions

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-DEV-portal-reaction-server

## Assertions

A. A read-model projection that backs an inventory entity-read *Action* SHALL gate its subscription on that *Action*'s permission (e.g. `participant_record` on `portal.participant.view`, `sites_index` on `portal.site.view`), via a custom `ViewPermissionNamer`, not on a bare `view:<projection>` name.

B. A read-model projection that backs an internal or operational feed SHALL gate its subscription on its `ACT-SEE-*` View *Action* permission (`questionnaire_instance` -> `portal.questionnaire.view_status`, `rave_sync_status` -> `portal.rave.view_sync`, `users_index` and `user_role_scopes` -> `portal.user.view_accounts`, `diary_entries` -> `portal.diary.view_entries`).

C. A projection not registered in the namer SHALL fail closed: its subscription SHALL be denied because no production *Role* holds the fallback name.

## Rationale

Modeling every protected read as an *Action* keeps the *Sponsor* authorization seed in a single vocabulary (*Role* -> *Action* permissions) and satisfies `DIARY-PRD-action-inventory/A` (every grantable permission references an inventory *Action*). It removes the parallel, hand-maintained `view:<projection>` grant table that previously duplicated policy and was the source of the *Administrator* View-*Participant* contradiction.

*End* *Read-model subscriptions gate on Action permissions* | **Hash**: c3069fa4
