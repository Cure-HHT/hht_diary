# portal_ui_evs

Minimal **reactive** Flutter web client for the event-sourced sponsor portal — the
first walking-skeleton vertical slice (CUR-1412). It mounts `reaction_widgets`'
`ReActionScope` over a `RemoteScope` and renders one screen:

- a live `user_role_scopes` list (`ViewBuilder`, updates over WebSocket as
  `role_assigned`/`role_unassigned` events materialize), and
- assign/revoke-site controls (`ActionBuilder` dispatching `ACT-USR-008` /
  `ACT-USR-011`).

It talks to `portal_server_evs` (the `reaction` HTTP/WS shell over `portal_service`'s
SP1/SP2 enforcement core). Auth is a dev credential (`userId:activeRole`); real
Identity Platform auth comes later.

## Run

```bash
./run.sh   # starts portal_server_evs + flutter run -d chrome
```

Connect as **admin-1 (Administrator)** to assign/revoke; connect as **sc-1
(StudyCoordinator)** to see an action denied by the policy.

Requires a machine-local `pubspec_overrides.yaml` (gitignored) pointing at the sibling
`event_sourcing` repo — see the implementation plan.
