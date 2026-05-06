# Action Permissions / Audited Actions Demo App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Linux-desktop two-process reference app at `apps/common-dart/action_permissions/example/` that exercises every public surface of the `audited_actions` and `action_permissions` libraries end-to-end. Validates the dispatcher pipeline, all denial types, every idempotency policy, scope-class enforcement, and the matrix-as-event-log pattern under realistic client-server conditions.

**Architecture:** Dart `shelf` HTTP server (`bin/server.dart`) hosts the dispatcher, event store, matrix, and user directory. A Flutter Linux-desktop client connects over `localhost:8080` and renders two panes — a client view (userId selector, hacker-mode toggle, gated action buttons) and a server-inspector view (event log, matrix, idempotency store, dispatch trace). Identity is asserted in-band on each request as a bare `userId`; the server resolves to a `Principal` via a YAML-seeded directory. No auth handshake. State delivery is HTTP polling at 1 Hz behind a swappable `DemoStateProjection` interface.

**Tech Stack:** Dart 3.10+, Flutter desktop (Linux), `shelf` for HTTP, `package:http` for client, `sembast` for storage, `package:yaml` for seeds, `package:test` + integration tests. Depends on the `audited_actions`, `action_permissions`, and `event_sourcing_datastore` libraries.

**Ticket:** CUR-1192 (demo informs CUR-1170 portal cutover scope)
**Design doc:** `docs/superpowers/specs/2026-05-06-action-permissions-demo-design.md`
**Verifies:** REQ-d00166..REQ-d00178 (Action interface, registry, dispatcher pipeline, authorization, idempotency, denial events, matrix as event log, scope class, snapshot, fail-safe bootstrap)

---

## Hard Prerequisites

This plan does **NOT** start until the following library work is complete and merged to this branch:

1. **`audited_actions` library** at `apps/common-dart/audited_actions/` — beyond the value-type scaffolding consolidated in `84574c5b`, the following must ship per `docs/superpowers/plans/2026-04-22-audited-actions-library.md`:
   - `Action<TInput, TResult>` abstract interface (REQ-d00166).
   - `ActionRegistry` with collision detection (REQ-d00167).
   - `ActionDispatcher` 10-stage pipeline (REQ-d00168).
   - `AuthorizationPolicy` interface (REQ-d00169).
   - Denial-event payload sanitization helpers (REQ-d00171).
   - `Principal`, `ActionContext`, `ScopeClass`, `EventDraft` value types.
   - `bootstrapAuditedActions(...)` composition function.
   - `dart test` green for every assertion in `spec/dev-audited-actions.md`.

2. **`action_permissions` library** at `apps/common-dart/action_permissions/` — does not yet exist as code; only the design (`docs/superpowers/specs/2026-04-23-action-permissions-design.md`) and spec (`spec/dev-action-permissions.md`) are on this branch. A separate plan (`docs/superpowers/plans/<DATE>-action-permissions-library.md`) must produce:
   - `TableBackedAuthorizationPolicy` over a `RoleMatrixReader` (REQ-d00173).
   - `MaterializedViewRoleMatrixReader` over `StorageBackend` view methods.
   - `RolePermissionGrantsMaterializer` (REQ-d00174).
   - `PermissionGranted` / `PermissionRevoked` event payload value types.
   - `PermissionSeed` + `YamlSeedLoader` + `SeedValidator` + `EventSeedApplier` (REQ-d00175).
   - `PermissionSnapshot` + `SnapshotRoleMatrixReader` (REQ-d00177).
   - `FailSafeAuthorizationPolicy` + `AuthorizationPolicyBootstrap` (REQ-d00178).
   - `bootstrapActionPermissions(...)` composition function.
   - `dart test` green for every assertion in `spec/dev-action-permissions.md`.

3. **`event_sourcing_datastore` library** on `main` — already shipped via CUR-1154; required transitively for `EventStore`, `StorageBackend`, `Materializer`, the `events.transaction` block, and (when Phase 4.12 ships) `watchEvents` / `watchFifo`.

If a Step 1 or Step 2 task in this plan fails because a library symbol is missing, that's a sign the prerequisite work was skipped. Do not work around — return to the library plan.

---

## Execution Rules

Read the design doc (`docs/superpowers/specs/2026-05-06-action-permissions-demo-design.md`) end-to-end before Task 1. Re-read §3 (Architecture) before Task 14. Re-read §5 (Walkthroughs) before Task 27.

TDD cadence per task: baseline (existing tests green) → write failing test → run-and-verify-fail → write minimal impl → run-and-verify-pass → commit. Commits use `[CUR-1192]` prefix.

REQ citation format:
- Implementation files include a `// IMPLEMENTS REQUIREMENTS:` block at the top listing all REQ-d ids the file implements (concrete actions all `// Implements: REQ-d00166`).
- Per-function: `// Implements: REQ-d00XXX-Y — <prose>` where applicable.
- Per-test: `// Verifies: REQ-d00XXX-Y — <prose>` AND the assertion ID starts the test description: `test('REQ-d00XXX-Y: description', () { ... })`.

Run from `apps/common-dart/action_permissions/example/`:
- `flutter pub get` after each pubspec change.
- `flutter test test/...` for unit tests (Flutter is required because the example links Flutter widgets).
- `flutter test integration_test/...` for end-to-end tests against a spawned server.
- `dart analyze` to verify lints clean.

After every commit, run `flutter test` and `dart analyze` to confirm green.

---

## File Structure

All paths relative to `apps/common-dart/action_permissions/example/`.

```text
example/
  bin/
    server.dart                       # shelf HTTP server entry; the trusted process
  lib/
    client/                           # Flutter UI (untrusted side)
      main.dart                       # entrypoint; bootstraps DualPaneApp
      app.dart                        # DualPaneApp MaterialApp + theme
      client_pane.dart                # left pane: userId selector, buttons, history
      server_inspector_pane.dart      # right pane: events, matrix, idempotency, trace
      userid_selector.dart            # dropdown widget
      hacker_mode_toggle.dart         # toggle widget
      action_buttons_panel.dart       # gated buttons + provision form (admin) + composer (hacker)
      request_history_panel.dart      # list of past dispatches with results
      permission_snapshot_cache.dart  # client-side snapshot held after /session/start
      http_client.dart                # thin wrapper over package:http
    server/                           # bin/ helpers (host-side, not library)
      user_directory.dart             # UserDirectoryEntry, UserDirectory in-memory map
      user_directory_materializer.dart  # Materializer for user_provisioned events
      user_directory_seed_applier.dart  # YAML seed -> events on boot
      action_catalog.dart             # registers all 7 demo actions
      actions/                        # per-action files
        request_help_action.dart
        edit_green_note_action.dart
        edit_blue_note_action.dart
        press_green_button_action.dart
        press_blue_button_action.dart
        press_red_alarm_action.dart
        provision_user_action.dart
      demo_routes.dart                # shelf route handlers
      inspect_snapshot.dart           # serializes server state for /_demo/inspect
      demo_state_projection.dart      # PollingDemoStateProjection (today)
      bootstrap.dart                  # bootstrapDemoServer composes everything
    shared/
      wire_types.dart                 # DispatchRequest/Response, SessionStart, InspectSnapshot
  tool/
    users.yaml                        # 4 userId entries
    permissions.yaml                  # role -> permissions matrix seed
    run_demo.sh                       # spawn server + flutter run
    stop_demo.sh                      # tear-down companion
    .demo-server.log                  # server stdout (gitignored)
  test/                               # Flutter unit tests (no shelf)
    actions/
      request_help_action_test.dart
      edit_green_note_action_test.dart
      ...
    user_directory_test.dart
    user_directory_materializer_test.dart
    user_directory_seed_applier_test.dart
    wire_types_test.dart
  integration_test/                   # spawn server subprocess; drive over HTTP
    test_support/
      demo_server_harness.dart        # start/stop/dispatch/inspect/reset helpers
    walkthrough_01_onboarding_test.dart
    walkthrough_02_happy_paths_test.dart
    walkthrough_03_matrix_perimeter_test.dart
    walkthrough_04_idempotency_policies_test.dart
    walkthrough_05_cross_user_keys_test.dart
    walkthrough_06_identity_decoupling_test.dart
    walkthrough_07_malformed_requests_test.dart
    walkthrough_08_audit_correlation_test.dart
    walkthrough_09_user_provisioning_test.dart
    walkthrough_10_reset_test.dart
  pubspec.yaml
  analysis_options.yaml
  .gitignore
  README.md
```

---

## Phase 0 — Package skeleton

### Task 1: Package skeleton + pubspec

**Files:**
- Create: `apps/common-dart/action_permissions/example/pubspec.yaml`
- Create: `apps/common-dart/action_permissions/example/analysis_options.yaml`
- Create: `apps/common-dart/action_permissions/example/.gitignore`
- Create: `apps/common-dart/action_permissions/example/README.md` (placeholder; Task 38 fills in)

- [ ] **Step 1: Write pubspec.yaml**

```yaml
# apps/common-dart/action_permissions/example/pubspec.yaml
name: action_permissions_demo
description: "Linux-desktop reference app exercising audited_actions + action_permissions libraries end-to-end. Verifies REQ-d00166..REQ-d00178."
version: 0.1.0+1
publish_to: none

environment:
  sdk: ^3.10.7
  flutter: ">=3.38.7"

dependencies:
  flutter:
    sdk: flutter
  audited_actions:
    path: ../../audited_actions
  action_permissions:
    path: ..
  event_sourcing_datastore:
    path: ../../event_sourcing_datastore
  shelf: ^1.4.1
  shelf_router: ^1.1.4
  http: ^1.2.0
  sembast: ^3.7.3
  path: ^1.9.1
  path_provider: ^2.1.5
  yaml: ^3.1.3
  uuid: ^4.5.2
  meta: ^1.16.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  test: ^1.25.15
  integration_test:
    sdk: flutter
  lints: ^5.0.0
```

- [ ] **Step 2: Write analysis_options.yaml**

```yaml
# apps/common-dart/action_permissions/example/analysis_options.yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    - prefer_const_constructors
    - prefer_final_locals
    - require_trailing_commas
```

- [ ] **Step 3: Write .gitignore**

```text
# apps/common-dart/action_permissions/example/.gitignore
.dart_tool/
.flutter-plugins-dependencies
build/
coverage/
pubspec.lock

# demo runtime
tool/.demo-server.log
*.db
**/*.install.uuid
```

- [ ] **Step 4: Write placeholder README**

```markdown
# action_permissions_demo

Linux-desktop reference app for `audited_actions` + `action_permissions`. Full README written in Task 38; this is a placeholder for early commits.
```

- [ ] **Step 5: Run flutter pub get**

```bash
cd apps/common-dart/action_permissions/example
flutter pub get
```

Expected: `Got dependencies!` (or `Changed N dependencies!`). If `audited_actions` or `action_permissions` path resolution fails, the prerequisite library work is incomplete — stop and address that.

- [ ] **Step 6: Run dart analyze**

```bash
dart analyze
```

Expected: `No issues found!` (no Dart files yet, but pubspec resolution should be clean).

- [ ] **Step 7: Commit**

```bash
git add apps/common-dart/action_permissions/example/
git commit -m "[CUR-1192] demo: package skeleton + deps"
```

---

## Phase 1 — Wire types

### Task 2: DispatchRequest / DispatchResponse JSON envelopes

**Files:**
- Create: `lib/shared/wire_types.dart`
- Test: `test/wire_types_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/wire_types_test.dart
// Verifies: REQ-d00168 (dispatcher pipeline wire-shape stability)
import 'package:flutter_test/flutter_test.dart';
import 'package:action_permissions_demo/shared/wire_types.dart';

void main() {
  group('DispatchRequest', () {
    test('REQ-d00168: round-trips through JSON', () {
      const req = DispatchRequest(
        actionName: 'EditGreenNoteAction',
        rawInput: <String, Object?>{'title': 'hi', 'body': 'there'},
        idempotencyKey: 'abc-123',
        userId: 'green-user-1',
      );
      final json = req.toJson();
      final parsed = DispatchRequest.fromJson(json);
      expect(parsed, equals(req));
    });

    test('REQ-d00168: omits null idempotencyKey and userId', () {
      const req = DispatchRequest(
        actionName: 'RequestHelpAction',
        rawInput: <String, Object?>{},
      );
      final json = req.toJson();
      expect(json.containsKey('idempotencyKey'), isFalse);
      expect(json.containsKey('userId'), isFalse);
    });
  });

  group('DispatchResponse', () {
    test('REQ-d00168: success variant round-trips', () {
      const resp = DispatchResponseSuccess(
        actionInvocationId: 'inv-1',
        emittedEventIds: <String>['evt-1', 'evt-2'],
        result: <String, Object?>{'ok': true},
      );
      final json = resp.toJson();
      final parsed = DispatchResponse.fromJson(json);
      expect(parsed, isA<DispatchResponseSuccess>());
      expect((parsed as DispatchResponseSuccess).actionInvocationId, 'inv-1');
    });

    test('REQ-d00171: denied variant carries denialKind and sanitized error', () {
      const resp = DispatchResponseDenied(
        denialKind: 'authorization_denied',
        actionInvocationId: 'inv-2',
        errorClass: 'AuthorizationError',
        errorMessageSanitized: 'permission notes.write.blue not granted',
        permissionDenied: 'notes.write.blue',
        requestedName: null,
      );
      final json = resp.toJson();
      final parsed = DispatchResponse.fromJson(json);
      expect(parsed, isA<DispatchResponseDenied>());
      expect((parsed as DispatchResponseDenied).denialKind, 'authorization_denied');
    });

    test('REQ-d00170: idempotencyHit variant carries prior result', () {
      const resp = DispatchResponseIdempotencyHit(
        actionInvocationId: 'inv-3',
        priorEventIds: <String>['evt-prev'],
        priorResult: <String, Object?>{'ok': true},
      );
      final json = resp.toJson();
      final parsed = DispatchResponse.fromJson(json);
      expect(parsed, isA<DispatchResponseIdempotencyHit>());
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/wire_types_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:action_permissions_demo/shared/wire_types.dart'`.

- [ ] **Step 3: Implement wire_types.dart**

```dart
// lib/shared/wire_types.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00168 (Dispatcher Pipeline) — wire envelope between client and server
//   REQ-d00170 (Idempotency Contract) — idempotencyHit variant on the wire
//   REQ-d00171 (Denial Events) — denied variant exposes sanitized fields only
//
// Both client and server import this file verbatim. If the JSON shape drifts,
// the compiler catches it.

import 'package:meta/meta.dart';

@immutable
class DispatchRequest {
  const DispatchRequest({
    required this.actionName,
    required this.rawInput,
    this.idempotencyKey,
    this.userId,
  });

  final String actionName;
  final Map<String, Object?> rawInput;
  final String? idempotencyKey;
  final String? userId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'actionName': actionName,
      'rawInput': rawInput,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      if (userId != null) 'userId': userId,
    };
  }

  factory DispatchRequest.fromJson(Map<String, Object?> json) {
    return DispatchRequest(
      actionName: json['actionName']! as String,
      rawInput: Map<String, Object?>.from(json['rawInput']! as Map<Object?, Object?>),
      idempotencyKey: json['idempotencyKey'] as String?,
      userId: json['userId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DispatchRequest &&
          actionName == other.actionName &&
          _mapEq(rawInput, other.rawInput) &&
          idempotencyKey == other.idempotencyKey &&
          userId == other.userId;

  @override
  int get hashCode => Object.hash(actionName, idempotencyKey, userId);
}

bool _mapEq(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

sealed class DispatchResponse {
  const DispatchResponse();

  Map<String, Object?> toJson();

  factory DispatchResponse.fromJson(Map<String, Object?> json) {
    final kind = json['kind']! as String;
    switch (kind) {
      case 'success':
        return DispatchResponseSuccess(
          actionInvocationId: json['actionInvocationId']! as String,
          emittedEventIds: List<String>.from(json['emittedEventIds']! as List<Object?>),
          result: Map<String, Object?>.from(json['result']! as Map<Object?, Object?>),
        );
      case 'denied':
        return DispatchResponseDenied(
          denialKind: json['denialKind']! as String,
          actionInvocationId: json['actionInvocationId']! as String,
          errorClass: json['errorClass']! as String,
          errorMessageSanitized: json['errorMessageSanitized']! as String,
          permissionDenied: json['permissionDenied'] as String?,
          requestedName: json['requestedName'] as String?,
        );
      case 'idempotencyHit':
        return DispatchResponseIdempotencyHit(
          actionInvocationId: json['actionInvocationId']! as String,
          priorEventIds: List<String>.from(json['priorEventIds']! as List<Object?>),
          priorResult: Map<String, Object?>.from(json['priorResult']! as Map<Object?, Object?>),
        );
      default:
        throw FormatException('unknown DispatchResponse kind: $kind');
    }
  }
}

@immutable
class DispatchResponseSuccess extends DispatchResponse {
  const DispatchResponseSuccess({
    required this.actionInvocationId,
    required this.emittedEventIds,
    required this.result,
  });

  final String actionInvocationId;
  final List<String> emittedEventIds;
  final Map<String, Object?> result;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': 'success',
        'actionInvocationId': actionInvocationId,
        'emittedEventIds': emittedEventIds,
        'result': result,
      };
}

@immutable
class DispatchResponseDenied extends DispatchResponse {
  const DispatchResponseDenied({
    required this.denialKind,
    required this.actionInvocationId,
    required this.errorClass,
    required this.errorMessageSanitized,
    this.permissionDenied,
    this.requestedName,
  });

  final String denialKind;
  final String actionInvocationId;
  final String errorClass;
  final String errorMessageSanitized;
  final String? permissionDenied;
  final String? requestedName;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': 'denied',
        'denialKind': denialKind,
        'actionInvocationId': actionInvocationId,
        'errorClass': errorClass,
        'errorMessageSanitized': errorMessageSanitized,
        if (permissionDenied != null) 'permissionDenied': permissionDenied,
        if (requestedName != null) 'requestedName': requestedName,
      };
}

@immutable
class DispatchResponseIdempotencyHit extends DispatchResponse {
  const DispatchResponseIdempotencyHit({
    required this.actionInvocationId,
    required this.priorEventIds,
    required this.priorResult,
  });

  final String actionInvocationId;
  final List<String> priorEventIds;
  final Map<String, Object?> priorResult;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'kind': 'idempotencyHit',
        'actionInvocationId': actionInvocationId,
        'priorEventIds': priorEventIds,
        'priorResult': priorResult,
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/wire_types_test.dart
```

Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/wire_types.dart test/wire_types_test.dart
git commit -m "[CUR-1192] demo: DispatchRequest/Response wire types"
```

### Task 3: SessionStartRequest / SessionStartResponse + InspectSnapshot

**Files:**
- Modify: `lib/shared/wire_types.dart` (append)
- Modify: `test/wire_types_test.dart` (append)

- [ ] **Step 1: Write failing tests** — append to `test/wire_types_test.dart`:

```dart
  group('SessionStartRequest/Response', () {
    test('REQ-d00177: SessionStartRequest round-trip with userId', () {
      const req = SessionStartRequest(userId: 'green-user-1');
      final parsed = SessionStartRequest.fromJson(req.toJson());
      expect(parsed.userId, 'green-user-1');
    });

    test('REQ-d00177: SessionStartRequest round-trip without userId (Anon)', () {
      const req = SessionStartRequest();
      final parsed = SessionStartRequest.fromJson(req.toJson());
      expect(parsed.userId, isNull);
    });
  });

  group('InspectSnapshot', () {
    test('round-trips through JSON', () {
      const snap = InspectSnapshot(
        events: <StoredEventSummary>[
          StoredEventSummary(
            eventId: 'evt-1',
            eventType: 'help_request',
            aggregateType: 'help_ticket',
            aggregateId: 'agg-1',
            actionInvocationId: 'inv-1',
            initiatorUserId: null,
            initiatorRole: 'Anon',
          ),
        ],
        matrixGrants: <MatrixGrant>[
          MatrixGrant(role: 'Admin', permission: 'audit.read.all'),
        ],
        directory: <UserDirectoryEntry>[
          UserDirectoryEntry(userId: 'admin-user', role: 'Admin', activeSite: null),
        ],
        idempotency: <IdempotencyEntrySummary>[],
        lastDispatchTrace: null,
      );
      final parsed = InspectSnapshot.fromJson(snap.toJson());
      expect(parsed.events, hasLength(1));
      expect(parsed.matrixGrants, hasLength(1));
      expect(parsed.directory, hasLength(1));
    });
  });
```

- [ ] **Step 2: Run test, expect fail**

```bash
flutter test test/wire_types_test.dart
```

Expected: FAIL — undefined classes `SessionStartRequest`, `SessionStartResponse`, `InspectSnapshot`, `StoredEventSummary`, `MatrixGrant`, `UserDirectoryEntry`, `IdempotencyEntrySummary`.

- [ ] **Step 3: Append to lib/shared/wire_types.dart**

```dart
// SessionStart -------------------------------------------------------------

@immutable
class SessionStartRequest {
  const SessionStartRequest({this.userId});
  final String? userId;

  Map<String, Object?> toJson() => <String, Object?>{
        if (userId != null) 'userId': userId,
      };

  factory SessionStartRequest.fromJson(Map<String, Object?> json) {
    return SessionStartRequest(userId: json['userId'] as String?);
  }
}

@immutable
class SessionStartResponse {
  const SessionStartResponse({
    required this.principalRole,
    required this.principalUserId,
    required this.principalActiveSite,
    required this.snapshotPermissions,
  });

  final String principalRole;
  final String? principalUserId;
  final String? principalActiveSite;
  final List<String> snapshotPermissions;

  Map<String, Object?> toJson() => <String, Object?>{
        'principalRole': principalRole,
        'principalUserId': principalUserId,
        'principalActiveSite': principalActiveSite,
        'snapshotPermissions': snapshotPermissions,
      };

  factory SessionStartResponse.fromJson(Map<String, Object?> json) {
    return SessionStartResponse(
      principalRole: json['principalRole']! as String,
      principalUserId: json['principalUserId'] as String?,
      principalActiveSite: json['principalActiveSite'] as String?,
      snapshotPermissions: List<String>.from(json['snapshotPermissions']! as List<Object?>),
    );
  }
}

// InspectSnapshot ----------------------------------------------------------

@immutable
class StoredEventSummary {
  const StoredEventSummary({
    required this.eventId,
    required this.eventType,
    required this.aggregateType,
    required this.aggregateId,
    required this.actionInvocationId,
    required this.initiatorUserId,
    required this.initiatorRole,
  });

  final String eventId;
  final String eventType;
  final String aggregateType;
  final String aggregateId;
  final String actionInvocationId;
  final String? initiatorUserId;
  final String initiatorRole;

  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'eventType': eventType,
        'aggregateType': aggregateType,
        'aggregateId': aggregateId,
        'actionInvocationId': actionInvocationId,
        'initiatorUserId': initiatorUserId,
        'initiatorRole': initiatorRole,
      };

  factory StoredEventSummary.fromJson(Map<String, Object?> json) {
    return StoredEventSummary(
      eventId: json['eventId']! as String,
      eventType: json['eventType']! as String,
      aggregateType: json['aggregateType']! as String,
      aggregateId: json['aggregateId']! as String,
      actionInvocationId: json['actionInvocationId']! as String,
      initiatorUserId: json['initiatorUserId'] as String?,
      initiatorRole: json['initiatorRole']! as String,
    );
  }
}

@immutable
class MatrixGrant {
  const MatrixGrant({required this.role, required this.permission});
  final String role;
  final String permission;

  Map<String, Object?> toJson() => <String, Object?>{'role': role, 'permission': permission};

  factory MatrixGrant.fromJson(Map<String, Object?> json) {
    return MatrixGrant(role: json['role']! as String, permission: json['permission']! as String);
  }
}

@immutable
class UserDirectoryEntry {
  const UserDirectoryEntry({
    required this.userId,
    required this.role,
    required this.activeSite,
  });
  final String userId;
  final String role;
  final String? activeSite;

  Map<String, Object?> toJson() => <String, Object?>{
        'userId': userId,
        'role': role,
        'activeSite': activeSite,
      };

  factory UserDirectoryEntry.fromJson(Map<String, Object?> json) {
    return UserDirectoryEntry(
      userId: json['userId']! as String,
      role: json['role']! as String,
      activeSite: json['activeSite'] as String?,
    );
  }
}

@immutable
class IdempotencyEntrySummary {
  const IdempotencyEntrySummary({
    required this.actionName,
    required this.principalUserId,
    required this.idempotencyKey,
    required this.expiresAt,
  });
  final String actionName;
  final String? principalUserId;
  final String idempotencyKey;
  final DateTime expiresAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'actionName': actionName,
        'principalUserId': principalUserId,
        'idempotencyKey': idempotencyKey,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory IdempotencyEntrySummary.fromJson(Map<String, Object?> json) {
    return IdempotencyEntrySummary(
      actionName: json['actionName']! as String,
      principalUserId: json['principalUserId'] as String?,
      idempotencyKey: json['idempotencyKey']! as String,
      expiresAt: DateTime.parse(json['expiresAt']! as String),
    );
  }
}

@immutable
class DispatchTrace {
  const DispatchTrace({
    required this.actionInvocationId,
    required this.actionName,
    required this.stages,
  });
  final String actionInvocationId;
  final String actionName;
  final List<String> stages; // e.g. ['lookup OK', 'parse OK', 'authorize DENIED:notGranted']

  Map<String, Object?> toJson() => <String, Object?>{
        'actionInvocationId': actionInvocationId,
        'actionName': actionName,
        'stages': stages,
      };

  factory DispatchTrace.fromJson(Map<String, Object?> json) {
    return DispatchTrace(
      actionInvocationId: json['actionInvocationId']! as String,
      actionName: json['actionName']! as String,
      stages: List<String>.from(json['stages']! as List<Object?>),
    );
  }
}

@immutable
class InspectSnapshot {
  const InspectSnapshot({
    required this.events,
    required this.matrixGrants,
    required this.directory,
    required this.idempotency,
    required this.lastDispatchTrace,
  });

  final List<StoredEventSummary> events;
  final List<MatrixGrant> matrixGrants;
  final List<UserDirectoryEntry> directory;
  final List<IdempotencyEntrySummary> idempotency;
  final DispatchTrace? lastDispatchTrace;

  Map<String, Object?> toJson() => <String, Object?>{
        'events': events.map((e) => e.toJson()).toList(),
        'matrixGrants': matrixGrants.map((g) => g.toJson()).toList(),
        'directory': directory.map((d) => d.toJson()).toList(),
        'idempotency': idempotency.map((i) => i.toJson()).toList(),
        'lastDispatchTrace': lastDispatchTrace?.toJson(),
      };

  factory InspectSnapshot.fromJson(Map<String, Object?> json) {
    return InspectSnapshot(
      events: (json['events']! as List<Object?>)
          .map((e) => StoredEventSummary.fromJson(e! as Map<String, Object?>))
          .toList(),
      matrixGrants: (json['matrixGrants']! as List<Object?>)
          .map((e) => MatrixGrant.fromJson(e! as Map<String, Object?>))
          .toList(),
      directory: (json['directory']! as List<Object?>)
          .map((e) => UserDirectoryEntry.fromJson(e! as Map<String, Object?>))
          .toList(),
      idempotency: (json['idempotency']! as List<Object?>)
          .map((e) => IdempotencyEntrySummary.fromJson(e! as Map<String, Object?>))
          .toList(),
      lastDispatchTrace: json['lastDispatchTrace'] == null
          ? null
          : DispatchTrace.fromJson(json['lastDispatchTrace']! as Map<String, Object?>),
    );
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
flutter test test/wire_types_test.dart
```

Expected: PASS, 6+ tests.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/wire_types.dart test/wire_types_test.dart
git commit -m "[CUR-1192] demo: SessionStart + InspectSnapshot wire types"
```

---

## Phase 2 — Server-side data layer

### Task 4: UserDirectory in-memory map

**Files:**
- Create: `lib/server/user_directory.dart`
- Test: `test/user_directory_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/user_directory_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:action_permissions_demo/server/user_directory.dart';

void main() {
  group('UserDirectory', () {
    test('resolve returns Anon when userId is null', () {
      final dir = UserDirectory();
      final p = dir.resolve(null);
      expect(p.role, 'Anon');
      expect(p.userId, isNull);
      expect(p.activeSite, isNull);
    });

    test('resolve returns Anon when userId is unknown', () {
      final dir = UserDirectory();
      final p = dir.resolve('not-a-user');
      expect(p.role, 'Anon');
    });

    test('resolve returns recorded principal for known userId', () {
      final dir = UserDirectory();
      dir.upsert(
        userId: 'green-user-1',
        role: 'GreenTeam',
        activeSite: 'green-workspace',
      );
      final p = dir.resolve('green-user-1');
      expect(p.role, 'GreenTeam');
      expect(p.userId, 'green-user-1');
      expect(p.activeSite, 'green-workspace');
    });

    test('listEntries returns sorted snapshot', () {
      final dir = UserDirectory();
      dir.upsert(userId: 'b-user', role: 'BlueTeam', activeSite: 'blue-workspace');
      dir.upsert(userId: 'a-user', role: 'Admin', activeSite: null);
      final entries = dir.listEntries();
      expect(entries.map((e) => e.userId).toList(), <String>['a-user', 'b-user']);
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
flutter test test/user_directory_test.dart
```

Expected: FAIL — undefined `UserDirectory`.

- [ ] **Step 3: Implement user_directory.dart**

```dart
// lib/server/user_directory.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00168 (Dispatcher Pipeline) — host-side resolver before pipeline entry.
//
// Server-side userId -> Principal resolver. Seed comes from tool/users.yaml at
// boot via UserDirectorySeedApplier; runtime mutations come from
// ProvisionUserAction via UserDirectoryMaterializer. Anon for any unrecognized
// or null userId.

import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:audited_actions/audited_actions.dart' show Principal;

class UserDirectory {
  final Map<String, _Entry> _entries = <String, _Entry>{};

  Principal resolve(String? userId) {
    if (userId == null) return _anon();
    final entry = _entries[userId];
    if (entry == null) return _anon();
    return Principal(
      role: entry.role,
      userId: userId,
      activeSite: entry.activeSite,
    );
  }

  void upsert({
    required String userId,
    required String role,
    required String? activeSite,
  }) {
    _entries[userId] = _Entry(role: role, activeSite: activeSite);
  }

  bool contains(String userId) => _entries.containsKey(userId);

  List<UserDirectoryEntry> listEntries() {
    final ids = _entries.keys.toList()..sort();
    return ids
        .map((id) => UserDirectoryEntry(
              userId: id,
              role: _entries[id]!.role,
              activeSite: _entries[id]!.activeSite,
            ))
        .toList();
  }

  static Principal _anon() => const Principal(role: 'Anon', userId: null, activeSite: null);
}

class _Entry {
  const _Entry({required this.role, required this.activeSite});
  final String role;
  final String? activeSite;
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
flutter test test/user_directory_test.dart
```

Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/server/user_directory.dart test/user_directory_test.dart
git commit -m "[CUR-1192] demo: UserDirectory in-memory resolver"
```

### Task 5: UserDirectoryMaterializer (folds user_provisioned events)

**Files:**
- Create: `lib/server/user_directory_materializer.dart`
- Test: `test/user_directory_materializer_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/user_directory_materializer_test.dart
// Verifies: REQ-d00174 (matrix view materializer pattern, applied to directory)
import 'package:flutter_test/flutter_test.dart';
import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:action_permissions_demo/server/user_directory_materializer.dart';

void main() {
  group('UserDirectoryMaterializer', () {
    test('REQ-d00174: applies user_provisioned event to directory', () {
      final dir = UserDirectory();
      final m = UserDirectoryMaterializer(directory: dir);
      m.applyDirect(<String, Object?>{
        'userId': 'green-user-3',
        'role': 'GreenTeam',
        'activeSite': 'green-workspace',
      });
      final p = dir.resolve('green-user-3');
      expect(p.role, 'GreenTeam');
      expect(p.activeSite, 'green-workspace');
    });

    test('REQ-d00174: idempotent on replay', () {
      final dir = UserDirectory();
      final m = UserDirectoryMaterializer(directory: dir);
      const payload = <String, Object?>{
        'userId': 'admin-user',
        'role': 'Admin',
        'activeSite': null,
      };
      m.applyDirect(payload);
      m.applyDirect(payload);
      expect(dir.listEntries(), hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
flutter test test/user_directory_materializer_test.dart
```

Expected: FAIL — undefined `UserDirectoryMaterializer`.

- [ ] **Step 3: Implement user_directory_materializer.dart**

```dart
// lib/server/user_directory_materializer.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00174 (Materializer-in-transaction pattern) — applies user_provisioned
//   events to the in-memory UserDirectory; runs inside the events.transaction
//   block as part of EventStore commit (when wired through Materializer
//   protocol from event_sourcing_datastore).
//
// applyDirect() is the bare projection used by tests and the seed applier.
// The Materializer protocol wrapper (subclassing event_sourcing_datastore's
// Materializer) is added in Task 14 when bootstrap.dart wires it up.

import 'package:action_permissions_demo/server/user_directory.dart';

class UserDirectoryMaterializer {
  UserDirectoryMaterializer({required this.directory});

  final UserDirectory directory;

  /// Applies a user_provisioned event payload to the directory.
  /// Idempotent: re-applying with the same userId+role+site is a no-op.
  void applyDirect(Map<String, Object?> payload) {
    final userId = payload['userId']! as String;
    final role = payload['role']! as String;
    final activeSite = payload['activeSite'] as String?;
    directory.upsert(userId: userId, role: role, activeSite: activeSite);
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
flutter test test/user_directory_materializer_test.dart
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/server/user_directory_materializer.dart test/user_directory_materializer_test.dart
git commit -m "[CUR-1192] demo: UserDirectoryMaterializer projects user_provisioned"
```

### Task 6: UserDirectorySeedApplier (YAML on boot)

**Files:**
- Create: `lib/server/user_directory_seed_applier.dart`
- Test: `test/user_directory_seed_applier_test.dart`
- Create: `tool/users.yaml` (seed file used in test fixture path)

- [ ] **Step 1: Write seed YAML**

```yaml
# tool/users.yaml
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00175 — YAML seed pattern, applied to user directory in this demo.
#
# Each entry maps a userId to the role + activeSite the server resolves it to.
# An unrecognized userId always resolves to Anon.

users:
  - userId: admin-user
    role: Admin
    activeSite: null
  - userId: green-user-1
    role: GreenTeam
    activeSite: green-workspace
  - userId: green-user-2
    role: GreenTeam
    activeSite: green-workspace
  - userId: blue-user
    role: BlueTeam
    activeSite: blue-workspace
```

- [ ] **Step 2: Write failing test**

```dart
// test/user_directory_seed_applier_test.dart
// Verifies: REQ-d00175 (seed-applier diff logic, applied to directory)
import 'package:flutter_test/flutter_test.dart';
import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:action_permissions_demo/server/user_directory_materializer.dart';
import 'package:action_permissions_demo/server/user_directory_seed_applier.dart';

void main() {
  group('UserDirectorySeedApplier', () {
    test('REQ-d00175: applies all seed entries to empty directory', () {
      final dir = UserDirectory();
      final mat = UserDirectoryMaterializer(directory: dir);
      final emitted = <Map<String, Object?>>[];
      final applier = UserDirectorySeedApplier(
        directory: dir,
        materializer: mat,
        emit: emitted.add,
      );
      const yaml = '''
users:
  - userId: admin-user
    role: Admin
    activeSite: null
  - userId: green-user-1
    role: GreenTeam
    activeSite: green-workspace
''';
      applier.applyYaml(yaml);
      expect(emitted, hasLength(2));
      expect(dir.contains('admin-user'), isTrue);
      expect(dir.contains('green-user-1'), isTrue);
    });

    test('REQ-d00175: skips entries already in directory (diff)', () {
      final dir = UserDirectory();
      dir.upsert(userId: 'admin-user', role: 'Admin', activeSite: null);
      final mat = UserDirectoryMaterializer(directory: dir);
      final emitted = <Map<String, Object?>>[];
      final applier = UserDirectorySeedApplier(
        directory: dir,
        materializer: mat,
        emit: emitted.add,
      );
      const yaml = '''
users:
  - userId: admin-user
    role: Admin
    activeSite: null
  - userId: green-user-1
    role: GreenTeam
    activeSite: green-workspace
''';
      applier.applyYaml(yaml);
      expect(emitted, hasLength(1));
      expect(emitted.first['userId'], 'green-user-1');
    });
  });
}
```

- [ ] **Step 3: Run test, expect fail**

```bash
flutter test test/user_directory_seed_applier_test.dart
```

Expected: FAIL — undefined `UserDirectorySeedApplier`.

- [ ] **Step 4: Implement seed applier**

```dart
// lib/server/user_directory_seed_applier.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00175 (YAML seed + event-emitting applier) — directory-side analogue
//   of action_permissions's EventSeedApplier. Diffs YAML against the current
//   directory view and emits user_provisioned event payloads for missing
//   entries; the materializer also runs against the same payload to update
//   the in-memory directory.

import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:action_permissions_demo/server/user_directory_materializer.dart';
import 'package:yaml/yaml.dart';

class UserDirectorySeedApplier {
  UserDirectorySeedApplier({
    required this.directory,
    required this.materializer,
    required this.emit,
  });

  final UserDirectory directory;
  final UserDirectoryMaterializer materializer;
  final void Function(Map<String, Object?> payload) emit;

  void applyYaml(String yamlSource) {
    final doc = loadYaml(yamlSource) as YamlMap;
    final users = doc['users'] as YamlList;
    for (final raw in users) {
      final entry = raw as YamlMap;
      final userId = entry['userId'] as String;
      final role = entry['role'] as String;
      final activeSite = entry['activeSite'] as String?;
      if (directory.contains(userId)) continue;
      final payload = <String, Object?>{
        'userId': userId,
        'role': role,
        'activeSite': activeSite,
      };
      emit(payload);
      materializer.applyDirect(payload);
    }
  }
}
```

- [ ] **Step 5: Run test, expect pass**

```bash
flutter test test/user_directory_seed_applier_test.dart
```

Expected: PASS, 2 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/server/user_directory_seed_applier.dart test/user_directory_seed_applier_test.dart tool/users.yaml
git commit -m "[CUR-1192] demo: UserDirectorySeedApplier + users.yaml seed"
```

---

## Phase 3 — Action catalog

> **Convention for Phase 3:** every action follows TDD. Each task has its own test file. Each action's class header carries `// Implements: REQ-d00166-A+B+C+D+E+F` (the Action interface contract assertions). Each test method's first line is `// Verifies: REQ-d00166-X` and the test description starts with the assertion ID.

### Task 7: RequestHelpAction (global, idempotency none, anyone)

**Files:**
- Create: `lib/server/actions/request_help_action.dart`
- Test: `test/actions/request_help_action_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/actions/request_help_action_test.dart
// Verifies: REQ-d00166 (Action interface), REQ-d00170 (idempotency none)
import 'package:flutter_test/flutter_test.dart';
import 'package:action_permissions_demo/server/actions/request_help_action.dart';
import 'package:audited_actions/audited_actions.dart';

void main() {
  group('RequestHelpAction', () {
    final action = RequestHelpAction();

    test('REQ-d00166-A: declares name help_request and global help.ask', () {
      expect(action.name, 'RequestHelpAction');
      expect(action.permissions, contains(const Permission('help.ask', scope: ScopeClass.global)));
      expect(action.idempotency, Idempotency.none);
    });

    test('REQ-d00166-C: parseInput accepts {message} and rejects garbage', () {
      final parsed = action.parseInput(<String, Object?>{'message': 'help me'});
      expect(parsed.message, 'help me');
      expect(
        () => action.parseInput(<String, Object?>{'wrong_field': 1}),
        throwsA(isA<Exception>()),
      );
    });

    test('REQ-d00166-D: validate rejects empty message', () {
      expect(
        () => action.validate(const HelpInput(message: '')),
        throwsA(isA<ValidationError>()),
      );
    });

    test('REQ-d00166-E: execute emits one help_request event', () async {
      final ctx = ActionContext(
        principal: const Principal(role: 'Anon', userId: null, activeSite: null),
        // ... whatever ActionContext requires from the lib (security details, etc.)
      );
      final result = await action.execute(const HelpInput(message: 'help'), ctx);
      expect(result.events, hasLength(1));
      expect(result.events.first.eventType, 'help_request');
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
flutter test test/actions/request_help_action_test.dart
```

Expected: FAIL — undefined `RequestHelpAction`.

- [ ] **Step 3: Implement request_help_action.dart**

```dart
// lib/server/actions/request_help_action.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166-A+B+C+D+E+F — Action interface contract.
//   REQ-d00170 (Idempotency Contract) — idempotency.none policy.

import 'package:audited_actions/audited_actions.dart';

class HelpInput {
  const HelpInput({required this.message});
  final String message;
}

class HelpResult {
  const HelpResult({required this.helpTicketId});
  final String helpTicketId;
  Map<String, Object?> toJson() => <String, Object?>{'helpTicketId': helpTicketId};
}

class RequestHelpAction extends Action<HelpInput, HelpResult> {
  @override
  String get name => 'RequestHelpAction';

  @override
  String get description => 'Anyone (including Anon) requests help; emits one help_request event.';

  @override
  Set<Permission> get permissions =>
      <Permission>{const Permission('help.ask', scope: ScopeClass.global)};

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  HelpInput parseInput(Map<String, Object?> raw) {
    final message = raw['message'];
    if (message is! String) {
      throw const FormatException('RequestHelpAction expects "message": String');
    }
    return HelpInput(message: message);
  }

  @override
  void validate(HelpInput input) {
    if (input.message.trim().isEmpty) {
      throw ValidationError('message must be non-empty');
    }
  }

  @override
  Future<ExecutionResult<HelpResult>> execute(HelpInput input, ActionContext ctx) async {
    // The events lib generates eventIds; aggregateId here is a fresh ticket id.
    final ticketId = ctx.newAggregateId();
    return ExecutionResult<HelpResult>(
      result: HelpResult(helpTicketId: ticketId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'help_ticket',
          aggregateId: ticketId,
          entryType: 'help_request',
          eventType: 'help_request',
          data: <String, Object?>{'message': input.message},
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
flutter test test/actions/request_help_action_test.dart
```

Expected: PASS, 4 tests. (If `ActionContext.newAggregateId` doesn't exist on the library, use `Uuid().v4()` directly via `package:uuid` and remove the assumption — adjust per the actual library shape from prerequisites.)

- [ ] **Step 5: Commit**

```bash
git add lib/server/actions/request_help_action.dart test/actions/request_help_action_test.dart
git commit -m "[CUR-1192] demo: RequestHelpAction (global, anyone)"
```

### Task 8: EditGreenNoteAction (site-scoped, optional idempotency)

**Files:**
- Create: `lib/server/actions/edit_green_note_action.dart`
- Test: `test/actions/edit_green_note_action_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/actions/edit_green_note_action_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:action_permissions_demo/server/actions/edit_green_note_action.dart';
import 'package:audited_actions/audited_actions.dart';

void main() {
  group('EditGreenNoteAction', () {
    final action = EditGreenNoteAction();

    test('REQ-d00166-A: declares site-scoped notes.write.green', () {
      expect(action.permissions, contains(
        const Permission('notes.write.green', scope: ScopeClass.site),
      ));
      expect(action.idempotency, Idempotency.optional);
    });

    test('REQ-d00166-D: validate rejects empty title', () {
      expect(
        () => action.validate(const EditGreenNoteInput(noteId: 'n1', title: '', body: 'x')),
        throwsA(isA<ValidationError>()),
      );
    });

    test('REQ-d00166-E: execute emits demo_note event with workspace=green', () async {
      final ctx = ActionContext(
        principal: const Principal(
          role: 'GreenTeam',
          userId: 'green-user-1',
          activeSite: 'green-workspace',
        ),
      );
      final result = await action.execute(
        const EditGreenNoteInput(noteId: 'n1', title: 't', body: 'b'),
        ctx,
      );
      expect(result.events.first.eventType, 'demo_note');
      expect(result.events.first.data['workspace'], 'green');
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
flutter test test/actions/edit_green_note_action_test.dart
```

Expected: FAIL — undefined `EditGreenNoteAction`.

- [ ] **Step 3: Implement edit_green_note_action.dart**

```dart
// lib/server/actions/edit_green_note_action.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166 — Action interface contract.
//   REQ-d00170 — Idempotency.optional policy.
//   REQ-d00172 — site-scoped permission (ScopeClass.site).

import 'package:audited_actions/audited_actions.dart';

class EditGreenNoteInput {
  const EditGreenNoteInput({required this.noteId, required this.title, required this.body});
  final String noteId;
  final String title;
  final String body;
}

class EditGreenNoteResult {
  const EditGreenNoteResult({required this.noteId});
  final String noteId;
  Map<String, Object?> toJson() => <String, Object?>{'noteId': noteId};
}

class EditGreenNoteAction extends Action<EditGreenNoteInput, EditGreenNoteResult> {
  @override
  String get name => 'EditGreenNoteAction';

  @override
  String get description => 'GreenTeam edits a note in green-workspace.';

  @override
  Set<Permission> get permissions =>
      <Permission>{const Permission('notes.write.green', scope: ScopeClass.site)};

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  EditGreenNoteInput parseInput(Map<String, Object?> raw) {
    final id = raw['noteId'];
    final t = raw['title'];
    final b = raw['body'];
    if (id is! String || t is! String || b is! String) {
      throw const FormatException('expects {noteId, title, body}: String');
    }
    return EditGreenNoteInput(noteId: id, title: t, body: b);
  }

  @override
  void validate(EditGreenNoteInput input) {
    if (input.title.trim().isEmpty) throw ValidationError('title required');
    if (input.noteId.trim().isEmpty) throw ValidationError('noteId required');
  }

  @override
  Future<ExecutionResult<EditGreenNoteResult>> execute(
    EditGreenNoteInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<EditGreenNoteResult>(
      result: EditGreenNoteResult(noteId: input.noteId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'DiaryEntry',
          aggregateId: input.noteId,
          entryType: 'demo_note',
          eventType: 'demo_note',
          data: <String, Object?>{
            'title': input.title,
            'body': input.body,
            'workspace': 'green',
          },
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
flutter test test/actions/edit_green_note_action_test.dart
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/server/actions/edit_green_note_action.dart test/actions/edit_green_note_action_test.dart
git commit -m "[CUR-1192] demo: EditGreenNoteAction (site, GreenTeam)"
```

### Task 9: EditBlueNoteAction (site-scoped, optional idempotency, BlueTeam)

**Files:**
- Create: `lib/server/actions/edit_blue_note_action.dart`
- Test: `test/actions/edit_blue_note_action_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/actions/edit_blue_note_action_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:action_permissions_demo/server/actions/edit_blue_note_action.dart';
import 'package:audited_actions/audited_actions.dart';

void main() {
  group('EditBlueNoteAction', () {
    final action = EditBlueNoteAction();

    test('REQ-d00166-A: declares site-scoped notes.write.blue', () {
      expect(action.permissions, contains(
        const Permission('notes.write.blue', scope: ScopeClass.site),
      ));
      expect(action.idempotency, Idempotency.optional);
    });

    test('REQ-d00166-D: validate rejects empty title', () {
      expect(
        () => action.validate(const EditBlueNoteInput(noteId: 'n1', title: '', body: 'x')),
        throwsA(isA<ValidationError>()),
      );
    });

    test('REQ-d00166-E: execute emits demo_note event with workspace=blue', () async {
      final ctx = ActionContext(
        principal: const Principal(
          role: 'BlueTeam',
          userId: 'blue-user',
          activeSite: 'blue-workspace',
        ),
      );
      final result = await action.execute(
        const EditBlueNoteInput(noteId: 'n1', title: 't', body: 'b'),
        ctx,
      );
      expect(result.events.first.eventType, 'demo_note');
      expect(result.events.first.data['workspace'], 'blue');
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
flutter test test/actions/edit_blue_note_action_test.dart
```

Expected: FAIL — undefined `EditBlueNoteAction`.

- [ ] **Step 3: Implement edit_blue_note_action.dart**

```dart
// lib/server/actions/edit_blue_note_action.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166 — Action interface contract.
//   REQ-d00170 — Idempotency.optional policy.
//   REQ-d00172 — site-scoped permission (ScopeClass.site).

import 'package:audited_actions/audited_actions.dart';

class EditBlueNoteInput {
  const EditBlueNoteInput({required this.noteId, required this.title, required this.body});
  final String noteId;
  final String title;
  final String body;
}

class EditBlueNoteResult {
  const EditBlueNoteResult({required this.noteId});
  final String noteId;
  Map<String, Object?> toJson() => <String, Object?>{'noteId': noteId};
}

class EditBlueNoteAction extends Action<EditBlueNoteInput, EditBlueNoteResult> {
  @override
  String get name => 'EditBlueNoteAction';

  @override
  String get description => 'BlueTeam edits a note in blue-workspace.';

  @override
  Set<Permission> get permissions =>
      <Permission>{const Permission('notes.write.blue', scope: ScopeClass.site)};

  @override
  Idempotency get idempotency => Idempotency.optional;

  @override
  EditBlueNoteInput parseInput(Map<String, Object?> raw) {
    final id = raw['noteId'];
    final t = raw['title'];
    final b = raw['body'];
    if (id is! String || t is! String || b is! String) {
      throw const FormatException('expects {noteId, title, body}: String');
    }
    return EditBlueNoteInput(noteId: id, title: t, body: b);
  }

  @override
  void validate(EditBlueNoteInput input) {
    if (input.title.trim().isEmpty) throw ValidationError('title required');
    if (input.noteId.trim().isEmpty) throw ValidationError('noteId required');
  }

  @override
  Future<ExecutionResult<EditBlueNoteResult>> execute(
    EditBlueNoteInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<EditBlueNoteResult>(
      result: EditBlueNoteResult(noteId: input.noteId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'DiaryEntry',
          aggregateId: input.noteId,
          entryType: 'demo_note',
          eventType: 'demo_note',
          data: <String, Object?>{
            'title': input.title,
            'body': input.body,
            'workspace': 'blue',
          },
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
flutter test test/actions/edit_blue_note_action_test.dart
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/server/actions/edit_blue_note_action.dart test/actions/edit_blue_note_action_test.dart
git commit -m "[CUR-1192] demo: EditBlueNoteAction (site, BlueTeam)"
```

### Task 10: PressGreenButtonAction (site, idempotency none)

**Files:**
- Create: `lib/server/actions/press_green_button_action.dart`
- Test: `test/actions/press_green_button_action_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/actions/press_green_button_action_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:action_permissions_demo/server/actions/press_green_button_action.dart';
import 'package:audited_actions/audited_actions.dart';

void main() {
  group('PressGreenButtonAction', () {
    final action = PressGreenButtonAction();

    test('REQ-d00166-A: declares site-scoped buttons.press.green, idempotency none', () {
      expect(action.name, 'PressGreenButtonAction');
      expect(action.permissions, contains(
        const Permission('buttons.press.green', scope: ScopeClass.site),
      ));
      expect(action.idempotency, Idempotency.none);
    });

    test('REQ-d00166-C: parseInput accepts empty map', () {
      expect(action.parseInput(const <String, Object?>{}), isA<PressGreenInput>());
    });

    test('REQ-d00166-E: execute emits green_button_pressed event', () async {
      final ctx = ActionContext(
        principal: const Principal(
          role: 'GreenTeam',
          userId: 'green-user-1',
          activeSite: 'green-workspace',
        ),
      );
      final result = await action.execute(const PressGreenInput(), ctx);
      expect(result.events, hasLength(1));
      expect(result.events.first.eventType, 'green_button_pressed');
      expect(result.events.first.aggregateType, 'GreenButtonPressed');
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
flutter test test/actions/press_green_button_action_test.dart
```

Expected: FAIL — undefined `PressGreenButtonAction`.

- [ ] **Step 3: Implement press_green_button_action.dart**

```dart
// lib/server/actions/press_green_button_action.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166 — Action interface contract.
//   REQ-d00170 — Idempotency.none policy.
//   REQ-d00172 — site-scoped permission.

import 'package:audited_actions/audited_actions.dart';

class PressGreenInput {
  const PressGreenInput();
}

class PressGreenResult {
  const PressGreenResult({required this.eventId});
  final String eventId;
  Map<String, Object?> toJson() => <String, Object?>{'eventId': eventId};
}

class PressGreenButtonAction extends Action<PressGreenInput, PressGreenResult> {
  @override
  String get name => 'PressGreenButtonAction';

  @override
  String get description => 'GreenTeam presses the green button (site-scoped).';

  @override
  Set<Permission> get permissions =>
      <Permission>{const Permission('buttons.press.green', scope: ScopeClass.site)};

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  PressGreenInput parseInput(Map<String, Object?> raw) => const PressGreenInput();

  @override
  void validate(PressGreenInput input) {
    // No fields to validate.
  }

  @override
  Future<ExecutionResult<PressGreenResult>> execute(PressGreenInput input, ActionContext ctx) async {
    final id = ctx.newAggregateId();
    return ExecutionResult<PressGreenResult>(
      result: PressGreenResult(eventId: id),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'GreenButtonPressed',
          aggregateId: id,
          entryType: 'green_button_pressed',
          eventType: 'green_button_pressed',
          data: const <String, Object?>{},
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
flutter test test/actions/press_green_button_action_test.dart
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/server/actions/press_green_button_action.dart test/actions/press_green_button_action_test.dart
git commit -m "[CUR-1192] demo: PressGreenButtonAction (site, GreenTeam)"
```

### Task 11: PressBlueButtonAction (site, idempotency none, BlueTeam)

**Files:**
- Create: `lib/server/actions/press_blue_button_action.dart`
- Test: `test/actions/press_blue_button_action_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/actions/press_blue_button_action_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:action_permissions_demo/server/actions/press_blue_button_action.dart';
import 'package:audited_actions/audited_actions.dart';

void main() {
  group('PressBlueButtonAction', () {
    final action = PressBlueButtonAction();

    test('REQ-d00166-A: declares site-scoped buttons.press.blue, idempotency none', () {
      expect(action.name, 'PressBlueButtonAction');
      expect(action.permissions, contains(
        const Permission('buttons.press.blue', scope: ScopeClass.site),
      ));
      expect(action.idempotency, Idempotency.none);
    });

    test('REQ-d00166-E: execute emits blue_button_pressed event', () async {
      final ctx = ActionContext(
        principal: const Principal(
          role: 'BlueTeam',
          userId: 'blue-user',
          activeSite: 'blue-workspace',
        ),
      );
      final result = await action.execute(const PressBlueInput(), ctx);
      expect(result.events, hasLength(1));
      expect(result.events.first.eventType, 'blue_button_pressed');
      expect(result.events.first.aggregateType, 'BlueButtonPressed');
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
flutter test test/actions/press_blue_button_action_test.dart
```

Expected: FAIL — undefined `PressBlueButtonAction`.

- [ ] **Step 3: Implement press_blue_button_action.dart**

```dart
// lib/server/actions/press_blue_button_action.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166 — Action interface contract.
//   REQ-d00170 — Idempotency.none policy.
//   REQ-d00172 — site-scoped permission.

import 'package:audited_actions/audited_actions.dart';

class PressBlueInput {
  const PressBlueInput();
}

class PressBlueResult {
  const PressBlueResult({required this.eventId});
  final String eventId;
  Map<String, Object?> toJson() => <String, Object?>{'eventId': eventId};
}

class PressBlueButtonAction extends Action<PressBlueInput, PressBlueResult> {
  @override
  String get name => 'PressBlueButtonAction';

  @override
  String get description => 'BlueTeam presses the blue button (site-scoped).';

  @override
  Set<Permission> get permissions =>
      <Permission>{const Permission('buttons.press.blue', scope: ScopeClass.site)};

  @override
  Idempotency get idempotency => Idempotency.none;

  @override
  PressBlueInput parseInput(Map<String, Object?> raw) => const PressBlueInput();

  @override
  void validate(PressBlueInput input) {
    // No fields to validate.
  }

  @override
  Future<ExecutionResult<PressBlueResult>> execute(PressBlueInput input, ActionContext ctx) async {
    final id = ctx.newAggregateId();
    return ExecutionResult<PressBlueResult>(
      result: PressBlueResult(eventId: id),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'BlueButtonPressed',
          aggregateId: id,
          entryType: 'blue_button_pressed',
          eventType: 'blue_button_pressed',
          data: const <String, Object?>{},
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
flutter test test/actions/press_blue_button_action_test.dart
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/server/actions/press_blue_button_action.dart test/actions/press_blue_button_action_test.dart
git commit -m "[CUR-1192] demo: PressBlueButtonAction (site, BlueTeam)"
```

### Task 12: PressRedAlarmAction (self, idempotency required)

**Files:**
- Create: `lib/server/actions/press_red_alarm_action.dart`
- Test: `test/actions/press_red_alarm_action_test.dart`

- [ ] **Step 1: Write failing test** — assert: name `PressRedAlarmAction`, permission `buttons.press.red` with `ScopeClass.self`, idempotency `required`, takes `{reason: String}` input, emits `red_button_pressed` event with `reason` in data.

- [ ] **Step 2: Run, expect fail.**

- [ ] **Step 3: Implement.**

```dart
// lib/server/actions/press_red_alarm_action.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166 — Action interface contract.
//   REQ-d00170-B — Idempotency.required: dispatcher returns
//   parseDenied(MissingIdempotencyKeyError) when caller omits the key.

import 'package:audited_actions/audited_actions.dart';

class RedAlarmInput {
  const RedAlarmInput({required this.reason});
  final String reason;
}

class RedAlarmResult {
  const RedAlarmResult({required this.alarmId});
  final String alarmId;
  Map<String, Object?> toJson() => <String, Object?>{'alarmId': alarmId};
}

class PressRedAlarmAction extends Action<RedAlarmInput, RedAlarmResult> {
  @override
  String get name => 'PressRedAlarmAction';

  @override
  String get description => 'GreenTeam or BlueTeam fires the red alarm. Self-scoped, idempotency required.';

  @override
  Set<Permission> get permissions =>
      <Permission>{const Permission('buttons.press.red', scope: ScopeClass.self)};

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  RedAlarmInput parseInput(Map<String, Object?> raw) {
    final r = raw['reason'];
    if (r is! String) throw const FormatException('expects {reason}: String');
    return RedAlarmInput(reason: r);
  }

  @override
  void validate(RedAlarmInput input) {
    if (input.reason.trim().isEmpty) throw ValidationError('reason required');
  }

  @override
  Future<ExecutionResult<RedAlarmResult>> execute(RedAlarmInput input, ActionContext ctx) async {
    final id = ctx.newAggregateId();
    return ExecutionResult<RedAlarmResult>(
      result: RedAlarmResult(alarmId: id),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'RedButtonPressed',
          aggregateId: id,
          entryType: 'red_button_pressed',
          eventType: 'red_button_pressed',
          data: <String, Object?>{'reason': input.reason},
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run, expect pass.**

- [ ] **Step 5: Commit** `[CUR-1192] demo: PressRedAlarmAction (self, required idempotency)`

### Task 13: ProvisionUserAction (Admin-only, system-admin permission)

**Files:**
- Create: `lib/server/actions/provision_user_action.dart`
- Test: `test/actions/provision_user_action_test.dart`

- [ ] **Step 1: Write failing test** — assert: name `ProvisionUserAction`, permission `users.provision` global with idempotency required; validate rejects when userId already exists in directory; execute emits one `user_provisioned` event.

- [ ] **Step 2: Run, expect fail.**

- [ ] **Step 3: Implement.**

```dart
// lib/server/actions/provision_user_action.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00166 — Action interface contract.
//   REQ-d00170 — Idempotency.required.
//
// Admin-only system-admin action. Validates uniqueness against the current
// directory view (passed in ctx.read or via injected directory accessor).

import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:audited_actions/audited_actions.dart';

class ProvisionUserInput {
  const ProvisionUserInput({
    required this.userId,
    required this.role,
    required this.activeSite,
  });
  final String userId;
  final String role;
  final String? activeSite;
}

class ProvisionUserResult {
  const ProvisionUserResult({required this.userId});
  final String userId;
  Map<String, Object?> toJson() => <String, Object?>{'userId': userId};
}

class ProvisionUserAction extends Action<ProvisionUserInput, ProvisionUserResult> {
  ProvisionUserAction({required this.directory});
  final UserDirectory directory;

  @override
  String get name => 'ProvisionUserAction';

  @override
  String get description => 'Admin provisions a new user; emits one user_provisioned event.';

  @override
  Set<Permission> get permissions =>
      <Permission>{const Permission('users.provision', scope: ScopeClass.global)};

  @override
  Idempotency get idempotency => Idempotency.required;

  @override
  ProvisionUserInput parseInput(Map<String, Object?> raw) {
    final id = raw['userId'];
    final r = raw['role'];
    final s = raw['activeSite'];
    if (id is! String || r is! String) {
      throw const FormatException('expects {userId, role}: String, optional {activeSite}: String?');
    }
    return ProvisionUserInput(userId: id, role: r, activeSite: s as String?);
  }

  @override
  void validate(ProvisionUserInput input) {
    if (input.userId.trim().isEmpty) throw ValidationError('userId required');
    if (input.role.trim().isEmpty) throw ValidationError('role required');
    if (directory.contains(input.userId)) {
      throw ValidationError('userId already provisioned: ${input.userId}');
    }
  }

  @override
  Future<ExecutionResult<ProvisionUserResult>> execute(
    ProvisionUserInput input,
    ActionContext ctx,
  ) async {
    return ExecutionResult<ProvisionUserResult>(
      result: ProvisionUserResult(userId: input.userId),
      events: <EventDraft>[
        EventDraft(
          aggregateType: 'user_directory',
          aggregateId: input.userId,
          entryType: 'user_provisioned',
          eventType: 'user_provisioned',
          data: <String, Object?>{
            'userId': input.userId,
            'role': input.role,
            'activeSite': input.activeSite,
          },
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run, expect pass.**

- [ ] **Step 5: Commit** `[CUR-1192] demo: ProvisionUserAction (Admin, global, required)`

---

## Phase 4 — Server bootstrap, routes, projection

### Task 14: Action catalog registration

**Files:**
- Create: `lib/server/action_catalog.dart`

- [ ] **Step 1: Implement registration helper**

```dart
// lib/server/action_catalog.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00167 (ActionRegistry and Bootstrap) — collision-free registration of
//   all 7 demo actions.

import 'package:action_permissions_demo/server/actions/edit_blue_note_action.dart';
import 'package:action_permissions_demo/server/actions/edit_green_note_action.dart';
import 'package:action_permissions_demo/server/actions/press_blue_button_action.dart';
import 'package:action_permissions_demo/server/actions/press_green_button_action.dart';
import 'package:action_permissions_demo/server/actions/press_red_alarm_action.dart';
import 'package:action_permissions_demo/server/actions/provision_user_action.dart';
import 'package:action_permissions_demo/server/actions/request_help_action.dart';
import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:audited_actions/audited_actions.dart';

ActionRegistry buildDemoActionRegistry({required UserDirectory directory}) {
  final registry = ActionRegistry();
  registry.register(RequestHelpAction());
  registry.register(EditGreenNoteAction());
  registry.register(EditBlueNoteAction());
  registry.register(PressGreenButtonAction());
  registry.register(PressBlueButtonAction());
  registry.register(PressRedAlarmAction());
  registry.register(ProvisionUserAction(directory: directory));
  return registry;
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze
```

Expected: clean.

- [ ] **Step 3: Commit** `[CUR-1192] demo: action catalog registration`

### Task 15: bootstrap.dart — composes everything

**Files:**
- Create: `lib/server/bootstrap.dart`
- Create: `tool/permissions.yaml`

- [ ] **Step 1: Write tool/permissions.yaml**

```yaml
# tool/permissions.yaml
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00175 — YAML seed for the role-permission matrix.

permissions:
  - role: Admin
    permission: audit.read.all
    scope: global
  - role: Admin
    permission: users.provision
    scope: global
  - role: GreenTeam
    permission: help.ask
    scope: global
  - role: GreenTeam
    permission: notes.write.green
    scope: site
  - role: GreenTeam
    permission: buttons.press.green
    scope: site
  - role: GreenTeam
    permission: buttons.press.red
    scope: self
  - role: BlueTeam
    permission: help.ask
    scope: global
  - role: BlueTeam
    permission: notes.write.blue
    scope: site
  - role: BlueTeam
    permission: buttons.press.blue
    scope: site
  - role: BlueTeam
    permission: buttons.press.red
    scope: self
  - role: Anon
    permission: help.ask
    scope: global
```

- [ ] **Step 2: Implement bootstrap.dart**

```dart
// lib/server/bootstrap.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00167 (Bootstrap) — composes ActionDispatcher with all dependencies.
//   REQ-d00175 (Seed appliers) — runs both YAML seed appliers in deterministic order.

import 'dart:io';

import 'package:action_permissions/action_permissions.dart';
import 'package:action_permissions_demo/server/action_catalog.dart';
import 'package:action_permissions_demo/server/user_directory.dart';
import 'package:action_permissions_demo/server/user_directory_materializer.dart';
import 'package:action_permissions_demo/server/user_directory_seed_applier.dart';
import 'package:audited_actions/audited_actions.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

class DemoServerComponents {
  DemoServerComponents({
    required this.dispatcher,
    required this.eventStore,
    required this.directory,
    required this.permissionsPolicy,
    required this.idempotencyStore,
  });

  final ActionDispatcher dispatcher;
  final EventStore eventStore;
  final UserDirectory directory;
  final AuthorizationPolicy permissionsPolicy;
  final IdempotencyStore idempotencyStore;
}

Future<DemoServerComponents> bootstrapDemoServer({
  required String dbPath,
  required bool ephemeral,
  required String permissionsYaml,
  required String usersYaml,
}) async {
  final Database db = ephemeral
      ? await databaseFactoryMemory.openDatabase('demo')
      : await databaseFactoryIo.openDatabase(dbPath);

  final backend = SembastBackend(database: db);
  final directory = UserDirectory();
  final directoryMaterializer = UserDirectoryMaterializer(directory: directory);

  // Compose EventStore with both materializers (matrix + directory).
  final eventStore = await bootstrapEventSourcingDatastore(
    backend: backend,
    materializers: <Materializer>[
      const RolePermissionGrantsMaterializer(),
      DirectoryMaterializerAdapter(directoryMaterializer),
    ],
  );

  // Run permission seed applier (action_permissions library).
  final policyBootstrap = await bootstrapActionPermissions(
    eventStore: eventStore,
    yamlSource: permissionsYaml,
  );
  final policy = policyBootstrap.policy;

  // Run user-directory seed applier (this demo's own seed).
  final dirSeedApplier = UserDirectorySeedApplier(
    directory: directory,
    materializer: directoryMaterializer,
    emit: (payload) async {
      await eventStore.appendWithSecurity(
        EventDraft(
          aggregateType: 'user_directory',
          aggregateId: payload['userId']! as String,
          entryType: 'user_provisioned',
          eventType: 'user_provisioned',
          data: payload,
        ),
        // Trusted in-process automation.
        initiator: const Initiator.automation(service: 'user_directory_seed'),
      );
    },
  );
  dirSeedApplier.applyYaml(usersYaml);

  // Idempotency + dispatcher.
  final idempotencyStore = InMemoryIdempotencyStore();
  final dispatcher = bootstrapAuditedActions(
    events: eventStore,
    authorization: policy,
    idempotency: idempotencyStore,
    actions: buildDemoActionRegistry(directory: directory).all,
  );

  return DemoServerComponents(
    dispatcher: dispatcher,
    eventStore: eventStore,
    directory: directory,
    permissionsPolicy: policy,
    idempotencyStore: idempotencyStore,
  );
}

/// Adapter so UserDirectoryMaterializer (demo-side) can be passed through the
/// Materializer protocol expected by event_sourcing_datastore. Filters by
/// aggregateType and forwards user_provisioned events.
class DirectoryMaterializerAdapter extends Materializer {
  DirectoryMaterializerAdapter(this._directoryMaterializer);
  final UserDirectoryMaterializer _directoryMaterializer;

  @override
  String get viewName => 'user_directory';

  @override
  bool appliesTo(StoredEvent event) => event.aggregateType == 'user_directory';

  @override
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required EntryTypeDefinition def,
  }) async {
    _directoryMaterializer.applyDirect(event.data);
  }
}
```

- [ ] **Step 3: Run analyze**

```bash
dart analyze
```

Expected: clean (assumes prerequisite library symbols exist as named).

- [ ] **Step 4: Commit** `[CUR-1192] demo: bootstrap composes EventStore+materializers+dispatcher`

### Task 16: demo_state_projection.dart (polling impl)

**Files:**
- Create: `lib/server/demo_state_projection.dart`
- Create: `lib/server/inspect_snapshot.dart`

- [ ] **Step 1: Implement DemoStateProjection interface + polling impl**

```dart
// lib/server/demo_state_projection.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00168 (Dispatcher Pipeline) — exposes pipeline state to inspector pane.
//
// PollingDemoStateProjection queries the event store + matrix view + directory
// view + idempotency store on each call. CUR-1154 Phase 4.12's reactive read
// layer (watchEvents/watchEntry/watchFifo) provides the future ReactiveDemoStateProjection
// swap target.

import 'package:action_permissions_demo/server/bootstrap.dart';
import 'package:action_permissions_demo/server/inspect_snapshot.dart';
import 'package:action_permissions_demo/shared/wire_types.dart';

abstract class DemoStateProjection {
  Future<InspectSnapshot> snapshot();
}

class PollingDemoStateProjection implements DemoStateProjection {
  PollingDemoStateProjection({required this.components, required this.lastTraceProvider});

  final DemoServerComponents components;
  final DispatchTrace? Function() lastTraceProvider;

  @override
  Future<InspectSnapshot> snapshot() async {
    return InspectSnapshot(
      events: await collectEventSummaries(components.eventStore, limit: 200),
      matrixGrants: await collectMatrixGrants(components.eventStore),
      directory: components.directory.listEntries(),
      idempotency: await collectIdempotencyEntries(components.idempotencyStore),
      lastDispatchTrace: lastTraceProvider(),
    );
  }
}
```

```dart
// lib/server/inspect_snapshot.dart
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:audited_actions/audited_actions.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

Future<List<StoredEventSummary>> collectEventSummaries(
  EventStore store, {
  required int limit,
}) async {
  final events = await store.findAllEvents(limit: limit);
  return events
      .map((e) => StoredEventSummary(
            eventId: e.eventId,
            eventType: e.eventType,
            aggregateType: e.aggregateType,
            aggregateId: e.aggregateId,
            actionInvocationId: (e.metadata['action_invocation_id'] as String?) ?? '',
            initiatorUserId: e.initiator.userId,
            initiatorRole: e.initiator.role ?? 'Unknown',
          ))
      .toList();
}

Future<List<MatrixGrant>> collectMatrixGrants(EventStore store) async {
  // Query the role_permission_grants materialized view directly.
  final rows = await store.backend.findEntries(
    viewName: 'role_permission_grants',
  );
  return rows
      .map((r) => MatrixGrant(
            role: r.data['role']! as String,
            permission: r.data['permissionName']! as String,
          ))
      .toList();
}

Future<List<IdempotencyEntrySummary>> collectIdempotencyEntries(IdempotencyStore store) async {
  final all = await store.listAll();
  return all
      .map((e) => IdempotencyEntrySummary(
            actionName: e.actionName,
            principalUserId: e.principalUserId,
            idempotencyKey: e.idempotencyKey,
            expiresAt: e.expiresAt,
          ))
      .toList();
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze
```

Expected: clean.

- [ ] **Step 3: Commit** `[CUR-1192] demo: PollingDemoStateProjection + inspect snapshot collectors`

### Task 17: demo_routes.dart (shelf handlers)

**Files:**
- Create: `lib/server/demo_routes.dart`

- [ ] **Step 1: Implement shelf routes**

```dart
// lib/server/demo_routes.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00167, REQ-d00168 — bootstrap and dispatch entry over HTTP.

import 'dart:async';
import 'dart:convert';

import 'package:action_permissions/action_permissions.dart';
import 'package:action_permissions_demo/server/bootstrap.dart';
import 'package:action_permissions_demo/server/demo_state_projection.dart';
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:audited_actions/audited_actions.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class DemoRoutes {
  DemoRoutes({
    required this.components,
    required this.projection,
  });

  final DemoServerComponents components;
  final DemoStateProjection projection;

  DispatchTrace? _lastTrace;

  Handler get handler {
    final router = Router()
      ..get('/healthz', _healthz)
      ..post('/session/start', _sessionStart)
      ..post('/dispatch', _dispatch)
      ..get('/_demo/inspect', _inspect)
      ..get('/_demo/audit', _audit)
      ..post('/_demo/reset', _reset);
    return router.call;
  }

  DispatchTrace? lastTrace() => _lastTrace;

  Future<Response> _healthz(Request _) async => Response.ok('ok');

  Future<Response> _sessionStart(Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, Object?>;
    final ssReq = SessionStartRequest.fromJson(body);
    final principal = components.directory.resolve(ssReq.userId);
    final perms = await components.permissionsPolicy.permissionsFor(principal);
    final response = SessionStartResponse(
      principalRole: principal.role,
      principalUserId: principal.userId,
      principalActiveSite: principal.activeSite,
      snapshotPermissions: perms.map((p) => p.name).toList()..sort(),
    );
    return Response.ok(jsonEncode(response.toJson()), headers: _jsonHeaders);
  }

  Future<Response> _dispatch(Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, Object?>;
    final dReq = DispatchRequest.fromJson(body);
    final principal = components.directory.resolve(dReq.userId);
    final ctx = ActionContext(principal: principal);

    // Capture stages for the inspector.
    final stages = <String>[];
    final result = await components.dispatcher.dispatch(
      dReq.actionName,
      dReq.rawInput,
      ctx,
      idempotencyKey: dReq.idempotencyKey,
      stageRecorder: stages.add,
    );

    _lastTrace = DispatchTrace(
      actionInvocationId: result.actionInvocationId,
      actionName: dReq.actionName,
      stages: stages,
    );

    final response = _toWireResponse(result);
    return Response.ok(jsonEncode(response.toJson()), headers: _jsonHeaders);
  }

  Future<Response> _inspect(Request _) async {
    final snap = await projection.snapshot();
    return Response.ok(jsonEncode(snap.toJson()), headers: _jsonHeaders);
  }

  Future<Response> _audit(Request req) async {
    // Gate by audit.read.all permission asserted in headers (demo-grade).
    final claimedUserId = req.headers['x-demo-user'];
    final principal = components.directory.resolve(claimedUserId);
    final perms = await components.permissionsPolicy.permissionsFor(principal);
    if (!perms.any((p) => p.name == 'audit.read.all')) {
      return Response.forbidden('audit.read.all required');
    }
    final events = await collectEventSummaries(components.eventStore, limit: 1000);
    return Response.ok(jsonEncode(events.map((e) => e.toJson()).toList()),
        headers: _jsonHeaders);
  }

  Future<Response> _reset(Request _) async {
    // Wipe + reseed: implemented at Task 35 (reset walkthrough).
    return Response.notFound('reset implemented in Task 35');
  }

  static const Map<String, String> _jsonHeaders = <String, String>{
    'content-type': 'application/json',
  };

  DispatchResponse _toWireResponse(DispatchResult result) {
    return switch (result) {
      DispatchSuccess(:final actionInvocationId, :final emittedEventIds, :final result) =>
        DispatchResponseSuccess(
          actionInvocationId: actionInvocationId,
          emittedEventIds: emittedEventIds,
          result: _resultToJson(result),
        ),
      DispatchUnknownAction(:final actionInvocationId, :final requestedName) =>
        DispatchResponseDenied(
          denialKind: 'unknown_action',
          actionInvocationId: actionInvocationId,
          errorClass: 'UnknownActionError',
          errorMessageSanitized: 'unknown action: $requestedName',
          requestedName: requestedName,
        ),
      DispatchParseDenied(:final actionInvocationId, :final error) =>
        DispatchResponseDenied(
          denialKind: 'parse_denied',
          actionInvocationId: actionInvocationId,
          errorClass: error.runtimeType.toString(),
          errorMessageSanitized: error.toString(),
        ),
      DispatchValidationDenied(:final actionInvocationId, :final error) =>
        DispatchResponseDenied(
          denialKind: 'validation_denied',
          actionInvocationId: actionInvocationId,
          errorClass: 'ValidationError',
          errorMessageSanitized: error.message,
        ),
      DispatchAuthorizationDenied(
        :final actionInvocationId,
        :final permission,
      ) =>
        DispatchResponseDenied(
          denialKind: 'authorization_denied',
          actionInvocationId: actionInvocationId,
          errorClass: 'AuthorizationError',
          errorMessageSanitized: 'permission ${permission.name} not granted',
          permissionDenied: permission.name,
        ),
      DispatchExecutionFailed(:final actionInvocationId, :final error) =>
        DispatchResponseDenied(
          denialKind: 'execution_failed',
          actionInvocationId: actionInvocationId,
          errorClass: error.runtimeType.toString(),
          errorMessageSanitized: 'execution failed',
        ),
      DispatchIdempotencyHit(
        :final actionInvocationId,
        :final priorEventIds,
        :final priorResult,
      ) =>
        DispatchResponseIdempotencyHit(
          actionInvocationId: actionInvocationId,
          priorEventIds: priorEventIds,
          priorResult: priorResult is Map<String, Object?>
              ? priorResult
              : <String, Object?>{'value': priorResult.toString()},
        ),
    };
  }

  Map<String, Object?> _resultToJson(Object? result) {
    if (result == null) return <String, Object?>{};
    final dyn = result as dynamic;
    try {
      final json = dyn.toJson() as Map<String, Object?>;
      return json;
    } on NoSuchMethodError {
      return <String, Object?>{'value': result.toString()};
    }
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze
```

Expected: clean.

- [ ] **Step 3: Commit** `[CUR-1192] demo: shelf route handlers`

### Task 18: bin/server.dart entry point

**Files:**
- Create: `bin/server.dart`

- [ ] **Step 1: Implement entry point**

```dart
// bin/server.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00167 (Bootstrap) — process entry; composes everything.

import 'dart:io';

import 'package:action_permissions_demo/server/bootstrap.dart';
import 'package:action_permissions_demo/server/demo_routes.dart';
import 'package:action_permissions_demo/server/demo_state_projection.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' show getApplicationSupportDirectory;
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', defaultsTo: '8080')
    ..addFlag('ephemeral', defaultsTo: false);
  final parsed = parser.parse(args);
  final port = int.parse(parsed['port'] as String);
  final ephemeral = parsed['ephemeral'] as bool;

  final supportDir = ephemeral ? Directory.systemTemp : await getApplicationSupportDirectory();
  final dbPath = p.join(supportDir.path, 'action_permissions_demo', 'demo.db');
  await Directory(p.dirname(dbPath)).create(recursive: true);

  final permissionsYaml = await File('tool/permissions.yaml').readAsString();
  final usersYaml = await File('tool/users.yaml').readAsString();

  final components = await bootstrapDemoServer(
    dbPath: dbPath,
    ephemeral: ephemeral,
    permissionsYaml: permissionsYaml,
    usersYaml: usersYaml,
  );

  final routes = DemoRoutes(
    components: components,
    projection: PollingDemoStateProjection(
      components: components,
      lastTraceProvider: () => null,
    ),
  );

  final server = await shelf_io.serve(routes.handler, 'localhost', port);
  stdout.writeln('demo server listening on http://${server.address.host}:${server.port}');
}
```

- [ ] **Step 2: Run server briefly**

```bash
flutter pub get
dart run bin/server.dart --ephemeral --port=8765 &
SERVER_PID=$!
sleep 2
curl -s http://localhost:8765/healthz
kill $SERVER_PID
```

Expected: prints `ok`.

- [ ] **Step 3: Add `args` to pubspec dependencies if missing.**

```yaml
  args: ^2.5.0
```

Then `flutter pub get`.

- [ ] **Step 4: Commit** `[CUR-1192] demo: bin/server.dart entry point`

---

## Phase 5 — Server-side test infrastructure

### Task 19: DemoServerHarness for integration tests

**Files:**
- Create: `integration_test/test_support/demo_server_harness.dart`

- [ ] **Step 1: Implement harness**

```dart
// integration_test/test_support/demo_server_harness.dart
// Spawns bin/server.dart as a subprocess on a free port, exposes
// dispatch / inspect / sessionStart / reset / stop helpers.

import 'dart:convert';
import 'dart:io';

import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:http/http.dart' as http;

class DemoServerHarness {
  DemoServerHarness._({required this.port, required this.process, required this.client});

  final int port;
  final Process process;
  final http.Client client;

  String get baseUrl => 'http://localhost:$port';

  static Future<DemoServerHarness> start() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();

    final process = await Process.start(
      'dart',
      <String>['run', 'bin/server.dart', '--ephemeral', '--port=$port'],
      mode: ProcessStartMode.normal,
    );

    final client = http.Client();
    final harness = DemoServerHarness._(port: port, process: process, client: client);
    await harness._waitForHealth();
    return harness;
  }

  Future<void> _waitForHealth() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      try {
        final r = await client.get(Uri.parse('$baseUrl/healthz'));
        if (r.statusCode == 200) return;
      } catch (_) {/* server still starting */}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    throw StateError('demo server failed to come up within 30s');
  }

  Future<SessionStartResponse> sessionStart({String? userId}) async {
    final body = jsonEncode(SessionStartRequest(userId: userId).toJson());
    final r = await client.post(
      Uri.parse('$baseUrl/session/start'),
      body: body,
      headers: const <String, String>{'content-type': 'application/json'},
    );
    return SessionStartResponse.fromJson(jsonDecode(r.body) as Map<String, Object?>);
  }

  Future<DispatchResponse> dispatch({
    required String actionName,
    required Map<String, Object?> rawInput,
    String? idempotencyKey,
    String? userId,
  }) async {
    final body = jsonEncode(DispatchRequest(
      actionName: actionName,
      rawInput: rawInput,
      idempotencyKey: idempotencyKey,
      userId: userId,
    ).toJson());
    final r = await client.post(
      Uri.parse('$baseUrl/dispatch'),
      body: body,
      headers: const <String, String>{'content-type': 'application/json'},
    );
    return DispatchResponse.fromJson(jsonDecode(r.body) as Map<String, Object?>);
  }

  Future<InspectSnapshot> inspect() async {
    final r = await client.get(Uri.parse('$baseUrl/_demo/inspect'));
    return InspectSnapshot.fromJson(jsonDecode(r.body) as Map<String, Object?>);
  }

  Future<void> stop() async {
    process.kill();
    await process.exitCode;
    client.close();
  }
}
```

- [ ] **Step 2: Add `http: ^1.2.0` to pubspec dev_dependencies if not already there. Run `flutter pub get`.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: DemoServerHarness for integration tests`

---

## Phase 6 — Client UI

> **Convention for Phase 6:** widget tests where reasonable; `pumpWidget` smoke tests confirm rendering. UI lessons live in walkthrough integration tests, not pixel testing.

### Task 20: Flutter app skeleton (main.dart, app.dart)

**Files:**
- Create: `lib/client/main.dart`
- Create: `lib/client/app.dart`
- Create: `lib/client/http_client.dart`

- [ ] **Step 1: Write http_client.dart**

```dart
// lib/client/http_client.dart
// Thin wrapper around package:http for the client side.

import 'dart:convert';
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:http/http.dart' as http;

class DemoHttpClient {
  DemoHttpClient({this.baseUrl = 'http://localhost:8080'}) : _http = http.Client();

  final String baseUrl;
  final http.Client _http;

  Future<SessionStartResponse> sessionStart({String? userId}) async {
    final body = jsonEncode(SessionStartRequest(userId: userId).toJson());
    final r = await _http.post(
      Uri.parse('$baseUrl/session/start'),
      body: body,
      headers: const <String, String>{'content-type': 'application/json'},
    );
    return SessionStartResponse.fromJson(jsonDecode(r.body) as Map<String, Object?>);
  }

  Future<DispatchResponse> dispatch(DispatchRequest req) async {
    final r = await _http.post(
      Uri.parse('$baseUrl/dispatch'),
      body: jsonEncode(req.toJson()),
      headers: const <String, String>{'content-type': 'application/json'},
    );
    return DispatchResponse.fromJson(jsonDecode(r.body) as Map<String, Object?>);
  }

  Future<InspectSnapshot> inspect() async {
    final r = await _http.get(Uri.parse('$baseUrl/_demo/inspect'));
    return InspectSnapshot.fromJson(jsonDecode(r.body) as Map<String, Object?>);
  }

  void close() => _http.close();
}
```

- [ ] **Step 2: Write main.dart**

```dart
// lib/client/main.dart
import 'package:action_permissions_demo/client/app.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DualPaneApp());
}
```

- [ ] **Step 3: Write app.dart (placeholder)**

```dart
// lib/client/app.dart
import 'package:action_permissions_demo/client/client_pane.dart';
import 'package:action_permissions_demo/client/server_inspector_pane.dart';
import 'package:flutter/material.dart';

class DualPaneApp extends StatelessWidget {
  const DualPaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'action_permissions_demo',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('action_permissions_demo')),
        body: const Row(
          children: <Widget>[
            Expanded(child: ClientPane()),
            VerticalDivider(width: 1),
            Expanded(child: ServerInspectorPane()),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run flutter analyze**

```bash
dart analyze
```

Expected: errors about undefined `ClientPane` and `ServerInspectorPane` (those land in subsequent tasks).

- [ ] **Step 5: Stub the panes to make analyze clean**

Create `lib/client/client_pane.dart` and `lib/client/server_inspector_pane.dart`:

```dart
// lib/client/client_pane.dart
import 'package:flutter/material.dart';
class ClientPane extends StatelessWidget {
  const ClientPane({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('client pane (Task 21)'));
}
```

```dart
// lib/client/server_inspector_pane.dart
import 'package:flutter/material.dart';
class ServerInspectorPane extends StatelessWidget {
  const ServerInspectorPane({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('inspector pane (Task 25)'));
}
```

- [ ] **Step 6: Run flutter test (smoke)**

```bash
flutter test
```

Expected: all existing tests still pass.

- [ ] **Step 7: Commit** `[CUR-1192] demo: Flutter app skeleton with dual-pane shell`

### Task 21: PermissionSnapshotCache + UserId selector

**Files:**
- Create: `lib/client/permission_snapshot_cache.dart`
- Create: `lib/client/userid_selector.dart`
- Modify: `lib/client/client_pane.dart`

- [ ] **Step 1: Implement snapshot cache**

```dart
// lib/client/permission_snapshot_cache.dart
import 'package:flutter/foundation.dart';

class PermissionSnapshotCache extends ChangeNotifier {
  String? _userId;
  String _principalRole = 'Anon';
  String? _principalUserId;
  String? _principalActiveSite;
  Set<String> _permissions = const <String>{};

  String? get userId => _userId;
  String get principalRole => _principalRole;
  String? get principalUserId => _principalUserId;
  String? get principalActiveSite => _principalActiveSite;
  Set<String> get permissions => _permissions;

  void set({
    required String? userId,
    required String principalRole,
    required String? principalUserId,
    required String? principalActiveSite,
    required Set<String> permissions,
  }) {
    _userId = userId;
    _principalRole = principalRole;
    _principalUserId = principalUserId;
    _principalActiveSite = principalActiveSite;
    _permissions = permissions;
    notifyListeners();
  }

  bool holds(String permissionName) => _permissions.contains(permissionName);
}
```

- [ ] **Step 2: Implement userid_selector.dart**

```dart
// lib/client/userid_selector.dart
import 'package:action_permissions_demo/client/permission_snapshot_cache.dart';
import 'package:flutter/material.dart';

class UserIdSelector extends StatelessWidget {
  const UserIdSelector({
    super.key,
    required this.cache,
    required this.onChanged,
    required this.knownUserIds,
  });

  final PermissionSnapshotCache cache;
  final void Function(String? userId) onChanged;
  final List<String> knownUserIds;

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('(Anon — no userId)')),
      for (final id in knownUserIds) DropdownMenuItem<String?>(value: id, child: Text(id)),
    ];
    return DropdownButton<String?>(
      value: cache.userId,
      items: items,
      onChanged: onChanged,
    );
  }
}
```

- [ ] **Step 3: Wire into client_pane.dart with stub buttons**

```dart
// lib/client/client_pane.dart
import 'package:action_permissions_demo/client/http_client.dart';
import 'package:action_permissions_demo/client/permission_snapshot_cache.dart';
import 'package:action_permissions_demo/client/userid_selector.dart';
import 'package:flutter/material.dart';

class ClientPane extends StatefulWidget {
  const ClientPane({super.key});
  @override
  State<ClientPane> createState() => _ClientPaneState();
}

class _ClientPaneState extends State<ClientPane> {
  final DemoHttpClient _http = DemoHttpClient();
  final PermissionSnapshotCache _cache = PermissionSnapshotCache();

  @override
  void initState() {
    super.initState();
    _refreshSession(null);
  }

  Future<void> _refreshSession(String? userId) async {
    final resp = await _http.sessionStart(userId: userId);
    _cache.set(
      userId: userId,
      principalRole: resp.principalRole,
      principalUserId: resp.principalUserId,
      principalActiveSite: resp.principalActiveSite,
      permissions: resp.snapshotPermissions.toSet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cache,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              UserIdSelector(
                cache: _cache,
                onChanged: _refreshSession,
                knownUserIds: const <String>[
                  'admin-user',
                  'green-user-1',
                  'green-user-2',
                  'blue-user',
                ],
              ),
              const SizedBox(height: 16),
              Text('Role: ${_cache.principalRole}'),
              Text('userId: ${_cache.principalUserId ?? "(none)"}'),
              Text('activeSite: ${_cache.principalActiveSite ?? "(none)"}'),
              const Divider(),
              Text('Permissions:'),
              for (final p in _cache.permissions) Text('  • $p'),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run analyze + test**

```bash
dart analyze
flutter test
```

Expected: clean.

- [ ] **Step 5: Commit** `[CUR-1192] demo: PermissionSnapshotCache + UserIdSelector + session-start wiring`

### Task 22: Hacker mode toggle

**Files:**
- Create: `lib/client/hacker_mode_toggle.dart`
- Modify: `lib/client/client_pane.dart`

- [ ] **Step 1: Implement toggle widget** (a `Switch` + label).
- [ ] **Step 2: Wire into client_pane state; ChangeNotifier holding `bool _hackerMode`.**
- [ ] **Step 3: Run analyze.**
- [ ] **Step 4: Commit** `[CUR-1192] demo: hacker mode toggle`

### Task 23: ActionButtonsPanel — happy-path buttons

**Files:**
- Create: `lib/client/action_buttons_panel.dart`
- Modify: `lib/client/client_pane.dart`

- [ ] **Step 1: Implement ActionButtonsPanel** — six buttons (RequestHelp, EditGreenNote, EditBlueNote, PressGreen, PressBlue, PressRedAlarm). Each button is enabled iff `cache.holds(permissionName) || hackerMode`. Tapping a button shows a small dialog form (depending on action's input shape), submits via `DemoHttpClient.dispatch`, and appends the result to a request-history list.

```dart
// lib/client/action_buttons_panel.dart
import 'package:action_permissions_demo/client/http_client.dart';
import 'package:action_permissions_demo/client/permission_snapshot_cache.dart';
import 'package:action_permissions_demo/shared/wire_types.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

typedef DispatchListener = void Function(DispatchResponse response, DispatchRequest request);

class ActionButtonsPanel extends StatelessWidget {
  const ActionButtonsPanel({
    super.key,
    required this.cache,
    required this.hackerMode,
    required this.http,
    required this.onDispatched,
  });

  final PermissionSnapshotCache cache;
  final bool hackerMode;
  final DemoHttpClient http;
  final DispatchListener onDispatched;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _btn(context, 'Ask for Help', 'help.ask', _requestHelp),
        _btn(context, 'Edit Green Note', 'notes.write.green', _editGreenNote),
        _btn(context, 'Edit Blue Note', 'notes.write.blue', _editBlueNote),
        _btn(context, 'Press Green', 'buttons.press.green', _pressGreen),
        _btn(context, 'Press Blue', 'buttons.press.blue', _pressBlue),
        _btn(context, 'Press Red Alarm', 'buttons.press.red', _pressRedAlarm),
      ],
    );
  }

  Widget _btn(BuildContext context, String label, String perm, Future<void> Function(BuildContext) onTap) {
    final enabled = hackerMode || cache.holds(perm);
    return ElevatedButton(
      onPressed: enabled ? () => onTap(context) : null,
      child: Text(label),
    );
  }

  Future<void> _requestHelp(BuildContext context) async {
    final message = await _prompt(context, 'Help message');
    if (message == null) return;
    final req = DispatchRequest(
      actionName: 'RequestHelpAction',
      rawInput: <String, Object?>{'message': message},
      userId: cache.userId,
    );
    onDispatched(await http.dispatch(req), req);
  }

  Future<void> _editGreenNote(BuildContext context) =>
      _editNote(context, 'EditGreenNoteAction');

  Future<void> _editBlueNote(BuildContext context) =>
      _editNote(context, 'EditBlueNoteAction');

  Future<void> _editNote(BuildContext context, String actionName) async {
    final title = await _prompt(context, 'Title');
    if (title == null) return;
    final body = await _prompt(context, 'Body');
    if (body == null) return;
    final req = DispatchRequest(
      actionName: actionName,
      rawInput: <String, Object?>{
        'noteId': const Uuid().v4(),
        'title': title,
        'body': body,
      },
      userId: cache.userId,
    );
    onDispatched(await http.dispatch(req), req);
  }

  Future<void> _pressGreen(BuildContext context) async {
    final req = DispatchRequest(
      actionName: 'PressGreenButtonAction',
      rawInput: const <String, Object?>{},
      userId: cache.userId,
    );
    onDispatched(await http.dispatch(req), req);
  }

  Future<void> _pressBlue(BuildContext context) async {
    final req = DispatchRequest(
      actionName: 'PressBlueButtonAction',
      rawInput: const <String, Object?>{},
      userId: cache.userId,
    );
    onDispatched(await http.dispatch(req), req);
  }

  Future<void> _pressRedAlarm(BuildContext context) async {
    final reason = await _prompt(context, 'Alarm reason');
    if (reason == null) return;
    final req = DispatchRequest(
      actionName: 'PressRedAlarmAction',
      rawInput: <String, Object?>{'reason': reason},
      idempotencyKey: const Uuid().v4(),
      userId: cache.userId,
    );
    onDispatched(await http.dispatch(req), req);
  }

  Future<String?> _prompt(BuildContext context, String label) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add to client_pane.dart layout below the role display.**
- [ ] **Step 3: Run analyze + smoke test.**
- [ ] **Step 4: Commit** `[CUR-1192] demo: action buttons panel (gated by snapshot)`

### Task 24: ProvisionUser form (Admin only)

**Files:**
- Modify: `lib/client/action_buttons_panel.dart`

- [ ] **Step 1: Add a 7th button "Provision User" gated by `users.provision`. Tapping shows a 3-field form (userId, role dropdown, activeSite optional).** Auto-generate idempotencyKey. Submit via `dispatch`.

- [ ] **Step 2: Run analyze.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: ProvisionUser form for Admin`

### Task 25: RequestHistoryPanel

**Files:**
- Create: `lib/client/request_history_panel.dart`
- Modify: `lib/client/client_pane.dart`

- [ ] **Step 1: Implement panel** — a scrollable list of `(DispatchRequest, DispatchResponse)` tuples; each row shows action name, denial kind or success, action_invocation_id, timestamp.

- [ ] **Step 2: Wire into client_pane state list.**

- [ ] **Step 3: Run analyze + smoke test.**

- [ ] **Step 4: Commit** `[CUR-1192] demo: request history panel`

### Task 26: Server inspector pane

**Files:**
- Create: `lib/client/server_inspector_pane.dart` (replaces stub)

- [ ] **Step 1: Implement inspector pane** — polls `GET /_demo/inspect` every second (`Timer.periodic`). Renders four sections: Event Log (scrollable list of StoredEventSummary), Matrix Grants (table), User Directory (table), Idempotency Store (table), Last Dispatch Trace (10-stage list with stage status).

- [ ] **Step 2: Smoke test (`flutter test`) — pumpWidget renders without throwing.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: server inspector pane (poll-based)`

### Task 27: Hacker-mode malformed-request affordances

**Files:**
- Modify: `lib/client/action_buttons_panel.dart`
- Modify: `lib/client/client_pane.dart`

- [ ] **Step 1: When hacker mode is on, surface three additional widgets in the button panel:**
  1. "Fire Unknown Action" button — dispatches `actionName: 'not_a_real_action'` with empty input.
  2. "Fire Corrupt Edit Green Note" button — dispatches `EditGreenNoteAction` with `rawInput: {wrong_field: 1}` (parse_denied path).
  3. "Fire Empty-Title Edit Green Note" button — dispatches `EditGreenNoteAction` with valid shape but empty title (validation_denied path).

- [ ] **Step 2: Run analyze + smoke test.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: hacker-mode malformed-request buttons`

---

## Phase 7 — End-to-end walkthrough integration tests

> **Convention for Phase 7:** every test file follows the README walkthrough script. `setUpAll` starts a fresh server harness, `tearDownAll` stops it. `setUp` calls harness.reset() (fresh state per test). Each test asserts the observable side effects via `harness.inspect()` after dispatches.

### Task 28: Walkthrough 1 — Onboarding (identity → principal → snapshot)

**Files:**
- Create: `integration_test/walkthrough_01_onboarding_test.dart`

- [ ] **Step 1: Write test**

```dart
// integration_test/walkthrough_01_onboarding_test.dart
// Verifies: REQ-d00177 (PermissionSnapshot delivery), REQ-d00169 (AuthorizationPolicy
// permissionsFor); session-start endpoint shape.
import 'package:flutter_test/flutter_test.dart';
import 'test_support/demo_server_harness.dart';

void main() {
  late DemoServerHarness harness;

  setUpAll(() async {
    harness = await DemoServerHarness.start();
  });

  tearDownAll(() => harness.stop());

  group('Walkthrough 1: Onboarding', () {
    test('REQ-d00177: admin-user resolves to Admin with audit.read.all + users.provision', () async {
      final resp = await harness.sessionStart(userId: 'admin-user');
      expect(resp.principalRole, 'Admin');
      expect(resp.principalUserId, 'admin-user');
      expect(resp.principalActiveSite, isNull);
      expect(resp.snapshotPermissions, containsAll(<String>['audit.read.all', 'users.provision']));
    });

    test('REQ-d00177: green-user-1 resolves to GreenTeam with green-workspace + green perms', () async {
      final resp = await harness.sessionStart(userId: 'green-user-1');
      expect(resp.principalRole, 'GreenTeam');
      expect(resp.principalActiveSite, 'green-workspace');
      expect(resp.snapshotPermissions, containsAll(<String>[
        'help.ask',
        'notes.write.green',
        'buttons.press.green',
        'buttons.press.red',
      ]));
    });

    test('REQ-d00177: unknown userId resolves to Anon with help.ask only', () async {
      final resp = await harness.sessionStart(userId: 'fake-user-12345');
      expect(resp.principalRole, 'Anon');
      expect(resp.principalUserId, isNull);
      expect(resp.snapshotPermissions, <String>['help.ask']);
    });

    test('REQ-d00177: no userId resolves to Anon', () async {
      final resp = await harness.sessionStart();
      expect(resp.principalRole, 'Anon');
    });
  });
}
```

- [ ] **Step 2: Run test**

```bash
flutter test integration_test/walkthrough_01_onboarding_test.dart
```

Expected: 4 PASS.

- [ ] **Step 3: Commit** `[CUR-1192] demo: walkthrough 01 onboarding integration test`

### Task 29: Walkthrough 2 — Dispatch happy paths across scope classes

**Files:**
- Create: `integration_test/walkthrough_02_happy_paths_test.dart`

- [ ] **Step 1: Write test** — for each happy-path action (RequestHelp as Anon, EditGreenNote as green-user-1, EditBlueNote as blue-user, PressGreen as green-user-1, PressBlue as blue-user, PressRedAlarm as green-user-1 with key), assert the response is `DispatchResponseSuccess`, the inspect snapshot contains a corresponding event of the right `eventType`, and (for site-scoped actions) the event's data contains the right `workspace`. One test per action.

- [ ] **Step 2: Run, expect pass.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: walkthrough 02 happy paths`

### Task 30: Walkthrough 3 — Matrix is the perimeter (denial paths)

**Files:**
- Create: `integration_test/walkthrough_03_matrix_perimeter_test.dart`

- [ ] **Step 1: Write tests for every denial cell:**
  - GreenTeam tries EditBlueNote → `DispatchResponseDenied(denialKind: 'authorization_denied', permissionDenied: 'notes.write.blue')`.
  - Anon tries PressGreen → `authorization_denied` (sessionPreconditionMissing for site scope).
  - Anon tries PressRedAlarm → `authorization_denied` (sessionPreconditionMissing for self scope).
  - Admin tries any write action (RequestHelp succeeds; EditGreenNote, PressGreen, PressBlue, PressRedAlarm all `authorization_denied`).
  - For each denial: assert one denial event present in `harness.inspect().events` with matching `actionInvocationId`.

- [ ] **Step 2: Run, expect pass.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: walkthrough 03 denial paths`

### Task 31: Walkthrough 4 — Idempotency policy matrix

**Files:**
- Create: `integration_test/walkthrough_04_idempotency_policies_test.dart`

- [ ] **Step 1: Write tests:**
  - PressGreenButton with `idempotencyKey='ignored'` → success; fire again with same key → also success (key ignored, two events in log).
  - EditGreenNote with no key → success; with key + replay → second is `DispatchResponseIdempotencyHit` with `priorEventIds` matching first response.
  - PressRedAlarm with no key → `DispatchResponseDenied(denialKind: 'parse_denied', errorClass: 'MissingIdempotencyKeyError')`.
  - PressRedAlarm with key + replay → second is `idempotencyHit`.

- [ ] **Step 2: Run, expect pass.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: walkthrough 04 idempotency policies`

### Task 32: Walkthrough 5 — Cross-user idempotency-store independence

**Files:**
- Create: `integration_test/walkthrough_05_cross_user_keys_test.dart`

- [ ] **Step 1: Write test** — fire `PressRedAlarm` with `idempotencyKey='shared'` from `green-user-1` (success); fire same action with same key from `green-user-2` (also success, distinct event); assert `harness.inspect().idempotency` has two entries with same key but different `principalUserId`; assert two `red_button_pressed` events in event log.

- [ ] **Step 2: Run, expect pass.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: walkthrough 05 cross-user keys`

### Task 33: Walkthrough 6 — Identity decouples from role

**Files:**
- Create: `integration_test/walkthrough_06_identity_decoupling_test.dart`

- [ ] **Step 1: Write test** — fire `EditGreenNoteAction` from `green-user-1`, then again from `green-user-2`; both succeed; assert event log contains two `demo_note` events, both with `initiatorRole: 'GreenTeam'` but different `initiatorUserId`.

- [ ] **Step 2: Run, expect pass.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: walkthrough 06 identity decoupling`

### Task 34: Walkthrough 7 — Malformed requests

**Files:**
- Create: `integration_test/walkthrough_07_malformed_requests_test.dart`

- [ ] **Step 1: Write tests:**
  - Dispatch `actionName: 'not_a_real_action'` → `DispatchResponseDenied(denialKind: 'unknown_action', requestedName: 'not_a_real_action')`.
  - Dispatch `EditGreenNoteAction` with `rawInput: {wrong: 1}` → `parse_denied`.
  - Dispatch `EditGreenNoteAction` with valid shape but empty title → `validation_denied`.
  - Each denial type has a corresponding event in the inspector's event log.

- [ ] **Step 2: Run, expect pass.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: walkthrough 07 malformed requests`

### Task 35: Walkthrough 8 — Audit correlation by action_invocation_id

**Files:**
- Create: `integration_test/walkthrough_08_audit_correlation_test.dart`

- [ ] **Step 1: Write test** — fire one denied action (e.g. green-user-1 → EditBlueNote), capture `actionInvocationId` from response; fetch `harness.inspect().events`; filter to events with that `actionInvocationId`; assert the denial event is present.

- [ ] **Step 2: Run, expect pass.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: walkthrough 08 audit correlation`

### Task 36: Walkthrough 9 — User provisioning end-to-end

**Files:**
- Create: `integration_test/walkthrough_09_user_provisioning_test.dart`

- [ ] **Step 1: Write test:**
  1. Verify `green-user-3` is NOT in `harness.inspect().directory` initially.
  2. Dispatch `ProvisionUserAction` as `admin-user` with `{userId: 'green-user-3', role: 'GreenTeam', activeSite: 'green-workspace'}` and a fresh idempotencyKey → expect `DispatchResponseSuccess`.
  3. Verify directory now contains `green-user-3` with role `GreenTeam` and activeSite `green-workspace`.
  4. Run `sessionStart(userId: 'green-user-3')` → expect role `GreenTeam`, snapshot includes `notes.write.green`.
  5. Dispatch `EditGreenNoteAction` as `green-user-3` → expect success.

- [ ] **Step 2: Run, expect pass.**

- [ ] **Step 3: Commit** `[CUR-1192] demo: walkthrough 09 user provisioning`

### Task 37: Walkthrough 10 — Reset all

**Files:**
- Modify: `lib/server/demo_routes.dart` (implement reset)
- Modify: `lib/server/bootstrap.dart` (factor reset into a callable)
- Create: `integration_test/walkthrough_10_reset_test.dart`

- [ ] **Step 1: Refactor bootstrap to expose `wipeAndReseed(components, ...)` callable.**

- [ ] **Step 2: Implement `_reset` route to call it.**

- [ ] **Step 3: Write test:**
  1. Dispatch a few actions (RequestHelp x3, EditGreenNote, PressRedAlarm).
  2. Verify event log has 5+ events.
  3. POST `/_demo/reset`.
  4. Verify event log is back to seed-only events; matrix grants still present (re-applied from yaml); directory still has 4 entries.

- [ ] **Step 4: Run, expect pass.**

- [ ] **Step 5: Commit** `[CUR-1192] demo: walkthrough 10 reset all`

---

## Phase 8 — Tooling and docs

### Task 38: tool/run_demo.sh + tool/stop_demo.sh

**Files:**
- Create: `tool/run_demo.sh`
- Create: `tool/stop_demo.sh`

- [ ] **Step 1: Write run_demo.sh**

```bash
#!/usr/bin/env bash
# tool/run_demo.sh
# Spawns the demo server in the background, then runs the Flutter client.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/.."
mkdir -p tool

# Kill any prior server.
if [ -f tool/.demo-server.pid ]; then
  kill "$(cat tool/.demo-server.pid)" 2>/dev/null || true
  rm tool/.demo-server.pid
fi

# Start the server.
nohup dart run bin/server.dart > tool/.demo-server.log 2>&1 &
echo $! > tool/.demo-server.pid
echo "demo server started (pid $(cat tool/.demo-server.pid)); logs at tool/.demo-server.log"

# Wait briefly for the server to come up.
sleep 2

# Run the Flutter client in the foreground.
flutter run -d linux
```

- [ ] **Step 2: Write stop_demo.sh**

```bash
#!/usr/bin/env bash
# tool/stop_demo.sh
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/.."
if [ -f tool/.demo-server.pid ]; then
  kill "$(cat tool/.demo-server.pid)" 2>/dev/null || true
  rm tool/.demo-server.pid
  echo "demo server stopped."
else
  echo "no demo server pid file found."
fi
```

- [ ] **Step 3: chmod +x both scripts.**

- [ ] **Step 4: Commit** `[CUR-1192] demo: run/stop scripts`

### Task 39: README.md (full walkthrough scripts)

**Files:**
- Modify: `README.md` (replace placeholder)

- [ ] **Step 1: Write the README** with:
  - Overview (purpose, what it validates)
  - Prerequisites (Linux deps for Flutter desktop)
  - How to run (`tool/run_demo.sh`)
  - All 10 walkthroughs as scenario scripts ("do X, observe Y in pane Z")
  - Architecture notes (link to design spec)
  - File layout
  - "What this architecture deliberately leaves out" list (auth, ownership, reactive primitives, atomic-rollback walkthrough, synthetic-burst, TLS, rate limiting, CORS)
  - Pointer to integration tests as canonical scenario specs

- [ ] **Step 2: Lint the markdown.**

```bash
cd ../../..
markdownlint apps/common-dart/action_permissions/example/README.md
```

(or whatever the project's md lint command is — pre-commit hook will catch.)

- [ ] **Step 3: Commit** `[CUR-1192] demo: README with full walkthrough scripts`

---

## Closing tasks

### Task 40: Final analyze + test pass

- [ ] **Step 1: Run full test suite from example dir**

```bash
cd apps/common-dart/action_permissions/example
flutter pub get
dart analyze
flutter test
flutter test integration_test/
```

Expected: all green.

- [ ] **Step 2: Commit** any last formatting fix-ups.

### Task 41: PR

- [ ] **Step 1: `git push` and open a PR titled `[CUR-1192] action_permissions / audited_actions demo app` with a summary referencing the design spec.**

---

## Plan summary

41 tasks across 8 phases:
- Phase 0: skeleton (1 task)
- Phase 1: wire types (2 tasks)
- Phase 2: server data layer (3 tasks)
- Phase 3: action catalog (7 tasks)
- Phase 4: server bootstrap + routes (5 tasks)
- Phase 5: server-side test infra (1 task)
- Phase 6: client UI (8 tasks)
- Phase 7: walkthrough integration tests (10 tasks)
- Phase 8: tooling + docs (4 tasks)

Each task has 2-7 steps. Estimated effort: 60-100 hours total assuming the library prerequisites are complete and clean. If a library symbol referenced in this plan doesn't exist or has a different shape, that's a signal to return to the library plan, not to work around in the demo.
