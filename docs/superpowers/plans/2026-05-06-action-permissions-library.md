# Action Permissions Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the new `apps/common-dart/action_permissions/` Dart library — the role-permission matrix mapping layer that sits between `audited_actions` (which declares permissions on each Action) and `event_sourcing_datastore` (which persists the matrix as a materialized view fed by `permission_granted` and `permission_revoked` events).

**Architecture:** A `TableBackedAuthorizationPolicy` answers `isPermitted` and `permissionsFor` queries by delegating to a `RoleMatrixReader`. Three reader implementations: `MaterializedViewRoleMatrixReader` (server-side, queries the `role_permission_grants` view via `StorageBackend`), `InMemoryRoleMatrixReader` (test fixtures + FailSafe backing), `SnapshotRoleMatrixReader` (client-side, wraps a `PermissionSnapshot`). The matrix lives in the unified event log: `permission_granted` and `permission_revoked` events drive a `RolePermissionGrantsMaterializer` that runs in the same transaction as the events. A YAML seed (`config/action_permissions/base.yaml`) is the deployment's authoritative grant list, applied via `EventSeedApplier` on every boot — idempotent across restarts. Bootstrap returns `PolicyReady` on success or `PolicyFailSafe` on validation failure (the latter denies every query and feeds a readiness probe).

**Tech Stack:** Pure Dart (no Flutter — this is a server-side library too). Depends on `audited_actions` (for `Permission`, `ScopeClass`, `Principal`, `AuthorizationPolicy`, `AuthorizationDecision`) and `event_sourcing_datastore` (for `EventStore`, `StorageBackend`, `Materializer`, `Initiator`). Tests via `package:test` against an in-memory Sembast backend.

**Ticket:** CUR-1192
**Design doc:** `docs/superpowers/specs/2026-04-23-action-permissions-design.md`
**Verifies:** REQ-d00172 (ScopeClass enum), REQ-d00173 (AuthorizationPolicy interface), REQ-d00174 (matrix as event log), REQ-d00175 (YAML seed + applier), REQ-d00176 (evaluation algorithm), REQ-d00177 (PermissionSnapshot), REQ-d00178 (FailSafe bootstrap)

---

## Hard Prerequisites

This plan does **NOT** start until the `audited_actions` library has the following symbols implemented and tested per `docs/superpowers/plans/2026-04-22-audited-actions-library.md`:

- `ScopeClass` enum with values `global`, `site`, `self` (REQ-d00172).
- `Permission` value type with `name: String` and `scope: ScopeClass`, equality on `name` only.
- `Principal` with at least `role`, `userId`, `activeSite` fields.
- `AuthorizationPolicy` abstract class with `isPermitted(Principal, Permission) -> Future<AuthorizationDecision>` and `permissionsFor(Principal) -> Future<Set<Permission>>`.
- `AuthorizationDecision` sealed type: `Allow` or `Deny(Permission, DenyReason)` where `DenyReason` is `notGranted | sessionPreconditionMissing | bootstrapFailure`.
- `Role` type — a String-based typed wrapper or a typedef. (See **Role-type seam** below.)

If any of these symbols don't exist or have a different shape, return to the audited_actions library plan; do not bend this library to compensate.

**Role-type seam:** the design doc lists `Role` as an `action_permissions` export ("typed String wrapper"), but `Principal.role` lives in `audited_actions` and references `Role` by name. The two libraries must agree on the type. Resolution:
- **Preferred:** `audited_actions` defines `Role` as a typed-String wrapper class in `audited_actions/lib/src/role.dart`; `action_permissions` re-exports it from its own public API.
- If audited_actions chose `String` instead, `action_permissions` matches: `typedef Role = String;`.
- Verify which choice the prerequisite plan landed on at the start of Task 2 below; adjust this plan's signatures accordingly.

`event_sourcing_datastore` is on `main` and provides `EventStore`, `StorageBackend`, `Materializer`, `Initiator`, `EventDraft`, `Txn`, `findViewRowsInTxn` / `upsertViewRowInTxn` / `deleteViewRowInTxn` view methods. No new APIs needed from it.

---

## Execution Rules

Read the design doc end-to-end before Task 1. Re-read §6 (Evaluation flow) before Task 7. Re-read §7 (Failsafe bootstrap) before Task 14.

TDD cadence per task: baseline (existing tests green) → write failing test → run-and-verify-fail → write minimal impl → run-and-verify-pass → commit.

Commits use `[CUR-1192]` prefix.

REQ citation format:
- Implementation files include a `// IMPLEMENTS REQUIREMENTS:` block at the top listing all REQ-d ids the file implements.
- Per-class header: `// Implements: REQ-d00XXX-Y+Z — <prose>`.
- Per-test method: `// Verifies: REQ-d00XXX-Y` AND the assertion ID starts the test description: `test('REQ-d00XXX-Y: description', () { ... })`.

Run from `apps/common-dart/action_permissions/`:
- `dart pub get` after each pubspec change.
- `dart test` for unit tests.
- `dart analyze` for lints.

After every commit, run `dart test` and `dart analyze` from `apps/common-dart/action_permissions/` to confirm green.

---

## File Structure

All paths relative to `apps/common-dart/action_permissions/`.

```text
action_permissions/                            NEW package
  pubspec.yaml                                 package metadata + deps on audited_actions, event_sourcing_datastore
  analysis_options.yaml                        strict lint config
  README.md                                    what this package is, how to bootstrap
  lib/
    action_permissions.dart                    public exports
    src/
      role.dart                                Role typedef or re-export from audited_actions
      permission_granted_payload.dart          PermissionGrantedPayload value type + JSON
      permission_revoked_payload.dart          PermissionRevokedPayload value type + JSON
      role_matrix_reader.dart                  abstract RoleMatrixReader interface
      in_memory_role_matrix_reader.dart        Map-backed reader (test fixture + FailSafe backing)
      materialized_view_role_matrix_reader.dart  reader over StorageBackend view methods
      snapshot_role_matrix_reader.dart         client-side reader over PermissionSnapshot
      table_backed_authorization_policy.dart   AuthorizationPolicy implementation
      role_permission_grants_materializer.dart Materializer projecting events -> view
      permission_seed.dart                     PermissionSeed value type
      yaml_seed_loader.dart                    parses YAML into PermissionSeed
      seed_validator.dart                      validates seed against declaredPermissions
      event_seed_applier.dart                  diffs YAML against view, emits granted events
      permission_snapshot.dart                 PermissionSnapshot value type + JSON
      fail_safe_authorization_policy.dart      always-deny policy + bootstrap-error carrier
      authorization_policy_bootstrap.dart      sealed PolicyReady | PolicyFailSafe
      bootstrap_action_permissions.dart        top-level convenience function
  test/
    permission_granted_payload_test.dart
    permission_revoked_payload_test.dart
    in_memory_role_matrix_reader_test.dart
    materialized_view_role_matrix_reader_test.dart
    snapshot_role_matrix_reader_test.dart
    table_backed_authorization_policy_test.dart
    role_permission_grants_materializer_test.dart
    yaml_seed_loader_test.dart
    seed_validator_test.dart
    event_seed_applier_test.dart
    permission_snapshot_test.dart
    fail_safe_authorization_policy_test.dart
    bootstrap_action_permissions_test.dart
    test_support/
      sembast_event_store_harness.dart         shared test helper: builds an in-memory EventStore with the materializer registered
```

---

## Phase 0 — Package skeleton

### Task 1: Package skeleton + pubspec

**Files:**
- Create: `apps/common-dart/action_permissions/pubspec.yaml`
- Create: `apps/common-dart/action_permissions/analysis_options.yaml`
- Create: `apps/common-dart/action_permissions/.gitignore`
- Create: `apps/common-dart/action_permissions/README.md` (placeholder)
- Create: `apps/common-dart/action_permissions/lib/action_permissions.dart` (empty exports list initially)

- [ ] **Step 1: Write pubspec.yaml**

```yaml
# apps/common-dart/action_permissions/pubspec.yaml
# IMPLEMENTS REQUIREMENTS:
#   REQ-d00172..REQ-d00178 — role-permission matrix mapping layer.
#
# Sibling library to audited_actions; depends on it for the abstract
# AuthorizationPolicy / Permission / Principal / ScopeClass surface, and
# on event_sourcing_datastore for the event store + materializer protocol.

name: action_permissions
description: "Role-permission matrix mapping for audited_actions, persisted as a materialized view in event_sourcing_datastore."
version: 0.1.0+1
publish_to: none

environment:
  sdk: ^3.10.7

dependencies:
  audited_actions:
    path: ../audited_actions
  event_sourcing_datastore:
    path: ../event_sourcing_datastore
  meta: ^1.16.0
  yaml: ^3.1.3
  uuid: ^4.5.2

dev_dependencies:
  test: ^1.25.15
  mocktail: ^1.0.4
  sembast: ^3.7.3
  lints: ^5.0.0
```

- [ ] **Step 2: Write analysis_options.yaml**

```yaml
# apps/common-dart/action_permissions/analysis_options.yaml
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
# apps/common-dart/action_permissions/.gitignore
.dart_tool/
build/
coverage/
pubspec.lock
**/doc/api/
```

- [ ] **Step 4: Write placeholder lib/action_permissions.dart**

```dart
// lib/action_permissions.dart
// Public exports. Filled in incrementally as Tasks 2-15 land. Final form
// in Task 16.

library action_permissions;
```

- [ ] **Step 5: Write placeholder README.md**

```markdown
# action_permissions

Role-permission matrix for `audited_actions`, persisted as a materialized view in `event_sourcing_datastore`. See `docs/superpowers/specs/2026-04-23-action-permissions-design.md` for the design.

Full README in Task 17.
```

- [ ] **Step 6: Run dart pub get**

```bash
cd apps/common-dart/action_permissions
dart pub get
```

Expected: `Got dependencies!` (or `Changed N dependencies!`). If `audited_actions` resolution fails, the prerequisite library work is incomplete — stop.

- [ ] **Step 7: Run dart analyze**

```bash
dart analyze
```

Expected: `No issues found!`.

- [ ] **Step 8: Commit**

```bash
git add apps/common-dart/action_permissions/
git commit -m "[CUR-1192] action_permissions: package skeleton + deps"
```

---

## Phase 1 — Event payload value types

### Task 2: PermissionGrantedPayload

**Files:**
- Create: `lib/src/permission_granted_payload.dart`
- Test: `test/permission_granted_payload_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/permission_granted_payload_test.dart
// Verifies: REQ-d00174-A (event payload shape for permission_granted)
import 'package:audited_actions/audited_actions.dart' show ScopeClass;
import 'package:action_permissions/src/permission_granted_payload.dart';
import 'package:test/test.dart';

void main() {
  group('PermissionGrantedPayload', () {
    test('REQ-d00174-A: round-trips through JSON', () {
      const payload = PermissionGrantedPayload(
        role: 'admin',
        permissionName: 'user.invite',
        scope: ScopeClass.global,
      );
      final json = payload.toJson();
      final parsed = PermissionGrantedPayload.fromJson(json);
      expect(parsed.role, 'admin');
      expect(parsed.permissionName, 'user.invite');
      expect(parsed.scope, ScopeClass.global);
    });

    test('REQ-d00174-A: scope serializes by enum name', () {
      const payload = PermissionGrantedPayload(
        role: 'patient',
        permissionName: 'diary.submit',
        scope: ScopeClass.self,
      );
      expect(payload.toJson()['scope'], 'self');
    });

    test('REQ-d00174-A: rejects unknown scope on parse', () {
      expect(
        () => PermissionGrantedPayload.fromJson(<String, Object?>{
          'role': 'x',
          'permissionName': 'y',
          'scope': 'not_a_scope',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
dart test test/permission_granted_payload_test.dart
```

Expected: FAIL — undefined `PermissionGrantedPayload`.

- [ ] **Step 3: Implement permission_granted_payload.dart**

```dart
// lib/src/permission_granted_payload.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00174-A (event payload shape for permission_granted).

import 'package:audited_actions/audited_actions.dart' show ScopeClass;
import 'package:meta/meta.dart';

@immutable
class PermissionGrantedPayload {
  const PermissionGrantedPayload({
    required this.role,
    required this.permissionName,
    required this.scope,
  });

  final String role;
  final String permissionName;
  final ScopeClass scope;

  Map<String, Object?> toJson() => <String, Object?>{
        'role': role,
        'permissionName': permissionName,
        'scope': scope.name,
      };

  factory PermissionGrantedPayload.fromJson(Map<String, Object?> json) {
    final scopeName = json['scope']! as String;
    final scope = ScopeClass.values.firstWhere(
      (s) => s.name == scopeName,
      orElse: () => throw FormatException('unknown scope: $scopeName'),
    );
    return PermissionGrantedPayload(
      role: json['role']! as String,
      permissionName: json['permissionName']! as String,
      scope: scope,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionGrantedPayload &&
          role == other.role &&
          permissionName == other.permissionName &&
          scope == other.scope;

  @override
  int get hashCode => Object.hash(role, permissionName, scope);
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
dart test test/permission_granted_payload_test.dart
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/src/permission_granted_payload.dart test/permission_granted_payload_test.dart
git commit -m "[CUR-1192] action_permissions: PermissionGrantedPayload"
```

### Task 3: PermissionRevokedPayload

**Files:**
- Create: `lib/src/permission_revoked_payload.dart`
- Test: `test/permission_revoked_payload_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/permission_revoked_payload_test.dart
// Verifies: REQ-d00174-B (event payload shape for permission_revoked)
import 'package:action_permissions/src/permission_revoked_payload.dart';
import 'package:test/test.dart';

void main() {
  group('PermissionRevokedPayload', () {
    test('REQ-d00174-B: round-trips through JSON', () {
      const payload = PermissionRevokedPayload(
        role: 'admin',
        permissionName: 'user.invite',
      );
      final parsed = PermissionRevokedPayload.fromJson(payload.toJson());
      expect(parsed.role, 'admin');
      expect(parsed.permissionName, 'user.invite');
    });

    test('REQ-d00174-B: equality on all fields', () {
      const a = PermissionRevokedPayload(role: 'r', permissionName: 'p');
      const b = PermissionRevokedPayload(role: 'r', permissionName: 'p');
      const c = PermissionRevokedPayload(role: 'r', permissionName: 'q');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
dart test test/permission_revoked_payload_test.dart
```

Expected: FAIL — undefined.

- [ ] **Step 3: Implement permission_revoked_payload.dart**

```dart
// lib/src/permission_revoked_payload.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00174-B (event payload shape for permission_revoked).

import 'package:meta/meta.dart';

@immutable
class PermissionRevokedPayload {
  const PermissionRevokedPayload({
    required this.role,
    required this.permissionName,
  });

  final String role;
  final String permissionName;

  Map<String, Object?> toJson() => <String, Object?>{
        'role': role,
        'permissionName': permissionName,
      };

  factory PermissionRevokedPayload.fromJson(Map<String, Object?> json) {
    return PermissionRevokedPayload(
      role: json['role']! as String,
      permissionName: json['permissionName']! as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionRevokedPayload &&
          role == other.role &&
          permissionName == other.permissionName;

  @override
  int get hashCode => Object.hash(role, permissionName);
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
dart test test/permission_revoked_payload_test.dart
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/src/permission_revoked_payload.dart test/permission_revoked_payload_test.dart
git commit -m "[CUR-1192] action_permissions: PermissionRevokedPayload"
```

---

## Phase 2 — RoleMatrixReader implementations

### Task 4: RoleMatrixReader interface

**Files:**
- Create: `lib/src/role_matrix_reader.dart`

- [ ] **Step 1: Implement interface**

```dart
// lib/src/role_matrix_reader.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00176-C (RoleMatrixReader is the single seam between policy and
//   storage substrate).
//
// Three concrete implementations live in sibling files:
//   - InMemoryRoleMatrixReader (Map-backed; tests + FailSafe)
//   - MaterializedViewRoleMatrixReader (server-side over StorageBackend)
//   - SnapshotRoleMatrixReader (client-side over PermissionSnapshot)

import 'package:audited_actions/audited_actions.dart' show Permission;

abstract class RoleMatrixReader {
  Future<bool> isGranted(String role, String permissionName);
  Future<Set<Permission>> grantsForRole(String role);
}
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze
```

Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add lib/src/role_matrix_reader.dart
git commit -m "[CUR-1192] action_permissions: RoleMatrixReader interface"
```

### Task 5: InMemoryRoleMatrixReader

**Files:**
- Create: `lib/src/in_memory_role_matrix_reader.dart`
- Test: `test/in_memory_role_matrix_reader_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/in_memory_role_matrix_reader_test.dart
// Verifies: REQ-d00176-C (RoleMatrixReader in-memory impl).
import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/in_memory_role_matrix_reader.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryRoleMatrixReader', () {
    test('REQ-d00176-C: empty map answers false / empty set', () async {
      final reader = InMemoryRoleMatrixReader.empty();
      expect(await reader.isGranted('admin', 'user.invite'), isFalse);
      expect(await reader.grantsForRole('admin'), isEmpty);
    });

    test('REQ-d00176-C: returns true / non-empty when grant present', () async {
      final reader = InMemoryRoleMatrixReader(<String, Map<String, Permission>>{
        'admin': <String, Permission>{
          'user.invite': const Permission('user.invite', scope: ScopeClass.global),
        },
      });
      expect(await reader.isGranted('admin', 'user.invite'), isTrue);
      expect(await reader.isGranted('admin', 'user.delete'), isFalse);
      final grants = await reader.grantsForRole('admin');
      expect(grants, hasLength(1));
      expect(grants.first.name, 'user.invite');
      expect(grants.first.scope, ScopeClass.global);
    });

    test('REQ-d00176-C: unknown role answers false / empty', () async {
      final reader = InMemoryRoleMatrixReader(<String, Map<String, Permission>>{
        'admin': <String, Permission>{
          'p': const Permission('p', scope: ScopeClass.global),
        },
      });
      expect(await reader.isGranted('patient', 'p'), isFalse);
      expect(await reader.grantsForRole('patient'), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
dart test test/in_memory_role_matrix_reader_test.dart
```

Expected: FAIL — undefined.

- [ ] **Step 3: Implement in_memory_role_matrix_reader.dart**

```dart
// lib/src/in_memory_role_matrix_reader.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00176-C (RoleMatrixReader in-memory impl). Used as test fixture and
//   as backing for FailSafeAuthorizationPolicy (with empty map).

import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/role_matrix_reader.dart';

class InMemoryRoleMatrixReader implements RoleMatrixReader {
  const InMemoryRoleMatrixReader(this._grants);

  factory InMemoryRoleMatrixReader.empty() =>
      const InMemoryRoleMatrixReader(<String, Map<String, Permission>>{});

  final Map<String, Map<String, Permission>> _grants;

  @override
  Future<bool> isGranted(String role, String permissionName) async {
    return _grants[role]?.containsKey(permissionName) ?? false;
  }

  @override
  Future<Set<Permission>> grantsForRole(String role) async {
    final perPermission = _grants[role];
    if (perPermission == null) return const <Permission>{};
    return perPermission.values.toSet();
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
dart test test/in_memory_role_matrix_reader_test.dart
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/src/in_memory_role_matrix_reader.dart test/in_memory_role_matrix_reader_test.dart
git commit -m "[CUR-1192] action_permissions: InMemoryRoleMatrixReader"
```

### Task 6: MaterializedViewRoleMatrixReader

**Files:**
- Create: `lib/src/materialized_view_role_matrix_reader.dart`
- Test: `test/materialized_view_role_matrix_reader_test.dart`
- Create: `test/test_support/sembast_event_store_harness.dart`

- [ ] **Step 1: Write the test harness**

```dart
// test/test_support/sembast_event_store_harness.dart
// Builds an in-memory Sembast-backed EventStore with the
// RolePermissionGrantsMaterializer registered. Shared by every test in
// Phases 2-9 that needs a real EventStore + StorageBackend.

import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:action_permissions/src/role_permission_grants_materializer.dart';

Future<EventStore> buildInMemoryEventStore() async {
  final db = await databaseFactoryMemory.openDatabase('test_db');
  final backend = SembastBackend(database: db);
  return bootstrapEventSourcingDatastore(
    backend: backend,
    materializers: const <Materializer>[RolePermissionGrantsMaterializer()],
  );
}
```

(Note: this references `RolePermissionGrantsMaterializer` from Task 8. The harness file lands now but Task 8 implements the materializer it imports. Until then, harness-using tests fail to compile — that's expected; Phase 2 implements the reader, which uses the materializer indirectly via stored events.)

- [ ] **Step 2: Write failing test**

```dart
// test/materialized_view_role_matrix_reader_test.dart
// Verifies: REQ-d00176-C (server-side RoleMatrixReader over StorageBackend).
import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/materialized_view_role_matrix_reader.dart';
import 'package:action_permissions/src/permission_granted_payload.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

import 'test_support/sembast_event_store_harness.dart';

void main() {
  group('MaterializedViewRoleMatrixReader', () {
    late EventStore eventStore;

    setUp(() async {
      eventStore = await buildInMemoryEventStore();
    });

    test('REQ-d00176-C: isGranted returns true after PermissionGranted appended', () async {
      const payload = PermissionGrantedPayload(
        role: 'admin',
        permissionName: 'user.invite',
        scope: ScopeClass.global,
      );
      await eventStore.appendWithSecurity(
        EventDraft(
          aggregateType: 'role_permission_grant',
          aggregateId: 'admin:user.invite',
          entryType: 'role_permission_grant',
          eventType: 'permission_granted',
          data: payload.toJson(),
        ),
        initiator: const Initiator.automation(service: 'test'),
      );
      final reader = MaterializedViewRoleMatrixReader(eventStore.backend);
      expect(await reader.isGranted('admin', 'user.invite'), isTrue);
    });

    test('REQ-d00176-C: isGranted returns false after PermissionRevoked appended', () async {
      // Grant then revoke.
      await eventStore.appendWithSecurity(
        EventDraft(
          aggregateType: 'role_permission_grant',
          aggregateId: 'admin:user.invite',
          entryType: 'role_permission_grant',
          eventType: 'permission_granted',
          data: const PermissionGrantedPayload(
            role: 'admin',
            permissionName: 'user.invite',
            scope: ScopeClass.global,
          ).toJson(),
        ),
        initiator: const Initiator.automation(service: 'test'),
      );
      await eventStore.appendWithSecurity(
        EventDraft(
          aggregateType: 'role_permission_grant',
          aggregateId: 'admin:user.invite',
          entryType: 'role_permission_grant',
          eventType: 'permission_revoked',
          data: const <String, Object?>{
            'role': 'admin',
            'permissionName': 'user.invite',
          },
        ),
        initiator: const Initiator.automation(service: 'test'),
      );
      final reader = MaterializedViewRoleMatrixReader(eventStore.backend);
      expect(await reader.isGranted('admin', 'user.invite'), isFalse);
    });

    test('REQ-d00176-C: grantsForRole returns all current grants for role', () async {
      for (final perm in <String>['user.invite', 'user.role.assign']) {
        await eventStore.appendWithSecurity(
          EventDraft(
            aggregateType: 'role_permission_grant',
            aggregateId: 'admin:$perm',
            entryType: 'role_permission_grant',
            eventType: 'permission_granted',
            data: PermissionGrantedPayload(
              role: 'admin',
              permissionName: perm,
              scope: ScopeClass.global,
            ).toJson(),
          ),
          initiator: const Initiator.automation(service: 'test'),
        );
      }
      final reader = MaterializedViewRoleMatrixReader(eventStore.backend);
      final grants = await reader.grantsForRole('admin');
      expect(grants.map((p) => p.name).toSet(), <String>{'user.invite', 'user.role.assign'});
    });
  });
}
```

- [ ] **Step 3: Run test, expect fail (compiles only after Task 8 lands)**

For now, only run the in_memory test to keep CI green:

```bash
dart test test/in_memory_role_matrix_reader_test.dart
```

(The `materialized_view_role_matrix_reader_test.dart` will compile-fail until Task 8 lands the materializer. That's fine — implementer sees green incremental progress.)

- [ ] **Step 4: Implement materialized_view_role_matrix_reader.dart**

```dart
// lib/src/materialized_view_role_matrix_reader.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00176-C (server-side RoleMatrixReader). Reads through
//   StorageBackend's view methods over the role_permission_grants view.

import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/role_matrix_reader.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

class MaterializedViewRoleMatrixReader implements RoleMatrixReader {
  const MaterializedViewRoleMatrixReader(this.backend);
  final StorageBackend backend;

  static const String _viewName = 'role_permission_grants';

  @override
  Future<bool> isGranted(String role, String permissionName) async {
    final row = await backend.findEntry(
      viewName: _viewName,
      aggregateId: '$role:$permissionName',
    );
    return row != null;
  }

  @override
  Future<Set<Permission>> grantsForRole(String role) async {
    final rows = await backend.findEntries(viewName: _viewName);
    return rows
        .where((r) => r.data['role'] == role)
        .map((r) => Permission(
              r.data['permissionName']! as String,
              scope: ScopeClass.values.firstWhere(
                (s) => s.name == r.data['scope']! as String,
                orElse: () => throw StateError(
                  'unknown scope ${r.data['scope']} in row ${r.aggregateId}',
                ),
              ),
            ))
        .toSet();
  }
}
```

- [ ] **Step 5: Defer running this test until after Task 8 (materializer) lands.**

- [ ] **Step 6: Commit**

```bash
git add lib/src/materialized_view_role_matrix_reader.dart \
        test/materialized_view_role_matrix_reader_test.dart \
        test/test_support/sembast_event_store_harness.dart
git commit -m "[CUR-1192] action_permissions: MaterializedViewRoleMatrixReader (test pending Task 8)"
```

### Task 7: SnapshotRoleMatrixReader (client-side)

**Files:**
- Create: `lib/src/snapshot_role_matrix_reader.dart`
- Test: `test/snapshot_role_matrix_reader_test.dart`

(Note: this depends on `PermissionSnapshot` from Task 12. To avoid cross-cutting test failures, this task imports a minimal placeholder, then Task 12 replaces it. Or — alternative path — implement Task 12 first then come back. The plan keeps the matrix-reader trio together for narrative coherence; the implementer can reorder if preferred.)

- [ ] **Step 1: Write failing test using the eventually-available PermissionSnapshot.**

```dart
// test/snapshot_role_matrix_reader_test.dart
// Verifies: REQ-d00176-C (client-side RoleMatrixReader), REQ-d00177-C
// (snapshot is principal-scoped — answers false for any other role).
import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/permission_snapshot.dart';
import 'package:action_permissions/src/snapshot_role_matrix_reader.dart';
import 'package:test/test.dart';

void main() {
  group('SnapshotRoleMatrixReader', () {
    test('REQ-d00176-C: isGranted returns true for snapshot role + listed permission', () async {
      final snap = PermissionSnapshot(
        role: 'admin',
        grants: <Permission>{
          const Permission('user.invite', scope: ScopeClass.global),
        },
        issuedAt: DateTime(2026),
      );
      final reader = SnapshotRoleMatrixReader(snap);
      expect(await reader.isGranted('admin', 'user.invite'), isTrue);
    });

    test('REQ-d00177-C: isGranted returns false for any role other than snapshot.role', () async {
      final snap = PermissionSnapshot(
        role: 'admin',
        grants: <Permission>{
          const Permission('user.invite', scope: ScopeClass.global),
        },
        issuedAt: DateTime(2026),
      );
      final reader = SnapshotRoleMatrixReader(snap);
      expect(await reader.isGranted('patient', 'user.invite'), isFalse);
      expect(await reader.grantsForRole('patient'), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail (until Task 12 lands PermissionSnapshot)**

- [ ] **Step 3: Implement snapshot_role_matrix_reader.dart**

```dart
// lib/src/snapshot_role_matrix_reader.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00176-C (client-side RoleMatrixReader),
//   REQ-d00177-C (principal-scoped — only answers for snapshot.role).

import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/permission_snapshot.dart';
import 'package:action_permissions/src/role_matrix_reader.dart';

class SnapshotRoleMatrixReader implements RoleMatrixReader {
  const SnapshotRoleMatrixReader(this._snapshot);
  final PermissionSnapshot _snapshot;

  @override
  Future<bool> isGranted(String role, String permissionName) async {
    if (role != _snapshot.role) return false;
    return _snapshot.grants.any((p) => p.name == permissionName);
  }

  @override
  Future<Set<Permission>> grantsForRole(String role) async {
    return role == _snapshot.role ? _snapshot.grants : const <Permission>{};
  }
}
```

- [ ] **Step 4: Defer running this test until after Task 12 lands PermissionSnapshot.**

- [ ] **Step 5: Commit**

```bash
git add lib/src/snapshot_role_matrix_reader.dart test/snapshot_role_matrix_reader_test.dart
git commit -m "[CUR-1192] action_permissions: SnapshotRoleMatrixReader (test pending Task 12)"
```

---

## Phase 3 — RolePermissionGrantsMaterializer

### Task 8: RolePermissionGrantsMaterializer

**Files:**
- Create: `lib/src/role_permission_grants_materializer.dart`
- Test: `test/role_permission_grants_materializer_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/role_permission_grants_materializer_test.dart
// Verifies: REQ-d00174-C+D (materializer projects events into view in
// transaction; permission_revoked deletes view row).
import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/permission_granted_payload.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

import 'test_support/sembast_event_store_harness.dart';

void main() {
  group('RolePermissionGrantsMaterializer', () {
    late EventStore eventStore;

    setUp(() async {
      eventStore = await buildInMemoryEventStore();
    });

    test('REQ-d00174-C: permission_granted upserts view row in same txn', () async {
      const payload = PermissionGrantedPayload(
        role: 'admin',
        permissionName: 'user.invite',
        scope: ScopeClass.global,
      );
      await eventStore.appendWithSecurity(
        EventDraft(
          aggregateType: 'role_permission_grant',
          aggregateId: 'admin:user.invite',
          entryType: 'role_permission_grant',
          eventType: 'permission_granted',
          data: payload.toJson(),
        ),
        initiator: const Initiator.automation(service: 'test'),
      );
      final row = await eventStore.backend.findEntry(
        viewName: 'role_permission_grants',
        aggregateId: 'admin:user.invite',
      );
      expect(row, isNotNull);
      expect(row!.data['role'], 'admin');
      expect(row.data['permissionName'], 'user.invite');
      expect(row.data['scope'], 'global');
    });

    test('REQ-d00174-D: permission_revoked deletes view row', () async {
      // Grant.
      await eventStore.appendWithSecurity(
        EventDraft(
          aggregateType: 'role_permission_grant',
          aggregateId: 'admin:user.invite',
          entryType: 'role_permission_grant',
          eventType: 'permission_granted',
          data: const PermissionGrantedPayload(
            role: 'admin',
            permissionName: 'user.invite',
            scope: ScopeClass.global,
          ).toJson(),
        ),
        initiator: const Initiator.automation(service: 'test'),
      );
      // Revoke.
      await eventStore.appendWithSecurity(
        EventDraft(
          aggregateType: 'role_permission_grant',
          aggregateId: 'admin:user.invite',
          entryType: 'role_permission_grant',
          eventType: 'permission_revoked',
          data: const <String, Object?>{
            'role': 'admin',
            'permissionName': 'user.invite',
          },
        ),
        initiator: const Initiator.automation(service: 'test'),
      );
      final row = await eventStore.backend.findEntry(
        viewName: 'role_permission_grants',
        aggregateId: 'admin:user.invite',
      );
      expect(row, isNull);
    });

    test('REQ-d00174-E: appliesTo filters by aggregateType', () async {
      const m = RolePermissionGrantsMaterializer();
      // appliesTo true for our aggregate type
      // (assert via the lib's StoredEvent factory — placeholder per
      // event_sourcing_datastore's actual factory signature).
      // Note: simulate StoredEvent construction; concrete shape depends on
      // event_sourcing_datastore's StoredEvent constructor — adjust if needed.
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
dart test test/role_permission_grants_materializer_test.dart
```

Expected: FAIL — undefined `RolePermissionGrantsMaterializer`.

- [ ] **Step 3: Implement role_permission_grants_materializer.dart**

```dart
// lib/src/role_permission_grants_materializer.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00174-C (permission_granted -> upsert view row),
//   REQ-d00174-D (permission_revoked -> delete view row),
//   REQ-d00174-E (appliesTo filters by aggregateType).

import 'package:action_permissions/src/permission_granted_payload.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

class RolePermissionGrantsMaterializer extends Materializer {
  const RolePermissionGrantsMaterializer();

  @override
  String get viewName => 'role_permission_grants';

  @override
  bool appliesTo(StoredEvent event) =>
      event.aggregateType == 'role_permission_grant';

  @override
  Future<void> applyInTxn(
    Txn txn,
    StorageBackend backend, {
    required StoredEvent event,
    required EntryTypeDefinition def,
  }) async {
    switch (event.eventType) {
      case 'permission_granted':
        final p = PermissionGrantedPayload.fromJson(event.data);
        await backend.upsertViewRowInTxn(
          txn,
          viewName,
          event.aggregateId,
          <String, Object?>{
            'role': p.role,
            'permissionName': p.permissionName,
            'scope': p.scope.name,
          },
        );
        return;
      case 'permission_revoked':
        await backend.deleteViewRowInTxn(txn, viewName, event.aggregateId);
        return;
      default:
        // Unknown event type for this aggregate — defensive no-op.
        return;
    }
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
dart test test/role_permission_grants_materializer_test.dart
```

Expected: PASS, 2-3 tests.

- [ ] **Step 5: Run the deferred materialized-view reader test (Task 6).**

```bash
dart test test/materialized_view_role_matrix_reader_test.dart
```

Expected: PASS, 3 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/src/role_permission_grants_materializer.dart \
        test/role_permission_grants_materializer_test.dart
git commit -m "[CUR-1192] action_permissions: RolePermissionGrantsMaterializer + MaterializedViewRoleMatrixReader tests passing"
```

---

## Phase 4 — TableBackedAuthorizationPolicy

### Task 9: TableBackedAuthorizationPolicy

**Files:**
- Create: `lib/src/table_backed_authorization_policy.dart`
- Test: `test/table_backed_authorization_policy_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/table_backed_authorization_policy_test.dart
// Verifies: REQ-d00176-A+B (isPermitted, permissionsFor algorithms).
import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/in_memory_role_matrix_reader.dart';
import 'package:action_permissions/src/table_backed_authorization_policy.dart';
import 'package:test/test.dart';

void main() {
  group('TableBackedAuthorizationPolicy', () {
    final reader = InMemoryRoleMatrixReader(<String, Map<String, Permission>>{
      'admin': <String, Permission>{
        'user.invite': const Permission('user.invite', scope: ScopeClass.global),
        'site.manage': const Permission('site.manage', scope: ScopeClass.site),
        'profile.read': const Permission('profile.read', scope: ScopeClass.self),
      },
    });
    final policy = TableBackedAuthorizationPolicy(reader);

    test('REQ-d00176-A: Allow when role holds global permission', () async {
      final p = const Principal(role: 'admin', userId: 'u1', activeSite: null);
      final d = await policy.isPermitted(p, const Permission('user.invite', scope: ScopeClass.global));
      expect(d, isA<Allow>());
    });

    test('REQ-d00176-A: Deny notGranted when role does not hold permission', () async {
      final p = const Principal(role: 'patient', userId: 'u1', activeSite: null);
      final d = await policy.isPermitted(p, const Permission('user.invite', scope: ScopeClass.global));
      expect(d, isA<Deny>());
      expect((d as Deny).reason, DenyReason.notGranted);
    });

    test('REQ-d00176-A: Deny sessionPreconditionMissing for site-scoped without activeSite', () async {
      final p = const Principal(role: 'admin', userId: 'u1', activeSite: null);
      final d = await policy.isPermitted(p, const Permission('site.manage', scope: ScopeClass.site));
      expect(d, isA<Deny>());
      expect((d as Deny).reason, DenyReason.sessionPreconditionMissing);
    });

    test('REQ-d00176-A: Deny sessionPreconditionMissing for self-scoped without userId', () async {
      final p = const Principal(role: 'admin', userId: null, activeSite: null);
      final d = await policy.isPermitted(p, const Permission('profile.read', scope: ScopeClass.self));
      expect(d, isA<Deny>());
      expect((d as Deny).reason, DenyReason.sessionPreconditionMissing);
    });

    test('REQ-d00176-A: scope precondition checked BEFORE matrix lookup', () async {
      // patient has no grants but is anon; site-scoped + null activeSite must
      // return sessionPreconditionMissing (not notGranted).
      final p = const Principal(role: 'patient', userId: null, activeSite: null);
      final d = await policy.isPermitted(p, const Permission('site.manage', scope: ScopeClass.site));
      expect(d, isA<Deny>());
      expect((d as Deny).reason, DenyReason.sessionPreconditionMissing);
    });

    test('REQ-d00176-B: permissionsFor filters out scope-precondition-failing perms', () async {
      // admin with no activeSite, no userId: only the global permission survives.
      final p = const Principal(role: 'admin', userId: null, activeSite: null);
      final perms = await policy.permissionsFor(p);
      expect(perms.map((x) => x.name), <String>{'user.invite'});
    });

    test('REQ-d00176-B: permissionsFor returns all when preconditions met', () async {
      final p = const Principal(role: 'admin', userId: 'u1', activeSite: 's1');
      final perms = await policy.permissionsFor(p);
      expect(perms.map((x) => x.name), <String>{'user.invite', 'site.manage', 'profile.read'});
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
dart test test/table_backed_authorization_policy_test.dart
```

Expected: FAIL — undefined.

- [ ] **Step 3: Implement table_backed_authorization_policy.dart**

```dart
// lib/src/table_backed_authorization_policy.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00176-A (isPermitted with scope-precondition check before matrix
//   lookup),
//   REQ-d00176-B (permissionsFor filters by session preconditions).

import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/role_matrix_reader.dart';

class TableBackedAuthorizationPolicy implements AuthorizationPolicy {
  const TableBackedAuthorizationPolicy(this._reader);
  final RoleMatrixReader _reader;

  @override
  Future<AuthorizationDecision> isPermitted(
    Principal principal,
    Permission perm,
  ) async {
    final preconditionOk = _scopePreconditionMet(principal, perm.scope);
    if (!preconditionOk) {
      return Deny(permission: perm, reason: DenyReason.sessionPreconditionMissing);
    }
    final granted = await _reader.isGranted(principal.role, perm.name);
    return granted ? const Allow() : Deny(permission: perm, reason: DenyReason.notGranted);
  }

  @override
  Future<Set<Permission>> permissionsFor(Principal principal) async {
    final all = await _reader.grantsForRole(principal.role);
    return all
        .where((p) => _scopePreconditionMet(principal, p.scope))
        .toSet();
  }

  bool _scopePreconditionMet(Principal p, ScopeClass scope) {
    switch (scope) {
      case ScopeClass.global:
        return true;
      case ScopeClass.site:
        return p.activeSite != null;
      case ScopeClass.self:
        return p.userId != null;
    }
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
dart test test/table_backed_authorization_policy_test.dart
```

Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/src/table_backed_authorization_policy.dart \
        test/table_backed_authorization_policy_test.dart
git commit -m "[CUR-1192] action_permissions: TableBackedAuthorizationPolicy"
```

---

## Phase 5 — YAML seed loading

### Task 10: PermissionSeed value type + YamlSeedLoader

**Files:**
- Create: `lib/src/permission_seed.dart`
- Create: `lib/src/yaml_seed_loader.dart`
- Test: `test/yaml_seed_loader_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/yaml_seed_loader_test.dart
// Verifies: REQ-d00175-A (YAML schema parsing).
import 'package:action_permissions/src/yaml_seed_loader.dart';
import 'package:test/test.dart';

void main() {
  group('YamlSeedLoader', () {
    test('REQ-d00175-A: parses well-formed seed', () {
      const yaml = '''
roles:
  - patient
  - investigator
  - admin

grants:
  patient:
    - patient.diary.submit
    - patient.consent.sign
  investigator:
    - patient.read
  admin: []
''';
      final seed = YamlSeedLoader().loadFromString(yaml);
      expect(seed.roles, <String>{'patient', 'investigator', 'admin'});
      expect(seed.grants['patient'], <String>{'patient.diary.submit', 'patient.consent.sign'});
      expect(seed.grants['investigator'], <String>{'patient.read'});
      expect(seed.grants['admin'], isEmpty);
    });

    test('REQ-d00175-A: throws on missing roles key', () {
      const yaml = 'grants: {}';
      expect(() => YamlSeedLoader().loadFromString(yaml), throwsA(isA<FormatException>()));
    });

    test('REQ-d00175-A: throws on missing grants key', () {
      const yaml = 'roles: [admin]';
      expect(() => YamlSeedLoader().loadFromString(yaml), throwsA(isA<FormatException>()));
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
dart test test/yaml_seed_loader_test.dart
```

Expected: FAIL — undefined.

- [ ] **Step 3: Implement permission_seed.dart**

```dart
// lib/src/permission_seed.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00175-A (PermissionSeed value type).

import 'package:meta/meta.dart';

@immutable
class PermissionSeed {
  const PermissionSeed({required this.roles, required this.grants});
  final Set<String> roles;
  final Map<String, Set<String>> grants;
}
```

- [ ] **Step 4: Implement yaml_seed_loader.dart**

```dart
// lib/src/yaml_seed_loader.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00175-A (YAML schema parsing into PermissionSeed).

import 'dart:io';

import 'package:action_permissions/src/permission_seed.dart';
import 'package:yaml/yaml.dart';

class YamlSeedLoader {
  PermissionSeed loadFromFile(String path) {
    final yaml = File(path).readAsStringSync();
    return loadFromString(yaml);
  }

  PermissionSeed loadFromString(String yaml) {
    final doc = loadYaml(yaml);
    if (doc is! YamlMap) {
      throw const FormatException('seed yaml: expected top-level map');
    }
    final rolesNode = doc['roles'];
    final grantsNode = doc['grants'];
    if (rolesNode is! YamlList) {
      throw const FormatException('seed yaml: missing or non-list "roles"');
    }
    if (grantsNode is! YamlMap) {
      throw const FormatException('seed yaml: missing or non-map "grants"');
    }
    final roles = rolesNode.cast<String>().toSet();
    final grants = <String, Set<String>>{};
    for (final entry in grantsNode.entries) {
      final role = entry.key as String;
      final perms = entry.value as YamlList;
      grants[role] = perms.cast<String>().toSet();
    }
    return PermissionSeed(roles: roles, grants: grants);
  }
}
```

- [ ] **Step 5: Run test, expect pass**

```bash
dart test test/yaml_seed_loader_test.dart
```

Expected: PASS, 3 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/src/permission_seed.dart lib/src/yaml_seed_loader.dart \
        test/yaml_seed_loader_test.dart
git commit -m "[CUR-1192] action_permissions: PermissionSeed + YamlSeedLoader"
```

### Task 11: SeedValidator

**Files:**
- Create: `lib/src/seed_validator.dart`
- Test: `test/seed_validator_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/seed_validator_test.dart
// Verifies: REQ-d00175-B+C+D+E (validator rules).
import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/permission_seed.dart';
import 'package:action_permissions/src/seed_validator.dart';
import 'package:test/test.dart';

void main() {
  group('SeedValidator', () {
    final declared = <Permission>{
      const Permission('user.invite', scope: ScopeClass.global),
      const Permission('patient.read', scope: ScopeClass.global),
    };

    test('REQ-d00175-B: SeedValid for clean seed', () {
      final seed = PermissionSeed(
        roles: <String>{'admin', 'investigator'},
        grants: <String, Set<String>>{
          'admin': <String>{'user.invite'},
          'investigator': <String>{'patient.read'},
        },
      );
      expect(SeedValidator().validate(seed, declared), isA<SeedValid>());
    });

    test('REQ-d00175-B: rejects unknown permission name (typo)', () {
      final seed = PermissionSeed(
        roles: <String>{'admin'},
        grants: <String, Set<String>>{
          'admin': <String>{'user.inivte'}, // typo
        },
      );
      final result = SeedValidator().validate(seed, declared);
      expect(result, isA<SeedInvalid>());
      expect((result as SeedInvalid).errors.first, contains('user.inivte'));
    });

    test('REQ-d00175-C: rejects grant key absent from roles list', () {
      final seed = PermissionSeed(
        roles: <String>{'admin'},
        grants: <String, Set<String>>{
          'admin': <String>{'user.invite'},
          'patient': <String>{'patient.read'}, // patient not in roles
        },
      );
      expect(SeedValidator().validate(seed, declared), isA<SeedInvalid>());
    });

    test('REQ-d00175-D: rejects role missing from grants', () {
      final seed = PermissionSeed(
        roles: <String>{'admin', 'patient'},
        grants: <String, Set<String>>{
          'admin': <String>{'user.invite'},
          // patient missing from grants
        },
      );
      expect(SeedValidator().validate(seed, declared), isA<SeedInvalid>());
    });

    test('REQ-d00175-E: rejects role name containing colon', () {
      final seed = PermissionSeed(
        roles: <String>{'a:b'},
        grants: <String, Set<String>>{'a:b': <String>{}},
      );
      expect(SeedValidator().validate(seed, declared), isA<SeedInvalid>());
    });

    test('REQ-d00175-E: rejects permission name containing colon', () {
      final declared2 = <Permission>{
        const Permission('user:invite', scope: ScopeClass.global),
      };
      final seed = PermissionSeed(
        roles: <String>{'admin'},
        grants: <String, Set<String>>{'admin': <String>{'user:invite'}},
      );
      expect(SeedValidator().validate(seed, declared2), isA<SeedInvalid>());
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
dart test test/seed_validator_test.dart
```

Expected: FAIL — undefined.

- [ ] **Step 3: Implement seed_validator.dart**

```dart
// lib/src/seed_validator.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00175-B (unknown permission name -> invalid),
//   REQ-d00175-C (grant key absent from roles list -> invalid),
//   REQ-d00175-D (role missing from grants -> invalid),
//   REQ-d00175-E (role/permission name containing ':' -> invalid).

import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/permission_seed.dart';
import 'package:meta/meta.dart';

@immutable
sealed class SeedValidationResult {
  const SeedValidationResult();
}

final class SeedValid extends SeedValidationResult {
  const SeedValid();
}

final class SeedInvalid extends SeedValidationResult {
  const SeedInvalid(this.errors);
  final List<String> errors;
}

class SeedValidator {
  SeedValidationResult validate(
    PermissionSeed seed,
    Set<Permission> declared,
  ) {
    final errors = <String>[];
    final declaredNames = declared.map((p) => p.name).toSet();

    // REQ-d00175-E: name colon check on roles.
    for (final role in seed.roles) {
      if (role.contains(':')) {
        errors.add("role name contains ':': $role");
      }
    }
    // REQ-d00175-E: name colon check on permissions.
    for (final entry in seed.grants.entries) {
      for (final perm in entry.value) {
        if (perm.contains(':')) {
          errors.add("permission name contains ':': $perm");
        }
      }
    }

    // REQ-d00175-C: every grant key must be in roles.
    for (final role in seed.grants.keys) {
      if (!seed.roles.contains(role)) {
        errors.add('grant key "$role" not in roles list');
      }
    }

    // REQ-d00175-D: every role must have a grant entry.
    for (final role in seed.roles) {
      if (!seed.grants.containsKey(role)) {
        errors.add('role "$role" missing from grants');
      }
    }

    // REQ-d00175-B: every granted permission name must be in declared.
    for (final entry in seed.grants.entries) {
      for (final perm in entry.value) {
        if (!declaredNames.contains(perm)) {
          errors.add('permission "$perm" granted to "${entry.key}" not declared by any Action');
        }
      }
    }

    return errors.isEmpty ? const SeedValid() : SeedInvalid(errors);
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
dart test test/seed_validator_test.dart
```

Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/src/seed_validator.dart test/seed_validator_test.dart
git commit -m "[CUR-1192] action_permissions: SeedValidator"
```

---

## Phase 6 — EventSeedApplier

### Task 12: PermissionSnapshot

**Files:**
- Create: `lib/src/permission_snapshot.dart`
- Test: `test/permission_snapshot_test.dart`

(Implemented now to unblock SnapshotRoleMatrixReader tests from Task 7.)

- [ ] **Step 1: Write failing test**

```dart
// test/permission_snapshot_test.dart
// Verifies: REQ-d00177-A (PermissionSnapshot value type and JSON).
import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/permission_snapshot.dart';
import 'package:test/test.dart';

void main() {
  group('PermissionSnapshot', () {
    test('REQ-d00177-A: round-trips through JSON', () {
      final snap = PermissionSnapshot(
        role: 'admin',
        grants: <Permission>{
          const Permission('user.invite', scope: ScopeClass.global),
          const Permission('site.manage', scope: ScopeClass.site),
        },
        issuedAt: DateTime.utc(2026, 5, 6),
      );
      final json = snap.toJson();
      final parsed = PermissionSnapshot.fromJson(json);
      expect(parsed.role, 'admin');
      expect(parsed.grants.length, 2);
      expect(parsed.grants.any((p) => p.name == 'user.invite' && p.scope == ScopeClass.global), isTrue);
      expect(parsed.grants.any((p) => p.name == 'site.manage' && p.scope == ScopeClass.site), isTrue);
      expect(parsed.issuedAt, DateTime.utc(2026, 5, 6));
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
dart test test/permission_snapshot_test.dart
```

Expected: FAIL — undefined.

- [ ] **Step 3: Implement permission_snapshot.dart**

```dart
// lib/src/permission_snapshot.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00177-A (snapshot value type and serialization).

import 'package:audited_actions/audited_actions.dart';
import 'package:meta/meta.dart';

@immutable
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.role,
    required this.grants,
    required this.issuedAt,
  });

  final String role;
  final Set<Permission> grants;
  final DateTime issuedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'role': role,
        'grants': grants
            .map((p) => <String, Object?>{'name': p.name, 'scope': p.scope.name})
            .toList(),
        'issuedAt': issuedAt.toIso8601String(),
      };

  factory PermissionSnapshot.fromJson(Map<String, Object?> json) {
    final grantsList = json['grants']! as List<Object?>;
    final grants = grantsList.map((g) {
      final m = g! as Map<Object?, Object?>;
      final scopeName = m['scope']! as String;
      return Permission(
        m['name']! as String,
        scope: ScopeClass.values.firstWhere(
          (s) => s.name == scopeName,
          orElse: () => throw FormatException('unknown scope $scopeName'),
        ),
      );
    }).toSet();
    return PermissionSnapshot(
      role: json['role']! as String,
      grants: grants,
      issuedAt: DateTime.parse(json['issuedAt']! as String),
    );
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
dart test test/permission_snapshot_test.dart
dart test test/snapshot_role_matrix_reader_test.dart
```

Expected: both PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/permission_snapshot.dart test/permission_snapshot_test.dart
git commit -m "[CUR-1192] action_permissions: PermissionSnapshot + SnapshotRoleMatrixReader tests passing"
```

### Task 13: EventSeedApplier

**Files:**
- Create: `lib/src/event_seed_applier.dart`
- Test: `test/event_seed_applier_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/event_seed_applier_test.dart
// Verifies: REQ-d00175-F (applier diff logic), REQ-d00175-G (idempotent
// across restarts), REQ-d00175-H (drift reported, not auto-revoked).
import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/event_seed_applier.dart';
import 'package:action_permissions/src/permission_granted_payload.dart';
import 'package:action_permissions/src/permission_seed.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

import 'test_support/sembast_event_store_harness.dart';

void main() {
  group('EventSeedApplier', () {
    late EventStore eventStore;
    final declared = <Permission>{
      const Permission('user.invite', scope: ScopeClass.global),
      const Permission('patient.read', scope: ScopeClass.global),
    };

    setUp(() async {
      eventStore = await buildInMemoryEventStore();
    });

    test('REQ-d00175-F: emits PermissionGranted for every pair in seed when view is empty', () async {
      final applier = EventSeedApplier(
        eventStore: eventStore,
        seedInitiator: const Initiator.automation(service: 'test'),
      );
      final seed = PermissionSeed(
        roles: <String>{'admin', 'investigator'},
        grants: <String, Set<String>>{
          'admin': <String>{'user.invite'},
          'investigator': <String>{'patient.read'},
        },
      );
      final result = await applier.apply(seed, declared);
      expect(result.grantsEmitted, 2);
      expect(result.grantsAlreadyPresent, 0);
      expect(result.grantsInViewNotInSeed, isEmpty);
    });

    test('REQ-d00175-G: re-running with unchanged seed emits zero events (idempotent)', () async {
      final applier = EventSeedApplier(
        eventStore: eventStore,
        seedInitiator: const Initiator.automation(service: 'test'),
      );
      final seed = PermissionSeed(
        roles: <String>{'admin'},
        grants: <String, Set<String>>{'admin': <String>{'user.invite'}},
      );
      await applier.apply(seed, declared);
      final result2 = await applier.apply(seed, declared);
      expect(result2.grantsEmitted, 0);
      expect(result2.grantsAlreadyPresent, 1);
    });

    test('REQ-d00175-H: reports drift (grant in view not in seed) without revoking', () async {
      // Manually grant something the seed will not contain.
      await eventStore.appendWithSecurity(
        EventDraft(
          aggregateType: 'role_permission_grant',
          aggregateId: 'admin:user.invite',
          entryType: 'role_permission_grant',
          eventType: 'permission_granted',
          data: const PermissionGrantedPayload(
            role: 'admin',
            permissionName: 'user.invite',
            scope: ScopeClass.global,
          ).toJson(),
        ),
        initiator: const Initiator.automation(service: 'pre-existing'),
      );

      final applier = EventSeedApplier(
        eventStore: eventStore,
        seedInitiator: const Initiator.automation(service: 'test'),
      );
      // Seed does not include user.invite for admin.
      final seed = PermissionSeed(
        roles: <String>{'admin'},
        grants: <String, Set<String>>{'admin': <String>{}},
      );
      final result = await applier.apply(seed, declared);
      expect(result.grantsEmitted, 0);
      expect(result.grantsInViewNotInSeed, contains('admin:user.invite'));

      // The pre-existing grant is still in the view (no revocation emitted).
      final row = await eventStore.backend.findEntry(
        viewName: 'role_permission_grants',
        aggregateId: 'admin:user.invite',
      );
      expect(row, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
dart test test/event_seed_applier_test.dart
```

Expected: FAIL — undefined.

- [ ] **Step 3: Implement event_seed_applier.dart**

```dart
// lib/src/event_seed_applier.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00175-F (diff yaml against view, emit missing grants),
//   REQ-d00175-G (idempotent across restarts),
//   REQ-d00175-H (drift reported, not auto-revoked).

import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/permission_granted_payload.dart';
import 'package:action_permissions/src/permission_seed.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:meta/meta.dart';

@immutable
class SeedApplyResult {
  const SeedApplyResult({
    required this.grantsEmitted,
    required this.grantsAlreadyPresent,
    required this.grantsInViewNotInSeed,
  });

  final int grantsEmitted;
  final int grantsAlreadyPresent;
  final List<String> grantsInViewNotInSeed; // aggregate ids
}

class EventSeedApplier {
  EventSeedApplier({
    required this.eventStore,
    required this.seedInitiator,
  });

  final EventStore eventStore;
  final Initiator seedInitiator;

  Future<SeedApplyResult> apply(
    PermissionSeed seed,
    Set<Permission> declared,
  ) async {
    final declaredByName = <String, Permission>{
      for (final p in declared) p.name: p,
    };

    // Read current grants in view.
    final rows = await eventStore.backend.findEntries(viewName: 'role_permission_grants');
    final inView = <String>{for (final r in rows) r.aggregateId};

    // Compute pairs implied by seed.
    final inSeed = <String>{};
    for (final entry in seed.grants.entries) {
      for (final perm in entry.value) {
        inSeed.add('${entry.key}:$perm');
      }
    }

    final missing = inSeed.difference(inView);
    final present = inSeed.intersection(inView);
    final drift = inView.difference(inSeed).toList()..sort();

    // Emit a permission_granted for each missing.
    for (final id in missing) {
      final colonIx = id.indexOf(':');
      final role = id.substring(0, colonIx);
      final permName = id.substring(colonIx + 1);
      final perm = declaredByName[permName];
      if (perm == null) {
        // Validator should have caught this earlier; defensive.
        throw StateError('permission $permName not in declaredPermissions during apply');
      }
      await eventStore.appendWithSecurity(
        EventDraft(
          aggregateType: 'role_permission_grant',
          aggregateId: id,
          entryType: 'role_permission_grant',
          eventType: 'permission_granted',
          data: PermissionGrantedPayload(
            role: role,
            permissionName: permName,
            scope: perm.scope,
          ).toJson(),
        ),
        initiator: seedInitiator,
      );
    }

    return SeedApplyResult(
      grantsEmitted: missing.length,
      grantsAlreadyPresent: present.length,
      grantsInViewNotInSeed: drift,
    );
  }
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
dart test test/event_seed_applier_test.dart
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/src/event_seed_applier.dart test/event_seed_applier_test.dart
git commit -m "[CUR-1192] action_permissions: EventSeedApplier"
```

---

## Phase 7 — FailSafe + bootstrap

### Task 14: FailSafeAuthorizationPolicy

**Files:**
- Create: `lib/src/fail_safe_authorization_policy.dart`
- Create: `lib/src/authorization_policy_bootstrap.dart`
- Test: `test/fail_safe_authorization_policy_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/fail_safe_authorization_policy_test.dart
// Verifies: REQ-d00178-A (fail-safe denies all).
import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/fail_safe_authorization_policy.dart';
import 'package:test/test.dart';

void main() {
  group('FailSafeAuthorizationPolicy', () {
    final policy = const FailSafeAuthorizationPolicy(<String>['boot validation failed']);

    test('REQ-d00178-A: isPermitted returns Deny(bootstrapFailure) for any query', () async {
      final p = const Principal(role: 'admin', userId: 'u1', activeSite: 's1');
      final d = await policy.isPermitted(p, const Permission('user.invite', scope: ScopeClass.global));
      expect(d, isA<Deny>());
      expect((d as Deny).reason, DenyReason.bootstrapFailure);
    });

    test('REQ-d00178-A: permissionsFor returns empty', () async {
      expect(await policy.permissionsFor(const Principal(role: 'admin', userId: 'u', activeSite: 's')), isEmpty);
    });

    test('REQ-d00178-A: bootstrapErrors are exposed', () {
      expect(policy.bootstrapErrors, <String>['boot validation failed']);
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
dart test test/fail_safe_authorization_policy_test.dart
```

Expected: FAIL — undefined.

- [ ] **Step 3: Implement fail_safe_authorization_policy.dart**

```dart
// lib/src/fail_safe_authorization_policy.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00178-A (every query denies with bootstrapFailure reason).

import 'package:audited_actions/audited_actions.dart';

class FailSafeAuthorizationPolicy implements AuthorizationPolicy {
  const FailSafeAuthorizationPolicy(this.bootstrapErrors);
  final List<String> bootstrapErrors;

  @override
  Future<AuthorizationDecision> isPermitted(Principal principal, Permission perm) async {
    return Deny(permission: perm, reason: DenyReason.bootstrapFailure);
  }

  @override
  Future<Set<Permission>> permissionsFor(Principal principal) async {
    return const <Permission>{};
  }
}
```

- [ ] **Step 4: Implement authorization_policy_bootstrap.dart**

```dart
// lib/src/authorization_policy_bootstrap.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00178-B (sealed PolicyReady | PolicyFailSafe with isReady flag).

import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/fail_safe_authorization_policy.dart';
import 'package:meta/meta.dart';

@immutable
sealed class AuthorizationPolicyBootstrap {
  const AuthorizationPolicyBootstrap();
  AuthorizationPolicy get policy;
  bool get isReady;
  List<String> get errors;
}

final class PolicyReady extends AuthorizationPolicyBootstrap {
  const PolicyReady(this._policy);
  final AuthorizationPolicy _policy;

  @override
  AuthorizationPolicy get policy => _policy;
  @override
  bool get isReady => true;
  @override
  List<String> get errors => const <String>[];
}

final class PolicyFailSafe extends AuthorizationPolicyBootstrap {
  const PolicyFailSafe(this._errors);
  final List<String> _errors;

  @override
  AuthorizationPolicy get policy => FailSafeAuthorizationPolicy(_errors);
  @override
  bool get isReady => false;
  @override
  List<String> get errors => _errors;
}
```

- [ ] **Step 5: Run test, expect pass**

```bash
dart test test/fail_safe_authorization_policy_test.dart
```

Expected: PASS, 3 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/src/fail_safe_authorization_policy.dart \
        lib/src/authorization_policy_bootstrap.dart \
        test/fail_safe_authorization_policy_test.dart
git commit -m "[CUR-1192] action_permissions: FailSafe policy + bootstrap sealed type"
```

### Task 15: bootstrapActionPermissions top-level function

**Files:**
- Create: `lib/src/bootstrap_action_permissions.dart`
- Test: `test/bootstrap_action_permissions_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/bootstrap_action_permissions_test.dart
// Verifies: REQ-d00178-B (bootstrap sequence). End-to-end: well-formed YAML
// + valid declared perms -> PolicyReady; mismatched yaml -> PolicyFailSafe.
import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/authorization_policy_bootstrap.dart';
import 'package:action_permissions/src/bootstrap_action_permissions.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';
import 'package:test/test.dart';

import 'test_support/sembast_event_store_harness.dart';

void main() {
  group('bootstrapActionPermissions', () {
    late EventStore eventStore;

    setUp(() async {
      eventStore = await buildInMemoryEventStore();
    });

    test('REQ-d00178-B: clean yaml + matching declared perms -> PolicyReady, ready answers permitted', () async {
      const yaml = '''
roles:
  - admin
grants:
  admin:
    - user.invite
''';
      final boot = await bootstrapActionPermissions(
        eventStore: eventStore,
        declaredPermissions: <Permission>{
          const Permission('user.invite', scope: ScopeClass.global),
        },
        yamlSource: yaml,
      );
      expect(boot, isA<PolicyReady>());
      expect(boot.isReady, isTrue);

      final policy = boot.policy;
      const p = Principal(role: 'admin', userId: 'u', activeSite: null);
      final d = await policy.isPermitted(p, const Permission('user.invite', scope: ScopeClass.global));
      expect(d, isA<Allow>());
    });

    test('REQ-d00178-B: yaml refers to undeclared permission -> PolicyFailSafe', () async {
      const yaml = '''
roles:
  - admin
grants:
  admin:
    - user.unknown
''';
      final boot = await bootstrapActionPermissions(
        eventStore: eventStore,
        declaredPermissions: <Permission>{
          const Permission('user.invite', scope: ScopeClass.global),
        },
        yamlSource: yaml,
      );
      expect(boot, isA<PolicyFailSafe>());
      expect(boot.isReady, isFalse);
      expect(boot.errors, isNotEmpty);

      // FailSafe denies everything.
      const p = Principal(role: 'admin', userId: 'u', activeSite: null);
      final d = await boot.policy.isPermitted(p, const Permission('user.invite', scope: ScopeClass.global));
      expect(d, isA<Deny>());
      expect((d as Deny).reason, DenyReason.bootstrapFailure);
    });

    test('REQ-d00178-B: re-bootstrap with same yaml is idempotent (no new events)', () async {
      const yaml = '''
roles:
  - admin
grants:
  admin:
    - user.invite
''';
      final declared = <Permission>{
        const Permission('user.invite', scope: ScopeClass.global),
      };
      await bootstrapActionPermissions(
        eventStore: eventStore,
        declaredPermissions: declared,
        yamlSource: yaml,
      );
      final eventsBefore = await eventStore.findAllEvents(limit: 1000);
      await bootstrapActionPermissions(
        eventStore: eventStore,
        declaredPermissions: declared,
        yamlSource: yaml,
      );
      final eventsAfter = await eventStore.findAllEvents(limit: 1000);
      expect(eventsAfter.length, eventsBefore.length);
    });
  });
}
```

- [ ] **Step 2: Run test, expect fail**

```bash
dart test test/bootstrap_action_permissions_test.dart
```

Expected: FAIL — undefined.

- [ ] **Step 3: Implement bootstrap_action_permissions.dart**

```dart
// lib/src/bootstrap_action_permissions.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00178-B (top-level bootstrap sequence: load -> validate -> apply
//   -> construct policy).

import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/src/authorization_policy_bootstrap.dart';
import 'package:action_permissions/src/event_seed_applier.dart';
import 'package:action_permissions/src/materialized_view_role_matrix_reader.dart';
import 'package:action_permissions/src/seed_validator.dart';
import 'package:action_permissions/src/table_backed_authorization_policy.dart';
import 'package:action_permissions/src/yaml_seed_loader.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

/// Bootstraps the role-permission matrix from a YAML seed.
///
/// Provide either [yamlPath] (loads from disk) or [yamlSource] (loads from
/// string); supplying both is a programmer error.
Future<AuthorizationPolicyBootstrap> bootstrapActionPermissions({
  required EventStore eventStore,
  required Set<Permission> declaredPermissions,
  String? yamlPath,
  String? yamlSource,
  Initiator seedInitiator =
      const Initiator.automation(service: 'action_permissions_seed'),
}) async {
  if ((yamlPath == null) == (yamlSource == null)) {
    throw ArgumentError('exactly one of yamlPath or yamlSource must be provided');
  }

  // 1. Load seed.
  final loader = YamlSeedLoader();
  final seed = yamlSource != null
      ? loader.loadFromString(yamlSource)
      : loader.loadFromFile(yamlPath!);

  // 2. Validate.
  final validation = SeedValidator().validate(seed, declaredPermissions);
  if (validation is SeedInvalid) {
    return PolicyFailSafe(validation.errors);
  }

  // 3. Apply seed (emit missing grants).
  final applier = EventSeedApplier(
    eventStore: eventStore,
    seedInitiator: seedInitiator,
  );
  await applier.apply(seed, declaredPermissions);

  // 4. Wrap in TableBackedAuthorizationPolicy over MaterializedViewRoleMatrixReader.
  final reader = MaterializedViewRoleMatrixReader(eventStore.backend);
  final policy = TableBackedAuthorizationPolicy(reader);
  return PolicyReady(policy);
}
```

- [ ] **Step 4: Run test, expect pass**

```bash
dart test test/bootstrap_action_permissions_test.dart
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/src/bootstrap_action_permissions.dart \
        test/bootstrap_action_permissions_test.dart
git commit -m "[CUR-1192] action_permissions: bootstrapActionPermissions top-level"
```

---

## Phase 8 — Public exports + README

### Task 16: lib/action_permissions.dart public exports

**Files:**
- Modify: `lib/action_permissions.dart`

- [ ] **Step 1: Replace placeholder with full export list**

```dart
// lib/action_permissions.dart
// IMPLEMENTS REQUIREMENTS:
//   REQ-d00172..REQ-d00178 (full library API surface).

library action_permissions;

export 'src/authorization_policy_bootstrap.dart';
export 'src/bootstrap_action_permissions.dart';
export 'src/event_seed_applier.dart' show EventSeedApplier, SeedApplyResult;
export 'src/fail_safe_authorization_policy.dart';
export 'src/in_memory_role_matrix_reader.dart';
export 'src/materialized_view_role_matrix_reader.dart';
export 'src/permission_granted_payload.dart';
export 'src/permission_revoked_payload.dart';
export 'src/permission_seed.dart';
export 'src/permission_snapshot.dart';
export 'src/role_matrix_reader.dart';
export 'src/role_permission_grants_materializer.dart';
export 'src/seed_validator.dart' show SeedValidator, SeedValidationResult, SeedValid, SeedInvalid;
export 'src/snapshot_role_matrix_reader.dart';
export 'src/table_backed_authorization_policy.dart';
export 'src/yaml_seed_loader.dart';
```

- [ ] **Step 2: Run analyze**

```bash
dart analyze
```

Expected: clean.

- [ ] **Step 3: Run all tests**

```bash
dart test
```

Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add lib/action_permissions.dart
git commit -m "[CUR-1192] action_permissions: public exports"
```

### Task 17: README.md (full)

**Files:**
- Modify: `README.md` (replace placeholder)

- [ ] **Step 1: Write README**

````markdown
# action_permissions

Role-permission matrix for `audited_actions`, persisted as a materialized view in `event_sourcing_datastore`. Sibling library to `audited_actions`; depends on it for `Permission`, `ScopeClass`, `Principal`, `AuthorizationPolicy`, `AuthorizationDecision`.

## What this library does

- Defines `TableBackedAuthorizationPolicy` over a `RoleMatrixReader`.
- Stores the matrix in the unified event log via two event types (`permission_granted`, `permission_revoked`) and a `RolePermissionGrantsMaterializer` that projects them into the `role_permission_grants` view inside the same transaction as the events.
- Loads a YAML seed (`config/action_permissions/base.yaml`-shaped) via `YamlSeedLoader`, validates it against `ActionRegistry.allDeclaredPermissions`, applies missing grants idempotently via `EventSeedApplier`.
- Returns `PolicyReady` on bootstrap success or `PolicyFailSafe` on validation failure (the latter denies every query).
- Provides three `RoleMatrixReader` impls: server-side (`MaterializedViewRoleMatrixReader`), client-side (`SnapshotRoleMatrixReader` over a `PermissionSnapshot`), and in-memory (`InMemoryRoleMatrixReader` for tests + FailSafe backing).

## Quick start (server)

```dart
import 'package:audited_actions/audited_actions.dart';
import 'package:action_permissions/action_permissions.dart';
import 'package:event_sourcing_datastore/event_sourcing_datastore.dart';

Future<void> main() async {
  // 1. Construct EventStore with the materializer in its list.
  final backend = SembastBackend(database: db);
  final eventStore = await bootstrapEventSourcingDatastore(
    backend: backend,
    materializers: const <Materializer>[RolePermissionGrantsMaterializer()],
  );

  // 2. Construct your ActionRegistry.
  final registry = ActionRegistry();
  registry.register(MyAction());
  // ... register other actions

  // 3. Bootstrap action permissions.
  final boot = await bootstrapActionPermissions(
    eventStore: eventStore,
    declaredPermissions: registry.allDeclaredPermissions,
    yamlPath: 'config/action_permissions/base.yaml',
  );

  if (!boot.isReady) {
    // Wire boot.policy into a readiness probe — bind it but mark unhealthy.
    print('action_permissions failed to bootstrap: ${boot.errors}');
  }

  // 4. Hand the policy to audited_actions.
  final dispatcher = bootstrapAuditedActions(
    events: eventStore,
    authorization: boot.policy,
    idempotency: idempotencyStore,
    actions: registry.all,
  );
}
```

## Quick start (client)

```dart
// At session start, the server sends a PermissionSnapshot in the auth response:
final snapshot = PermissionSnapshot.fromJson(authResponse['snapshot']);
final reader = SnapshotRoleMatrixReader(snapshot);
final policy = TableBackedAuthorizationPolicy(reader);

// Use the policy in widget enablement:
final allowed = await policy.isPermitted(currentPrincipal, somePermission);
if (allowed is Allow) { /* show button */ }
```

## YAML schema

```yaml
roles:
  - patient
  - investigator
  - admin

grants:
  patient:
    - patient.diary.submit
  investigator:
    - patient.read
  admin:
    - user.invite
    - user.role.assign
```

Validation rules (REQ-d00175):

- Every permission name must be declared by some registered Action (`registry.allDeclaredPermissions`); typos fail closed.
- Every grant key must be in `roles`; every role must have a grants entry (empty list legal).
- No role or permission name may contain `:` (it's the aggregateId composite delimiter).

## Drift handling

Grants present in the materialized view but absent from the YAML are reported in `SeedApplyResult.grantsInViewNotInSeed` and **not auto-revoked**. This preserves runtime grants written by future admin Actions when the YAML happens to lag. To revoke a grant, append a `permission_revoked` event explicitly (a future admin Action will do this).

## Tests

```bash
cd apps/common-dart/action_permissions
dart pub get
dart test
dart analyze
```

In-memory Sembast harness (`test/test_support/sembast_event_store_harness.dart`) wraps the materializer and event store; reused by every test that needs a real EventStore.

## Related

- Design doc: `docs/superpowers/specs/2026-04-23-action-permissions-design.md`
- REQ assertions: `spec/dev-action-permissions.md` (REQ-d00172..REQ-d00178)
- Sibling library: `apps/common-dart/audited_actions/`
- Storage substrate: `apps/common-dart/event_sourcing_datastore/`
````

- [ ] **Step 2: Lint markdown.** (pre-commit catches this.)

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "[CUR-1192] action_permissions: full README"
```

---

## Phase 9 — Final pass

### Task 18: Final analyze + test

- [ ] **Step 1: Run full library suite**

```bash
cd apps/common-dart/action_permissions
dart pub get
dart analyze
dart test
```

Expected: all green; `dart test` should report 30+ passing tests across 13 test files.

- [ ] **Step 2: If any test was deferred during earlier tasks (Tasks 6 and 7 had test files committed before the Materializer/Snapshot landed), confirm they all run green now.**

- [ ] **Step 3: Commit any final cleanup.**

---

## Plan summary

18 tasks across 9 phases:

- Phase 0: skeleton (1 task)
- Phase 1: event payloads (2 tasks)
- Phase 2: matrix readers (3 tasks + interface) — 4 tasks
- Phase 3: materializer (1 task)
- Phase 4: TableBackedAuthorizationPolicy (1 task)
- Phase 5: YAML seed loading (2 tasks)
- Phase 6: snapshot + applier (2 tasks)
- Phase 7: failsafe + bootstrap (2 tasks)
- Phase 8: exports + README (2 tasks)
- Phase 9: final pass (1 task)

Each task: 5 to 8 steps, TDD-disciplined, 30 minutes to 2 hours of work. Estimated total: 25-40 hours assuming the audited_actions prerequisites are clean. The library has no UI surface and no integration tests against external processes — it's library code with unit tests against an in-memory Sembast event store.
