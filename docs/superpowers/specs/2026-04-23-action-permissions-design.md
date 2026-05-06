# Action Permissions Library — Design

**Date**: 2026-04-23
**Audience**: dev
**Implements**: REQ-d00172 through REQ-d00178 (see `spec/dev-action-permissions.md`)

## 1. Purpose

`action_permissions` is the sibling library to `audited_actions`. Each registered Action declares a set of `Permission`s; this library is the mapping layer that records which roles hold which permissions and answers the dispatcher's authorize-stage question: does this principal's role hold this permission, and does the principal's session satisfy the permission's scope class.

The library is app-agnostic. It serves the portal server, the mobile diary app, and any other host that builds on `audited_actions`. Its persistence is the unified event store provided by `event_sourcing_datastore`: the matrix is a materialized view fed by two permission-domain event types, kept current by a registered `Materializer` that runs inside the same transaction as the events that drive it. There is one storage story across the platform.

## 2. Package structure

One package, two upstream dependencies:

```text
apps/common-dart/
  audited_actions/              defines AuthorizationPolicy, Permission,
                                ScopeClass, Principal, AuthorizationDecision
  event_sourcing_datastore/     EventStore + StorageBackend + Materializer
  action_permissions/           THIS LIBRARY
```

**Dependency graph:**

```text
audited_actions  <----+
                       \
event_sourcing_datastore  <----  action_permissions
```

`audited_actions` and `event_sourcing_datastore` have no dependency on `action_permissions`. Hosts (mobile diary app, portal server) construct an `EventStore` from `event_sourcing_datastore` (with whatever `StorageBackend` they prefer — `SembastBackend` on a Flutter client today; a future `PostgresBackend` server-side), construct an `ActionRegistry` from `audited_actions`, then call `bootstrapActionPermissions(eventStore, declaredPermissions, yamlPath)` which returns an `AuthorizationPolicy` they pass to `bootstrapAuditedActions(...)`.

### `action_permissions` exports

- `TableBackedAuthorizationPolicy` — implements `AuthorizationPolicy` over a `RoleMatrixReader`.
- `RoleMatrixReader` — interface; the single seam between the policy and the storage substrate.
- `MaterializedViewRoleMatrixReader` — `RoleMatrixReader` over the `role_permission_grants` view via `StorageBackend`'s view methods.
- `InMemoryRoleMatrixReader` — backed by an in-memory `Map<Role, Map<String, Permission>>`; used for unit tests of the policy without an event-store harness, and as the underlying reader for `FailSafeAuthorizationPolicy` (empty map).
- `SnapshotRoleMatrixReader` — wraps a `PermissionSnapshot`; used by clients that received a snapshot from a server.
- `PermissionSnapshot` — value type the server ships to clients at session start.
- `Role` — typed `String` wrapper.
- `RolePermissionGrantsMaterializer` — `Materializer` (from `event_sourcing_datastore`) that folds `PermissionGranted` and `PermissionRevoked` events into the `role_permission_grants` view.
- `PermissionGranted`, `PermissionRevoked` — event-payload value types and serialization.
- `PermissionSeed`, `YamlSeedLoader`, `SeedValidator` — parse and validate the YAML.
- `EventSeedApplier` — diffs the YAML seed against the current view and emits the missing `PermissionGranted` events.
- `FailSafeAuthorizationPolicy` — denies every query; used when bootstrap validation fails.
- `AuthorizationPolicyBootstrap` (sealed: `PolicyReady` | `PolicyFailSafe`).
- `bootstrapActionPermissions(...)` — top-level convenience function that runs the full bootstrap sequence.

### Tests

The library is developed and tested against the existing in-memory Sembast backend that ships with `event_sourcing_datastore` (the same harness pattern its own tests use). The matrix is small enough that integration tests run quickly and cover the materializer-runs-in-transaction guarantee end-to-end.

## 3. Vocabulary in audited_actions

Four shapes in `audited_actions` are consumed by `action_permissions`. Each is listed here in its required form.

### `ScopeClass` enum (`audited_actions/lib/src/scope_class.dart`)

```dart
enum ScopeClass {
  global,   // no session precondition
  site,     // principal.activeSite must be non-null
  self,     // principal.userId must be non-null
}
```

Closed set with three values. Adding a value requires a deliberate code plus REQ change.

### `Permission` value type (`audited_actions/lib/src/permission.dart`)

```dart
class Permission {
  const Permission(this.name, {required this.scope});
  final String     name;
  final ScopeClass scope;

  // Equality on name only: a permission name's scope is code-defined,
  // so two Permissions with the same name have the same scope. The
  // ActionRegistry enforces this at boot.
  @override
  bool operator ==(Object other) => other is Permission && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
```

`scope` is required; every Action that declares a permission states its scope explicitly.

### `Principal` (`audited_actions/lib/src/principal.dart`)

The `Principal` exposes at least:

- `role: Role` — the single active role for this request.
- `activeSite: SiteId?` — non-null iff the principal has selected a site context for the session.
- `userId: UserId?` — non-null iff the principal is authenticated.

Additional fields on `Principal` may exist; `action_permissions` uses only the three above.

### `AuthorizationPolicy` interface (`audited_actions/lib/src/authorization_policy.dart`)

```dart
abstract class AuthorizationPolicy {
  Future<AuthorizationDecision> isPermitted(
    Principal  principal,
    Permission permission,
  );

  Future<Set<Permission>> permissionsFor(Principal principal);
}
```

Two methods. The dispatcher's authorize stage calls `isPermitted` once per permission declared by the Action being dispatched. Hosts call `permissionsFor` once per session start to construct a `PermissionSnapshot` for client delivery.

### `AuthorizationDecision` sealed type (`audited_actions/lib/src/authorization_decision.dart`)

```dart
sealed class AuthorizationDecision {
  const AuthorizationDecision();
}

final class Allow extends AuthorizationDecision {
  const Allow();
}

final class Deny extends AuthorizationDecision {
  const Deny({required this.permission, required this.reason});
  final Permission permission;
  final DenyReason reason;
}

enum DenyReason {
  notGranted,                  // role does not hold the permission in the matrix
  sessionPreconditionMissing,  // scope precondition not satisfied
  bootstrapFailure,            // policy booted in failsafe mode; no decisions are valid
}
```

## 4. Event types and materialized view

The matrix lives in the unified event store as the projection of two event types onto a single materialized view.

### Event types

Both events use `aggregateType: 'role_permission_grant'`. The aggregate identity for each `(role, permissionName)` pair is the composite `aggregateId: '<role>:<permissionName>'`. Multiple grants and revocations of the same pair form one aggregate's event stream; the materializer collapses the stream into a current-state row.

```dart
// Event payload for eventType: 'permission_granted'
class PermissionGrantedPayload {
  const PermissionGrantedPayload({
    required this.role,
    required this.permissionName,
    required this.scope,
  });
  final String     role;
  final String     permissionName;
  final ScopeClass scope;

  Map<String, Object?> toJson();
  factory PermissionGrantedPayload.fromJson(Map<String, Object?> json);
}

// Event payload for eventType: 'permission_revoked'
class PermissionRevokedPayload {
  const PermissionRevokedPayload({
    required this.role,
    required this.permissionName,
  });
  final String role;
  final String permissionName;

  Map<String, Object?> toJson();
  factory PermissionRevokedPayload.fromJson(Map<String, Object?> json);
}
```

Both are appended via `EventStore.append(...)` with the appropriate `entryType`, `aggregateType`, `aggregateId`, `eventType`, and `data`. The seed applier uses an `AutomationInitiator(service: 'action_permissions_seed')`. Future admin Actions that grant or revoke at runtime use `UserInitiator(userId: <admin>)`.

### Materializer

```dart
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
    required List<StoredEvent> aggregateHistory,
  }) async {
    switch (event.eventType) {
      case 'permission_granted':
        final p = PermissionGrantedPayload.fromJson(event.data);
        await backend.upsertViewRowInTxn(
          txn,
          viewName,
          event.aggregateId,            // '<role>:<permissionName>'
          {
            'role':           p.role,
            'permissionName': p.permissionName,
            'scope':          p.scope.name,
          },
        );
      case 'permission_revoked':
        await backend.deleteViewRowInTxn(txn, viewName, event.aggregateId);
      default:
        // Unknown event type for this aggregate. Defensive: do nothing.
        // The aggregateType filter above should have already excluded this.
        return;
    }
  }
}
```

Hosts register this materializer in the `EventStore` they construct. The library's bootstrap helper does this automatically when the host calls `bootstrapActionPermissions(...)` — but if a host constructs its `EventStore` directly, it includes `RolePermissionGrantsMaterializer()` in the `materializers` list.

### View shape

View name: `role_permission_grants`.

Row key: `'<role>:<permissionName>'` — the same string used as `aggregateId` for the granting events. Role names and permission names contain no `:` by convention; the validator rejects names containing `:`.

Row payload: `{role: String, permissionName: String, scope: String}`. Scope is stored as the enum's `.name` (one of `'global'`, `'site'`, `'self'`).

Absence of a row means no grant. A row produced by `permission_granted` and later removed by `permission_revoked` ends up absent and is treated identically to "never granted." This is the intended semantics: revocation is final unless re-granted.

### Why per-pair aggregates

Each `(role, permissionName)` pair has a small, well-defined event stream. Querying "all grants for a role" reduces to a view scan filtered by row content (or by aggregateId prefix, where backend support exists). Materialization is `upsert` or `delete` of one row per event — cheap and atomic. There is no read-modify-write inside the materializer, so concurrent grants of different pairs cannot conflict.

The tradeoff: `permissionsFor(role)` is a multi-row read across the view rather than a single-row read of a denormalized "all my grants" row. The matrix is small (tens of roles, hundreds of permissions, low thousands of grants worst-case), so a full-view scan with predicate filter is acceptable. If `StorageBackend` exposes a prefix-scan or filter API for view rows, the reader uses it; otherwise it falls back to "fetch all rows in the view, filter in Dart."

## 5. YAML seed and applier

### File layout

```text
config/action_permissions/
  base.yaml                  # authoritative seed for the deployment
```

### Schema

```yaml
roles:
  - patient
  - investigator
  - sponsor
  - auditor
  - analyst
  - administrator
  - developer_admin

grants:
  patient:
    - patient.diary.submit
    - patient.consent.sign
    - patient.profile.read.self
  investigator:
    - patient.read
    - patient.enroll
    - diary.review
  sponsor:
    - user.invite
    - user.role.assign
    - report.aggregate.read
  # Each role in `roles` must appear as a key in `grants`. Empty lists
  # are legal.
```

Permission names are exact string matches against `Permission.name` declared by registered Actions. No scope information in YAML. No conditions, wildcards, globs, or hierarchy expressions.

### Dart types

```dart
class PermissionSeed {
  const PermissionSeed({required this.roles, required this.grants});
  final Set<Role>              roles;
  final Map<Role, Set<String>> grants;  // permission names
}

class YamlSeedLoader {
  PermissionSeed loadFromFile(String path);
  PermissionSeed loadFromString(String yaml);
}
```

### Validator

```dart
sealed class SeedValidationResult {
  const SeedValidationResult();
}

final class SeedValid   extends SeedValidationResult { const SeedValid(); }

final class SeedInvalid extends SeedValidationResult {
  const SeedInvalid(this.errors);
  final List<String> errors;
}

class SeedValidator {
  SeedValidationResult validate(
    PermissionSeed       seed,
    Set<Permission>      declaredPermissions,
  );
}
```

The validator's "discovered permissions" set is the live `ActionRegistry.allDeclaredPermissions` collected at boot — the union of every registered Action's declared permissions. There is no persisted permission registry. Validation reports `SeedInvalid` if any of:

1. A permission name in any grant list is absent from `declaredPermissions` (typos fail closed).
2. A role key in `grants` is absent from `roles`.
3. `roles` contains duplicates, or any grant list contains duplicates.
4. Any role in `roles` is missing from `grants`.
5. A role name or permission name contains a `:` (the aggregate-id composite delimiter).

### Event seed applier

```dart
class EventSeedApplier {
  EventSeedApplier({
    required this.eventStore,
    required this.seedInitiator,
  });
  final EventStore eventStore;
  final Initiator  seedInitiator;

  Future<SeedApplyResult> apply(
    PermissionSeed     seed,
    Set<Permission>    declaredPermissions,
  );
}

class SeedApplyResult {
  const SeedApplyResult({
    required this.grantsEmitted,
    required this.grantsAlreadyPresent,
    required this.grantsInViewNotInSeed,
  });
  final int          grantsEmitted;          // PermissionGranted events emitted this run
  final int          grantsAlreadyPresent;   // grant in YAML and already in view; skipped
  final List<String> grantsInViewNotInSeed;  // drift; logged, never auto-revoked
}
```

The applier:

1. Reads the current `role_permission_grants` view: `await eventStore.backend.findViewRowsInTxn(txn, 'role_permission_grants', ...)` (or the equivalent non-transactional read).
2. Computes the set of `(role, permissionName)` pairs implied by the YAML.
3. For each pair in YAML and absent from view: appends one `PermissionGranted` event via `eventStore.append(...)` with `entryType: 'role_permission_grant'`, `aggregateType: 'role_permission_grant'`, `aggregateId: '<role>:<permissionName>'`, `eventType: 'permission_granted'`, `data: PermissionGrantedPayload(...).toJson()`, `initiator: seedInitiator`. The materializer (already registered on the EventStore) writes the corresponding view row in the same transaction.
4. For each pair in view and absent from YAML: records the row's key in `grantsInViewNotInSeed`. Does not emit `PermissionRevoked` events. (Drift is reported, not silently revoked. This preserves any grants written by future runtime admin Actions when the YAML happens to lag behind.)
5. Returns the `SeedApplyResult`.

The applier is idempotent across restarts: re-running with an unchanged YAML emits zero events because every pair is already present in the view.

## 6. Evaluation flow

`TableBackedAuthorizationPolicy` implements `AuthorizationPolicy` over a `RoleMatrixReader`.

### `isPermitted`

```dart
@override
Future<AuthorizationDecision> isPermitted(Principal p, Permission perm) async {
  final preconditionOk = switch (perm.scope) {
    ScopeClass.global => true,
    ScopeClass.site   => p.activeSite != null,
    ScopeClass.self   => p.userId     != null,
  };
  if (!preconditionOk) {
    return Deny(permission: perm, reason: DenyReason.sessionPreconditionMissing);
  }

  final granted = await _reader.isGranted(p.role, perm.name);
  return granted
      ? const Allow()
      : Deny(permission: perm, reason: DenyReason.notGranted);
}
```

The scope precondition runs first so a principal without a selected site attempting a site-scoped action receives `sessionPreconditionMissing` — the accurate, actionable reason — rather than `notGranted`.

### `permissionsFor`

```dart
@override
Future<Set<Permission>> permissionsFor(Principal p) async {
  final all = await _reader.grantsForRole(p.role);
  return all.where((perm) => switch (perm.scope) {
    ScopeClass.global => true,
    ScopeClass.site   => p.activeSite != null,
    ScopeClass.self   => p.userId     != null,
  }).toSet();
}
```

Returns the exercisable permission set for the current session. UI code that wants the role's full grant list regardless of session reads the snapshot directly.

### `RoleMatrixReader` interface

```dart
abstract class RoleMatrixReader {
  Future<bool>             isGranted(Role role, String permissionName);
  Future<Set<Permission>>  grantsForRole(Role role);  // scope included per permission
}
```

Implementations:

- **`MaterializedViewRoleMatrixReader`** — `isGranted` is `backend.readViewRowInTxn(txn, 'role_permission_grants', '<role>:<permissionName>')` (or the non-transactional equivalent), returning `true` if a row exists. `grantsForRole` is a scan of the view filtered to rows where `role == requested`, mapped into `Permission` values using the row's `scope` field. Where the backend supports an aggregateId prefix-scan, it uses `'<role>:'` as the prefix; otherwise it fetches all view rows and filters in Dart. The matrix is small enough that either approach is fast.

- **`InMemoryRoleMatrixReader`** — `Map<Role, Map<String, Permission>>`. Constructed once, not mutated. Used for unit tests of `TableBackedAuthorizationPolicy` and as the backing for `FailSafeAuthorizationPolicy` (with an empty map).

- **`SnapshotRoleMatrixReader`** — wraps a `PermissionSnapshot`; used by Flutter clients (Section 8).

### Dispatcher integration

The `audited_actions` dispatcher's authorize stage iterates the registered Action's declared permission set and calls `policy.isPermitted(principal, perm)` for each. The first `Deny` short-circuits; the dispatcher emits an `AuthorizationDenied` event carrying the denied permission and the `DenyReason`, then returns `DispatchResult.denied`.

`action_permissions` returns `AuthorizationDecision` values; event construction belongs to the dispatcher.

### Concurrency

`RoleMatrixReader` implementations are safe for concurrent reads. `MaterializedViewRoleMatrixReader` reads through the `StorageBackend`'s view methods, which serialize through the backend's own concurrency model (Sembast: single-isolate transactions; future Postgres: row-level locks). `SnapshotRoleMatrixReader` and `InMemoryRoleMatrixReader` wrap immutable state.

## 7. Failsafe bootstrap

Bootstrap returns an `AuthorizationPolicyBootstrap` sealed value. Validation failures produce a `PolicyFailSafe` result; the bootstrap function does not throw. In a Cloud Run deployment the host wires `isReady` into a readiness probe so an unhealthy revision does not receive traffic without crashing the container.

### Types

```dart
sealed class AuthorizationPolicyBootstrap {
  const AuthorizationPolicyBootstrap();
  AuthorizationPolicy get policy;
  bool                get isReady;
  List<String>        get errors;
}

final class PolicyReady extends AuthorizationPolicyBootstrap {
  const PolicyReady(this._policy);
  final AuthorizationPolicy _policy;
  @override AuthorizationPolicy get policy  => _policy;
  @override bool                get isReady => true;
  @override List<String>        get errors  => const [];
}

final class PolicyFailSafe extends AuthorizationPolicyBootstrap {
  const PolicyFailSafe(this._errors);
  final List<String> _errors;
  @override AuthorizationPolicy get policy  => FailSafeAuthorizationPolicy(_errors);
  @override bool                get isReady => false;
  @override List<String>        get errors  => _errors;
}
```

### Failsafe policy

```dart
class FailSafeAuthorizationPolicy implements AuthorizationPolicy {
  const FailSafeAuthorizationPolicy(this.bootstrapErrors);
  final List<String> bootstrapErrors;

  @override
  Future<AuthorizationDecision> isPermitted(Principal p, Permission perm) async =>
      Deny(permission: perm, reason: DenyReason.bootstrapFailure);

  @override
  Future<Set<Permission>> permissionsFor(Principal p) async => const {};
}
```

Every attempted action during failsafe operation flows through the dispatcher's denial path and records a denial event. The audit trail covers the outage faithfully.

### Bootstrap function

```dart
Future<AuthorizationPolicyBootstrap> bootstrapActionPermissions({
  required EventStore     eventStore,
  required Set<Permission> declaredPermissions,
  required String         yamlPath,
  Initiator               seedInitiator =
      const AutomationInitiator(service: 'action_permissions_seed'),
});
```

### Bootstrap sequence

The host has already constructed an `EventStore` (with `RolePermissionGrantsMaterializer()` in its `materializers` list) and an `ActionRegistry`. Then:

1. Load `PermissionSeed` from the YAML at `yamlPath` via `YamlSeedLoader`.
2. Validate the seed against `declaredPermissions`. On `SeedInvalid`, return `PolicyFailSafe(errors)`; stop.
3. Construct `EventSeedApplier(eventStore, seedInitiator)`; call `apply(seed, declaredPermissions)`. Collect drift in the result.
4. Construct `MaterializedViewRoleMatrixReader(eventStore.backend)`, wrap in `TableBackedAuthorizationPolicy`, return `PolicyReady(policy)`.

The host inspects `isReady` to wire its readiness probe. The library logs `errors` once at WARN on startup and rate-limits subsequent failsafe denial logs to avoid log spam.

A note on the materializer-already-registered requirement: `bootstrapActionPermissions` does not register the materializer for the host (the host must construct its `EventStore` with the materializer in the list). This is because materializers must be present from the first `EventStore.append` to keep the view coherent; registering one mid-stream would leave a gap in the projection. The host's `EventStore` construction is the right place to assemble all of its materializers in one list.

## 8. Client-side implementation

Flutter clients (portal UI, mobile diary) answer authorization questions locally against a `PermissionSnapshot` received at session start. Same `AuthorizationPolicy` interface as on the server; different `RoleMatrixReader` backing.

### `PermissionSnapshot`

```dart
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.role,
    required this.grants,
    required this.issuedAt,
  });
  final Role            role;
  final Set<Permission> grants;    // scope included per permission
  final DateTime        issuedAt;

  Map<String, Object?> toJson();
  factory PermissionSnapshot.fromJson(Map<String, Object?> json);
}
```

A denormalized view of the server-side `permissionsFor(principal)` result, packaged for wire delivery. `issuedAt` gives a downstream cache-invalidation protocol a hook.

### `SnapshotRoleMatrixReader`

```dart
class SnapshotRoleMatrixReader implements RoleMatrixReader {
  const SnapshotRoleMatrixReader(this._snapshot);
  final PermissionSnapshot _snapshot;

  @override
  Future<bool> isGranted(Role role, String permissionName) async {
    if (role != _snapshot.role) return false;
    return _snapshot.grants.any((p) => p.name == permissionName);
  }

  @override
  Future<Set<Permission>> grantsForRole(Role role) async =>
      role == _snapshot.role ? _snapshot.grants : const {};
}
```

The snapshot is principal-scoped (issued for the authenticated user's current role), so the reader answers `false` / `{}` for any other role.

### Client bootstrap

1. Client receives `PermissionSnapshot` JSON in the authentication response and parses it via `PermissionSnapshot.fromJson`.
2. Client constructs `SnapshotRoleMatrixReader(snapshot)`, wraps in `TableBackedAuthorizationPolicy`, and places the policy in session-scoped state (framework choice: Provider, Riverpod, inherited widget).
3. Widget code calls `policy.isPermitted(...)` to drive widget enablement; `policy.permissionsFor(...)` when iterating grants for menu or dashboard construction.

### Why clients don't subscribe to matrix events directly

Matrix events live in the server-side event log. Patient clients have no business reading the full set of admin grants; investigator clients have no need to see another role's grants. The snapshot is the single, principal-scoped projection that clients receive. Sync of the matrix to clients via the events lib's sync mechanism is intentionally not used here.

### Session lifecycle

The snapshot is immutable per session. Events that require re-fetch:

- Login or logout.
- Active role switch (the new role requires a new snapshot).

Active site change does not require re-fetch: the snapshot is unchanged, and `permissionsFor(principal)` returns different results because the principal's `activeSite` changed, transparently.

## 9. Related artifacts

- Formal REQ assertions: `spec/dev-action-permissions.md` (REQ-d00172 through REQ-d00178).
- Sibling library: `audited_actions`.
- Storage substrate: `event_sourcing_datastore` (provides `EventStore`, `StorageBackend`, `Materializer`, `Initiator`).
- Implementation prompt for the worktree that builds this library: `docs/superpowers/specs/2026-04-23-action-permissions-prompt.md`.

## Requirements

This design's authoritative REQ assertions live in
`spec/dev-action-permissions.md` (REQ-d00172..REQ-d00178). This file is
the design narrative; assertion text and content hashes are maintained
in the dev-spec.
