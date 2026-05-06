# Action Permissions / Audited Actions Demo App — Design

**Date**: 2026-05-06
**Audience**: dev
**Ticket**: CUR-1192 (audited_actions library) + CUR-1170 context (the demo informs portal cutover requirements)
**Scope**: Reference / example app at `apps/common-dart/action_permissions/example/`. Library code under `apps/common-dart/audited_actions/` and `apps/common-dart/action_permissions/` is consumed unmodified.
**Refines**: none
**Satisfies**: REQ-d00115..d00127 (verifies, does not extend)
**Status**: Draft

## 1. Purpose

`event_sourcing_datastore` shipped with a Linux-desktop dual-pane Flutter demo that exercises every public surface of the storage primitive. The demo found and shaped API decisions (lifecycle protocols, wedge-aware fillBatch, read-side gaps) that pure library-shape thinking missed. The same pattern applies one layer up: `audited_actions` (the dispatch pipeline) and `action_permissions` (the role-permission matrix) form a tightly coupled pair where the matrix-materializer-runs-in-transaction-with-grants story is the kind of integration concern unit tests cannot stress-test.

This demo is the cheapest place to find design mistakes before CUR-1170 (portal cutover) consumes the libraries area-by-area. It validates the dispatcher pipeline, denial-event shape, idempotency policy semantics, scope-class enforcement, and the matrix-as-event-log pattern under realistic client-server conditions.

## 2. Scope

**In scope:**

- A two-process reference application: a Dart `shelf` HTTP server (`bin/server.dart`) hosting the dispatcher, event store, matrix, and user directory; and a Flutter Linux-desktop client connecting over `localhost`.
- Seven concrete `Action` implementations covering all three `ScopeClass` values, all three `Idempotency` policies, multi-role permissions, single-role permissions, and an Anon-allowed action.
- A `UserDirectory` mapping client-asserted `userId` to server-derived `Principal`, seeded from YAML and event-sourced via a `user_provisioned` event type plus a `UserDirectoryMaterializer`.
- A YAML-seeded role-permission matrix consumed by `action_permissions`'s `EventSeedApplier` and projected by `RolePermissionGrantsMaterializer`.
- An admin-side `ProvisionUserAction` demonstrating the dispatcher pipeline against a system-admin permission and exercising materializer composition (matrix and directory in one server).
- Integration tests scripted against every README walkthrough.
- A poll-based `/_demo/inspect` endpoint hidden behind a `DemoStateProjection` interface, swappable to `watchEvents` / `watchEntry` (per Phase 4.12 reactive read layer) without architectural change.

**Out of scope:**

- Authentication. The client asserts `userId` in each request body; the server takes the assertion at face value. Real consumers wire auth at the `shelf` middleware layer in front of `dispatcher.dispatch`.
- Resource-level ownership (alice-vs-bob). The demo's principals are role-as-identity; no per-resource owner field on any aggregate.
- Reactive view-change notifications (cross-process push or intra-process Stream subscriptions). Server-side data delivery is HTTP polling at 1 Hz; both upgrades land cleanly when CUR-1154 Phase 4.12 ships.
- Failure-injection knobs for atomic rollback demonstrations. The `events.transaction` rollback contract is verified by integration tests, not by a live walkthrough.
- TLS, rate limiting, CORS, payload size limits — `shelf` middleware concerns, not library validation.
- Synthetic-burst load generators. Existing library tests cover throughput under stress.

## 3. Architecture

### 3.1 Process layout

```text
+---------------------------------------------------------------+
|  Flutter Linux Desktop App  (single MaterialApp)              |
|                                                               |
|  +----------------------+   +----------------------------+    |
|  |  CLIENT pane         |   |  SERVER INSPECTOR pane     |    |
|  |                      |   |  (polls GET /_demo/inspect |    |
|  |  - userId selector   |   |   ~1Hz, displays only)     |    |
|  |  - hacker toggle     |   |                            |    |
|  |  - action buttons    |   |  - Event log (live)        |    |
|  |    (gated by         |   |  - Matrix view             |    |
|  |     PermissionSnapsh)|   |  - Idempotency store       |    |
|  |  - request history   |   |  - Last dispatch trace     |    |
|  |                      |   |    (10-stage pipeline)     |    |
|  +----------+-----------+   +-------------+--------------+    |
|             |                             |                   |
+-------------+-----------------------------+-------------------+
              |                             |
              | HTTP (shelf)                | HTTP (shelf)
              | localhost:8080              | localhost:8080
              v                             v
+---------------------------------------------------------------+
|  bin/server.dart  (Dart shelf HTTP server)                    |
|                                                               |
|  Routes:                                                      |
|    GET  /healthz         -> 200 once bootstrap completes      |
|    POST /session/start   -> {principal, snapshot}             |
|    POST /dispatch        -> DispatchResult                    |
|    GET  /_demo/inspect   -> server-state snapshot             |
|    GET  /_demo/audit     -> event log (audit.read.all)        |
|    POST /_demo/reset     -> wipe + reseed                     |
|                                                               |
|  Bootstrap (boot order):                                      |
|    1. open sembast db                                         |
|    2. EventStore + StorageBackend                             |
|    3. RolePermissionGrantsMaterializer registered             |
|    4. UserDirectoryMaterializer registered                    |
|    5. EventSeedApplier(permissions.yaml) -> appends grants    |
|    6. UserDirectorySeedApplier(users.yaml) -> appends users   |
|    7. ActionRegistry + 7 demo actions registered              |
|    8. AuthorizationPolicy = TableBackedAuthorizationPolicy    |
|    9. ActionDispatcher composed                               |
|   10. shelf.serve(routes, 'localhost', 8080)                  |
+---------------------------------------------------------------+
```

### 3.2 File layout

```text
apps/common-dart/action_permissions/example/
  bin/
    server.dart                # shelf entry; the trusted process
  lib/
    client/                    # Flutter UI (untrusted side)
      main.dart, app.dart, client_pane.dart,
      server_inspector_pane.dart, userid_selector.dart,
      action_buttons.dart, request_history.dart
    server/                    # bin/ helpers (host-side, not library)
      user_directory.dart      # in-memory directory + materializer
      action_catalog.dart      # 7 demo actions
      demo_routes.dart         # shelf route handlers
      inspect_snapshot.dart    # serializes server state for /_demo/inspect
      demo_state_projection.dart  # poll-vs-reactive seam
    shared/
      wire_types.dart          # DispatchRequest, DispatchResponse, etc.
  tool/
    users.yaml                 # admin-user, green-user-1/2, blue-user
    permissions.yaml           # role -> permissions matrix seed
    run_demo.sh                # spawns server in background, flutter run
    stop_demo.sh               # tear-down companion
  test/                        # unit tests (no shelf, no flutter)
  integration_test/            # end-to-end tests; spawn server subprocess
  pubspec.yaml
  README.md
```

### 3.3 Wire shapes

`lib/shared/wire_types.dart` defines the JSON envelopes both processes import. If a shape drifts, the compiler catches it.

```dart
class DispatchRequest {
  final String actionName;
  final Map<String, Object?> rawInput;
  final String? idempotencyKey;
  final String? userId;
  // toJson / fromJson / hash code / equality
}

sealed class DispatchResponse {}

final class DispatchResponseSuccess extends DispatchResponse {
  final String actionInvocationId;
  final List<String> emittedEventIds;
  final Map<String, Object?> result;
}

final class DispatchResponseDenied extends DispatchResponse {
  final String denialKind;     // unknown_action | parse_denied | validation_denied | authorization_denied | execution_failed
  final String actionInvocationId;
  final String errorClass;
  final String errorMessageSanitized;
  final String? permissionDenied;
  final String? requestedName;
}

final class DispatchResponseIdempotencyHit extends DispatchResponse {
  final String actionInvocationId;
  final List<String> priorEventIds;
  final Map<String, Object?> priorResult;
}

class SessionStartRequest { final String? userId; }
class SessionStartResponse { final Principal principal; final PermissionSnapshot snapshot; }

class InspectSnapshot {
  final List<StoredEventSummary> events;
  final List<MatrixGrant> matrixGrants;
  final List<UserDirectoryEntry> directory;
  final List<IdempotencyEntrySummary> idempotency;
  final DispatchTrace? lastDispatchTrace;
}
```

### 3.4 Identity-assertion model

The client asserts a `userId` in every request body. The server resolves `userId → Principal` via `UserDirectory`. There is no auth handshake.

| Client asserts `userId` | Server resolves to Principal |
| --- | --- |
| `admin-user` | `{role: Admin, userId: 'admin-user', activeSite: null}` |
| `green-user-1` | `{role: GreenTeam, userId: 'green-user-1', activeSite: 'green-workspace'}` |
| `green-user-2` | `{role: GreenTeam, userId: 'green-user-2', activeSite: 'green-workspace'}` |
| `blue-user` | `{role: BlueTeam, userId: 'blue-user', activeSite: 'blue-workspace'}` |
| anything unrecognized or absent | `{role: Anon, userId: null, activeSite: null}` |

Two GreenTeam users with the same role/site but distinct userIds force the matrix and idempotency-store keying to honor the role/identity decoupling. A bug that conflated `userId` with `role` (or that mis-keyed the store on `(action, key)` instead of `(action, principal, key)`) shows up immediately in the cross-user same-key walkthrough.

### 3.5 Trust boundary and hacker mode

The client UI carries two trust controls:

- **userId selector** (always visible). Sets the asserted identity for subsequent requests. The user has no idea what role they will be assigned until the server returns a `PermissionSnapshot` from `POST /session/start`.
- **Hacker mode toggle** (default off). When off, action buttons are gated by the in-memory snapshot — buttons whose required permissions the snapshot does not list are disabled. When on, all buttons are enabled regardless of snapshot. The principal is unchanged.

The trust-model lesson is direct: lifting the client's UI gates does not lift the server's gates. Click "Edit Blue Note" as `green-user-1` with hacker mode on; the request reaches the server, the matrix denies on `notGranted`, an `authorization_denied` event flows into the unified log, and the request-history entry shows the denial. Selecting `admin-user` and clicking any write action results in the same denial — Admin holds zero domain-data writes.

### 3.6 Request flow

A typical dispatch:

```text
client                                  server
  |                                       |
  |--- POST /dispatch ------------------->|
  |    {actionName, rawInput,             |
  |     idempotencyKey?, userId?}         |
  |                                       |
  |                              userDirectory.resolve(userId)
  |                                  -> Principal
  |                                       |
  |                              ActionContext { principal, security }
  |                                       |
  |                              dispatcher.dispatch(
  |                                actionName, rawInput, ctx,
  |                                idempotencyKey: ...)
  |                                       |
  |                              [10-stage pipeline; emits events
  |                               via events.transaction]
  |                                       |
  |<--- DispatchResponse -----------------|
  |     {success | denied | idempotencyHit}
```

The 10-stage pipeline is unchanged from REQ-d00117. Demo wiring contributes only the route handler (`POST /dispatch`), the wire-type marshalling, and the user-directory resolution before pipeline entry.

### 3.7 Server-state delivery to the client

`GET /_demo/inspect` returns an `InspectSnapshot`. The Flutter inspector pane polls this endpoint at 1 Hz, displaying the freshest event log, matrix view, idempotency store, directory, and last-dispatch trace. The implementation lives behind `DemoStateProjection`:

```dart
abstract class DemoStateProjection {
  Future<InspectSnapshot> snapshot();
}

class PollingDemoStateProjection implements DemoStateProjection {
  // current impl: query StorageBackend on each call
}

class ReactiveDemoStateProjection implements DemoStateProjection {
  // future impl after Phase 4.12: subscribe to watchEvents / watchEntry
  // / watchFifo and maintain a cached InspectSnapshot updated on each
  // emission. snapshot() returns the cache.
}
```

When CUR-1154 Phase 4.12 lands, the implementation swap is local. The HTTP transport stays plain GET poll; an SSE upgrade is a follow-on change orthogonal to this design.

### 3.8 Bootstrap and persistence

The server uses sembast on disk by default (`<applicationSupportDirectory>/action_permissions_demo/demo.db`). An `--ephemeral` flag swaps to sembast in-memory for integration tests. On boot, `EventSeedApplier` and `UserDirectorySeedApplier` run their diff logic against the current materialized views and emit `PermissionGranted` / `PermissionRevoked` and `user_provisioned` events for any seed entries not already represented. Subsequent boots find the views already populated from prior-session events; the seed appliers diff to no-ops.

`POST /_demo/reset` wipes the db and re-runs both seed appliers from a clean state, used between repeated demo runs without restart.

## 4. Catalog

### 4.1 Roles

| Role | userId(s) | activeSite |
| --- | --- | --- |
| `Admin` | `admin-user` | `null` |
| `GreenTeam` | `green-user-1`, `green-user-2` | `green-workspace` |
| `BlueTeam` | `blue-user` | `blue-workspace` |
| `Anon` | `null` | `null` |

### 4.2 Permissions

Each permission's `ScopeClass` is fixed in code. The matrix only chooses which roles hold it.

| Permission name | ScopeClass | Idempotency on actions using it | Held by |
| --- | --- | --- | --- |
| `help.ask` | global | none | Admin, GreenTeam, BlueTeam, Anon |
| `notes.write.green` | site (workspace=green) | optional | GreenTeam |
| `notes.write.blue` | site (workspace=blue) | optional | BlueTeam |
| `buttons.press.green` | site (workspace=green) | none | GreenTeam |
| `buttons.press.blue` | site (workspace=blue) | none | BlueTeam |
| `buttons.press.red` | self | required | GreenTeam, BlueTeam |
| `users.provision` | global | required | Admin |
| `audit.read.all` | global | n/a (read-side only) | Admin |

### 4.3 Action catalog

Seven actions go through `ActionDispatcher`:

1. **`RequestHelpAction`** — perm `help.ask`, idempotency none. Anyone, including Anon. Emits `help_request`.
2. **`EditGreenNoteAction`** — perm `notes.write.green`, idempotency optional. GreenTeam-only. Emits `demo_note` lifecycle events.
3. **`EditBlueNoteAction`** — perm `notes.write.blue`, idempotency optional. BlueTeam-only. Mirror of (2).
4. **`PressGreenButtonAction`** — perm `buttons.press.green`, idempotency none. Emits `green_button_pressed`.
5. **`PressBlueButtonAction`** — perm `buttons.press.blue`, idempotency none. Emits `blue_button_pressed`.
6. **`PressRedAlarmAction`** — perm `buttons.press.red`, idempotency required. Held by both teams. Emits `red_button_pressed`.
7. **`ProvisionUserAction`** — perm `users.provision`, idempotency required. Admin-only. Input `{userId, role, activeSite?}`. `validate` rejects duplicates against the current directory view. Emits `user_provisioned`.

Read-side: one server endpoint `GET /_demo/audit` gated by `audit.read.all`; the Admin client's audit panel queries it.

### 4.4 Coverage

| Library surface | Walkthrough(s) demonstrating it |
| --- | --- |
| `ScopeClass.global` | RequestHelp, ReadAudit |
| `ScopeClass.site` | EditGreenNote, EditBlueNote, PressGreenButton, PressBlueButton |
| `ScopeClass.self` | PressRedAlarm |
| `Idempotency.none` | PressGreenButton, PressBlueButton, RequestHelp |
| `Idempotency.optional` | EditGreenNote, EditBlueNote |
| `Idempotency.required` | PressRedAlarm, ProvisionUser |
| Multi-role permission | PressRedAlarm (held by both teams) |
| Anon-allowed action | RequestHelp |
| Admin-denied-on-write | every dispatched action other than ProvisionUser |
| Cross-team `notGranted` | GreenTeam tries Edit Blue Note |
| `sessionPreconditionMissing` (site) | Anon tries Press Green |
| `sessionPreconditionMissing` (self) | Anon tries Press Red Alarm |
| `parse_denied(MissingIdempotencyKeyError)` | PressRedAlarm without a key |
| Idempotency replay short-circuit | PressRedAlarm twice with same key |
| Cross-user same-key independence | green-user-1 and green-user-2, same key, both succeed |
| Identity decouples from role | green-user-1 vs green-user-2 audit trails |
| Materializer composition | ProvisionUser (UserDirectoryMaterializer + RolePermissionGrantsMaterializer in one process) |
| Audit-trail correlation by `action_invocation_id` | every walkthrough's denial-or-success row |

## 5. Walkthroughs

The README scripts these in order, each as a "do X, observe Y" exercise.

1. **Onboarding: identity → principal → snapshot.** Cycle the userId selector through every entry; observe Principal and Snapshot returned by `POST /session/start`; observe gated buttons in well-behaved mode.

2. **Dispatch happy paths across scope classes.** As Anon, click Ask for Help; as `green-user-1`, click Edit Green Note and Press Green Button; as `blue-user`, click Edit Blue Note and Press Blue Button; as `green-user-1` with auto-key, click Press Red Alarm. Observe pipeline traces with all stages green.

3. **The matrix is the perimeter (denial paths).** Disabled buttons in well-behaved mode. Flip hacker mode on; click any disabled button; observe `authorization_denied` events flowing server-side. Repeat as Anon, repeat as Admin.

4. **Idempotency policy matrix.** Three sub-flows for none, optional, required. Replay scenarios for optional and required.

5. **Cross-user idempotency-store independence.** Same `idempotencyKey='shared'` from `green-user-1` and `green-user-2` against `PressRedAlarm`; both succeed; two distinct store entries.

6. **Identity decouples from role.** Edit Green Note from `green-user-1` then `green-user-2`; identical role and snapshot, distinct `initiator.userId` in audit trail.

7. **Malformed requests.** Hacker mode reveals: Fire Unknown Action, Corrupt Input toggle, empty-title input. Observe `unknown_action`, `parse_denied`, `validation_denied`.

8. **Audit correlation by `action_invocation_id`.** Pick any prior attempt's id; filter the event log by that id; observe every event from one attempt under one filter.

9. **User provisioning end-to-end.** As `admin-user`, provision `green-user-3`. Pipeline runs; `UserDirectoryMaterializer` and the directory view update in the same transaction. Within one poll interval, the userId dropdown picks up `green-user-3`. Switch to it, click Edit Green Note, succeed.

10. **Reset all.** Click Reset All. Server wipes db, replays seed appliers, restores baseline. Idempotent.

## 6. Testing strategy

Three layers.

**Library-side unit tests** (pre-condition for the demo) live in `apps/common-dart/audited_actions/test/` and `apps/common-dart/action_permissions/test/`. The dispatcher's 10-stage pipeline tests are the largest gap to close before the demo plan starts. `ActionRegistry` collision detection, `TableBackedAuthorizationPolicy` outcomes across every `ScopeClass × DenyReason` cell, `FailSafeAuthorizationPolicy`, `RolePermissionGrantsMaterializer` in-transaction behavior, `EventSeedApplier` diff logic, and denial-event payload sanitization all need exhaustive coverage. These follow `superpowers:test-driven-development` and ship in the CUR-1192 library completion plan, not this design's plan.

**Demo unit tests** (`example/test/`) cover each of the 7 `Action` implementations' `parseInput`/`validate`/`execute` methods, the `UserDirectory` YAML parser, the `UserDirectoryMaterializer` (idempotent on replay, transactional with the events that drive it), `wire_types.dart` round-trip serialization for every variant, and `UserDirectorySeedApplier`'s diff logic against various current-view states.

**End-to-end integration tests** (`example/integration_test/`) script every walkthrough. Each test:

1. Spawns `bin/server.dart` as a subprocess via `Process.start` with `--ephemeral --port=$FREE_PORT` (sembast in-memory; port from `ServerSocket.bind(0)`).
2. Waits for `GET /healthz` to return 200.
3. Drives via direct HTTP (`package:http`); does not drive the Flutter UI.
4. Asserts observable state by polling `GET /_demo/inspect` for expected event-log entries, matrix grants, idempotency-store contents, dispatch-trace contents.
5. Tears down the subprocess in `tearDownAll`.

A `test/test_support/demo_server_harness.dart` helper module provides `DemoServerHarness` with `start()`, `stop()`, `dispatch(request)`, `inspect()`, `reset()`. The walkthrough script and the integration-test assertions derive from one source — the test file's structure mirrors the walkthrough's flow.

**Coverage targets:**

- Every `DispatchResult` variant has at least one integration test that produces it on the wire.
- Every walkthrough has at least one integration test that scripts it.
- Every `ScopeClass × Idempotency × Role` cell with a matrix grant has at least one happy-path test; every Anon/Admin denial cell has at least one denial test.

**Annotation discipline:**

- Each `Action` subclass header carries `// Implements: REQ-d00115-A+B+C+D+E+F — Action interface contract`.
- Each demo materializer carries `// Implements: REQ-d00121` against the materializer interface.
- `bin/server.dart` and `lib/server/demo_routes.dart` carry `// Verifies: REQ-d00116, REQ-d00117 — bootstrap and dispatch entry`.
- Every test method carries `// Verifies: REQ-d00XXX-Y` keyed to the assertion(s) it covers.

**CI:** demo unit tests run with the standard `flutter test` step. Demo integration tests run in a dedicated CI job (`run-demo-integration`) with sembast in-memory for isolation.

## 7. Out of scope

- Authentication, TLS, rate limiting, CORS, payload limits.
- Resource-level ownership semantics. The demo's principals are role-as-identity; no per-resource owner field.
- Reactive view-change notifications. Server-to-client delivery is HTTP polling at 1 Hz behind `DemoStateProjection`. CUR-1154 Phase 4.12 (reactive read layer) provides the swap target.
- Atomic-rollback live walkthroughs. Verified by integration tests, not the live demo.
- Synthetic-burst load generators.
- Flutter UI driver tests. Slow and brittle; the demo's library-validation lessons live in the request/response shape.
- Real auth-handshake mechanisms (JWT validation, session cookies, OAuth flows). Real consumers wire these at the `shelf` middleware layer in front of `dispatcher.dispatch`.

## Requirements

The demo introduces no new library functionality and claims no new REQ-d numbers. The implementation plan modifies neither `spec/dev-audited-actions.md`, `spec/dev-action-permissions.md`, nor `spec/INDEX.md`.

**Existing REQs verified by demo implementation and integration tests:**

From `spec/dev-audited-actions.md`:

- **REQ-d00115** (Action Interface Contract) — verified by all 7 demo `Action` subclasses' `parseInput` / `validate` / `execute` signatures and pure-method discipline.
- **REQ-d00116** (ActionRegistry and Bootstrap) — verified by the server-side `bootstrapDemoServer` call composing all 7 actions and asserting collision-free registration.
- **REQ-d00117** (Dispatcher Pipeline) — verified end-to-end by every walkthrough integration test, each asserting the resulting `DispatchResult` variant matches the stage at which the request fails or succeeds.
- **REQ-d00118** (Authorization Policy) — verified by the cross-team and Anon-precondition denial walkthroughs.
- **REQ-d00119** (Idempotency Contract) — verified by the per-policy walkthrough (none / optional / required), the cross-user same-key walkthrough, and the replay walkthrough.
- **REQ-d00120** (Denial Events) — verified by integration assertions on every denial path that the resulting denial event has the expected `eventType`, `aggregateType: 'action_attempt'`, sanitized payload, and shared `action_invocation_id`.

From `spec/dev-action-permissions.md`:

- **REQ-d00121** through **REQ-d00127** — verified by the bootstrap walkthrough (`FailSafeAuthorizationPolicy` boot path), matrix view materialization, `PermissionSnapshot` delivery, `EventSeedApplier` diff logic, and `MaterializedViewRoleMatrixReader` round-trip behavior.

From the events lib and `event_sourcing_datastore` (existing on main):

- The dispatcher's atomic-persist contract (Stage 8 — entire `events.transaction` rolls back on any append failure) is exercised; failure injection comes via integration tests only.
- Materializer-in-transaction. `RolePermissionGrantsMaterializer` and the demo's `UserDirectoryMaterializer` both run inside the same `events.transaction` block as the events that drive them. Verified by the user-provisioning walkthrough's assertion that both the matrix view and the directory view advance together with their driving events.

**Annotation discipline (the implementation plan must enforce on every file it touches):**

- Every `Action` subclass header: `// Implements: REQ-d00115-A+B+C+D+E+F — Action interface contract`.
- Every demo `Materializer` subclass: `// Implements: REQ-d00121 — materializer-in-transaction contract`.
- `bin/server.dart` and `lib/server/demo_routes.dart`: `// Verifies: REQ-d00116, REQ-d00117 — bootstrap and dispatch entry`.
- Every test method in `example/test/` and `example/integration_test/`: `// Verifies: REQ-d00XXX-Y` for each assertion the test covers.

**No `spec/dev-*.md` updates required.** No `spec/INDEX.md` change. No new REQ-d claims.

## Related specifications

- `spec/dev-audited-actions.md` — REQ-d00115..REQ-d00120 (Action interface, registry, dispatcher pipeline, authorization, idempotency, denial events).
- `spec/dev-action-permissions.md` — REQ-d00121..REQ-d00127 (matrix-as-event-log, materializer, seed applier, snapshot, FailSafe policy).
- `docs/superpowers/specs/2026-04-22-events-and-actions-libs-design.md` — original consolidated design from CUR-1159.
- `docs/superpowers/specs/2026-04-23-action-permissions-design.md` — sibling library design (matrix, scope class, snapshot delivery).
- `docs/superpowers/specs/2026-04-25-phase4.12-reactive-read-layer-design.md` — `watchEvents` / `watchFifo` API shapes that `ReactiveDemoStateProjection` will consume on swap.
- `apps/common-dart/event_sourcing_datastore/example/README.md` — pattern source for the dual-pane shell, sembast bootstrap, and live-knob harness.

## Revision history

| Version | Date       | Changes                                       | Ticket     |
| ------- | ---------- | --------------------------------------------- | ---------- |
| 1.0     | 2026-05-06 | Initial demo design                           | CUR-1192   |
