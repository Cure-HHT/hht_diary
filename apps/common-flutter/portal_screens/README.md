# portal_screens

Composed portal admin/operator screens. Pure presentation layer built on
[`diary_design_system`](../diary_design_system).

## Purpose

The portal app (`portal_ui_evs`) splits into two layers:

- **`portal_ui_evs`** — the wiring layer. Subscribes to event-sourced
  projections via `reaction_widgets`' `ViewBuilder`, dispatches actions
  via `ActionClient`, gates permissions via `PermissionGate`, fetches
  audit data over HTTP. Knows about event_sourcing, firebase, the
  WebSocket transport.
- **`portal_screens`** (this package) — the presentation layer. Pure
  stateless widgets that receive their data as constructor params and
  emit user intent as callbacks. Owns plain Dart value types
  (`PortalUserView`, `AuditEntryView`, `RoleAssignmentView`). No streams,
  no permission gates, no server URLs. Depends only on
  `diary_design_system` + `flutter`.

The split keeps the UI pixel-perfect-testable without spinning up
WebSocket / firebase infra and decouples visual iteration from data
wiring.

## What lives here

| Layer | Files |
| ---   | ---   |
| Models | `lib/src/models/` — value types (`PortalUserView`, etc.) |
| Reusable widgets | `lib/src/widgets/` — portal-wide chrome (`PortalAppBar`, role pills) |
| Admin screens | `lib/src/admin/` — `UsersScreen`, `AuditLogsScreen`, the 5-tab `AdminDashboard` shell |

The package grows additively as each portal screen gets redesigned. See
`docs/superpowers/specs/portal-ui-evs-redesign-plan.md` for the phased
plan.

## Design tenets

- **Snapshots, not streams.** Screens take `List<X>` + `bool isLoading`,
  not `Stream<ViewState<X>>`. The wiring layer translates.
- **Booleans for permissions.** Screens take `bool canCreate` etc.; the
  wiring layer reads the principal and passes them in. No
  `PermissionGate` crosses the package boundary.
- **Callbacks for intent.** All actions are `VoidCallback` /
  `ValueChanged<T>` exposed as constructor params. The wiring layer
  binds them to `ActionClient.submit(...)` or HTTP calls.
- **Own value types.** Plain Dart classes, no `event_sourcing` /
  `reaction_widgets` types in the public API.

## Running tests

```bash
cd apps/common-flutter/portal_screens
flutter pub get
flutter test
```
