# action_permissions_demo

A Linux-desktop reference application that exercises the `event_sourcing`
library's actions and permissions modules end-to-end. The demo runs a Dart
`shelf` server hosting the dispatcher, event store, and permission matrix,
paired with a Flutter Linux client that renders a dual pane: user-facing
controls on the left, server-side inspector on the right. It is the canonical
hands-on validation surface for REQ-d00166 through REQ-d00178 — every claim the
library makes about action dispatch, authorization, idempotency, identity
decoupling, audit correlation, user provisioning, and snapshot delivery is
demonstrated here as a runnable scenario, mirrored by an integration test under
`test/walkthroughs/`.

## What it exercises

- REQ-d00166 — `Action` lifecycle (parse, validate, authorize, execute) and
  typed event emission, surfaced in the request history pane.
- REQ-d00168 — Dispatcher pipeline correlation: every dispatch carries a fresh
  v4 `action_invocation_id`, and `authorization_denied` events are emitted by
  the authorize stage. Visible in the inspector's audit view.
- REQ-d00170 — Idempotency policy matrix (none / optional / required) plus
  cache-key composition that includes `principalId`, validated by the
  client-side replay mechanics.
- REQ-d00171 — Denial events for parse failures, validation failures, and
  unknown-action requests, surfaced as audit entries.
- REQ-d00174 — `UserDirectory` materializer/seed-applier loop driven by
  `provision_user` action emissions.
- REQ-d00176 — `AuthorizationPolicy` matrix lookup as the single perimeter
  for all action authorization decisions.
- REQ-d00177 — Per-`userId` `PermissionSnapshot` delivery to the client and
  cache invalidation on identity change.
- REQ-d00178 — Identity decoupling: switching the active `userId` changes the
  effective permission set without restarting the server.

## Architecture

The server is a single-process Dart `shelf` HTTP service that wires the
event-store, dispatcher, permission matrix, action catalog, and user-directory
projection into one in-memory pipeline. The Flutter Linux desktop client talks
to the server over plain HTTP and renders both panes from the same process; the
right pane polls the server's inspector endpoints to expose the audit log,
projected state, and current permission snapshot.

```text
+--------------------------------------------------+
|             Flutter Linux desktop app            |
|                                                  |
|  +------------------+    +-------------------+   |
|  |  Client pane     |    |  Inspector pane   |   |
|  |  - userId picker |    |  - event log      |   |
|  |  - action btns   |    |  - projected      |   |
|  |  - request hist. |    |    state          |   |
|  |                  |    |  - snapshot view  |   |
|  +--------+---------+    +---------+---------+   |
|           |                        |             |
+-----------|------------------------|-------------+
            |   HTTP (shelf, JSON)   |
            v                        v
+--------------------------------------------------+
|                Dart shelf server                 |
|                                                  |
|   dispatcher --> action catalog --> event store  |
|       |              |                  |        |
|       v              v                  v        |
|   matrix       idempotency        projections    |
|  (perimeter)      store         (user dir, etc.) |
+--------------------------------------------------+
```

## File layout

```text
example_action_permissions/
  bin/
    server.dart                     # shelf server entry point
  lib/
    server/
      actions/                      # 7 demo actions
      action_catalog.dart
      bootstrap.dart                # wires the in-memory pipeline
      demo_idempotency_store.dart
      demo_routes.dart              # HTTP route table
      demo_state_projection.dart
      inspect_snapshot.dart
      user_directory.dart
      user_directory_materializer.dart
      user_directory_seed_applier.dart
    client/
      app.dart                      # MaterialApp shell
      main.dart                     # Flutter entry point
      client_pane.dart              # left pane
      server_inspector_pane.dart    # right pane
      action_buttons_panel.dart
      hacker_mode_toggle.dart       # raw-JSON view toggle
      http_client.dart
      permission_snapshot_cache.dart
      request_history_panel.dart
      userid_selector.dart
    shared/
      wire_types.dart               # request/response/snapshot shapes
  tool/
    run_demo.sh                     # start server + client
    stop_demo.sh                    # graceful shutdown
    permissions.yaml                # demo matrix seed
    users.yaml                      # demo user seed
  test/
    actions/                        # per-action unit tests
    client/                         # widget tests
    walkthroughs/                   # canonical end-to-end scenarios
      test_support/
        demo_server_harness.dart
      walkthrough_01..10_*.dart
    bootstrap_test.dart
    demo_routes_test.dart
    demo_state_projection_test.dart
    user_directory_*_test.dart
    wire_types_test.dart
```

## Prerequisites

- Flutter 3.38 or newer (channel `stable` is fine).
- Dart 3.10 or newer (bundled with the matching Flutter version).
- Linux desktop with the GTK packages required by Flutter Linux:
  `libgtk-3-dev`, `libblkid-dev`, `liblzma-dev`, `clang`, `cmake`, `ninja-build`,
  `pkg-config`. On Debian/Ubuntu:
  ```
  sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev \
                   libblkid-dev liblzma-dev
  ```

Run `flutter doctor` and confirm the "Linux toolchain" line is green before
launching the demo.

## How to run

From this package's directory:

```
tool/run_demo.sh
```

This builds the server, starts it on a free local port, builds the Flutter
Linux client, and launches it pointed at the running server. Console output
streams from both processes.

To stop:

```
tool/stop_demo.sh
```

If the scripts do not fit your environment, the manual equivalent is:

1. Start the server: `dart run bin/server.dart`.
2. In another terminal, run the client:
   `flutter run -d linux --dart-define=DEMO_SERVER_URL=http://127.0.0.1:<port>`.
3. Stop both with `Ctrl+C` when finished.

## The 10 walkthroughs

Each walkthrough below describes a hands-on scenario you can run against the
live demo. The corresponding integration test under `test/walkthroughs/`
canonicalizes the expected behavior — when the prose and the test disagree,
trust the test.

### Walkthrough 1: Onboarding (identity to principal to snapshot)

Launch the demo and pick `green-user-1` from the userId selector. Observe the
client fetch a fresh `PermissionSnapshot`, the inspector pane populate with
that user's effective matrix slice, and the action buttons in the left pane
enable/disable to match the snapshot. This is the cold-start identity flow:
identity selection drives principal resolution, which drives snapshot
delivery, which drives UI affordance.

Canonical test: `test/walkthroughs/walkthrough_01_onboarding_test.dart`.

### Walkthrough 2: Happy paths across scope classes

Still as `green-user-1`, click "Press Green Button" and "Edit Green Note".
Watch a `green_button_pressed` event, then a `green_note_edited` event,
appear in the inspector's event log. Switch to `blue-user-1` and repeat with
the blue actions. Each happy path covers a different scope class in the
permission matrix and confirms typed event emission per REQ-d00166-E.

Canonical test: `test/walkthroughs/walkthrough_02_happy_paths_test.dart`.

### Walkthrough 3: Matrix is the perimeter (denial paths)

As `green-user-1`, attempt "Press Blue Button". The button is disabled in
the snapshot, but if you flip the hacker-mode toggle you can fire the request
anyway. The server rejects it with an `authorization_denied` event in the
audit log, sourced from the matrix lookup. The matrix is the only thing
guarding the action — there are no per-action checks downstream.

Canonical test: `test/walkthroughs/walkthrough_03_matrix_perimeter_test.dart`.

### Walkthrough 4: Idempotency policy matrix

Fire each of three actions twice with the same idempotency key:
`press_red_alarm` (policy: required), `request_help` (policy: optional, with a
key supplied), and `press_green_button` (policy: none). Observe that the first
two collapse to a single event on replay while the third double-fires.

Canonical test:
`test/walkthroughs/walkthrough_04_idempotency_policies_test.dart`.

### Walkthrough 5: Cross-user idempotency-store independence

Fire `request_help` with key `K-42` as `green-user-1`. Switch to `blue-user-1`
and fire `request_help` with the same key `K-42`. Both succeed and emit
distinct events: the cache key is `(principalId, key)`, not `key` alone, so
keyspaces are partitioned per user.

Canonical test: `test/walkthroughs/walkthrough_05_cross_user_keys_test.dart`.

### Walkthrough 6: Identity decouples from role

Without restarting the server, switch the userId selector between
`green-user-1`, `blue-user-1`, and `red-user-1`. The snapshot, button states,
and inspector view all change in step. Identity is a runtime input to the
dispatcher, not a server-startup binding.

Canonical test:
`test/walkthroughs/walkthrough_06_identity_decoupling_test.dart`.

### Walkthrough 7: Malformed requests (parse / validation / unknown action)

Enable hacker mode and POST three deliberately broken requests: malformed
JSON, a known action with an out-of-range field, and an `actionType` the
catalog has never heard of. Each produces a distinct denial event
(`parse_failed`, `validation_failed`, `unknown_action`) with the request's
`action_invocation_id` recorded.

Canonical test:
`test/walkthroughs/walkthrough_07_malformed_requests_test.dart`.

### Walkthrough 8: Audit correlation by action_invocation_id

Pick any happy-path action and submit it. Note the `action_invocation_id`
shown in the request history panel. Open the inspector, filter the audit log
by that id, and confirm every event the dispatch produced — accept, execute,
emit — shares the same id. This is the auditor's primary correlation tool.

Canonical test:
`test/walkthroughs/walkthrough_08_audit_correlation_test.dart`.

### Walkthrough 9: User provisioning end-to-end

As an admin user, fire `provision_user` with a new userId. Watch the
`user_provisioned` event land in the audit log, the user-directory
projection update, and the new user appear in the userId selector dropdown
on next refresh. Switch to the new user and confirm a `PermissionSnapshot` is
delivered for them.

Canonical test:
`test/walkthroughs/walkthrough_09_user_provisioning_test.dart`.

### Walkthrough 10: Reset all (ephemeral restart pattern)

Stop the demo with `tool/stop_demo.sh` and restart it with
`tool/run_demo.sh`. The event store, idempotency cache, and projections all
return to seed state. There is no in-process reset endpoint — restart is the
only supported path, and restart is fast enough that this is fine.

Canonical test: `test/walkthroughs/walkthrough_10_reset_test.dart`.

## What this architecture deliberately leaves out

- Real authentication and TLS. The server trusts whatever userId the client
  sends; transport is plain HTTP on loopback.
- Aggregate-level ownership and row-level authorization. The matrix is
  global; there are no "user X owns row Y" checks.
- Reactive primitives on the client. The inspector polls; there are no
  server-sent events, websockets, or change-feed subscriptions.
- A true in-process `/_demo/reset` endpoint. Resetting state means restarting
  the process (see Walkthrough 10).
- Synthetic-burst load testing. The walkthroughs exercise correctness, not
  throughput.
- Rate limiting, CORS hardening, and production observability (structured
  logging, metrics, traces).

## Pointer

The integration tests under `test/walkthroughs/` are the canonical
specification of each scenario. The prose above is a human-readable summary
intended to orient a new reader; if the README and a test diverge, the test
wins.

## Design doc

Full design rationale, scope decisions, and REQ traceability live in
`docs/superpowers/specs/2026-05-06-action-permissions-demo-design.md`.
